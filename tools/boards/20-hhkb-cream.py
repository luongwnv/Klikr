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
            (2, [('lctrl', 1.75), *'asdfghjkl', ';', "'", ('enter', 2.25)]),
            (3, [('lshift', 2.25), *'zxcvbnm', ',', '.', '/', ('rshift', 1.75), 'mo(1)']),
            (4, ['lcmd', ('lopt', 1.5), ('space', 6), ('ropt', 1.5), 'rcmd'], 1.5),
        ])
        h.label(keys, 'mo(1)', 'Fn')
        h.set_layer(keys, 1, {**{n: f'f{i + 1}' for i, n in enumerate(h.NUM + ['-', '='])}, '\\': 'help', '`': 'del',
                              'bspc': 'del', '[': 'up', ';': 'left', "'": 'right', '/': 'down', 'tab': 'capslock'})
        return h.board(keys, h.FN_LAYERS, {'key': '#e6e1d3', 'keyTop': '#f1ede2', 'legend': '#222222',
                                           'case': '#6f7478', 'plate': '#3a3d40'},
                       {'x': 0.1, 'y': -0.32, 'w': 14.92, 'h': 5.68, 'r': 0.12})
    return {
        'id': '20-hhkb-cream', 'name': '60% HHKB Cream Kana', 'layout': layout,
        'skins': [dict(photo='keyboards/20.webp', ppu=64, region=(-0.05, -0.45, 15.15, 5.5),
                       mask=('custom', quad_mask([(0.2, -0.302), (14.946, -0.333), (15.007, 5.377), (0.097, 5.338)], 0.12)),
                       points=[((65.5, 100), (0.5, 0.5)), ((307, 100.5), (4.5, 0.5)), ((564.5, 101), (8.5, 0.5)),
                               ((838.5, 99), (12.5, 0.5)), ((980.5, 98.5), (14.5, 0.5)), ((151, 162), (2, 1.5)),
                               ((530.5, 162.5), (8, 1.5)), ((961.5, 168.5), (14.25, 1.5)), ((165.5, 227), (2.25, 2.5)),
                               ((482.5, 229.5), (7.25, 2.5)), ((820, 235), (12.25, 2.5)), ((935, 236.5), (13.875, 2.5)),
                               ((99, 287.5), (1.125, 3.5)), ((447.5, 295), (6.75, 3.5)), ((785.5, 303), (11.75, 3.5)),
                               ((980.5, 306.5), (14.5, 3.5)), ((148.5, 353.5), (2, 4.5)), ((464, 362.5), (7, 4.5)),
                               ((716.5, 370.5), (10.75, 4.5))])],
        'caps': ([0.05, 0.04, 0.05, 0.1], 0.1),
    }
