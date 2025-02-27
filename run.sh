#!/bin/bash

# This script gathers latency measurements for all levels of memory.
# Fill in the `stats.txt` with appropriate cache sizes before running.

# func to parse cache information from stats.txt
parse_cache() {
    local level="$1"
    local line
    line=$(grep -i "^${level}:" stats.txt)
    if [ -z "$line" ]; then
        echo "0"
        return
    fi

    local data
    data=$(echo "$line" | sed -E "s/^${level}:[[:space:]]*//")

    local number
    number=$(echo "$data" | awk '{print $1}')
    local unit
    unit=$(echo "$data" | awk '{print $2}' | sed 's/,//')

    local multiplier=1
    if [[ "$unit" =~ ^K ]]; then
        multiplier=1024
    elif [[ "$unit" =~ ^M ]]; then
        multiplier=$((1024*1024))
    elif [[ "$unit" =~ ^G ]]; then
        multiplier=$((1024*1024*1024))
    fi

    local total_bytes=$(( number * multiplier ))

    local instances
    instances=$(echo "$data" | grep -oE '[0-9]+ instances' | awk '{print $1}')
    if [ -n "$instances" ] && [ "$instances" -gt 0 ]; then
        echo $(( total_bytes / instances ))
    else
        echo "$total_bytes"
    fi
}

L1_size=$(parse_cache "L1")
L2_size=$(parse_cache "L2")
L3_size=$(parse_cache "L3")

echo "Detected cache sizes (per instance in bytes):"
echo "L1: $L1_size, L2: $L2_size, L3: $L3_size"

L1_ptr_size=$(( L1_size / 2 ))
L2_ptr_size=$(( L2_size / 2 ))
L3_ptr_size=$(( L3_size / 2 ))
DRAM_ptr_size=$(( L3_size * 8 ))

echo "Computed PTRCHASE_ARRAY_SIZE values:"
echo "L1 test:   $L1_ptr_size"
echo "L2 test:   $L2_ptr_size"
echo "L3 test:   $L3_ptr_size"
echo "DRAM test: $DRAM_ptr_size"

declare -A tests
tests=( ["L1"]=$L1_ptr_size ["L2"]=$L2_ptr_size ["L3"]=$L3_ptr_size ["DRAM"]=$DRAM_ptr_size )

csv_file="results.csv"
echo "Configuration,Iteration,Array size,latency,TLB miss" > "$csv_file"

for config in "${!tests[@]}"; do
    size=${tests[$config]}
    echo ">>> Running configuration: $config with PTRCHASE_ARRAY_SIZE = $size"
    
    sed -i.bak -E "s/^(PTRCHASE_ARRAY_SIZE\s*\?*=).*/PTRCHASE_ARRAY_SIZE = $size    # $config/" Makefile
    
    make clean
    make
    for i in {1..10}; do
         echo "  --> Test iteration $i for $config"
         output=$(numactl -C 0 -m 0 perf stat -e L1-dcache-loads,L1-dcache-load-misses,L2-loads,L2-load-misses,LLC-loads,LLC-load-misses ./ptr_chase 2>&1)
         
         array_size=$(echo "$output" | grep -oP 'array_bytes:\s*\K\S+')
         latency=$(echo "$output" | grep -oP 'mem latency is.*?:\s*\K[0-9.]+(?=ns)')
         tlb_miss=$(echo "$output" | grep -oP '\K[0-9]+(?= tlb1missTLBmiss)')
         
         echo "$config,$i,$array_size,$latency,$tlb_miss" >> "$csv_file"
    done
done

echo "Benchmarking complete. Results logged in $csv_file"
