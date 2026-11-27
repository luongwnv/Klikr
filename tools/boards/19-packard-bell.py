import os, tempfile

PAD = 40


class PaddedPhoto:
    """The case corners touch the photo border: build skins from a copy with edge pixels extended by PAD px."""
    def __init__(self, src):
        self.src = src

    def __fspath__(self):
        from PIL import Image
        import numpy as np
        root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        out = os.path.join(tempfile.gettempdir(), 'klikr-19-packard-bell-padded.png')
        a = np.asarray(Image.open(os.path.join(root, self.src)).convert('RGB'))
        Image.fromarray(np.pad(a, ((PAD, PAD), (PAD, PAD), (0, 0)), mode='edge')).save(out)
        return out


def quad_mask(quad, radius):
    """Case outline: quad corners in layout units, corners rounded by radius."""
    def fn(rgba, keys, x0, y0, ppu):
        import numpy as np
        from PIL import Image, ImageDraw
        from scipy import ndimage as nd
        H, W = rgba.shape[:2]
        cx, cy = sum(p[0] for p in quad) / 4, sum(p[1] for p in quad) / 4
        inner = []
        for x, y in quad:
            dx, dy = cx - x, cy - y
            inner.append(((x + radius * (1 if dx > 0 else -1) - x0) * ppu, (y + radius * (1 if dy > 0 else -1) - y0) * ppu))
        m = Image.new('L', (W, H), 0)
        ImageDraw.Draw(m).polygon(inner, fill=255)
        return nd.distance_transform_edt(np.asarray(m) == 0) <= radius * ppu
    return fn


CASE = [(-0.6, -2.21), (23.3, -2.01), (23.04, 7.98), (-0.6, 7.99)]


def register(h):
    G = h.G
    R = 2.0

    def layout():
        keys = h.build_rows([
            (0, ['esc', (G, 1), 'f1', 'f2', 'f3', 'f4', (G, .5), 'f5', 'f6', 'f7', 'f8', (G, .5), 'f9', 'f10', 'f11', 'f12',
                 (G, .25), 'f13', 'f14', 'f15']),
            (R, ['`', *h.NUM, '-', '=', ('bspc', 2), (G, .25), 'help', 'home', 'pgup', (G, .25),
                 'numlock', 'kp/', 'kp*', 'kp-']),
            (R + 1, [('tab', 1.5), *'qwertyuiop', '[', ']', ('\\', 1.5), (G, .25), 'del', 'end', 'pgdn', (G, .25),
                     'kp7', 'kp8', 'kp9', ('kp+', 1, {'h': 2})]),
            (R + 2, [('capslock', 1.75), *'asdfghjkl', ';', "'", ('enter', 2.25), (G, 3.5), 'kp4', 'kp5', 'kp6']),
            (R + 3, [('lshift', 2.25), *'zxcvbnm', ',', '.', '/', ('rshift', 2.75), (G, 1.25), 'up', (G, 1.25),
                     'kp1', 'kp2', 'kp3', ('kpenter', 1, {'h': 2})]),
            (R + 4, [('lctrl', 1.5), (G, 1), ('lopt', 1.5), ('space', 7), ('ropt', 1.5), (G, 1), ('rctrl', 1.5), (G, .25),
                     'left', 'down', 'right', (G, .25), ('kp0', 2), 'kp.']),
        ])
        for a, t in (('f13', 'print'), ('f14', 'scroll'), ('f15', 'pause'), ('help', 'ins')):
            h.label(keys, a, t)
        h.fn_row_media(keys)
        return h.board(keys, h.FN_LAYERS, {'key': '#e6dfcc', 'keyTop': '#efe9d8', 'legend': '#2e2e2e',
                                           'case': '#ddd6c6', 'plate': '#2a2826'},
                       {'x': -0.62, 'y': -2.22, 'w': 23.93, 'h': 10.21, 'r': 0.15})

    points = [((78, 656), (0.5, 0.5)), ((768, 418), (17.75, 0.5)), ((174, 889), (0.75, R + 4.5)),
              ((980, 601), (21.0, R + 4.5)), ((966, 433), (22.0, R + 0.5)), ((145, 725), (1.5, R + 0.5)),
              ((1016, 572), (22.0, R + 4)), ((848, 645), (17.75, R + 4.5)), ((161.7, 631.7), (2.5, 0.5)),
              ((280, 591.7), (5.5, 0.5)), ((517.3, 508.3), (11.5, 0.5)), ((630, 471), (14.5, 0.5)),
              ((349.3, 651.7), (6.5, R + 0.5)), ((380, 675), (7, R + 1.5)), ((716.7, 523.3), (15.75, R + 0.5)),
              ((803.3, 536.7), (17.75, R + 1.5)), ((753.3, 508.3), (16.75, R + 0.5))]
    return {
        'id': '19-packard-bell', 'name': 'Packard Bell 101', 'layout': layout,
        'skins': [dict(photo=PaddedPhoto('keyboards/19.webp'), ppu=60, region=(-0.75, -2.35, 23.45, 8.1),
                       mask=('custom', quad_mask(CASE, 0.15)),
                       points=[((x + PAD, y + PAD), u) for (x, y), u in points])],
        'caps': ([0.08, 0.06, 0.08, 0.12], 0.08),
        'leds': [{'kind': 'caps', 'x': 20.55, 'y': 0.87, 'w': 0.16, 'h': 0.07, 'color': '#62e05a'}],
    }
