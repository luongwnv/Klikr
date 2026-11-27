def quad_mask(poly, r):
    def fn(rgba, keys, x0, y0, ppu):
        import numpy as np
        from PIL import Image, ImageDraw
        from scipy import ndimage as nd
        m = Image.new('L', (rgba.shape[1], rgba.shape[0]), 0)
        ImageDraw.Draw(m).polygon([((x - x0) * ppu, (y - y0) * ppu) for x, y in poly], fill=255)
        core = nd.distance_transform_edt(np.asarray(m) > 127) > r * ppu
        return nd.distance_transform_edt(~core) <= r * ppu
    return fn


def register(h):
    def layout():
        keys = h.build_rows([
            (0, ['esc', *h.NUM, '-', '=', '\\', '`']),
            (1, [('tab', 1.5), *'qwertyuiop', '[', ']', ('bspc', 1.5)]),
            (2, [('capslock', 1.75), *'asdfghjkl', ';', "'", ('enter', 2.25)]),
            (3, [('lshift', 2.25), *'zxcvbnm', ',', '.', '/', ('rshift', 1.75), 'mo(1)']),
            (4, [('lopt', 1.5), (h.G, 1), ('lcmd', 1.5), ('space', 7), ('rcmd', 1.5), (h.G, 1), ('ropt', 1.5)]),
        ])
        h.label(keys, 'mo(1)', 'Code')
        h.set_layer(keys, 1, {**{n: f'f{i + 1}' for i, n in enumerate(h.NUM + ['-', '='])}, '\\': 'help', '`': 'del',
                              'bspc': 'del', '[': 'up', ';': 'left', "'": 'right', '/': 'down'})
        return h.board(keys, h.FN_LAYERS, {'key': '#e4ddd0', 'keyTop': '#f0ebe2', 'legend': '#b0283c',
                                           'case': '#d9d9d6', 'plate': '#4a1f17'},
                       {'x': -0.24, 'y': -0.38, 'w': 15.47, 'h': 5.91, 'r': 0.2})
    return {
        'id': '24-hiragana', 'name': '60% Hiragana Red', 'layout': layout,
        'skins': [dict(photo='keyboards/24.webp', ppu=64, region=(-0.3, -0.42, 15.31, 5.56),
                       mask=('custom', quad_mask([(-0.181, -0.347), (15.152, -0.38), (15.276, 5.535), (-0.274, 5.508)], 0.3)),
                       points=[((89, 277), (0.5, 0.5)), ((346, 275.5), (4.5, 0.5)), ((603.5, 274), (8.5, 0.5)),
                               ((859.5, 272.5), (12.5, 0.5)), ((924, 272), (13.5, 0.5)), ((109, 339), (0.75, 1.5)),
                               ((379.5, 339), (5, 1.5)), ((634.5, 338), (9, 1.5)), ((889.5, 336.5), (13, 1.5)),
                               ((207, 403), (2.25, 2.5)), ((460.5, 401.5), (6.25, 2.5)), ((713.5, 400.5), (10.25, 2.5)),
                               ((135.5, 466.5), (1.125, 3.5)), ((430, 464.5), (5.75, 3.5)), ((682.5, 463.5), (9.75, 3.5)),
                               ((111.5, 529.5), (0.75, 4.5)), ((539, 529), (7.5, 4.5)), ((809, 527.5), (11.75, 4.5)),
                               ((941.5, 399.5), (13.875, 2.5)), ((896.5, 461), (13.125, 3.5)), ((982, 461.5), (14.5, 3.5)),
                               ((966.5, 525), (14.25, 4.5))])],
        'caps': ([0.05, 0.04, 0.05, 0.1], 0.1),
    }
