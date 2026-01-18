"""
Semi-auto PDF -> line-band images extractor (improved for Arabic diacritics / تشكيل).

How it works:
- Renders each PDF page to an image
- Converts to grayscale and binarizes (ink vs background)
- (NEW) Optionally dilates ink mask vertically to keep diacritics attached
- Computes horizontal "ink density" per row
- Finds contiguous row segments = "line bands"
- Draws rectangles for detected bands

Controls:
- Click inside a rectangle -> selects it
- Enter        -> save selected rectangle crop
- Backspace    -> delete selected rectangle (won't be saved)
- m            -> manual crop: click TL then BR (saves immediately)
- r            -> re-run detection with current parameters
- [ / ]        -> decrease / increase sensitivity (threshold factor)
- - / +        -> decrease / increase minimum band height
- n / p        -> next / previous page
- q            -> quit

Dependencies:
  pip install pdf2image pillow matplotlib numpy
Poppler required:
  - Windows: install poppler, add bin to PATH OR pass --poppler
  - macOS: brew install poppler
  - Linux: sudo apt-get install poppler-utils
"""

import argparse
from pathlib import Path
from datetime import datetime

import numpy as np
import matplotlib.pyplot as plt
from PIL import Image
from pdf2image import convert_from_path


def ensure_dir(p: Path) -> None:
    p.mkdir(parents=True, exist_ok=True)


def render_pdf(pdf_path: Path, dpi: int, poppler_path: str | None):
    return convert_from_path(str(pdf_path), dpi=dpi, poppler_path=poppler_path)


def binarize(gray: np.ndarray, thr: int) -> np.ndarray:
    """Returns ink mask: True where pixel is 'ink' (dark)."""
    return gray < thr


def dilate_mask(mask: np.ndarray, ky: int = 7, kx: int = 1) -> np.ndarray:
    """
    Binary dilation (no OpenCV needed).
    This helps attach small diacritics above/below to the main line body.
    ky/kx should be positive integers; odd numbers are best.
    """
    ky = int(max(1, ky))
    kx = int(max(1, kx))
    py = ky // 2
    px = kx // 2

    m = np.pad(mask.astype(np.uint8), ((py, py), (px, px)), mode="constant")
    out = np.zeros_like(mask, dtype=np.uint8)

    # OR-shift windows
    H, W = mask.shape
    for dy in range(ky):
        for dx in range(kx):
            out |= m[dy:dy + H, dx:dx + W]

    return out.astype(bool)


def smooth_1d(x: np.ndarray, win: int) -> np.ndarray:
    if win <= 1:
        return x
    win = int(win)
    k = np.ones(win, dtype=np.float32) / win
    return np.convolve(x.astype(np.float32), k, mode="same")


def find_bands(density: np.ndarray, active_thr: float, min_h: int, merge_gap: int):
    """
    density: 1D array (rows) = ink density per row (0..1)
    active_thr: threshold on smoothed density to consider row "active"
    min_h: minimum height (rows) to keep a band
    merge_gap: if gap between bands <= merge_gap, merge them
    """
    active = density > active_thr
    bands = []
    h = len(active)
    i = 0
    while i < h:
        if not active[i]:
            i += 1
            continue
        start = i
        while i < h and active[i]:
            i += 1
        end = i  # exclusive
        if (end - start) >= min_h:
            bands.append([start, end])

    # merge close bands
    merged = []
    for b in bands:
        if not merged:
            merged.append(b)
            continue
        if b[0] - merged[-1][1] <= merge_gap:
            merged[-1][1] = b[1]
        else:
            merged.append(b)
    return merged


def clamp_box(x1, y1, x2, y2, w, h):
    x1, x2 = sorted([int(round(x1)), int(round(x2))])
    y1, y2 = sorted([int(round(y1)), int(round(y2))])
    x1 = max(0, min(x1, w - 1))
    x2 = max(0, min(x2, w))
    y1 = max(0, min(y1, h - 1))
    y2 = max(0, min(y2, h))
    if x2 <= x1 + 1:
        x2 = min(w, x1 + 2)
    if y2 <= y1 + 1:
        y2 = min(h, y1 + 2)
    return x1, y1, x2, y2


class AutoLineExtractor:
    def __init__(
        self,
        pages,
        out_dir: Path,
        base_name: str,
        ink_thr=200,
        smooth_win=25,
        active_factor=0.35,
        min_h=18,
        merge_gap=10,
        pad_y=18,
        pad_x=6,
        dilate_y=7,
        dilate_x=1,
    ):
        self.pages = pages
        self.out_dir = out_dir
        self.base_name = base_name

        # parameters
        self.ink_thr = ink_thr
        self.smooth_win = smooth_win
        self.active_factor = active_factor
        self.min_h = min_h
        self.merge_gap = merge_gap
        self.pad_y = pad_y
        self.pad_x = pad_x

        # NEW: dilation settings to catch tashkeel
        self.dilate_y = dilate_y
        self.dilate_x = dilate_x

        self.page_idx = 0
        self.rects = []      # list of (x1,y1,x2,y2)
        self.selected = None # index of selected rect
        self.manual_mode = False
        self.manual_clicks = []

        self.fig, self.ax = plt.subplots()
        self.fig.canvas.mpl_connect("button_press_event", self.on_click)
        self.fig.canvas.mpl_connect("key_press_event", self.on_key)

        self.load_page()

    def page_prefix(self):
        return f"{self.base_name}_page{self.page_idx+1:03d}"

    def load_page(self):
        self.ax.clear()
        pil = self.pages[self.page_idx]
        self.page_np = np.array(pil)

        if self.page_np.ndim == 3:
            gray = (
                0.299 * self.page_np[:, :, 0] +
                0.587 * self.page_np[:, :, 1] +
                0.114 * self.page_np[:, :, 2]
            ).astype(np.uint8)
        else:
            gray = self.page_np.astype(np.uint8)

        self.gray = gray
        self.h, self.w = gray.shape[:2]

        self.detect_rects()
        self.draw()

    def detect_rects(self):
        # 1) binarize
        ink = binarize(self.gray, self.ink_thr)

        # 2) NEW: dilate vertically so diacritics connect to text body
        if (self.dilate_y and self.dilate_y > 1) or (self.dilate_x and self.dilate_x > 1):
            ink = dilate_mask(ink, ky=max(1, int(self.dilate_y)), kx=max(1, int(self.dilate_x)))

        # 3) row density
        row_density = ink.mean(axis=1)
        row_s = smooth_1d(row_density, self.smooth_win)

        # 4) robust threshold (median + factor*(max-median))
        med = float(np.median(row_s))
        mx = float(np.max(row_s))
        active_thr = med + self.active_factor * (mx - med)

        bands = find_bands(
            row_s,
            active_thr=active_thr,
            min_h=self.min_h,
            merge_gap=self.merge_gap,
        )

        rects = []
        for (y1, y2) in bands:
            yy1 = max(0, y1 - self.pad_y)
            yy2 = min(self.h, y2 + self.pad_y)
            xx1 = 0 + self.pad_x
            xx2 = self.w - self.pad_x
            rects.append((xx1, yy1, xx2, yy2))

        self.rects = rects
        self.selected = 0 if rects else None
        self.manual_mode = False
        self.manual_clicks = []

    def draw(self):
        self.ax.clear()
        self.ax.imshow(self.page_np)
        self.ax.axis("off")

        title = (
            f"Page {self.page_idx+1}/{len(self.pages)} | "
            f"Rects: {len(self.rects)} | "
            f"[ ] sensitivity={self.active_factor:.2f} | "
            f"-/+ min_h={self.min_h} | "
            f"dilate_y={self.dilate_y} pad_y={self.pad_y} | "
            f"Enter=save  Backspace=delete  m=manual  r=redetect  n/p page  q quit"
        )
        if self.manual_mode:
            title = "MANUAL: click TOP-LEFT then BOTTOM-RIGHT (saves immediately) | Esc cancels"
        self.ax.set_title(title)

        for i, (x1, y1, x2, y2) in enumerate(self.rects):
            is_sel = (self.selected == i)
            lw = 3 if is_sel else 1.5
            rect = plt.Rectangle((x1, y1), x2 - x1, y2 - y1, fill=False, linewidth=lw)
            self.ax.add_patch(rect)
            self.ax.text(x1 + 4, y1 + 14, f"{i+1}", fontsize=10)

        self.fig.canvas.draw_idle()

    def save_rect(self, rect, tag="line"):
        x1, y1, x2, y2 = rect
        x1, y1, x2, y2 = clamp_box(x1, y1, x2, y2, self.w, self.h)

        crop = Image.fromarray(self.page_np[y1:y2, x1:x2])
        stamp = datetime.now().strftime("%Y%m%d_%H%M%S_%f")
        out_path = self.out_dir / f"{self.page_prefix()}_{tag}_{stamp}.png"
        crop.save(out_path)
        print(f"[SAVED] {out_path}")

    def pick_rect_by_point(self, x, y):
        for i, (x1, y1, x2, y2) in enumerate(self.rects):
            if x1 <= x <= x2 and y1 <= y <= y2:
                return i
        return None

    def on_click(self, event):
        if event.inaxes != self.ax or event.xdata is None or event.ydata is None:
            return
        x, y = float(event.xdata), float(event.ydata)

        if self.manual_mode:
            self.manual_clicks.append((x, y))
            if len(self.manual_clicks) == 2:
                (x1, y1), (x2, y2) = self.manual_clicks
                self.save_rect((x1, y1, x2, y2), tag="manual")
                self.manual_mode = False
                self.manual_clicks = []
                self.draw()
            return

        idx = self.pick_rect_by_point(x, y)
        if idx is not None:
            self.selected = idx
            self.draw()

    def on_key(self, event):
        key = (event.key or "").lower().strip()

        if key == "q":
            plt.close(self.fig)
            return

        if key == "n":
            if self.page_idx < len(self.pages) - 1:
                self.page_idx += 1
                self.load_page()
            return

        if key == "p":
            if self.page_idx > 0:
                self.page_idx -= 1
                self.load_page()
            return

        if key == "m":
            self.manual_mode = True
            self.manual_clicks = []
            self.draw()
            return

        if key == "escape":
            self.manual_mode = False
            self.manual_clicks = []
            self.draw()
            return

        if key == "r":
            self.detect_rects()
            self.draw()
            return

        if key == "[":
            self.active_factor = max(0.0, self.active_factor - 0.05)
            self.detect_rects()
            self.draw()
            return

        if key == "]":
            self.active_factor = min(1.0, self.active_factor + 0.05)
            self.detect_rects()
            self.draw()
            return

        if key == "-":
            self.min_h = max(2, self.min_h - 2)
            self.detect_rects()
            self.draw()
            return

        if key in ("+", "="):  # '=' is usually '+' without shift
            self.min_h = min(400, self.min_h + 2)
            self.detect_rects()
            self.draw()
            return

        # save selected
        if key in ("enter", "return"):
            if self.selected is not None and 0 <= self.selected < len(self.rects):
                self.save_rect(self.rects[self.selected], tag="line")
            return

        # delete selected
        if key in ("backspace", "delete"):
            if self.selected is not None and 0 <= self.selected < len(self.rects):
                del self.rects[self.selected]
                if not self.rects:
                    self.selected = None
                else:
                    self.selected = min(self.selected, len(self.rects) - 1)
                self.draw()
            return


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("pdf", help="Input PDF path")
    ap.add_argument("--out", default="out_lines_auto", help="Output folder")
    ap.add_argument("--dpi", type=int, default=250, help="Render DPI")
    ap.add_argument("--poppler", default=None, help="Poppler bin path (Windows often needs this)")
    ap.add_argument("--ink_thr", type=int, default=200, help="Grayscale threshold for ink (0..255)")

    # NEW tuning flags
    ap.add_argument("--pad_y", type=int, default=18, help="Vertical padding for each band crop")
    ap.add_argument("--pad_x", type=int, default=6, help="Horizontal padding for each band crop")
    ap.add_argument("--smooth_win", type=int, default=25, help="Smoothing window for row density")
    ap.add_argument("--active_factor", type=float, default=0.35, help="Sensitivity factor (median->max mix)")
    ap.add_argument("--min_h", type=int, default=18, help="Minimum band height in pixels/rows")
    ap.add_argument("--merge_gap", type=int, default=10, help="Merge adjacent bands if gap <= this")

    # NEW: dilation for diacritics
    ap.add_argument("--dilate_y", type=int, default=7, help="Vertical dilation kernel size (1 disables)")
    ap.add_argument("--dilate_x", type=int, default=1, help="Horizontal dilation kernel size")

    args = ap.parse_args()

    pdf_path = Path(args.pdf).expanduser().resolve()
    if not pdf_path.exists():
        raise FileNotFoundError(f"PDF not found: {pdf_path}")

    out_dir = Path(args.out).expanduser().resolve()
    ensure_dir(out_dir)

    print(f"[INFO] Rendering {pdf_path.name} at {args.dpi} DPI...")
    pages = render_pdf(pdf_path, dpi=args.dpi, poppler_path=args.poppler)
    print(f"[INFO] Pages: {len(pages)}")

    base_name = pdf_path.stem

    # Save full pages too (helpful for debugging)
    pages_dir = out_dir / f"{base_name}_pages"
    ensure_dir(pages_dir)
    for i, img in enumerate(pages, start=1):
        img.save(pages_dir / f"{base_name}_page{i:03d}.png")

    extractor = AutoLineExtractor(
        pages=pages,
        out_dir=out_dir,
        base_name=base_name,
        ink_thr=args.ink_thr,
        smooth_win=args.smooth_win,
        active_factor=args.active_factor,
        min_h=args.min_h,
        merge_gap=args.merge_gap,
        pad_y=args.pad_y,
        pad_x=args.pad_x,
        dilate_y=args.dilate_y,
        dilate_x=args.dilate_x,
    )

    plt.show()
    print("[DONE]")


if __name__ == "__main__":
    main()