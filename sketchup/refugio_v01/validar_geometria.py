# Validación de la geometría: ángulos, cota 2.10, interferencias y zapatas.
# Uso: python3 validar_geometria.py geometria_refugio.py salida.json
import math, sys, json, collections
ns = {"math": math}
exec(open(sys.argv[1], encoding="utf-8").read(), ns)
P, info = ns["build"]()
print("primitivas", len(P), collections.Counter(p[1] for p in P))
mi = info["mouth_info"]; print("boca", [(round(a,3),round(b,3)) for a,b in info["mouth"]], {k:(round(v,3) if isinstance(v,float) else v) for k,v in mi.items()})
print("angulos interiores boca", [round(a,2) for a in ns["interior_angles"](info["mouth"])], "pie", ns["ANG_FOOT"])
for i in (0, 9, 18):
    print("portico", i+1, [round(a,1) for a in ns["interior_angles"](ns["frame_profile"](i))])
# cota verde
X=ns["X_MOUTH"]; pm=ns["frame_pts3"](18); yg=ns["yA_at"](X)+ns["GREEN_U"]
C,D=pm[2],pm[3]; zc=C[2]+(yg-C[1])*(D[2]-C[2])/(D[1]-C[1]); th=math.atan2(D[2]-C[2],D[1]-C[1])
print("altura libre en linea verde (NPT->cara inferior):", round(zc-ns["R20"]/math.cos(th)-ns["FFL"],4))
L=[p["largo"] for p in info["posts"]]; print("postes", len(L), "largo min/max", round(min(L),2), round(max(L),2))
print("altura NPT sobre terreno min/max", round(min(ns["FFL"]-p["terreno"] for p in info["posts"]),2), round(max(ns["FFL"]-p["terreno"] for p in info["posts"]),2))
print("rampa", info["rampa"])
# interferencias
cyls=[p for p in P if p[0]=="cyl"]
def segdist(p1,q1,p2,q2):
    import itertools
    d1=[q1[i]-p1[i] for i in range(3)]; d2=[q2[i]-p2[i] for i in range(3)]; r=[p1[i]-p2[i] for i in range(3)]
    a=sum(x*x for x in d1); e=sum(x*x for x in d2); f=sum(d2[i]*r[i] for i in range(3))
    c=sum(d1[i]*r[i] for i in range(3)); b=sum(d1[i]*d2[i] for i in range(3)); den=a*e-b*b
    s=0.0 if den<1e-12 else max(0,min(1,(b*f-c*e)/den))
    t=(b*s+f)/e if e>1e-12 else 0
    if t<0: t=0; s=max(0,min(1,-c/a))
    elif t>1: t=1; s=max(0,min(1,(b-c)/a))
    pa=[p1[i]+d1[i]*s for i in range(3)]; pb=[p2[i]+d2[i]*t for i in range(3)]
    return math.dist(pa,pb)
def bb(p):
    a,b,r=p[4],p[5],p[6]; return [min(a[i],b[i])-r for i in range(3)],[max(a[i],b[i])+r for i in range(3)]
groups=collections.defaultdict(list)
for p in cyls: groups[(p[1],p[2])].append(p)
pairs=[(("10_FIGURAS_HUMANAS",None),None),]
def check(selA, selB, tol=0.01, label=""):
    A=[p for p in cyls if selA(p)]; B=[p for p in cyls if selB(p)]
    hits=[]
    for p in A:
        ba=bb(p)
        for q in B:
            if p is q: continue
            bq=bb(q)
            if any(ba[1][i]<bq[0][i] or bq[1][i]<ba[0][i] for i in range(3)): continue
            d=segdist(p[4],p[5],q[4],q[5])
            if d < p[6]+q[6]-tol: hits.append((round(p[6]+q[6]-d,3),p[7],q[7]))
    hits.sort(reverse=True)
    print(label, "choques:", len(hits), hits[:6])
fig=lambda p:p[1]=="10_FIGURAS_HUMANAS"
struct=lambda p:p[1] in ("04_ESTRUCTURA_PRINCIPAL_CAÑA_20CM","05_ESTRUCTURA_SECUNDARIA","06_ARRIOSTRAMIENTOS","08_CUBIERTA","12_COTAS_Y_DETALLES") 
check(fig, lambda p: struct(p) or p[1]=="09_ASIENTOS_Y_MOBILIARIO" or (p[1]=="07_PLATAFORMA_Y_ENTABLADO" and p[2]=="Entablado_D6"), label="figuras vs estructura/mobiliario/entablado")
check(lambda p:p[1]=="05_ESTRUCTURA_SECUNDARIA", lambda p:p[1] in ("04_ESTRUCTURA_PRINCIPAL_CAÑA_20CM","08_CUBIERTA","06_ARRIOSTRAMIENTOS"), label="correas vs porticos/cubierta/tensores")
check(lambda p:p[1]=="08_CUBIERTA", lambda p:p[1]=="04_ESTRUCTURA_PRINCIPAL_CAÑA_20CM", label="latillas vs porticos")
check(lambda p:p[1]=="06_ARRIOSTRAMIENTOS", lambda p:p[1] in ("04_ESTRUCTURA_PRINCIPAL_CAÑA_20CM","07_PLATAFORMA_Y_ENTABLADO"), label="arriostres vs principal/plataforma")
check(lambda p:p[1]=="09_ASIENTOS_Y_MOBILIARIO", lambda p:p[1] in ("04_ESTRUCTURA_PRINCIPAL_CAÑA_20CM","05_ESTRUCTURA_SECUNDARIA"), label="mobiliario vs estructura")
check(lambda p:p[1]=="04_ESTRUCTURA_PRINCIPAL_CAÑA_20CM" and p[2].startswith("Portico"), lambda p:p[1]=="04_ESTRUCTURA_PRINCIPAL_CAÑA_20CM" and p[2].startswith("Portico"), tol=0.01, label="porticos entre si")
check(lambda p:p[1]=="07_PLATAFORMA_Y_ENTABLADO", lambda p:p[1]=="04_ESTRUCTURA_PRINCIPAL_CAÑA_20CM", tol=0.015, label="plataforma vs principal (tolerancia apoyo)")
check(lambda p:p[1]=="07_PLATAFORMA_Y_ENTABLADO", lambda p:p[1]=="07_PLATAFORMA_Y_ENTABLADO", tol=0.015, label="plataforma interna")
json.dump({"mouth":info["mouth"],"mouth_info":info["mouth_info"],"rampa":info["rampa"],"posts":info["posts"]}, open(sys.argv[2],"w"), indent=1, ensure_ascii=False)
# zapatas superpuestas
zs=[p for p in P if p[0]=="box" and p[1]=="02_CIMENTACIONES"]
ov=[]
for i,a in enumerate(zs):
    for b in zs[i+1:]:
        ax0,ay0=a[4][0],a[4][1]; ax1,ay1=ax0+a[5][0],ay0+a[6][1]
        bx0,by0=b[4][0],b[4][1]; bx1,by1=bx0+b[5][0],by0+b[6][1]
        if ax0<bx1-1e-6 and bx0<ax1-1e-6 and ay0<by1-1e-6 and by0<ay1-1e-6: ov.append((a[8],b[8]))
print("zapatas superpuestas:", len(ov), ov[:5])
L=[p["largo"] for p in info["posts"]]; print("postes", len(L))
