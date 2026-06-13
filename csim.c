#include "cachelab.h"
#include <stdio.h>
#include <getopt.h>
#include <stdlib.h>
#include <unistd.h>

typedef struct {
    int valid;
    unsigned long tag;
    int lastUsed;
} CacheLine;

// 내부에서만 사용할 때는 static 붙이는 것이 좋음
static CacheLine **cache;

static int s = -1;
static int E = -1;
static int b = -1;
static int verbose = 0;
static char *traceFile = NULL;

static int hitCount = 0;
static int missCount = 0;
static int evictionCount = 0;

static void printHint(void) {
  printf(
    "Usage: ./csim [-hv] -s <num> -E <num> -b <num> -t <file>\n"
    "Options:\n"
    "  -h         Print this help message.\n"
    "  -v         Optional verbose flag.\n"
    "  -s <num>   Number of set index bits.\n"
    "  -E <num>   Number of lines per set.\n"
    "  -b <num>   Number of block offset bits.\n"
    "  -t <file>  Trace file.\n"
    "\n"
    "Examples:\n"
    "  linux> ./csim -s 4 -E 1 -b 4 -t traces/yi.trace\n"
    "  linux> ./csim -v -s 8 -E 2 -b 4 -t traces/yi.trace\n"
  );
}

static void accessCache(unsigned long address) {
  static int currentTime = 0; // 전역변수인데 이 함수에서 밖에 안 씀
  currentTime++;

  // address >> b : offset 버리기
  // (1 << s) - 1 : 마스크 만들기 (1을 set 비트수만큼 왼쪽으로 밀기->뒤에 set 비트수만 남기기 위해서 마스크로 만들기 위해 1 빼기)
  // ex) 0x110=0001|0001|0000, b=4, s=4, 1<<s=10000 여기에 1을 빼면 01111
  // 두 계산식으로 AND하면 setIndex만 추출 가능. 00010001 & 00001111 = 000000001
  unsigned long setIndex = (address >> b) & ((1UL << s) - 1);
  unsigned long tag = address >> (s + b);

  // printf("set=%lu tag=%lu\n", setIndex, tag);

  // 같은 setIndex 내 tag 비교하기
  CacheLine *lines = cache[setIndex];
  int isHit = 0;
  int isStored = 0;

  for (int i = 0; i < E; i++) {
    // hit인 경우
    if (lines[i].valid && lines[i].tag == tag) {
      hitCount++;
      isHit = 1;
      lines[i].lastUsed = currentTime;
      break;
    }
  }
  if (isHit) {
    return;
  }

  // miss인 경우, 먼저 빈 라인을 찾아서 저장
  missCount++;
  for (int i = 0; i < E; i++) {
    if (!lines[i].valid) {
      lines[i].valid = 1;
      lines[i].tag = tag;
      lines[i].lastUsed = currentTime;
      isStored = 1;
      break;
    }
  }
  if (isStored) {
    return;
  }

  // 빈라인이 없는 경우 -> LRU: 가장 오래전에 사용된 line 찾아 초기화하고 새로 저장
  int lruIndex = 0;
  int oldestLastUsed = lines[0].lastUsed;

  for (int i = 1; i < E; i++) {
    if (lines[i].lastUsed < oldestLastUsed) {
      oldestLastUsed = lines[i].lastUsed;
      lruIndex = i;
    }
  }

  // 가장 오래된 line을 새 block으로 교체
  lines[lruIndex].tag = tag;
  lines[lruIndex].lastUsed = currentTime;
  evictionCount++;
}

int main(int argc, char *argv[])
{
  int opt;
  char line[100];

  // getopt: 옵션 순서와 개수를 처리
  while ((opt = getopt(argc, argv, "hvs:E:b:t:")) != -1) {
    switch (opt) {
      case 'h':
        printHint();
        return 0;
      case 'v':
        verbose = 1;
        break;
      case 's':
        s = atoi(optarg);
        break;
      case 'E':
        E = atoi(optarg);
        break;
      case 'b':
        b = atoi(optarg);
        break;
      case 't':
        traceFile = optarg;
        break;
      default:
        printHint();
        return 1;
    }
  }

  if (s < 0 || E < 0 || b < 0 || traceFile == NULL) {
    printf("./csim: Missing required command line argument\n");
    printHint();
    return 1;
  }

  // printf("s=%d E=%d b=%d t=%s v=%d\n", s, E, b, traceFile, verbose);

  FILE *fp = fopen(traceFile, "r");
  if (fp == NULL) {
    printf("%s: No such file or directory", traceFile);
    return 1;
  }

  int S = 1 << s; // set의 개수. S = 2^s

  // 캐시 메모리 할당,  Java에서 CacheLine[][] cache
  // 연속된 메모리에 있다고 가정할 수 없음
  cache = malloc(sizeof(CacheLine *) * S); // S 개의 set 포인터 배열
  for (int i = 0; i < S; i++) {
    cache[i] = malloc(sizeof(CacheLine) * E); // 각 set의 line 배열
  }
  // 초기화
  for (int i = 0; i < S; i++) {
    for (int j = 0; j < E; j++) {
      cache[i][j].valid = 0;
      cache[i][j].tag = 0;
      cache[i][j].lastUsed = 0;
    }
  }

  while (fgets(line, sizeof(line), fp) != NULL) {
    char op;
    unsigned long address;
    int size;

    // %c  → L/M/S/I 같은 문자, %lx → 16진수 주소를 unsigned long으로 읽기, %d  → size
    sscanf(line, " %c %lx,%d", &op, &address, &size);
    // printf("op=%c, address=%lx, size=%d\n", op, address, size);

    // I는 무시하라고 명시되어 있음
    if (op == 'I') {
      continue;
    } 

    accessCache(address);

    // M = load + store => 캐시 접근이 2번
    if (op == 'M') {
      accessCache(address);
    }
  }

  printSummary(hitCount, missCount, evictionCount);

  fclose(fp);
  for (int i = 0; i < S; i++) {
    free(cache[i]);
  }
  free(cache);

  return 0;
}
