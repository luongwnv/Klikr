ROW0 = [(362.4, 291.9), (397.3, 280.4), (430.5, 268.3), (465.5, 257.1), (498.6, 245.6), (532.0, 234.1), (564.9, 222.8),
        (598.2, 211.4), (630.8, 200.5), (664.0, 189.3)]
ROW1 = [(384.6, 314.6), (419.5, 303.2), (453.7, 290.6), (487.9, 279.2), (521.9, 267.9), (555.2, 256.1), (589.1, 244.8),
        (621.9, 233.2), (655.0, 221.8)]
ROW2 = [(416.5, 332.6), (452.4, 320.8), (485.4, 308.5), (520.3, 297.1), (555.5, 285.7), (587.4, 273.0), (620.6, 261.9),
        (654.5, 250.2), (687.3, 238.5)]
ROW3 = [((367.4, 381.4), 0.5), ((404.8, 367.5), 1.5), ((438.7, 355.7), 2.5), ((683.7, 270.7), 9.625), ((720.1, 257.5), 10.75),
        ((754.8, 245.8), 11.75)]
DX, DY = 0.0, 0.0
# Case outline as rectangles in layout units: lilac pads behind, white frame, feet and the base between them
HULL = [((-0.97, -0.92), (1.85, -0.4)), ((9.5, -0.92), (12.12, -0.4)), ((-0.97, -0.47), (12.48, 4.95)),
        ((-0.4, 4.9), (12.0, 5.5)), ((-0.4, 5.5), (3.15, 6.32)), ((8.4, 5.5), (12.0, 6.32))]
POINTS = ([(p, (1.5 + i + DX, 0.5 + DY)) for i, p in enumerate(ROW0)] +
          [(p, (1.75 + i + DX, 1.5 + DY)) for i, p in enumerate(ROW1)] +
          [(p, (2.25 + i + DX, 2.5 + DY)) for i, p in enumerate(ROW2)] +
          [(p, (u + DX, 3.5 + DY)) for p, u in ROW3])


def register(h):
    import numpy as np

    def layout():
        keys = h.build_rows([
            (0, ['esc', *'qwertyuiop']),
            (1, [('tab', 1.25), *'asdfghjkl', "'"]),
            (2, [('lshift', 1.75), *'zxcvbnm', ',', '.', ('rshift', 1.5)]),
            (3, ['lctrl', 'lcmd', 'lopt', ('space', 3), ('space', 3, {'id': 'rspace'}), ('ropt', 1.25),
                 'mo(2)', 'mo(1)']),
        ])
        keys.append({'id': 'enter', 'x': 11.25, 'y': 0, 'w': 1, 'h': 2, 'x2': -0.25, 'y2': 0, 'w2': 1.25, 'h2': 1,
                     'actions': ['enter']})
        symbols = {**{c: f'shift+{n}' for c, n in zip('qwertyuiop', h.NUM)},
                   'esc': '`', 'a': '-', 's': '=', 'd': '[', 'f': ']', 'g': '\\', 'h': ';', 'j': 'shift+;', 'k': '/',
                   'l': 'shift+/', "'": 'shift+\'', 'z': 'shift+-', 'x': 'shift+=', 'c': 'shift+[', 'v': 'shift+]',
                   'b': 'shift+\\', 'n': 'shift+`', 'm': '`'}
        nav = {**{c: n for c, n in zip('qwertyuiop', h.NUM)},
               'esc': '`', 'tab': 'capslock', 'a': 'f1', 's': 'f2', 'd': 'f3', 'f': 'f4', 'g': 'f5', 'h': 'left', 'j': 'down',
               'k': 'up', 'l': 'right', "'": 'pgup', 'enter': 'pgdn', 'z': 'f6', 'x': 'f7', 'c': 'f8', 'v': 'f9', 'b': 'f10',
               'n': 'f11', 'm': 'f12', ',': 'home', '.': 'end'}
        h.set_layer(keys, 1, symbols)
        h.set_layer(keys, 2, nav)
        next(k for k in keys if k['id'] == 'rspace')['actions'] = ['space', 'bspc', 'del']
        for k in keys:
            if k['actions'][0] in ('f', 'j'):
                k['homing'] = True
        return h.board(keys, [{'name': 'Base', 'short': 'abc'}, {'name': 'Lower', 'short': 'low'},
                              {'name': 'Raise', 'short': 'rse'}],
                       {'key': '#1b1c1f', 'keyTop': '#2a2b2f', 'legend': '#e8e8e8', 'case': '#eeece8', 'plate': '#101012'},
                       {'x': -0.6, 'y': -0.6, 'w': 13.45, 'h': 5.2, 'r': 0.3})

    def mask(rgba, keys, x0, y0, ppu):
        from scipy import ndimage as nd
        rgb = nd.uniform_filter(rgba[..., :3].astype(float), (3, 3, 1))
        G, B = rgb[..., 1], rgb[..., 2]
        mx, mn = rgb.max(axis=2), rgb.min(axis=2)
        fg = ((mn > 120) & (mx - mn < 30)) | (B > G + 10)
        px = lambda u, v: (int((v - y0) * ppu), int((u - x0) * ppu))
        hull = np.zeros_like(fg)
        for (u0, v0), (u1, v1) in HULL:
            (a, b), (c, d) = px(u0, v0), px(u1, v1)
            hull[a:c, b:d] = True
        fg &= hull
        (a, b), (c, d) = px(-0.15, 0.05), px(12.15, 4.45)
        fg[a:c, b:d] = True
        fg = nd.binary_closing(fg, iterations=3) & hull
        lab, n = nd.label(fg)
        fg = nd.binary_fill_holes(lab == lab[px(6, 2)])
        fg = nd.binary_opening(fg, iterations=2)
        fg = nd.gaussian_filter(fg.astype(float), 0.05 * ppu) > 0.5
        return fg

    return {
        'id': '22-lilac40', 'name': '40% Lilac', 'layout': layout,
        'skins': [dict(photo='keyboards/22.webp', ppu=50, region=(-1.0, -1.2, 13.4, 6.6), mask=('custom', mask),
                       points=POINTS)],
        'caps': ([0.1, 0.1, 0.2, 0.15], 0.1),
    }
