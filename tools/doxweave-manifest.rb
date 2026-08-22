#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "yaml"

# doxweave-manifest.rb – Generates manifests/ from kernel Lua sources.
#
# Scans kernel/*.lua, extracts each kernel's advertise data by parsing the
# kernel.advertise() function body, and produces:
#   manifests/Kernels.yaml      – per-kernel index with capabilities
#   manifests/Capabilities.yaml – aggregate capability contract registry
#
# The parser handles a strict subset of Lua sufficient for advertise tables:
#   - double-quoted string literals (with \" escape)
#   - table constructors ({…}) with string and identifier keys
#   - comments (-- to end of line)
#   - nested tables, trailing commas, bare-value entries

DOXTK_ROOT = File.expand_path('..', __dir__)
KERNEL_DIR = File.join(DOXTK_ROOT, 'kernel')
MANIFEST_DIR = File.join(DOXTK_ROOT, 'manifests')

# ---------------------------------------------------------------------------
# Minimal Lua table parser
# ---------------------------------------------------------------------------

class LuaTableParser
  def initialize(source)
    @s = source
    @pos = 0
  end

  def parse
    skip_whitespace_and_comments
    raise "expected '{'" unless peek == '{'
    advance  # consume '{'
    read_table
  end

  private

  def peek
    @s[@pos]
  end

  def advance
    c = @s[@pos]
    @pos += 1
    c
  end

  def skip_whitespace_and_comments
    loop do
      while @pos < @s.length && (@s[@pos] =~ /\s/)
        @pos += 1
      end
      if @pos + 1 < @s.length && @s[@pos] == '-' && @s[@pos + 1] == '-'
        @pos += 2
        while @pos < @s.length && @s[@pos] != "\n"
          @pos += 1
        end
      else
        break
      end
    end
  end

  def read_string
    raise "expected '\"' at #{@pos}" unless peek == '"'
    advance
    result = +""
    loop do
      raise "unterminated string at #{@pos}" if @pos >= @s.length
      c = advance
      break if c == '"'
      if c == '\\' && @pos < @s.length
        n = advance
        case n
        when '"', '\\', '/' then result << n
        when 'n' then result << "\n"
        when 't' then result << "\t"
        when 'r' then result << "\r"
        else result << '\\' << n
        end
      else
        result << c
      end
    end
    result
  end

  def read_key
    skip_whitespace_and_comments
    c = peek
    if c == '"'
      read_string
    elsif c =~ /[a-zA-Z_]/
      ident = +""
      while @pos < @s.length && (@s[@pos] =~ /[a-zA-Z0-9_.]/)
        ident << advance
      end
      ident
    else
      raise "expected key at #{@pos}, got #{c.inspect}"
    end
  end

  def read_value
    skip_whitespace_and_comments
    c = peek
    case c
    when '{'
      advance              # consume '{'
      read_table
    when '"'
      read_string
    when '['
      advance              # consume '['
      read_array
    when 't', 'f', 'n'
      read_literal
    when '-', '0'..'9'
      read_number
    else
      raise "unexpected value start #{c.inspect} at #{@pos}"
    end
  end

  def read_array
    result = []
    skip_whitespace_and_comments
    if peek == ']'
      advance
      return result
    end
    loop do
      result << read_value
      skip_whitespace_and_comments
      c = advance
      break if c == ']'
      raise "expected ',' or ']' at #{@pos}, got #{c.inspect}" unless c == ','
    end
    result
  end

  def read_literal
    if @s[@pos, 4] == 'true'
      @pos += 4
      true
    elsif @s[@pos, 5] == 'false'
      @pos += 5
      false
    elsif @s[@pos, 3] == 'nil'
      @pos += 3
      nil
    else
      raise "expected literal at #{@pos}"
    end
  end

  def read_number
    start = @pos
    advance if peek == '-'
    while @pos < @s.length && (@s[@pos] =~ /[0-9]/)
      @pos += 1
    end
    if @pos < @s.length && @s[@pos] == '.'
      @pos += 1
      while @pos < @s.length && (@s[@pos] =~ /[0-9]/)
        @pos += 1
      end
    end
    @s[start...@pos].to_f
  end

  def read_table
    # We already consumed the '{' in read_value or parse
    result = {}
    skip_whitespace_and_comments
    return result if peek == '}'

    loop do
      skip_whitespace_and_comments
      break if peek == '}' || @pos >= @s.length

      # Try to read a key, then check for '=' to distinguish
      # key = value from bare value entries.
      if peek == '"' || (peek =~ /[a-zA-Z_]/)
        save = @pos
        key = read_key
        skip_whitespace_and_comments
        if peek == '='
          advance            # consume '='
          result[key] = read_value
        else
          # Bare value: rewind and read as value
          @pos = save
          val = read_value
          result[result.length + 1] = val
        end
      else
        val = read_value
        result[result.length + 1] = val
      end

      skip_whitespace_and_comments
      break if peek == '}' || @pos >= @s.length
      c = advance
      break if c == '}'
      raise "expected ',' or '}' at #{@pos}, got #{c.inspect}" unless c == ','
    end

    # Consume the closing '}'
    if peek == '}'
      advance
    end

    result
  end
end

# ---------------------------------------------------------------------------
# Extract the advertise table from a Lua source string
# ---------------------------------------------------------------------------

def extract_advertise(source)
  # Find "function kernel.advertise()"
  idx = source.index(/function\s+kernel\.advertise\s*\(/)
  return nil unless idx

  # Find the return statement inside the function
  ret_idx = source.index(/return\s*\{/, idx)
  return nil unless ret_idx

  # Find the matching closing brace for the return table
  brace_start = source.index('{', ret_idx)
  return nil unless brace_start

  depth = 0
  pos = brace_start
  while pos < source.length
    c = source[pos]
    if c == '{'
      depth += 1
    elsif c == '}'
      depth -= 1
      if depth == 0
        table_src = source[brace_start..pos]
        begin
          parser = LuaTableParser.new(table_src)
          return parser.parse
        rescue => e
          $stderr.puts "  WARNING: parse error in advertise: #{e.message}"
          return nil
        end
      end
    elsif c == '"'
      # skip string
      pos += 1
      while pos < source.length
        if source[pos] == '\\'
          pos += 2
        elsif source[pos] == '"'
          break
        else
          pos += 1
        end
      end
    elsif c == '-' && source[pos + 1] == '-'
      # skip comment
      pos += 2
      while pos < source.length && source[pos] != "\n"
        pos += 1
      end
    end
    pos += 1
  end
  nil
end

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main
  FileUtils.mkdir_p(MANIFEST_DIR)

  kernels = []
  capabilities = {}

  kernel_files = Dir.glob(File.join(KERNEL_DIR, '*.lua')).sort

  puts "Scanning #{kernel_files.length} kernel files..."

  kernel_files.each do |path|
    basename = File.basename(path)
    source = File.read(path)
    advertise = extract_advertise(source)

    unless advertise
      $stderr.puts "  SKIP #{basename}: could not extract advertise table"
      next
    end

    name = advertise['name']
    description = advertise['description']
    caps = advertise['capabilities']

    unless name && caps
      $stderr.puts "  SKIP #{basename}: missing name or capabilities"
      next
    end

    # Normalize capabilities: Lua table may be indexed 1..n
    cap_list = []
    if caps.is_a?(Hash)
      cap_list = caps.keys.select { |k| k.is_a?(Integer) }.sort.map { |k| caps[k] }
    end

    next if cap_list.empty?

    kernel_entry = {
      'name' => name,
      'path' => "kernel/#{basename}",
      'description' => description,
      'capabilities' => cap_list.map { |c| c['name'] }
    }

    kernels << kernel_entry

    cap_list.each do |cap|
      cap_name = cap['name']
      next unless cap_name

      capabilities[cap_name] = {
        'name' => cap_name,
        'version' => cap['version'],
        'description' => cap['description'] || description,
        'inputs' => cap['inputs'],
        'outputs' => cap['outputs'],
        'services' => cap['services']
      }
    end

    puts "  OK  #{basename} -> #{name} (#{cap_list.length} capabilities)"
  end

  # Write Kernels.yaml
  kernels_yaml = {
    'schema' => 'doxtk.kernels/1.0.0',
    'kind' => 'KernelManifest',
    'generated_by' => 'tools/doxweave-manifest.rb',
    'kernels' => kernels
  }

  kernels_path = File.join(MANIFEST_DIR, 'Kernels.yaml')
  File.write(kernels_path, YAML.dump(kernels_yaml))
  puts "\nWrote #{kernels_path} (#{kernels.length} kernels)"

  # Write Capabilities.yaml
  caps_yaml = {
    'schema' => 'doxtk.capabilities/1.0.0',
    'kind' => 'CapabilityRegistry',
    'generated_by' => 'tools/doxweave-manifest.rb',
    'capabilities' => capabilities
  }

  caps_path = File.join(MANIFEST_DIR, 'Capabilities.yaml')
  File.write(caps_path, YAML.dump(caps_yaml))
  puts "Wrote #{caps_path} (#{capabilities.length} capabilities)"
end

main
