#!/usr/bin/env python3
# Ashura: the process table for the Apps list (services/AppUsage.qml), one line
# per process: "pid ppid cpu_seconds memory_kB command".
# Memory is PSS (proportional set size: shared pages split between the
# processes sharing them), not RSS. RSS counts every shared library and GPU
# mapping in full for each process, so a kitty showed ~350 MB and Firefox's
# tree several GB. PSS sums correctly over a process tree.
import os

tick = os.sysconf("SC_CLK_TCK")
out = []
for name in os.listdir("/proc"):
    if not name.isdigit():
        continue
    try:
        with open(f"/proc/{name}/stat") as f:
            stat = f.read()
        comm = stat[stat.index("(") + 1:stat.rindex(")")]
        rest = stat[stat.rindex(")") + 2:].split()
        ppid, cpu = rest[1], (int(rest[11]) + int(rest[12])) / tick
        pss = None
        try:
            with open(f"/proc/{name}/smaps_rollup") as f:
                for line in f:
                    if line.startswith("Pss:"):
                        pss = line.split()[1]
                        break
        except OSError:
            pass
        if pss is None:                       # not ours to read: fall back to RSS
            with open(f"/proc/{name}/statm") as f:
                pss = str(int(f.read().split()[1]) * os.sysconf("SC_PAGE_SIZE") // 1024)
        out.append(f"{name} {ppid} {cpu:.2f} {pss} {comm}")
    except (OSError, ValueError, IndexError):
        continue
print("\n".join(out))
