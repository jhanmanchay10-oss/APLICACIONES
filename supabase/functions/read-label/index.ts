// Edge Function: lee con GPT la etiqueta nutricional de un producto envasado.
// Se usa cuando el código de barras no está en Open Food Facts (frecuente en productos peruanos).
import {
  authorize,
  callOpenAIJson,
  CATEGORIES,
  clamp,
  corsHeaders,
  imageDataUrl,
  json,
  NUTRIENT_KEYS,
  openAIErrorResponse,
  PER_100G_SCHEMA,
  readBody,
} from "../_shared/common.ts";

const MAX_PER_HOUR = 20;
const OCTAGONS = ["high_sugar", "high_sodium", "high_saturated_fat", "contains_trans_fat"] as const;

const LABEL_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: [
    "is_readable", "name", "brand", "serving_size", "serving_grams", "category", "nova_group",
    "per_100g", "warning_octagons", "ingredients", "notes",
  ],
  properties: {
    is_readable: { type: "boolean" },
    name: { type: "string" },
    brand: { type: "string" },
    serving_size: { type: "string" },
    serving_grams: { type: "number" },
    category: { type: "string", enum: CATEGORIES },
    nova_group: { type: "integer" },
    per_100g: PER_100G_SCHEMA,
    warning_octagons: { type: "array", items: { type: "string", enum: OCTAGONS } },
    ingredients: { type: "string" },
    notes: { type: "string" },
  },
};

type Label = {
  is_readable: boolean;
  name: string;
  brand: string;
  serving_size: string;
  serving_grams: number;
  category: string;
  nova_group: number;
  per_100g: Record<string, number>;
  warning_octagons: string[];
  ingredients: string;
  notes: string;
};

const SYSTEM_PROMPT = `Eres un experto en leer etiquetas de alimentos envasados, incluidas las peruanas
con octógonos de advertencia ("ALTO EN AZÚCAR", "ALTO EN SODIO", "ALTO EN GRASAS SATURADAS",
"CONTIENE GRASAS TRANS").
Lee la tabla de información nutricional de la foto y devuelve los valores POR 100 g (o 100 ml).
- Si la tabla solo muestra valores por porción, conviértelos a 100 g usando el tamaño de porción.
- Si la etiqueta da sal en lugar de sodio: sodio (mg) = sal (g) × 400.
- Usa 0 solo si el valor realmente es 0 o no aparece; NUNCA inventes números.
- name y brand: tal como aparecen en el envase ("" si no se ven).
- serving_size: texto de la porción (ej. "1 vaso (250 ml)"); serving_grams: gramos o ml de la porción (0 si no se ve).
- category y nova_group: tu mejor estimación según el tipo de producto e ingredientes
  (1 sin procesar … 4 ultraprocesado).
- warning_octagons: solo los octógonos que realmente se ven.
- ingredients: lista de ingredientes si se ve ("" si no).
- Si no se puede leer la tabla, is_readable=false y en notes explica qué foto tomar
  (más cerca, con más luz, enfocando la tabla).`;

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const caller = await authorize(request, "label", MAX_PER_HOUR);
  if (caller instanceof Response) return caller;

  const body = await readBody(request);
  if (!body) return json({ error: "invalid_json" }, 400);
  const image = imageDataUrl(body);
  if ("error" in image) return json({ error: image.error }, image.status);

  try {
    const label = await callOpenAIJson<Label>(
      SYSTEM_PROMPT,
      [
        { type: "input_text", text: "Lee la información nutricional de este producto." },
        { type: "input_image", image_url: image.url, detail: "high" },
      ],
      "nutrition_label",
      LABEL_SCHEMA,
    );
    if (!label) return json({ error: "analysis_failed" }, 422);

    return json({
      is_readable: label.is_readable,
      name: label.name.slice(0, 80),
      brand: label.brand.slice(0, 60),
      serving_size: label.serving_size.slice(0, 60),
      serving_grams: clamp(label.serving_grams, 0, 3000),
      category: label.category,
      nova_group: Math.round(clamp(label.nova_group, 1, 4)),
      per_100g: Object.fromEntries(
        NUTRIENT_KEYS.map((key) => [key, clamp(Number(label.per_100g?.[key] ?? 0), 0, key === "sodium_mg" ? 40000 : 1000)]),
      ),
      warning_octagons: label.warning_octagons.filter((octagon) => (OCTAGONS as readonly string[]).includes(octagon)),
      ingredients: label.ingredients.slice(0, 1500),
      notes: label.notes.slice(0, 300),
    });
  } catch (error) {
    return openAIErrorResponse(error);
  }
});
