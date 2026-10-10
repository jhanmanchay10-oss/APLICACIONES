# Prompt: Pabellón de caña guadua (modelo SketchUp en metros)

Copia y pega este prompt junto con la imagen de referencia.

---

Actúa como arquitecto especialista en construcción con bambú y modela en SketchUp (conéctate al conector de SketchUp y construye por etapas, en vivo) el pabellón mirador de la imagen adjunta. Reprodúcelo **igual a la foto**: misma forma, proporciones, ritmo de costillas, deck, rampa y mobiliario. **Lo único que cambia es el material: todo es caña guadua** (cañas rollizas, no tablones).

## Unidades y escala
- Unidades del archivo: **metros**, formato decimal, precisión 0.00 m; área m², volumen m³.
- Escala: **la línea verde de la foto mide 2.10 m**. Es la altura libre, desde el piso del deck hasta la cara inferior de la viga de la boca, del lado cercano (junto al pie derecho de la boca). Ajusta todas las demás medidas en proporción a esa cota.
- Deja un cilindro verde de 2.10 m en esa posición, en el tag `Z-Referencia_2.10m`, para poder comprobar la medida.

## Geometría a reproducir
1. **Cascarón de costillas** (unas 20 costillas, separadas entre 0.40 y 0.48 m, unos 8.3 m de túnel).
   - Cada costilla es un polígono abierto de 8 vértices: pie cercano, rodilla, hombro, cumbrera cercana, cumbrera lejana, hombro lejano, rodilla lejana y pie lejano.
   - Atrás las costillas son casi rectangulares y verticales (unos 2.9 m de ancho por 3.45 m de alto). Hacia la boca crecen, se inclinan (el lado cercano baja y el lejano sube a unos 3.95 m) y giran en planta para abrirse hacia el mar.
   - En la cubierta deben verse los escalones dentados de la foto.
   - Cada costilla es un haz de 3 cañas: 2 de Ø10 cm lado a lado más 1 de Ø8 cm por el exterior, con traslapes de unos 7 cm en los nudos.
2. **Correas longitudinales**: cañas de Ø6 cm que unen los vértices de costillas consecutivas, por el interior.
3. **Tumbona / respaldo inclinado** en el lado lejano: el tramo inclinado entre la rodilla y el pie lejano, relleno con cañas de Ø6 cm cada unos 10 cm, entre las costillas 2 y 13.
4. **Cerramiento posterior**: montantes verticales hasta el terreno y travesaño horizontal a unos 1.10 m, como en la foto.
5. **Banca baja** interior de caña frente a la tumbona (asiento a 0.45 m).
6. **Deck elevado** a +0.70 m sobre el terreno.
   - Tablillas transversales de caña de Ø6 cm cada 8.5 cm.
   - Bajo el túnel, el deck es una franja estrecha. Hacia el frente se abre en una plaza de unos 4 m hacia el lado del observador, con borde dentado y la esquina delantera recortada en diagonal.
7. **Subestructura**: vigas longitudinales de Ø10 cm y transversales de Ø12 cm. Postes de Ø12 cm con zapata de acero galvanizado y dado de concreto de 30×30 cm (las bases grises de la foto).
8. **Rampa de acceso** en la esquina delantera derecha: unos 2 m de largo, de +0.70 m hasta el terreno, con 3 largueros.
9. **Terreno** plano de arena para la presentación.

## Organización profesional
- Todo dentro del grupo `Pabellon_Cana_Guadua`, con subgrupos numerados (01_Costillas … 09_Rampa).
- Componentes reutilizables: `Cana_Estructural`, `Cana_Secundaria`, `Cana_Piso`, `Zapata_Acero`, `Dado_Concreto`.
- Tags: `A-Estructura_Costillas_Cana_D10`, `A-Correas_Cana_D6`, `A-Mobiliario_Tumbona`, `A-Deck_Piso_Cana`, `A-Rampa`, `S-Subestructura_Vigas_Postes`, `S-Cimentacion`, `Z-Referencia_2.10m`, `Z-Terreno`.
- Materiales con nombre y diámetro: `Cana_Guadua_Estructural_D10`, `Cana_Guadua_Secundaria_D6`, `Cana_Guadua_Piso_D6`, `Acero_Galvanizado`, `Concreto_Dado`.
- Escenas:
  1. Perspectiva igual a la foto (fondo a la izquierda, boca y mar a la derecha, cámara a la altura de los ojos)
  2. Boca hacia el mar
  3. Interior desde la tumbona
  4. Alzado lateral (ortogonal)
  5. Planta (ortogonal)
  6. Axonometría
  7. Estructura sin deck
- Estilo de presentación exterior con cielo, horizonte, sombras y oclusión ambiental.

## Verificación antes de entregar
- La altura libre en la cota verde es 2.10 m (±5 cm).
- La vista 01 coincide con la foto: el fondo del túnel a la izquierda, la boca a la derecha, la plaza del deck y la rampa en primer plano a la derecha.
- Entrega el enlace de descarga del .skp.
