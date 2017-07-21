UNAME := $(shell uname)

ifeq ($(UNAME), Darwin)
ERL_INCLUDE_PATH=/usr/local/Cellar/erlang/19.1/lib/erlang/usr/include/
CC=clang
CFLAGS := -undefined dynamic_lookup -dynamiclib -I$(ERL_INCLUDE_PATH)
else
ERL_INCLUDE_PATH=/usr/lib/erlang/usr/include/
CC=gcc
CFLAGS := -fPIC -shared -I$(ERL_INCLUDE_PATH)
endif
C_SRC=./c_src
C_LIB=./c_lib

.PHONY: all
all: configure \
		 torrent_worker_nif

torrent_worker_nif: $(C_SRC)/torrent_worker_nif.c
	$(CC) $(CFLAGS) -o $(C_LIB)/$@.so $(C_SRC)/$@.c


.PHONY: configure
configure:
ifeq (,$(findstring $(C_LIB),$(wildcard $(C_LIB) )))
	mkdir $(C_LIB)
endif

.PHONY: clean
clean:
	rm $(C_LIB)/*.so
