#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'USAGE'
Usage: ./run-transpose-experiments.sh [options]

Runs two experiment groups by default:
  1. Every function registered by trans.c::registerFunctions()
  2. Generic blocked transpose with block sizes 1x1 through MAXxMAX

Options:
  -m, --matrices LIST       Comma-separated matrix sizes as MxN.
                            Overrides --matrix-preset when provided.
  --matrix-preset NAME      Matrix set to test. Default: mixed
                            Choices: official, mixed
  --max-block N             Sweep square block sizes 1x1 through NxN.
                            Default: 32
  -b, --blocks LIST         Use explicit block sizes instead of --max-block.
                            Values may be N or ROWxCOL.
  --registered-only         Run only functions registered in trans.c.
  --block-only              Run only the generic block-size sweep.
  -k, --keep                Keep the temporary build directory.
  -h, --help                Show this help.

Examples:
  ./run-transpose-experiments.sh
  ./run-transpose-experiments.sh --registered-only -m 64x64
  ./run-transpose-experiments.sh --matrix-preset mixed --max-block 16
  ./run-transpose-experiments.sh --max-block 16 -m 32x32,64x64
  ./run-transpose-experiments.sh --block-only -b 4x8,8x4,16
USAGE
}

matrix_preset="mixed"
matrices_arg=""
blocks_arg=""
max_block=32
run_registered=1
run_blocks=1
keep_workdir=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        -m|--matrices)
            matrices_arg="${2:?missing value for $1}"
            matrix_preset="custom"
            shift 2
            ;;
        --matrix-preset)
            matrix_preset="${2:?missing value for $1}"
            matrices_arg=""
            shift 2
            ;;
        --max-block)
            max_block="${2:?missing value for $1}"
            shift 2
            ;;
        -b|--blocks)
            blocks_arg="${2:?missing value for $1}"
            shift 2
            ;;
        --registered-only)
            run_registered=1
            run_blocks=0
            shift
            ;;
        --block-only)
            run_registered=0
            run_blocks=1
            shift
            ;;
        -k|--keep)
            keep_workdir=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if [[ ! "$max_block" =~ ^[0-9]+$ ]] || [[ "$max_block" -lt 1 ]]; then
    echo "--max-block must be a positive integer." >&2
    exit 2
fi

if [[ -z "$matrices_arg" ]]; then
    case "$matrix_preset" in
        official)
            matrices_arg="32x32,64x64,61x67"
            ;;
        mixed)
            matrices_arg="8x8,16x16,31x31,32x32,33x31,32x64,64x32,64x64,61x67,67x61,96x128,128x96,127x131,128x128"
            ;;
        custom)
            echo "Internal error: custom matrix preset selected without --matrices." >&2
            exit 2
            ;;
        *)
            echo "Unknown matrix preset: $matrix_preset" >&2
            echo "Choices: official, mixed" >&2
            exit 2
            ;;
    esac
fi

repo_dir="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
workdir="$(mktemp -d "${TMPDIR:-/tmp}/cachelab-transpose.XXXXXX")"

cleanup() {
    if [[ "$keep_workdir" -eq 1 ]]; then
        echo "Kept temporary build directory: $workdir" >&2
    else
        rm -rf "$workdir"
    fi
}
trap cleanup EXIT

require_file() {
    if [[ ! -e "$repo_dir/$1" ]]; then
        echo "Required file not found: $1" >&2
        exit 1
    fi
}

require_file "test-trans.c"
require_file "tracegen.c"
require_file "cachelab.c"
require_file "cachelab.h"
require_file "csim-ref"
require_file "trans.c"

if [[ "$run_blocks" -eq 1 ]]; then
    require_file "transpose_block_experiment.c"
fi

if [[ ! -x "$repo_dir/csim-ref" ]]; then
    echo "csim-ref exists but is not executable: $repo_dir/csim-ref" >&2
    exit 1
fi

if ! command -v valgrind >/dev/null 2>&1; then
    echo "valgrind is required because test-trans uses it to generate traces." >&2
    exit 1
fi

if ! command -v gcc >/dev/null 2>&1; then
    echo "gcc is required to build the temporary test binaries." >&2
    exit 1
fi

IFS=',' read -r -a matrix_specs <<< "$matrices_arg"
for matrix_spec in "${matrix_specs[@]}"; do
    if [[ ! "$matrix_spec" =~ ^[0-9]+x[0-9]+$ ]]; then
        echo "Invalid matrix size: $matrix_spec" >&2
        exit 2
    fi
done

block_specs=()
if [[ -n "$blocks_arg" ]]; then
    IFS=',' read -r -a block_specs <<< "$blocks_arg"
else
    for ((block = 1; block <= max_block; block++)); do
        block_specs+=("$block")
    done
fi

for block_spec in "${block_specs[@]}"; do
    if [[ ! "$block_spec" =~ ^[0-9]+$ && ! "$block_spec" =~ ^[0-9]+x[0-9]+$ ]]; then
        echo "Invalid block size: $block_spec" >&2
        exit 2
    fi
done

cc=(gcc -g -Wall -Werror -std=c99 -m64)
registered_rows="$workdir/registered.tsv"
block_rows="$workdir/blocks.tsv"

ln -sf "$repo_dir/csim-ref" "$workdir/csim-ref"

parse_registered_output() {
    local matrix_m="$1"
    local matrix_n="$2"

    awk -v matrix_m="$matrix_m" -v matrix_n="$matrix_n" '
        /^func [0-9]+ \(/ {
            line = $0

            id = line
            sub(/^func /, "", id)
            sub(/ .*/, "", id)

            desc = line
            sub(/^func [0-9]+ \(/, "", desc)
            sub(/\): hits:.*/, "", desc)

            hits = line
            sub(/.*hits:/, "", hits)
            sub(/, misses:.*/, "", hits)

            misses = line
            sub(/.*misses:/, "", misses)
            sub(/, evictions:.*/, "", misses)

            evictions = line
            sub(/.*evictions:/, "", evictions)

            printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
                matrix_m, matrix_n, id, desc, hits, misses, evictions
        }
    '
}

print_registered_summary() {
    if [[ ! -s "$registered_rows" ]]; then
        echo "No registered-function results were collected."
        return
    fi

    echo
    echo "== Registered Functions =="
    printf 'M\tN\tfunc_id\tdescription\thits\tmisses\tevictions\n'
    cat "$registered_rows"

    echo
    echo "== Best Registered Function(s) By Matrix =="
    printf 'M\tN\tfunc_id\tdescription\tmisses\n'
    awk -F '\t' '
        {
            rows += 1
            row_m[rows] = $1
            row_n[rows] = $2
            row_id[rows] = $3
            row_desc[rows] = $4
            row_misses[rows] = $6

            key = $1 "x" $2
            if (!(key in seen)) {
                seen[key] = 1
                order[++order_count] = key
            }
            if (!(key in best_misses) || $6 + 0 < best_misses[key]) {
                best_misses[key] = $6
                best_m[key] = $1
                best_n[key] = $2
            }
        }
        END {
            for (i = 1; i <= order_count; i++) {
                key = order[i]
                for (r = 1; r <= rows; r++) {
                    if (row_m[r] "x" row_n[r] == key &&
                        row_misses[r] + 0 == best_misses[key] + 0) {
                        printf "%s\t%s\t%s\t%s\t%s\n",
                            best_m[key], best_n[key], row_id[r],
                            row_desc[r], best_misses[key]
                    }
                }
            }
        }
    ' "$registered_rows"

    echo
    echo "== Best Registered Function(s) By Total Misses =="
    printf 'func_id\tdescription\tmatrices\ttotal_misses\n'
    awk -F '\t' '
        {
            key = $3 SUBSEP $4
            if (!(key in seen)) {
                seen[key] = 1
                order[++order_count] = key
            }
            total[key] += $6
            count[key] += 1
        }
        END {
            for (key in total) {
                if (!found || total[key] < best_total) {
                    found = 1
                    best_total = total[key]
                }
            }
            for (i = 1; i <= order_count; i++) {
                key = order[i]
                if (total[key] == best_total) {
                    split(key, fields, SUBSEP)
                    printf "%s\t%s\t%s\t%s\n",
                        fields[1], fields[2], count[key], total[key]
                }
            }
        }
    ' "$registered_rows"
}

print_block_summary() {
    if [[ ! -s "$block_rows" ]]; then
        echo "No block-sweep results were collected."
        return
    fi

    echo
    echo "== Generic Block Sweep =="
    printf 'M\tN\trow_block\tcol_block\tcorrect\tmisses\n'
    cat "$block_rows"

    echo
    echo "== Best Block Size(s) By Matrix =="
    printf 'M\tN\trow_block\tcol_block\tmisses\n'
    awk -F '\t' '
        $5 == 1 {
            rows += 1
            row_m[rows] = $1
            row_n[rows] = $2
            row_block[rows] = $3
            col_block[rows] = $4
            row_misses[rows] = $6

            key = $1 "x" $2
            if (!(key in seen)) {
                seen[key] = 1
                order[++order_count] = key
            }
            if (!(key in best_misses) || $6 + 0 < best_misses[key]) {
                best_misses[key] = $6
                best_m[key] = $1
                best_n[key] = $2
            }
        }
        END {
            for (i = 1; i <= order_count; i++) {
                key = order[i]
                for (r = 1; r <= rows; r++) {
                    if (row_m[r] "x" row_n[r] == key &&
                        row_misses[r] + 0 == best_misses[key] + 0) {
                        printf "%s\t%s\t%s\t%s\t%s\n",
                            best_m[key], best_n[key], row_block[r],
                            col_block[r], best_misses[key]
                    }
                }
            }
        }
    ' "$block_rows"

    echo
    echo "== Best Block Size(s) By Total Misses =="
    printf 'row_block\tcol_block\tmatrices\ttotal_misses\n'
    awk -F '\t' '
        $5 == 1 {
            key = $3 SUBSEP $4
            if (!(key in seen)) {
                seen[key] = 1
                order[++order_count] = key
            }
            total[key] += $6
            count[key] += 1
        }
        END {
            for (key in total) {
                if (!found || total[key] < best_total) {
                    found = 1
                    best_total = total[key]
                }
            }
            for (i = 1; i <= order_count; i++) {
                key = order[i]
                if (total[key] == best_total) {
                    split(key, fields, SUBSEP)
                    printf "%s\t%s\t%s\t%s\n",
                        fields[1], fields[2], count[key], total[key]
                }
            }
        }
    ' "$block_rows"
}

run_registered_experiments() {
    local obj="$workdir/trans-current.o"
    local tracegen_bin="$workdir/tracegen-current"
    local test_bin="$workdir/test-trans-current"

    "${cc[@]}" -O0 -I "$repo_dir" -c "$repo_dir/trans.c" -o "$obj"
    "${cc[@]}" -O0 -I "$repo_dir" \
        -o "$tracegen_bin" "$repo_dir/tracegen.c" "$obj" "$repo_dir/cachelab.c"
    "${cc[@]}" -I "$repo_dir" \
        -o "$test_bin" "$repo_dir/test-trans.c" "$repo_dir/cachelab.c" "$obj"

    ln -sf "$tracegen_bin" "$workdir/tracegen"
    ln -sf "$test_bin" "$workdir/test-trans"

    : > "$registered_rows"

    for matrix_spec in "${matrix_specs[@]}"; do
        local matrix_m="${matrix_spec%x*}"
        local matrix_n="${matrix_spec#*x}"
        local output

        if output="$(cd "$workdir" && ./test-trans -M "$matrix_m" -N "$matrix_n" 2>&1)"; then
            parse_registered_output "$matrix_m" "$matrix_n" <<< "$output" >> "$registered_rows"
        else
            echo "Registered-function run failed for ${matrix_m}x${matrix_n}." >&2
            printf '%s\n' "$output" >&2
        fi
    done

    print_registered_summary
}

run_block_experiments() {
    : > "$block_rows"

    for block_spec in "${block_specs[@]}"; do
        local row_block
        local col_block

        if [[ "$block_spec" =~ ^([0-9]+)$ ]]; then
            row_block="${BASH_REMATCH[1]}"
            col_block="$row_block"
        else
            row_block="${block_spec%x*}"
            col_block="${block_spec#*x}"
        fi

        local obj="$workdir/trans_${row_block}x${col_block}.o"
        local tracegen_bin="$workdir/tracegen_${row_block}x${col_block}"
        local test_bin="$workdir/test-trans_${row_block}x${col_block}"

        "${cc[@]}" -O0 -I "$repo_dir" \
            -DROW_BLOCK="$row_block" -DCOL_BLOCK="$col_block" \
            -c "$repo_dir/transpose_block_experiment.c" -o "$obj"
        "${cc[@]}" -O0 -I "$repo_dir" \
            -o "$tracegen_bin" "$repo_dir/tracegen.c" "$obj" "$repo_dir/cachelab.c"
        "${cc[@]}" -I "$repo_dir" \
            -o "$test_bin" "$repo_dir/test-trans.c" "$repo_dir/cachelab.c" "$obj"

        ln -sf "$tracegen_bin" "$workdir/tracegen"
        ln -sf "$test_bin" "$workdir/test-trans"

        for matrix_spec in "${matrix_specs[@]}"; do
            local matrix_m="${matrix_spec%x*}"
            local matrix_n="${matrix_spec#*x}"
            local output
            local result
            local correct=0
            local misses=0

            if output="$(cd "$workdir" && ./test-trans -M "$matrix_m" -N "$matrix_n" 2>&1)"; then
                result="$(printf '%s\n' "$output" | awk -F= '/TEST_TRANS_RESULTS=/{print $2}' | tail -n 1)"
                if [[ "$result" =~ ^([0-9]+):([0-9]+)$ ]]; then
                    correct="${BASH_REMATCH[1]}"
                    misses="${BASH_REMATCH[2]}"
                fi
            else
                echo "Block run failed for block ${row_block}x${col_block}, matrix ${matrix_m}x${matrix_n}." >&2
                printf '%s\n' "$output" >&2
            fi

            printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
                "$matrix_m" "$matrix_n" "$row_block" "$col_block" "$correct" "$misses" \
                >> "$block_rows"
        done
    done

    print_block_summary
}

if [[ "$run_registered" -eq 1 ]]; then
    run_registered_experiments
fi

if [[ "$run_blocks" -eq 1 ]]; then
    run_block_experiments
fi
