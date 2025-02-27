SHELL := /bin/bash

CC = c++
TARGET = ptr_chase
TARGET_ARRAYGEN = arraygen

CACHE_LINE ?= 64
PTRCHASE_NUM_INSTRUCTIONS ?= 40000000  # 10M instructions
PTRCHASE_NUM_ITERATIONS ?= 40000       # 10K iterations
PTRCHASE_ARRAY_SIZE = 134217728    # DRAM


# Architectural details
cache_line_size = ${CACHE_LINE}

# Benchmark configuration
array_size = ${PTRCHASE_ARRAY_SIZE}
instructions = ${PTRCHASE_NUM_INSTRUCTIONS}
iterations = ${PTRCHASE_NUM_ITERATIONS}

# Compute derived parameters
array_elems := $(shell echo "$(array_size) / $(cache_line_size)" | bc)
loop_instr := $(shell echo "$(instructions) / $(iterations)" | bc)

# Debug prints
$(info array_size = $(array_size))
$(info cache_line_size = $(cache_line_size))
$(info array_elems = $(array_elems))
$(info loop_instr = $(loop_instr))

all: ptr_chase array

ptr_chase: ptr_chase.c loop.h
	$(CC) -O0 -DARRAY_ELEMS=$(array_elems) -DITERS=$(iterations) -o $(TARGET) ptr_chase.c

loop.h: loop_template.h
	awk '{for(i=0; i<$(loop_instr); i++)print}' loop_template.h > loop.h

arraygen: arraygen.c
	$(CC) -O3 -DARRAY_ELEMS=$(array_elems) -o $(TARGET_ARRAYGEN) arraygen.c

array: arraygen
	./$(TARGET_ARRAYGEN)

clean:
	rm -f $(TARGET) $(TARGET_ARRAYGEN) loop.h

fullclean: clean
	rm -f array.dat

.PHONY: all array clean fullclean