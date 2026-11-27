
# Case outline measured on the warped photo (layout units): top, bottom, left and right edge (x = a + b * y)
CASE_TOP, CASE_BOTTOM, CASE_LEFT, CASE_RIGHT, CASE_R = -1.04, 5.73, (-0.785, 0.01), (16.10, 0.058), 0.06
# Side-mounted knob poking out of the back edge (outline in layout units)
KNOB = [(12.58, -1.0), (12.65, -1.1), (12.8, -1.2), (13.0, -1.31), (13.2, -1.39), (13.4, -1.44), (13.6, -1.46),
        (13.9, -1.46), (14.04, -1.43), (14.1, -1.38), (14.12, -1.0)]


def case_mask(rgba, keys, x0, y0, ppu):
    import numpy as np
    from PIL import Image, ImageDraw
    from scipy import ndimage as nd
    Hh, W = rgba.shape[:2]
    ss, r = 4, CASE_R
    xl, xr = (lambda y: CASE_LEFT[0] + CASE_LEFT[1] * y), (lambda y: CASE_RIGHT[0] + CASE_RIGHT[1] * y)
    corners = [(xl(CASE_TOP), CASE_TOP), (xr(CASE_TOP), CASE_TOP), (xr(CASE_BOTTOM), CASE_BOTTOM), (xl(CASE_BOTTOM), CASE_BOTTOM)]
    m = Image.new('L', (W * ss, Hh * ss), 0)
    ImageDraw.Draw(m).polygon([((x - x0) * ppu * ss, (y - y0) * ppu * ss) for x, y in corners], fill=255)
    ImageDraw.Draw(m).polygon([((x - x0) * ppu * ss, (y - y0) * ppu * ss) for x, y in KNOB], fill=255)
    hard = np.asarray(m) > 127
    rp = int(r * ppu * ss)
    inner = nd.distance_transform_edt(hard) > rp
    rounded = nd.distance_transform_edt(~inner) <= rp
    cover = np.asarray(Image.fromarray((rounded * 255).astype('uint8')).resize((W, Hh), Image.Resampling.BOX)) / 255.0
    # The bottom-right corner tip lies just outside the photo: extend the plain frame into it
    core = nd.binary_erosion(rgba[..., 3] == 255, iterations=3)
    gap = (cover > 0) & ~core & nd.binary_dilation(rgba[..., 3] < 255, iterations=3)
    if not gap.any():
        return cover
    idx = nd.distance_transform_edt(~core, return_distances=False, return_indices=True)
    filled = rgba.copy()
    filled[gap] = rgba[idx[0][gap], idx[1][gap]]
    filled[gap, 3] = 255
    return cover, filled


def register(h):
    def layout():
        keys = h.build_rows([
            (0, ['esc', *h.NUM, '-', '=', ('bspc', 2), 'del']),
            (1, [('tab', 1.5), *'qwertyuiop', '[', ']', ('\\', 1.5), 'pgup']),
            (2, [('capslock', 1.75), *'asdfghjkl', ';', "'", ('enter', 2.25), 'pgdn']),
            (3, [('lshift', 2.25), *'zxcvbnm', ',', '.', '/', ('rshift', 1.75), 'up', 'end']),
            (4, [('lctrl', 1.25), ('lcmd', 1.25), ('lopt', 1.25), ('space', 6.25), ('ropt', 1.25), ('mo(1)', 1.25),
                 (h.G, 0.5), 'left', 'down', 'right']),
        ])
        h.label(keys, 'lcmd', 'sys')
        h.label(keys, 'mo(1)', 'fn')
        h.set_layer(keys, 1, {**{n: f'f{i + 1}' for i, n in enumerate(h.NUM + ['-', '='])}, 'esc': '`', 'bspc': 'del'})
        data = h.board(keys, h.FN_LAYERS, {'key': '#e9ebe6', 'keyTop': '#f6f7f3', 'legend': '#2a2a2a',
                                           'case': '#dcdcdc', 'plate': '#8fbf2a'},
                       {'x': -0.8, 'y': -1.07, 'w': 17.4, 'h': 6.8, 'r': 0.1})
        data['encoders'] = [{'id': 'K1', 'group': 'board', 'x': 13.5, 'y': -1.25, 'd': 0.4, 'style': 'silver',
                             'ccw': 'vol-', 'cw': 'vol+', 'press': 'mute'}]
        return data
    return {
        'id': '16-lime65', 'name': '65% Lime Shell', 'layout': layout,
        'skins': [dict(photo='keyboards/16.webp', ppu=60, region=(-1.0, -1.7, 17.1, 6.1), mask=('custom', case_mask),
                       points=[((328, 928), (0.625, 4.5)), ((816, 576), (10.625, 4.5)), ((868, 538), (11.875, 4.5)),
                               ((1012, 443), (15.5, 4.5)), ((943, 418), (14.5, 3.5)), ((878, 270), (15.5, 0.5)),
                               ((827, 304), (14.0, 0.5)), ((292, 716), (2.0, 1.5)), ((232, 683), (1.5, 0.5)),
                               ((609, 651), (6.75, 3.5)), ((880, 393), (13.875, 2.5)), ((267, 808), (0.875, 2.5)),
                               ((657, 618), (7.75, 3.5)), ((700, 588), (8.75, 3.5)), ((552, 622), (6.25, 2.5)),
                               ((600, 592), (7.25, 2.5))])],
        'caps': ([0.05, 0.04, 0.05, 0.1], 0.1),
    }
