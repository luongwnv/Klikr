import math

EDGES = {
    'top': [(45, 156.8), (95, 156.4), (145, 156.2), (195, 156.1), (245, 156.2), (295, 156.5), (345, 156.9), (395, 157.3),
            (445, 157.4), (495, 157.4), (511, 157.4), (514, 154.9), (566, 154.9), (569, 157.1), (595, 157.0), (645, 156.7),
            (695, 156.2), (745, 155.6), (795, 155.2), (845, 154.9), (895, 155.1), (945, 155.4), (995, 155.5), (1045, 155.9)],
    'right': [(1059.0, 175), (1060.0, 225), (1060.6, 275), (1061.4, 325), (1061.9, 375), (1062.3, 425), (1062.4, 475),
              (1062.5, 525), (1062.3, 575)],
    'bottom': [(45, 590.9), (95, 591.4), (145, 591.8), (195, 592.2), (245, 592.3), (295, 592.1), (345, 591.7), (395, 591.4),
               (445, 591.1), (495, 590.7), (545, 590.7), (595, 590.7), (645, 591.0), (695, 591.3), (745, 591.4), (795, 591.4),
               (845, 590.9), (895, 590.6), (945, 589.9), (995, 589.5), (1045, 588.7)],
    'left': [(27.8, 175), (27.5, 225), (27.1, 275), (26.5, 325), (26.3, 375), (26.3, 425), (26.3, 475), (26.5, 525),
             (26.7, 575)],
}
POINTS = [((86, 217.5), (0.5, 0.5)), ((206.5, 292), (2.5, 1.75)), ((797.5, 292), (12.5, 1.75)), ((890.5, 291), (14.0, 1.75)),
          ((93.5, 530), (0.625, 5.75)), ((467.5, 528.5), (6.875, 5.75)), ((803.5, 528), (12.5, 5.75)),
          ((839, 468.5), (13.125, 4.75)), ((1000, 539), (15.75, 6.0)), ((924, 214), (14.5, 0.5))]


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
    G = h.G

    def layout():
        keys = h.build_rows([
            (0, ['esc', (G, .25), 'f1', 'f2', 'f3', 'f4', (G, .25), 'f5', 'f6', 'f7', 'f8', (G, .25), 'f9', 'f10', 'f11',
                 'f12', (G, .25), 'del']),
            (1.25, ['§', *h.NUM, '-', '=', ('bspc', 2), (G, .5), 'home']),
            (2.25, [('tab', 1.5), *'qwertyuiop', '[', ']', (G, 2), 'pgup']),
            (3.25, [('capslock', 1.75), *'asdfghjkl', ';', "'", '\\', (G, 1.75), 'pgdn']),
            (4.25, [('lshift', 1.25), '`', *'zxcvbnm', ',', '.', '/', ('rshift', 1.75), (G, .25), ('up', 1, {'y': 4.5}),
                    (G, .25), 'end']),
            (5.25, [('lctrl', 1.25), ('lopt', 1.25), ('lcmd', 1.25), ('space', 6.25), 'ropt', 'mo(1)', 'rctrl']),
            (5.5, ['left', 'down', 'right'], 13.25),
        ])
        keys.append({'id': 'enter', 'x': 13.75, 'y': 2.25, 'w': 1.25, 'h': 2, 'x2': -0.25, 'y2': 0, 'w2': 1.5, 'h2': 1,
                     'actions': ['enter']})
        h.label(keys, 'mo(1)', 'Fn')
        h.fn_row_media(keys)
        data = h.board(keys, h.FN_LAYERS, {'key': '#f1eeea', 'keyTop': '#fbfaf8', 'legend': '#1a1a1a',
                                           'case': '#1b1b1c', 'plate': '#0e0e0f'},
                       {'x': -0.5, 'y': -0.53, 'w': 17.32, 'h': 7.32, 'r': 0.19})
        data['encoders'] = [{'id': 'K1', 'group': 'board', 'x': 16.09, 'y': 0.42, 'd': 1.13, 'style': 'black',
                             'ccw': 'vol-', 'cw': 'vol+', 'press': 'mute'}]
        return data

    return {
        'id': '23-iso75-red', 'name': '75% ISO DE Red and White', 'layout': layout,
        'skins': [dict(photo='keyboards/23.webp', ppu=60, region=(-0.65, -0.7, 17.0, 6.95),
                       mask=('custom', outline_mask(h, POINTS, EDGES, 0.19)), points=POINTS)],
        'caps': ([0.05, 0.04, 0.05, 0.1], 0.1),
    }
