# Generates layouts/split40.json (and with --skin the photo skins) from measurements of keyboards/6.jpeg.
# Usage: python3 tools/gen_split40.py layouts/split40.json [--skin keyboards/6.jpeg]
# --skin needs numpy, scipy and pillow.
import json, math, os, sys

# Key centers measured on the left half crop (origin at display (50, 820) of the 1659px-wide view, scale 1.5).
# One key unit = 140px horizontally and 131px vertically in that crop; r is rotation in degrees.
L = {
    'c0': [None, (0.90, 2.78, -8), (1.04, 3.80, -8)],
    'c1': [(1.82, 2.10, -8), (1.96, 3.12, -8), (2.10, 4.14, -8)],
    'c2': [(2.91, 1.47, -3), (2.96, 2.47, -3), (3.01, 3.47, -3)],
    'c3': [(4.05, 0.95, 0), (4.05, 1.95, 0), (4.05, 2.95, 0)],
    'c4': [(5.05, 1.43, 0), (5.05, 2.43, 0), (5.05, 3.43, 0)],
    'c5': [(6.05, 1.62, 0), (6.05, 2.62, 0), (6.05, 3.62, 0)],
}
LT = [(5.05, 4.71, 0), (6.13, 4.84, 6), (7.17, 5.27, 16)]
ENC = (7.24, 3.05, 1.07)
COVERS = [(6.57, 0.38, 1.39, 3.92), (0.54, 4.43, 4.03, 0.84), (2.64, 4.05, 1.93, 1.22), (3.57, 3.55, 1.0, 1.72)]
M = 17.4          # right half x = M - left x
X0, Y0 = 0.40, 0.45
UX, UY = 140.0, 131.0
# Right half photo is the mirror of the left: right_crop_x = A - left_crop_x (crop origin display x 830), shifted DYR px down
A, DYR = 1150.0, 4.0

T = None
layers = [
    {  # base
        'L': {'c0': [T, 'tab', 'lshift'], 'c1': ['q', 'a', 'z'], 'c2': ['w', 's', 'x'], 'c3': ['e', 'd', 'c'], 'c4': ['r', 'f', 'v'], 'c5': ['t', 'g', 'b']},
        'R': {'c5': ['y', 'h', 'n'], 'c4': ['u', 'j', 'm'], 'c3': ['i', 'k', ','], 'c2': ['o', 'l', '.'], 'c1': ['p', ';', '/'], 'c0': [T, "'", 'rshift']},
        'LT': ['lcmd', 'mo(1)', 'space'], 'RT': ['bspc', 'mo(2)', 'enter'],
    },
    {  # numbers + symbols
        'L': {'c0': [T, 'esc', T], 'c1': ['1', 'lctrl', 'vol-'], 'c2': ['2', 'lopt', 'vol+'], 'c3': ['3', 'lcmd', 'mute'], 'c4': ['4', 'lshift', 'play'], 'c5': ['5', '`', 'next']},
        'R': {'c5': ['6', '-', 'shift+-'], 'c4': ['7', '=', 'shift+='], 'c3': ['8', '[', 'shift+['], 'c2': ['9', ']', 'shift+]'], 'c1': ['0', '\\', 'shift+\\'], 'c0': [T, T, T]},
        'LT': [T, T, T], 'RT': [T, T, T],
    },
    {  # navigation + function
        'L': {'c0': [T, 'esc', T], 'c1': ['f1', 'lctrl', 'lcmd+z'], 'c2': ['f2', 'lopt', 'lcmd+x'], 'c3': ['f3', 'lcmd', 'lcmd+c'], 'c4': ['f4', 'lshift', 'lcmd+v'], 'c5': ['f5', 'capslock', 'lcmd+lshift+z']},
        'R': {'c5': ['f6', 'left', 'home'], 'c4': ['f7', 'down', 'pgdn'], 'c3': ['f8', 'up', 'pgup'], 'c2': ['f9', 'right', 'end'], 'c1': ['f10', 'del', 'f11'], 'c0': [T, T, 'f12']},
        'LT': [T, T, T], 'RT': [T, T, T],
    },
]


def strip(a):
    while a and a[-1] is None:
        a.pop()
    return a


keys = []


def add(id, group, cx, cy, r, acts, homing=False):
    k = {'id': id, 'group': group, 'x': round(cx - 0.5 - X0, 3) + 0.0, 'y': round(cy - 0.5 - Y0, 3) + 0.0}
    if r:
        k['r'] = r
    if homing:
        k['homing'] = True
    k['actions'] = strip(list(acts))
    keys.append(k)


for c, rows in L.items():
    for r, pos in enumerate(rows):
        if pos is None:
            continue
        cx, cy, rot = pos
        add(f'L{c[1]}{r}', 'left', cx, cy, rot, [ly['L'][c][r] for ly in layers], homing=(c == 'c4' and r == 1))
        add(f'R{c[1]}{r}', 'right', M - cx, cy, -rot, [ly['R'][c][r] for ly in layers], homing=(c == 'c4' and r == 1))
for i, (cx, cy, rot) in enumerate(LT):
    add(f'LT{i}', 'left', cx, cy, rot, [ly['LT'][i] for ly in layers], homing=(i == 1))
    add(f'RT{i}', 'right', M - cx, cy, -rot, [ly['RT'][i] for ly in layers], homing=(i == 1))
keys.sort(key=lambda k: (k['group'], k['y'], k['x']))

ex, ey, ed = ENC
encoders = [
    {'id': 'LE', 'group': 'left', 'x': round(ex - X0, 3), 'y': round(ey - Y0, 3), 'd': ed, 'style': 'black', 'ccw': 'vol-', 'cw': 'vol+', 'press': 'mute'},
    {'id': 'RE', 'group': 'right', 'x': round(M - ex - X0, 3), 'y': round(ey - Y0, 3), 'd': ed, 'style': 'silver', 'ccw': 'bright-', 'cw': 'bright+', 'press': 'play'},
]
covers = []
for (x, y, w, h) in COVERS:
    covers.append({'group': 'left', 'x': round(x - X0, 3), 'y': round(y - Y0, 3), 'w': w, 'h': h})
    covers.append({'group': 'right', 'x': round(M - x - w - X0, 3), 'y': round(y - Y0, 3), 'w': w, 'h': h})

out = {
    'name': 'Split 40',
    'spacing': {'x': 18, 'y': round(18 * UY / UX, 4)},
    'layers': [{'name': 'Base', 'short': 'abc'}, {'name': 'Number', 'short': '123'}, {'name': 'Nav', 'short': 'nav'}],
    'groups': {
        'left': {'key': '#8c8c8c', 'keyTop': '#9d9d9d', 'legend': '#f4f4f4', 'case': '#f1f1ef', 'plate': '#3a3a3a', 'splitShift': 0},
        'right': {'key': '#e6e3dd', 'keyTop': '#f3f1ec', 'legend': '#3c3c3c', 'case': '#f1f1ef', 'plate': '#3a3a3a', 'splitShift': 1},
    },
    'keys': keys, 'encoders': encoders, 'covers': covers,
    'cap': {'inset': [0.025, 0.03, 0.025, 0.02], 'radius': 0.2},
}


# Case outlines traced on 6.jpeg (px), kept slightly inside the edge; bright case walls and acrylic edges
# within a band outside them are added back, so the dark carpet never gets in.
OUTLINE = {
    'left': [[160, 2513], [172, 2497], [367, 2490], [370, 2355], [628, 2350], [632, 2197], [900, 2190], [903, 2093], [1203, 2088], [1220, 2117], [1628, 2117], [1645, 2122], [1953, 2122], [1970, 2147], [1970, 3072], [2017, 3083], [2012, 3147], [1862, 3403], [1828, 3407], [1670, 3323], [1537, 3263], [1387, 3227], [1187, 3220], [1153, 3197], [253, 3183], [250, 3030], [220, 3043], [172, 3033], [160, 3013]],
    'right': [[2127, 2130], [2438, 2127], [2863, 2123], [2872, 2097], [3172, 2097], [3193, 2188], [3450, 2188], [3460, 2330], [3727, 2333], [3733, 2477], [3893, 2480], [3897, 3013], [3843, 3017], [3840, 3190], [2947, 3192], [2938, 3217], [2797, 3238], [2580, 3272], [2413, 3330], [2280, 3397], [2238, 3400], [2213, 3383], [2093, 3130], [2100, 3097], [2127, 3077]],
}


def outline_mask(group, rgb, D):
    import numpy as np
    from PIL import Image, ImageDraw
    from scipy import ndimage as nd
    h, w = rgb.shape[:2]
    lum = nd.gaussian_filter(rgb.mean(2), 1.5 / D * 2)
    m = Image.new('L', (w, h), 0)
    ImageDraw.Draw(m).polygon([(x / D, y / D) for x, y in OUTLINE[group]], fill=255)
    m = np.asarray(m) > 0
    core = nd.distance_transform_edt(m) > 14 / D
    ring = ~core & (nd.distance_transform_edt(~core) < 45 / D)
    fg = core | nd.binary_opening(ring & (lum > 125), iterations=1)
    lab, _ = nd.label(fg)
    fg = np.isin(lab, np.unique(lab[core]))
    fg = nd.binary_closing(fg, iterations=2)
    fg = nd.binary_fill_holes(fg)
    return nd.binary_opening(fg, iterations=1)


def make_skins(photo, out_json):
    import numpy as np
    from PIL import Image, ImageDraw, ImageFilter
    from scipy import ndimage as nd

    im = Image.open(photo).convert('RGB')
    W, H = im.size
    s = W / 1659.0
    px_per_unit = s * UX / 1.5

    def to_orig(group, lx, ly):
        if group == 'left':
            return s * (50 + (lx + X0) * UX / 1.5), s * (820 + (ly + Y0) * UY / 1.5)
        rcx = A - (M - X0 - lx) * UX
        return s * (830 + rcx / 1.5), s * (820 + ((ly + Y0) * UY + DYR) / 1.5)

    def to_layout(group, X, Y):
        ly = ((Y / s - 820) * 1.5 - (DYR if group == 'right' else 0)) / UY - Y0
        if group == 'left':
            return (X / s - 50) * 1.5 / UX - X0, ly
        return M - X0 - (A - (X / s - 830) * 1.5) / UX, ly

    D = 2
    small = im.resize((W // D, H // D), Image.LANCZOS)
    lum = nd.gaussian_filter(np.asarray(small).astype(float).mean(axis=2), 1.5)
    skin_dir = os.path.splitext(out_json)[0] + '-skin'
    os.makedirs(skin_dir, exist_ok=True)
    scale_out = 0.7
    skins = []
    for g in ('left', 'right'):
        fg = outline_mask(g, np.asarray(small).astype(float), D)
        ys, xs = np.where(fg)
        pad = 2
        x0, y0 = (xs.min() - pad) * D, (ys.min() - pad) * D
        x1, y1 = (xs.max() + pad + 1) * D, (ys.max() + pad + 1) * D
        mask = Image.fromarray((fg * 255).astype('uint8')).resize((W, H), Image.BILINEAR).crop((x0, y0, x1, y1))
        mask = mask.filter(ImageFilter.GaussianBlur(D * 1.2)).point(lambda v: max(0, min(255, (v - 128) * 3 + 128)))
        rgba = im.crop((x0, y0, x1, y1)).convert('RGBA')
        rgba.putalpha(mask)
        size = (int((x1 - x0) * scale_out), int((y1 - y0) * scale_out))
        rgba = rgba.resize(size, Image.LANCZOS)
        name = f'{g}.png'
        rgba.save(os.path.join(skin_dir, name), optimize=True)
        lx0, ly0 = to_layout(g, x0, y0)
        lx1, ly1 = to_layout(g, x1, y1)
        skins.append({'group': g, 'image': f'{os.path.basename(skin_dir)}/{name}',
                      'x': round(lx0, 4), 'y': round(ly0, 4), 'w': round(lx1 - lx0, 4), 'h': round(ly1 - ly0, 4)})
    return skins


def dump(path):
    def j(v):
        return json.dumps(v, ensure_ascii=False)
    lines = ['{']
    items = list(out.items())
    for i, (k, v) in enumerate(items):
        comma = ',' if i < len(items) - 1 else ''
        if isinstance(v, list):
            lines.append(f'  {j(k)}: [')
            lines += [f'    {j(e)}' + (',' if n < len(v) - 1 else '') for n, e in enumerate(v)]
            lines.append('  ]' + comma)
        elif isinstance(v, dict) and k == 'groups':
            lines.append(f'  {j(k)}: {{')
            g = list(v.items())
            lines += [f'    {j(a)}: {j(b)}' + (',' if n < len(g) - 1 else '') for n, (a, b) in enumerate(g)]
            lines.append('  }' + comma)
        else:
            lines.append(f'  {j(k)}: {j(v)}' + comma)
    lines.append('}')
    open(path, 'w').write('\n'.join(lines) + '\n')


if __name__ == '__main__':
    target = sys.argv[1]
    if '--skin' in sys.argv:
        out['skins'] = make_skins(sys.argv[sys.argv.index('--skin') + 1], target)
    elif os.path.exists(target):
        prev = json.load(open(target))
        if 'skins' in prev:
            out['skins'] = prev['skins']
    dump(target)
    print(len(keys), 'keys', '+ skins' if 'skins' in out else '')
