# -*- coding: utf-8 -*-
# Refugio costero de caña - geometría paramétrica V01 (metros).
# Módulo SIN imports: se ejecuta tal cual dentro del conector de SketchUp (que trae `math`
# precargado) y localmente para validar y dibujar planos. Genera primitivas:
#   ("cyl", grupo, sub, defn, p0, p1, r, nombre)
#   ("box", grupo, sub, defn, origen, ex, ey, ez, nombre)   # caja unitaria -> ejes escalados
#   ("sph", grupo, sub, defn, centro, (rx, ry, rz), nombre)

G00 = "00_REFERENCIAS"
G01 = "01_TOPOGRAFÍA_EXISTENTE"
G02 = "02_CIMENTACIONES"
G03 = "03_ANCLAJES_Y_PEDESTALES"
G04 = "04_ESTRUCTURA_PRINCIPAL_CAÑA_20CM"
G05 = "05_ESTRUCTURA_SECUNDARIA"
G06 = "06_ARRIOSTRAMIENTOS"
G07 = "07_PLATAFORMA_Y_ENTABLADO"
G08 = "08_CUBIERTA"
G09 = "09_ASIENTOS_Y_MOBILIARIO"
G10 = "10_FIGURAS_HUMANAS"
G11 = "11_VEGETACIÓN"
G12 = "12_COTAS_Y_DETALLES"
G13 = "13_ESCENAS_Y_PRESENTACIÓN"

# ---------------- parámetros ----------------
R20 = 0.10          # caña principal Ø20 cm (nominal, exterior)
R12 = 0.06          # viguetas Ø12
R10 = 0.05          # correas / riostras Ø10
R06 = 0.03          # entablado / latillas Ø6
FFL = 0.90          # nivel de piso terminado (NPT) respecto al datum ±0.00
Z_SLAT = FFL - R06                  # 0.87 eje tablilla
Z_JOIST = FFL - 2*R06 - R12         # 0.78 eje vigueta
Z_BEAM = Z_JOIST - R12 - R20        # 0.62 eje viga principal transversal
Z_BEAM_BOT = Z_BEAM - R20           # 0.52
Z_SOLERA = Z_BEAM + R20 + R20       # 0.82 eje solera (sobre viga principal)
Z_SOLERA_TOP = Z_SOLERA + R20       # 0.92
ZF = Z_SOLERA_TOP + 0.03            # 0.95 arranque del eje de costilla (zapata metálica 12 mm + holgura)
NF = 19                             # pórticos
DXF = 0.42                          # separación de pórticos
X_MOUTH = DXF*(NF-1)                # 7.56
BEAM_DX = 3*DXF                     # 1.26 vigas principales cada 3 pórticos
XS, XE = -0.30, 12.70               # límites del entablado en X
GREEN_U = 0.45                      # posición de la línea verde: 0.45 m desde el pie cercano de la boca
GREEN_H = 2.10

# ángulos interiores de la boca (referencia 4). Los pies (87.5°) cierran el hexágono:
# 105+120+155+165 = 545  ->  720-545 = 175  ->  87.5° por pie (desvío de 2.5° frente a 90°).
ANG = {"B": 165.0, "C": 120.0, "D": 105.0, "E": 155.0}
ANG_FOOT = (720.0 - sum(ANG.values()))/2.0

def _add(a, b): return (a[0]+b[0], a[1]+b[1], a[2]+b[2])
def _sub(a, b): return (a[0]-b[0], a[1]-b[1], a[2]-b[2])
def _mul(a, s): return (a[0]*s, a[1]*s, a[2]*s)
def _len(a): return math.sqrt(a[0]*a[0]+a[1]*a[1]+a[2]*a[2])
def _nrm(a):
    L = _len(a)
    return (a[0]/L, a[1]/L, a[2]/L)
def _lerp(a, b, t): return a + (b-a)*t
def _ss(t):
    t = max(0.0, min(1.0, t)); return t*t*(3-2*t)

# ---------------- pórtico de la boca (ángulos exactos) ----------------
def mouth_profile(AB=1.50, CD=3.40, DE=1.40):
    """Hexágono de la boca en coordenadas (u, z): u = distancia horizontal desde el pie cercano.
    BC se resuelve para que la altura libre en la línea verde sea exactamente 2.10 m sobre el NPT."""
    hA = ANG_FOOT
    hB = hA - (180 - ANG["B"])
    hC = hB - (180 - ANG["C"])
    hD = hC - (180 - ANG["D"])
    hE = hD - (180 - ANG["E"])
    def d(h): return (math.cos(math.radians(h)), math.sin(math.radians(h)))
    A = (0.0, 0.0)
    B = (A[0]+AB*d(hA)[0], A[1]+AB*d(hA)[1])
    # cara inferior de la viga CD en u = GREEN_U debe quedar a NPT + 2.10
    zc_target = (FFL + GREEN_H) - ZF + R20/math.cos(math.radians(hC))
    tC = math.tan(math.radians(hC))
    # Cz + (GREEN_U - Cu)*tC = zc_target ; C = B + BC*d(hB)
    dB = d(hB)
    BC = (zc_target - B[1] - (GREEN_U - B[0])*tC)/(dB[1] - dB[0]*tC)
    C = (B[0]+BC*dB[0], B[1]+BC*dB[1])
    D = (C[0]+CD*d(hC)[0], C[1]+CD*d(hC)[1])
    E = (D[0]+DE*d(hD)[0], D[1]+DE*d(hD)[1])
    dE = d(hE)
    EF = -E[1]/dE[1]
    F = (E[0]+EF*dE[0], 0.0)
    return [A, B, C, D, E, F], {"AB": AB, "BC": BC, "CD": CD, "DE": DE, "EF": EF, "AF": F[0],
                                "headings": [hA, hB, hC, hD, hE]}

MOUTH, MOUTH_INFO = mouth_profile()
# pórtico posterior (primer modelo, más vertical y cerrado; incluye la caída del respaldo lejano)
BACK = [(0.0, 0.0), (-0.05, 2.15), (0.45, 3.05), (2.05, 3.30), (2.75, 1.10), (2.05, 0.0)]
YA0, YA1 = 0.25, 0.00               # línea de pies cercana (solera cercana) en el pórtico 1 y en la boca

def frame_x(i): return DXF*i
def t_shape(i): return (i/(NF-1.0))**1.6
def t_lin(i): return i/(NF-1.0)
def yA_at(x): return _lerp(YA0, YA1, x/X_MOUTH)
def yF_at(x): return yA_at(x) + _lerp(BACK[5][0], MOUTH[5][0], x/X_MOUTH)

def frame_profile(i):
    ts, tl = t_shape(i), t_lin(i)
    pts = []
    for k in range(6):
        if k in (0, 5):
            u = _lerp(BACK[k][0], MOUTH[k][0], tl); z = 0.0
        else:
            u = _lerp(BACK[k][0], MOUTH[k][0], ts); z = _lerp(BACK[k][1], MOUTH[k][1], ts)
        pts.append((u, z))
    return pts

def frame_pts3(i):
    x = frame_x(i); ya = yA_at(x)
    return [(x, ya + u, ZF + z) for (u, z) in frame_profile(i)]

def interior_angles(pts2):
    out = []
    n = len(pts2)
    for k in range(1, n-1):
        a = (pts2[k-1][0]-pts2[k][0], pts2[k-1][1]-pts2[k][1])
        b = (pts2[k+1][0]-pts2[k][0], pts2[k+1][1]-pts2[k][1])
        c = (a[0]*b[0]+a[1]*b[1])/(math.hypot(*a)*math.hypot(*b))
        out.append(math.degrees(math.acos(max(-1, min(1, c)))))
    return out

# ---------------- topografía (aproximación visual, no levantamiento) ----------------
def terrain(x, y):
    """Aproximación visual (no es levantamiento topográfico). Casi plano bajo la plataforma,
    montículo de arena en el arranque de la rampa, médanos y caída hacia la playa (x > 17.5)."""
    z = -0.03 - 0.006*x - 0.004*y
    z += 0.020*math.sin(1.3*x+0.4*y) + 0.015*math.sin(0.7*y-0.9*x+1.0) + 0.010*math.sin(2.1*x+1.7*y+0.5)
    z += 0.65*math.exp(-(((x-15.6)**2)/3.0 + ((y+1.3)**2)/5.0))      # montículo de arranque de rampa
    z += 0.35*math.exp(-(((x-15.0)**2)/6.0 + ((y+4.5)**2)/8.0))      # médano lateral
    z += 0.30*math.exp(-(((x+5.0)**2)/10.0 + ((y-1.0)**2)/18.0))     # médano posterior
    if x > 17.5: z -= 3.2*_ss((x-17.5)/7.0)
    return z

# ---------------- límites del entablado ----------------
def ymin_at(x):
    if x < 2.0: return -0.45
    if x < 4.4: return -0.45 + _ss((x-2.0)/2.4)*(-3.45)
    if x < 11.2: return -3.90
    return -3.90 + (x-11.2)*1.30
def ymax_at(x):
    if x <= X_MOUTH + 0.01: return yF_at(min(max(x, 0.0), X_MOUTH)) + 0.45
    if x <= 8.90: return yF_at(X_MOUTH) + 0.45
    return 0.70

def build():
    P = []
    def cyl(g, s, d, p0, p1, r, n): P.append(("cyl", g, s, d, p0, p1, r, n))
    def boxa(g, s, d, o, ex, ey, ez, n): P.append(("box", g, s, d, o, ex, ey, ez, n))
    def box(g, s, d, x, y, z, w, dp, h, n): boxa(g, s, d, (x, y, z), (w, 0, 0), (0, dp, 0), (0, 0, h), n)
    def sph(g, s, d, c, rr, n): P.append(("sph", g, s, d, c, rr, n))
    info = {}

    # ===== 04 pórticos Ø20 + 03 nodos metálicos =====
    GAP = 0.12                                   # recorte de la caña en cada nodo
    for i in range(NF):
        pts = frame_pts3(i)
        sub = "Portico_%02d" % (i+1) if i < NF-1 else "Portico_19_BOCA"
        prof2 = frame_profile(i)
        angs = [0.0] + interior_angles(prof2) + [0.0]
        gaps = [0.0] + [max(GAP, (R20 + 0.012)/math.sin(math.radians(angs[k])/2.0)) for k in range(1, 5)] + [0.0]
        for k in range(5):
            a, b = pts[k], pts[k+1]
            u = _nrm(_sub(b, a))
            a2 = a if k == 0 else _add(a, _mul(u, gaps[k]))
            b2 = b if k == 4 else _sub(b, _mul(u, gaps[k+1]))
            cyl(G04, sub, "cana20", a2, b2, R20, "P%02d_Tramo_%s%s" % (i+1, "ABCDEF"[k], "ABCDEF"[k+1]))
        # nodos B, C, D, E: pletinas a ambas caras + 2 pernos por extremo + pasador central
        for k in (1, 2, 3, 4):
            v = pts[k]
            for nb in (k-1, k+1):
                u = _nrm(_sub(pts[nb], v))
                w = _nrm((0.0, -u[2], u[1]))     # perpendicular en el plano del pórtico
                for sx in (-1, 1):
                    xo = sx*(R20 + 0.004)
                    o = _add(_add(v, (xo - 0.004, 0, 0)), _mul(w, -0.08))
                    boxa(G03, "Nodos_Porticos", "acero", o, (0.008, 0, 0), _mul(u, gaps[k] + 0.40), _mul(w, 0.16),
                         "P%02d_Nodo%s_Pletina" % (i+1, "ABCDEF"[k]))
                for dd in (gaps[k] + 0.15, gaps[k] + 0.30):
                    c = _add(v, _mul(u, dd))
                    cyl(G03, "Nodos_Porticos", "perno", _add(c, (-0.135, 0, 0)), _add(c, (0.135, 0, 0)), 0.008,
                        "P%02d_Nodo%s_Perno_M16" % (i+1, "ABCDEF"[k]))
            cyl(G03, "Nodos_Porticos", "acero", _add(v, (-0.118, 0, 0)), _add(v, (0.118, 0, 0)), 0.07,
                "P%02d_Nodo%s_Pasador" % (i+1, "ABCDEF"[k]))
        # zapatas metálicas de pie (sobre solera)
        for k in (0, 5):
            v = pts[k]
            box(G03, "Apoyos_Porticos", "acero", v[0]-0.15, v[1]-0.15, Z_SOLERA_TOP, 0.30, 0.30, 0.012,
                "P%02d_Pie%s_Placa" % (i+1, "ABCDEF"[k]))
            for sx in (-1, 1):
                box(G03, "Apoyos_Porticos", "acero", v[0]+sx*(R20+0.004)-0.004, v[1]-0.10, Z_SOLERA_TOP, 0.008, 0.20, 0.26,
                    "P%02d_Pie%s_Oreja" % (i+1, "ABCDEF"[k]))
            c = (v[0], v[1], ZF + 0.14)
            cyl(G03, "Apoyos_Porticos", "perno", _add(c, (-0.135, 0, 0)), _add(c, (0.135, 0, 0)), 0.008,
                "P%02d_Pie%s_Perno_M16" % (i+1, "ABCDEF"[k]))
            cyl(G03, "Apoyos_Porticos", "perno", (v[0], v[1], Z_SOLERA - 0.12), (v[0], v[1], Z_SOLERA_TOP + 0.03), 0.008,
                "P%02d_Pie%s_Varilla_Solera" % (i+1, "ABCDEF"[k]))

    # ===== 05 correas Ø10 por el interior en B..E =====
    for i in range(NF-1):
        pa, pb = frame_pts3(i), frame_pts3(i+1)
        for k in (1, 2, 3, 4):
            def inward(pts, k):
                a = _nrm(_sub(pts[k-1], pts[k])); b = _nrm(_sub(pts[k+1], pts[k]))
                bis = _nrm(_add(a, b))
                half = math.acos(max(-1.0, min(1.0, a[0]*b[0]+a[1]*b[1]+a[2]*b[2])))/2.0
                return _add(pts[k], _mul(bis, (R20 + R10 + 0.025)/math.sin(half)))
            a, b = inward(pa, k), inward(pb, k)
            u = _nrm(_sub(b, a))
            cyl(G05, "Correas_D10", "cana10", _sub(a, _mul(u, 0.06)), _add(b, _mul(u, 0.06)), R10,
                "Correa_%s_%02d" % ("ABCDEF"[k], i+1))

    # ===== 08 cubierta permeable: latillas Ø6 sobre el tramo C-D, por bahía =====
    for i in range(NF-1):
        pa, pb = frame_pts3(i), frame_pts3(i+1)
        Lcd = _len(_sub(pa[3], pa[2]))
        n = int((Lcd - 0.30)/0.16)
        for j in range(n+1):
            f = (0.15 + j*0.16)/Lcd
            a = _add(pa[2], _mul(_sub(pa[3], pa[2]), f))
            b = _add(pb[2], _mul(_sub(pb[3], pb[2]), f))
            # encima del eje de la caña Ø20 (normal exterior del tramo)
            def up(p0, p1, q):
                t = _nrm(_sub(p1, p0)); nrm = _nrm((0.0, -t[2], t[1]))
                if nrm[2] < 0: nrm = _mul(nrm, -1)
                return _add(q, _mul(nrm, R20 + R06 + 0.005))
            a = up(pa[2], pa[3], a); b = up(pb[2], pb[3], b)
            u = _nrm(_sub(b, a))
            cyl(G08, "Latillas_Sombra_D6", "cana06", _sub(a, _mul(u, 0.05)), _add(b, _mul(u, 0.05)), R06,
                "Latilla_%02d_%02d" % (i+1, j+1))

    # ===== 06 arriostramientos: tensores Ø16 en cruz (muro cercano, cubierta, muro lejano) =====
    for (i0, nm) in ((1, "B02-03"), (8, "B09-10"), (15, "B16-17")):
        pa, pb = frame_pts3(i0), frame_pts3(i0+1)
        for (k0, k1, plano) in ((0, 1, "Muro_Cercano"), (2, 3, "Cubierta"), (4, 5, "Muro_Lejano")):
            for (s, e) in (((pa, k0), (pb, k1)), ((pa, k1), (pb, k0))):
                q0 = s[0][s[1]]; q1 = e[0][e[1]]
                def lift(pts, kk, q):
                    if kk in (0, 5):
                        nb = pts[1] if kk == 0 else pts[4]
                        return _add(q, _mul(_nrm(_sub(nb, q)), 0.30))
                    return q
                q0 = lift(s[0], s[1], q0); q1 = lift(e[0], e[1], q1)
                c = (q0[0], sum(p[1] for p in pa)/6.0, sum(p[2] for p in pa)/6.0)
                def outw(q):
                    d = _nrm((0.0, q[1]-c[1], q[2]-c[2])); return _add(q, _mul(d, R20 + 0.07))
                cyl(G06, "Tensores_Acero_Inox", "tensor", outw(q0), outw(q1), 0.008, "Tensor_%s_%s" % (nm, plano))

    # ===== plataforma: vigas principales, soleras, postes, cimentación =====
    beam_xs = [round(BEAM_DX*k, 3) for k in range(int(XE/BEAM_DX)+1)]
    posts = []
    for k, x in enumerate(beam_xs):
        y0, y1 = ymin_at(x)+0.10, ymax_at(x)-0.10
        cyl(G07, "Vigas_Principales_D20", "cana20", (x, y0-0.05, Z_BEAM), (x, y1+0.05, Z_BEAM), R20, "Viga_Principal_E%02d" % (k+1))
        ys = []
        if x <= X_MOUTH + 0.01:
            ya, yf = yA_at(x), yF_at(x)
            ys = [ya, yf]
            n = int(math.ceil((yf-ya)/1.5)); ys += [ya + (yf-ya)*j/n for j in range(1, n)]
            lo = y0 + 0.15
            if ya - lo > 0.4:
                n = int(math.ceil((ya-lo)/1.5)); ys += [lo + (ya-lo)*j/n for j in range(n)]
            if y1 - 0.15 - yf > 0.3: ys.append(y1 - 0.15)
        else:
            lo, hi = y0 + 0.15, y1 - 0.15
            n = int(math.ceil((hi-lo)/1.5)); ys = [lo + (hi-lo)*j/n for j in range(n+1)]
        # separación mínima entre apoyos (zapatas de 0.80 m): 0.90 m; los apoyos bajo soleras son obligatorios
        must = [ya, yf] if x <= X_MOUTH + 0.01 else []
        kept = list(must)
        for y in sorted(ys, key=lambda v: min([abs(v - m) for m in must] + [99.0]), reverse=True):
            if y in must: continue
            if all(abs(y - q) >= 0.90 for q in kept) and y0 - 0.01 <= y <= y1 + 0.01:
                kept.append(y); continue
            q = min(kept, key=lambda v: abs(v - y))          # desplazar a 0.90 m del apoyo más próximo
            y2 = q - 0.90 if y < q else q + 0.90
            if all(abs(y2 - v) >= 0.899 for v in kept) and y0 - 0.01 <= y2 <= y1 + 0.01:
                kept.append(y2)
        for y in sorted(kept):
            posts.append((x, y, k))
    sol_x0, sol_x1 = -0.25, X_MOUTH + 0.25
    for nm, fy in (("Cercana", yA_at), ("Lejana", yF_at)):
        a = (sol_x0, fy(0.0) + (fy(X_MOUTH)-fy(0.0))*sol_x0/X_MOUTH, Z_SOLERA)
        b = (sol_x1, fy(0.0) + (fy(X_MOUTH)-fy(0.0))*sol_x1/X_MOUTH, Z_SOLERA)
        cyl(G04, "Soleras_Apoyo_Porticos", "cana20", a, b, R20, "Solera_%s_D20" % nm)

    info["posts"] = []
    for n, (x, y, k) in enumerate(posts):
        zt = terrain(x, y)
        zp = zt + 0.20                              # cara superior del pedestal: 20 cm sobre terreno
        zb = zt - 0.60                              # fondo de zapata
        box(G02, "Zapatas", "concreto", x-0.40, y-0.40, zb, 0.80, 0.80, 0.30, "Zapata_%02d_80x80x30" % (n+1))
        box(G03, "Pedestales", "concreto", x-0.175, y-0.175, zb+0.30, 0.35, 0.35, zp-(zb+0.30), "Pedestal_%02d_35x35" % (n+1))
        box(G03, "Anclajes_Postes", "acero", x-0.13, y-0.13, zp, 0.26, 0.26, 0.012, "Anclaje_%02d_Placa" % (n+1))
        for sy in (-1, 1):
            box(G03, "Anclajes_Postes", "acero", x-0.09, y+sy*(R20+0.004)-0.004, zp, 0.18, 0.008, 0.22, "Anclaje_%02d_Oreja" % (n+1))
        c = (x, y, zp + 0.13)
        cyl(G03, "Anclajes_Postes", "perno", _add(c, (0, -0.135, 0)), _add(c, (0, 0.135, 0)), 0.008, "Anclaje_%02d_Perno_M16" % (n+1))
        z0 = zp + 0.03
        cyl(G04, "Postes_D20", "cana20", (x, y, z0), (x, y, Z_BEAM_BOT), R20, "Poste_%02d" % (n+1))
        info["posts"].append({"x": x, "y": y, "terreno": zt, "largo": Z_BEAM_BOT - z0})
        hpost = Z_BEAM_BOT - z0
        # riostra en "rodilla" Ø10 en el plano de la viga principal (dirección Y) si el poste es alto
        if hpost > 0.55:
            sy = 1 if (n % 2 == 0) else -1
            cyl(G06, "Riostras_Plataforma_D10", "cana10", (x, y + sy*0.15, Z_BEAM_BOT - min(0.45, hpost-0.15)),
                (x + 0.12, y + sy*0.55, Z_BEAM - 0.02), R10, "Riostra_Y_%02d" % (n+1))
    # cruces de San Andrés con tensores entre postes alineados (dirección X) bajo las soleras
    for nm, fy in (("Cercana", yA_at), ("Lejana", yF_at)):
        row = [(x, y) for (x, y, k) in posts if abs(y - fy(x)) < 0.01]
        row.sort()
        for j in range(len(row)-1):
            if j % 2: continue
            (xa, ya), (xb, yb) = row[j], row[j+1]
            za = terrain(xa, ya) + 0.45; zb2 = terrain(xb, yb) + 0.45
            if Z_BEAM_BOT - max(za, zb2) < 0.10: continue
            cyl(G06, "Tensores_Plataforma", "tensor", (xa+0.11, ya, za), (xb-0.11, yb, Z_BEAM_BOT-0.03), 0.008, "Tensor_X_%s_%d_a" % (nm, j))
            cyl(G06, "Tensores_Plataforma", "tensor", (xa+0.11, ya, Z_BEAM_BOT-0.03), (xb-0.11, yb, zb2), 0.008, "Tensor_X_%s_%d_b" % (nm, j))

    # viguetas Ø12 longitudinales (entre soleras y fuera de ellas)
    jy = []
    y = -3.75
    while y <= yF_at(X_MOUTH) + 0.40:
        jy.append(round(y, 3)); y += 0.45
    for k, y in enumerate(jy):
        xs = [XS + s*0.02 for s in range(int((XE-XS)/0.02)+1)]
        ok = []
        for xx in xs:
            near_sol = (xx <= sol_x1 + 0.15) and (abs(y - yA_at(min(max(xx, 0), X_MOUTH))) < 0.25 or abs(y - yF_at(min(max(xx, 0), X_MOUTH))) < 0.25)
            ok.append((ymin_at(xx)+0.08 <= y <= ymax_at(xx)-0.08) and not near_sol)
        run = None
        for xx, good in zip(xs + [None], ok + [False]):
            if good and run is None: run = xx
            if (not good) and run is not None:
                xend = xx - 0.02 if xx is not None else xs[-1]
                if xend - run > 1.0:
                    cyl(G07, "Viguetas_D12", "cana12", (run, y, Z_JOIST), (xend, y, Z_JOIST), R12, "Vigueta_%02d_%.1f" % (k+1, run))
                run = None
    # entablado Ø6 transversal, cortado en las soleras
    x = XS; i = 0
    while x <= XE + 1e-6:
        jag = 0.07*((i*7) % 4) if x > 2.4 else 0.0
        lo = ymin_at(x) + jag
        hi = ymax_at(x) - (0.04*((i*5) % 3) if x > 8.9 else 0.0)
        cuts = [(lo, hi)]
        if x <= sol_x1:
            ya, yf = yA_at(min(max(x, 0), X_MOUTH)), yF_at(min(max(x, 0), X_MOUTH))
            cuts = [(lo, ya - R20 - 0.01), (ya + R20 + 0.01, yf - R20 - 0.01), (yf + R20 + 0.01, hi)]
        for c0, c1 in cuts:
            if c1 - c0 > 0.08:
                cyl(G07, "Entablado_D6", "cana06", (x, c0, Z_SLAT), (x, c1, Z_SLAT), R06, "Tablilla_%03d" % (i+1))
        x += 0.085; i += 1

    # ===== rampa (A.120): pendiente según desnivel =====
    ry0, ry1 = -1.95, -0.65
    def ramp_len(slope):
        L = 0.2
        while L < 20:
            zt = terrain(XE + L, (ry0+ry1)/2)
            if FFL - slope*L <= zt + 0.02: return L, FFL - zt
            L += 0.02
        return L, 0
    slope = 0.12
    for s_try in (0.12, 0.10, 0.08, 0.06):
        L, rise = ramp_len(s_try)
        lim = 0.25 if s_try == 0.12 else (0.75 if s_try == 0.10 else (1.20 if s_try == 0.08 else 1.80))
        if rise <= lim:
            slope = s_try; break
    L, rise = ramp_len(slope)
    info["rampa"] = {"pendiente": slope, "largo": round(L, 2), "desnivel": round(rise, 2)}
    RG = "Rampa_Acceso"
    nsl = int(L/0.085)
    for j in range(nsl+1):
        xx = XE + j*0.085
        z = FFL - slope*(xx - XE)
        cyl(G07, RG, "cana06", (xx, ry0, z - R06), (xx, ry1, z - R06), R06, "Rampa_Tablilla_%02d" % (j+1))
    for j, y in enumerate((ry0+0.12, (ry0+ry1)/2, ry1-0.12)):
        za = FFL - 2*R06 - R12
        zb = FFL - slope*L - 2*R06 - R12
        cyl(G07, RG, "cana12", (XE + 0.02, y, za - slope*0.02), (XE + L, y, zb), R12, "Rampa_Larguero_%d" % (j+1))
    xb = XE + L + 0.05
    zt = terrain(xb, (ry0+ry1)/2)
    box(G02, "Zapatas", "concreto", xb - 0.25, ry0 - 0.10, zt - 0.30, 0.50, (ry1-ry0) + 0.20, 0.32, "Rampa_Losa_Arranque")
    if L > 2.2:   # apoyo intermedio
        xm = XE + L/2; zt = terrain(xm, (ry0+ry1)/2)
        zr = FFL - slope*(L/2) - 2*R06 - 2*R12
        cyl(G07, RG, "cana12", (xm, ry0 + 0.05, zr - R12), (xm, ry1 - 0.05, zr - R12), R12, "Rampa_Travesano_Medio")
        for y in (ry0 + 0.12, ry1 - 0.12):
            box(G02, "Zapatas", "concreto", xm - 0.15, y - 0.15, zt - 0.40, 0.30, 0.30, 0.60, "Rampa_Dado_Medio")
            cyl(G04, "Postes_D20", "cana20", (xm, y, zt + 0.23), (xm, y, zr - 2*R12), R20 if zr - 2*R12 - zt - 0.23 > 0.15 else 0.06,
                "Rampa_Poste_Medio")
    if L > 3.0:   # barandas de caña (A.120: rampas > 3 m)
        for y in (ry0 - 0.04, ry1 + 0.04):
            cyl(G09, "Barandas_Rampa", "cana06", (XE, y, FFL + 0.90), (XE + L, y, FFL - slope*L + 0.90), 0.025, "Pasamano")
            nposts = int(L/1.2) + 1
            for j in range(nposts + 1):
                xx = XE + L*j/nposts; z = FFL - slope*(xx-XE)
                cyl(G09, "Barandas_Rampa", "cana06", (xx, y, z), (xx, y, z + 0.90), 0.03, "Parante_Baranda")

    # ===== 09 tumbona longitudinal (respaldo sube hacia el fondo, mirada al mar) =====
    TG = "Tumbona_Longitudinal"
    prof = [(4.60, 0.06), (3.30, 0.30), (2.95, 0.40), (2.35, 1.02), (2.12, 1.22)]
    ty0, ty1 = 1.10, 2.55
    segs = []
    tot = 0.0
    for a, b in zip(prof, prof[1:]):
        Ls = math.hypot(b[0]-a[0], b[1]-a[1]); segs.append((a, b, Ls)); tot += Ls
    s = 0.04; j = 0
    while s < tot - 0.02:
        acc = 0.0
        for a, b, Ls in segs:
            if s <= acc + Ls:
                f = (s-acc)/Ls; px = a[0] + (b[0]-a[0])*f; pz = a[1] + (b[1]-a[1])*f; break
            acc += Ls
        cyl(G09, TG, "cana06", (px, ty0, FFL + pz + R12), (px, ty1, FFL + pz + R12), R06, "Tumbona_Liston_%02d" % (j+1))
        s += 0.075; j += 1
    for y in (ty0 + 0.12, (ty0+ty1)/2, ty1 - 0.12):
        for a, b in zip(prof, prof[1:]):
            cyl(G09, TG, "cana12", (a[0], y, FFL + a[1] - 0.03), (b[0], y, FFL + b[1] - 0.03), 0.045, "Tumbona_Larguero")
        for (px, pz) in prof[1:]:
            if pz > 0.15:
                cyl(G09, TG, "cana10", (px, y, FFL), (px, y, FFL + pz - 0.07), 0.04, "Tumbona_Pata")
    # banca baja junto a la tumbona
    for k in range(7):
        y = 0.60 + k*0.075
        cyl(G09, "Banca_Baja", "cana06", (4.95, y, FFL + 0.42), (5.95, y, FFL + 0.42), R06, "Banca_Liston_%d" % (k+1))
    for xx in (5.03, 5.87):
        cyl(G09, "Banca_Baja", "cana10", (xx, 0.56, FFL + 0.36), (xx, 1.10, FFL + 0.36), 0.04, "Banca_Travesano")
        for y in (0.62, 1.04):
            cyl(G09, "Banca_Baja", "cana10", (xx, y, FFL), (xx, y, FFL + 0.32), 0.04, "Banca_Pata")

    # ===== 10 figuras humanas esquemáticas =====
    def person(name, pts, rad):
        # pts: dict de articulaciones; rad: radio de segmentos
        bones = [("pelvis", "torax", 0.15), ("torax", "cuello", 0.07), ("torax", "hombroI", 0.06), ("torax", "hombroD", 0.06),
                 ("hombroI", "manoI", 0.045), ("hombroD", "manoD", 0.045), ("pelvis", "rodillaI", 0.075), ("pelvis", "rodillaD", 0.075),
                 ("rodillaI", "pieI", 0.055), ("rodillaD", "pieD", 0.055)]
        for a, b, r in bones:
            cyl(G10, name, "figura", pts[a], pts[b], r*rad, "%s_%s_%s" % (name, a, b))
        for j in ("pelvis", "torax", "rodillaI", "rodillaD", "hombroI", "hombroD"):
            sph(G10, name, "figura_esf", pts[j], (0.075*rad, 0.075*rad, 0.075*rad), name + "_" + j)
        sph(G10, name, "figura_esf", pts["cabeza"], (0.10, 0.10, 0.115), name + "_cabeza")
    def recl(name, y, knee_up):
        # reclinada sobre la tumbona: espalda sobre el respaldo (sube hacia -X), mirada al mar (+X)
        z = FFL + R12 + 2*R06 + 0.10
        P0 = {"pelvis": (3.16, y, z + 0.38), "torax": (2.72, y, z + 0.78), "cuello": (2.52, y, z + 0.99),
              "cabeza": (2.50, y, z + 1.13), "hombroI": (2.62, y - 0.19, z + 0.90), "hombroD": (2.62, y + 0.19, z + 0.90),
              "manoI": (3.05, y - 0.30, z + 0.50), "manoD": (3.05, y + 0.30, z + 0.50)}
        if knee_up:
            P0.update({"rodillaI": (3.55, y - 0.10, z + 0.62), "rodillaD": (3.55, y + 0.10, z + 0.62),
                       "pieI": (3.92, y - 0.12, z + 0.17), "pieD": (3.92, y + 0.12, z + 0.17)})
        else:
            P0.update({"rodillaI": (3.55, y - 0.10, z + 0.27), "rodillaD": (3.55, y + 0.10, z + 0.27),
                       "pieI": (4.00, y - 0.12, z + 0.12), "pieD": (4.00, y + 0.12, z + 0.12)})
        person(name, P0, 1.0)
    recl("Persona_01_Recostada", 1.45, False)
    recl("Persona_02_Recostada", 2.15, True)
    # sentada en el piso junto a la boca, apoyada en el pie cercano del pórtico 18, mirando al mar
    xs0, ys0 = 6.95, 0.62
    z = FFL
    Ps = {"pelvis": (xs0, ys0, z + 0.14), "torax": (xs0 - 0.10, ys0, z + 0.55), "cuello": (xs0 - 0.14, ys0, z + 0.75),
          "cabeza": (xs0 - 0.12, ys0, z + 0.88), "hombroI": (xs0 - 0.12, ys0 - 0.19, z + 0.66), "hombroD": (xs0 - 0.12, ys0 + 0.19, z + 0.66),
          "manoI": (xs0 + 0.30, ys0 - 0.12, z + 0.42), "manoD": (xs0 + 0.30, ys0 + 0.14, z + 0.42),
          "rodillaI": (xs0 + 0.40, ys0 - 0.09, z + 0.44), "rodillaD": (xs0 + 0.40, ys0 + 0.11, z + 0.44),
          "pieI": (xs0 + 0.62, ys0 - 0.10, z + 0.06), "pieD": (xs0 + 0.64, ys0 + 0.12, z + 0.06)}
    person("Persona_03_Sentada_Boca", Ps, 1.0)

    # ===== 11 vegetación costera (arbustos bajos), fuera de la huella =====
    seed = 7
    k = 0; tries = 0
    while k < 70 and tries < 2000:
        tries += 1
        seed = (seed*1103515245 + 12345) % 2147483648
        x = -8.0 + (seed % 10000)/10000.0*25.0
        seed = (seed*1103515245 + 12345) % 2147483648
        y = -11.0 + (seed % 10000)/10000.0*21.0
        seed = (seed*1103515245 + 12345) % 2147483648
        s = 0.25 + (seed % 1000)/1000.0*0.45
        inside = (XS - 0.8 <= x <= XE + 0.8 and ymin_at(min(max(x, XS), XE)) - 0.8 <= y <= ymax_at(min(max(x, XS), XE)) + 0.8)
        inside = inside or (XE <= x <= XE + 5.5 and ry0 - 0.8 <= y <= ry1 + 0.8)
        if inside or x > 17.0: continue
        # despejar el cono visual de las escenas 01/12 (cámara en el lado de tierra, mirando al mar)
        if -14.0 < y < -1.0 and -3.0 < x < 13.0: continue
        if -12.0 < y < 3.0 and -6.0 < x < -0.5 and s > 0.40: continue
        k += 1
        zt = terrain(x, y)
        sph(G11, "Arbustos_Costeros", "arbusto", (x, y, zt + s*0.35), (s*1.25, s*1.0, s*0.65), "Arbusto_%02d" % k)
        if seed % 2 == 0:
            sph(G11, "Arbustos_Costeros", "arbusto2", (x + s*0.6, y - s*0.3, zt + s*0.25), (s*0.8, s*0.7, s*0.45), "Arbusto_%02db" % k)

    # ===== 12 cotas (marcadores geométricos) =====
    pm = frame_pts3(NF-1)
    yg = yA_at(X_MOUTH) + GREEN_U
    cyl(G12, "Cota_Linea_Verde_2.10m", "verde", (X_MOUTH, yg, FFL), (X_MOUTH, yg, FFL + GREEN_H), 0.02, "COTA_2.10m_NPT_a_cara_inferior_viga")
    for zz in (FFL, FFL + GREEN_H):
        cyl(G12, "Cota_Linea_Verde_2.10m", "verde", (X_MOUTH, yg - 0.10, zz), (X_MOUTH, yg + 0.10, zz), 0.008, "COTA_2.10m_Tope")
    # arcos de ángulo en los vértices de la boca
    pr = frame_profile(NF-1)
    for k, lab in ((1, "B_165"), (2, "C_120"), (3, "D_105"), (4, "E_155"), (0, "A_%.1f" % ANG_FOOT), (5, "F_%.1f" % ANG_FOOT)):
        v = pr[k]
        if k == 0: a_dir = (1.0, 0.0); b_dir = (pr[1][0]-v[0], pr[1][1]-v[1])
        elif k == 5: a_dir = (-1.0, 0.0); b_dir = (pr[4][0]-v[0], pr[4][1]-v[1])
        else: a_dir = (pr[k-1][0]-v[0], pr[k-1][1]-v[1]); b_dir = (pr[k+1][0]-v[0], pr[k+1][1]-v[1])
        a0 = math.atan2(a_dir[1], a_dir[0]); a1 = math.atan2(b_dir[1], b_dir[0])
        da = a1 - a0
        while da > math.pi: da -= 2*math.pi
        while da < -math.pi: da += 2*math.pi
        rr = 0.38; nseg = 10
        for j in range(nseg):
            t0 = a0 + da*j/nseg; t1 = a0 + da*(j+1)/nseg
            p0 = (X_MOUTH + 0.14, yA_at(X_MOUTH) + v[0] + rr*math.cos(t0), ZF + v[1] + rr*math.sin(t0))
            p1 = (X_MOUTH + 0.14, yA_at(X_MOUTH) + v[0] + rr*math.cos(t1), ZF + v[1] + rr*math.sin(t1))
            cyl(G12, "Angulos_Referencia", "marcador", p0, p1, 0.008, "ANG_" + lab)
    # cotas generales (líneas finas con topes)
    def dim(name, a, b, tick):
        cyl(G12, "Cotas_Generales", "marcador", a, b, 0.006, name)
        for p in (a, b):
            cyl(G12, "Cotas_Generales", "marcador", _sub(p, tick), _add(p, tick), 0.006, name + "_tope")
    dim("COTA_Largo_tunel_%.2fm" % X_MOUTH, (0.0, -0.9, FFL + 0.02), (X_MOUTH, -0.9, FFL + 0.02), (0, 0.08, 0))
    dim("COTA_Largo_plataforma_%.2fm" % (XE - XS), (XS, -4.6, FFL + 0.02), (XE, -4.6, FFL + 0.02), (0, 0.08, 0))
    dim("COTA_Ancho_boca_%.2fm" % MOUTH[5][0], (X_MOUTH + 0.25, yA_at(X_MOUTH), FFL + 0.02), (X_MOUTH + 0.25, yF_at(X_MOUTH), FFL + 0.02), (0.08, 0, 0))
    hmax = max(p[2] for p in pm) + R20 - FFL
    dim("COTA_Altura_max_boca_%.2fm_sobre_NPT" % hmax, (X_MOUTH + 0.25, pm[3][1], FFL), (X_MOUTH + 0.25, pm[3][1], FFL + hmax), (0, 0.08, 0))
    # ejes estructurales (00)
    for k, x in enumerate(beam_xs):
        cyl(G00, "Ejes_Estructurales", "eje", (x, ymin_at(x) - 1.2, FFL + 0.005), (x, ymax_at(x) + 1.2, FFL + 0.005), 0.004, "EJE_%d" % (k+1))
    for nm, fy in (("A_Solera_Cercana", yA_at), ("F_Solera_Lejana", yF_at)):
        cyl(G00, "Ejes_Estructurales", "eje", (-1.5, fy(0) - (fy(X_MOUTH)-fy(0))*1.5/X_MOUTH, FFL + 0.005),
            (X_MOUTH + 1.5, fy(X_MOUTH) + (fy(X_MOUTH)-fy(0))*1.5/X_MOUTH, FFL + 0.005), 0.004, "EJE_" + nm)

    # ===== 13 despiece constructivo (copia separada, no altera el modelo) =====
    DX0, DY0 = 2.0, 16.0
    zt = terrain(DX0, DY0)
    base = zt + 0.6
    lift = 0.0
    def lvl(h):
        return base + h
    box(G13, "Despiece_Apoyo_Tipo", "concreto", DX0 - 0.40, DY0 - 0.40, lvl(0.00), 0.80, 0.80, 0.30, "D1_Zapata_80x80x30")
    box(G13, "Despiece_Apoyo_Tipo", "concreto", DX0 - 0.175, DY0 - 0.175, lvl(0.55), 0.35, 0.35, 0.80, "D2_Pedestal_35x35")
    box(G13, "Despiece_Apoyo_Tipo", "acero", DX0 - 0.13, DY0 - 0.13, lvl(1.60), 0.26, 0.26, 0.012, "D3_Placa_Anclaje")
    for sy in (-1, 1):
        box(G13, "Despiece_Apoyo_Tipo", "acero", DX0 - 0.09, DY0 + sy*0.104 - 0.004, lvl(1.60), 0.18, 0.008, 0.22, "D3_Oreja")
    cyl(G13, "Despiece_Apoyo_Tipo", "cana20", (DX0, DY0, lvl(2.05)), (DX0, DY0, lvl(2.85)), R20, "D4_Poste_D20")
    cyl(G13, "Despiece_Apoyo_Tipo", "cana20", (DX0, DY0 - 0.9, lvl(3.25)), (DX0, DY0 + 0.9, lvl(3.25)), R20, "D5_Viga_Principal_D20")
    cyl(G13, "Despiece_Apoyo_Tipo", "cana20", (DX0 - 0.9, DY0, lvl(3.75)), (DX0 + 0.9, DY0, lvl(3.75)), R20, "D6_Solera_D20")
    box(G13, "Despiece_Apoyo_Tipo", "acero", DX0 - 0.15, DY0 - 0.15, lvl(4.15), 0.30, 0.30, 0.012, "D7_Zapata_Metalica_Pie")
    cyl(G13, "Despiece_Apoyo_Tipo", "cana20", (DX0, DY0, lvl(4.55)), (DX0, DY0 + 0.05, lvl(5.70)), R20, "D8_Pie_Portico_D20")
    for j in range(5):
        cyl(G13, "Despiece_Apoyo_Tipo", "cana12", (DX0 + 1.2, DY0 - 0.9 + j*0.45, lvl(3.65)), (DX0 + 1.2, DY0 - 0.9 + j*0.45 + 0.01, lvl(3.65)), R12, "D9_Vigueta_D12_seccion")
    for j in range(8):
        cyl(G13, "Despiece_Apoyo_Tipo", "cana06", (DX0 + 1.8 + j*0.085, DY0 - 0.9, lvl(4.05)), (DX0 + 1.8 + j*0.085, DY0 + 0.9, lvl(4.05)), R06, "D10_Tablilla_D6")
    # nodo tipo despiezado
    NX = DX0 + 4.0
    a = (NX, DY0, lvl(2.5)); b = (NX, DY0 + 0.8, lvl(3.2)); c = (NX, DY0 - 0.8, lvl(3.2))
    cyl(G13, "Despiece_Nodo_Tipo", "cana20", a, (NX, DY0 + 0.0, lvl(1.8)), R20, "N1_Cana_D20_inferior")
    cyl(G13, "Despiece_Nodo_Tipo", "cana20", (NX, DY0 + 0.35, lvl(3.3)), (NX, DY0 + 1.2, lvl(3.9)), R20, "N2_Cana_D20_superior")
    cyl(G13, "Despiece_Nodo_Tipo", "acero", (NX - 0.12, DY0 + 0.1, lvl(3.0)), (NX + 0.12, DY0 + 0.1, lvl(3.0)), 0.07, "N3_Pasador_Central")
    for sx in (-1, 1):
        boxa(G13, "Despiece_Nodo_Tipo", "acero", (NX + sx*0.45 - 0.004, DY0 - 0.3, lvl(2.6)), (0.008, 0, 0), (0, 0.6, 0), (0, 0, 0.6), "N4_Pletina_8mm")
    for j in range(4):
        cyl(G13, "Despiece_Nodo_Tipo", "perno", (NX - 0.7, DY0 - 0.2 + j*0.12, lvl(3.7)), (NX + 0.7, DY0 - 0.2 + j*0.12, lvl(3.7)), 0.008, "N5_Perno_M16_inox")

    info["mouth"] = MOUTH; info["mouth_info"] = MOUTH_INFO
    info["beam_xs"] = beam_xs
    info["n_posts"] = len(posts)
    return P, info

def terrain_grid(x0=-8.0, x1=26.0, y0=-12.0, y1=14.0, step=0.75):
    xs = []; x = x0
    while x <= x1 + 1e-9: xs.append(round(x, 3)); x += step
    ys = []; y = y0
    while y <= y1 + 1e-9: ys.append(round(y, 3)); y += step
    return xs, ys
