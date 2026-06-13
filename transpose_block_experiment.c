/*
 * transpose_block_experiment.c - Isolated block-size sweep implementation.
 *
 * This file is intentionally not used by the normal Makefile.  The helper
 * script compiles it with different ROW_BLOCK/COL_BLOCK values and links it
 * into temporary copies of test-trans and tracegen.
 */
#include "cachelab.h"

#ifndef ROW_BLOCK
#define ROW_BLOCK 8
#endif

#ifndef COL_BLOCK
#define COL_BLOCK ROW_BLOCK
#endif

#if ROW_BLOCK <= 0
#error "ROW_BLOCK must be positive"
#endif

#if COL_BLOCK <= 0
#error "COL_BLOCK must be positive"
#endif

char transpose_submit_desc[] = "Transpose submission";

static int min_int(int a, int b)
{
    return a < b ? a : b;
}

void transpose_submit(int M, int N, int A[N][M], int B[M][N])
{
    int row, col, i, j;

    for (row = 0; row < N; row += ROW_BLOCK) {
        int row_end = min_int(row + ROW_BLOCK, N);

        for (col = 0; col < M; col += COL_BLOCK) {
            int col_end = min_int(col + COL_BLOCK, M);

            for (i = row; i < row_end; i++) {
                for (j = col; j < col_end; j++) {
                    B[j][i] = A[i][j];
                }
            }
        }
    }
}

void registerFunctions(void)
{
    registerTransFunction(transpose_submit, transpose_submit_desc);
}

int is_transpose(int M, int N, int A[N][M], int B[M][N])
{
    int i, j;

    for (i = 0; i < N; i++) {
        for (j = 0; j < M; j++) {
            if (A[i][j] != B[j][i]) {
                return 0;
            }
        }
    }

    return 1;
}
