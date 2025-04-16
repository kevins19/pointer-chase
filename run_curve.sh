#!/bin/bash

# usage: ./run_curve.sh x
# x is machine id

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

cache_line_config=$(grep -i "^Cache Line Size:" "$STATS_FILE" | awk -F: '{print $2}' | xargs)
if [ -z "$cache_line_config" ]; then
    echo "Cache Line Size not specified in $STATS_FILE, using default 64"
    cache_line_config=64
fi
echo "Configured cache line size: $cache_line_config"
sed -i.bak -E "s/^(CACHE_LINE\s*\?*=).*/CACHE_LINE = $cache_line_config    # from config/" Makefile

# memory range of latency curve
MIN_EXP=10   # 2^10 = 1KB
MAX_EXP=29   # 2^29 = 128MB

csv_file="curve_results_${MACHINE_ID}.csv"
echo "Power,ArraySize,latency,cycles,freq,instructions" > "$csv_file"

for power in $(seq $MIN_EXP $MAX_EXP); do
    size=$((2**power))
    echo ">>> Running pointer chase with PTRCHASE_ARRAY_SIZE = $size (2^$power bytes)"
    
    sed -i.bak -E "s/^(PTRCHASE_ARRAY_SIZE\s*\?*=).*/PTRCHASE_ARRAY_SIZE = $size    # power of two $power/" Makefile
    
    make clean
    make
    echo "  --> Executing test for 2^$power ($size bytes)"
    output=$(numactl -C 0 -m 0 ./ptr_chase 2>&1)
    
    array_size=$(echo "$output" | grep -oP 'array_bytes:\s*\K\S+')
    instructions=$(echo "$output" | grep -oP 'instructions:\s*\K\S+')
    freq=$(echo "$output" | grep -oP 'freq:\s*\K\S+')
    latency=$(echo "$output" | grep -oP 'mem latency is.*?:\s*\K[0-9.]+(?=ns)')
    cycles=$(echo "$output" | grep -oP '\K[0-9]+(?= cycles)')
    
    echo "$power,$array_size,$latency,$cycles,$freq,$instructions" >> "$csv_file"
    
    echo "$output"
done

echo "Latency curve evaluation complete. Results logged in $csv_file"
