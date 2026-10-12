# -*- coding: utf-8 -*-
"""Exporta el andamio sobre talud a IFC (se abre directamente en Revit).

Se usa IFC2x3 Coordination View 2.0 con geometria de caras planas
(IfcFacetedBrep), que es el formato que Revit importa con mas fiabilidad.

Uso:  python3 revit/herramientas/exportar_ifc.py [salida.ifc]
Requiere:  pip install ifcopenshell
"""
import importlib.util
import math
import os
import sys
import time

import ifcopenshell
import ifcopenshell.guid

AQUI = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(AQUI, "..", "AndamioTalud.extension", "AndamioTalud.tab",
                      "Modelado.panel", "AndamioTalud.pushbutton", "script.py")
spec = importlib.util.spec_from_file_location("andamio", SCRIPT)
andamio = importlib.util.module_from_spec(spec)
spec.loader.exec_module(andamio)

SEGMENTOS = 12   # caras por tubo

# grupo del modelo -> (clase IFC, PredefinedType o None)
CLASES = {
    "Terreno": ("IfcBuildingElementProxy", None),
    "Cimentacion": ("IfcFooting", "PAD_FOOTING"),
    "Base regulable": ("IfcMember", None),
    "Montante": ("IfcMember", None),
    "Larguero": ("IfcMember", None),
    "Larguero de plataforma": ("IfcMember", None),
    "Larguero de atado": ("IfcMember", None),
    "Travesano": ("IfcMember", None),
    "Travesano de plataforma": ("IfcMember", None),
    "Barandilla": ("IfcRailing", "GUARDRAIL"),
    "Diagonal": ("IfcMember", None),
    "Anclaje": ("IfcMember", None),
    "Plataforma": ("IfcPlate", None),
    "Rodapie": ("IfcPlate", None),
    "Escalera": ("IfcBuildingElementProxy", None),
}


# -----------------------------------------------------------------------------
# Mallas poligonales (caras con normal hacia fuera)
# -----------------------------------------------------------------------------
def _cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2],
            a[0] * b[1] - a[1] * b[0])


def _norm(a):
    L = math.sqrt(sum(c * c for c in a))
    return tuple(c / L for c in a)


def malla_cilindro(a, b, r):
    n = _norm([b[i] - a[i] for i in range(3)])
    ref = (0, 0, 1) if abs(n[2]) < 0.99 else (1, 0, 0)
    u = _norm(_cross(n, ref))
    v = _cross(n, u)
    s = SEGMENTOS
    vs = []
    for p in (a, b):
        for k in range(s):
            t = 2 * math.pi * k / s
            vs.append(tuple(p[i] + r * (math.cos(t) * u[i] + math.sin(t) * v[i])
                            for i in range(3)))
    caras = [(k, (k + 1) % s, s + (k + 1) % s, s + k) for k in range(s)]
    caras.append(tuple(range(s - 1, -1, -1)))          # base (normal -n)
    caras.append(tuple(range(s, 2 * s)))               # tapa (normal +n)
    return vs, caras


def malla_caja(p0, p1):
    (x0, y0, z0), (x1, y1, z1) = p0, p1
    vs = [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
          (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]
    caras = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5),
             (2, 3, 7, 6), (3, 0, 4, 7)]
    return vs, caras


def malla_perfil_y(pts, y0, y1):
    area = sum(pts[i][0] * pts[(i + 1) % len(pts)][1] -
               pts[(i + 1) % len(pts)][0] * pts[i][1] for i in range(len(pts)))
    if area < 0:                       # orientar antihorario en el plano XZ
        pts = pts[::-1]
    n = len(pts)
    vs = [(x, y0, z) for x, z in pts] + [(x, y1, z) for x, z in pts]
    # antihorario en XZ visto desde -Y => normal -Y en la cara y0
    caras = [(k, n + k, n + (k + 1) % n, (k + 1) % n) for k in range(n)]
    caras.append(tuple(range(n)))
    caras.append(tuple(range(2 * n - 1, n - 1, -1)))
    return vs, caras


def mallas(prim):
    t = prim[0]
    if t == "cil":
        return [malla_cilindro(prim[1], prim[2], prim[3])]
    if t == "caja":
        return [malla_caja(prim[1], prim[2])]
    if t == "losa":
        (x0, y0, x1, y1), z0, z1, hueco = prim[1], prim[2], prim[3], prim[4]
        if not hueco:
            return [malla_caja((x0, y0, z0), (x1, y1, z1))]
        hx0, hy0 = max(hueco[0], x0 + 0.05), max(hueco[1], y0 + 0.05)
        hx1, hy1 = min(hueco[2], x1 - 0.05), min(hueco[3], y1 - 0.05)
        # marco alrededor del hueco de la trampilla
        return [malla_caja((x0, y0, z0), (x1, hy0, z1)),
                malla_caja((x0, hy1, z0), (x1, y1, z1)),
                malla_caja((x0, hy0, z0), (hx0, hy1, z1)),
                malla_caja((hx1, hy0, z0), (x1, hy1, z1))]
    if t == "perfil_y":
        return [malla_perfil_y(list(prim[1]), prim[2], prim[3])]
    raise ValueError(t)


# -----------------------------------------------------------------------------
# Escritura IFC2x3
# -----------------------------------------------------------------------------
class Exportador(object):
    def __init__(self):
        f = ifcopenshell.file(schema="IFC2X3")
        self.f = f
        f.header.file_description.description = (
            "ViewDefinition [CoordinationView_V2.0]",)
        f.header.file_name.name = "AndamioTalud.ifc"

        persona = f.createIfcPerson(None, "Andamio", "Talud")
        org = f.createIfcOrganization(None, "001-PA-AND-001")
        po = f.createIfcPersonAndOrganization(persona, org)
        app = f.createIfcApplication(org, "1.0", "Andamio sobre talud",
                                     "AndamioTalud")
        self.oh = f.createIfcOwnerHistory(po, app, None, "ADDED", None, po,
                                          app, int(time.time()))

        unidades = f.createIfcUnitAssignment([
            f.createIfcSIUnit(None, "LENGTHUNIT", None, "METRE"),
            f.createIfcSIUnit(None, "AREAUNIT", None, "SQUARE_METRE"),
            f.createIfcSIUnit(None, "VOLUMEUNIT", None, "CUBIC_METRE"),
            f.createIfcSIUnit(None, "PLANEANGLEUNIT", None, "RADIAN")])
        self.ctx = f.createIfcGeometricRepresentationContext(
            None, "Model", 3, 1.0e-5, self.eje(), f.createIfcDirection((0., 1.)))
        proyecto = f.createIfcProject(self.gid(), self.oh,
                                      "Andamio sobre talud 001-PA-AND-001",
                                      None, None, None, None, [self.ctx], unidades)

        self.pl_sitio = f.createIfcLocalPlacement(None, self.eje())
        sitio = f.createIfcSite(self.gid(), self.oh, "Talud", None, None,
                                self.pl_sitio, None, None, "ELEMENT",
                                None, None, 0.0, None, None)
        self.pl_edif = f.createIfcLocalPlacement(self.pl_sitio, self.eje())
        edif = f.createIfcBuilding(self.gid(), self.oh, "Andamio multidireccional",
                                   None, None, self.pl_edif, None, None,
                                   "ELEMENT", None, None, None)
        self.rel_agg(proyecto, [sitio])
        self.rel_agg(sitio, [edif])

        self.niveles = []
        for cota, nombre in [
                (0.0, "N+0.00 Pie de talud"),
                (andamio.NIV_PRINCIPAL,
                 "N+%.2f Plataforma de trabajo" % andamio.NIV_PRINCIPAL),
                (andamio.NIV_SUPERIOR,
                 "N+%.2f Plataforma de torre" % andamio.NIV_SUPERIOR),
                (andamio.NIV_CORONACION,
                 "N+%.2f Coronacion" % andamio.NIV_CORONACION)]:
            pl = f.createIfcLocalPlacement(self.pl_edif, self.eje((0., 0., cota)))
            n = f.createIfcBuildingStorey(self.gid(), self.oh, nombre, None, None,
                                          pl, None, None, "ELEMENT", float(cota))
            self.niveles.append((cota, n, pl, []))
        self.rel_agg(edif, [n for _, n, _, _ in self.niveles])

        self.estilos, self.materiales, self.por_material = {}, {}, {}
        for nombre, (r, g, b) in andamio.MATERIALES.items():
            color = f.createIfcColourRgb(None, r / 255.0, g / 255.0, b / 255.0)
            render = f.createIfcSurfaceStyleRendering(
                color, 0.0, None, None, None, None, None, None, "FLAT")
            estilo = f.createIfcSurfaceStyle(nombre, "BOTH", [render])
            self.estilos[nombre] = f.createIfcPresentationStyleAssignment([estilo])
            self.materiales[nombre] = f.createIfcMaterial(nombre)
            self.por_material[nombre] = []

    # -- utilidades ---------------------------------------------------------
    @staticmethod
    def gid():
        return ifcopenshell.guid.new()

    def eje(self, p=(0., 0., 0.)):
        return self.f.createIfcAxis2Placement3D(
            self.f.createIfcCartesianPoint(tuple(float(c) for c in p)), None, None)

    def rel_agg(self, padre, hijos):
        self.f.createIfcRelAggregates(self.gid(), self.oh, None, None, padre, hijos)

    def brep(self, vs, caras, cota):
        f = self.f
        pts = [f.createIfcCartesianPoint((float(x), float(y), float(z - cota)))
               for x, y, z in vs]
        faces = [f.createIfcFace([f.createIfcFaceOuterBound(
            f.createIfcPolyLoop([pts[i] for i in cara]), True)]) for cara in caras]
        return f.createIfcFacetedBrep(f.createIfcClosedShell(faces))

    # -- elementos ------------------------------------------------------------
    def agregar(self, el):
        f = self.f
        clase, tipo = CLASES[el["grupo"]]
        # nivel: el mas alto cuya cota no supere la base del elemento
        z_min = min(min(v[2] for v in vs) for p in el["prims"]
                    for vs, _ in mallas(p))
        destino = self.niveles[0]
        for nivel in self.niveles:
            if nivel[0] <= z_min + 0.05:
                destino = nivel
        cota, _, pl_nivel, contenidos = destino

        items = [self.brep(vs, caras, cota) for p in el["prims"]
                 for vs, caras in mallas(p)]
        for it in items:
            f.createIfcStyledItem(it, [self.estilos[el["material"]]], None)
        rep = f.createIfcShapeRepresentation(self.ctx, "Body", "Brep", items)
        forma = f.createIfcProductDefinitionShape(None, None, [rep])
        pl = f.createIfcLocalPlacement(pl_nivel, self.eje())

        args = [self.gid(), self.oh, el["nombre"], el["grupo"], el["grupo"],
                pl, forma, None]
        if clase == "IfcBuildingElementProxy":
            args.append("ELEMENT")
        elif tipo:
            args.append(tipo)
        prod = f.create_entity(clase, *args)
        contenidos.append(prod)
        self.por_material[el["material"]].append(prod)

    def guardar(self, ruta):
        f = self.f
        for _, nivel, _, productos in self.niveles:
            if productos:
                f.createIfcRelContainedInSpatialStructure(
                    self.gid(), self.oh, None, None, productos, nivel)
        for nombre, productos in self.por_material.items():
            if productos:
                f.createIfcRelAssociatesMaterial(self.gid(), self.oh, None, None,
                                                 productos, self.materiales[nombre])
        f.write(ruta)


def main(ruta):
    modelo = andamio.Modelo().construir()
    ex = Exportador()
    for el in modelo.elementos:
        ex.agregar(el)
    ex.guardar(ruta)
    print("IFC escrito en %s  (%d elementos)" % (ruta, len(modelo.elementos)))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "andamio_talud.ifc")
