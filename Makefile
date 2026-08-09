VERILATOR := verilator
VERILATOR_FLAGS := -Wall --trace-fst --Wno-fatal

RTL_DIR := target
RTL_SRCS = $(wildcard $(RTL_DIR)/*.sv)
TOP := tarunes_top
TB_CPP := src/tb_top.cpp
ROM_HEX ?= helloworld_prg.hex
CROM_HEX ?= helloworld_chr.hex
SDL_CFLAGS := $(shell sdl2-config --cflags)
SDL_LIBS := $(shell sdl2-config --libs)

all: build

veryl-fmt:
	veryl fmt

veryl-build: veryl-fmt
	veryl build

build: veryl-build
	$(VERILATOR) $(VERILATOR_FLAGS) \
		--cc $(RTL_SRCS) \
		--top-module $(TOP) \
		--exe $(TB_CPP) \
		-GPROM_PATH='"$(ROM_HEX)"' \
		-GCROM_PATH='"$(CROM_HEX)"' \
		-I$(RTL_DIR) \
		-CFLAGS "-std=c++17 $(SDL_CFLAGS)" \
		-LDFLAGS "$(SDL_LIBS)"
	$(MAKE) -C obj_dir -f V$(TOP).mk

run:
	./obj_dir/V$(TOP)

clean:
	rm -rf obj_dir *.fst tb_top

.PHONY: all build run clean veryl-fmt veryl-build
