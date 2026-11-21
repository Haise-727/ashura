#!/usr/bin/env bash
# Push the repo's Hyprland and shell config to the live desktop after
# ashura/install.sh has run once. Copies only files the repo owns and never
# deletes anything; files that are generated or rewritten at runtime are left
# alone (wallpaper colours, the 12/24 h lock clock, video-wallpaper restore).
# Then Hyprland reloads; the shell reloads itself when its files change.
#
#   ashura/sync.sh            copy + reload
#   ashura/sync.sh --dry-run  list what would change
set -euo pipefail
REPO="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
DOTS="$REPO/dots/.config"
DRY=()
[ "${1:-}" = "--dry-run" ] && DRY=(--dry-run)

# Never while the session is locked: the shell reloads when its files change,
# and a reload under the lock drops the lock screen (Hyprland then shows
# "lockscreen died"). Learned the hard way on 2026-11-09.
if [ ${#DRY[@]} -eq 0 ] && hyprctl monitors -j 2>/dev/null | grep -q '"LOCK"'; then
    echo "session is locked; not syncing (unlock first)" >&2
    exit 1
fi

EXCLUDES=(
    --exclude 'hyprland/colors.lua'
    --exclude 'hyprlock/colors.conf'
    --exclude 'hyprlock.conf'
    --exclude 'custom/scripts/__restore_video_wallpaper.sh'
    --exclude 'custom/scripts/mpvpaper_thumbnails'
    --exclude 'monitors.lua'
)
rsync -a --itemize-changes "${DRY[@]}" "${EXCLUDES[@]}" "$DOTS/hypr/" "$HOME/.config/hypr/"
rsync -a --itemize-changes "${DRY[@]}" "$DOTS/quickshell/ashura/" "$HOME/.config/quickshell/ashura/"
[ ${#DRY[@]} -eq 0 ] && hyprctl reload >/dev/null && echo "synced; Hyprland reloaded"
true
