#!/usr/bin/env python3

import pandas as pd
import matplotlib.pyplot as plt
import glob
import re
import os

data_dir = "."

core_counts = {
    "denali": 48,
    "61": 64,
    "71": 128,
    "81": 256
}

csv_files = glob.glob(os.path.join(data_dir, "curve_results_*.csv"))

plot_lines = []
labels = []
cores_for_sorting = []

plt.figure(figsize=(10, 6))

for file_path in csv_files:
    match = re.search(r"curve_results_(.*)\.csv", os.path.basename(file_path))
    if not match:
        continue
    machine_id = match.group(1)
    cores = core_counts.get(machine_id, None)
    if cores is None:
        continue

    label = f"{machine_id} ({cores} cores)"
    df = pd.read_csv(file_path)
    if "ArraySize" in df.columns and "latency" in df.columns:
        line, = plt.plot(df["ArraySize"], df["latency"])
        plot_lines.append(line)
        labels.append(label)
        cores_for_sorting.append(cores)

sorted_data = sorted(zip(cores_for_sorting, labels, plot_lines), reverse=True)
sorted_labels = [lbl for _, lbl, _ in sorted_data]
sorted_lines = [ln for _, _, ln in sorted_data]

plt.xscale('log')
plt.xlabel("Array Size (log scale)")
plt.ylabel("Latency (ns)")
plt.title("Latency vs Array Size Across Machines")
plt.legend(sorted_lines, sorted_labels, title="Machine (Cores)")
plt.grid(True, which='both', linestyle='--', linewidth=0.5)
plt.tight_layout()
plt.savefig("./plots/all_plots.png")
