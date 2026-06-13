#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'USAGE'
Usage: ./run-block-tests.sh [options]

Options:
  -b, --blocks LIST     Comma-separated block sizes. Use N or ROWxCOL.
                        Default: 1,2,4,8,16,32
  -m, --matrices LIST   Comma-separated matrix sizes passed as MxN.
                        Default: 32x32,64x64,61x67
  -k, --keep            Keep the temporary build directory.
  -h, --help            Show this help.

Examples:
  ./run-block-tests.sh
  ./run-block-tests.sh -b 4,8,16 -m 64x64
  ./run-block-tests.sh -b 4x8,8x4,16x16 -m 32x32,61x67
USAGE
}

blocks_arg="1,2,4,8,16,32"
matrices_arg="32x32,64x64,61x67"
keep_workdir=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        -b|--blocks)
            blocks_arg="${2:?missing value for $1}"
            shift 2
            ;;
        -m|--matrices)
            matrices_arg="${2:?missing value for $1}"
            shift 2
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

repo_dir="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
workdir="$(mktemp -d "${TMPDIR:-/tmp}/cachelab-blocktest.XXXXXX")"

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
require_file "transpose_block_experiment.c"

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

IFS=',' read -r -a block_specs <<< "$blocks_arg"
IFS=',' read -r -a matrix_specs <<< "$matrices_arg"

cc=(gcc -g -Wall -Werror -std=c99 -m64)
ln -sf "$repo_dir/csim-ref" "$workdir/csim-ref"

printf 'M,N,row_block,col_block,correct,misses\n'

for block_spec in "${block_specs[@]}"; do
    if [[ "$block_spec" =~ ^([0-9]+)$ ]]; then
        row_block="${BASH_REMATCH[1]}"
        col_block="$row_block"
    elif [[ "$block_spec" =~ ^([0-9]+)x([0-9]+)$ ]]; then
        row_block="${BASH_REMATCH[1]}"
        col_block="${BASH_REMATCH[2]}"
    else
        echo "Invalid block size: $block_spec" >&2
        exit 2
    fi

    obj="$workdir/trans_${row_block}x${col_block}.o"
    tracegen_bin="$workdir/tracegen_${row_block}x${col_block}"
    test_bin="$workdir/test-trans_${row_block}x${col_block}"

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
        if [[ "$matrix_spec" =~ ^([0-9]+)x([0-9]+)$ ]]; then
            matrix_m="${BASH_REMATCH[1]}"
            matrix_n="${BASH_REMATCH[2]}"
        else
            echo "Invalid matrix size: $matrix_spec" >&2
            exit 2
        fi

        if output="$(cd "$workdir" && ./test-trans -M "$matrix_m" -N "$matrix_n" 2>&1)"; then
            result="$(printf '%s\n' "$output" | awk -F= '/TEST_TRANS_RESULTS=/{print $2}' | tail -n 1)"
            if [[ "$result" =~ ^([0-9]+):([0-9]+)$ ]]; then
                correct="${BASH_REMATCH[1]}"
                misses="${BASH_REMATCH[2]}"
            else
                correct=0
                misses=0
            fi
        else
            correct=0
            misses=0
            printf '%s\n' "$output" >&2
        fi

        printf '%s,%s,%s,%s,%s,%s\n' \
            "$matrix_m" "$matrix_n" "$row_block" "$col_block" "$correct" "$misses"
    done
done
