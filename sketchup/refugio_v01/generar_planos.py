# -*- coding: utf-8 -*-
"""Genera las láminas PDF, la tabla de componentes y el resumen de control a partir de
geometria_refugio.py (la misma geometría que se envió a SketchUp).
Uso: python3 generar_planos.py <carpeta_salida>"""
import math, os, sys, json, collections
from reportlab.lib.pagesizes import A3, landscape
from reportlab.pdfgen import canvas
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.colors import Color, black, white

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "entregables")
os.makedirs(OUT, exist_ok=True)
G = {"math": math}
exec(open(os.path.join(HERE, "geometria_refugio.py"), encoding="utf-8").read(), G)
P, INFO = G["build"]()

pdfmetrics.registerFont(TTFont("DV", "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"))
pdfmetrics.registerFont(TTFont("DVB", "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"))
W, H = landscape(A3)
MM = 72/25.4

COL = {"cana20": (0.62, 0.46, 0.22), "cana12": (0.70, 0.54, 0.30), "cana10": (0.74, 0.58, 0.33), "cana06": (0.80, 0.66, 0.42),
       "acero": (0.55, 0.57, 0.60), "perno": (0.30, 0.31, 0.33), "tensor": (0.25, 0.27, 0.30), "concreto": (0.72, 0.71, 0.68),
       "figura": (0.93, 0.92, 0.89), "figura_esf": (0.93, 0.92, 0.89), "arbusto": (0.45, 0.50, 0.33), "arbusto2": (0.56, 0.55, 0.37),
       "verde": (0.10, 0.85, 0.45), "marcador": (0.85, 0.12, 0.38), "eje": (0.85, 0.25, 0.20)}

def sheet_frame(c, code, title, scale_txt, note=None):
    c.setStrokeColor(black); c.setLineWidth(1.2)
    c.rect(10*MM, 10*MM, W-20*MM, H-20*MM)
    bx = W - 10*MM - 150*MM
    c.rect(bx, 10*MM, 150*MM, 32*MM)
    c.setFont("DVB", 11); c.drawString(bx + 4*MM, 34*MM, "REFUGIO COSTERO DE CAÑA — PROPUESTA CONSTRUCTIVA V01")
    c.setFont("DV", 9); c.drawString(bx + 4*MM, 28*MM, title)
    c.drawString(bx + 4*MM, 22*MM, "Escala: " + scale_txt + "   ·   Unidades: metros   ·   NPT +0.90 (datum ±0.00)")
    c.setFont("DV", 7.5)
    c.drawString(bx + 4*MM, 16.5*MM, "Nivel 2: propuesta preliminar. NO apta para construcción sin cálculo estructural,")
    c.drawString(bx + 4*MM, 12.8*MM, "estudio de suelos (E.050) y revisión de profesional colegiado.")
    c.setFont("DVB", 20); c.drawRightString(W - 14*MM, 45*MM, code)
    if note:
        c.setFont("DV", 8)
        y = 60*MM
        for line in note:
            c.drawString(bx, y, line); y -= 4*MM

def nice(c, x, y, s, size=8, bold=False, col=black, anchor="l"):
    c.setFillColor(col); c.setFont("DVB" if bold else "DV", size)
    if anchor == "c": c.drawCentredString(x, y, s)
    elif anchor == "r": c.drawRightString(x, y, s)
    else: c.drawString(x, y, s)
    c.setFillColor(black)

# ---------- proyección genérica ----------
class Ortho:
    def __init__(self, axes, depth, origin, scale):
        self.ax, self.dp, self.o, self.s = axes, depth, origin, scale   # axes: (i,sign),(j,sign)
    def p(self, q):
        (i, si), (j, sj) = self.ax
        return (self.o[0] + si*q[i]*self.s, self.o[1] + sj*q[j]*self.s)
    def d(self, q):
        k, sk = self.dp
        return sk*q[k]
    def w(self, r, q=None): return 2*r*self.s

class Persp:
    def __init__(self, eye, tgt, fov, origin, half_h):
        self.e = eye; f = [tgt[i]-eye[i] for i in range(3)]; L = math.sqrt(sum(v*v for v in f)); self.f = [v/L for v in f]
        r = [self.f[1], -self.f[0], 0.0]; L = math.hypot(r[0], r[1]); self.r = [r[0]/L, r[1]/L, 0.0]
        u = [self.r[1]*self.f[2]-0*self.f[1], 0*self.f[0]-self.r[0]*self.f[2], self.r[0]*self.f[1]-self.r[1]*self.f[0]]
        self.u = u; self.k = half_h/math.tan(math.radians(fov/2)); self.o = origin
    def cam(self, q):
        v = [q[i]-self.e[i] for i in range(3)]
        return (sum(v[i]*self.r[i] for i in range(3)), sum(v[i]*self.u[i] for i in range(3)), sum(v[i]*self.f[i] for i in range(3)))
    def p(self, q):
        x, y, z = self.cam(q); z = max(z, 0.05)
        return (self.o[0] + self.k*x/z, self.o[1] + self.k*y/z)
    def d(self, q): return -self.cam(q)[2]
    def w(self, r, q): return 2*r*self.k/max(self.cam(q)[2], 0.05)

def hull(pts):
    pts = sorted(set(pts))
    if len(pts) < 3: return pts
    def cr(o, a, b): return (a[0]-o[0])*(b[1]-o[1]) - (a[1]-o[1])*(b[0]-o[0])
    lo, up = [], []
    for p in pts:
        while len(lo) >= 2 and cr(lo[-2], lo[-1], p) <= 0: lo.pop()
        lo.append(p)
    for p in reversed(pts):
        while len(up) >= 2 and cr(up[-2], up[-1], p) <= 0: up.pop()
        up.append(p)
    return lo[:-1] + up[:-1]

def draw_prims(c, proj, prims, clip=None, shade=True, outline=0.25):
    items = []
    for pr in prims:
        if pr[0] == "cyl":
            _, g, s, d, a, b, r, n = pr
            mid = ((a[0]+b[0])/2, (a[1]+b[1])/2, (a[2]+b[2])/2)
            items.append((proj.d(mid), pr))
        elif pr[0] == "box":
            o, ex, ey, ez = pr[4], pr[5], pr[6], pr[7]
            mid = tuple(o[i] + (ex[i]+ey[i]+ez[i])/2 for i in range(3))
            items.append((proj.d(mid), pr))
        else:
            items.append((proj.d(pr[4]), pr))
    items.sort(key=lambda t: t[0])
    for _, pr in items:
        col = COL.get(pr[3], (0.5, 0.5, 0.5))
        if pr[0] == "cyl":
            a, b, r = pr[4], pr[5], pr[6]
            pa, pb = proj.p(a), proj.p(b)
            wa = proj.w(r, a) if isinstance(proj, Persp) else proj.w(r)
            wd = max(wa, 0.25)
            if outline and wd > 1.2:
                c.setStrokeColorRGB(*[v*0.55 for v in col]); c.setLineWidth(wd + outline*2); c.setLineCap(1)
                c.line(pa[0], pa[1], pb[0], pb[1])
            c.setStrokeColorRGB(*col); c.setLineWidth(wd); c.setLineCap(1)
            c.line(pa[0], pa[1], pb[0], pb[1])
        elif pr[0] == "box":
            o, ex, ey, ez = pr[4], pr[5], pr[6], pr[7]
            cs = []
            for i in (0, 1):
                for j in (0, 1):
                    for k in (0, 1):
                        cs.append(proj.p(tuple(o[t] + i*ex[t] + j*ey[t] + k*ez[t] for t in range(3))))
            hp = hull([(round(x, 2), round(y, 2)) for x, y in cs])
            if len(hp) >= 3:
                path = c.beginPath(); path.moveTo(*hp[0])
                for q in hp[1:]: path.lineTo(*q)
                path.close()
                c.setFillColorRGB(*col); c.setStrokeColorRGB(*[v*0.6 for v in col]); c.setLineWidth(0.3)
                c.drawPath(path, fill=1, stroke=1)
        else:
            cc, rr = pr[4], pr[5]
            pc = proj.p(cc)
            if isinstance(proj, Persp):
                rad = proj.w(max(rr), cc)/2
            else:
                (i, _), (j, _) = proj.ax; rad = max(rr[i], rr[j])*proj.s
            c.setFillColorRGB(*col); c.setStrokeColorRGB(*[v*0.7 for v in col]); c.setLineWidth(0.3)
            c.circle(pc[0], pc[1], max(rad, 0.4), fill=1, stroke=1)

def terrain_profile(c, proj, pts, col=(0.55, 0.47, 0.35), lw=1.2, fill=False, base=None):
    pp = [proj.p(q) for q in pts]
    c.setStrokeColorRGB(*col); c.setLineWidth(lw)
    path = c.beginPath(); path.moveTo(*pp[0])
    for q in pp[1:]: path.lineTo(*q)
    if fill and base is not None:
        path.lineTo(pp[-1][0], base); path.lineTo(pp[0][0], base); path.close()
        c.setFillColorRGB(0.90, 0.85, 0.74); c.drawPath(path, fill=1, stroke=1)
    else:
        c.drawPath(path, fill=0, stroke=1)

def dimline(c, a, b, txt, off=(0, 0), size=8, col=(0.1, 0.1, 0.1)):
    c.setStrokeColorRGB(*col); c.setLineWidth(0.5)
    a2 = (a[0]+off[0], a[1]+off[1]); b2 = (b[0]+off[0], b[1]+off[1])
    c.line(a[0], a[1], a2[0], a2[1]); c.line(b[0], b[1], b2[0], b2[1]); c.line(a2[0], a2[1], b2[0], b2[1])
    for q in (a2, b2):
        c.line(q[0]-2, q[1]-2, q[0]+2, q[1]+2)
    ang = math.degrees(math.atan2(b2[1]-a2[1], b2[0]-a2[0]))
    c.saveState(); c.translate((a2[0]+b2[0])/2, (a2[1]+b2[1])/2); c.rotate(ang)
    c.setFillColorRGB(*col); c.setFont("DV", size); c.drawCentredString(0, 2.5, txt); c.restoreState()

X_M = G["X_MOUTH"]; FFL = G["FFL"]; ZF = G["ZF"]; R20 = G["R20"]
terrain = G["terrain"]
sel = lambda *grs: [p for p in P if p[1] in grs]
G04, G03, G02 = G["G04"], G["G03"], G["G02"]
ALLSTRUCT = [G["G02"], G["G03"], G["G04"], G["G05"], G["G06"], G["G07"], G["G08"], G["G09"]]

pdf_path = os.path.join(OUT, "REFUGIO_CAÑA_V01_LAMINAS.pdf")
c = canvas.Canvas(pdf_path, pagesize=(W, H))
c.setTitle("Refugio costero de caña - Propuesta constructiva V01")

# ===== L-01 perspectiva (como la foto) =====
sheet_frame(c, "L-01", "Vista principal de referencia (perspectiva desde el lado cercano, como la fotografía)", "sin escala")
CAM01 = json.loads(os.environ.get("CAM01", "[[1.0,-11.5,1.65],[7.8,1.8,1.7],46]"))
cam = Persp(tuple(CAM01[0]), tuple(CAM01[1]), CAM01[2], (W/2 - 30*MM, H/2 + 20*MM), 120*MM)
# cielo y mar
c.setFillColorRGB(0.80, 0.89, 0.97); c.rect(12*MM, 12*MM, W-24*MM, H-24*MM, fill=1, stroke=0)
hz = cam.p((60.0, 1.0, -3.3))[1]
c.setFillColorRGB(0.33, 0.55, 0.72); c.rect(12*MM, 12*MM, W-24*MM, hz-12*MM, fill=1, stroke=0)
# terreno como triángulos
xs, ys = G["terrain_grid"](step=0.75)
tris = []
for j in range(len(ys)-1):
    for i in range(len(xs)-1):
        q = [(xs[i], ys[j]), (xs[i+1], ys[j]), (xs[i+1], ys[j+1]), (xs[i], ys[j+1])]
        q3 = [(a, b, terrain(a, b)) for a, b in q]
        for t in ((q3[0], q3[1], q3[2]), (q3[0], q3[2], q3[3])):
            mid = tuple(sum(v[k] for v in t)/3 for k in range(3))
            if cam.cam(mid)[2] < 0.5: continue
            n = ((t[1][1]-t[0][1])*(t[2][2]-t[0][2]) - (t[1][2]-t[0][2])*(t[2][1]-t[0][1]),
                 (t[1][2]-t[0][2])*(t[2][0]-t[0][0]) - (t[1][0]-t[0][0])*(t[2][2]-t[0][2]),
                 (t[1][0]-t[0][0])*(t[2][1]-t[0][1]) - (t[1][1]-t[0][1])*(t[2][0]-t[0][0]))
            Ln = math.sqrt(sum(v*v for v in n)) or 1
            lit = 0.75 + 0.25*max(0, (n[0]*0.4 - n[1]*0.3 + n[2]*0.85)/Ln)
            tris.append((cam.d(mid), t, lit))
tris.sort(key=lambda t: t[0])
for _, t, lit in tris:
    pp = [cam.p(v) for v in t]
    path = c.beginPath(); path.moveTo(*pp[0]); path.lineTo(*pp[1]); path.lineTo(*pp[2]); path.close()
    c.setFillColorRGB(0.84*lit, 0.76*lit, 0.60*lit); c.setStrokeColorRGB(0.84*lit, 0.76*lit, 0.60*lit); c.setLineWidth(0.2)
    c.drawPath(path, fill=1, stroke=1)
def above_ground(pr):
    if pr[1] == G["G02"]: return None
    if pr[0] == "box" and pr[2] == "Pedestales":
        o, ex, ey, ez = pr[4], pr[5], pr[6], pr[7]
        zt = terrain(o[0] + ex[0]/2, o[1] + ey[1]/2) - 0.02
        top = o[2] + ez[2]
        return ("box", pr[1], pr[2], pr[3], (o[0], o[1], zt), ex, ey, (0, 0, top - zt), pr[8])
    return pr
vis = [above_ground(p) for p in P if p[1] not in (G["G00"], G["G12"], G["G13"]) and cam.cam(p[4])[2] > 0.3]
vis = [p for p in vis if p is not None]
draw_prims(c, cam, vis, outline=0.2)
c.setFillColor(white); c.rect(12*MM, H-30*MM, 140*MM, 16*MM, fill=1, stroke=0)
nice(c, 16*MM, H-20*MM, "Escena 01 — Vista principal de referencia", 12, True)
nice(c, 16*MM, H-26*MM, "Reproducción de la cámara de la escena 01 del archivo .skp (generada desde la geometría del modelo).", 7.5)
c.showPage()

# ===== L-02 planta general =====
sheet_frame(c, "L-02", "Planta general: huella de plataforma, pórticos, asientos, apoyos y cotas", "1:75 (A3)")
s = 1000/75.0*MM/1000*1000/1000  # 1 m -> mm a 1:75
s = (1000/75.0)*MM
pl = Ortho(((0, 1), (1, 1)), (2, 1), (40*MM, 120*MM), s)
plan_prims = [p for p in P if p[1] in (G["G02"], G["G03"], G["G04"], G["G05"], G["G07"], G["G09"], G["G10"], G["G06"])]
draw_prims(c, pl, plan_prims, outline=0.15)
# ejes
for k, x in enumerate(INFO["beam_xs"]):
    a = pl.p((x, G["ymin_at"](x)-1.0, 0)); b = pl.p((x, G["ymax_at"](x)+0.9, 0))
    c.setStrokeColorRGB(0.8, 0.2, 0.2); c.setLineWidth(0.4); c.setDash([6, 2, 1, 2]); c.line(a[0], a[1], b[0], b[1]); c.setDash()
    c.circle(b[0], b[1]+3*MM, 3*MM); nice(c, b[0], b[1]+2*MM, str(k+1), 7, True, anchor="c")
for nm, fy, lab in (("A", G["yA_at"], "A"), ("F", G["yF_at"], "F")):
    a = pl.p((-1.2, fy(0)-(fy(X_M)-fy(0))*1.2/X_M, 0)); b = pl.p((X_M+0.9, fy(X_M)+(fy(X_M)-fy(0))*0.9/X_M, 0))
    c.setStrokeColorRGB(0.8, 0.2, 0.2); c.setLineWidth(0.4); c.setDash([6, 2, 1, 2]); c.line(a[0], a[1], b[0], b[1]); c.setDash()
    c.circle(a[0]-3*MM, a[1], 3*MM); nice(c, a[0]-3*MM, a[1]-1*MM, lab, 7, True, anchor="c")
dimline(c, pl.p((G["XS"], -4.1, 0)), pl.p((G["XE"], -4.1, 0)), "%.2f (plataforma)" % (G["XE"]-G["XS"]), off=(0, -10*MM))
dimline(c, pl.p((0, -0.6, 0)), pl.p((X_M, -0.6, 0)), "%.2f (19 pórticos @ 0.42)" % X_M, off=(0, -3*MM))
dimline(c, pl.p((X_M+0.4, G["yA_at"](X_M), 0)), pl.p((X_M+0.4, G["yF_at"](X_M), 0)), "%.2f boca (eje a eje)" % (G["yF_at"](X_M)-G["yA_at"](X_M)), off=(14*MM, 0))
r = INFO["rampa"]
nice(c, pl.p((G["XE"]+0.2, -2.25, 0))[0], pl.p((G["XE"]+0.2, -2.25, 0))[1], "RAMPA %.0f%% · L=%.2f · Δh=%.2f" % (r["pendiente"]*100, r["largo"], r["desnivel"]), 7)
nice(c, pl.p((2.6, 1.8, 0))[0], pl.p((2.6, 1.8, 0))[1], "TUMBONA", 7, True)
nice(c, pl.p((5.0, 0.85, 0))[0], pl.p((5.0, 0.85, 0))[1]-8, "BANCA", 7, True)
nice(c, pl.p((9.5, -2.0, 0))[0], pl.p((9.5, -2.0, 0))[1], "PLAZA / EXTENSIÓN EXTERIOR — NPT +0.90", 8, True)
nice(c, pl.p((14.5, 3.5, 0))[0], pl.p((14.5, 3.5, 0))[1], "→ MAR (+X)", 10, True, col=Color(0.2, 0.4, 0.7))
nice(c, 20*MM, H-20*MM, "Planta general (se omite la cubierta permeable de latillas para leer pórticos y mobiliario)", 9, True)
c.showPage()

# ===== L-03 elevaciones lateral y posterior =====
sheet_frame(c, "L-03", "Elevación lateral (desde el lado cercano, -Y) y elevación posterior (desde -X)", "1:50 (A3)")
s = (1000/50.0)*MM
el = Ortho(((0, 1), (2, 1)), (1, -1), (30*MM, 175*MM), s)
lat = [p for p in P if p[1] in ALLSTRUCT + [G["G10"]]]
prof = [(x/10.0, -0.3, terrain(x/10.0, -0.3)) for x in range(-20, 190)]
terrain_profile(c, el, prof, fill=True, base=el.p((0, 0, -1.2))[1])
draw_prims(c, el, lat, outline=0.15)
pm = G["frame_pts3"](18)
dimline(c, el.p((X_M+0.6, 0, FFL)), el.p((X_M+0.6, 0, max(q[2] for q in pm)+R20)), "%.2f s/NPT" % (max(q[2] for q in pm)+R20-FFL), off=(10*MM, 0))
dimline(c, el.p((-0.6, 0, 0)), el.p((-0.6, 0, FFL)), "NPT +0.90", off=(-8*MM, 0))
nice(c, 30*MM, H-20*MM, "Elevación lateral (corte de terreno en y = -0.30)", 9, True)
s2 = (1000/50.0)*MM
ep = Ortho(((1, -1), (2, 1)), (0, 1), (150*MM, 45*MM), s2)
back = [p for p in P if p[1] in ALLSTRUCT]
draw_prims(c, ep, back, outline=0.15)
prof2 = [(-0.5, y/10.0, terrain(-0.5, y/10.0)) for y in range(-40, 52)]
terrain_profile(c, ep, prof2)
nice(c, 40*MM, 130*MM, "Elevación posterior (desde -X)", 9, True)
c.showPage()

# ===== L-04 sección por la boca: ángulos y cota 2.10 =====
sheet_frame(c, "L-04", "Elevación frontal / sección por la boca (pórtico 19): ángulos de referencia y cota de 2.10 m", "1:25 (A3)",
            note=["Ángulos interiores del hexágono de la boca: B=165°, C=120°, D=105°, E=155° (referencia 4).",
                  "Pies A y F = 87.5° c/u: cierre geométrico (105+120+155+165 = 545°; 720-545 = 175°).",
                  "Cota verde: NPT (+0.90) a cara inferior de la viga C-D, a 0.45 m del pie cercano = 2.10 m."])
s = (1000/25.0)*MM
fs = Ortho(((1, -1), (2, 1)), (0, 1), (W/2 + 110*MM, 40*MM), s)
mouth = [p for p in P if (p[1] == G04 and p[2] == "Portico_19_BOCA") or (p[1] == G03 and p[-1].startswith("P19_"))
         or (p[1] == G["G12"] and p[2] in ("Cota_Linea_Verde_2.10m", "Angulos_Referencia"))]
deck = [p for p in P if p[1] == G["G07"] and p[2] in ("Vigas_Principales_D20",) and abs(p[4][0]-7.56) < 0.01]
draw_prims(c, fs, mouth, outline=0.2)
ya = G["yA_at"](X_M)
for k, (u, z) in enumerate(G["MOUTH"]):
    q = fs.p((X_M, ya+u, ZF+z)); nice(c, q[0]+6, q[1]+6, "ABCDEF"[k], 11, True, col=Color(0.75, 0.1, 0.3))
labels = {1: "165°", 2: "120°", 3: "105°", 4: "155°", 0: "87.5°", 5: "87.5°"}
for k, t in labels.items():
    u, z = G["MOUTH"][k]; q = fs.p((X_M, ya+u, ZF+z))
    nice(c, q[0]-30, q[1]-18 if k in (0, 5) else q[1]-24, t, 10, True, col=Color(0.75, 0.1, 0.3))
yg = ya + G["GREEN_U"]
a = fs.p((X_M, yg, FFL)); b = fs.p((X_M, yg, FFL+2.10))
nice(c, a[0]-8, (a[1]+b[1])/2, "2.10", 14, True, col=Color(0.05, 0.6, 0.3), anchor="r")
c.setStrokeColorRGB(0.4, 0.4, 0.4); c.setLineWidth(0.6); q0 = fs.p((X_M, ya-0.6, FFL)); q1 = fs.p((X_M, ya+4.9, FFL)); c.line(q0[0], q0[1], q1[0], q1[1])
nice(c, q1[0]-4, q1[1]+3, "NPT +0.90", 8, anchor="r")
mi = INFO["mouth_info"]
y0 = H - 22*MM
nice(c, 20*MM, y0, "Pórtico de la boca — longitudes de eje (m)", 10, True)
for i, (k, v) in enumerate([("A-B", mi["AB"]), ("B-C", mi["BC"]), ("C-D", mi["CD"]), ("D-E", mi["DE"]), ("E-F", mi["EF"]), ("A-F (luz)", mi["AF"])]):
    nice(c, 20*MM, y0 - (i+1)*5*MM, "%-10s %.3f" % (k, v), 9)
nice(c, 20*MM, y0 - 8*5*MM, "Rumbos de eje: " + ", ".join("%.1f°" % h for h in mi["headings"]), 8)
nice(c, 20*MM, y0 - 9*5*MM, "Vista desde el mar (+X): el lado cercano (A) queda a la DERECHA.", 8)
c.showPage()

# ===== L-05 cimentación y detalles =====
sheet_frame(c, "L-05", "Planta de cimentación y detalles preliminares de unión — PENDIENTE DE CÁLCULO", "planta 1:100 · detalles 1:10",
            note=["Hipótesis sin validar: suelo arenoso compacto, capacidad admisible a definir por EMS (E.050).",
                  "Zapata 0.80x0.80x0.30, fondo -0.60 bajo terreno; pedestal 0.35x0.35 hasta +0.20 sobre terreno.",
                  "Ninguna caña en contacto con el suelo. Anclaje en U inox AISI 316 + perno M16,",
                  "entrenudo relleno de mortero. Separación mínima entre apoyos: 0.90 m."])
s = (1000/100.0)*MM
cp = Ortho(((0, 1), (1, 1)), (2, 1), (60*MM, 200*MM), s)
fund = [p for p in P if p[1] in (G02,) or (p[1] == G03 and p[2] in ("Pedestales", "Anclajes_Postes"))]
draw_prims(c, cp, fund, outline=0.1)
for n, q in enumerate(INFO["posts"]):
    pp = cp.p((q["x"], q["y"], 0)); nice(c, pp[0]+5, pp[1]+5, str(n+1), 5)
nice(c, 30*MM, H-20*MM, "Planta de cimentación: %d apoyos (zapatas aisladas + pedestales)" % len(INFO["posts"]), 9, True)
# detalle apoyo tipo (sección esquemática)
ox, oy, sc = 60*MM, 22*MM, (1000/10.0)*MM*0.42   # 1:20 efectivo en A3 para que entre
def rect(x, y, w, h, col, lab=None):
    c.setFillColorRGB(*col); c.setStrokeColor(black); c.setLineWidth(0.6)
    c.rect(ox + x*sc, oy + y*sc, w*sc, h*sc, fill=1, stroke=1)
    if lab: nice(c, ox + (x+w)*sc + 4, oy + (y+h/2)*sc, lab, 7)
rect(-0.40, 0.00, 0.80, 0.30, (0.78, 0.77, 0.74), "Zapata 0.80×0.80×0.30 (f'c a definir)")
rect(-0.175, 0.30, 0.35, 0.50, (0.82, 0.81, 0.78), "Pedestal 0.35×0.35, cara sup. +0.20 s/terreno")
rect(-0.13, 0.80, 0.26, 0.012, (0.55, 0.57, 0.6), "Placa base inox 260×260×12 + 4 anclajes")
rect(-0.115, 0.812, 0.008, 0.22, (0.55, 0.57, 0.6)); rect(0.107, 0.812, 0.008, 0.22, (0.55, 0.57, 0.6))
nice(c, ox + 0.13*sc + 4, oy + 0.95*sc, "Orejas en U, perno pasante M16 a 0.13 (entrenudo con mortero)", 7)
rect(-0.10, 0.842, 0.20, 0.55, (0.72, 0.56, 0.30), "Poste caña Ø20 (separación 3 cm de la placa)")
rect(-0.40, 1.392, 0.80, 0.20, (0.72, 0.56, 0.30), "Viga principal Ø20 (transversal)")
c.setStrokeColorRGB(0.5, 0.4, 0.3); c.setLineWidth(1.0); c.line(ox - 0.7*sc, oy + 0.60*sc, ox + 0.7*sc, oy + 0.60*sc)
nice(c, ox - 0.7*sc, oy + 0.62*sc, "terreno natural", 7)
nice(c, ox - 0.7*sc, oy + 1.70*sc, "DETALLE 1 — APOYO TIPO (esquemático, sin escala exacta)", 8, True)
# detalle nodo de pórtico
nx0, ny0 = W/2 - 20*MM, 40*MM
c.setStrokeColorRGB(0.62, 0.46, 0.22); c.setLineWidth(0.20*sc); c.setLineCap(0)
c.line(nx0 - 0.9*sc*0.6, ny0 - 0.5*sc*0.6, nx0 - 0.12*sc, ny0 - 0.05*sc)
c.line(nx0 + 0.12*sc, ny0 + 0.02*sc, nx0 + 0.9*sc*0.6, ny0 + 0.25*sc*0.6)
c.setFillColorRGB(0.55, 0.57, 0.6); c.circle(nx0, ny0, 0.07*sc, fill=1, stroke=1)
c.setStrokeColor(black); c.setLineWidth(0.6)
for sgn in (-1, 1):
    for d in (0.27, 0.42):
        ang = math.atan2(-0.5, -0.9) if sgn < 0 else math.atan2(0.25, 0.9)
        c.circle(nx0 + d*sc*math.cos(ang), ny0 + d*sc*math.sin(ang), 0.008*sc*2, fill=0, stroke=1)
nice(c, nx0 - 60*MM, ny0 + 62*MM, "DETALLE 2 — NODO DE PÓRTICO (B, C, D, E)", 8, True)
for i, t in enumerate(["• Corte de cada caña a ≥ (r+12 mm)/sen(θ/2) del vértice para no interferir.",
                       "• Pletinas inox 8 mm a ambas caras + pasador central Ø14 (rigidez de nudo).",
                       "• 2 pernos M16 por extremo; 1.º perno a ≥ 150 mm del corte, en entrenudo",
                       "  relleno de mortero (práctica E.100 / ISO 22156, a verificar por cálculo).",
                       "• Sin nudos articulados puros: el pórtico necesita nudo resistente a momento."]):
    nice(c, nx0 - 60*MM, ny0 + 56*MM - i*4.2*MM, t, 7)
c.showPage()
c.save()

# ===== tabla de componentes =====
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment
DESC = {"cana20": "Caña guadua Ø20 cm nominal (principal)", "cana12": "Caña guadua Ø12 cm (viguetas/largueros)",
        "cana10": "Caña guadua Ø10 cm (correas/riostras/patas)", "cana06": "Caña guadua Ø6 cm (entablado/latillas/listones)",
        "acero": "Pletina/placa/pasador acero inox AISI 316", "perno": "Perno/varilla roscada inox M16", "tensor": "Tensor inox Ø16 con tensor de rosca",
        "concreto": "Concreto (zapata/pedestal/losa)", "figura": "Figura humana (escala)", "figura_esf": "Figura humana (escala)",
        "arbusto": "Vegetación costera", "arbusto2": "Vegetación costera", "verde": "Cota de referencia 2.10 m", "marcador": "Marcador de cotas/ángulos", "eje": "Eje estructural"}
rows = collections.OrderedDict()
for pr in P:
    key = (pr[1], pr[2], pr[3])
    r = rows.setdefault(key, {"n": 0, "L": 0.0, "V": 0.0})
    r["n"] += 1
    if pr[0] == "cyl":
        L = math.dist(pr[4], pr[5]); r["L"] += L
    elif pr[0] == "box":
        ex, ey, ez = pr[5], pr[6], pr[7]
        vol = abs(ex[0]*(ey[1]*ez[2]-ey[2]*ez[1]) - ex[1]*(ey[0]*ez[2]-ey[2]*ez[0]) + ex[2]*(ey[0]*ez[1]-ey[1]*ez[0]))
        r["V"] += vol
wb = Workbook(); ws = wb.active; ws.title = "Componentes"
hdr = ["Grupo SketchUp", "Subgrupo", "Componente / material", "Cantidad", "Longitud total (m)", "Volumen (m³)", "Observación"]
ws.append(hdr)
for c_ in ws[1]: c_.font = Font(bold=True, color="FFFFFF"); c_.fill = PatternFill("solid", fgColor="6B4F2A"); c_.alignment = Alignment(wrap_text=True)
for (g, s_, d), r in rows.items():
    obs = ""
    if d == "concreto": obs = "Dimensiones preliminares: requiere EMS y cálculo"
    if d in ("acero", "perno", "tensor"): obs = "Conexión preliminar: pendiente de cálculo"
    if d == "cana20": obs = "Verificar disponibilidad de Ø20 real, espesor de pared y especie"
    ws.append([g, s_, DESC.get(d, d), r["n"], round(r["L"], 2) if r["L"] else None, round(r["V"], 3) if r["V"] else None, obs])
for col, wdt in zip("ABCDEFG", (34, 30, 42, 10, 16, 13, 52)): ws.column_dimensions[col].width = wdt
ws2 = wb.create_sheet("Resumen_caña")
ws2.append(["Diámetro", "Longitud total (m)", "N.º piezas", "Largo comercial supuesto (m)", "Cañas enteras aprox. (+10% desperdicio)"])
for c_ in ws2[1]: c_.font = Font(bold=True)
tot = collections.defaultdict(lambda: [0.0, 0])
for pr in P:
    if pr[0] == "cyl" and pr[3].startswith("cana") and pr[1] != G["G13"]:
        tot[pr[3]][0] += math.dist(pr[4], pr[5]); tot[pr[3]][1] += 1
for d in ("cana20", "cana12", "cana10", "cana06"):
    L, n = tot[d]; ws2.append([DESC[d], round(L, 1), n, 6.0, math.ceil(L*1.10/6.0)])
ws2.column_dimensions["A"].width = 46; ws2.column_dimensions["E"].width = 38
ws3 = wb.create_sheet("Control_geometrico")
mi = INFO["mouth_info"]
ws3.append(["Dato", "Valor", "Origen", "Estado"])
for c_ in ws3[1]: c_.font = Font(bold=True)
ctrl = [
 ("Altura libre en línea verde (NPT→cara inferior viga C-D)", "2.100 m", "Referencia 5 (dato del cliente)", "Cumple (cota en modelo)"),
 ("Ángulo B / C / D / E (boca)", "165° / 120° / 105° / 155°", "Referencia 4 (interpretación: ángulos interiores)", "Cumple exacto"),
 ("Ángulo de pies A y F", "87.5°", "Cierre geométrico (720°−545°)/2", "Desvío de 2.5° vs. 90° indicado"),
 ("90° en plataforma", "Postes verticales ⟂ plataforma horizontal", "Referencia 4 (interpretación)", "Cumple"),
 ("Diámetro principal (pórticos, postes, vigas principales, soleras)", "Ø20 cm nominal", "Requisito del cliente", "Modelado; espesor de pared NO definido"),
 ("Ancho de boca eje a eje", "%.3f m" % mi["AF"], "Derivado (ángulos + cota 2.10)", "Por verificar con fotografía/medición"),
 ("Altura máx. boca s/NPT", "%.2f m" % (max(q[2] for q in pm)+R20-FFL), "Derivado", "Por verificar"),
 ("Largo de túnel (19 pórticos @ 0.42)", "%.2f m" % X_M, "Primer modelo (base geométrica)", "Estimado de fotografía"),
 ("Largo de plataforma", "%.2f m" % (G["XE"]-G["XS"]), "Primer modelo", "Estimado de fotografía"),
 ("NPT sobre terreno", "%.2f – %.2f m" % (min(FFL-q["terreno"] for q in INFO["posts"]), max(FFL-q["terreno"] for q in INFO["posts"])), "Topografía aproximada", "Requiere levantamiento"),
 ("Rampa", "%.0f%% · %.2f m · Δh %.2f m" % (INFO["rampa"]["pendiente"]*100, INFO["rampa"]["largo"], INFO["rampa"]["desnivel"]), "A.120 (tabla de pendientes, a verificar)", "Cumple con topografía supuesta"),
]
for r in ctrl: ws3.append(list(r))
for col, wdt in zip("ABCD", (58, 34, 44, 40)): ws3.column_dimensions[col].width = wdt
xlsx_path = os.path.join(OUT, "REFUGIO_CAÑA_V01_TABLA_COMPONENTES.xlsx")
wb.save(xlsx_path)
json.dump({"mouth": INFO["mouth"], "mouth_info": INFO["mouth_info"], "rampa": INFO["rampa"],
           "n_postes": len(INFO["posts"]), "n_primitivas": len(P), "cana_total_m": {k: round(v[0], 1) for k, v in tot.items()}},
          open(os.path.join(OUT, "control_geometrico.json"), "w", encoding="utf-8"), indent=1, ensure_ascii=False)
print(pdf_path); print(xlsx_path)
print({k: (round(v[0], 1), v[1]) for k, v in tot.items()})
