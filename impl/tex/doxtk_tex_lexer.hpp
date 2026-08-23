#ifndef DOXTK_TEX_LEXER_HPP
#define DOXTK_TEX_LEXER_HPP

/* ========================================================================
 * doxtk_tex_lexer.hpp — the "mouth" of the impl/tex frontend
 *
 * A tokeniser for TeX source following TeX82's input processor (the
 * get_next procedure in third_party/TeXScrape/TeXSource/TeX.p,
 * sections 332–365):
 *
 *   - three scanning states: NewLine (N), MidLine (M), SkipBlanks (S)
 *     ({341:});
 *   - control words (letters only, trailing blanks skipped) vs.
 *     control symbols (a single non-letter) ({354:});
 *   - `%` comments consume the rest of the line ({353:});
 *   - an empty line yields the token `\par` ({347:});
 *   - `^^h` / `^^hh` input escapes are resolved while reading, before
 *     catcode lookup ({352:});
 *   - active characters (catcode 13, e.g. `~`) are reported as
 *     single-character control sequences, exactly as TeX does
 *     ({353:}: curcs := cur_chr).
 *
 * The lexer is pull-based: tokens are produced on demand so that the
 * expander (the "gullet") sits between the lexer and the parser,
 * mirroring TeX's mouth → gullet → stomach pipeline.  An input stack
 * supports \input/\include (TeX.p {300:} instaterecord, simplified).
 * ======================================================================== */

#include <cstdint>
#include <optional>
#include <string>
#include <utility>
#include <vector>

#include "doxtk_tex_catcode.hpp"

namespace doxtk {
namespace swaff {
namespace tex {

/* ------------------------------------------------------------------------
 * TexToken
 *
 * A lexical token.  Two forms, matching TeX's (curcmd, curchr) pairs:
 *   - character token: is_cs=false, cat=catcode, ch=character;
 *   - control sequence: is_cs=true, name=cs name (no escape char);
 *     cat is Escape.
 * param_index > 0 marks a #n parameter reference; only the expander
 * produces those (inside macro bodies).  noexpand marks a token that
 * \noexpand protected during a single expansion step.
 * -------------------------------------------------------------------- */

struct TexToken {
    bool is_cs = false;
    CatCode cat = CatCode::Other;
    char ch = 0;
    std::string name;
    uint32_t line = 0;
    int param_index = 0;   /* 0 = not a parameter reference */
    bool noexpand = false;

    static TexToken character(CatCode cat, char c, uint32_t line) {
        TexToken t;
        t.is_cs = false;
        t.cat = cat;
        t.ch = c;
        t.line = line;
        return t;
    }

    static TexToken control_seq(std::string cs_name, uint32_t line) {
        TexToken t;
        t.is_cs = true;
        t.cat = CatCode::Escape;
        t.name = std::move(cs_name);
        t.line = line;
        return t;
    }

    /* Source reconstruction (used for math content and diagnostics). */
    std::string to_source() const {
        if (is_cs) {
            /* Control words need a trailing space to stay lexically
             * separate from following letters. */
            bool word = !name.empty();
            for (char c : name) {
                if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z'))) {
                    word = false;
                    break;
                }
            }
            return "\\" + name + (word ? " " : "");
        }
        return std::string(1, ch);
    }
};

/* ------------------------------------------------------------------------
 * Lexer
 * -------------------------------------------------------------------- */

class Lexer {
public:
    explicit Lexer(std::string source, std::string source_name = "<input>") {
        push_source(std::move(source), std::move(source_name));
    }

    CatCodeTable& catcodes() { return catcodes_; }
    const CatCodeTable& catcodes() const { return catcodes_; }

    /* Push a new input source (\\input / \\include).  Tokens are read
     * from the new source until it is exhausted, then reading resumes
     * in the enclosing source (TeX.p {321:}–{323:}, simplified). */
    void push_source(std::string source, std::string source_name) {
        inputs_.push_back(Input{std::move(source), std::move(source_name), 0, 1});
    }

    const std::string& current_source_name() const {
        return inputs_.back().name;
    }

    size_t input_depth() const { return inputs_.size(); }

    /* Fetch the next raw character, resolving ^^ sequences (TeX.p
     * {352:}).  Returns -1 when every input on the stack is
     * exhausted.  Newlines are counted for diagnostics. */
    int read_char() {
        for (;;) {
            if (inputs_.empty()) return -1;
            Input& in = inputs_.back();
            if (in.pos >= in.text.size()) {
                inputs_.pop_back();
                continue;
            }
            char c = in.text[in.pos++];

            /* ^^ processing: only when the character's own catcode is
             * Superscript (TeX.p {352:}).  With INITEX defaults this
             * means the two characters must both be '^'. */
            if (catcodes_.catcode_of(c) == CatCode::Superscript &&
                in.pos < in.text.size() && in.text[in.pos] == c) {
                if (in.pos + 1 < in.text.size()) {
                    char c1 = in.text[in.pos + 1];
                    bool is_lhex = (c1 >= '0' && c1 <= '9') ||
                                   (c1 >= 'a' && c1 <= 'f');
                    if (is_lhex && in.pos + 2 < in.text.size()) {
                        char c2 = in.text[in.pos + 2];
                        bool c2_lhex = (c2 >= '0' && c2 <= '9') ||
                                       (c2 >= 'a' && c2 <= 'f');
                        if (c2_lhex) {
                            /* ^^hh: two lowercase hex digits. */
                            auto hv = [](char h) -> int {
                                if (h >= '0' && h <= '9') return h - '0';
                                return h - 'a' + 10;
                            };
                            c = static_cast<char>(hv(c1) * 16 + hv(c2));
                            in.pos += 3;
                            return static_cast<unsigned char>(c);
                        }
                    }
                    /* ^^c: c < 128 maps to c +/- 64 (TeX.p {352:}). */
                    int code = static_cast<unsigned char>(c1);
                    if (code < 128) {
                        if (code >= 64 && code <= 127) code -= 64;
                        else code += 64;
                        in.pos += 2;
                        return code;
                    }
                }
            }

            if (c == '\n') in.line++;
            return static_cast<unsigned char>(c);
        }
    }

    /* Put one character back (used after lookahead).  Only valid
     * immediately after read_char returned a character from the
     * current input. */
    void unread_char(char c) {
        if (inputs_.empty()) return;
        Input& in = inputs_.back();
        if (in.pos > 0) {
            in.pos--;
            in.text[in.pos] = c;
        }
    }

    /* Read raw text until (and consuming) `delim`.  Used for the
     * verbatim environment, whose body must not be tokenised.
     * Searches only the current input source. */
    std::string read_raw_until(const std::string& delim) {
        std::string out;
        for (;;) {
            int c = read_char();
            if (c < 0) break;  /* EOF: unterminated verbatim; take what we have */
            out += static_cast<char>(c);
            if (out.size() >= delim.size() &&
                out.compare(out.size() - delim.size(), delim.size(), delim) == 0) {
                out.resize(out.size() - delim.size());
                break;
            }
        }
        return out;
    }

    uint32_t current_line() const {
        return inputs_.empty() ? 0 : inputs_.back().line;
    }

    /* ----------------------------------------------------------------
     * next_token — the input processor core (TeX.p {343:}–{357:}).
     * Returns std::nullopt at end of all input.
     * ------------------------------------------------------------- */
    std::optional<TexToken> next_token() {
        for (;;) {
            int ci = read_char();
            if (ci < 0) return std::nullopt;
            char c = static_cast<char>(ci);
            CatCode cat = catcodes_.catcode_of(c);
            uint32_t line = current_line();

            switch (cat) {
            case CatCode::Escape:
                return scan_control_sequence(line);

            case CatCode::BeginGroup:
            case CatCode::EndGroup:
            case CatCode::MathShift:
            case CatCode::AlignTab:
            case CatCode::Parameter:
            case CatCode::Superscript:
            case CatCode::Subscript:
                state_ = State::MidLine;
                return TexToken::character(cat, c, line);

            case CatCode::Letter:
            case CatCode::Other:
                state_ = State::MidLine;
                return TexToken::character(cat, c, line);

            case CatCode::Active:
                /* Active characters behave like control sequences
                 * whose name is the character itself (TeX.p {353:}). */
                state_ = State::MidLine;
                return TexToken::control_seq(std::string(1, c), line);

            case CatCode::Space:
                if (state_ == State::MidLine) {
                    state_ = State::SkipBlanks;
                    return TexToken::character(CatCode::Space, ' ', line);
                }
                /* NewLine / SkipBlanks: blanks are absorbed. */
                break;

            case CatCode::EndOfLine: {
                State was = state_;
                state_ = State::NewLine;
                if (was == State::NewLine) {
                    /* Empty line → \par (TeX.p {347:}). */
                    return TexToken::control_seq("par", line);
                }
                if (was == State::MidLine) {
                    /* End of line acts as a space (TeX.p {348:}). */
                    return TexToken::character(CatCode::Space, ' ', line);
                }
                /* SkipBlanks: no token. */
                break;
            }

            case CatCode::Comment:
                /* Skip to (and including) end of line (TeX.p {353:}). */
                skip_to_end_of_line();
                state_ = State::NewLine;
                break;

            case CatCode::Ignored:
                break;

            case CatCode::Invalid:
                /* TeX errors here; the frontend is total, so skip. */
                break;
            }
        }
    }

private:
    enum class State { NewLine, MidLine, SkipBlanks };

    struct Input {
        std::string text;
        std::string name;
        size_t pos = 0;
        uint32_t line = 1;
    };

    /* TeX.p {355:}–{356:}: after the escape character, a letter starts
     * a control word; anything else is a single-character control
     * symbol. */
    TexToken scan_control_sequence(uint32_t line) {
        int ci = read_char();
        if (ci < 0) {
            return TexToken::control_seq("", line);
        }
        char c = static_cast<char>(ci);
        CatCode cat = catcodes_.catcode_of(c);

        std::string name;
        if (cat == CatCode::Letter) {
            name += c;
            for (;;) {
                int ni = read_char();
                if (ni < 0) break;
                char nc = static_cast<char>(ni);
                if (catcodes_.catcode_of(nc) == CatCode::Letter) {
                    name += nc;
                } else {
                    unread_char(nc);
                    break;
                }
            }
            /* Blanks after a control word are skipped (TeX.p {356:}). */
            state_ = State::SkipBlanks;
        } else {
            name += c;
            state_ = State::MidLine;
        }
        return TexToken::control_seq(std::move(name), line);
    }

    void skip_to_end_of_line() {
        for (;;) {
            int ci = read_char();
            if (ci < 0) return;
            char c = static_cast<char>(ci);
            if (catcodes_.catcode_of(c) == CatCode::EndOfLine) return;
        }
    }

    CatCodeTable catcodes_;
    std::vector<Input> inputs_;
    State state_ = State::NewLine;
};

} // namespace tex
} // namespace swaff
} // namespace doxtk

#endif // DOXTK_TEX_LEXER_HPP
