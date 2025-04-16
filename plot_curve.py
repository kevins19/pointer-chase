#!/usr/bin/env python3
import sys, re
import pandas as pd
import matplotlib.pyplot as plt

def conv_bytes(val, unit):
    v = float(val)
    u = unit.upper()
    if "KB" in u: return v * 1024
    if "MB" in u: return v * 1024 * 1024
    if "GB" in u: return v * 1024 * 1024 * 1024
    return v

def parse_stats(fn):
    with open(fn) as f: txt = f.read()
    m = re.search(r'Cache Line Size:\s*(\d+)', txt, re.IGNORECASE)
    cache_line = int(m.group(1)) if m else 64
    stats = {'cache_line': cache_line}
    for lvl in ['L1','L2','L3']:
        m = re.search(r'^%s:\s*([\d\.]+)\s*([KMG]B).*?(\d+)\s*instances' % lvl,
                      txt, re.IGNORECASE | re.MULTILINE)
        stats[lvl] = conv_bytes(m.group(1), m.group(2)) / int(m.group(3)) if m else None
    return stats

if len(sys.argv) != 2:
    print(f"Usage: {sys.argv[0]} <machine_id>")
    sys.exit(1)

mid = sys.argv[1]
stats_file = f"stats_{mid}.txt"
csv_file   = f"curve_results_{mid}.csv"

stats = parse_stats(stats_file)
df = pd.read_csv(csv_file)

plt.plot(df['ArraySize'], df['latency'], marker='o', label="Measured Latency")
plt.xscale('log')
plt.xlabel("Memory Size (bytes)")
plt.ylabel("Latency (ns)")
for lvl in ['L1', 'L2', 'L3']:
    if stats[lvl]:
        plt.axvline(x=stats[lvl], linestyle='--', label=f"{lvl} Limit ({int(stats[lvl])} bytes)")
plt.legend()
plt.tight_layout()
plt.show()
