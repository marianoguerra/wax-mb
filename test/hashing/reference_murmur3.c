/*
 * Hermetic conformance oracle for MurmurHash3 x86-32.
 *
 * The hash core follows Austin Appleby's public-domain reference source:
 * https://github.com/aappleby/smhasher/blob/master/src/MurmurHash3.cpp
 * The byte loading below is written explicitly so the oracle is portable to
 * hosts with different alignment requirements.
 */

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

static uint32_t rotl32(uint32_t value, int shift) {
  return (value << shift) | (value >> (32 - shift));
}

static uint32_t mix_k1(uint32_t value) {
  value *= UINT32_C(0xcc9e2d51);
  value = rotl32(value, 15);
  value *= UINT32_C(0x1b873593);
  return value;
}

static uint32_t fmix32(uint32_t value) {
  value ^= value >> 16;
  value *= UINT32_C(0x85ebca6b);
  value ^= value >> 13;
  value *= UINT32_C(0xc2b2ae35);
  value ^= value >> 16;
  return value;
}

static uint32_t murmur3_x86_32(const uint8_t *data, size_t length,
                               uint32_t seed) {
  uint32_t hash = seed;
  size_t offset = 0;
  while (offset + 4 <= length) {
    uint32_t word = (uint32_t)data[offset] |
                    ((uint32_t)data[offset + 1] << 8) |
                    ((uint32_t)data[offset + 2] << 16) |
                    ((uint32_t)data[offset + 3] << 24);
    hash ^= mix_k1(word);
    hash = rotl32(hash, 13);
    hash = hash * 5 + UINT32_C(0xe6546b64);
    offset += 4;
  }
  uint32_t tail = 0;
  switch (length - offset) {
  case 3:
    tail ^= (uint32_t)data[offset + 2] << 16;
    /* fall through */
  case 2:
    tail ^= (uint32_t)data[offset + 1] << 8;
    /* fall through */
  case 1:
    tail ^= data[offset];
    hash ^= mix_k1(tail);
    break;
  default:
    break;
  }
  return fmix32(hash ^ (uint32_t)length);
}

int main(void) {
  for (uint32_t case_index = 0; case_index < 512; case_index++) {
    size_t length = case_index % 257;
    uint8_t *data = malloc(length == 0 ? 1 : length);
    if (data == NULL) {
      return 2;
    }
    uint32_t state = UINT32_C(0x6d2b79f5) ^ case_index;
    for (size_t i = 0; i < length; i++) {
      state = state * UINT32_C(1664525) + UINT32_C(1013904223);
      data[i] = (uint8_t)(state >> 24);
    }
    uint32_t seed = case_index * UINT32_C(0x9e3779b9);
    printf("%08x\n", murmur3_x86_32(data, length, seed));
    free(data);
  }
  return 0;
}
