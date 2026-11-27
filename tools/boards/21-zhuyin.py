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
            (0, ['esc', *h.NUM, '-', '=', ('bspc', 2)]),
            (1, [('tab', 1.5), *'qwertyuiop', '[', ']', ('\\', 1.5)]),
            (2, [('capslock', 1.75), *'asdfghjkl', ';', "'", ('enter', 2.25)]),
            (3, [('lshift', 2.25), *'zxcvbnm', ',', '.', '/', ('rshift', 1.75), 'mo(1)']),
            (4, ['lopt', ('lcmd', 1.5), ('space', 7), ('rcmd', 1.5), 'ropt'], 1.5),
        ])
        h.label(keys, 'mo(1)', 'Fn')
        h.set_layer(keys, 1, {**{n: f'f{i + 1}' for i, n in enumerate(h.NUM + ['-', '='])}, 'esc': '`', 'bspc': 'del',
                              '[': 'up', ';': 'left', "'": 'right', '/': 'down'})
        return h.board(keys, h.FN_LAYERS, {'key': '#dcdcd8', 'keyTop': '#ecebe7', 'legend': '#222222',
                                           'case': '#1c2230', 'plate': '#101318'},
                       {'x': -0.34, 'y': -0.39, 'w': 15.71, 'h': 5.82, 'r': 0.12})
    return {
        'id': '21-zhuyin', 'name': '60% Zhuyin', 'layout': layout,
        'skins': [dict(photo='keyboards/21.webp', ppu=60, region=(-0.36, -0.43, 15.4, 5.47),
                       mask=('custom', quad_mask([(-0.336, -0.378), (15.321, -0.409), (15.347, 5.416), (-0.343, 5.447)], 0.12)),
                       points=[((244.5, 278), (0.5, 0.5)), ((417, 279.5), (4.5, 0.5)), ((585.5, 280.5), (8.5, 0.5)),
                               ((755, 281), (12.5, 0.5)), ((256.5, 321), (0.75, 1.5)), ((438, 322.5), (5, 1.5)),
                               ((606.5, 323.5), (9, 1.5)), ((776, 323.5), (13, 1.5)), ((261.5, 364), (0.875, 2.5)),
                               ((490, 365), (6.25, 2.5)), ((658.5, 365.5), (10.25, 2.5)), ((813.5, 366.5), (13.875, 2.5)),
                               ((271, 406.5), (1.125, 3.5)), ((468.5, 407.5), (5.75, 3.5)), ((637.5, 407.5), (9.75, 3.5)),
                               ((840.5, 408), (14.5, 3.5)), ((309.5, 447.5), (2, 4.5)), ((362.5, 447.5), (3.25, 4.5)),
                               ((543, 449), (7.5, 4.5)), ((722.5, 449), (11.75, 4.5)), ((776, 450), (13, 4.5))])],
        'caps': ([0.05, 0.04, 0.05, 0.1], 0.1),
    }
