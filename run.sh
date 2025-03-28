#!/bin/bash

# usage: ./run.sh x
# x is machine id
# This script gathers latency measurements for all levels of memory.
# Fill in the `stats_{machine}.txt` with appropriate cache sizes before running.

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <machine_id>"
    echo "Example: $0 81  (will use stats_81.txt)"
    exit 1
fi

MACHINE_ID="$1"
STATS_FILE="stats_${MACHINE_ID}.txt"

if [ ! -f "$STATS_FILE" ]; then
    echo "Error: Stats file '$STATS_FILE' not found!"
    exit 1
fi

# parse cache line size
cache_line_config=$(grep -i "^Cache Line Size:" "$STATS_FILE" | awk -F: '{print $2}' | xargs)
if [ -z "$cache_line_config" ]; then
    echo "Cache Line Size not specified in $STATS_FILE, using default 64"
    cache_line_config=64
fi
echo "Configured cache line size: $cache_line_config"
sed -i.bak -E "s/^(CACHE_LINE\s*\?*=).*/CACHE_LINE = $cache_line_config    # from config/" Makefile


# func to parse cache information from stats.txt
parse_cache() {
    local level="$1"
    local line
    line=$(grep -i "^${level}:" "$STATS_FILE")
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

    local total_bytes=$(awk -v n="$number" -v m="$multiplier" 'BEGIN {printf "%d", n*m}')

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

configs=("L1" "L2" "L3" "DRAM")
sizes=("$L1_ptr_size" "$L2_ptr_size" "$L3_ptr_size" "$DRAM_ptr_size")

csv_file="results_${MACHINE_ID}.csv"

# echo "Configuration,Iteration,Array size,latency,cycles,miss_dltb_hit_stlb,active_page_walk_cycles,freq,instructions" > "$csv_file"
echo "Configuration,Iteration,Array size,latency,cycles,freq,instructions" > "$csv_file"

for index in "${!configs[@]}"; do
    config="${configs[$index]}"
    size="${sizes[$index]}"

    echo ">>> Running configuration: $config with PTRCHASE_ARRAY_SIZE = $size"
    
    sed -i.bak -E "s/^(PTRCHASE_ARRAY_SIZE\s*\?*=).*/PTRCHASE_ARRAY_SIZE = $size    # $config/" Makefile
    
    for i in {1..10}; do
        make clean
        make
        echo "  --> Test iteration $i for $config"
        output=$(numactl -C 0 -m 0 ./ptr_chase 2>&1)
        
        array_size=$(echo "$output" | grep -oP 'array_bytes:\s*\K\S+')
        instructions=$(echo "$output" | grep -oP 'instructions:\s*\K\S+')
        freq=$(echo "$output" | grep -oP 'freq:\s*\K\S+')
        latency=$(echo "$output" | grep -oP 'mem latency is.*?:\s*\K[0-9.]+(?=ns)')
        cycles=$(echo "$output" | grep -oP '\K[0-9]+(?= cycles)')
        
        echo "$config,$i,$array_size,$latency,$cycles,$freq,$instructions" >> "$csv_file"

        echo $output
    done
done

echo "Benchmarking complete. Results logged in $csv_file"
