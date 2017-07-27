#include "erl_nif.h"
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

/*
  https://github.com/lita/bittorrent/blob/master/peers.py
  python example
  for chunk in self.chunkToSixBytes(response):
  ip = []
  port = None
  for i in range(0, 4):
  ip.append(str(ord(chunk[i])))

  port = ord(chunk[4])*256+ord(chunk[5])
  mySocket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
  mySocket.setblocking(0)
  ip = '.'.join(ip)
  peer = Peer(ip, port, mySocket, self.infoHash, self.peer_id)
  self.peers.append(peer)

  example: <<78, 132, 52, 74, 192, 8>>
*/

static ERL_NIF_TERM
get_peer_connection_info(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]){
  //load the passed binary
  int binary_size;
  ErlNifBinary temp_bin;
  char* ipBuff = (char*) malloc(sizeof(char) * 8);
  memset(ipBuff, '.', sizeof(char) * 8);
  int portBuff = 0;
  if( !enif_get_int(env, argv[1], &binary_size)
      || !enif_inspect_binary(env, argv[0], &temp_bin)) {
    return enif_make_badarg(env);
  }

  //Get IP
  for(int x = 0; x < binary_size + 4; x+2) {
    //printf("%d:%c\n", x, temp_bin.data[x]);
    ipBuff[x] = temp_bin.data[x];
  }

  //Get Port
  portBuff = atoi((const char *) &temp_bin.data[4]) * 256 + atoi((const char*) &temp_bin.data[5]);

  //return tuple {ip, port}
  ERL_NIF_TERM retIP = enif_make_string(env, ipBuff, ERL_NIF_LATIN1);
  ERL_NIF_TERM retPort = enif_make_uint(env, portBuff);
  free(ipBuff);
  return enif_make_tuple(env, 2, retIP, retPort);
}

static ErlNifFunc nif_funcs[] = {
  {"get_peer_connection_info", 2, get_peer_connection_info}
};

//ERL_NIF_INIT(__MODULE__, ErlNifFunc* arr, void* load_func, void* upgrade_func, void* unload_func, void* reload_func)
ERL_NIF_INIT(Elixir.BittorrentClient.Torrent.Worker, nif_funcs, NULL,NULL,NULL,NULL)

