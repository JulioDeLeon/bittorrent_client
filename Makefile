ERL_INCLUDE_PATH=/usr/lib/erlang/usr/include/
C_SRC=./c_src
C_LIB=./c_lib



peer_helper: $(C_SRC)/peer_helper.c
	gcc -fPIC -I$(ERL_INCLUDE_PATH) -shared -o $(C_LIB)/$@.so $(C_SRC)/$@.c

all: peer_helper

clean:
	rm $(C_LIB)/*.so
