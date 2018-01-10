#ifndef PEER_HELPER_FUNCTION
#define PEER_HELPER_FUNCTION
#include <erl_nif.h>
#include <string.h>
#include <stdio.h>
#include <unistd.h>

typedef struct {
  char *bitfield;
  size_t size;
} bitfield;

int piece_is_in_bitfield(int piece_index, bitfield *bitfield)
{
  char *bits = malloc(sizeof(bitfield->bitfield));
  size_t size = sizeof(bitfield->bitfield);
  memcpy(bits, bitfield->bitfield, size);
  long num_of_pieces = sizeof(bitfield->bitfield) * 8;

  if (piece_index >= num_of_pieces) return 1;

  int byte_index = piece_index / 8;
  int bit_index = piece_index % 8;
  uint8_t num = power_of_num(2, bit_index);
  uint8_t get_byte = 0;
  memcpy(&get_byte, (char *)bits + byte_index, sizeof(char));

  if ((get_byte & num) != num) return 1;

  return 0;
}

int put_piece_into_bitfield(int piece_index, bitfield *bitfield) {
  if(piece_is_in_bitfield(piece_index, bitfield_t) == 0) return 1;
  int byte_index = piece_index/8;
  int bit_index = piece_index%8;

  uint8_t get_byte = 0;
  memcpy(&get_byte, (char*)bitfield_t->bitfield + byte_index, sizeof(char));
  uint8_t num = power_of_num(2, bit_index);
  get_byte = get_byte|num;

  memcpy((char*)bitfield_t->bitfield + byte_index, &get_byte, sizeof(char));
  return 0;
}

static ERL_NIF_TERM create_bitfield_from_lst(ErlNifEnv *env, int argc, const ERL_NIF_TERM arg[]) {
  bitfield *ret = malloc(sizeof(bitfield));

  for(int i = 0; i < length, i++){
    put_piece_into_bitfield(lst[i], bitfield);
  }
}

#endif PEER_HELPER_FUNCTION
