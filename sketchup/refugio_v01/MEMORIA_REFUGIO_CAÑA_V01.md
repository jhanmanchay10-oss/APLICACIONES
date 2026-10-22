# Refugio costero de caña — Propuesta constructiva V01

**Memoria breve, hipótesis y pendientes de validación.**

> **Nivel de resultado:** 1 (modelo arquitectónico 3D) + 2 (propuesta constructiva preliminar).
> **No es** un proyecto estructural verificado (nivel 3). No está apto para construir sin el estudio de mecánica de suelos (EMS), los ensayos o la ficha técnica de la caña, el cálculo estructural y la revisión de un ingeniero colegiado.

## 1. Archivos

| Archivo | Contenido |
|---|---|
| `REFUGIO_COSTERO_CAÑA_PROPUESTA_CONSTRUCTIVA_V01.skp` | Modelo de SketchUp en metros, con 14 grupos, 17 tags y 13 escenas. Se descarga desde el enlace que entrega el conector de SketchUp (ver el mensaje de entrega). |
| `original/pabellon_cana_1_ORIGINAL.skp` | Copia intacta del primer modelo (referencia 2). No se sobrescribió. |
| `geometria_refugio.py` | Geometría paramétrica: es el mismo código que se ejecutó en SketchUp. |
| `generar_planos.py` | Genera las láminas, la tabla y el control a partir de esa misma geometría. |
| `entregables/REFUGIO_CAÑA_V01_LAMINAS.pdf` | Láminas L-01 a L-05: perspectiva, planta, elevaciones, sección por la boca con ángulos y cota, cimentación y detalles. |
| `entregables/REFUGIO_CAÑA_V01_TABLA_COMPONENTES.xlsx` | Tabla de componentes, resumen de caña por diámetro y tabla de control geométrico. |
| `entregables/control_geometrico.json` | Valores de control en formato legible por máquina. |

## 2. Auditoría de archivos (fase 1)

- **Referencia 2 (primer modelo):** `pabellon_caña_1.skp`, formato SketchUp 2026 (v26.1), en pulgadas.
  - Tiene 18 costillas hexagonales separadas 0.42 m, deck a +0.55 m, tumbona, banca y rampa.
  - Usa 3 materiales (`Cana_Guadua`, `Cana_Guadua_Oscura`, `Referencia_Verde`) y un estilo.
  - Se conserva su lógica: pórticos planos repetidos, perpendiculares al eje, que se transforman de atrás hacia la boca; plataforma elevada; tumbona en el lado lejano; rampa en la esquina delantera.
- **Referencia 3 (segundo modelo):** este archivo **no se recibió en esta conversación**.
  - Se usó como referencia el segundo modelo que generé antes (en metros, con zapatas de acero y dados de concreto).
  - De ese modelo solo se tomó la idea de apoyo aislado elevado. Las dimensiones se redefinieron.
- **Referencia 4 (imagen con ángulos):** la imagen **no se recibió**. Los ángulos se aplicaron según la interpretación del punto 3.
- **Unidades del nuevo archivo:** metros decimales, precisión 0.00; áreas en m² y volúmenes en m³.

## 3. Levantamiento geométrico y tabla de control (fase 2)

### Interpretación de los ángulos

Los ángulos se tomaron como **ángulos interiores del hexágono de la boca** (pórtico 19). En la vista desde el mar, el lado cercano queda a la derecha:

- 105° en el primer cambio superior.
- 120° en el siguiente encuentro superior.
- 155° en el encuentro lateral izquierdo.
- 165° en el encuentro lateral derecho.

**Incompatibilidad detectada:** un hexágono suma 720°.

- 105 + 120 + 155 + 165 + 90 + 90 = **725°**, es decir, sobran 5°.
- Si los cuatro ángulos dados se respetan exactos, los dos pies deben medir (720 − 545) / 2 = **87.5°** cada uno.
- **Solución adoptada:** mantener exactos los cuatro ángulos superiores y laterales, que definen la forma visible.
- Los 90° se cumplen como **postes verticales perpendiculares a la plataforma horizontal**, que es la otra lectura posible de "las dos referencias inferiores de la plataforma".
- Los pies de la boca quedan a 87.5°, es decir, 2.5° de inclinación hacia el interior.
- Si en la imagen los 90° corresponden a los pies del pórtico, hay que corregir 5° en alguno de los otros ángulos. Esta es una decisión de diseño que queda pendiente.

### Interpretación de la línea verde

La línea verde es la altura libre **desde el NPT (+0.90) hasta la cara inferior de la viga C-D de la boca**, medida a 0.45 m del pie cercano. Vale **2.10 m exactos**.

- La longitud del tramo B-C se calculó para que esa medida se cumpla.
- No es la altura total: la altura máxima de la boca es ≈3.00 m sobre el NPT.

### Tabla de control

| Dato | Valor | Estado |
|---|---|---|
| Altura libre en la línea verde | 2.100 m | **Dato del cliente.** Cumple: el cilindro verde está en `12_COTAS_Y_DETALLES`. |
| Ángulos B / C / D / E | 165° / 120° / 105° / 155° | **Dato del cliente** (interpretado). Cumple exacto. |
| Pies A / F de la boca | 87.5° | **Derivado** por el cierre geométrico. |
| Ejes de la boca A-B / B-C / C-D / D-E / E-F | 1.500 / 0.641 / 3.400 / 1.400 / 1.606 m | A-B, C-D y D-E estimados de la foto; B-C y E-F calculados. |
| Luz de la boca (eje a eje) | 4.29 m | Derivado; **por verificar** con la foto o con medición. |
| Pórticos | 19 a 0.42 m (túnel de 7.56 m) | Viene del primer modelo; **estimado** de la foto. |
| Plataforma | 13.0 m de largo, NPT +0.90 | Estimado. |
| NPT sobre el terreno | 0.88 a 1.02 m | La topografía es **aproximada**. |
| Rampa | 10%, 2.72 m, desnivel 0.29 m | Responde a la topografía supuesta. |

## 4. Propuesta constructiva (fases 3 y 4)

### Recorrido de cargas

1. Pórtico Ø20.
2. Zapata metálica de pie, con orejas y un perno M16.
3. Solera longitudinal Ø20, que recibe los pies de los pórticos.
4. Viga principal transversal Ø20, cada 3 pórticos (1.26 m).
5. Poste Ø20.
6. Anclaje en U de acero inoxidable AISI 316 sobre placa base.
7. Pedestal de concreto de 0.35 × 0.35 m, con la cara superior a **+0.20 m sobre el terreno**, para que ninguna caña toque el suelo.
8. Zapata aislada de 0.80 × 0.80 × 0.30 m, con el fondo a 0.60 m bajo el terreno.

El piso se apoya así: tablillas Ø6, sobre viguetas Ø12 cada 0.45 m, sobre las vigas principales.

### Correcciones hechas durante la validación

- **Zapatas superpuestas (ejes 1 a 3):** se impuso una separación mínima de 0.90 m entre apoyos.
- **Voladizo de 0.98 m en el eje 3:** se reubicó el poste. El voladizo máximo es ahora 0.65 m.
- **Rampa:** con el primer terreno supuesto el desnivel era de ~1.1 m, lo que exigía una rampa de más de 13 m. Se modeló un montículo de arena en el arranque de la rampa y quedó un desnivel de 0.29 m.
- **Interferencias:**
  - Cañas Ø20 que se cruzaban en los nudos: ahora se cortan a (r + 12 mm)/sen(θ/2) del vértice.
  - Correas que chocaban con los pórticos de la boca: ahora van sobre la bisectriz.
  - La banca, que chocaba con el pie cercano.
  - Las figuras, que atravesaban la tumbona.
  - Los tensores, que rozaban las cañas.
- **Resultado:** 0 choques entre piezas. Los únicos contactos que quedan son de apoyo (poste contra viga, riostra contra viga).

### Nudos de pórtico (B, C, D, E) — preliminares, pendientes de cálculo

- Pletinas inoxidables de 8 mm a ambas caras, más un pasador central.
- Dos pernos M16 por cada extremo de caña. El primer perno está a ≥150 mm del corte, en un entrenudo relleno de mortero.
- **El pórtico necesita nudos resistentes a momento.** Con nudos articulados, el hexágono es un mecanismo inestable. Hay que dimensionar las pletinas, los pernos y el aplastamiento de la pared de la caña.

### Estabilidad

- **Longitudinal:** cruces de tensores inoxidables Ø16 en las bahías 2-3, 9-10 y 16-17, en tres planos (muro cercano, cubierta y muro lejano). Además hay correas Ø10 en los vértices.
- **Transversal:** depende de los nudos rígidos y del empotramiento en la base, que es una hipótesis.
- **Plataforma:** los postes son cortos (0.27 a 0.41 m) y van sobre pedestales. La estabilidad lateral depende del anclaje. Hay tensores en X bajo las soleras donde la altura lo permite.

### Cubierta

Es **permeable**: latillas Ø6 cada 0.16 m sobre el tramo C-D, solo para dar sombra. **No es estanca.** Si hace falta protección contra la lluvia, hay que agregar una membrana o una cubierta impermeable y revisar las cargas.

En la boca, el tramo C-D tiene una pendiente de 12.5° (por la geometría). Hay que verificar que el agua escurra y que las latillas no acumulen humedad.

## 5. Escenas guardadas en el .skp

1. Vista principal de referencia (tres cuartos desde el lado de tierra, como la foto).
2. Vista frontal (boca y altura libre).
3. Vista lateral (ortogonal).
4. Vista interior (tumbona y personas recostadas).
5. Vista posterior.
6. Axonometría estructural.
7. Cimentación y terreno (con el terreno transparente).
8. Despiece constructivo (copia separada del apoyo tipo y del nudo tipo; no altera el modelo).
9. Detalle de uniones.
10. Planta general (ortogonal).
11. Elevación y sección por la boca (ortogonal).
12. Vista ambiental final.
13. Control geométrico (ángulos y cota de 2.10 m).

**Limitación del conector:** el entorno no permite crear entidades de cota ni de texto de SketchUp. Las cotas y los ángulos son marcadores 3D con el valor en el nombre (por ejemplo, `COTA_2.10m_NPT_a_cara_inferior_viga` o `ANG_C_120`). Si quieres cotas nativas, puedes agregarlas con la herramienta Acotación en esas escenas.

## 6. Incertidumbres críticas

1. **Apertura del lado cercano.** En la foto el interior y las personas se ven a través de un lado cercano bastante abierto. Con los pórticos cerrados del primer modelo, ese lado se lee como una columnata.
   - Para abrirlo habría que retirar o inclinar los pies cercanos en las bahías centrales.
   - Eso convierte la cubierta en un voladizo y exige nudos y cimentación distintos.
   - **Se dejó como decisión de diseño pendiente.**
2. **Caña de Ø20 cm.** Hay que confirmar la especie (por ejemplo, *Guadua angustifolia*), su disponibilidad comercial con ese diámetro, el espesor de pared real, la humedad y el tratamiento de preservación. Ø20 está en el extremo superior de lo habitual en guadua. Una alternativa es un haz de 2 cañas de Ø12 a 14 cm equivalente.
3. **Suelo.** No hay EMS. La capacidad portante, el nivel freático, la salinidad y la erosión de la duna están sin definir. Las zapatas son una hipótesis.
4. **Topografía.** Es una aproximación visual, no un levantamiento. La rampa y la altura del NPT dependen de ella.
5. **Ángulos y línea verde.** Se aplicaron según la interpretación del punto 3. Falta la imagen con los ángulos para confirmarla.
6. **Cargas.** No están calculadas: peso propio, ocupación, viento costero y sismo.

## 7. Normativa a considerar (verificar aplicabilidad y versión vigente)

- **Reglamento Nacional de Edificaciones (Perú):**
  - E.100 Bambú: confirmar que cubre la especie elegida.
  - E.020 Cargas (incluido viento).
  - E.030 Diseño Sismorresistente.
  - E.050 Suelos y Cimentaciones.
  - E.060 Concreto Armado.
  - E.090 Estructuras Metálicas.
  - A.010 Condiciones Generales de Diseño (barandas en desniveles).
  - A.120 Accesibilidad (pendiente y barandas de rampas).
- **Referencias internacionales:** ISO 22156 (diseño de estructuras de bambú) e ISO 22157 (ensayos de propiedades).
- **Ambiente marino:** acero inoxidable AISI 316 o galvanizado en caliente con espesor verificado; concreto con recubrimientos y relación agua/cemento para exposición a cloruros; preservación de la caña y protección UV; mantenimiento periódico.

## 8. Cómo regenerar

```bash
python3 generar_planos.py entregables      # láminas PDF + tabla XLSX + control JSON
```

Para reconstruir el .skp: el contenido de `geometria_refugio.py` se ejecuta tal cual en el conector de SketchUp (no tiene imports; `math` ya está cargado), y después se insertan las primitivas con componentes unitarios.
