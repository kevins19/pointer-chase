#!/bin/bash
#SBATCH --job-name=hugepage_check
#SBATCH --output=hugepage_check.out
#SBATCH --error=hugepage_check.err
#SBATCH --time=00:05:00
#SBATCH --nodes=1
#SBATCH -w denali

echo "Job running on: $(hostname) at $(date)"
echo "=== Huge Page Information from /proc/meminfo ==="
grep -i huge /proc/meminfo
echo "=== End of Huge Page Information ==="
