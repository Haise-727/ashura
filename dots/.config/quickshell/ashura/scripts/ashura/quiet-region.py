#!/usr/bin/env python3
"""Find the quietest (lowest-detail) region of an image.
# Ashura: from the first Ashura shell (~/rice); used by modules/ashura/desktopClock.

Used to place the desktop clock where it won't sit on top of busy artwork.
Prints: <anchor> <x> <y> <w> <h> <luma>
   e.g.  bottom-right 1420 780 460 220 0.18
<luma> is the mean brightness of the chosen region (0..1), so the caller can pick
readable text colour instead of assuming a dark wallpaper.

Pillow + numpy only - no OpenCV needed for per-region variance.
"""
import sys, numpy as np
from PIL import Image

GRID_X, GRID_Y = 4, 3          # candidate regions
DOWNSCALE = 320                # analyse small; detail survives, cost doesn't

def main(path, out_w=1920, out_h=1080):
    im = Image.open(path).convert("L")
    im.thumbnail((DOWNSCALE, DOWNSCALE))
    a = np.asarray(im, dtype=np.float32)
    h, w = a.shape

    best, best_score = None, None
    for gy in range(GRID_Y):
        for gx in range(GRID_X):
            y0, y1 = int(gy * h / GRID_Y), int((gy + 1) * h / GRID_Y)
            x0, x1 = int(gx * w / GRID_X), int((gx + 1) * w / GRID_X)
            tile = a[y0:y1, x0:x1]
            # local gradient magnitude = "business"; variance alone rates a smooth
            # gradient as busy, which it is not.
            gy_, gx_ = np.gradient(tile)
            score = float(np.mean(np.abs(gy_) + np.abs(gx_)))
            # gently prefer corners - a clock centred on the image looks wrong
            edge_bonus = 0.0
            if gx in (0, GRID_X - 1): edge_bonus -= 0.15
            if gy in (0, GRID_Y - 1): edge_bonus -= 0.15
            score += edge_bonus * score
            if best_score is None or score < best_score:
                best_score, best = score, (gx, gy)

    gx, gy = best
    # mean brightness of the winning region, for text-contrast selection
    y0, y1 = int(gy * h / GRID_Y), int((gy + 1) * h / GRID_Y)
    x0, x1 = int(gx * w / GRID_X), int((gx + 1) * w / GRID_X)
    luma = float(np.mean(a[y0:y1, x0:x1])) / 255.0

    rw, rh = out_w // GRID_X, out_h // GRID_Y
    x, y = gx * rw, gy * rh
    anchor = ("top" if gy == 0 else "bottom" if gy == GRID_Y - 1 else "middle") + "-" + \
             ("left" if gx == 0 else "right" if gx == GRID_X - 1 else "centre")
    print(f"{anchor} {x} {y} {rw} {rh} {luma:.3f}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit("usage: quiet-region <image> [screen_w screen_h]")
    main(sys.argv[1], *(int(v) for v in sys.argv[2:4]) if len(sys.argv) >= 4 else (1920, 1080))
