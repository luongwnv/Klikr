# Builds Support/AppIcon.icns from the real photo: the Corne half cut out of its background, no tile behind it.
# Usage: python3 tools/make_icon.py   (needs pillow, numpy, scipy and macOS iconutil)
import os, shutil, subprocess, tempfile
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage as nd

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
S = 1024
CONTENT = 880  # widest side of the keyboard inside the 1024 canvas


def clean_cutout(img):
    """Icon-grade mask: drop wood showing through gaps at the edge, specks, and jagged outline."""
    rgb = np.asarray(img.convert('RGB')).astype(float)
    solid = np.asarray(img.getchannel('A')) > 127
    mx, mn = rgb.max(axis=2), rgb.min(axis=2)
    warm = ((mx - mn) / np.maximum(mx, 1) > 0.12) & (rgb[..., 0] > rgb[..., 2] + 10) & (mx < 215)
    # Warm pixels joined to the transparent outside are background; warm details inside (logos) are kept
    lab, _ = nd.label(warm | ~solid)
    border = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
    fg = solid & ~np.isin(lab, border[border > 0])
    fg = nd.binary_opening(fg, iterations=7)  # also drops thin slivers of the case frame
    # Keep every sizeable piece (loose keycaps included), drop specks
    lab, n = nd.label(fg)
    sizes = nd.sum(fg, lab, range(1, n + 1))
    fg = np.isin(lab, [i + 1 for i, v in enumerate(sizes) if v > 0.005 * fg.size])
    fg = nd.binary_fill_holes(fg)
    smooth = nd.gaussian_filter(fg.astype(float), 2.0) > 0.5
    alpha = Image.fromarray((smooth * 255).astype('uint8')).filter(ImageFilter.GaussianBlur(0.8))
    out = img.copy()
    out.putalpha(alpha)
    return out


def build():
    kb = clean_cutout(Image.open(os.path.join(ROOT, 'layouts/corne-skin/left.png')).convert('RGBA'))
    kb = kb.crop(kb.getbbox())
    scale = CONTENT / max(kb.width, kb.height)
    kb = kb.resize((round(kb.width * scale), round(kb.height * scale)), Image.Resampling.LANCZOS)
    x, y = (S - kb.width) // 2, (S - kb.height) // 2 - 12

    canvas = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    # Soft contact shadow so the cut-out sits on Finder, Launchpad and the Dock without a backdrop
    shadow = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    sh = Image.new('RGBA', kb.size, (0, 0, 0, 0))
    sh.putalpha(kb.getchannel('A').point(lambda v: v * 110 // 255))
    shadow.paste(sh, (x, y + 18), sh)
    shadow = shadow.filter(ImageFilter.GaussianBlur(16))
    canvas = Image.alpha_composite(canvas, shadow)
    canvas.alpha_composite(kb, (x, y))
    return canvas


def menu_template(height_pt=18):
    """Black-on-transparent template of the same cut-out for the menu bar: light keycaps solid, gaps clear."""
    kb = clean_cutout(Image.open(os.path.join(ROOT, 'layouts/corne-skin/left.png')).convert('RGBA'))
    kb = kb.crop(kb.getbbox())
    lum = nd.gaussian_filter(np.asarray(kb.convert('L')).astype(float), 1.0)
    mask = np.asarray(kb.getchannel('A')) > 127
    # Keycaps solid (legends filled in, gaps to the outside stay open), plus a ~1pt rim for the silhouette
    keys = nd.binary_fill_holes((lum > 150) & mask)
    keys = nd.binary_opening(keys, iterations=2)
    px_per_pt = kb.height / height_pt
    rim = mask & ~nd.binary_erosion(mask, iterations=max(1, round(px_per_pt * 0.9)))
    solid = keys | rim
    mono = Image.new('RGBA', kb.size, (0, 0, 0, 0))
    mono.putalpha(Image.fromarray((solid * 255).astype('uint8')))
    out = {}
    for scale in (1, 2):
        h = height_pt * scale
        w = round(kb.width * h / kb.height)
        out[scale] = mono.resize((w, h), Image.Resampling.LANCZOS)
    return out


def menu_photo(height_pt=18):
    """The real keyboard for the menu bar, in grayscale, with a faint rim so it holds up on light bars."""
    kb = clean_cutout(Image.open(os.path.join(ROOT, 'layouts/corne-skin/left.png')).convert('RGBA'))
    kb = kb.crop(kb.getbbox())
    alpha = kb.getchannel('A')
    gray = kb.convert('L').point(lambda v: min(255, int(v * 1.05)))
    mask = np.asarray(alpha) > 127
    px_per_pt = kb.height / height_pt
    rim = mask & ~nd.binary_erosion(mask, iterations=max(1, round(px_per_pt * 0.6)))
    g = np.asarray(gray).copy()
    g[rim] = (g[rim] * 0.45).astype('uint8')
    photo = Image.merge('RGBA', [Image.fromarray(g)] * 3 + [alpha])
    out = {}
    for scale in (1, 2):
        h = height_pt * scale
        out[scale] = photo.resize((round(kb.width * h / kb.height), h), Image.Resampling.LANCZOS)
    return out


def main():
    for scale, img in menu_template().items():
        img.save(os.path.join(ROOT, 'Support', 'MenuTemplate.png' if scale == 1 else 'MenuTemplate@2x.png'))
    for scale, img in menu_photo().items():
        img.save(os.path.join(ROOT, 'Support', 'MenuIcon.png' if scale == 1 else 'MenuIcon@2x.png'))
    icon = build()
    icon.save(os.path.join(ROOT, 'Support/AppIcon.png'))
    tmp = tempfile.mkdtemp()
    iconset = os.path.join(tmp, 'AppIcon.iconset')
    os.makedirs(iconset)
    for size in (16, 32, 128, 256, 512):
        for mult in (1, 2):
            px = size * mult
            name = f'icon_{size}x{size}' + ('@2x' if mult == 2 else '') + '.png'
            icon.resize((px, px), Image.Resampling.LANCZOS).save(os.path.join(iconset, name))
    subprocess.run(['iconutil', '-c', 'icns', iconset, '-o', os.path.join(ROOT, 'Support/AppIcon.icns')], check=True)
    shutil.rmtree(tmp)
    print('Support/AppIcon.icns')


if __name__ == '__main__':
    main()
