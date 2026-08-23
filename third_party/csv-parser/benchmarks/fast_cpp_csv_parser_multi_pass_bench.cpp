#include "bench_common.hpp"

#include <csv.h>

#include <cstddef>
#include <cstdint>
#include <filesystem>
#include <string>
#include <string_view>
#include <unordered_map>
#include <vector>

namespace {
    using quoted_csv_reader = io::CSVReader<
        8,
        io::trim_chars<' '>,
        io::double_quote_escape<',', '"'>
    >;

    struct materialized_row {
        std::string id;
        std::string city;
        std::string state;
        std::string category;
        std::uint64_t amount;
        std::uint64_t quantity;
        std::string flag;
        std::string note;
    };

    const std::string& bench_file() {
        return csv_bench::input_path();
    }

    std::vector<materialized_row> materialize_fast_cpp_rows(const std::string& path) {
        quoted_csv_reader reader(path.c_str());
        reader.read_header(
            io::ignore_extra_column,
            "id",
            "city",
            "state",
            "category",
            "amount",
            "quantity",
            "flag",
            "note"
        );

        std::vector<materialized_row> rows;
        materialized_row row;

        while (reader.read_row(
            row.id,
            row.city,
            row.state,
            row.category,
            row.amount,
            row.quantity,
            row.flag,
            row.note
        )) {
            rows.push_back(row);
        }

        return rows;
    }

    std::uint64_t run_fast_cpp_multi_pass_etl(const std::vector<materialized_row>& rows) {
        std::uint64_t amount_sum = 0;
        for (const auto& row : rows) {
            amount_sum += row.amount;
        }

        std::uint64_t quantity_sum = 0;
        std::uint64_t enabled_count = 0;
        for (const auto& row : rows) {
            quantity_sum += row.quantity;
            enabled_count += row.flag == "Y" ? 1u : 0u;
        }

        std::unordered_map<std::string_view, std::uint64_t> category_counts;
        category_counts.reserve(8);
        for (const auto& row : rows) {
            ++category_counts[row.category];
        }

        std::uint64_t text_checksum = 0;
        for (const auto& row : rows) {
            text_checksum += static_cast<std::uint64_t>(row.city.size() * 3 + row.note.size());
            if (!row.city.empty()) {
                text_checksum += static_cast<unsigned char>(row.city.front());
            }
            if (!row.note.empty()) {
                text_checksum += static_cast<unsigned char>(row.note.front());
            }
        }

        std::uint64_t category_checksum = 0;
        for (const auto& entry : category_counts) {
            category_checksum += static_cast<std::uint64_t>(entry.first.size()) * entry.second;
        }

        return amount_sum + quantity_sum + enabled_count + text_checksum + category_checksum;
    }

    void BM_fast_cpp_csv_parser_materialize_struct_8col(benchmark::State& state) {
        const auto& path = bench_file();
        const auto bytes = std::filesystem::file_size(path);
        std::size_t rows = 0;

        for (auto _ : state) {
            auto materialized = materialize_fast_cpp_rows(path);
            rows = materialized.size();
            benchmark::DoNotOptimize(materialized.data());
            benchmark::ClobberMemory();
        }

        csv_bench::set_items_processed(state, rows);
        csv_bench::set_bytes_processed(state, bytes);
    }

    void BM_fast_cpp_csv_parser_multi_pass_struct_8col(benchmark::State& state) {
        const auto& path = bench_file();
        const auto bytes = std::filesystem::file_size(path);
        const auto rows = materialize_fast_cpp_rows(path);

        for (auto _ : state) {
            const auto checksum = run_fast_cpp_multi_pass_etl(rows);

            benchmark::DoNotOptimize(checksum);
            benchmark::ClobberMemory();
        }

        csv_bench::set_items_processed(state, rows.size());
        csv_bench::set_bytes_processed(state, bytes);
    }

    void BM_fast_cpp_csv_parser_materialize_and_multi_pass_struct_8col(benchmark::State& state) {
        const auto& path = bench_file();
        const auto bytes = std::filesystem::file_size(path);
        std::size_t rows = 0;

        for (auto _ : state) {
            auto materialized = materialize_fast_cpp_rows(path);
            rows = materialized.size();

            const auto checksum = run_fast_cpp_multi_pass_etl(materialized);

            benchmark::DoNotOptimize(checksum);
            benchmark::ClobberMemory();
        }

        csv_bench::set_items_processed(state, rows);
        csv_bench::set_bytes_processed(state, bytes);
    }

    BENCHMARK(BM_fast_cpp_csv_parser_materialize_struct_8col)->UseRealTime()->Unit(benchmark::kMillisecond);
    BENCHMARK(BM_fast_cpp_csv_parser_multi_pass_struct_8col)->UseRealTime()->Unit(benchmark::kMillisecond);
    BENCHMARK(BM_fast_cpp_csv_parser_materialize_and_multi_pass_struct_8col)->UseRealTime()->Unit(benchmark::kMillisecond);
}

CSV_BENCHMARK_MAIN()
