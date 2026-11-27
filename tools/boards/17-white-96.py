def case_mask(thr, radius, inset=0.6):
    """Rounded quad fitted to the four case edges, found where luminance crosses thr."""
    def fn(rgba, keys, x0, y0, ppu):
        import numpy as np
        from PIL import Image, ImageDraw
        from scipy import ndimage as nd
        lum = rgba[..., :3].astype(float) @ [0.299, 0.587, 0.114]
        fg = nd.binary_opening((lum > thr) & (rgba[..., 3] > 0), iterations=2)
        lab, n = nd.label(fg)
        fg = nd.binary_fill_holes(lab == int(np.argmax(nd.sum(fg, lab, range(1, n + 1)))) + 1)
        H, W = fg.shape
        ys, xs = np.nonzero(fg)
        bx0, bx1, by0, by1 = xs.min(), xs.max(), ys.min(), ys.max()

        def fit(ts, vs):
            ts, vs = np.array(ts, float), np.array(vs, float)
            keep = np.ones(len(ts), bool)
            for _ in range(4):
                a, b = np.polyfit(ts[keep], vs[keep], 1)
                res = np.abs(vs - (a * ts + b))
                keep = res < max(1.5, 2.5 * np.median(res[keep]))
            return a, b
        span = lambda lo, hi: range(int(lo + (hi - lo) * 0.12), int(hi - (hi - lo) * 0.12), 3)
        top = fit(*zip(*[(x, np.argmax(fg[:, x])) for x in span(bx0, bx1)]))
        bot = fit(*zip(*[(x, H - np.argmax(fg[::-1, x])) for x in span(bx0, bx1)]))
        lef = fit(*zip(*[(y, np.argmax(fg[y])) for y in span(by0, by1)]))
        rig = fit(*zip(*[(y, W - np.argmax(fg[y, ::-1])) for y in span(by0, by1)]))
        r = radius * ppu

        def corner(h, v, dy, dx):
            # y = h0*x + h1 + dy, x = v0*y + v1 + dx
            y = (h[0] * (v[1] + dx) + h[1] + dy) / (1 - h[0] * v[0])
            return (v[0] * y + v[1] + dx, y)
        d = r + inset
        quad = [corner(top, lef, d, d), corner(top, rig, d, -d), corner(bot, rig, -d, -d), corner(bot, lef, -d, d)]
        m = Image.new('L', (W, H), 0)
        ImageDraw.Draw(m).polygon(quad, fill=255)
        return nd.distance_transform_edt(np.asarray(m) == 0) <= r
    return fn


def register(h):
    G = h.G

    def layout():
        keys = h.build_rows([
            (0, ['esc', (G, .25), 'f1', 'f2', 'f3', 'f4', (G, .25), 'f5', 'f6', 'f7', 'f8', (G, .25),
                 'f9', 'f10', 'f11', 'f12', (G, .25), 'f13', 'f14', (G, .25), 'f15', 'f16', 'f17', 'f18']),
            (1.25, ['§', *h.NUM, '-', '=', ('bspc', 2), 'pgup', (G, .25), 'numlock', 'kp/', 'kp*', 'kp-']),
            (2.25, [('tab', 1.5), *'qwertyuiop', '[', ']', (G, 1.5), 'pgdn', (G, .25), 'kp7', 'kp8', 'kp9',
                    ('kp+', 1, {'h': 2})]),
            (3.25, [('capslock', 1.75), *'asdfghjkl', ';', "'", '\\', (G, 1.25), 'home', (G, .25), 'kp4', 'kp5', 'kp6']),
            (4.25, [('lshift', 1.25), '`', *'zxcvbnm', ',', '.', '/', ('rshift', 1.75), 'up', 'end', (G, .25),
                    'kp1', 'kp2', 'kp3', ('kpenter', 1, {'h': 2})]),
            (5.25, [('lctrl', 1.25), ('lopt', 1.25), ('lcmd', 1.25), ('space', 6.25), ('rcmd', 1.25), ('ropt', 1.25),
                    (G, .5), 'left', 'down', 'right', (G, .25), ('kp0', 2), 'kp.']),
        ])
        keys.append({'id': 'enter', 'x': 13.75, 'y': 2.25, 'w': 1.25, 'h': 2, 'x2': -0.25, 'y2': 0, 'w2': 1.5, 'h2': 1,
                     'actions': ['enter']})
        h.fn_row_media(keys)
        for a, t in (('§', '^'), ('`', '<'), ('home', 'Y'), ('end', '≡')):
            h.label(keys, a, t)
        for k in keys:
            if k['actions'][0] in ('up', 'left', 'down', 'right'):
                k.update(color='#f28a1c', legend='#ffffff')
        return h.board(keys, h.FN_LAYERS, {'key': '#ecebe6', 'keyTop': '#f6f5f1', 'legend': '#4a4a4a',
                                           'case': '#e9e5dc', 'plate': '#d8d3c8'},
                       {'x': -0.33, 'y': -0.83, 'w': 20.9, 'h': 7.38, 'r': 0.32})

    return {
        'id': '17-white-96', 'name': '96% White Orange DE', 'layout': layout,
        'skins': [dict(photo='keyboards/17.webp', ppu=60, region=(-0.45, -0.95, 20.7, 6.7),
                       mask=('custom', case_mask(90, 0.32)),
                       points=[((85, 386), (0.5, 0.5)), ((854, 386), (19.75, 0.5)), ((84, 597), (0.625, 5.75)),
                               ((814, 598), (18.75, 5.75)), ((854, 437), (19.75, 1.75)), ((123, 436), (1.5, 1.75)),
                               ((314, 519), (6.25, 3.75)), ((605.5, 598), (13.5, 5.75))])],
        'caps': ([0.05, 0.04, 0.05, 0.08], 0.1),
    }
