#include "erl_nif.h"
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

//Some functions i have defined to help handle peer information

/*
  from Elixir:
  get_peer_connection_info :: Bitstring -> Int -> Bitstring
  takes a byte array from elixir, parses to create strings which rep ips and ports for each client
 */
static ERL_NIF_TERM
get_peer_connection_info(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]){
  int size;
  unsigned char* bin_term;
  enif_get_int(env, argv[1], &size);
  bin_term = enif_make_new_binary(env, size, )
  return enif_make_string(env, "ret", ERL_NIF_LATIN1);
}

static ErlNifFunc nif_funcs[] = {
  {"get_peer_connection_info", 2, get_peer_connection_info}
};

//ERL_NIF_INIT(__MODULE__, ErlNifFunc* arr, void* load_func, void* upgrade_func, void* unload_func, void* reload_func)
ERL_NIF_INIT(Elixir.BittorrentClient.Torrent.Worker, nif_funcs, NULL,NULL,NULL,NULL)
