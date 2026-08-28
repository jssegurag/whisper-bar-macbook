#!/usr/bin/env python3
"""Devuelve la transparencia a un PNG que qlmanage aplanó sobre blanco.

qlmanage es el único rasterizador de SVG que trae macOS de fábrica, pero compone
el resultado sobre fondo blanco opaco: el PNG sale con alfa 255 en todos los
píxeles. Un icono de plantilla dibujado con ese PNG se ve como un rectángulo
sólido, porque macOS solo usa el canal alfa.

El arte de Gluffi es un color plano sobre blanco, así que el alfa se reconstruye
exactamente. Para cada píxel:  P = a·F + (1-a)·255  →  a = (255-P) / (255-F)
usando el canal donde F está más lejos del blanco.

Uso:  restore-alpha.py entrada.png salida.png [RRGGBB]
      El color por defecto es negro (000000), que es como viene el mark.
Sin dependencias externas: solo zlib y struct de la librería estándar.
"""
import struct, sys, zlib


def read_png(path):
    data = open(path, "rb").read()
    pos, idat, w, h, ct = 8, b"", None, None, None
    while pos < len(data):
        length = struct.unpack(">I", data[pos:pos + 4])[0]
        kind = data[pos + 4:pos + 8]
        chunk = data[pos + 8:pos + 8 + length]
        if kind == b"IHDR":
            w, h, _bd, ct = struct.unpack(">IIBB", chunk[:10])
        elif kind == b"IDAT":
            idat += chunk
        pos += 12 + length
    channels = {0: 1, 2: 3, 4: 2, 6: 4}[ct]
    raw = zlib.decompress(idat)
    stride = w * channels
    out, prev, i = bytearray(), bytearray(stride), 0
    for _ in range(h):
        filt = raw[i]; i += 1
        line = bytearray(raw[i:i + stride]); i += stride
        for x in range(stride):
            a = line[x - channels] if x >= channels else 0
            b = prev[x]
            c = prev[x - channels] if x >= channels else 0
            if filt == 1:
                line[x] = (line[x] + a) & 255
            elif filt == 2:
                line[x] = (line[x] + b) & 255
            elif filt == 3:
                line[x] = (line[x] + (a + b) // 2) & 255
            elif filt == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        out += line
        prev = line
    return w, h, channels, bytes(out)


def write_png(path, w, h, rgba):
    def chunk(kind, payload):
        return (struct.pack(">I", len(payload)) + kind + payload
                + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF))

    raw = b"".join(b"\x00" + rgba[y * w * 4:(y + 1) * w * 4] for y in range(h))
    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(raw, 9))
           + chunk(b"IEND", b""))
    open(path, "wb").write(png)


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 1
    src, dst = sys.argv[1], sys.argv[2]
    hexcolor = sys.argv[3] if len(sys.argv) > 3 else "000000"
    fr, fg, fb = (int(hexcolor[i:i + 2], 16) for i in (0, 2, 4))

    w, h, channels, px = read_png(src)
    # Canal con el mayor contraste contra el blanco: da el alfa más preciso.
    target = [fr, fg, fb]
    best = max(range(3), key=lambda c: 255 - target[c])
    denom = 255 - target[best]
    if denom == 0:
        print("✗ el color del arte es blanco: no se puede separar del fondo")
        return 1

    out = bytearray(w * h * 4)
    for i in range(w * h):
        o = i * channels
        if channels >= 3:
            value = px[o + best]
        else:
            value = px[o]
        alpha = max(0, min(255, round((255 - value) * 255 / denom)))
        out[i * 4:i * 4 + 4] = bytes((fr, fg, fb, alpha))

    write_png(dst, w, h, bytes(out))
    print("✓ %s → %s (color %s, %dx%d)" % (src, dst, hexcolor, w, h))
    return 0


if __name__ == "__main__":
    sys.exit(main())
