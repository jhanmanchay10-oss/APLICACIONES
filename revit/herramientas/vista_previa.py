# -*- coding: utf-8 -*-
"""Vista previa del modelo SIN Revit: exporta OBJ y renderiza PNG.

Uso:  python3 revit/herramientas/vista_previa.py [carpeta_salida]
Requiere numpy y matplotlib solo para el PNG.
"""
import importlib.util
import math
import os
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(AQUI, "..", "AndamioTalud.extension", "AndamioTalud.tab",
                      "Modelado.panel", "AndamioTalud.pushbutton", "script.py")
spec = importlib.util.spec_from_file_location("andamio", SCRIPT)
andamio = importlib.util.module_from_spec(spec)
spec.loader.exec_module(andamio)


def mallas(prim, segs=10):
    """Devuelve (vertices, caras) de una primitiva."""
    t = prim[0]
    if t == "cil":
        a, b, r = prim[1], prim[2], prim[3]
        d = [b[i] - a[i] for i in range(3)]
        L = math.sqrt(sum(c * c for c in d))
        n = [c / L for c in d]
        ref = (0, 0, 1) if abs(n[2]) < 0.99 else (1, 0, 0)
        u = cross(n, ref); u = norm(u); v = cross(n, u)
        vs = []
        for p in (a, b):
            for k in range(segs):
                ang = 2 * math.pi * k / segs
                vs.append(tuple(p[i] + r * (math.cos(ang) * u[i] + math.sin(ang) * v[i])
                                for i in range(3)))
        fs = [(k, (k + 1) % segs, segs + (k + 1) % segs, segs + k) for k in range(segs)]
        fs.append(tuple(range(segs))); fs.append(tuple(range(2 * segs - 1, segs - 1, -1)))
        return vs, fs
    if t in ("caja", "losa"):
        if t == "caja":
            (x0, y0, z0), (x1, y1, z1) = prim[1], prim[2]
        else:
            (x0, y0, x1, y1), z0, z1 = prim[1], prim[2], prim[3]
        vs = [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
              (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]
        fs = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
        return vs, fs
    if t == "perfil_y":
        pts, y0, y1 = prim[1], prim[2], prim[3]
        n = len(pts)
        vs = [(x, y0, z) for x, z in pts] + [(x, y1, z) for x, z in pts]
        fs = [(k, (k + 1) % n, n + (k + 1) % n, n + k) for k in range(n)]
        return vs, fs
    raise ValueError(t)


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def norm(a):
    L = math.sqrt(sum(c * c for c in a)); return tuple(c / L for c in a)


def main(out):
    os.makedirs(out, exist_ok=True)
    m = andamio.Modelo().construir()
    grupos = {}
    for el in m.elementos:
        grupos[el["grupo"]] = grupos.get(el["grupo"], 0) + 1
    print("Elementos:", len(m.elementos))
    for g, c in sorted(grupos.items()):
        print("  %-26s %d" % (g, c))
    print("Husillos:", {k: round(v, 3) for k, v in m.husillos.items()})
    print("Montantes:", {k: tuple(round(z, 2) for z in v) for k, v in m.montantes.items()})

    # OBJ
    with open(os.path.join(out, "andamio_talud.obj"), "w") as f:
        base = 1
        for el in m.elementos:
            f.write("g %s\n" % el["nombre"].replace(" ", "_"))
            for p in el["prims"]:
                vs, fs = mallas(p)
                for v in vs:  # OBJ con Y arriba
                    f.write("v %.4f %.4f %.4f\n" % (v[0], v[2], -v[1]))
                for fc in fs:
                    f.write("f " + " ".join(str(base + i) for i in fc) + "\n")
                base += len(vs)

    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
        from mpl_toolkits.mplot3d.art3d import Poly3DCollection
    except ImportError:
        return
    colores = {k: tuple(c / 255.0 for c in v) for k, v in andamio.MATERIALES.items()}
    for nombre, elev, azim in (("iso", 22, -58), ("alzado", 0, -90), ("planta", 90, -90)):
        fig = plt.figure(figsize=(10, 10), dpi=130)
        ax = fig.add_subplot(111, projection="3d")
        for el in m.elementos:
            if el["grupo"] == "Terreno" and nombre == "planta":
                continue
            col = colores[el["material"]]
            for p in el["prims"]:
                vs, fs = mallas(p, 8)
                polys = [[vs[i] for i in fc] for fc in fs]
                ax.add_collection3d(Poly3DCollection(
                    polys, facecolor=col, edgecolor=(0, 0, 0, 0.15) if el["grupo"] != "Terreno" else None,
                    linewidth=0.2, alpha=0.55 if el["grupo"] == "Terreno" else 1.0))
        ax.set_xlim(-1.5, 4.5); ax.set_ylim(-2.2, 3.8); ax.set_zlim(-0.5, 5.5)
        ax.set_box_aspect((1, 1, 1))
        ax.view_init(elev=elev, azim=azim)
        ax.set_xlabel("X (m)"); ax.set_ylabel("Y (m)"); ax.set_zlabel("Z (m)")
        ax.set_title("Andamio sobre talud - %s" % nombre)
        fig.savefig(os.path.join(out, "preview_%s.png" % nombre), bbox_inches="tight")
        plt.close(fig)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "preview")
