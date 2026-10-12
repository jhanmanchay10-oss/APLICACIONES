# -*- coding: utf-8 -*-
"""
ANDAMIO MULTIDIRECCIONAL SOBRE TALUD  -  Plano 001-PA-AND-001
=============================================================
Genera en Revit (plantilla metrica) el modelo 3D de un andamio
multidireccional tipo "ringlock" apoyado sobre un talud:

  * Torre de acceso de 1.09 m con plataforma superior a +4.20 m.
  * Plataforma principal de trabajo de 3.27 m (torre + 2.20 m) a +2.20 m.
  * Coronacion de la torre a +5.20 m  (3.00 m sobre la plataforma principal).

Compatible con:
  - pyRevit (boton de esta extension)            -> IronPython o CPython
  - RevitPythonShell (Run script)                -> IronPython
  - Dynamo (copiar en un nodo "Python Script")   -> CPython3 / IronPython

Todas las cotas de este archivo estan en METROS; se convierten a pies
(unidad interna de Revit) solo al crear la geometria.

Ejes del modelo
  X : a lo largo del talud (positivo = pendiente abajo)
  Y : profundidad del andamio (0 = cara frontal, D = cara posterior)
  Z : cota; 0.00 = terreno en el pie del talud
"""
from __future__ import print_function

__title__ = "Andamio\nTalud"
__doc__ = "Modela el andamio multidireccional sobre talud (plano 001-PA-AND-001)."

import math

# =============================================================================
# 1. PARAMETROS DE DISENO (metros)
# =============================================================================

# Ejes de montantes en X. Modulo de largueros multidireccionales de 1.09 m:
#   torre = 1.09 m  |  plataforma = 2 x 1.09 = 2.18 m (cota nominal 2.20 m)
EJES_X = [0.00, 1.09, 2.18, 3.27]
PROF = 1.57                      # profundidad del andamio (larguero de 1.57 m)

NIV_PRINCIPAL = 2.20             # plataforma de trabajo
NIV_SUPERIOR = 4.20              # plataforma de la torre (galibo libre 2.00 m)
NIV_CORONACION = 5.20            # barandilla superior de la torre
PASO_ROSETA = 0.50               # roseta cada 0.50 m

# Cota de coronacion de cada linea de montantes
TOPE_MONTANTE = {0: NIV_CORONACION, 1: NIV_CORONACION,
                 2: NIV_SUPERIOR, 3: NIV_SUPERIOR}

# Secciones normalizadas
R_TUBO = 0.0483 / 2.0            # montantes, largueros y diagonales  (48.3 mm)
R_HUSILLO = 0.038 / 2.0          # husillo de base (38 mm)
R_ROSETA = 0.062                 # roseta de 124 mm
E_ROSETA = 0.010
R_LARG_ESC = 0.021               # larguero de escalera
R_PELD_ESC = 0.0135              # peldano de escalera

E_PLATAFORMA = 0.045             # plataforma metalica (canto)
H_RODAPIE = 0.15                 # rodapie reglamentario >= 0.15 m
E_RODAPIE = 0.025
N_PLATAFORMAS = 5                # plataformas por vano en la profundidad

# Barandillas: intermedia +0.50 m, principal +1.00 m sobre la plataforma
H_BARANDA = (0.50, 1.00)

# Perfil del talud (x, z) obtenido del plano de elevacion y prolongado
PERFIL_TERRENO = [
    (-3.00, 3.85), (-1.80, 2.95), (-0.60, 2.10), (-0.10, 1.75),
    (0.15, 1.45), (0.35, 1.15), (0.85, 0.62), (1.25, 0.50),
    (1.60, 0.32), (1.90, 0.02), (2.00, 0.00), (3.60, 0.00),
    (4.60, -0.25), (6.00, -0.35),
]
FONDO_TERRENO = -1.20
MARGEN_Y_TERRENO = 2.00

# Escaleras interiores (inclinacion 75 grados, ancho 0.40 m)
ANG_ESCALERA = math.radians(75.0)
ANCHO_ESCALERA = 0.40
PASO_PELDANO = 0.28
SOBRE_DESEMBARCO = 1.00          # la escalera sobresale 1.00 m del desembarco

# Materiales: nombre -> color RGB
MATERIALES = {
    "AND_Acero galvanizado": (176, 180, 184),
    "AND_Plataforma acero": (128, 132, 136),
    "AND_Rojo seguridad": (200, 32, 32),
    "AND_Trampilla amarilla": (230, 180, 20),
    "AND_Madera durmiente": (140, 100, 60),
    "AND_Concreto": (190, 190, 185),
    "AND_Terreno talud": (176, 146, 104),
}

APP_ID = "AndamioTalud-001-PA-AND-001"


# =============================================================================
# 2. GEOMETRIA (Python puro, sin Revit)
# =============================================================================
# Primitivas:
#   ("cil",  p0, p1, r)                      cilindro entre dos puntos
#   ("caja", (x0,y0,z0), (x1,y1,z1))         caja alineada a ejes
#   ("losa", (x0,y0,x1,y1), z0, z1, hueco)   losa con hueco (x0,y0,x1,y1) o None
#   ("perfil_y", [(x,z),...], y0, y1)        perfil en XZ extruido en Y

def cota_terreno(x):
    p = PERFIL_TERRENO
    if x <= p[0][0]:
        return p[0][1]
    for (xa, za), (xb, zb) in zip(p[:-1], p[1:]):
        if xa <= x <= xb:
            return za + (zb - za) * (x - xa) / (xb - xa)
    return p[-1][1]


def x_terreno(z):
    """Primer x (desde la izquierda) en el que el terreno baja a la cota z."""
    p = PERFIL_TERRENO
    for (xa, za), (xb, zb) in zip(p[:-1], p[1:]):
        if (za - z) * (zb - z) <= 0 and za != zb:
            return xa + (xb - xa) * (za - z) / (za - zb)
    return p[0][0]


def niveles_grilla(z_min, z_max):
    """Cotas de roseta (multiplos de 0.50 m referidos a la plataforma)."""
    k_min = int(math.ceil((z_min - NIV_PRINCIPAL) / PASO_ROSETA - 1e-9))
    k_max = int(math.floor((z_max - NIV_PRINCIPAL) / PASO_ROSETA + 1e-9))
    return [round(NIV_PRINCIPAL + k * PASO_ROSETA, 3)
            for k in range(k_min, k_max + 1)]


class Modelo(object):
    def __init__(self):
        self.elementos = []
        self.montantes = {}       # (ix, iy) -> (z_base_tubo, z_tope)
        self.husillos = {}        # (ix, iy) -> extension del husillo

    def add(self, nombre, grupo, material, prims):
        self.elementos.append({"nombre": nombre, "grupo": grupo,
                               "material": material, "prims": prims})

    # -- utilidades ----------------------------------------------------------
    def y(self, iy):
        return 0.0 if iy == 0 else PROF

    def cubre(self, ix, iy, z):
        zb, zt = self.montantes[(ix, iy)]
        return zb + 0.05 <= z <= zt + 1e-6

    # -- terreno ---------------------------------------------------------------
    def terreno(self):
        pts = list(PERFIL_TERRENO)
        pts.append((PERFIL_TERRENO[-1][0], FONDO_TERRENO))
        pts.append((PERFIL_TERRENO[0][0], FONDO_TERRENO))
        self.add("Talud - terreno natural", "Terreno", "AND_Terreno talud",
                 [("perfil_y", pts, -MARGEN_Y_TERRENO, PROF + MARGEN_Y_TERRENO)])

    # -- apoyos: dado de concreto + durmiente + placa + husillo -----------------
    def apoyos_y_montantes(self):
        for ix, x in enumerate(EJES_X):
            for iy in (0, 1):
                y = self.y(iy)
                # dado de nivelacion: su cara superior queda horizontal sobre
                # el punto mas alto del terreno bajo la huella (criterio talud)
                g_max = max(cota_terreno(x - 0.22), cota_terreno(x + 0.22))
                g_min = min(cota_terreno(x - 0.22), cota_terreno(x + 0.22))
                z_dado = g_max + 0.05
                self.add("Dado de nivelacion E%d-%s" % (ix + 1, "AB"[iy]),
                         "Cimentacion", "AND_Concreto",
                         [("caja", (x - 0.22, y - 0.22, g_min - 0.25),
                           (x + 0.22, y + 0.22, z_dado))])
                z_durm = z_dado + 0.05
                self.add("Durmiente de madera E%d-%s" % (ix + 1, "AB"[iy]),
                         "Cimentacion", "AND_Madera durmiente",
                         [("caja", (x - 0.15, y - 0.15, z_dado),
                           (x + 0.15, y + 0.15, z_durm))])
                z_placa = z_durm + 0.008
                # el husillo absorbe la diferencia hasta la primera roseta
                z_ros = niveles_grilla(z_placa + 0.18, 99)[0]
                z_tubo = z_ros - 0.10
                self.husillos[(ix, iy)] = z_tubo - z_placa
                z_top = TOPE_MONTANTE[ix]
                self.montantes[(ix, iy)] = (z_tubo, z_top)

                self.add("Husillo de base E%d-%s" % (ix + 1, "AB"[iy]),
                         "Base regulable", "AND_Acero galvanizado",
                         [("caja", (x - 0.075, y - 0.075, z_durm),
                           (x + 0.075, y + 0.075, z_placa)),
                          ("cil", (x, y, z_placa), (x, y, z_tubo + 0.15),
                           R_HUSILLO)])

                prims = [("cil", (x, y, z_tubo), (x, y, z_top), R_TUBO)]
                for zr in niveles_grilla(z_tubo + 0.05, z_top - 0.05):
                    prims.append(("cil", (x, y, zr - E_ROSETA / 2),
                                  (x, y, zr + E_ROSETA / 2), R_ROSETA))
                self.add("Montante E%d-%s  (L=%.2f m)"
                         % (ix + 1, "AB"[iy], z_top - z_tubo),
                         "Montante", "AND_Acero galvanizado", prims)

    # -- largueros longitudinales (X) y transversales (Y) ----------------------
    def larguero_x(self, i, iy, z, tipo="Larguero"):
        if not (self.cubre(i, iy, z) and self.cubre(i + 1, iy, z)):
            return
        y = self.y(iy)
        self.add("%s X E%d-E%d %s z=%.2f" % (tipo, i + 1, i + 2, "AB"[iy], z),
                 tipo, "AND_Acero galvanizado",
                 [("cil", (EJES_X[i], y, z), (EJES_X[i + 1], y, z), R_TUBO)])

    def larguero_y(self, ix, z, tipo="Travesano"):
        if not (self.cubre(ix, 0, z) and self.cubre(ix, 1, z)):
            return
        x = EJES_X[ix]
        self.add("%s Y E%d z=%.2f" % (tipo, ix + 1, z), tipo,
                 "AND_Acero galvanizado",
                 [("cil", (x, 0.0, z), (x, PROF, z), R_TUBO)])

    def largueros(self):
        bajo = [round(NIV_PRINCIPAL - k * PASO_ROSETA, 3) for k in (1, 2, 3, 4)]
        p, s = NIV_PRINCIPAL, NIV_SUPERIOR
        for iy in (0, 1):
            # bajo plataforma: arriostramiento horizontal donde haya montante
            for z in bajo:
                for i in (0, 1, 2):
                    self.larguero_x(i, iy, z)
            # nivel de plataforma principal
            for i in (0, 1, 2):
                self.larguero_x(i, iy, p, "Larguero de plataforma")
            # barandillas de la plataforma principal (perimetro frontal/posterior)
            for h in H_BARANDA:
                for i in (0, 1, 2):
                    self.larguero_x(i, iy, p + h, "Barandilla")
            # torre: nivel intermedio, plataforma superior y barandillas
            self.larguero_x(0, iy, p + 1.50)
            for i in (0, 1, 2):
                # a +4.20 el larguero ata la torre con la plataforma principal
                self.larguero_x(i, iy, s, "Larguero de plataforma"
                                if i == 0 else "Larguero de atado")
            for h in H_BARANDA:
                self.larguero_x(0, iy, s + h, "Barandilla")

        # transversales (Y)
        for z in bajo:
            for ix in (0, 1, 2):      # E4 queda libre: acceso a la escalera
                self.larguero_y(ix, z)
        for ix in (0, 1, 2, 3):
            self.larguero_y(ix, p, "Travesano de plataforma")
        for h in H_BARANDA:
            # E2 y E3 libres: paso entre torre y plataforma (galibo 2.00 m)
            self.larguero_y(0, p + h, "Barandilla")
            self.larguero_y(3, p + h, "Barandilla")
        self.larguero_y(0, p + 1.50)
        for ix in (0, 1, 2, 3):
            self.larguero_y(ix, s, "Travesano de plataforma"
                            if ix < 2 else "Larguero de atado")
        for h in H_BARANDA:
            self.larguero_y(0, s + h, "Barandilla")
            self.larguero_y(1, s + h, "Barandilla")

    # -- diagonales -------------------------------------------------------------
    def diagonales(self):
        p, s = NIV_PRINCIPAL, NIV_SUPERIOR
        # caras longitudinales (como el plano de elevacion: dos "V")
        en_x = [((0, s), (1, p)), ((0, p), (1, p - 1.00)),
                ((1, p), (2, p - 1.50)), ((2, p - 1.50), (3, p)),
                ((2, p), (3, s))]
        for iy in (0, 1):
            y = self.y(iy)
            for (ia, za), (ib, zb) in en_x:
                self.add("Diagonal X E%d-E%d %s" % (min(ia, ib) + 1,
                                                    max(ia, ib) + 1, "AB"[iy]),
                         "Diagonal", "AND_Acero galvanizado",
                         [("cil", (EJES_X[ia], y, za), (EJES_X[ib], y, zb),
                           R_TUBO)])
        # caras transversales
        en_y = [(0, p, s), (1, p - 1.00, p), (2, p - 1.50, p), (3, p, s)]
        for ix, za, zb in en_y:
            x = EJES_X[ix]
            self.add("Diagonal Y E%d" % (ix + 1), "Diagonal",
                     "AND_Acero galvanizado",
                     [("cil", (x, 0.0, za), (x, PROF, zb), R_TUBO)])
        # arriostramiento horizontal en planta bajo la plataforma principal
        self.add("Diagonal en planta E2-E3", "Diagonal", "AND_Acero galvanizado",
                 [("cil", (EJES_X[1], 0.0, p - 0.06),
                   (EJES_X[2], PROF, p - 0.06), R_TUBO)])

    # -- anclajes de la torre al talud -----------------------------------------
    def anclajes(self):
        z = NIV_PRINCIPAL + 0.25
        xt = x_terreno(z)
        for iy in (0, 1):
            y = self.y(iy)
            self.add("Amarre al talud %s" % "AB"[iy], "Anclaje",
                     "AND_Acero galvanizado",
                     [("cil", (EJES_X[0], y, z), (xt + 0.02, y, z), R_TUBO),
                      ("caja", (xt - 0.02, y - 0.10, z - 0.10),
                       (xt + 0.02, y + 0.10, z + 0.10)),
                      ("cil", (xt, y, z), (xt - 0.45, y, z - 0.12), 0.008)])

    # -- plataformas, trampillas y rodapies --------------------------------------
    def plataformas(self, i, z, hueco=None):
        """Plataformas del vano i (entre ejes i e i+1) a la cota de larguero z."""
        x0, x1 = EJES_X[i] + 0.03, EJES_X[i + 1] - 0.03
        z0 = z + R_TUBO
        z1 = z0 + E_PLATAFORMA
        ancho = (PROF - 0.04) / N_PLATAFORMAS
        tramp = None
        if hueco:
            # la trampilla ocupa las dos plataformas posteriores
            tramp = (N_PLATAFORMAS - 2, N_PLATAFORMAS - 1)
        for k in range(N_PLATAFORMAS):
            if tramp and k in tramp:
                continue
            ya = 0.02 + k * ancho + 0.004
            yb = 0.02 + (k + 1) * ancho - 0.004
            self.add("Plataforma vano %d z=%.2f n%d" % (i + 1, z, k + 1),
                     "Plataforma", "AND_Plataforma acero",
                     [("losa", (x0, ya, x1, yb), z0, z1, None)])
        if tramp:
            ya = 0.02 + tramp[0] * ancho + 0.004
            yb = 0.02 + (tramp[1] + 1) * ancho - 0.004
            self.add("Plataforma con trampilla vano %d z=%.2f" % (i + 1, z),
                     "Plataforma", "AND_Trampilla amarilla",
                     [("losa", (x0, ya, x1, yb), z0, z1, hueco)])
        return z1

    def rodapies(self, z_sup, tramos, nombre):
        for (xa, ya), (xb, yb) in tramos:
            # se colocan por el interior del perimetro
            if ya == yb:
                yy = ya + (0.03 if ya == 0.0 else -0.03)
                caja = ((xa, yy - E_RODAPIE / 2, z_sup),
                        (xb, yy + E_RODAPIE / 2, z_sup + H_RODAPIE))
            else:
                xx = xa + (0.03 if xa == EJES_X[0] else -0.03)
                caja = ((xx - E_RODAPIE / 2, ya, z_sup),
                        (xx + E_RODAPIE / 2, yb, z_sup + H_RODAPIE))
            self.add("Rodapie %s" % nombre, "Rodapie", "AND_Rojo seguridad",
                     [("caja", caja[0], caja[1])])

    # -- escaleras ----------------------------------------------------------------
    def escalera(self, nombre, x_pie, z_pie, z_desemb):
        """Escalera inclinada que sube hacia -X, centrada junto a la cara
        posterior (bajo la trampilla)."""
        yc = self.y_escalera()
        t = 1.0 / math.tan(ANG_ESCALERA)
        z_fin = z_desemb + SOBRE_DESEMBARCO
        x_fin = x_pie - (z_fin - z_pie) * t
        prims = []
        for dy in (-ANCHO_ESCALERA / 2, ANCHO_ESCALERA / 2):
            prims.append(("cil", (x_pie, yc + dy, z_pie),
                          (x_fin, yc + dy, z_fin), R_LARG_ESC))
        z = z_pie + PASO_PELDANO
        while z < z_desemb + 0.01:
            xp = x_pie - (z - z_pie) * t
            prims.append(("cil", (xp, yc - ANCHO_ESCALERA / 2, z),
                          (xp, yc + ANCHO_ESCALERA / 2, z), R_PELD_ESC))
            z += PASO_PELDANO
        self.add(nombre, "Escalera", "AND_Acero galvanizado", prims)
        return x_pie - (z_desemb - z_pie) * t      # x donde cruza el desembarco

    def y_escalera(self):
        ancho = (PROF - 0.04) / N_PLATAFORMAS
        ya = 0.02 + (N_PLATAFORMAS - 2) * ancho
        yb = 0.02 + N_PLATAFORMAS * ancho
        return (ya + yb) / 2.0

    def hueco(self, x_cruce):
        yc = self.y_escalera()
        return (x_cruce - 0.30, yc - 0.27, x_cruce + 0.40, yc + 0.27)

    # -- ensamblaje ----------------------------------------------------------------
    def construir(self):
        self.terreno()
        self.apoyos_y_montantes()
        self.largueros()
        self.diagonales()
        self.anclajes()

        p, s = NIV_PRINCIPAL, NIV_SUPERIOR
        # escalera 1: terreno -> plataforma principal (vano E3-E4, acceso por E4)
        x_pie1 = EJES_X[3] - 0.32
        xc1 = self.escalera("Escalera de acceso N+0.00 a N+%.2f" % p,
                            x_pie1, cota_terreno(x_pie1), p)
        # escalera 2: plataforma principal -> plataforma superior (torre)
        x_pie2 = EJES_X[1] - 0.14
        xc2 = self.escalera("Escalera de torre N+%.2f a N+%.2f" % (p, s),
                            x_pie2, p + R_TUBO + E_PLATAFORMA, s)

        z_p = self.plataformas(0, p)
        self.plataformas(1, p)
        self.plataformas(2, p, self.hueco(xc1))
        z_s = self.plataformas(0, s, self.hueco(xc2))

        x0, x3, x1 = EJES_X[0], EJES_X[3], EJES_X[1]
        self.rodapies(z_p, [((x0, 0.0), (x3, 0.0)), ((x0, PROF), (x3, PROF)),
                            ((x0, 0.0), (x0, PROF)), ((x3, 0.0), (x3, PROF))],
                      "plataforma principal")
        self.rodapies(z_s, [((x0, 0.0), (x1, 0.0)), ((x0, PROF), (x1, PROF)),
                            ((x0, 0.0), (x0, PROF)), ((x1, 0.0), (x1, PROF))],
                      "plataforma superior")
        return self


# =============================================================================
# 3. TRADUCCION A REVIT
# =============================================================================
FT = 0.3048


def _cargar_revit():
    import clr
    clr.AddReference("RevitAPI")
    clr.AddReference("System")
    g = globals()
    from Autodesk.Revit import DB
    from System.Collections.Generic import List
    g["DB"] = DB
    g["List"] = List


def _contexto():
    """Devuelve (doc, uidoc, transaction_manager_dynamo_o_None)."""
    try:
        uiapp = __revit__                      # pyRevit / RevitPythonShell
        return uiapp.ActiveUIDocument.Document, uiapp.ActiveUIDocument, None
    except NameError:
        import clr
        clr.AddReference("RevitServices")
        from RevitServices.Persistence import DocumentManager
        from RevitServices.Transactions import TransactionManager
        dm = DocumentManager.Instance
        return (dm.CurrentDBDocument, dm.CurrentUIApplication.ActiveUIDocument,
                TransactionManager.Instance)


def _xyz(p):
    return DB.XYZ(p[0] / FT, p[1] / FT, p[2] / FT)


def _loop(puntos):
    loop = DB.CurveLoop()
    n = len(puntos)
    for i in range(n):
        a, b = puntos[i], puntos[(i + 1) % n]
        if a.DistanceTo(b) > 1e-6:
            loop.Append(DB.Line.CreateBound(a, b))
    return loop


def _rect(x0, y0, x1, y1, z, horario=False):
    pts = [(x0, y0, z), (x1, y0, z), (x1, y1, z), (x0, y1, z)]
    if horario:
        pts.reverse()
    return _loop([_xyz(p) for p in pts])


def _extruir(loops, direccion, largo, opts):
    return DB.GeometryCreationUtilities.CreateExtrusionGeometry(
        List[DB.CurveLoop](loops), direccion, largo, opts)


def _solido(prim, opts):
    t = prim[0]
    if t == "cil":
        a, b, r = _xyz(prim[1]), _xyz(prim[2]), prim[3] / FT
        d = b - a
        n = d.Normalize()
        ref = DB.XYZ.BasisZ if abs(n.Z) < 0.99 else DB.XYZ.BasisX
        u = n.CrossProduct(ref).Normalize()
        v = n.CrossProduct(u)
        plano = DB.Plane.CreateByOriginAndBasis(a, u, v)
        loop = DB.CurveLoop()
        loop.Append(DB.Arc.Create(plano, r, 0.0, math.pi))
        loop.Append(DB.Arc.Create(plano, r, math.pi, 2.0 * math.pi))
        return _extruir([loop], n, d.GetLength(), opts)
    if t == "caja":
        (x0, y0, z0), (x1, y1, z1) = prim[1], prim[2]
        return _extruir([_rect(x0, y0, x1, y1, z0)], DB.XYZ.BasisZ,
                        (z1 - z0) / FT, opts)
    if t == "losa":
        (x0, y0, x1, y1), z0, z1, hueco = prim[1], prim[2], prim[3], prim[4]
        loops = [_rect(x0, y0, x1, y1, z0)]
        if hueco:
            hx0, hy0, hx1, hy1 = hueco
            loops.append(_rect(max(hx0, x0 + 0.05), max(hy0, y0 + 0.05),
                               min(hx1, x1 - 0.05), min(hy1, y1 - 0.05),
                               z0, horario=True))
        return _extruir(loops, DB.XYZ.BasisZ, (z1 - z0) / FT, opts)
    if t == "perfil_y":
        pts, y0, y1 = prim[1], prim[2], prim[3]
        loop = _loop([_xyz((x, y0, z)) for x, z in pts])
        return _extruir([loop], DB.XYZ.BasisY, (y1 - y0) / FT, opts)
    raise ValueError("Primitiva desconocida: %s" % t)


def _materiales(doc):
    existentes = dict((m.Name, m) for m in
                      DB.FilteredElementCollector(doc).OfClass(DB.Material))
    ids = {}
    for nombre, (r, g, b) in MATERIALES.items():
        mat = existentes.get(nombre)
        if mat is None:
            mat = doc.GetElement(DB.Material.Create(doc, nombre))
        mat.Color = DB.Color(r, g, b)
        try:
            mat.SurfaceForegroundPatternColor = DB.Color(r, g, b)
        except Exception:
            pass
        ids[nombre] = mat.Id
    return ids


def _unidades_metros(doc):
    try:                                            # Revit 2021+
        unidades = doc.GetUnits()
        fo = DB.FormatOptions(DB.UnitTypeId.Meters)
        fo.Accuracy = 0.01
        unidades.SetFormatOptions(DB.SpecTypeId.Length, fo)
        doc.SetUnits(unidades)
    except Exception:
        pass


def _niveles(doc):
    existentes = dict((l.Name, l) for l in
                      DB.FilteredElementCollector(doc).OfClass(DB.Level))
    for cota, nombre in [(0.0, "N+0.00 Pie de talud"),
                         (NIV_PRINCIPAL, "N+%.2f Plataforma de trabajo" % NIV_PRINCIPAL),
                         (NIV_SUPERIOR, "N+%.2f Plataforma de torre" % NIV_SUPERIOR),
                         (NIV_CORONACION, "N+%.2f Coronacion" % NIV_CORONACION)]:
        if nombre in existentes:
            continue
        nivel = None
        for l in existentes.values():
            if abs(l.Elevation - cota / FT) < 1e-4:
                nivel = l
                break
        if nivel is None:
            nivel = DB.Level.Create(doc, cota / FT)
        try:
            nivel.Name = nombre
        except Exception:
            pass


def _borrar_anteriores(doc):
    ids = [e.Id for e in DB.FilteredElementCollector(doc)
           .OfClass(DB.DirectShape) if e.ApplicationId == APP_ID]
    if ids:
        doc.Delete(List[DB.ElementId](ids))
    return len(ids)


def _vista_3d(doc):
    nombre = "3D - Andamio sobre talud"
    for v in DB.FilteredElementCollector(doc).OfClass(DB.View3D):
        if v.Name == nombre and not v.IsTemplate:
            return v
    vft = [t for t in DB.FilteredElementCollector(doc).OfClass(DB.ViewFamilyType)
           if t.ViewFamily == DB.ViewFamily.ThreeDimensional][0]
    vista = DB.View3D.CreateIsometric(doc, vft.Id)
    vista.Name = nombre
    vista.DetailLevel = DB.ViewDetailLevel.Fine
    vista.DisplayStyle = DB.DisplayStyle.ShadingWithEdges
    centro = _xyz((1.6, PROF / 2, 2.6))
    ojo = centro + _xyz((7.0, -9.0, 5.0))
    adelante = (centro - ojo).Normalize()
    derecha = adelante.CrossProduct(DB.XYZ.BasisZ).Normalize()
    arriba = derecha.CrossProduct(adelante)
    vista.SetOrientation(DB.ViewOrientation3D(ojo, arriba, adelante))
    return vista


def construir_en_revit(modelo):
    doc, uidoc, tm = _contexto()
    if tm is None:
        tx = DB.Transaction(doc, "Andamio multidireccional sobre talud")
        tx.Start()
    else:
        tm.EnsureInTransaction(doc)
    try:
        _unidades_metros(doc)
        borrados = _borrar_anteriores(doc)
        mats = _materiales(doc)
        _niveles(doc)

        cat_gm = DB.ElementId(DB.BuiltInCategory.OST_GenericModel)
        cat_topo = DB.ElementId(DB.BuiltInCategory.OST_Topography)
        if not DB.DirectShape.IsValidCategoryId(cat_topo, doc):
            cat_topo = cat_gm

        creados, errores = 0, []
        for el in modelo.elementos:
            opts = DB.SolidOptions(mats[el["material"]], DB.ElementId.InvalidElementId)
            try:
                geo = [_solido(p, opts) for p in el["prims"]]
                cat = cat_topo if el["grupo"] == "Terreno" else cat_gm
                ds = DB.DirectShape.CreateElement(doc, cat)
                ds.ApplicationId = APP_ID
                ds.ApplicationDataId = el["nombre"]
                ds.SetShape(List[DB.GeometryObject](geo))
                try:
                    ds.Name = el["nombre"]
                except Exception:
                    pass
                for bip, valor in ((DB.BuiltInParameter.ALL_MODEL_INSTANCE_COMMENTS,
                                    el["nombre"]),
                                   (DB.BuiltInParameter.ALL_MODEL_MARK,
                                    el["grupo"])):
                    prm = ds.get_Parameter(bip)
                    if prm is not None and not prm.IsReadOnly:
                        prm.Set(valor)
                creados += 1
            except Exception as ex:
                errores.append("%s: %s" % (el["nombre"], ex))
        vista = _vista_3d(doc)
    except Exception:
        if tm is None:
            tx.RollBack()
        raise
    if tm is None:
        tx.Commit()
    else:
        tm.TransactionTaskDone()

    if uidoc is not None and tm is None:
        try:
            uidoc.ActiveView = vista
        except Exception:
            pass

    msg = ["Andamio sobre talud generado.",
           "Elementos creados: %d   (reemplazados: %d)" % (creados, borrados),
           "Husillos de base (extension en m): " + ", ".join(
               "E%d-%s=%.2f" % (k[0] + 1, "AB"[k[1]], v)
               for k, v in sorted(modelo.husillos.items()))]
    if errores:
        msg.append("Errores (%d):" % len(errores))
        msg.extend(errores[:20])
    return "\n".join(msg)


# =============================================================================
# 4. EJECUCION
# =============================================================================
if __name__ in ("__main__", "<module>") or "IN" in globals():
    try:
        _cargar_revit()
        EN_REVIT = True
    except Exception:
        EN_REVIT = False
    if EN_REVIT:
        resultado = construir_en_revit(Modelo().construir())
        print(resultado)
        OUT = resultado                                  # salida para Dynamo
