// Supabase Edge Function: identifica TODOS los alimentos de la foto de un plato con GPT (visión).
// Despliegue automático: .github/workflows/deploy-backend.yml (o `supabase functions deploy`).
import {
  authorize,
  callOpenAIJson,
  clamp,
  corsHeaders,
  FOOD_SCHEMA,
  type Food,
  imageDataUrl,
  json,
  NUTRITION_RULES,
  openAIErrorResponse,
  readBody,
  sanitizeFoods,
} from "../_shared/common.ts";

const MAX_PER_HOUR = 30;

const ANALYSIS_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["is_food", "overall_confidence", "dish_name", "notes", "foods"],
  properties: {
    is_food: { type: "boolean" },
    overall_confidence: { type: "number" },
    dish_name: { type: "string" },
    notes: { type: "string" },
    foods: { type: "array", items: FOOD_SCHEMA },
  },
};

type Analysis = { is_food: boolean; overall_confidence: number; dish_name: string; notes: string; foods: Food[] };

const SYSTEM_PROMPT = `Eres un nutricionista experto en reconocer alimentos en fotografías, con muy buen
conocimiento de la comida peruana y latinoamericana (lomo saltado, ceviche, ají de gallina, causa,
arroz chaufa, tallarines verdes, seco, menestras, anticuchos, papa a la huancaína, chicharrón,
tamales, panes, frutas andinas y amazónicas) y de la comida internacional.

Tu tarea: identificar TODOS los alimentos visibles en la foto.
- Separa SIEMPRE cada componente del plato en un alimento propio. Ejemplo: "lomo saltado" →
  carne de res salteada, cebolla, tomate, papas fritas, arroz blanco.
- Incluye bebidas, salsas, cremas, panes, postres, frutas y guarniciones.
- Los alimentos simples también cuentan: un huevo cocido, una fruta, un pan o un vaso de agua.
- Cuenta las unidades y estima su peso (ej. 2 huevos cocidos ≈ 100 g; 1 pan francés ≈ 30 g).
- Estima la porción en gramos con referencias visuales (plato, cubiertos, manos).
- Nunca omitas un alimento por no estar seguro: da tu mejor opción con confidence baja (0-1).
- dish_name: nombre del plato si es reconocible (ej. "Lomo saltado"), o "" si no aplica.
- Si la imagen no contiene comida, devuelve is_food=false y foods vacío.
- overall_confidence (0-1) refleja la calidad de la foto y la certeza global.
- notes: una frase breve y amable sobre supuestos importantes (aceite, sal o azúcar que no se ven).
  No hables de dietas ni de bajar de peso.
${NUTRITION_RULES}`;

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const caller = await authorize(request, "photo", MAX_PER_HOUR);
  if (caller instanceof Response) return caller;

  const body = await readBody(request);
  if (!body) return json({ error: "invalid_json" }, 400);
  const image = imageDataUrl(body);
  if ("error" in image) return json({ error: image.error }, image.status);

  try {
    const result = await callOpenAIJson<Analysis>(
      SYSTEM_PROMPT,
      [
        { type: "input_text", text: "Identifica todos los alimentos de esta foto." },
        { type: "input_image", image_url: image.url, detail: "high" },
      ],
      "meal_analysis",
      ANALYSIS_SCHEMA,
    );
    if (!result) return json({ error: "analysis_failed" }, 422);

    return json({
      overall_confidence: result.is_food ? clamp(result.overall_confidence, 0, 1) : 0,
      dish_name: result.is_food ? result.dish_name.slice(0, 80) : "",
      notes: result.notes,
      foods: result.is_food ? sanitizeFoods(result.foods) : [],
    });
  } catch (error) {
    return openAIErrorResponse(error);
  }
});
