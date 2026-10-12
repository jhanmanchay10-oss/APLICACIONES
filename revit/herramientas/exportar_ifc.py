# -*- coding: utf-8 -*-
"""Exporta el andamio sobre talud a IFC4 (se abre directamente en Revit).

Uso:  python3 revit/herramientas/exportar_ifc.py [salida.ifc]
Requiere:  pip install ifcopenshell
"""
import importlib.util
import math
import os
import sys

import ifcopenshell
import ifcopenshell.api
import ifcopenshell.guid

AQUI = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(AQUI, "..", "AndamioTalud.extension", "AndamioTalud.tab",
                      "Modelado.panel", "AndamioTalud.pushbutton", "script.py")
spec = importlib.util.spec_from_file_location("andamio", SCRIPT)
andamio = importlib.util.module_from_spec(spec)
spec.loader.exec_module(andamio)

# grupo del modelo -> (clase IFC, PredefinedType)
CLASES = {
    "Terreno": ("IfcGeographicElement", "TERRAIN"),
    "Cimentacion": ("IfcFooting", "PAD_FOOTING"),
    "Base regulable": ("IfcMember", "POST"),
    "Montante": ("IfcMember", "POST"),
    "Larguero": ("IfcMember", "MEMBER"),
    "Larguero de plataforma": ("IfcMember", "MEMBER"),
    "Larguero de atado": ("IfcMember", "MEMBER"),
    "Travesano": ("IfcMember", "MEMBER"),
    "Travesano de plataforma": ("IfcMember", "MEMBER"),
    "Barandilla": ("IfcRailing", "GUARDRAIL"),
    "Diagonal": ("IfcMember", "BRACE"),
    "Anclaje": ("IfcMember", "STRUT"),
    "Plataforma": ("IfcPlate", "SHEET"),
    "Rodapie": ("IfcPlate", "USERDEFINED"),
    "Escalera": ("IfcStair", "USERDEFINED"),
}


class Exportador(object):
    def __init__(self):
        f = ifcopenshell.file(schema="IFC4")
        self.f = f
        proyecto = ifcopenshell.api.run("root.create_entity", f,
                                        ifc_class="IfcProject",
                                        name="Andamio sobre talud 001-PA-AND-001")
        unidades = [ifcopenshell.api.run("unit.add_si_unit", f, unit_type=u)
                    for u in ("LENGTHUNIT", "AREAUNIT", "VOLUMEUNIT")]
        unidades.append(ifcopenshell.api.run("unit.add_si_unit", f,
                                             unit_type="PLANEANGLEUNIT"))
        ifcopenshell.api.run("unit.assign_unit", f, units=unidades)  # metros
        ctx = ifcopenshell.api.run("context.add_context", f, context_type="Model")
        self.body = ifcopenshell.api.run("context.add_context", f,
                                         context_type="Model",
                                         context_identifier="Body",
                                         target_view="MODEL_VIEW", parent=ctx)
        sitio = ifcopenshell.api.run("root.create_entity", f, ifc_class="IfcSite",
                                     name="Talud")
        edif = ifcopenshell.api.run("root.create_entity", f,
                                    ifc_class="IfcBuilding",
                                    name="Andamio multidireccional")
        ifcopenshell.api.run("aggregate.assign_object", f,
                             relating_object=proyecto, products=[sitio])
        ifcopenshell.api.run("aggregate.assign_object", f,
                             relating_object=sitio, products=[edif])
        self.origen = f.createIfcLocalPlacement(None, self.eje(0, 0, 0))
        for obj in (sitio, edif):
            obj.ObjectPlacement = self.origen

        self.niveles = []
        for cota, nombre in [
                (0.0, "N+0.00 Pie de talud"),
                (andamio.NIV_PRINCIPAL,
                 "N+%.2f Plataforma de trabajo" % andamio.NIV_PRINCIPAL),
                (andamio.NIV_SUPERIOR,
                 "N+%.2f Plataforma de torre" % andamio.NIV_SUPERIOR),
                (andamio.NIV_CORONACION,
                 "N+%.2f Coronacion" % andamio.NIV_CORONACION)]:
            n = ifcopenshell.api.run("root.create_entity", f,
                                     ifc_class="IfcBuildingStorey", name=nombre)
            n.Elevation = cota
            n.ObjectPlacement = f.createIfcLocalPlacement(
                self.origen, self.eje(0, 0, cota))
            ifcopenshell.api.run("aggregate.assign_object", f,
                                 relating_object=edif, products=[n])
            self.niveles.append((cota, n, []))

        self.estilos, self.materiales = {}, {}
        for nombre, (r, g, b) in andamio.MATERIALES.items():
            estilo = ifcopenshell.api.run("style.add_style", f, name=nombre)
            ifcopenshell.api.run(
                "style.add_surface_style", f, style=estilo,
                ifc_class="IfcSurfaceStyleShading",
                attributes={"SurfaceColour": {"Name": None, "Red": r / 255.0,
                                              "Green": g / 255.0,
                                              "Blue": b / 255.0}})
            self.estilos[nombre] = estilo
            mat = ifcopenshell.api.run("material.add_material", f, name=nombre)
            self.materiales[nombre] = mat

    # -- utilidades geometricas -------------------------------------------
    def pt(self, x, y, z=None):
        if z is None:
            return self.f.createIfcCartesianPoint((float(x), float(y)))
        return self.f.createIfcCartesianPoint((float(x), float(y), float(z)))

    def dir(self, v):
        return self.f.createIfcDirection(tuple(float(c) for c in v))

    def eje(self, x, y, z, axis=None, ref=None):
        return self.f.createIfcAxis2Placement3D(
            self.pt(x, y, z), self.dir(axis) if axis else None,
            self.dir(ref) if ref else None)

    def polilinea(self, pts):
        pts = list(pts) + [pts[0]]
        return self.f.createIfcPolyline([self.pt(x, y) for x, y in pts])

    def extruir(self, perfil, posicion, largo):
        return self.f.createIfcExtrudedAreaSolid(perfil, posicion,
                                                 self.dir((0, 0, 1)), float(largo))

    def solido(self, prim):
        f, t = self.f, prim[0]
        if t == "cil":
            a, b, r = prim[1], prim[2], prim[3]
            d = [b[i] - a[i] for i in range(3)]
            L = math.sqrt(sum(c * c for c in d))
            n = [c / L for c in d]
            ref = (0, 0, 1) if abs(n[2]) < 0.99 else (1, 0, 0)
            u = (n[1] * ref[2] - n[2] * ref[1], n[2] * ref[0] - n[0] * ref[2],
                 n[0] * ref[1] - n[1] * ref[0])
            lu = math.sqrt(sum(c * c for c in u))
            u = [c / lu for c in u]
            perfil = f.createIfcCircleProfileDef("AREA", None, None, float(r))
            return self.extruir(perfil, self.eje(a[0], a[1], a[2], n, u), L)
        if t == "caja":
            (x0, y0, z0), (x1, y1, z1) = prim[1], prim[2]
            perfil = f.createIfcRectangleProfileDef(
                "AREA", None,
                f.createIfcAxis2Placement2D(self.pt((x0 + x1) / 2, (y0 + y1) / 2)),
                float(x1 - x0), float(y1 - y0))
            return self.extruir(perfil, self.eje(0, 0, z0), z1 - z0)
        if t == "losa":
            (x0, y0, x1, y1), z0, z1, hueco = prim[1], prim[2], prim[3], prim[4]
            exterior = self.polilinea([(x0, y0), (x1, y0), (x1, y1), (x0, y1)])
            if hueco:
                hx0, hy0 = max(hueco[0], x0 + 0.05), max(hueco[1], y0 + 0.05)
                hx1, hy1 = min(hueco[2], x1 - 0.05), min(hueco[3], y1 - 0.05)
                interior = self.polilinea([(hx0, hy0), (hx0, hy1),
                                           (hx1, hy1), (hx1, hy0)])
                perfil = f.createIfcArbitraryProfileDefWithVoids(
                    "AREA", None, exterior, [interior])
            else:
                perfil = f.createIfcArbitraryClosedProfileDef("AREA", None, exterior)
            return self.extruir(perfil, self.eje(0, 0, z0), z1 - z0)
        if t == "perfil_y":
            pts, y0, y1 = prim[1], prim[2], prim[3]
            # plano local: x = X global, y = Z global, extrusion = -Y global
            perfil = f.createIfcArbitraryClosedProfileDef(
                "AREA", None, self.polilinea([(x, z) for x, z in pts]))
            return self.extruir(perfil, self.eje(0, y1, 0, (0, -1, 0), (1, 0, 0)),
                                y1 - y0)
        raise ValueError(t)

    # -- elementos ----------------------------------------------------------
    def agregar(self, el):
        f = self.f
        clase, tipo = CLASES[el["grupo"]]
        prod = ifcopenshell.api.run("root.create_entity", f, ifc_class=clase,
                                    name=el["nombre"], predefined_type=tipo)
        if tipo == "USERDEFINED":
            prod.ObjectType = el["grupo"]
        prod.Description = el["grupo"]
        prod.ObjectPlacement = self.origen
        items = [self.solido(p) for p in el["prims"]]
        rep = f.createIfcShapeRepresentation(self.body, "Body", "SweptSolid", items)
        ifcopenshell.api.run("geometry.assign_representation", f,
                             product=prod, representation=rep)
        ifcopenshell.api.run("style.assign_representation_styles", f,
                             shape_representation=rep,
                             styles=[self.estilos[el["material"]]] * len(items))
        ifcopenshell.api.run("material.assign_material", f, products=[prod],
                             material=self.materiales[el["material"]])
        # nivel: el mas alto cuya cota no supere la base del elemento
        z_min = min(self.z_base(p) for p in el["prims"])
        destino = self.niveles[0]
        for nivel in self.niveles:
            if nivel[0] <= z_min + 0.05:
                destino = nivel
        destino[2].append(prod)

    @staticmethod
    def z_base(prim):
        t = prim[0]
        if t == "cil":
            return min(prim[1][2], prim[2][2])
        if t == "caja":
            return prim[1][2]
        if t == "losa":
            return prim[2]
        return 0.0

    def guardar(self, ruta):
        for _, nivel, productos in self.niveles:
            if productos:
                ifcopenshell.api.run("spatial.assign_container", self.f,
                                     relating_structure=nivel, products=productos)
        self.f.write(ruta)


def main(ruta):
    modelo = andamio.Modelo().construir()
    ex = Exportador()
    for el in modelo.elementos:
        ex.agregar(el)
    ex.guardar(ruta)
    print("IFC escrito en %s  (%d elementos)" % (ruta, len(modelo.elementos)))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "andamio_talud.ifc")
