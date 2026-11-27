try:
    import numpy as np
    from scipy import ndimage as nd
except ImportError:  # only needed when building skins
    np = nd = None


def fit_side(pos, val, keep):
    pos, val = np.asarray(pos, float), np.asarray(val, float)
    ok = np.ones(len(pos), bool)
    for _ in range(4):
        a, b = np.polyfit(pos[ok], val[ok], 1)
        res = np.abs(val - (a * pos + b))
        ok = res < max(1.0, keep * np.median(res[ok]) + 0.5)
    return a, b


def case_mask(rgba, keys, x0, y0, ppu):
    rgb = nd.gaussian_filter(rgba[..., :3].astype(float), (1, 1, 0))
    r, b = rgb[..., 0], rgb[..., 2]
    fg = ((r < 180) | ((b - r < 25) & (rgb.mean(axis=2) < 215))) & (rgba[..., 3] > 0)
    fg = nd.binary_opening(fg, iterations=2)
    lab, n = nd.label(fg)
    fg = lab == (int(np.argmax(nd.sum(fg, lab, range(1, n + 1)))) + 1)
    fg = nd.binary_fill_holes(nd.binary_closing(fg, iterations=4))
    Hh, W = fg.shape
    ys, xs = np.arange(Hh), np.arange(W)
    cols = xs[int(W * 0.12):int(W * 0.88)]
    rows = ys[int(Hh * 0.2):int(Hh * 0.8)]
    top = fit_side(cols, [np.argmax(fg[:, c]) for c in cols], 3)
    bot = fit_side(cols, [Hh - 1 - np.argmax(fg[::-1, c]) for c in cols], 3)
    lft = fit_side(rows, [np.argmax(fg[r_]) for r_ in rows], 3)
    rgt = fit_side(rows, [W - 1 - np.argmax(fg[r_, ::-1]) for r_ in rows], 3)
    X, Y = np.meshgrid(xs, ys)
    quad = ((Y >= top[0] * X + top[1]) & (Y <= bot[0] * X + bot[1] + 1) &
            (X >= lft[0] * Y + lft[1]) & (X <= rgt[0] * Y + rgt[1] + 1))
    soft = nd.gaussian_filter(fg.astype(float), 2.5) > 0.5
    # Straight sides come from the fitted lines; the segmentation only shapes the rounded corners
    corner = np.zeros_like(fg)
    for hz in (top, bot):
        for vt in (lft, rgt):
            cy = (hz[0] * vt[1] + hz[1]) / (1 - hz[0] * vt[0])
            cx = vt[0] * cy + vt[1]
            corner |= np.hypot(X - cx, Y - cy) < 0.45 * ppu
    return nd.binary_erosion(quad & (soft | ~corner), iterations=1)


def register(h):
    def layout():
        keys = h.build_rows([
            (0, ['esc', *h.NUM, '-', '=', ('bspc', 2)]),
            (1, [('tab', 1.5), *'qwertyuiop', '[', ']']),
            (2, [('capslock', 1.75), *'asdfghjkl', ';', "'", '\\']),
            (3, [('lshift', 1.25), '`', *'zxcvbnm', ',', '.', '/', ('rshift', 2.75)]),
            (4, [('lctrl', 1.25), ('lcmd', 1.25), ('lopt', 1.25), ('space', 2.75), ('space', 1.25), ('space', 2.25),
                 ('ropt', 1.25), ('rcmd', 1.25), ('mo(1)', 1.25), ('rctrl', 1.25)]),
        ])
        keys.append({'id': 'enter', 'x': 13.75, 'y': 1, 'w': 1.25, 'h': 2, 'x2': -0.25, 'y2': 0, 'w2': 1.5, 'h2': 1,
                     'actions': ['enter']})
        h.label(keys, '`', '<>')
        h.label(keys, 'mo(1)', 'Fn')
        h.label(keys, 'ropt', 'Alt Gr')
        h.set_layer(keys, 1, {**{n: f'f{i + 1}' for i, n in enumerate(h.NUM + ['-', '='])}, 'bspc': 'del'})
        teal = {'esc', 'tab', 'capslock', 'lshift', 'lctrl', 'lcmd', 'lopt', 'bspc', 'enter', 'rshift', 'ropt', 'rcmd',
                'mo(1)', 'rctrl'}
        for k in keys:
            if k['actions'][0] in teal:
                k.update(color='#2f6f86', legend='#ffffff')
        return h.board(keys, h.FN_LAYERS, {'key': '#c9c9cb', 'keyTop': '#d8d8da', 'legend': '#1f5f80',
                                           'case': '#8e8e92', 'plate': '#2a2a2c'},
                       {'x': -0.75, 'y': -0.3, 'w': 16.05, 'h': 5.6, 'r': 0.2})
    return {
        'id': '15-teal60', 'name': '60% ISO Teal', 'layout': layout,
        'skins': [dict(photo='keyboards/15.webp', ppu=60, region=(-0.95, -0.35, 15.45, 5.65), mask=('custom', case_mask),
                       points=[((176, 300), (0.5, 0.5)), ((871, 192), (14.0, 0.5)), ((210, 505), (0.625, 4.5)),
                               ((927, 398), (14.375, 4.5)), ((826, 255), (13.0, 1.5)), ((850, 305), (13.25, 2.5)),
                               ((782, 367), (11.75, 3.5)), ((305, 434), (2.75, 3.5)), ((791, 207), (12.5, 0.5))])],
        'caps': ([0.05, 0.04, 0.05, 0.1], 0.1),
    }
