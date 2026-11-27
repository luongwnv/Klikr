import math

EDGES = {
    'top': [(135, 247.5), (255, 248.5), (375, 249.2), (495, 249.8), (615, 250.3), (735, 250.6), (855, 250.6), (935, 250.5)],
    'right': [(985.3, 275), (985.7, 325), (986.6, 400), (987.6, 450), (988.7, 500), (989.6, 525), (989.9, 550)],
    'bottom': [(135, 584.7), (215, 584.5), (295, 584.2), (375, 583.9), (455, 583.9), (535, 584.2), (615, 584.4),
               (695, 584.7), (775, 585.6), (855, 586.0), (935, 586.6)],
    'left': [(113.4, 270), (112.1, 320), (111.8, 370), (110.8, 420), (109.2, 470), (108.7, 495), (107.4, 545)],
}
POINTS = [((156, 297), (0.5, 0.5)), ((214, 297), (1.5, 0.5)), ((948, 298), (14.5, 0.5)), ((169, 357), (0.75, 1.5)),
          ((242, 357.5), (2.0, 1.5)), ((864, 357), (13.0, 1.5)), ((936, 357), (14.25, 1.5)), ((256, 413), (2.25, 2.5)),
          ((822, 413), (12.25, 2.5)), ((284, 469), (2.75, 3.5)), ((794, 469), (11.75, 3.5)), ((950, 470), (14.5, 3.5)),
          ((241, 527), (2.0, 4.5)), ((552, 526), (7.5, 4.5)), ((863, 526), (13.0, 4.5))]


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


def register(h):
    def layout():
        keys = h.build_rows([
            (0, ['esc', *h.NUM, '-', '=', '\\', '`']),
            (1, [('tab', 1.5), *'qwertyuiop', '[', ']', ('bspc', 1.5)]),
            (2, [('capslock', 1.75), *'asdfghjkl', ';', "'", ('enter', 2.25)]),
            (3, [('lshift', 2.25), *'zxcvbnm', ',', '.', '/', ('rshift', 1.75), 'mo(1)']),
            (4, ['lcmd', ('lopt', 1.5), ('space', 7), ('ropt', 1.5), 'rcmd'], 1.5),
        ])
        h.label(keys, 'mo(1)', 'Fn')
        h.set_layer(keys, 1, {**{n: f'f{i + 1}' for i, n in enumerate(h.NUM + ['-', '='])}, '\\': 'help', '`': 'del',
                              'bspc': 'del', '[': 'up', ';': 'left', "'": 'right', '/': 'down', 'esc': '`'})
        return h.board(keys, h.FN_LAYERS, {'key': '#d9dbd8', 'keyTop': '#e9eae7', 'legend': '#1f2a3a',
                                           'case': '#3c4347', 'plate': '#15181a'},
                       {'x': -0.3, 'y': -0.37, 'w': 15.5, 'h': 5.9, 'r': 0.18})
    return {
        'id': '25-cherry60', 'name': 'Cherry 60% HHKB Grey', 'layout': layout,
        'skins': [dict(photo='keyboards/25.webp', ppu=60, region=(-0.5, -0.55, 15.45, 5.7),
                       mask=('custom', outline_mask(h, POINTS, EDGES, 0.18)), points=POINTS)],
        'caps': ([0.05, 0.04, 0.05, 0.1], 0.1),
    }
