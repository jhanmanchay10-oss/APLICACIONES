# Refugio costero de caña — Propuesta constructiva V02

**Sección constante: una extrusión recta de la boca al extremo.**

> **Nivel de resultado:** 1 (modelo 3D) + 2 (propuesta constructiva preliminar). No es apto para construir sin el estudio de mecánica de suelos (EMS), el cálculo estructural, los datos reales de la caña y la revisión de un ingeniero colegiado. Las hipótesis y la normativa a verificar son las mismas que en `../refugio_v01/MEMORIA_REFUGIO_CAÑA_V01.md`.

## 1. Qué cambia respecto a V01 (según la imagen con los ángulos en rojo)

| Pedido | Cómo quedó en V02 |
|---|---|
| "Que la mirada sea recta hacia el otro extremo, sin deformarse" | Los **19 pórticos son idénticos**, a 0.42 m (7.56 m en total). En V01 la sección se transformaba de atrás hacia la boca; ahora es una extrusión recta. |
| 90° "sí o sí, hasta el final del proyecto" | Los pies A y F son **verticales a 90.00° exactos** en todos los pórticos. Se verificó por cálculo en los 19. |
| Ángulos en rojo 165 / 120 / 105 / 155 | Se mantiene la misma estructura de la imagen. Ver el ajuste del punto 2. |
| Zona verde: espacio para que la gente descanse | **Tumbona continua** contra el muro de 155°, de 6.5 m de largo: respaldo inclinado, asiento y patas de caña. Hay dos personas recostadas en ella. |
| Cara frontal de la imagen | La escena 02 reproduce esa vista: muro alto con quiebre de 155° a la izquierda, vértice de 105° arriba a la izquierda, cubierta inclinada hacia los quiebres de 120° y 165° a la derecha, tumbona a la izquierda y banca al centro. |

## 2. Ángulos: por qué cambian 1.25°

Un hexágono suma siempre **720°**. Con los valores de la imagen la suma es 90 + 165 + 120 + 105 + 155 + 90 = **725°**: sobran 5° y la figura no puede cerrar.

Como los 90° son obligatorios y los demás se pueden ajustar, los 5° se reparten en partes iguales (1.25° cada uno) entre los cuatro quiebres:

| Vértice | Imagen | Modelo V02 |
|---|---|---|
| A (pie, lado 165) | 90° | **90.00°** |
| B | 165° | 163.75° |
| C | 120° | 118.75° |
| D | 105° | 103.75° |
| E | 155° | 153.75° |
| F (pie, lado 155) | 90° | **90.00°** |

## 3. Medidas de la sección tipo (ejes de caña Ø20)

| Dato | Valor | Origen |
|---|---|---|
| A-B, muro vertical del lado 165 | 2.050 m | **Cota verde:** NPT (+0.90) → quiebre B = **2.10 m** |
| B-C / C-D / D-E | 1.50 / 3.36 / 1.93 m | Proporciones medidas sobre la imagen |
| E-F, muro vertical del lado 155 | 2.486 m | Calculado por el cierre de la figura |
| Luz entre pies (eje a eje) | 4.554 m | Derivado |
| Altura máxima (cara superior de la caña) sobre el NPT | ≈4.37 m | Derivado |

La cota verde se interpretó como la **altura del muro vertical derecho hasta el quiebre de 165°**: en la imagen, la línea verde está junto a ese muro. Si la medida corresponde a otro punto, basta cambiar `GREEN_H` y la sección se recalcula.

## 4. Componentes nuevos o modificados

- **Correas exteriores continuas Ø10:** 9 líneas (en B, C, D, E y en puntos intermedios de los tramos) que sobresalen 0.30 m en ambos extremos, como en la imagen.
- **Revestimiento interior de cañas Ø6 cada 0.10 m:** en los muros (grupo 05) y en la cubierta (grupo 08). Es continuo en todo el largo. Es una cubierta **permeable**, de sombra, **no estanca**.
- **Tensores inoxidables en cruz:** en las bahías 2-3, 9-10 y 16-17, en los muros y en la cubierta, por fuera de las correas.
- **Tumbona:** perfil transversal en (distancia al muro, altura sobre el NPT): respaldo (0.30, 1.05) → (0.62, 0.78) → (1.02, 0.44), asiento (1.40, 0.38) → (1.95, 0.32). Listones Ø6 longitudinales cada 0.07 m, costillas Ø10 cada ~0.84 m y patas Ø9.
- **Plataforma, cimentación, rampa y topografía:** se mantiene la lógica de V01 (65 apoyos con separación ≥0.90 m, sin zapatas superpuestas, pedestales a +0.20 m sobre el terreno, rampa al 10% de 2.72 m), adaptada a la nueva luz entre pies.

## 5. Validación (`validar_geometria_v02.py`)

- Pies a 90.000° y 90.000°; las 19 secciones son idénticas.
- Quiebre B a 2.100 m sobre el NPT.
- 0 choques entre cañas, pletinas, revestimiento, tumbona, personas y cotas. Los únicos contactos son de apoyo (poste contra viga), que es lo esperado.
- 0 zapatas superpuestas.
- **Coincidencia con SketchUp:** 2369 piezas tanto en el modelo como en la validación local.

## 6. Escenas del .skp

1. Vista principal.
2. **Vista frontal recta** (la de la imagen).
3. Vista lateral.
4. Vista interior de la zona de descanso.
5. Vista posterior.
6. Axonometría estructural.
7. Cimentación y terreno.
8. Despiece constructivo.
9. Detalle de uniones.
10. Planta.
11. Elevación y sección por la boca.
12. Vista ambiental.
13. Control geométrico (ángulos y cota de 2.10 m).

## 7. Pendientes

- Confirmar la interpretación de la cota de 2.10 m.
- Aprobar el ajuste de 1.25° en los cuatro quiebres.
- Validar la caña Ø20 (especie, diámetro real y espesor de pared).
- Hacer el EMS y el levantamiento topográfico.
- Calcular los nudos (resistentes a momento) y los tensores.
- Definir si la cubierta será impermeable.
