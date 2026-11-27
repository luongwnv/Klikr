# Template for a board module (files starting with _ are skipped). Copy to tools/boards/<id>.py.
def register(h):
    def layout():
        keys = h.build_rows([
            (0, ['esc', *h.NUM, '-', '=', ('bspc', 2)]),
            (1, [('tab', 1.5), *'qwertyuiop', '[', ']', ('\\', 1.5)]),
            (2, [('capslock', 1.75), *'asdfghjkl', ';', "'", ('enter', 2.25)]),
            (3, [('lshift', 2.25), *'zxcvbnm', ',', '.', '/', ('rshift', 2.75)]),
            (4, [('lctrl', 1.25), ('lcmd', 1.25), ('lopt', 1.25), ('space', 6.25), ('ropt', 1.25), ('mo(1)', 1.25),
                 ('menu', 1.25), ('rctrl', 1.25)]),
        ])
        h.label(keys, 'mo(1)', 'fn')
        return h.board(keys, h.FN_LAYERS, {'key': '#dddddd', 'keyTop': '#eeeeee', 'legend': '#333333',
                                           'case': '#888888', 'plate': '#222222'},
                       {'x': -0.3, 'y': -0.3, 'w': 15.6, 'h': 5.6, 'r': 0.2})
    return {
        'id': 'example60', 'name': '60% Example', 'layout': layout,
        'skins': [dict(photo='keyboards/NN.webp', ppu=80, region=(-0.4, -0.4, 15.4, 5.4),
                       mask=('rect', -0.3, -0.3, 15.3, 5.3, 0.2), snap=True,
                       points=[((100, 100), (0.5, 0.5)), ((900, 100), (14.0, 0.5)), ((100, 500), (0.625, 4.5)),
                               ((900, 500), (14.375, 4.5))])],
        'caps': ([0.05, 0.04, 0.05, 0.1], 0.1),
    }
