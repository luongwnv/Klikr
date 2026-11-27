POINTS = [((177.5, 214.4), (0.5, 0.5)), ((866.25, 213.1), (16.0, 0.5)), ((189.1, 391), (0.625, 4.5)),
          ((861.25, 388.1), (16.0, 4.5)), ((425, 260), (6.0, 1.5)), ((479.4, 302.5), (7.25, 2.5)),
          ((618.75, 388.75), (10.375, 4.5)), ((819.4, 343.6), (15.0, 3.5)), ((210.6, 350.6), (1.125, 3.5))]
CASE_PX = [(151.25, 184.5), (888.75, 181.5), (887.5, 422.5), (157, 427)]


def register(h):
    import numpy as np

    def layout():
        keys = h.build_rows([
            (0, ['esc', *h.NUM, '-', '=', ('bspc', 2), (h.G, .5), 'help']),
            (1, [('tab', 1.5), *'qwertyuiop', '[', ']', ('\\', 1.5), (h.G, .5), 'del']),
            (2, [('capslock', 1.75), *'asdfghjkl', ';', "'", ('enter', 2.25)]),
            (3, [('lshift', 2.25), *'zxcvbnm', ',', '.', '/', ('rshift', 2.25), 'up']),
            (4, [('lctrl', 1.25), ('lcmd', 1.25), ('lopt', 1.25), ('space', 6), ('ropt', 1.25), ('rcmd', 1.25),
                 ('menu', 1.25), 'left', 'down', 'right']),
        ])
        h.label(keys, 'help', 'ins')
        return h.board(keys, [{'name': 'Base', 'short': 'abc'}],
                       {'key': '#e6e2d8', 'keyTop': '#f1eee6', 'legend': '#222222', 'case': '#1d1f23', 'plate': '#121315'},
                       {'x': -0.1, 'y': -0.2, 'w': 16.65, 'h': 5.5, 'r': 0.06})

    def mask(rgba, keys, x0, y0, ppu):
        from PIL import Image, ImageDraw
        from scipy import ndimage as nd
        Hi = np.linalg.inv(h.homography(POINTS))
        Hh, W = rgba.shape[:2]
        ss = 4
        m = Image.new('L', (W * ss, Hh * ss), 0)
        poly = [((u - x0) * ppu * ss, (v - y0) * ppu * ss) for u, v in (h.apply_h(Hi, p) for p in CASE_PX)]
        ImageDraw.Draw(m).polygon(poly, fill=255)
        inside = np.asarray(m.resize((W, Hh), Image.Resampling.BOX)) > 127
        r = 0.08 * ppu
        core = nd.distance_transform_edt(inside) > r
        case = nd.distance_transform_edt(~core) <= r
        rgb = rgba[..., :3].astype(float)
        R, G, B = rgb[..., 0], rgb[..., 1], rgb[..., 2]
        skin = ((R - G) / np.maximum(R, 1) > 0.15) & ((R - B) / np.maximum(R, 1) > 0.22) & (R > 35)
        skin[:int((4.6 - y0) * ppu)] = False
        skin = nd.binary_closing(skin, iterations=2)
        lab, n = nd.label(skin)
        outside = ~nd.binary_erosion(case, iterations=2)
        hits = [i for i in np.unique(lab[outside & skin]) if i and (lab == i).sum() > (0.5 * ppu) ** 2]
        hand = nd.binary_fill_holes(nd.binary_closing(np.isin(lab, hits), iterations=3))
        hand = nd.gaussian_filter(hand.astype(float), 0.05 * ppu) > 0.3
        hand = nd.distance_transform_edt(~hand) <= 2.5
        # Keep the whole case and paint the hand over with the surrounding case and caps
        hole = case & hand
        known = case & ~hand
        out = rgba.astype(float).copy()
        # Case lip and spacebar edges run horizontally, so fill each row from its nearest known pixels left and right
        for y in np.where(hole.any(axis=1))[0]:
            row_known = np.where(known[y])[0]
            if row_known.size < 2:
                continue
            xs = np.where(hole[y])[0]
            for c in range(3):
                out[y, xs, c] = np.interp(xs, row_known, rgb[y, row_known, c])
        out[..., :3] = np.where(hole[..., None], nd.uniform_filter(out[..., :3], size=(3, 1, 1)), out[..., :3])
        return case, out

    return {
        'id': '18-black65', 'name': '65% Black', 'layout': layout,
        'skins': [dict(photo='keyboards/18.webp', ppu=60, region=(-0.3, -0.4, 16.85, 5.5), mask=('custom', mask),
                       points=POINTS)],
        'caps': ([0.05, 0.04, 0.05, 0.1], 0.1),
    }
