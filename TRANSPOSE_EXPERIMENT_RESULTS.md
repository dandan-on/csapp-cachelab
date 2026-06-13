# Transpose Experiment Results

실행일: 2026-06-13

실행 명령:

```bash
./run-transpose-experiments.sh --matrix-preset mixed
```

## Matrix Presets

`official`:

```text
32x32,64x64,61x67
```

`mixed`:

```text
8x8,16x16,31x31,32x32,33x31,32x64,64x32,64x64,61x67,67x61,96x128,128x96,127x131,128x128
```

## Registered Function Results

`trans.c`의 `registerFunctions()`에 등록된 함수 전체를 `mixed` matrix set에 대해 실행했다.

전체 합산 miss 기준 best:

| func_id | function description | matrices | total_misses |
|---:|---|---:|---:|
| 3 | 8x8 blocking with registers | 14 | 62415 |

Matrix별 best:

| M | N | best func_id | function description | misses |
|---:|---:|---:|---|---:|
| 8 | 8 | 3 | 8x8 blocking with registers | 26 |
| 16 | 16 | 3 | 8x8 blocking with registers | 82 |
| 31 | 31 | 1 | Simple row-wise scan transpose | 415 |
| 32 | 32 | 0 | Transpose submission | 288 |
| 32 | 32 | 3 | 8x8 blocking with registers | 288 |
| 33 | 31 | 1 | Simple row-wise scan transpose | 452 |
| 32 | 64 | 9 | 8x8 blocking with swap | 616 |
| 32 | 64 | 10 | 8x8 blocking with swap and diagonal | 616 |
| 64 | 32 | 3 | 8x8 blocking with registers | 572 |
| 64 | 64 | 0 | Transpose submission | 1228 |
| 64 | 64 | 9 | 8x8 blocking with swap | 1228 |
| 64 | 64 | 10 | 8x8 blocking with swap and diagonal | 1228 |
| 61 | 67 | 0 | Transpose submission | 1993 |
| 61 | 67 | 4 | 16x16 blocking | 1993 |
| 67 | 61 | 0 | Transpose submission | 2009 |
| 67 | 61 | 4 | 16x16 blocking | 2009 |
| 96 | 128 | 10 | 8x8 blocking with swap and diagonal | 12544 |
| 128 | 96 | 3 | 8x8 blocking with registers | 3412 |
| 127 | 131 | 3 | 8x8 blocking with registers | 13774 |
| 128 | 128 | 3 | 8x8 blocking with registers | 18436 |

해석:

- 현재 등록 함수들 중 mixed 전체 기준으로는 `trans3` (`8x8 blocking with registers`)가 가장 안정적으로 좋다.
- `32x32`에서는 `transpose_submit`과 `trans3`가 동률이다.
- `64x64`에서는 `transpose_submit`, `trans9`, `trans10`이 동률이다.
- `61x67`, `67x61`에서는 `transpose_submit`과 `trans4`가 동률이다.

## Generic Block Sweep Results

`transpose_block_experiment.c`를 사용해 단순 blocked transpose를 `1x1`부터 `32x32`까지 순차 실행했다.

전체 합산 miss 기준 best block size:

| row_block | col_block | matrices | total_misses |
|---:|---:|---:|---:|
| 2 | 2 | 14 | 55062 |

Matrix별 best block size:

| M | N | row_block | col_block | misses |
|---:|---:|---:|---:|---:|
| 8 | 8 | 1 | 1 | 40 |
| 8 | 8 | 8 | 8 | 40 |
| 8 | 8 | 9 | 9 | 40 |
| 8 | 8 | 10 | 10 | 40 |
| 8 | 8 | 11 | 11 | 40 |
| 8 | 8 | 12 | 12 | 40 |
| 8 | 8 | 13 | 13 | 40 |
| 8 | 8 | 14 | 14 | 40 |
| 8 | 8 | 15 | 15 | 40 |
| 8 | 8 | 16 | 16 | 40 |
| 8 | 8 | 17 | 17 | 40 |
| 8 | 8 | 18 | 18 | 40 |
| 8 | 8 | 19 | 19 | 40 |
| 8 | 8 | 20 | 20 | 40 |
| 8 | 8 | 21 | 21 | 40 |
| 8 | 8 | 22 | 22 | 40 |
| 8 | 8 | 23 | 23 | 40 |
| 8 | 8 | 24 | 24 | 40 |
| 8 | 8 | 25 | 25 | 40 |
| 8 | 8 | 26 | 26 | 40 |
| 8 | 8 | 27 | 27 | 40 |
| 8 | 8 | 28 | 28 | 40 |
| 8 | 8 | 29 | 29 | 40 |
| 8 | 8 | 30 | 30 | 40 |
| 8 | 8 | 31 | 31 | 40 |
| 8 | 8 | 32 | 32 | 40 |
| 16 | 16 | 1 | 1 | 110 |
| 16 | 16 | 8 | 8 | 110 |
| 16 | 16 | 16 | 16 | 110 |
| 16 | 16 | 17 | 17 | 110 |
| 16 | 16 | 18 | 18 | 110 |
| 16 | 16 | 19 | 19 | 110 |
| 16 | 16 | 20 | 20 | 110 |
| 16 | 16 | 21 | 21 | 110 |
| 16 | 16 | 22 | 22 | 110 |
| 16 | 16 | 23 | 23 | 110 |
| 16 | 16 | 24 | 24 | 110 |
| 16 | 16 | 25 | 25 | 110 |
| 16 | 16 | 26 | 26 | 110 |
| 16 | 16 | 27 | 27 | 110 |
| 16 | 16 | 28 | 28 | 110 |
| 16 | 16 | 29 | 29 | 110 |
| 16 | 16 | 30 | 30 | 110 |
| 16 | 16 | 31 | 31 | 110 |
| 16 | 16 | 32 | 32 | 110 |
| 31 | 31 | 1 | 1 | 415 |
| 31 | 31 | 31 | 31 | 415 |
| 31 | 31 | 32 | 32 | 415 |
| 32 | 32 | 8 | 8 | 344 |
| 33 | 31 | 1 | 1 | 452 |
| 32 | 64 | 4 | 4 | 940 |
| 64 | 32 | 8 | 8 | 680 |
| 64 | 64 | 4 | 4 | 1892 |
| 61 | 67 | 23 | 23 | 1929 |
| 67 | 61 | 21 | 21 | 1951 |
| 96 | 128 | 2 | 2 | 8452 |
| 128 | 96 | 8 | 8 | 4048 |
| 127 | 131 | 2 | 2 | 12712 |
| 128 | 128 | 2 | 2 | 11396 |

해석:

- 단순 blocked transpose만 놓고 보면 mixed 전체 합산 기준 `2x2`가 가장 낮은 miss를 보였다.
- 하지만 이 결과는 `trans3`, `trans9`, `trans10`처럼 register를 활용하거나 swap을 쓰는 최적화와는 다른 기준이다.
- Cache Lab 공식 점수와 직접 연결되는 것은 `transpose_submit`이다.

## Script Usage

기본 실행:

```bash
./run-transpose-experiments.sh
```

기본 실행은 다음 두 실험을 모두 수행한다.

1. `trans.c`의 `registerFunctions()`에 등록된 모든 함수 실행
2. `transpose_block_experiment.c` 기반 generic block sweep 실행

공식 matrix만 테스트:

```bash
./run-transpose-experiments.sh --matrix-preset official
```

섞인 matrix set 테스트:

```bash
./run-transpose-experiments.sh --matrix-preset mixed
```

직접 matrix 지정:

```bash
./run-transpose-experiments.sh -m 32x32,64x64,128x128
```

등록 함수만 테스트:

```bash
./run-transpose-experiments.sh --registered-only -m 64x64
```

generic block sweep만 테스트:

```bash
./run-transpose-experiments.sh --block-only --max-block 16 -m 32x32,64x64
```

`1x1`부터 `NxN`까지 block size 순차 테스트:

```bash
./run-transpose-experiments.sh --block-only --max-block 32
```

특정 block size만 테스트:

```bash
./run-transpose-experiments.sh --block-only -b 4,8,16 -m 64x64
```

직사각형 block size 테스트:

```bash
./run-transpose-experiments.sh --block-only -b 4x8,8x4,16x16 -m 32x32
```

임시 빌드 디렉터리 보존:

```bash
./run-transpose-experiments.sh -k --matrix-preset official
```

도움말:

```bash
./run-transpose-experiments.sh --help
```

주의:

- `registered` 실험은 `trans.c`에 정의된 모든 함수가 아니라 `registerFunctions()`에 등록된 함수만 실행한다.
- `generic block sweep`은 `trans.c`를 사용하지 않고, `transpose_block_experiment.c`를 매번 다른 `ROW_BLOCK`, `COL_BLOCK`으로 컴파일해서 실행한다.
- `mixed`와 `--max-block 32` 조합은 valgrind 실행 횟수가 많아서 오래 걸린다.
