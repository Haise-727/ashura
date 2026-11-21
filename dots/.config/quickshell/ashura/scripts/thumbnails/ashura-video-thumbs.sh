#!/usr/bin/env bash
# Ashura: freedesktop thumbnails for the videos in a folder, so the wallpaper
# picker's Live mode can show them. Same path rule as ThumbnailImage.qml:
#   ~/.cache/thumbnails/<size>/md5("file://" + path with each part
#   percent-encoded like JS encodeURIComponent).png
# Usage: ashura-video-thumbs.sh <directory> <normal|large|x-large|xx-large>
set -u
dir="${1:?directory}"
size_name="${2:-large}"
case "$size_name" in normal) px=128;; large) px=256;; x-large) px=512;; xx-large) px=1024;; *) px=256;; esac
cache="${XDG_CACHE_HOME:-$HOME/.cache}/thumbnails/$size_name"
mkdir -p "$cache"
shopt -s nullglob nocaseglob
files=("$dir"/*.{mp4,webm,mkv,mov,avi,ashura})
assets="$(cd "$(dirname "$0")/../.." && pwd)/assets/ashura/shaders"
total=${#files[@]}; n=0
for f in "${files[@]}"; do
    n=$((n + 1))
    real=$(readlink -f "$f")
    # The shell hashes the path as the folder model reports it (not resolved)
    hash=$(/usr/bin/python3 -c 'import sys,urllib.parse,hashlib;p=sys.argv[1];e="/".join(urllib.parse.quote(x,safe="-_.!~*'"'"'()") for x in p.split("/"));print(hashlib.md5(("file://"+e).encode()).hexdigest())' "$f")
    out="$cache/$hash.png"
    if [[ "$f" == *.ashura ]]; then      # shader wallpaper: use its shipped preview
        name=$(basename "$f" .ashura)
        [ -f "$out" ] || { magick "$assets/$name.png" -resize "${px}x${px}" "$out.part.png" 2>/dev/null && mv "$out.part.png" "$out"; }
    else
        # written to a temp name first: an interrupted run must not leave a
        # truncated PNG that the existence check would then keep forever
        [ -f "$out" ] || { ffmpegthumbnailer -i "$real" -o "$out.part.png" -s "$px" -t 15% >/dev/null 2>&1 && mv "$out.part.png" "$out"; }
    fi
    echo "PROGRESS $n/$total"
    echo "FILE $f"
done
