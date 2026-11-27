# Builds the standard-geometry layouts (keyboards/1,2,3,4,5,7) and their photo skins.
# Usage: python3 tools/build_layouts.py [--skin] [id ...]      (--skin needs numpy, scipy, pillow)
# Skins are made by fitting a homography from measured key centers (photo px) to layout units,
# then warping the photo top-down so every cap lines up with its key.
import json, math, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'layouts')
G = '_'  # gap marker

NUM = list('1234567890')
FN_MEDIA = ['bright-', 'bright+', None, None, None, None, 'prev', 'play', 'next', 'mute', 'vol-', 'vol+']


def build_rows(rows):
    """rows: list of (y, [item...]); item = action | (action, w) | (action, w, extra) | (G, w)."""
    keys = []
    for r, (y, items, *x0) in enumerate(rows):
        x = x0[0] if x0 else 0.0
        for item in items:
            if not isinstance(item, tuple):
                item = (item, 1)
            act, w = item[0], item[1]
            extra = item[2] if len(item) > 2 else {}
            if act == G:
                x += w
                continue
            k = {'id': f'r{r}k{len(keys)}', 'x': round(x, 4), 'y': y}
            if w != 1:
                k['w'] = w
            k['actions'] = [act]
            k.update(extra)
            keys.append(k)
            x += w
    return keys


def set_layer(keys, layer, mapping):
    """mapping: base action -> action on `layer`."""
    for k in keys:
        a = k['actions'][0]
        if a in mapping:
            acts = k['actions']
            while len(acts) <= layer:
                acts.append(None)
            acts[layer] = mapping[a]


def fn_row_media(keys, layer=1):
    set_layer(keys, layer, {f'f{i + 1}': m for i, m in enumerate(FN_MEDIA) if m})


def colorize(keys, actions, **style):
    for k in keys:
        if k['actions'][0] in actions:
            k.update(style)


def label(keys, action, text):
    for k in keys:
        if k['actions'][0] == action:
            k['labels'] = [text]


# ---------------------------------------------------------------- TKL (5.jpeg, 2.jpeg)
def tkl():
    keys = build_rows([
        (0, ['esc', (G, 1), 'f1', 'f2', 'f3', 'f4', (G, .5), 'f5', 'f6', 'f7', 'f8', (G, .5), 'f9', 'f10', 'f11', 'f12',
             (G, .25), 'f13', 'f14', 'f15']),
        (1.25, ['`', *NUM, '-', '=', ('bspc', 2), (G, .25), 'help', 'home', 'pgup']),
        (2.25, [('tab', 1.5), *'qwertyuiop', '[', ']', ('\\', 1.5), (G, .25), 'del', 'end', 'pgdn']),
        (3.25, [('capslock', 1.75), *'asdfghjkl', ';', "'", ('enter', 2.25)]),
        (4.25, [('lshift', 2.25), *'zxcvbnm', ',', '.', '/', ('rshift', 2.75), (G, 1.25), 'up']),
        (5.25, [('lctrl', 1.5), 'lopt', ('lcmd', 1.5), ('space', 7), ('rcmd', 1.5), 'mo(1)', ('rctrl', 1.5), (G, .25),
                'left', 'down', 'right']),
    ])
    label(keys, 'f13', 'print')
    label(keys, 'f14', 'scroll')
    label(keys, 'f15', 'pause')
    label(keys, 'help', 'ins')
    fn_row_media(keys)
    return {
        'spacing': {'x': 19.05, 'y': 19.05},
        'layers': [{'name': 'Base', 'short': 'abc'}, {'name': 'Fn', 'short': 'fn'}],
        'groups': {'board': {'key': '#e4e2dc', 'keyTop': '#f4f3ef', 'legend': '#5a5a5a', 'case': '#e6e9ee',
                             'plate': '#c9ced6'}},
        'keys': keys,
        'cases': [{'x': -0.9, 'y': -1.75, 'w': 19.8, 'h': 9.15, 'r': 0.25}],
    }


# ---------------------------------------------------------------- 75% (3.webp)
def k75():
    keys = build_rows([
        (0, [('esc', 1.5), *[f'f{i}' for i in range(1, 13)], ('del', 1.5)]),
        (1, ['`', *NUM, '-', '=', ('bspc', 2)]),
        (2, [('tab', 1.75), *'qwertyuiop', '[', ']', ('\\', 1.25)]),
        (3, [('capslock', 2), *'asdfghjkl', ';', "'", ('enter', 2)]),
        (4, [('lshift', 2.25), *'zxcvbnm', ',', '.', '/', ('rshift', 1.75), 'up']),
        (5, ['lctrl', 'mo(1)', 'lopt', ('lcmd', 1.25), ('space', 6.25), 'rcmd', ('mo(1)', 1.5), 'left', 'down', 'right']),
    ])
    fn_row_media(keys)
    colorize(keys, {'esc', 'up', 'left', 'down', 'right'}, color='#ff6a00', legend='#ffffff')
    return {
        'spacing': {'x': 19.05, 'y': 19.05},
        'layers': [{'name': 'Base', 'short': 'abc'}, {'name': 'Fn', 'short': 'fn'}],
        'groups': {'board': {'key': '#e9e9e7', 'keyTop': '#f7f7f5', 'legend': '#555555', 'case': '#dcdcdc',
                             'plate': '#1e1e1e'}},
        'keys': keys,
        'cases': [{'x': -0.15, 'y': -0.15, 'w': 16.3, 'h': 6.4, 'r': 0.2}],
    }


# ---------------------------------------------------------------- 65% (7.webp)
def k65():
    keys = build_rows([
        (0, ['esc', *NUM, '-', '=', ('bspc', 2)]),
        (1, [('tab', 1.5), *'qwertyuiop', '[', ']', ('\\', 1.5), '`']),
        (2, [('capslock', 1.75), *'asdfghjkl', ';', "'", ('enter', 2.25), 'f16']),
        (3, [('lshift', 2.25), *'zxcvbnm', ',', '.', '/', ('rshift', 1.75), 'up', 'f17']),
        (4, ['mo(1)', 'lctrl', 'lopt', ('lcmd', 1.25), ('space', 6.25), ('rcmd', 1.5), 'ropt', 'left', 'down', 'right']),
    ])
    label(keys, 'esc', '✱')
    label(keys, 'f16', 'wrk')
    label(keys, 'f17', 'run')
    label(keys, 'mo(1)', 'fp')
    set_layer(keys, 1, {**{n: f'f{i + 1}' for i, n in enumerate(NUM + ['-', '='])}, 'bspc': 'del', 'up': 'pgup',
                        'down': 'pgdn', 'left': 'home', 'right': 'end'})
    return {
        'spacing': {'x': 19.05, 'y': 19.05},
        'layers': [{'name': 'Base', 'short': 'abc'}, {'name': 'Fn', 'short': 'fn'}],
        'groups': {'board': {'key': '#3a3a3c', 'keyTop': '#4a4a4c', 'legend': '#e6e6e6', 'case': '#4a4c50',
                             'plate': '#141414'}},
        'keys': keys,
        'cases': [{'x': -2.25, 'y': -0.85, 'w': 18.6, 'h': 6.1, 'r': 0.2}],
    }


# ---------------------------------------------------------------- 60% HHKB (1.jpeg)
def hhkb_keys(space=6):
    keys = build_rows([
        (0, ['esc', *NUM, '-', '=', '\\', '`']),
        (1, [('tab', 1.5), *'qwertyuiop', '[', ']', ('bspc', 1.5)]),
        (2, [('lctrl', 1.75), *'asdfghjkl', ';', "'", ('enter', 2.25)]),
        (3, [('lshift', 2.25), *'zxcvbnm', ',', '.', '/', ('rshift', 1.75), 'mo(1)']),
        (4, ['lopt', ('lcmd', 1.5), ('space', space), ('rcmd', 1.5), 'ropt'], 1.5),
    ])
    label(keys, 'mo(1)', 'Fn')
    set_layer(keys, 1, {**{n: f'f{i + 1}' for i, n in enumerate(NUM + ['-', '='])}, '\\': 'help', '`': 'del',
                        'bspc': 'del', '[': 'up', ';': 'left', "'": 'right', '/': 'down', 'tab': 'capslock'})
    return keys


def hhkb_kana():
    return {
        'spacing': {'x': 19.05, 'y': 19.05},
        'layers': [{'name': 'Base', 'short': 'abc'}, {'name': 'Fn', 'short': 'fn'}],
        'groups': {'board': {'key': '#0b5f96', 'keyTop': '#1371b0', 'legend': '#ffffff', 'case': '#ece9e4',
                             'plate': '#0c1016'}},
        'keys': hhkb_keys(space=7),
        'cases': [{'x': -0.22, 'y': -0.36, 'w': 15.28, 'h': 5.8, 'r': 0.06}],
    }


# ---------------------------------------------------------------- Apple Magic Keyboard with Touch ID (14.webp)
def magic():
    media = ['bright-', 'bright+', 'f3', 'f4', 'f5', 'f6', 'prev', 'play', 'next', 'mute', 'vol-', 'vol+']
    keys = build_rows([
        (0, [('esc', 1.5), *media, 'lctrl+lcmd+q']),
        (1, ['`', *NUM, '-', '=', ('bspc', 1.5)]),
        (2, [('tab', 1.5), *'qwertyuiop', '[', ']', '\\']),
        (3, [('capslock', 1.75), *'asdfghjkl', ';', "'", ('enter', 1.75)]),
        (4, [('lshift', 2.25), *'zxcvbnm', ',', '.', '/', ('rshift', 2.25)]),
        (5, ['mo(1)', 'lctrl', 'lopt', ('lcmd', 1.25), ('space', 5), ('rcmd', 1.25), 'ropt', 'left', ('up', 1, {'h': 0.5}),
             'right']),
    ])
    up = next(k for k in keys if k['actions'][0] == 'up')
    keys.append({'id': 'down', 'x': up['x'], 'y': up['y'] + 0.5, 'h': 0.5, 'actions': ['down']})
    # Like Apple's keyboard: media on the F-row, F1-F12 with fn (globe)
    for k, n in zip([k for k in keys if k['y'] == 0][1:13], range(1, 13)):
        k['actions'] = [k['actions'][0], f'f{n}']
    label(keys, 'lctrl+lcmd+q', '◯')
    label(keys, 'mo(1)', '🌐')
    return {
        'spacing': {'x': 19.05, 'y': 18.5},
        'layers': [{'name': 'Base', 'short': 'abc'}, {'name': 'Fn', 'short': 'fn'}],
        'groups': {'board': {'key': '#f4f4f6', 'keyTop': '#ffffff', 'legend': '#86868b', 'case': '#e3e3e6',
                             'plate': '#dcdce0'}},
        'keys': keys,
        'cases': [{'x': -0.09, 'y': -0.12, 'w': 14.67, 'h': 6.24, 'r': 0.3}],
    }


# ---------------------------------------------------------------- 65% ISO German (10.jpeg)
def iso65():
    keys = build_rows([
        (0, ['esc', *NUM, '-', '=', ('bspc', 2), 'f18']),
        (1, [('tab', 1.5), *'qwertyuiop', '[', ']', (G, 1.5), 'home']),
        (2, [('capslock', 1.75), *'asdfghjkl', ';', "'", '\\', (G, 1.25), 'pgup']),
        (3, [('lshift', 2.25), *'zxcvbnm', ',', '.', '/', ('rshift', 1.75), 'up', 'pgdn']),
        (4, [('lctrl', 1.25), ('lcmd', 1.25), ('lopt', 1.25), ('space', 6.25), ('ropt', 1.25), ('mo(1)', 1.25), (G, 0.5),
             'left', 'down', 'right']),
    ])
    keys.append({'id': 'enter', 'x': 13.75, 'y': 1, 'w': 1.25, 'h': 2, 'x2': -0.25, 'y2': 0, 'w2': 1.5, 'h2': 1,
                 'actions': ['enter']})
    label(keys, 'f18', '❖')
    label(keys, 'mo(1)', 'Fn')
    set_layer(keys, 1, {**{n: f'f{i + 1}' for i, n in enumerate(NUM + ['-', '='])}, 'bspc': 'del', 'home': 'end',
                        'up': 'pgup', 'down': 'pgdn'})
    for acts, color in ((['1', '2'], '#f2c230'), (['3', '4'], '#3fb4d4'), (['5', '6'], '#5cc28a'),
                        (['7', '8'], '#f2a0b8'), (['9', '0'], '#ef4f3c'), (['-', '='], '#4b5fcf')):
        colorize(keys, set(acts), color=color, legend='#111111')
    colorize(keys, {'esc', 'bspc', 'f18', 'home', 'pgup', 'pgdn', 'lshift', 'rshift'}, color='#3b3c40', legend='#ffffff')
    colorize(keys, {'ropt'}, color='#f2a7bd', legend='#111111')
    return {
        'spacing': {'x': 19.05, 'y': 19.05},
        'layers': [{'name': 'Base', 'short': 'abc'}, {'name': 'Fn', 'short': 'fn'}],
        'groups': {'board': {'key': '#d3d7d3', 'keyTop': '#e4e7e3', 'legend': '#1a1a1a', 'case': '#ebe8f2',
                             'plate': '#1c1c1e'}},
        'keys': keys,
        'cases': [{'x': -0.22, 'y': -0.08, 'w': 16.39, 'h': 5.18, 'r': 0.05}],
    }


# ---------------------------------------------------------------- 60% pink (8.webp)
def pink60():
    keys = build_rows([
        (0, ['esc', *NUM, '-', '=', ('bspc', 2)]),
        (1, [('tab', 1.5), *'qwertyuiop', '[', ']', ('\\', 1.5)]),
        (2, [('capslock', 1.75), *'asdfghjkl', ';', "'", ('enter', 2.25)]),
        (3, [('lshift', 2.25), *'zxcvbnm', ',', '.', '/', ('rshift', 2.75)]),
        (4, [('lctrl', 1.25), ('lcmd', 1.25), ('lopt', 1.25), ('space', 6.25), ('ropt', 1.25), ('mo(1)', 1.25),
             ('rctrl', 1.25), ('rcmd', 1.25)]),
    ])
    label(keys, 'mo(1)', 'Fn')
    set_layer(keys, 1, {**{n: f'f{i + 1}' for i, n in enumerate(NUM + ['-', '='])}, 'bspc': 'del', '`': 'esc',
                        'i': 'up', 'j': 'left', 'k': 'down', 'l': 'right'})
    return {
        'spacing': {'x': 19.05, 'y': 19.05},
        'layers': [{'name': 'Base', 'short': 'abc'}, {'name': 'Fn', 'short': 'fn'}],
        'groups': {'board': {'key': '#e8efe9', 'keyTop': '#f7faf6', 'legend': '#ee6aa7', 'case': '#f2d6dc',
                             'plate': '#e6c3ca'}},
        'keys': keys,
        'cases': [{'x': -0.42, 'y': -0.42, 'w': 15.84, 'h': 5.9, 'r': 0.15}],
    }


# ---------------------------------------------------------------- Alice 40 (12.jpeg)
# Each half is laid out in its own unrotated frame, then rotated ±ALICE_DEG; the right half's origin sits at ALICE_RIGHT.
ALICE_DEG = 9.4
ALICE_RIGHT = (7.18, 1.31)
ALICE_COLORS = {'r': '#d4232f', 'y': '#e8b52c', 'b': '#1d62b4', 't': '#1d98a2'}
ALICE_LEFT = [  # (row, x, width, action, color, label)
    (0, 0, 1.5, 'tab', 'b', None), (0, 1.5, 1, 'q', 'b', None), (0, 2.5, 1, 'w', 'r', None), (0, 3.5, 1, 'e', 'y', None),
    (0, 4.5, 1, 'r', 'y', None), (0, 5.5, 1, 't', 'y', None),
    (1, 0, 1.75, 'mo(1)', 'b', '⇩'), (1, 1.75, 1, 'a', 'r', None), (1, 2.75, 1, 's', 'r', None), (1, 3.75, 1, 'd', 'r', None),
    (1, 4.75, 1, 'f', 'y', None), (1, 5.75, 1, 'g', 'y', None),
    (2, 0, 1.25, 'lshift', 'b', None), (2, 1.25, 1, '`', 'b', '<>'), (2, 2.25, 1, 'z', 'b', None), (2, 3.25, 1, 'x', 'b', None),
    (2, 4.25, 1, 'c', 'b', None), (2, 5.25, 1, 'v', 'y', None), (2, 6.25, 1, 'b', 'y', None),
    (3, 0, 1.5, 'lctrl', 'b', None), (3, 1.5, 1, 'lcmd', 'b', None), (3, 2.5, 1.5, 'lopt', 'b', None),
    (3, 5.0, 2.25, 'space', 't', None),
]
ALICE_RIGHT_KEYS = [
    (0, 0, 1, 'y', 'r', None), (0, 1, 1, 'u', 'r', None), (0, 2, 1, 'i', 'r', None), (0, 3, 1, 'o', 't', None),
    (0, 4, 1, 'p', 't', None), (0, 5, 1, '[', 'b', None),
    (1, 0.25, 1, 'h', 'y', None), (1, 1.25, 1, 'j', 'r', None), (1, 2.25, 1, 'k', 't', None), (1, 3.25, 1, 'l', 't', None),
    (1, 4.25, 1, ';', 'b', None), (1, 5.25, 1, "'", 'b', None),
    (2, -0.25, 1, 'b', 'y', None), (2, 0.75, 1, 'n', 'y', None), (2, 1.75, 1, 'm', 't', None), (2, 2.75, 1, ',', 'b', None),
    (2, 3.75, 1, '.', 'b', None), (2, 4.75, 1, '/', 'b', None), (2, 5.75, 1.5, 'rshift', 'y', None),
    (3, -0.25, 2.75, 'space', 'y', None), (3, 3.25, 1.5, 'ropt', 'y', None), (3, 4.75, 1, 'rcmd', 'y', None),
    (3, 5.75, 1.5, 'rctrl', 'y', None),
]


def alice_place(half, cx, cy):
    """Half-local key center -> global layout coordinates."""
    a = math.radians(ALICE_DEG if half == 'left' else -ALICE_DEG)
    x, y = cx * math.cos(a) - cy * math.sin(a), cx * math.sin(a) + cy * math.cos(a)
    if half == 'right':
        x, y = x + ALICE_RIGHT[0], y + ALICE_RIGHT[1]
    return x, y


def alice():
    layer1 = {**{c: n for c, n in zip('qwertyuiop', NUM)}, '[': '-', "'": '=', ';': '\\', 'tab': 'esc',
              'h': 'left', 'j': 'down', 'k': 'up', 'l': 'right', 'n': 'del'}
    keys = []
    specs = [('left', ALICE_LEFT), ('right', ALICE_RIGHT_KEYS)]
    for half, table in specs:
        for n, (row, x, w, act, col, lab) in enumerate(table):
            gx, gy = alice_place(half, x + w / 2, row + 0.5)
            k = {'id': f'{half[0].upper()}{n}', 'group': 'board', 'x': round(gx - w / 2, 4), 'y': round(gy - 0.5, 4)}
            if w != 1:
                k['w'] = w
            k['r'] = ALICE_DEG if half == 'left' else -ALICE_DEG
            acts = [act]
            if act in layer1:
                acts.append(layer1[act])
            if half == 'right' and act == 'space':
                acts = ['space', 'bspc']
            k['actions'] = acts
            k['color'] = ALICE_COLORS[col]
            k['legend'] = '#ffffff'
            if lab:
                k['labels'] = [lab]
            if act in ('f', 'j'):
                k['homing'] = True
            keys.append(k)
    # ISO Enter on the right half: 1.25x2 with a 1.5-wide top, rotated with the half about its own center
    gx, gy = alice_place('right', 6.25 + 0.625, 1.0)
    keys.append({'id': 'enter', 'group': 'board', 'x': round(gx - 0.625, 4), 'y': round(gy - 1, 4), 'w': 1.25, 'h': 2,
                 'x2': -0.25, 'y2': 0, 'w2': 1.5, 'h2': 1, 'r': -ALICE_DEG, 'actions': ['enter'],
                 'color': ALICE_COLORS['y'], 'legend': '#ffffff'})
    return {
        'spacing': {'x': 19.05, 'y': 19.05},
        'layers': [{'name': 'Base', 'short': 'abc'}, {'name': 'Number', 'short': '123'}],
        'groups': {'board': {'key': '#e8b52c', 'keyTop': '#f0c445', 'legend': '#ffffff', 'case': '#c8ccd1',
                             'plate': '#1a1a1c'}},
        'keys': keys,
    }


def alice_points():
    left = [((1150, 706.7), (2.0, 0.5)), ((1716.7, 806.7), (6.0, 0.5)), ((1183.3, 1006.7), (2.75, 2.5)),
            ((1763.3, 1098.3), (6.75, 2.5))]
    right = [((1980, 823.3), (0.5, 0.5)), ((2663.3, 726.7), (5.5, 0.5)), ((1983.3, 1110), (0.25, 2.5)),
             ((2708.3, 1006.7), (5.25, 2.5))]
    # Measured on cap tops; tall caps shot from the front sit ~0.2u (28px) above their footprint on the plate
    base = lambda p: (p[0], p[1] + 28)
    return ([(base(p), alice_place('left', *u)) for p, u in left] + [(base(p), alice_place('right', *u)) for p, u in right])


# ---------------------------------------------------------------- Unibody split (11.jpeg)
# Left half is unrotated; the right half's local frame is rotated UNI_DEG about UNI_RIGHT (fitted on the photo's plane).
UNI_DEG = -15.4
UNI_RIGHT = (7.63, -0.24)
UNI_GRAY, UNI_RED, UNI_ORANGE, UNI_TEAL = '#b3b2ad', '#c8342b', '#e8891f', '#12809a'
UNI_LEFT = [  # (x, y, w, action, color, label)
    (0, 0, 1, 'esc', UNI_GRAY, None), (1, 0, 1, 'q', None, None), (2, 0, 1, 'w', None, None), (3, 0, 1, 'e', None, None),
    (4, 0, 1, 'r', None, None), (5, 0, 1, 't', None, None),
    (0, 1, 1, 'mo(1)', UNI_GRAY, '+'), (1, 1, 1, 'a', None, None), (2, 1, 1, 's', None, None), (3, 1, 1, 'd', None, None),
    (4, 1, 1, 'f', None, None), (5, 1, 1, 'g', None, None),
    (0, 2, 1.5, 'lopt', UNI_GRAY, None), (1.5, 2, 1, 'z', None, None), (2.5, 2, 1, 'x', None, None),
    (3.5, 2, 1, 'c', None, None), (4.5, 2, 1, 'v', None, None), (5.5, 2, 1, 'b', None, None),
    (-0.05, 3.3, 1, 'lctrl', UNI_RED, None), (1.1, 3.05, 1, 'lcmd', UNI_ORANGE, None), (2.0, 3.0, 1.25, 'lopt', UNI_TEAL, None),
    (3.9, 3.15, 1, 'enter', None, '↩'), (4.95, 3.15, 1.75, 'space', None, 'space'),
]
UNI_RIGHT_KEYS = [
    (0, 0, 1, 'y', None, None), (1, 0, 1, 'u', None, None), (2, 0, 1, 'i', None, None), (3, 0, 1, 'o', None, None),
    (4, 0, 1, 'p', None, None), (5, 0, 1, 'bspc', None, '⌫'),
    (0, 1, 1, 'h', None, None), (1, 1, 1, 'j', None, None), (2, 1, 1, 'k', None, None), (3, 1, 1, 'l', None, None),
    (4, 1, 1, ';', None, None), (5, 1, 1, 'pgdn', UNI_GRAY, None),
    (-0.5, 2, 1, '/', None, None), (0.5, 2, 1, 'n', None, None), (1.5, 2, 1, 'm', None, None), (2.5, 2, 1, ',', None, None),
    (3.5, 2, 1, '.', None, None), (4.5, 2, 1.5, 'ropt', UNI_GRAY, None),
    (-0.3, 3.05, 1.25, 'rshift', UNI_GRAY, None), (1.3, 3.1, 1, 'rcmd', UNI_GRAY, None), (2.55, 2.95, 1.25, 'ropt', UNI_TEAL, None),
    (3.7, 2.95, 1.25, 'rcmd', UNI_ORANGE, None), (5.0, 3.2, 1.25, 'rctrl', UNI_RED, None),
]


def uni_place(half, cx, cy):
    if half == 'left':
        return cx, cy
    a = math.radians(UNI_DEG)
    return (UNI_RIGHT[0] + cx * math.cos(a) - cy * math.sin(a), UNI_RIGHT[1] + cx * math.sin(a) + cy * math.cos(a))


def unisplit():
    layer1 = {**{c: n for c, n in zip('qwertyuiop', NUM)}, 'h': 'left', 'j': 'down', 'k': 'up', 'l': 'right',
              ';': "'", '/': '\\', 'n': '-', 'm': '=', ',': '[', '.': ']', 'esc': '`', 'bspc': 'del'}
    keys = []
    for half, table in (('left', UNI_LEFT), ('right', UNI_RIGHT_KEYS)):
        for n, (x, y, w, act, col, lab) in enumerate(table):
            gx, gy = uni_place(half, x + w / 2, y + 0.5)
            k = {'id': f'{half[0].upper()}{n}', 'group': half, 'x': round(gx - w / 2, 4), 'y': round(gy - 0.5, 4)}
            if w != 1:
                k['w'] = w
            if half == 'right':
                k['r'] = UNI_DEG
            k['actions'] = [act] + ([layer1[act]] if act in layer1 else [])
            if col:
                k['color'] = col
                k['legend'] = '#ffffff' if col != UNI_GRAY else '#3a3a3a'
            if lab:
                k['labels'] = [lab]
                if lab in ('↩', 'space', '⌫'):
                    k['remap'] = True
            if act in ('f', 'j'):
                k['homing'] = True
            keys.append(k)
    return {
        'spacing': {'x': 19.05, 'y': 19.05},
        'layers': [{'name': 'Base', 'short': 'abc'}, {'name': 'Number', 'short': '123'}],
        'groups': {g: {'key': '#e3e2dd', 'keyTop': '#efeee9', 'legend': '#6b6b6b', 'case': '#d6d2d0', 'plate': '#3a3a3a'}
                   for g in ('left', 'right')},
        'keys': keys,
    }


def uni_points(half):
    f = lambda X, Y: (1100 + X / 0.27, 1100 + Y / 0.27 + 60)  # cap tops -> footprints (~0.2u lower)
    left = [((232, 347), (0.5, 0.5)), ((692, 347), (5.5, 0.5)), ((382, 527), (2.0, 2.5)), ((747, 527), (6.0, 2.5)),
            ((235, 437), (0.5, 1.5)), ((697, 437), (5.5, 1.5))]
    right = [((952, 310), (0.5, 0.5)), ((1260, 230), (4.5, 0.5)), ((977, 400), (0.5, 1.5)), ((1285, 310), (4.5, 1.5)),
             ((1045, 465), (1.0, 2.5)), ((1275, 400), (4.0, 2.5))]
    return [(f(*p), uni_place(half, *u)) for p, u in (left if half == 'left' else right)]


FN_LAYERS = [{'name': 'Base', 'short': 'abc'}, {'name': 'Fn', 'short': 'fn'}]


# ---------------------------------------------------------------- Real boards from top-down product shots
def ortho_points(origin, pitch, w, h, pitch_y=None):
    """Straight overhead shot: layout units map to photo px by a plain scale from the cell origin of key (0, 0)."""
    py = pitch_y or pitch
    return [((origin[0] + u * pitch, origin[1] + v * py), (u, v)) for u, v in ((0, 0), (w, 0), (0, h), (w, h))]


def board(keys, layers, style, case, spacing=19.05):
    for k in keys:
        k['group'] = 'board'
    return {'spacing': {'x': spacing, 'y': spacing}, 'layers': layers, 'groups': {'board': style}, 'keys': keys,
            'cases': [case]}


RAZER_STYLE = {'key': '#141416', 'keyTop': '#1f2023', 'legend': '#44d62c', 'case': '#111113', 'plate': '#0a0a0b'}


def huntsman_mini():
    keys = build_rows([
        (0, ['esc', *NUM, '-', '=', ('bspc', 2)]),
        (1, [('tab', 1.5), *'qwertyuiop', '[', ']', ('\\', 1.5)]),
        (2, [('capslock', 1.75), *'asdfghjkl', ';', "'", ('enter', 2.25)]),
        (3, [('lshift', 2.25), *'zxcvbnm', ',', '.', '/', ('rshift', 2.75)]),
        (4, [('lctrl', 1.25), ('lcmd', 1.25), ('lopt', 1.25), ('space', 6.25), ('ropt', 1.25), ('mo(1)', 1.25),
             ('menu', 1.25), ('rctrl', 1.25)]),
    ])
    label(keys, 'mo(1)', 'fn')
    set_layer(keys, 1, {**{n: f'f{i + 1}' for i, n in enumerate(NUM + ['-', '='])}, 'esc': '`', 'bspc': 'del',
                        'i': 'up', 'j': 'left', 'k': 'down', 'l': 'right', 'p': 'print', '[': 'pgup', ']': 'home',
                        ';': 'pgdn', "'": 'end', '/': 'help'})
    return board(keys, FN_LAYERS, RAZER_STYLE, {'x': -0.38, 'y': -0.33, 'w': 15.76, 'h': 5.74, 'r': 0.2})


def blackwidow_v4x():
    m = [f'none' for _ in range(6)]
    keys = build_rows([
        (0, [m[0], (G, .25), 'esc', (G, 1), 'f1', 'f2', 'f3', 'f4', (G, .5), 'f5', 'f6', 'f7', 'f8', (G, .5),
             'f9', 'f10', 'f11', 'f12', (G, .25), 'f13', 'f14', 'f15'], -1.25),
        (1.33, [m[1], (G, .25), '`', *NUM, '-', '=', ('bspc', 2), (G, .25), 'help', 'home', 'pgup', (G, .25),
                'numlock', 'kp/', 'kp*', 'kp-'], -1.25),
        (2.33, [m[2], (G, .25), ('tab', 1.5), *'qwertyuiop', '[', ']', ('\\', 1.5), (G, .25), 'del', 'end', 'pgdn',
                (G, .25), 'kp7', 'kp8', 'kp9', ('kp+', 1, {'h': 2})], -1.25),
        (3.33, [m[3], (G, .25), ('capslock', 1.75), *'asdfghjkl', ';', "'", ('enter', 2.25), (G, 3.5),
                'kp4', 'kp5', 'kp6'], -1.25),
        (4.33, [m[4], (G, .25), ('lshift', 2.25), *'zxcvbnm', ',', '.', '/', ('rshift', 2.75), (G, 1.25), 'up', (G, 1.25),
                'kp1', 'kp2', 'kp3', ('kpenter', 1, {'h': 2})], -1.25),
        (5.33, [m[5], (G, .25), ('lctrl', 1.25), ('lcmd', 1.25), ('lopt', 1.25), ('space', 6.25), ('ropt', 1.25),
                ('mo(1)', 1.25), ('menu', 1.25), ('rctrl', 1.25), (G, .25), 'left', 'down', 'right', (G, .25),
                ('kp0', 2), 'kp.'], -1.25),
    ])
    for k, n in zip([k for k in keys if k['actions'] == ['none']], range(6, 0, -1)):
        k['labels'] = [f'M{n}']
    for a, t in (('f13', 'prt sc'), ('f14', 'scr lk'), ('f15', 'pause'), ('help', 'ins'), ('mo(1)', 'fn')):
        label(keys, a, t)
    set_layer(keys, 1, {'help': 'prev', 'home': 'play', 'pgup': 'next', 'del': 'mute', 'f11': 'bright-', 'f12': 'bright+'})
    return board(keys, FN_LAYERS, RAZER_STYLE, {'x': -1.64, 'y': -0.68, 'w': 24.6, 'h': 8.05, 'r': 0.15})


def blackwidow_v4_75():
    keys = build_rows([
        (0, ['esc', (G, .25), 'f1', 'f2', 'f3', 'f4', (G, .25), 'f5', 'f6', 'f7', 'f8', (G, .25), 'f9', 'f10', 'f11', 'f12']),
        (1.33, ['`', *NUM, '-', '=', ('bspc', 2), 'del']),
        (2.33, [('tab', 1.5), *'qwertyuiop', '[', ']', ('\\', 1.5), 'pgup']),
        (3.33, [('capslock', 1.75), *'asdfghjkl', ';', "'", ('enter', 2.25), 'pgdn']),
        (4.33, [('lshift', 2.25), *'zxcvbnm', ',', '.', '/', ('rshift', 1.75), 'up', 'help']),
        (5.33, [('lctrl', 1.25), ('lcmd', 1.25), ('lopt', 1.25), ('space', 6.25), 'ropt', 'mo(1)', 'rctrl',
                'left', 'down', 'right']),
    ])
    label(keys, 'mo(1)', 'fn')
    label(keys, 'help', 'ins')
    set_layer(keys, 1, {'pgup': 'home', 'pgdn': 'end', 'help': 'pause', 'p': 'print', 'f11': 'bright-', 'f12': 'bright+'})
    return board(keys, FN_LAYERS, RAZER_STYLE, {'x': -0.46, 'y': -0.71, 'w': 16.9, 'h': 7.4, 'r': 0.12})


def nut75():
    keys = build_rows([
        (0, ['esc', (G, .25), 'f1', 'f2', 'f3', 'f4', (G, .25), 'f5', 'f6', 'f7', 'f8', (G, .25), 'f9', 'f10', 'f11', 'f12',
             (G, .25), 'del', 'home']),
        (1.27, ['`', *NUM, '-', '=', ('bspc', 2), 'end']),
        (2.27, [('tab', 1.5), *'qwertyuiop', '[', ']', ('\\', 1.5), 'pgup']),
        (3.27, [('capslock', 1.75), *'asdfghjkl', ';', "'", ('enter', 2.25), 'pgdn']),
        (4.27, [('lshift', 2.25), *'zxcvbnm', ',', '.', '/', ('rshift', 1.75), 'up']),
        (5.27, [('lctrl', 1.25), ('lcmd', 1.25), ('lopt', 1.25), ('space', 6.25), ('mo(1)', 1.25), ('rctrl', 1.25),
                (G, .5), 'left', 'down', 'right']),
    ])
    label(keys, 'mo(1)', 'fn')
    fn_row_media(keys)
    data = board(keys, FN_LAYERS, {'key': '#e9e9e6', 'keyTop': '#f7f7f5', 'legend': '#d4561c', 'case': '#e8792e',
                                   'plate': '#c9601f'}, {'x': -0.33, 'y': -0.37, 'w': 16.66, 'h': 7.1, 'r': 0.15})
    data['encoders'] = [{'id': 'K1', 'group': 'board', 'x': 15.83, 'y': 4.87, 'd': 0.57, 'shape': 'roller', 'w': 0.57, 'h': 0.31,
                         'style': 'silver',
                         'ccw': 'vol-', 'cw': 'vol+', 'press': 'mute'}]
    return data


def mx_keys_s():
    fr = {'h': 0.79}
    top = [('esc', 1.75, fr)] + [(a, 1, fr) for a in
                                 ('bright-', 'bright+', 'f3', 'f4', 'f5', 'f6', 'f7', 'prev', 'play', 'next', 'mute', 'vol-',
                                  'vol+')]
    keys = build_rows([
        (0, [*top, (G, .17), ('none', 1, fr), ('none', 1, fr), ('none', 1, fr), (G, .15),
             ('none', 1, fr), ('shift+cmd+4', 1, fr), ('menu', 1, fr), ('lctrl+lcmd+q', 1, fr)]),
        (0.78, ['`', *NUM, '-', '=', ('bspc', 1.75), (G, .17), 'help', 'home', 'pgup', (G, .15), 'numlock', 'kp/', 'kp*', 'kp-']),
        (1.78, [('tab', 1.5), *'qwertyuiop', '[', ']', ('\\', 1.25), (G, .17), 'del', 'end', 'pgdn', (G, .15),
                'kp7', 'kp8', 'kp9', ('kp+', 1, {'h': 2})]),
        (2.78, [('capslock', 1.75), *'asdfghjkl', ';', "'", ('enter', 2), (G, 3.32), 'kp4', 'kp5', 'kp6']),
        (3.78, [('lshift', 2.25), *'zxcvbnm', ',', '.', '/', ('rshift', 2.5), (G, 1.17), 'up', (G, 1.15),
                'kp1', 'kp2', 'kp3', ('kpenter', 1, {'h': 2})]),
        (4.78, [('lctrl', 1.444), ('lopt', 1.356), ('lcmd', 1.49), ('space', 6.16), ('rcmd', 1.45), ('mo(1)', 1.44),
                ('ropt', 1.41), (G, .17), 'left', 'down', 'right', (G, .15), ('kp0', 2), 'kp.']),
    ])
    for k, n in zip(keys[1:13], range(1, 13)):
        k['actions'] = [k['actions'][0], f'f{n}']
    label(keys, 'mo(1)', 'fn')
    label(keys, 'lctrl+lcmd+q', '🔒')
    label(keys, 'shift+cmd+4', '⌗')
    for k in keys:
        k['group'] = 'board'
    return {
        'spacing': {'x': 19.0, 'y': 19.0},
        'layers': FN_LAYERS,
        'groups': {'board': {'key': '#26282b', 'keyTop': '#34373b', 'legend': '#e4e4e4', 'case': '#5f6165', 'plate': '#4b4d51'}},
        'keys': keys,
        'cases': [{'x': -0.27, 'y': -0.28, 'w': 22.62, 'h': 6.37, 'r': 0.45}],
    }


def pro_x_tkl():
    keys = build_rows([
        (0, ['esc', (G, 1), 'f1', 'f2', 'f3', 'f4', (G, .5), 'f5', 'f6', 'f7', 'f8', (G, .5), 'f9', 'f10', 'f11', 'f12',
             (G, .35), 'f13', 'f14', 'f15']),
        (1.25, ['`', *NUM, '-', '=', ('bspc', 2), (G, .35), 'help', 'home', 'pgup']),
        (2.25, [('tab', 1.5), *'qwertyuiop', '[', ']', ('\\', 1.5), (G, .35), 'del', 'end', 'pgdn']),
        (3.25, [('capslock', 1.75), *'asdfghjkl', ';', "'", ('enter', 2.25)]),
        (4.25, [('lshift', 2.25), *'zxcvbnm', ',', '.', '/', ('rshift', 2.75), (G, 1.35), 'up']),
        (5.25, [('lctrl', 1.25), ('lcmd', 1.25), ('lopt', 1.25), ('space', 6.25), ('ropt', 1.25), ('mo(1)', 1.25),
                ('menu', 1.25), ('rctrl', 1.25), (G, .35), 'left', 'down', 'right']),
    ])
    for a, t in (('f13', 'print'), ('f14', 'scroll'), ('f15', 'pause'), ('help', 'ins'), ('mo(1)', 'fn')):
        label(keys, a, t)
    fn_row_media(keys)
    for k in keys:
        k['group'] = 'board'
    return {
        'spacing': {'x': 19.05, 'y': 19.05},
        'layers': FN_LAYERS,
        'groups': {'board': {'key': '#1c1d1f', 'keyTop': '#2a2b2e', 'legend': '#3fa9f5', 'case': '#202124', 'plate': '#2c2d30'}},
        'keys': keys,
        'cases': [{'x': -0.3, 'y': -1.45, 'w': 18.9, 'h': 7.95, 'r': 0.3}],
    }


def nut65():
    keys = build_rows([
        (0, ['esc', *NUM, '-', '=', ('bspc', 2), 'help']),
        (1, [('tab', 1.5), *'qwertyuiop', '[', ']', ('\\', 1.5), 'del']),
        (2, [('capslock', 1.75), *'asdfghjkl', ';', "'", ('enter', 2.25), 'pgup']),
        (3, [('lshift', 2.25), *'zxcvbnm', ',', '.', '/', ('rshift', 1.75), 'up', 'pgdn']),
        (4, [('lctrl', 1.25), ('lcmd', 1.25), ('lopt', 1.25), ('space', 6.25), ('ropt', 1.25), ('mo(1)', 1.25), (G, .5),
             'left', 'down', 'right']),
    ])
    label(keys, 'mo(1)', 'fn')
    label(keys, 'help', 'ins')
    set_layer(keys, 1, {**{n: f'f{i + 1}' for i, n in enumerate(NUM + ['-', '='])}, 'esc': '`', 'pgup': 'home', 'pgdn': 'end'})
    return board(keys, FN_LAYERS, {'key': '#141416', 'keyTop': '#202125', 'legend': '#f2f2f2', 'case': '#151517',
                                   'plate': '#0b0b0c'}, {'x': -0.27, 'y': -0.36, 'w': 16.43, 'h': 5.81, 'r': 0.12})


def rainy75():
    data = nut75()
    del data['encoders']
    data['groups']['board'] = {'key': '#e9e4cf', 'keyTop': '#f4f0dc', 'legend': '#8f86a8', 'case': '#e8d6e6',
                               'plate': '#cbb8cc'}
    data['cases'] = [{'x': -0.28, 'y': -0.37, 'w': 16.58, 'h': 7.1, 'r': 0.22}]
    return data


def hhkb():
    keys = hhkb_keys(space=6)
    colorize(keys, {'tab', 'lctrl', 'lshift', 'rshift', 'bspc', 'mo(1)', 'lopt', 'ropt', 'lcmd', 'rcmd', '`'},
             color='#0f5a4e', legend='#ffffff')
    colorize(keys, {'esc', 'enter'}, color='#ff5b1a', legend='#ffffff')
    return {
        'spacing': {'x': 19.05, 'y': 19.05},
        'layers': [{'name': 'Base', 'short': 'abc'}, {'name': 'Fn', 'short': 'fn'}],
        'groups': {'board': {'key': '#e8e6df', 'keyTop': '#f4f2ec', 'legend': '#ff5b1a', 'case': '#ecebe6',
                             'plate': '#2b2b2b'}},
        'keys': keys,
        'cases': [{'x': -0.45, 'y': -0.45, 'w': 15.9, 'h': 6.05, 'r': 0.15}],
    }


# ---------------------------------------------------------------- Corne 3x6+3 (4.jpeg, 4-left.png)
CORNE_STAGGER = [0.375, 0.375, 0.125, 0, 0.125, 0.25]
CORNE_THUMBS = [(4.0, 3.69, 1, 0), (5.11, 3.82, 1, 15), (6.27, 4.0, 1.5, 30)]  # center x, y, height, rotation
CORNE_M = 15.5  # right x = M - left x


def corne_center(half, c, r):
    x, y = c + 0.5, CORNE_STAGGER[c] + r + 0.5
    return (CORNE_M - x, y) if half == 'right' else (x, y)


def corne_thumb(half, i):
    x, y, h, rot = CORNE_THUMBS[i]
    return (CORNE_M - x, y, h, -rot) if half == 'right' else (x, y, h, rot)


def corne():
    T = None
    L = [['`', 'q', 'w', 'e', 'r', 't'], ['lopt', 'a', 's', 'd', 'f', 'g'], ['lcmd', 'z', 'x', 'c', 'v', 'b']]
    R = [['\\', 'p', 'o', 'i', 'u', 'y'], ["'", ';', 'l', 'k', 'j', 'h'], ['rcmd', '/', '.', ',', 'm', 'n']]
    L1 = [['esc', '1', '2', '3', '4', '5'], [T] * 6, [T] * 6]
    R1 = [['del', '0', '9', '8', '7', '6'], ['=', '-', 'right', 'down', 'left', 'up'], [T, '-', '}', '{', ']', '[']]
    LT, RT = ['esc', 'space', 'lctrl'], ['mo(1)', 'bspc', 'enter']
    LT_LABEL, RT_LABEL = [None, 'space', None], ['123', '⌫', '↩']
    keys = []
    for half, base, layer1 in (('left', L, L1), ('right', R, R1)):
        for r in range(3):
            for c in range(6):
                cx, cy = corne_center(half, c, r)
                acts = [base[r][c]] + ([layer1[r][c]] if layer1[r][c] else [])
                k = {'id': f'{half[0].upper()}{c}{r}', 'group': half, 'x': round(cx - .5, 4), 'y': round(cy - .5, 4),
                     'actions': acts}
                if (c, r) == (4, 1):
                    k['homing'] = True
                keys.append(k)
        for i in range(3):
            cx, cy, h, rot = corne_thumb(half, i)
            act = (LT if half == 'left' else RT)[i]
            lab = (LT_LABEL if half == 'left' else RT_LABEL)[i]
            k = {'id': f'{half[0].upper()}T{i}', 'group': half, 'x': round(cx - .5, 4), 'y': round(cy - h / 2, 4)}
            if h != 1:
                k['h'] = h
            if rot:
                k['r'] = rot
            k['actions'] = [act]
            if lab:
                k['labels'] = [lab]
                k['remap'] = True
            keys.append(k)
    mcu = [{'group': 'left', 'x': 6.05, 'y': 0.3, 'w': 0.9, 'h': 3.0, 'color': '#1b1d22', 'r': 0.05},
           {'group': 'right', 'x': CORNE_M - 6.95, 'y': 0.3, 'w': 0.9, 'h': 3.0, 'color': '#1b1d22', 'r': 0.05}]
    style = {'key': '#e6e6e3', 'keyTop': '#f6f6f4', 'legend': '#222222', 'case': '#c8c9cc', 'plate': '#2a2a2a'}
    return {
        'spacing': {'x': 19.05, 'y': 19.05},
        'layers': [{'name': 'Base', 'short': 'abc'}, {'name': 'Number', 'short': '123'}],
        'groups': {'left': {**style, 'splitShift': 0}, 'right': {**style, 'splitShift': 1}},
        'keys': keys,
        'covers': mcu,
    }


# ---------------------------------------------------------------- photo skins
CORNE_LEFT_POINTS = {
    (0, 0): (195, 230), (1, 0): (365, 246), (2, 0): (557, 213), (3, 0): (749, 205), (4, 0): (937, 250), (5, 0): (1115, 287),
    (0, 1): (160, 413), (1, 1): (347, 427), (2, 1): (540, 398), (3, 1): (730, 390), (4, 1): (916, 422), (5, 1): (1100, 467),
    (0, 2): (142, 600), (1, 2): (327, 616), (2, 2): (525, 585), (3, 2): (715, 580), (4, 2): (900, 615), (5, 2): (1085, 647),
}
CORNE_RIGHT_POINTS = {  # in 4.jpeg; (c, r) are mirrored left column indices
    (5, 0): (2936.5, 1284.7), (4, 0): (3107, 1235.3), (3, 0): (3277.6, 1184.7), (1, 0): (3654, 1190.6),
    (0, 0): (3836.5, 1155.3), (5, 1): (2971.8, 1464.7), (1, 1): (3701, 1367), (0, 1): (3874, 1331.8),
    (5, 2): (3007, 1643.5), (4, 2): (3185.9, 1598.8), (1, 2): (3727, 1545.9), (0, 2): (3915.3, 1516.5),
}


def corne_pts(half, table, thumbs):
    pts = [(p, corne_center(half, c, r)) for (c, r), p in table.items()]
    pts += [(p, corne_thumb(half, i)[:2]) for i, p in thumbs.items()]
    return pts


# Case parts not covered by the padded keys: controller bay and the slanted plate under the thumbs
_CORNE_LEFT_CASE = [[(6.0, 0.25), (7.2, 0.25), (7.2, 2.9), (6.55, 4.9), (6.0, 4.0)],
                    [(2.0, 3.0), (3.6, 3.0), (3.6, 4.2), (3.5, 4.2)]]
# Generous outline of the aluminium case (layout units); wood outside it is cut, inside it only neutral pixels stay
_CORNE_LEFT_OUTLINE = [(-0.03, 0.3), (1.96, 0.3), (1.96, 0.02), (2.96, 0.02), (2.96, -0.08), (4.04, -0.08), (4.04, 0.02),
                       (5.0, 0.02), (5.0, 0.14), (6.0, 0.14), (6.0, 0.4), (7.4, 0.4), (7.4, 3.62), (6.42, 5.1), (5.3, 4.62),
                       (3.42, 4.32), (2.98, 3.47), (-0.03, 3.47)]
_CORNE_LEFT_SOLID = [(6.0, 0.5), (7.32, 0.5), (7.32, 3.55), (6.0, 3.55)]
CORNE_OUTLINE = {'left': _CORNE_LEFT_OUTLINE,
                 'right': [(min(CORNE_M - x, CORNE_M - 0.04), max(y, 0.34) if x < 2 else y) for x, y in _CORNE_LEFT_OUTLINE]}
CORNE_SOLID = {'left': _CORNE_LEFT_SOLID, 'right': [(CORNE_M - x, y) for x, y in _CORNE_LEFT_SOLID]}
CORNE_CASE = {'left': _CORNE_LEFT_CASE,
              'right': [[(CORNE_M - x, y) for x, y in poly] for poly in _CORNE_LEFT_CASE]}

SKINS = {
    'rainy75': [dict(photo='keyboards/wobkey-rainy75-lavender.jpg', ppu=100, region=(-0.35, -0.45, 16.4, 6.85),
                     mask=('rect', -0.28, -0.37, 16.3, 6.73, 0.22),
                     points=[((424, 240), (0.5, 0.5)), ((2147, 240), (15.5, 0.5)), ((440, 844), (0.625, 5.77)),
                             ((2140, 847), (15.5, 5.77)), ((1971, 377), (14, 1.77))])],
    'nut65': [dict(photo='keyboards/weikav-nut65-black.jpg', ppu=50, region=(-0.3, -0.4, 16.2, 5.5),
                   mask=('rect', -0.27, -0.36, 16.16, 5.45, 0.1), points=ortho_points((23, 25), 48.4, 16, 5, 49.0))],
    'huntsman-mini': [dict(photo='keyboards/razer-huntsman-mini-black.jpg', ppu=110, region=(-0.38, -0.33, 15.4, 5.42),
                           mask=('background', 238), points=ortho_points((69, 496), 183.6, 15, 5))],
    'blackwidow-v4x': [dict(photo='keyboards/razer-blackwidow-v4x.jpg', ppu=90, region=(-1.66, -0.7, 22.98, 7.4),
                            mask=('background', 238), points=ortho_points((138, 168), 81, 21, 6.33))],
    'blackwidow-v4-75': [dict(photo='keyboards/razer-blackwidow-v4-75.jpg', ppu=100, region=(-0.48, -0.72, 16.46, 6.68),
                              mask=('rect', -0.46, -0.71, 16.44, 6.66, 0.1), points=ortho_points((190, 285), 101.7, 16, 6.33))],
    'nut75': [dict(photo='keyboards/weikav-nut75-orange.png', ppu=60, region=(-0.4, -0.5, 16.5, 7.0),
                   mask=('rect', -0.27, -0.375, 16.38, 6.91, 0.12), points=ortho_points((61, 293), 55.0, 16, 6.27, 56.0))],
    'pro-x-tkl': [dict(photo='keyboards/logi-pro-x-tkl-black.png', ppu=60, region=(-0.4, -1.55, 18.7, 6.6), mask=('alpha',),
                       points=[((48, 117.5), (0.5, 0.5)), ((1075, 118), (17.85, 0.5)), ((56, 431), (0.625, 5.75)),
                               ((1072.5, 431), (17.85, 5.75)), ((851, 194), (14, 1.75))])],
    'mx-keys-s': [dict(photo='keyboards/logi-mx-keys-s-graphite.png', ppu=100, region=(-0.3, -0.92, 22.42, 6.13), mask=('alpha',),
                       points=ortho_points((45, 124), 130.2, 22, 5.78))],
    'unisplit': [dict(photo='keyboards/11.jpeg', group='left', ppu=110, region=(-0.6, -0.5, 7.5, 4.85),
                      mask=('pad', 0.3, 0.6), points=uni_points('left')),
                 dict(photo='keyboards/11.jpeg', group='right', ppu=110, region=(6.6, -2.5, 15.0, 4.9),
                      mask=('pad', 0.3, 0.6), points=uni_points('right'))],
    'alice': [dict(photo='keyboards/12.jpeg', ppu=110, region=(-1.0, -1.1, 16.2, 6.4), mask=('pad', 0.45, 0.8, 100, 0.4),
                   points=alice_points())],
    'hhkb-kana': [dict(photo='keyboards/9.webp', ppu=90, region=(-0.4, -0.55, 15.25, 5.65),
                       mask=('rect', -0.21, -0.36, 15.06, 5.44, 0.06), snap=True,
                       points=[((131.3, 545.6), (0.5, 0.5)), ((965, 545.6), (14.5, 0.5)), ((963.8, 727.5), (14.5, 3.5)),
                               ((217.5, 784.4), (2.0, 4.5)), ((875, 784.4), (13.0, 4.5))])],
    'magic': [dict(photo='keyboards/14.webp', ppu=100, region=(-0.25, -0.3, 14.75, 6.3),
                   mask=('background', 246),
                   points=[((83, 352), (0.75, 0.5)), ((957.5, 352), (14.0, 0.5)), ((67, 673), (0.5, 5.5)),
                           ((956.5, 673), (14.0, 5.5)), ((933, 544), (13.625, 3.5))])],
    'iso65': [dict(photo='keyboards/10.jpeg', region=(-0.4, -0.3, 16.35, 5.3), mask=('rect', -0.19, -0.06, 16.14, 5.07, 0.05),
                   points=[((320, 842.5), (0.5, 0.5)), ((3550, 842.5), (15.5, 0.5)), ((362.5, 1707.5), (0.625, 4.5)),
                           ((3530, 1707.5), (15.5, 4.5)), ((3550, 1497.5), (15.5, 3.5))])],
    'pink60': [dict(photo='keyboards/8.webp', ppu=70, region=(-0.7, -0.7, 15.7, 5.95), mask=('rect', -0.08, -0.15, 15.42, 5.9, 0.12),
                    points=[((200.3, 193.8), (1.5, 0.5)), ((748.6, 236.6), (10.5, 0.5)), ((393.4, 311), (5.25, 2.5)),
                            ((705.9, 344.8), (10.25, 2.5)), ((603.8, 389.7), (8.75, 3.5)), ((221, 351.7), (2.75, 3.5)),
                            ((78.3, 393.1), (0.625, 4.5)), ((230, 406.9), (3.125, 4.5)), ((719.7, 460.7), (10.625, 4.5)),
                            ((890, 478), (13.125, 4.5)), ((985, 313.8), (14.25, 1.5))])],
    'tkl-frost-rgb': [dict(photo='keyboards/5.jpeg', region=(-1.1, -2.0, 19.1, 7.6), mask=('rect', -0.92, -1.82, 18.9, 7.52, 0.2), snap=True,
                           points=[((415, 1213), (0.5, 0.5)), ((2590, 1215), (17.75, 0.5)), ((2332, 1214), (15.75, 0.5)),
                                   ((450, 1870), (0.75, 5.75)), ((2335, 1870), (15.75, 5.75)), ((2592, 1870), (17.75, 5.75))])],
    'tkl-frost': [dict(photo='keyboards/2.jpeg', region=(-1.1, -2.0, 19.1, 7.6), mask=('rect', -0.92, -1.82, 18.9, 7.52, 0.2), snap=True,
                       points=[((1076, 1288), (0.5, 0.5)), ((4205, 1290), (16.75, 0.5)), ((4400, 1292), (17.75, 0.5)),
                               ((1117, 2285), (0.75, 5.75)), ((4192, 2285), (16.75, 5.75)), ((4375, 2285), (17.75, 5.75))])],
    '75-orange': [dict(photo='keyboards/3.webp', region=(-0.35, -0.35, 16.35, 6.45), mask=('alpha',),
                       points=[((507, 1441.5), (0.75, 0.5)), ((3139, 1441.5), (14.25, 0.5)), ((3401, 2330), (15.5, 5.5)),
                               ((452, 2330), (0.5, 5.5))])],
    '65-creator': [dict(photo='keyboards/7.webp', region=(-2.4, -0.9, 16.4, 5.35), mask=('alpha',),
                        points=[((378, 941), (0.5, 0.5)), ((405.5, 1048.5), (0.75, 1.5)), ((1909, 1371), (13.5, 4.5)),
                                ((2145, 1371), (15.5, 4.5)), ((1791, 1371), (12.5, 4.5))])],
    'hhkb-tofu': [dict(photo='keyboards/1.jpeg', region=(-0.7, -0.7, 15.7, 5.85), mask=('rect', -0.34, -0.5, 15.2, 5.52, 0.12), snap=True,
                       points=[((556, 2574), (0.5, 0.5)), ((3320, 1750), (14.5, 0.5)), ((3504, 2340), (14.5, 3.5)),
                               ((1103, 3256), (2.0, 4.5)), ((3073, 2681), (12.0, 4.5))])],
    'corne': [
        dict(photo='keyboards/4-left.png', group='left', region=(-0.35, -0.2, 7.35, 5.1), mask=('outline', CORNE_OUTLINE['left'], CORNE_SOLID['left']),
             points=corne_pts('left', CORNE_LEFT_POINTS, {0: (785, 802), 1: (988, 848), 2: (1200, 902)})),
        dict(photo='keyboards/4.jpeg', group='right', region=(CORNE_M - 7.35, -0.2, CORNE_M + 0.35, 5.1), mask=('outline', CORNE_OUTLINE['right'], CORNE_SOLID['right']),
             points=corne_pts('right', CORNE_RIGHT_POINTS, {0: (3303.5, 1763.5), 1: (3103.5, 1825.9), 2: (2907, 1884.7)})),
    ],
}

# Extra photos of the same board in other colours, warped with the same fit: (id, name, swatch, photo)
COLORWAYS = {
    'rainy75': [('lavender', 'Lavender', '#e3cfe2', 'keyboards/wobkey-rainy75-lavender.jpg'),
                ('lavender-rgb', 'Lavender RGB', '#b98be0', 'keyboards/wobkey-rainy75-lavender-rgb.jpg',
                 dict(points=[((171, 282), (0.5, 0.5)), ((1755, 291), (15.5, 0.5)), ((186, 832), (0.625, 5.77)),
                              ((1744, 841), (15.5, 5.77)), ((1596, 415), (14, 1.77))])),
                ('silver', 'Silver', '#c8c9cc', 'keyboards/wobkey-rainy75-silver.jpg',
                 dict(points=[((246, 362), (0.5, 0.5)), ((1688, 353), (15.5, 0.5)), ((233, 871), (0.625, 5.77)),
                              ((1712, 865), (15.5, 5.77)), ((1545, 467), (14, 1.77)), ((847, 871), (6.875, 5.77))]))],
    'huntsman-mini': [('black', 'Black', '#18181a', 'keyboards/razer-huntsman-mini-black.jpg'),
                      ('mercury', 'Mercury', '#eeeef0', 'keyboards/razer-huntsman-mini-mercury.jpg',
                       dict(points=ortho_points((70, 280), 180.5, 15, 5), mask=('rect', -0.38, -0.33, 15.4, 5.41, 0.14)))],
    'nut75': [('orange', 'Orange', '#e8792e', 'keyboards/weikav-nut75-orange.png'),
              ('silver', 'Silver', '#c9cbce', 'keyboards/weikav-nut75-silver.jpg',
               dict(points=ortho_points((85, 335), 51.9, 16, 6.27, 52.2), ppu=56,
                    mask=('rect', -0.25, -0.4, 16.28, 6.72, 0.12), dim=[(15.19, 4.81, 0.22, 0.46)],
                    leds=[{'kind': 'caps', 'x': 15.19, 'y': 4.81, 'w': 0.11, 'h': 0.32, 'color': '#3fd0ff'}],
                    encoders=[{'id': 'K1', 'x': 15.73, 'y': 4.8, 'd': 0.66, 'shape': 'roller', 'w': 0.66, 'h': 0.34,
                               'style': 'silver', 'ccw': 'vol-', 'cw': 'vol+', 'press': 'mute'}]))],
    'pro-x-tkl': [('black', 'Black', '#1c1d1f', 'keyboards/logi-pro-x-tkl-black.png'),
                  ('white', 'White', '#f2f2f2', 'keyboards/logi-pro-x-tkl-white.png'),
                  ('magenta', 'Magenta', '#e0418f', 'keyboards/logi-pro-x-tkl-magenta.png')],
    'mx-keys-s': [('graphite', 'Graphite', '#3a3c40', 'keyboards/logi-mx-keys-s-graphite.png'),
                  ('palegray', 'Pale Gray', '#e4e4e2', 'keyboards/logi-mx-keys-s-palegray.png'),
                  ('black', 'Black', '#16171a', 'keyboards/logi-mx-keys-s-black.png')],
}

# Indicator lights on the photo, centre and size in layout units (boards without one get a glowing Caps key)
LEDS = {
    'mx-keys-s': [{'kind': 'caps', 'x': 1.6, 'y': 2.93, 'w': 0.05}],
    'magic': [{'kind': 'caps', 'x': 0.24, 'y': 3.27, 'w': 0.06, 'color': '#3be05a'}],
    'huntsman-mini': [{'kind': 'caps', 'key': 'capslock', 'style': 'glow'}],
    'blackwidow-v4-75': [{'kind': 'caps', 'key': 'capslock', 'style': 'glow'}],
    'nut65': [{'kind': 'caps', 'key': 'capslock', 'style': 'glow'}],
    'tkl-frost-rgb': [{'kind': 'caps', 'key': 'capslock', 'style': 'glow'}],
    'pro-x-tkl': [{'kind': 'caps', 'x': 9.06, 'y': -0.4, 'w': 0.11}],
    'blackwidow-v4x': [{'kind': 'caps', 'x': 19.01, 'y': 0.49, 'w': 0.09}],
    'nut75': [{'kind': 'caps', 'x': 15.305, 'y': 4.86, 'w': 0.09, 'h': 0.31, 'color': '#3fd0ff'}],
}

# Decorations measured in photo px (converted to layout units through the same homography)
ENCODERS = {
    '75-orange': [dict(id='K1', at=(3405, 1395), r=66, style='black', ccw='vol-', cw='vol+', press='mute'),
                  dict(id='K2', at=(3407, 1545), r=66, style='black', ccw='bright-', cw='bright+', press='play')],
    '65-creator': [dict(id='K1', at=(151, 943), r=30, style='silver', ccw='vol-', cw='vol+', press='mute'),
                   dict(id='K2', at=(238, 943), r=30, style='silver', ccw='bright-', cw='bright+', press='play'),
                   dict(id='K3', at=(2138, 943), r=30, style='silver', ccw='vol-', cw='vol+', press='mute')],
}
SCREENS = {
    '75-orange': [((3312, 1685), (3508, 2225))],
    '65-creator': [((122, 1004), (274, 1238))],
}

# Keycap silhouettes measured on each skin: [left, top, right, bottom] insets from the key cell, and corner radius
CAPS = {
    'rainy75': ([0.05, 0.04, 0.05, 0.1], 0.1),
    'nut65': ([0.06, 0.04, 0.06, 0.12], 0.1),
    'huntsman-mini': ([0.05, 0.03, 0.05, 0.1], 0.08),
    'blackwidow-v4x': ([0.05, 0.03, 0.05, 0.1], 0.08),
    'blackwidow-v4-75': ([0.05, 0.03, 0.05, 0.1], 0.08),
    'nut75': ([0.05, 0.04, 0.05, 0.08], 0.1),
    'pro-x-tkl': ([0.06, 0.04, 0.06, 0.1], 0.1),
    'mx-keys-s': ([0.035, 0.035, 0.035, 0.035], 0.12),
    'unisplit': ([0.04, 0.03, 0.04, 0.06], 0.08),
    'alice': ([0.03, 0.02, 0.03, 0.06], 0.08),
    'hhkb-kana': ([0.03, 0.02, 0.03, 0.05], 0.07),
    'magic': ([0.06, 0.0625, 0.06, 0.0625], 0.09),
    'iso65': ([0.03, 0.02, 0.03, 0.05], 0.07),
    'pink60': ([0.04, 0.03, 0.04, 0.06], 0.08),
    'tkl-frost-rgb': ([0.012, 0.01, 0.035, 0.012], 0.05),
    'tkl-frost': ([0.012, 0.01, 0.035, 0.012], 0.05),
    '75-orange': ([0.012, 0.01, 0.06, 0.02], 0.14),
    '65-creator': ([0.125, 0.09, 0.195, 0.09], 0.16),
    'hhkb-tofu': ([0.012, 0.012, 0.012, 0.012], 0.06),
    'corne': ([0.015, 0.012, 0.015, 0.012], 0.07),
}

# Live clock screens. box: text area in photo px; clean: (area, luminance threshold, grow px) whose bright pixels
# (the clock baked into the photo) are painted over with the surrounding screen background.
# Line y is the cap-height midline and size the font size, both as fractions of the box height.
DISPLAYS = {
    '75-orange': [dict(box=((3337, 1727), (3480, 1837)), clean=(((3350, 1748), (3466, 1813)), 70, 2), lines=[
        dict(format='time', size=0.35, y=0.377, color='#ffffff', weight='medium'),
        dict(format='date', size=0.155, y=0.655, color='#e8d630', weight='regular')])],
    '65-creator': [dict(box=((150, 1068), (258, 1192)), clean=(((148, 1064), (260, 1196)), 150, 4), lines=[
        dict(format='hour', size=0.6, y=0.25, x=0.04, align='left', color='#ffffff', weight='thin'),
        dict(format='minute', size=0.6, y=0.73, x=0.04, align='left', color='#ffffff', weight='thin'),
        dict(format='ampm', size=0.105, y=0.93, x=0.94, align='right', color='#ffffff', weight='regular')]),
        # Status row: connection dot, Bluetooth glyph, battery bars (white/blue icons sit on a bright green streak)
        dict(box=((130, 1224), (258, 1246)), clean=(((131, 1225), (257, 1245)), 170, 2, 'white+blue'), lines=[
            dict(format='btdot', size=0.45, y=0.5, x=0.078, color='#2f7bff'),
            dict(format='bluetooth', size=0.55, y=0.5, x=0.2, color='#ffffff'),
            dict(format='battery', size=0.36, y=0.5, x=0.953, align='right', color='#ffffff')])],
}

LAYOUTS = {
    'tkl-frost-rgb': ('TKL Frost RGB', tkl),
    'tkl-frost': ('TKL Frost', tkl),
    '75-orange': ('75% Orange', k75),
    '65-creator': ('65% Creator', k65),
    'hhkb-tofu': ('60% HHKB', hhkb),
    'corne': ('Corne 42', corne),
    'pink60': ('60% Pink', pink60),
    'hhkb-kana': ('60% HHKB Kana', hhkb_kana),
    'iso65': ('65% ISO DE', iso65),
    'magic': ('Apple Magic Keyboard', magic),
    'alice': ('Alice 40', alice),
    'unisplit': ('Unibody Split', unisplit),
    'mx-keys-s': ('Logitech MX Keys S', mx_keys_s),
    'pro-x-tkl': ('Logitech G Pro X TKL', pro_x_tkl),
    'huntsman-mini': ('Razer Huntsman Mini', huntsman_mini),
    'blackwidow-v4x': ('Razer BlackWidow V4 X', blackwidow_v4x),
    'blackwidow-v4-75': ('Razer BlackWidow V4 75%', blackwidow_v4_75),
    'nut75': ('Weikav Nut75', nut75),
    'nut65': ('Weikav Nut65', nut65),
    'rainy75': ('Wobkey Rainy 75', rainy75),
}


def homography(pairs):
    """H mapping layout units -> photo px, least squares DLT."""
    import numpy as np
    A = []
    for (px, py), (ux, uy) in pairs:
        A.append([ux, uy, 1, 0, 0, 0, -px * ux, -px * uy, -px])
        A.append([0, 0, 0, ux, uy, 1, -py * ux, -py * uy, -py])
    _, _, vt = np.linalg.svd(np.array(A, dtype=float))
    H = vt[-1].reshape(3, 3)
    return H / H[2, 2]


def apply_h(H, p):
    import numpy as np
    v = H @ np.array([p[0], p[1], 1.0])
    return v[0] / v[2], v[1] / v[2]


def make_skin(lid, spec, keys, ppu=120):
    import numpy as np
    from PIL import Image, ImageDraw, ImageFilter
    from scipy import ndimage as nd

    H = homography(spec['points'])
    err = [math.dist(apply_h(H, u), p) for p, u in spec['points']]
    x0, y0, x1, y1 = spec['region']
    # Small photos are drawn about twice their size on Retina screens: render them larger and sharpen
    cu, cv = (x0 + x1) / 2, (y0 + y1) / 2
    src_ppu = math.dist(apply_h(H, (cu, cv)), apply_h(H, (cu + 1, cv)))
    enhance = spec.get('enhance', True) and src_ppu < 80
    if enhance:
        ppu = max(ppu, 110)
    W, Hh = int((x1 - x0) * ppu), int((y1 - y0) * ppu)
    A = np.array([[1 / ppu, 0, x0], [0, 1 / ppu, y0], [0, 0, 1]])
    M = H @ A
    M = M / M[2, 2]
    photo = Image.open(os.path.join(ROOT, spec['photo']))
    photo = photo.convert('RGBA')
    warped = photo.transform((W, Hh), Image.Transform.PERSPECTIVE, data=tuple(M.flatten()[:8]), resample=Image.Resampling.BICUBIC)
    if enhance:
        rgb, a = warped.convert('RGB'), warped.getchannel('A')
        rgb = rgb.filter(ImageFilter.UnsharpMask(radius=max(1.0, ppu / src_ppu * 0.9), percent=70, threshold=1))
        warped = Image.merge('RGBA', (*rgb.split(), a))

    kind = spec['mask'][0]
    if kind == 'alpha':
        alpha = warped.getchannel('A')
    elif kind == 'rect':
        _, mx0, my0, mx1, my1, rr = spec['mask']
        if spec.get('snap'):
            mx0, my0, mx1, my1 = snap_rect(warped, (mx0, my0, mx1, my1), x0, y0, ppu)
            print(f'  {lid}: case edge snapped to x {mx0:.3f}..{mx1:.3f}, y {my0:.3f}..{my1:.3f}')
        ss = 4
        m = Image.new('L', (W * ss, Hh * ss), 0)
        ImageDraw.Draw(m).rounded_rectangle(
            [((mx0 - x0) * ppu * ss, (my0 - y0) * ppu * ss), ((mx1 - x0) * ppu * ss, (my1 - y0) * ppu * ss)],
            radius=rr * ppu * ss, fill=255)
        alpha = m.resize((W, Hh), Image.Resampling.LANCZOS)
    elif kind == 'keys':
        _, pad, polys = spec['mask']
        ss = 4
        m = Image.new('L', (W * ss, Hh * ss), 0)
        d = ImageDraw.Draw(m)

        def px(ux, uy):
            return ((ux - x0) * ppu * ss, (uy - y0) * ppu * ss)
        for k in keys:
            if k.get('group') != spec.get('group'):
                continue
            w, h = k.get('w', 1), k.get('h', 1)
            cx, cy, rot = k['x'] + w / 2, k['y'] + h / 2, math.radians(k.get('r', 0))
            pts = []
            for dx, dy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                ex, ey = dx * (w / 2 + pad), dy * (h / 2 + pad)
                pts.append(px(cx + ex * math.cos(rot) - ey * math.sin(rot), cy + ex * math.sin(rot) + ey * math.cos(rot)))
            d.polygon(pts, fill=255)
        for poly in polys:
            d.polygon([px(*p) for p in poly], fill=255)
        hull = np.asarray(m.resize((W, Hh), Image.Resampling.LANCZOS)) > 127
        # Thin case frames leave a sliver of the (wooden) background inside the hull: drop warm, saturated
        # pixels, but only in a narrow band along the hull edge so coloured details inside stay
        rgb = np.asarray(warped.convert('RGB')).astype(float)
        mx, mn = rgb.max(axis=2), rgb.min(axis=2)
        sat = (mx - mn) / np.maximum(mx, 1)
        warm = (sat > 0.12) & (rgb[..., 0] > rgb[..., 2] + 10)
        band = hull & ~nd.binary_erosion(hull, iterations=max(1, int(0.12 * ppu)))
        fg = hull & ~(nd.binary_opening(warm & band, iterations=1))
        fg = nd.binary_opening(fg, iterations=1)
        alpha = Image.fromarray((fg * 255).astype('uint8')).filter(ImageFilter.GaussianBlur(1.2))
    elif kind == 'outline':
        # Neutral (aluminium, white caps, black PCB) pixels inside a case outline, plus every key footprint
        _, poly, *solid = spec['mask']
        ss = 2
        m = Image.new('L', (W * ss, Hh * ss), 0)
        d = ImageDraw.Draw(m)
        d.polygon([((ux - x0) * ppu * ss, (uy - y0) * ppu * ss) for ux, uy in poly], fill=255)
        for sp in solid:
            d.polygon([((ux - x0) * ppu * ss, (uy - y0) * ppu * ss) for ux, uy in sp], fill=128)
        for k in keys:
            if k.get('group') != spec.get('group'):
                continue
            w, h = k.get('w', 1), k.get('h', 1)
            cx, cy, rot = k['x'] + w / 2, k['y'] + h / 2, math.radians(k.get('r', 0))
            pts = []
            for dx, dy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                ex, ey = dx * (w / 2 - 0.03), dy * (h / 2 - 0.03)
                pts.append((((cx + ex * math.cos(rot) - ey * math.sin(rot)) - x0) * ppu * ss,
                            ((cy + ex * math.sin(rot) + ey * math.cos(rot)) - y0) * ppu * ss))
            d.polygon(pts, fill=128)
        m = np.asarray(m.resize((W, Hh), Image.Resampling.NEAREST))
        inside, keyfoot = m > 0, m == 128
        rgb = np.asarray(warped.convert('RGB')).astype(float) / 255
        mx, mn = rgb.max(axis=2), rgb.min(axis=2)
        sat = nd.uniform_filter(np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0), 5)
        warm = (rgb[..., 0] - rgb[..., 2]) > 0.05
        neutral = (sat < 0.16) | ((nd.uniform_filter(mx, 5) < 0.25) & ~nd.binary_opening(warm, iterations=2))
        fg = (inside & neutral) | keyfoot
        fg = nd.binary_closing(fg, iterations=3)
        fg = nd.binary_fill_holes(fg)
        fg = nd.binary_opening(fg, iterations=3)
        lab, n = nd.label(fg)
        if n > 1:
            fg = lab == (int(np.argmax(nd.sum(fg, lab, range(1, n + 1)))) + 1)
        alpha = Image.fromarray((fg * 255).astype('uint8')).filter(ImageFilter.GaussianBlur(1.0))
    elif kind == 'custom':
        # Board module supplies fn(rgba array, keys of this group, x0, y0, ppu) -> bool foreground
        group_keys = [k for k in keys if k.get('group') == spec.get('group', k.get('group'))]
        fg = spec['mask'][1](np.asarray(warped), group_keys, x0, y0, ppu)
        if isinstance(fg, tuple):
            # The module also repainted the photo (for example over a hand covering the case)
            fg, repainted = fg
            warped = Image.fromarray(repainted.astype('uint8'), 'RGBA')
        alpha = Image.fromarray((fg * 255).astype('uint8')).filter(ImageFilter.GaussianBlur(1.0))
    elif kind == 'background':
        # Product shot on a plain white background: everything darker than it is the keyboard
        _, thr = spec['mask']
        rgb = np.asarray(warped.convert('RGB')).astype(float)
        valid = np.asarray(warped.getchannel('A')) > 0
        fg = (rgb.min(axis=2) < thr) & valid
        fg = nd.binary_closing(fg, iterations=3)
        fg = nd.binary_fill_holes(fg)
        fg = nd.binary_opening(fg, iterations=2)
        lab, n = nd.label(fg)
        if n > 1:
            fg = lab == (int(np.argmax(nd.sum(fg, lab, range(1, n + 1)))) + 1)
        alpha = Image.fromarray((fg * 255).astype('uint8')).filter(ImageFilter.GaussianBlur(0.8))
    elif kind == 'pad':
        # Case hugging the keys: footprints grown by `pad`, notches up to `close` filled (for clear/frosted cases)
        _, pad, close, *trim = spec['mask']  # optional trim: (darkness threshold, band width)
        blob = Image.new('L', (W, Hh), 0)
        d = ImageDraw.Draw(blob)
        for k in keys:
            if spec.get('group') and k.get('group') != spec['group']:
                continue
            w, h = k.get('w', 1), k.get('h', 1)
            cx, cy, rot = k['x'] + w / 2, k['y'] + h / 2, math.radians(k.get('r', 0))
            pts = []
            for dx, dy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                ex, ey = dx * w / 2, dy * h / 2
                pts.append(((cx + ex * math.cos(rot) - ey * math.sin(rot) - x0) * ppu,
                            (cy + ex * math.sin(rot) + ey * math.cos(rot) - y0) * ppu))
            d.polygon(pts, fill=255)
        m = int((pad + close) * ppu) + 2  # border so the closing does not stick to the image edge
        blob = np.pad(np.asarray(blob) > 0, m)
        grown = nd.distance_transform_edt(~blob) <= (pad + close) * ppu
        fg = (nd.distance_transform_edt(grown) > close * ppu)[m:-m, m:-m]
        if trim:
            # Drop dark background the hull overlaps, only near its edge so dark plates inside stay
            thr, band_w = trim
            lum = nd.gaussian_filter(np.asarray(warped.convert('L')).astype(float), 1.0)
            band = fg & (nd.distance_transform_edt(fg) <= band_w * ppu)
            fg = fg & ~(band & (lum < thr))
            fg = nd.binary_opening(fg, iterations=2)
            fg = nd.binary_fill_holes(fg)
            lab, n = nd.label(fg)
            if n > 1:
                fg = lab == (int(np.argmax(nd.sum(fg, lab, range(1, n + 1)))) + 1)
        alpha = Image.fromarray((fg * 255).astype('uint8')).filter(ImageFilter.GaussianBlur(1.5))
    elif kind == 'bright':
        # Light case on a dark background: bright pixels near the keys, plus the keys themselves, holes filled
        _, thr, pad = spec['mask']
        blob = Image.new('L', (W, Hh), 0)
        d = ImageDraw.Draw(blob)
        for k in keys:
            if spec.get('group') and k.get('group') != spec['group']:
                continue
            w, h = k.get('w', 1), k.get('h', 1)
            cx, cy, rot = k['x'] + w / 2, k['y'] + h / 2, math.radians(k.get('r', 0))
            pts = []
            for dx, dy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                ex, ey = dx * w / 2, dy * h / 2
                pts.append(((cx + ex * math.cos(rot) - ey * math.sin(rot) - x0) * ppu,
                            (cy + ex * math.sin(rot) + ey * math.cos(rot) - y0) * ppu))
            d.polygon(pts, fill=255)
        blob = np.asarray(blob) > 0
        lum = nd.gaussian_filter(np.asarray(warped.convert('L')).astype(float), 1.5)
        near = nd.binary_dilation(blob, iterations=int(pad * ppu))
        fg = ((lum > thr) & near) | blob
        fg = nd.binary_closing(fg, iterations=6)
        fg = nd.binary_fill_holes(fg)
        lab, n = nd.label(fg)
        if n > 1:
            sizes = nd.sum(fg, lab, range(1, n + 1))
            fg = lab == (int(np.argmax(sizes)) + 1)
        fg = nd.binary_opening(fg, iterations=3)
        alpha = Image.fromarray((fg * 255).astype('uint8')).filter(ImageFilter.GaussianBlur(1.2))
    else:
        a = np.asarray(warped.convert('RGB')).astype(float) / 255
        valid = np.asarray(warped.getchannel('A')) > 0
        mx, mn = a.max(axis=2), a.min(axis=2)
        sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
        sat = nd.uniform_filter(sat, 5)
        fg = ((sat < 0.13) | (mx < 0.22)) & valid
        seeds = np.zeros_like(fg)
        for _, (ux, uy) in spec['points']:
            seeds[int((uy - y0) * ppu), int((ux - x0) * ppu)] = True
        fg = nd.binary_opening(fg, iterations=3)
        lab, _ = nd.label(fg)
        ids = np.unique(lab[seeds])
        fg = np.isin(lab, ids[ids > 0])
        fg = nd.binary_closing(fg, iterations=6)
        fg = nd.binary_fill_holes(fg)
        fg = nd.binary_opening(fg, iterations=4)
        alpha = Image.fromarray((fg * 255).astype('uint8')).filter(ImageFilter.GaussianBlur(1.2))
    warped.putalpha(alpha)
    if spec.get('flatten_light'):
        # Even out uneven lighting (a sunlit half, a shadowed half) toward the board's median brightness
        arr = np.asarray(warped).astype(float)
        inside = (arr[..., 3] > 128).astype(float)
        lum = arr[..., :3].mean(axis=2)
        sigma = ppu * 1.2
        illum = nd.gaussian_filter(lum * inside, sigma) / np.maximum(nd.gaussian_filter(inside, sigma), 1e-3)
        target = np.median(illum[inside > 0])
        gain = np.clip(target / np.maximum(illum, 1), 0.55, 1.8) ** spec['flatten_light']
        arr[..., :3] = np.clip(arr[..., :3] * gain[..., None], 0, 255)
        warped = Image.fromarray(arr.astype('uint8'), 'RGBA')
    warped = dim_lights(warped, spec.get('dim', []), x0, y0, ppu)
    warped = clean_displays(lid, warped, H, x0, y0, ppu)
    warped = clean_remapped(warped, [k for k in keys if k.get('remap') and k.get('group') == spec.get('group', k.get('group'))],
                            x0, y0, ppu)
    key_caps = None
    if spec.get('fit_caps', True):
        base = CAPS.get(lid, ([0.03, 0.03, 0.03, 0.03], 0.1))[0]
        group_keys = [k for k in keys if k.get('group') == spec.get('group', k.get('group'))]
        # Colourway photos keep their own per-key caps; the plain skin writes them onto the keys
        key_caps = {} if spec.get('variant') else None
        n = fit_caps(warped, group_keys, x0, y0, ppu, base, key_caps)
        print(f'  {lid}: per-key caps fitted on {n} keys')
    skin_dir = os.path.join(OUT, f'{lid}-skin')
    os.makedirs(skin_dir, exist_ok=True)
    name = f"{spec['variant']}-{spec.get('group', 'board')}.png" if spec.get('variant') else f"{spec.get('group', 'board')}.png"
    warped.save(os.path.join(skin_dir, name), optimize=True)
    print(f'  {lid}/{name}: {W}x{Hh}, fit error px mean {sum(err) / len(err):.1f} max {max(err):.1f}')
    skin = {'group': spec.get('group', 'board'), 'image': f'{lid}-skin/{name}',
            'x': x0, 'y': y0, 'w': round(x1 - x0, 4), 'h': round(y1 - y0, 4)}
    if key_caps:
        skin['_caps'] = key_caps
    return skin


def fit_caps(img, keys, x0, y0, ppu, base, out=None):
    """Measure where each keycap's outline really sits in the warped photo and set per-key insets.

    Each side is found as the strongest brightness edge near the expected inset, then a smooth model
    (inset = a + b*x + c*y over the board) is fitted so printed legends or odd caps cannot throw it off.
    Tall caps photographed from above lean outward, which is what the linear terms capture."""
    import numpy as np
    from scipy import ndimage as nd
    arr = np.asarray(img).astype(float)
    lum = nd.gaussian_filter(arr[..., :3].mean(axis=2), 1.0)
    alpha = arr[..., 3]
    gy, gx = np.abs(np.gradient(lum))
    Hh, W = lum.shape
    u = ppu
    samples = {s: [] for s in range(4)}
    plain = [k for k in keys if 'x2' not in k]
    margin = 0.12
    for k in plain:
        w, h = k.get('w', 1), k.get('h', 1)
        rot = math.radians(k.get('r', 0))
        cx, cy = (k['x'] + w / 2 - x0) * u, (k['y'] + h / 2 - y0) * u
        if not (2 <= cx < W - 3 and 2 <= cy < Hh - 3) or alpha[int(cy), int(cx)] < 200:
            continue
        # Sample the key in its own (rotated) frame so tilted keys are measured like straight ones
        nx, ny = int((w + 2 * margin) * u), int((h + 2 * margin) * u)
        lx = np.arange(nx) / u - (w / 2 + margin)
        ly = np.arange(ny) / u - (h / 2 + margin)
        LX, LY = np.meshgrid(lx, ly)
        px = cx + (LX * math.cos(rot) - LY * math.sin(rot)) * u
        py = cy + (LX * math.sin(rot) + LY * math.cos(rot)) * u
        patch = nd.map_coordinates(lum, [py, px], order=1, mode='nearest')
        pgy, pgx = np.abs(np.gradient(patch))
        X0, X1 = margin * u, (margin + w) * u
        Y0, Y1 = margin * u, (margin + h) * u
        rows = slice(int(Y0 + 0.3 * (Y1 - Y0)), int(Y0 + 0.7 * (Y1 - Y0)) + 1)
        cols = slice(int(X0 + 0.3 * (X1 - X0)), int(X0 + 0.7 * (X1 - X0)) + 1)

        def pick(profile, start, expected):
            if len(profile) == 0:
                return expected
            pos = np.arange(len(profile)) + start
            prior = np.exp(-0.5 * ((pos - expected) / (0.12 * u)) ** 2)
            return pos[int(np.argmax(profile * (0.35 + prior)))]
        lo, hi = max(0, int(X0 - 0.06 * u)), int(X0 + 0.3 * u)
        xl = pick(pgx[rows, lo:hi].mean(axis=0), lo, X0 + base[0] * u)
        lo, hi = int(X1 - 0.3 * u), min(nx, int(X1 + 0.06 * u))
        xr = pick(pgx[rows, lo:hi].mean(axis=0), lo, X1 - base[2] * u)
        lo, hi = max(0, int(Y0 - 0.06 * u)), int(Y0 + 0.3 * u)
        yt = pick(pgy[lo:hi, cols].mean(axis=1), lo, Y0 + base[1] * u)
        lo, hi = int(Y1 - 0.35 * u), min(ny, int(Y1 + 0.06 * u))
        yb = pick(pgy[lo:hi, cols].mean(axis=1), lo, Y1 - base[3] * u)
        pu, pv = k['x'] + w / 2, k['y'] + h / 2
        for side, val in enumerate(((xl - X0) / u, (yt - Y0) / u, (X1 - xr) / u, (Y1 - yb) / u)):
            samples[side].append((pu, pv, val))
    if len(samples[0]) < 8:
        return 0
    models = []
    for side in range(4):
        a = np.array(samples[side])
        A = np.c_[np.ones(len(a)), a[:, 0], a[:, 1]]
        keep = np.ones(len(a), bool)
        for _ in range(4):
            coef, *_ = np.linalg.lstsq(A[keep], a[keep, 2], rcond=None)
            res = np.abs(A @ coef - a[:, 2])
            mad = np.median(res[keep]) + 1e-3
            keep = res < 2.5 * mad + 0.01
        if np.median(res[keep]) > 0.05:
            coef = np.array([np.median(a[:, 2]), 0, 0])
        models.append(coef)
    changed = 0
    for k in plain:
        w, h = k.get('w', 1), k.get('h', 1)
        pu, pv = k['x'] + w / 2, k['y'] + h / 2
        ins = [float(np.clip(m[0] + m[1] * pu + m[2] * pv, -0.05, 0.3)) for m in models]
        if out is not None:
            out[k['id']] = [round(i, 3) for i in ins]
            changed += 1
        elif max(abs(i - b) for i, b in zip(ins, base)) > 0.01:
            k['cap'] = [round(i, 3) for i in ins]
            changed += 1
        else:
            k.pop('cap', None)
    return changed


def snap_rect(img, rect, x0, y0, ppu, inward=0.18, outward=0.06):
    """Move each side of a hand-measured case rectangle onto the case/background boundary.

    Scans a band across each side, takes the median luminance gradient along the middle half of that side
    (corners are rounded), and keeps the outermost strong edge so inner bevels are not picked."""
    import numpy as np
    lum = np.asarray(img.convert('L')).astype(float)
    Hh, W = lum.shape
    X0, Y0, X1, Y1 = [(v - o) * ppu for v, o in zip(rect, (x0, y0, x0, y0))]
    a, b = int(inward * ppu), int(outward * ppu)

    def edge(profile, outer_first):
        g = np.abs(np.diff(profile))
        if g.size == 0 or g.max() <= 0:
            return None
        idx = range(g.size) if outer_first else range(g.size - 1, -1, -1)
        return next(i for i in idx if g[i] >= 0.6 * g.max())

    ys = slice(int(Y0 + (Y1 - Y0) * 0.25), int(Y0 + (Y1 - Y0) * 0.75))
    xs = slice(int(X0 + (X1 - X0) * 0.25), int(X0 + (X1 - X0) * 0.75))
    out = list(rect)
    lo, hi = max(0, int(X0) - b), min(W - 1, int(X0) + a)
    e = edge(np.median(lum[ys, lo:hi], axis=0), True)
    if e is not None: out[0] = (lo + e + 1) / ppu + x0
    lo, hi = max(0, int(X1) - a), min(W - 1, int(X1) + b)
    e = edge(np.median(lum[ys, lo:hi], axis=0), False)
    if e is not None: out[2] = (lo + e) / ppu + x0
    lo, hi = max(0, int(Y0) - b), min(Hh - 1, int(Y0) + a)
    e = edge(np.median(lum[lo:hi, xs], axis=1), True)
    if e is not None: out[1] = (lo + e + 1) / ppu + y0
    lo, hi = max(0, int(Y1) - a), min(Hh - 1, int(Y1) + b)
    e = edge(np.median(lum[lo:hi, xs], axis=1), False)
    if e is not None: out[3] = (lo + e) / ppu + y0
    return out


def dim_lights(img, lights, x0, y0, ppu):
    """Turn off an indicator that was lit in the photo (pill at centre x, y of size w x h, layout units)."""
    import numpy as np
    from PIL import Image, ImageDraw, ImageFilter
    if not lights:
        return img
    arr = np.asarray(img).astype(float)
    m = Image.new('L', img.size, 0)
    d = ImageDraw.Draw(m)
    for x, y, w, h in lights:
        box = [(x - w / 2 - x0) * ppu, (y - h / 2 - y0) * ppu, (x + w / 2 - x0) * ppu, (y + h / 2 - y0) * ppu]
        d.rounded_rectangle(box, radius=min(w, h) / 2 * ppu, fill=255)
    k = np.asarray(m.filter(ImageFilter.GaussianBlur(1.5))).astype(float)[..., None] / 255
    rgb = arr[..., :3]
    off = np.repeat(rgb.mean(axis=2, keepdims=True) * 0.45 + 18, 3, axis=2)
    arr[..., :3] = rgb * (1 - k) + off * k
    return Image.fromarray(np.clip(arr, 0, 255).astype('uint8'), 'RGBA')


def clean_remapped(img, keys, x0, y0, ppu):
    """Wipe the printed legend off remapped keycaps so the app can print the real function there."""
    import numpy as np
    from PIL import Image, ImageDraw
    from scipy import ndimage as nd
    if not keys:
        return img
    arr = np.asarray(img).astype(float)
    Hh, W = arr.shape[:2]
    for k in keys:
        w, h = k.get('w', 1), k.get('h', 1)
        cx, cy, rot = k['x'] + w / 2, k['y'] + h / 2, math.radians(k.get('r', 0))
        pts = []
        for dx, dy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            ex, ey = dx * (w / 2 - 0.09), dy * (h / 2 - 0.08)
            pts.append(((cx + ex * math.cos(rot) - ey * math.sin(rot) - x0) * ppu,
                        (cy + ex * math.sin(rot) + ey * math.cos(rot) - y0) * ppu))
        m = Image.new('L', (W, Hh), 0)
        ImageDraw.Draw(m).polygon(pts, fill=255)
        area = np.asarray(m) > 0
        rgb = arr[..., :3]
        lum = rgb.mean(axis=2)
        sat = (rgb.max(axis=2) - rgb.min(axis=2)) / np.maximum(rgb.max(axis=2), 1)
        local = nd.median_filter(lum, size=int(ppu * 0.35) | 1)
        ink = area & ((lum < local - 18) | (sat > 0.2))
        ink = nd.binary_dilation(ink, iterations=3) & area
        known = area & ~ink
        todo = ink.copy()
        for sigma in (2, 4, 8, 16):
            wgt = nd.gaussian_filter(known.astype(float), sigma)
            est = np.stack([nd.gaussian_filter(rgb[..., c] * known, sigma) for c in range(3)], -1) / np.maximum(wgt, 1e-6)[..., None]
            ok = todo & (wgt > 0.2)
            arr[..., :3][ok] = est[ok]
            todo &= ~ok
    return Image.fromarray(np.clip(arr, 0, 255).astype('uint8'), 'RGBA')


def clean_displays(lid, img, H, x0, y0, ppu):
    """Paint over the clock baked into the photo so the app can draw the live time there."""
    import numpy as np
    from PIL import Image
    from scipy import ndimage as nd
    if lid not in DISPLAYS:
        return img
    Hinv = np.linalg.inv(H)
    arr = np.asarray(img).astype(float)
    for disp in DISPLAYS[lid]:
        (a, b), thr, grow, *mode = disp['clean']
        ax, ay = apply_h(Hinv, a)
        bx, by = apply_h(Hinv, b)
        X0, Y0 = int((ax - x0) * ppu), int((ay - y0) * ppu)
        X1, Y1 = int(math.ceil((bx - x0) * ppu)), int(math.ceil((by - y0) * ppu))
        sub = arr[Y0:Y1, X0:X1, :3]
        lum = sub.mean(axis=2)
        if mode and mode[0] == 'white+blue':
            hit = (sub.min(axis=2) > thr) | ((sub[..., 2] - sub[..., 0] > 80) & (sub[..., 2] > 170))
        else:
            hit = lum > thr
        mask = nd.binary_dilation(hit, iterations=grow)
        # Digits often carry a dark drop shadow: treat pixels much darker than the local background as text too
        local = nd.median_filter(lum, size=41)
        mask |= nd.binary_dilation(lum < local - 18, iterations=2) & nd.binary_dilation(mask, iterations=grow * 2)
        known = ~mask
        out = sub.copy()
        todo = mask.copy()
        for sigma in (3, 6, 12, 24):
            w = nd.gaussian_filter(known.astype(float), sigma)
            est = np.stack([nd.gaussian_filter(sub[..., c] * known, sigma) for c in range(3)], -1) / np.maximum(w, 1e-6)[..., None]
            ok = todo & (w > 0.15)
            out[ok] = est[ok]
            todo &= ~ok
        arr[Y0:Y1, X0:X1, :3] = out
    return Image.fromarray(np.clip(arr, 0, 255).astype('uint8'), 'RGBA')


def photo_to_units(lid, p):
    import numpy as np
    H = homography(SKINS[lid][0]['points'])
    return apply_h(np.linalg.inv(H), p)


def decorations(lid, data):
    if lid in ENCODERS:
        H = homography(SKINS[lid][0]['points'])
        scale = math.dist(apply_h(H, (0, 0)), apply_h(H, (1, 0)))
        encs = []
        for e in ENCODERS[lid]:
            x, y = photo_to_units(lid, e['at'])
            encs.append({'id': e['id'], 'group': 'board', 'x': round(x, 3), 'y': round(y, 3), 'd': round(2 * e['r'] / scale, 3),
                         'style': e['style'], 'ccw': e['ccw'], 'cw': e['cw'], 'press': e['press']})
        data['encoders'] = encs
    if lid in SCREENS:
        covers = data.setdefault('covers', [])
        for a, b in SCREENS[lid]:
            ax, ay = photo_to_units(lid, a)
            bx, by = photo_to_units(lid, b)
            covers.append({'group': 'board', 'x': round(ax, 3), 'y': round(ay, 3), 'w': round(bx - ax, 3), 'h': round(by - ay, 3),
                           'color': '#121212', 'r': 0.12})
    if lid in DISPLAYS:
        displays = []
        for disp in DISPLAYS[lid]:
            a, b = disp['box']
            ax, ay = photo_to_units(lid, a)
            bx, by = photo_to_units(lid, b)
            displays.append({'group': 'board', 'x': round(ax, 3), 'y': round(ay, 3), 'w': round(bx - ax, 3),
                             'h': round(by - ay, 3), 'lines': disp['lines']})
        data['displays'] = displays


def dump(path, data):
    def j(v):
        return json.dumps(v, ensure_ascii=False)
    lines = ['{']
    items = list(data.items())
    for i, (k, v) in enumerate(items):
        comma = ',' if i < len(items) - 1 else ''
        if isinstance(v, list):
            lines.append(f'  {j(k)}: [')
            lines += [f'    {j(e)}' + (',' if n < len(v) - 1 else '') for n, e in enumerate(v)]
            lines.append('  ]' + comma)
        elif isinstance(v, dict) and k == 'groups':
            lines.append(f'  {j(k)}: {{')
            g = list(v.items())
            lines += [f'    {j(a)}: {j(b)}' + (',' if n < len(g) - 1 else '') for n, (a, b) in enumerate(g)]
            lines.append('  }' + comma)
        else:
            lines.append(f'  {j(k)}: {j(v)}' + comma)
    lines.append('}')
    open(path, 'w').write('\n'.join(lines) + '\n')


def load_boards():
    """Boards defined in tools/boards/*.py: each module has register(helpers) returning a dict with
    id, name, layout (function), skins, and optional caps, leds, colorways."""
    import importlib.util, types
    helpers = types.SimpleNamespace(build_rows=build_rows, set_layer=set_layer, fn_row_media=fn_row_media, label=label,
                                    board=board, ortho_points=ortho_points, homography=homography, apply_h=apply_h,
                                    G=G, NUM=NUM, FN_LAYERS=FN_LAYERS)
    folder = os.path.join(ROOT, 'tools', 'boards')
    for f in sorted(os.listdir(folder)) if os.path.isdir(folder) else []:
        if not f.endswith('.py') or f.startswith('_'):
            continue
        spec = importlib.util.spec_from_file_location(f[:-3], os.path.join(folder, f))
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        b = mod.register(helpers)
        LAYOUTS[b['id']] = (b['name'], b['layout'])
        SKINS[b['id']] = b['skins']
        for key, table in (('caps', CAPS), ('leds', LEDS), ('colorways', COLORWAYS), ('displays', DISPLAYS)):
            if key in b:
                table[b['id']] = b[key]


def main():
    load_boards()
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    skins = '--skin' in sys.argv
    for lid in args or LAYOUTS:
        name, fn = LAYOUTS[lid]
        data = {'name': name, **fn()}
        for k in data['keys']:
            k.setdefault('group', next(iter(data['groups'])))
        if lid in LEDS:
            data['leds'] = [{'group': next(iter(data['groups'])), **l} for l in LEDS[lid]]
        path = os.path.join(OUT, f'{lid}.json')
        if lid in SKINS:
            try:
                decorations(lid, data)
            except ImportError:
                pass
            if skins and lid in COLORWAYS:
                data['colorways'] = [{'id': cid, 'name': cname, 'swatch': sw,
                                      **{key: [{'group': next(iter(data['groups'])), **l} for l in extra[0][key]]
                                         for key in ('leds', 'encoders') if extra and key in extra[0]},
                                      'skins': [make_skin(lid, sp, data['keys'], ppu=sp.get('ppu', 120)) for sp in
                                                [{**s, 'photo': photo, 'variant': cid, **(extra[0] if extra else {})}
                                                 for s in SKINS[lid]]]}
                                     for cid, cname, sw, photo, *extra in COLORWAYS[lid]]
                for cw in data['colorways']:
                    caps = {}
                    for sk in cw['skins']:
                        caps.update(sk.pop('_caps', {}))
                    if caps:
                        cw['keyCaps'] = caps
                for k in data['keys']:
                    if k['id'] in data['colorways'][0].get('keyCaps', {}):
                        k['cap'] = data['colorways'][0]['keyCaps'][k['id']]
                data['skins'] = data['colorways'][0]['skins']
            elif skins:
                data['skins'] = [make_skin(lid, s, data['keys'], ppu=s.get('ppu', 120)) for s in SKINS[lid]]
            elif os.path.exists(path):
                prev = json.load(open(path))
                caps_by_id = {k['id']: k['cap'] for k in prev.get('keys', []) if 'cap' in k}
                for k in data['keys']:
                    if k['id'] in caps_by_id:
                        k['cap'] = caps_by_id[k['id']]
                for key in ('skins', 'colorways'):
                    if key in prev:
                        data[key] = prev[key]
                for key in ('encoders',):
                    if key in prev and key not in data:
                        data[key] = prev[key]
            if '--fit-caps' in sys.argv and 'colorways' not in data:
                from PIL import Image
                for sk in data.get('skins', []):
                    img = Image.open(os.path.join(OUT, sk['image'])).convert('RGBA')
                    group_keys = [k for k in data['keys'] if k.get('group') == sk['group']]
                    n = fit_caps(img, group_keys, sk['x'], sk['y'], img.width / sk['w'],
                                 CAPS.get(lid, ([0.03, 0.03, 0.03, 0.03], 0.1))[0])
                    print(f'  {lid}/{sk["group"]}: per-key caps fitted on {n} keys')
            data['skinLegends'] = True  # every photo here has printed legends
            if any(k.get('remap') for k in data['keys']):
                data['remapCleaned'] = True
            if lid in CAPS:
                data['cap'] = {'inset': CAPS[lid][0], 'radius': CAPS[lid][1]}
        dump(path, data)
        print(lid, len(data['keys']), 'keys')


if __name__ == '__main__':
    main()
