#!/usr/bin/env python3
# Ashura: one JSON line for the dashboard's Performance tab (polled only while
# it is open): CPU name and temperature, GPU name/temperature/load (nvidia-smi),
# the real disks (not tmpfs, not /boot), network byte counters.
import json
import os
import shutil
import subprocess

def read(p, default=""):
    try:
        with open(p) as f:
            return f.read().strip()
    except OSError:
        return default

out = {}
for line in read("/proc/cpuinfo").splitlines():
    if line.startswith("model name"):
        out["cpu"] = line.split(":", 1)[1].strip().replace("(R)", "").replace("(TM)", "").replace(" CPU", "")
        break
for h in sorted(os.listdir("/sys/class/hwmon")):
    base = f"/sys/class/hwmon/{h}"
    if read(f"{base}/name") in ("coretemp", "k10temp", "zenpower"):
        t = read(f"{base}/temp1_input")
        if t:
            out["cpuTemp"] = round(int(t) / 1000)
        break
if shutil.which("nvidia-smi"):
    try:
        r = subprocess.run(["nvidia-smi", "--query-gpu=name,temperature.gpu,utilization.gpu",
                            "--format=csv,noheader,nounits"], capture_output=True, text=True, timeout=3)
        name, temp, util = [x.strip() for x in r.stdout.strip().splitlines()[0].split(",")]
        out["gpu"] = name.replace("NVIDIA ", "")
        out["gpuTemp"], out["gpuUsage"] = int(temp), int(util) / 100
    except Exception:
        pass
disks = []
for line in read("/proc/mounts").splitlines():
    dev, mnt, fs = line.split()[:3]
    if not dev.startswith("/dev/") or mnt.startswith("/boot") or fs in ("squashfs", "vfat"):
        continue
    try:
        st = os.statvfs(mnt)
    except OSError:
        continue
    total, free = st.f_blocks * st.f_frsize, st.f_bavail * st.f_frsize
    if total < 1 << 30:
        continue
    label = {"/": "Linux"}.get(mnt, os.path.basename(mnt) or mnt)
    if any(d["mount"] == mnt for d in disks):
        continue
    disks.append({"label": label, "mount": mnt, "total": total, "used": total - free})
out["disks"] = disks
rx = tx = 0
for line in read("/proc/net/dev").splitlines()[2:]:
    name, data = line.split(":", 1)
    if name.strip() == "lo":
        continue
    f = data.split()
    rx += int(f[0]); tx += int(f[8])
out["rx"], out["tx"] = rx, tx
print(json.dumps(out))
