import math, os, sys, tempfile

EDGES = {
    'top': [(150, 270.6), (220, 270.8), (290, 271.3), (360, 271.6), (430, 271.9), (500, 272.1), (570, 272.1), (640, 271.9),
            (710, 271.4), (780, 270.8), (850, 270.0), (885, 269.6)],
    'right': [(931.7, 285), (930.3, 335), (928.7, 385), (927.5, 435), (926.3, 485), (925.1, 535)],
    'bottom': [(150, 544.7), (220, 544.4), (290, 543.8), (360, 543.3), (430, 542.8), (500, 542.6), (570, 542.5),
               (640, 542.7), (710, 543.0), (780, 543.4), (850, 544.0), (885, 544.4)],
    'left': [(132.4, 285), (134.1, 335), (135.7, 385), (137.4, 435), (139.1, 485), (140.6, 535)],
}
POINTS = [((191, 317), (0.75, 0.5)), ((266, 316), (2.0, 0.5)), ((797, 316), (11.0, 0.5)), ((875, 316), (12.25, 0.5)),
          ((200, 380), (0.875, 1.5)), ((851, 380), (11.875, 1.5)), ((216, 437), (1.125, 2.5)), ((864, 437), (12.125, 2.5)),
          ((248.5, 496), (1.7, 3.5)), ((532.5, 496), (6.575, 3.5)), ((818.5, 496), (11.45, 3.5))]
PLATES = [(0, 0, 1.5), (11.5, 0, 1.5), (0, 1, 1.75), (10.75, 1, 2.25), (0, 2, 2.25)]  # (x, y, w) of the kanji keys
LAYERS = [{'name': 'Base', 'short': 'abc'}, {'name': 'Number', 'short': '123'}, {'name': 'Navigation', 'short': 'nav'}]


def outline_mask(h, points, edges, r, inset=1.0):
    """Case outline from edge samples measured in the photo (px), pulled in by inset px, corners rounded by r units."""
    import numpy as np
    Hi = np.linalg.inv(h.homography(points))
    d = {'top': (0, inset), 'bottom': (0, -inset), 'left': (inset, 0), 'right': (-inset, 0)}
    e = {k: [h.apply_h(Hi, (x + d[k][0], y + d[k][1])) for x, y in v] for k, v in edges.items()}
    top, bot, left, right = e['top'], e['bottom'], e['left'], e['right']
    tl, tr = (left[0][0], top[0][1]), (right[0][0], top[-1][1])
    br, bl = (right[-1][0], bot[-1][1]), (left[-1][0], bot[0][1])

    def arc(c, a0):
        return [(c[0] + r * math.cos(math.radians(a0 + i * 10)), c[1] + r * math.sin(math.radians(a0 + i * 10)))
                for i in range(10)]
    poly = arc((tl[0] + r, tl[1] + r), 180) + [p for p in top if tl[0] + r < p[0] < tr[0] - r]
    poly += arc((tr[0] - r, tr[1] + r), 270) + [p for p in right if tr[1] + r < p[1] < br[1] - r]
    poly += arc((br[0] - r, br[1] - r), 0) + [p for p in bot[::-1] if bl[0] + r < p[0] < br[0] - r]
    poly += arc((bl[0] + r, bl[1] - r), 90) + [p for p in left[::-1] if tl[1] + r < p[1] < bl[1] - r]

    def fn(arr, keys, x0, y0, ppu):
        from PIL import Image, ImageDraw
        ss = 4
        H, W = arr.shape[:2]
        m = Image.new('L', (W * ss, H * ss), 0)
        ImageDraw.Draw(m).polygon([((x - x0) * ppu * ss, (y - y0) * ppu * ss) for x, y in poly], fill=255)
        return np.asarray(m.resize((W, H), Image.Resampling.BOX)) > 127
    return fn


def clean_photo(h):
    """Copy of the photo with the black kanji plates painted over, so the remapped keys read cleanly."""
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    out = os.path.join(tempfile.gettempdir(), 'klikr-26-kanji40-clean.png')
    if '--skin' not in sys.argv:
        return out
    import numpy as np
    from PIL import Image, ImageDraw
    from scipy import ndimage as nd
    img = np.asarray(Image.open(os.path.join(root, 'keyboards/26.webp')).convert('RGB')).astype(float)
    H = h.homography(POINTS)
    for x, y, w in PLATES:
        c = [h.apply_h(H, p) for p in ((x + 0.15, y + 0.15), (x + w - 0.15, y + 0.15), (x + w - 0.15, y + 0.8),
                                       (x + 0.15, y + 0.8))]
        X0, Y0 = int(min(p[0] for p in c)), int(min(p[1] for p in c))
        X1, Y1 = int(max(p[0] for p in c)) + 1, int(max(p[1] for p in c)) + 1
        lab, n = nd.label(img[Y0:Y1, X0:X1].mean(axis=2) < 90)
        ys, xs = np.nonzero(lab == (int(np.argmax(nd.sum(np.ones_like(lab), lab, range(1, n + 1)))) + 1))
        a, b, cc, d = Y0 + ys.min() - 4, Y0 + ys.max() + 5, X0 + xs.min() - 4, X0 + xs.max() + 5
        # Coons patch from the cap colour just outside the plate keeps the dish shading
        top, bot = nd.median_filter(img[a - 3:a - 1, cc:d].mean(0), (9, 1)), nd.median_filter(img[b + 1:b + 3, cc:d].mean(0), (9, 1))
        lft, rgt = nd.median_filter(img[a:b, cc - 3:cc - 1].mean(1), (9, 1)), nd.median_filter(img[a:b, d + 1:d + 3].mean(1), (9, 1))
        v = np.linspace(0, 1, b - a)[:, None, None]
        u = np.linspace(0, 1, d - cc)[None, :, None]
        c00, c01 = (top[0] + lft[0]) / 2, (top[-1] + rgt[0]) / 2
        c10, c11 = (bot[0] + lft[-1]) / 2, (bot[-1] + rgt[-1]) / 2
        img[a:b, cc:d] = ((1 - v) * top[None] + v * bot[None] + (1 - u) * lft[:, None] + u * rgt[:, None]
                          - ((1 - u) * (1 - v) * c00 + u * (1 - v) * c01 + (1 - u) * v * c10 + u * v * c11))
        # Lift the whole cap just above the build's legend-ink saturation test so it leaves the cap as is
        m = Image.new('L', (img.shape[1], img.shape[0]), 0)
        ImageDraw.Draw(m).polygon([h.apply_h(H, p) for p in ((x + 0.06, y + 0.05), (x + w - 0.06, y + 0.05),
                                                             (x + w - 0.06, y + 0.95), (x + 0.06, y + 0.95))], fill=255)
        cap = np.asarray(m) > 0
        px = img[cap]
        mx, mn = px.max(1, keepdims=True), px.min(1, keepdims=True)
        k = np.maximum(1, 0.212 / np.maximum((mx - mn) / np.maximum(mx, 1), 0.02))
        img[cap] = np.clip(mx - (mx - px) * k, 0, 255)
    Image.fromarray(np.clip(img, 0, 255).astype('uint8')).save(out)
    return out


def register(h):
    def layout():
        keys = h.build_rows([
            (0, [('tab', 1.5, {'remap': True}), *'qwertyuiop', ('bspc', 1.5, {'remap': True})]),
            (1, [('esc', 1.75, {'remap': True}), *'asdfghjkl', ('enter', 2.25, {'remap': True})]),
            (2, [('lshift', 2.25, {'remap': True}), *'zxcvbnm', ',', '.', ('rshift', 1.75)]),
            (3, ['lcmd', ('lopt', 1.25), ('space', 6.25), ('mo(1)', 1.25), 'mo(2)'], 1.2),
        ])
        for a, t in (('tab', '⇥'), ('bspc', '⌫'), ('esc', 'esc'), ('enter', '↩'), ('lshift', '⇧'), ('mo(1)', 'Fn'),
                     ('mo(2)', 'Fn')):
            h.label(keys, a, t)
        h.set_layer(keys, 1, {**dict(zip('qwertyuiop', h.NUM)), 'a': '-', 's': '=', 'd': '[', 'f': ']', 'g': '\\',
                              'h': ';', 'j': "'", 'k': '/', 'l': '`', 'bspc': 'del', 'tab': '`', 'esc': 'lctrl'})
        h.set_layer(keys, 2, {**{c: f'f{i + 1}' for i, c in enumerate('qwertyuiop')}, 'a': 'f11', 's': 'f12',
                              'y': 'pgup', 'u': 'home', 'i': 'up', 'o': 'end', 'h': 'pgdn', 'j': 'left', 'k': 'down',
                              'l': 'right', 'z': 'mute', 'x': 'vol-', 'c': 'vol+', 'v': 'prev', 'b': 'play', 'n': 'next',
                              'm': 'bright-', ',': 'bright+', 'bspc': 'del', 'esc': 'capslock', 'tab': 'lctrl'})
        return h.board(keys, LAYERS, {'key': '#ece6d6', 'keyTop': '#f6f1e4', 'legend': '#1c1c1c',
                                      'case': '#e7e3da', 'plate': '#2a2826'},
                       {'x': -0.24, 'y': -0.27, 'w': 13.45, 'h': 4.6, 'r': 0.13})
    return {
        'id': '26-kanji40', 'name': '40% Cream Kanji', 'layout': layout,
        'skins': [dict(photo=clean_photo(h), ppu=60, region=(-0.4, -0.45, 13.45, 4.5),
                       mask=('custom', outline_mask(h, POINTS, EDGES, 0.13)), points=POINTS)],
        'caps': ([0.05, 0.04, 0.05, 0.1], 0.1),
        'leds': [{'kind': 'caps', 'x': 13.0, 'y': 3.27, 'w': 0.15, 'h': 0.15, 'color': '#3be05a'}],
    }
