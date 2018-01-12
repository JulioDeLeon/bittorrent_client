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
all: niftest_nif \
     binaries_example

niftest_nif: $(C_SRC)/niftest_nif.c
	$(CC) $(CFLAGS) -o $(C_LIB)/$@.so $(C_SRC)/$@.c

binaries_example: $(C_SRC)/binaries_example.c
	$(CC) $(CFLAGS) -o $(C_LIB)/$@.so $(C_SRC)/$@.c


.PHONY: clean
clean:
rm $(C_LIB)/*.s
