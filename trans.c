/* 
 * trans.c - Matrix transpose B = A^T
 *
 * Each transpose function must have a prototype of the form:
 * void trans(int M, int N, int A[N][M], int B[M][N]);
 *
 * A transpose function is evaluated by counting the number of misses
 * on a 1KB direct mapped cache with a block size of 32 bytes.
 */ 
#include <stdio.h>
#include "cachelab.h"

int is_transpose(int M, int N, int A[N][M], int B[M][N]);

/* 
 * You can define additional transpose functions below. We've defined
 * a simple one below to help you get started. 
 */ 

/* 
 * trans - A simple baseline transpose function, not optimized for the cache.
 */
char trans_desc[] = "Simple row-wise scan transpose";
void trans(int M, int N, int A[N][M], int B[M][N])
{
    int i, j, tmp;

    for (i = 0; i < N; i++) {
        for (j = 0; j < M; j++) {
            tmp = A[i][j];
            B[j][i] = tmp;
        }
    }    

}

char trans2_desc[] = "8x8 blocking";
void trans2(int M, int N, int A[N][M], int B[M][N])
{
    int i, j, k, l;
    int rowEnd, colEnd;

    for (i = 0; i < N; i += 8) {
      for (j = 0; j < M; j += 8) {
        rowEnd = i + 8;
        colEnd = j + 8;

        if (rowEnd > N) {
          rowEnd = N;
        }
        if (colEnd > M) {
          colEnd = M;
        }

        for (k = i; k < rowEnd; k++) {
          for (l = j; l < colEnd; l++) {
            B[l][k] = A[k][l];
          }
        }
      }
    }
}

char trans3_desc[] = "8x8 blocking with registers";
void trans3(int M, int N, int A[N][M], int B[M][N])
{
    int i, j, k, l;
    int t0, t1, t2, t3, t4, t5, t6, t7;

    for (i = 0; i < N; i += 8) {
      for (j = 0; j < M; j += 8) {
        if (j + 7 < M) {
          for (k = i; k < (i + 8 > N ? N : i + 8); k++) {
            t0 = A[k][j];
            t1 = A[k][j+1];
            t2 = A[k][j+2];
            t3 = A[k][j+3];
            t4 = A[k][j+4];
            t5 = A[k][j+5];
            t6 = A[k][j+6];
            t7 = A[k][j+7];

            B[j][k] = t0;
            B[j+1][k] = t1;
            B[j+2][k] = t2;
            B[j+3][k] = t3;
            B[j+4][k] = t4;
            B[j+5][k] = t5;
            B[j+6][k] = t6;
            B[j+7][k] = t7;
          }
        } else {
          for (k = i; k < (i + 8 > N ? N : i + 8); k++) {
            for (l = j; l < (j + 8 > M ? M : j + 8); l++) {
              B[l][k] = A[k][l];
            }
          }
        }
      }
    }
}

char trans4_desc[] = "16x16 blocking";
void trans4(int M, int N, int A[N][M], int B[M][N])
{
    int i, j, k, l;
    int rowEnd, colEnd;

    for (i = 0; i < N; i += 16) {
      for (j = 0; j < M; j += 16) {
        rowEnd = i + 16;
        colEnd = j + 16;

        if (rowEnd > N) {
          rowEnd = N;
        }
        if (colEnd > M) {
          colEnd = M;
        }

        for (k = i; k < rowEnd; k++) {
          for (l = j; l < colEnd; l++) {
            B[l][k] = A[k][l];
          }
        }
      }
    }
}

char trans5_desc[] = "4x4 blocking";
void trans5(int M, int N, int A[N][M], int B[M][N])
{
    int i, j, k, l;
    int rowEnd, colEnd;

    for (i = 0; i < N; i += 4) {
      for (j = 0; j < M; j += 4) {
        rowEnd = i + 4;
        colEnd = j + 4;

        if (rowEnd > N) {
          rowEnd = N;
        }
        if (colEnd > M) {
          colEnd = M;
        }

        for (k = i; k < rowEnd; k++) {
          for (l = j; l < colEnd; l++) {
            B[l][k] = A[k][l];
          }
        }
      }
    }
}

char trans6_desc[] = "4x4 blocking with registers";
void trans6(int M, int N, int A[N][M], int B[M][N])
{
    int i, j, k, l;
    int t0, t1, t2, t3;

    for (i = 0; i < N; i += 4) {
      for (j = 0; j < M; j += 4) {
        if (j + 3 < M) {
          for (k = i; k < (i + 4 > N ? N : i + 4); k++) {
            t0 = A[k][j];
            t1 = A[k][j+1];
            t2 = A[k][j+2];
            t3 = A[k][j+3];

            B[j][k] = t0;
            B[j+1][k] = t1;
            B[j+2][k] = t2;
            B[j+3][k] = t3;
          }
        } else {
          for (k = i; k < (i + 4 > N ? N : i + 4); k++) {
            for (l = j; l < (j + 4 > M ? M : j + 4); l++) {
              B[l][k] = A[k][l];
            }
          }
        }
      }
    }
}

char trans7_desc[] = "8x8 split into 4x4 blocks";
void trans7(int M, int N, int A[N][M], int B[M][N])
{
    int i, j, k, l;
    int ii, jj;
    int rowEnd, colEnd;

    for (i = 0; i < N; i += 8) {
      for (j = 0; j < M; j += 8) {
        rowEnd = i + 8;
        colEnd = j + 8;

        if (rowEnd > N) rowEnd = N;
        if (colEnd > M) colEnd = M;

        for (ii = i; ii < rowEnd; ii += 4) {
          for (jj = j; jj < colEnd; jj += 4) {
            for (k = ii; k < (ii + 4 > rowEnd ? rowEnd : ii + 4); k++) {
              for (l = jj; l < (jj + 4 > colEnd ? colEnd : jj + 4); l++) {
                  B[l][k] = A[k][l];
              }
            }
          }
        }
      }
    }
}

char trans8_desc[] = "8x8 split into 4x4 blocks with registers";
void trans8(int M, int N, int A[N][M], int B[M][N])
{
    int i, j, k, l;
    int ii, jj;
    int rowEnd, colEnd;
    int t0, t1, t2, t3;

    for (i = 0; i < N; i += 8) {
      for (j = 0; j < M; j += 8) {
        rowEnd = i + 8;
        colEnd = j + 8;

        if (rowEnd > N) rowEnd = N;
        if (colEnd > M) colEnd = M;

        for (ii = i; ii < rowEnd; ii += 4) {
          for (jj = j; jj < colEnd; jj += 4) {
            if (jj + 3 > colEnd) {
              for (k = ii; k < (ii + 4 > rowEnd ? rowEnd : ii + 4); k++) {
                for (k = ii; k < (ii + 4 > rowEnd ? rowEnd : ii + 4); k++) {
                  t0 = A[k][jj];
                  t1 = A[k][jj + 1];
                  t2 = A[k][jj + 2];
                  t3 = A[k][jj + 3];

                  B[jj][k] = t0;
                  B[jj + 1][k] = t1;
                  B[jj + 2][k] = t2;
                  B[jj + 3][k] = t3;
                }
              }
            } else {
              for (k = ii; k < (ii + 4 > rowEnd ? rowEnd : ii + 4); k++) {
                for (l = jj; l < colEnd; l++) {
                    B[l][k] = A[k][l];
                }
              }
            }
          }
        }
      }
    }
}

/* 
 * transpose_submit - This is the solution transpose function that you
 *     will be graded on for Part B of the assignment. Do not change
 *     the description string "Transpose submission", as the driver
 *     searches for that string to identify the transpose function to
 *     be graded. 
 */
char transpose_submit_desc[] = "Transpose submission";
void transpose_submit(int M, int N, int A[N][M], int B[M][N])
{
  if (M == 32 && N == 32) {
    trans3(M, N, A, B);
  } else if (M == 64 && N == 64) {
    trans7(M, N, A, B);
  } else {
    trans4(M, N, A, B);
  }
}


/*
 * registerFunctions - This function registers your transpose
 *     functions with the driver.  At runtime, the driver will
 *     evaluate each of the registered functions and summarize their
 *     performance. This is a handy way to experiment with different
 *     transpose strategies.
 */
void registerFunctions()
{
    /* Register your solution function */
    registerTransFunction(transpose_submit, transpose_submit_desc); 

    /* Register any additional transpose functions */
    registerTransFunction(trans, trans_desc); 
    registerTransFunction(trans2, trans2_desc);
    registerTransFunction(trans3, trans3_desc);
    registerTransFunction(trans4, trans4_desc);
    registerTransFunction(trans5, trans5_desc);
    registerTransFunction(trans6, trans6_desc);
    registerTransFunction(trans7, trans7_desc);
    registerTransFunction(trans8, trans8_desc);

}

/* 
 * is_transpose - This helper function checks if B is the transpose of
 *     A. You can check the correctness of your transpose by calling
 *     it before returning from the transpose function.
 */
int is_transpose(int M, int N, int A[N][M], int B[M][N])
{
    int i, j;

    for (i = 0; i < N; i++) {
        for (j = 0; j < M; ++j) {
            if (A[i][j] != B[j][i]) {
                return 0;
            }
        }
    }
    return 1;
}

