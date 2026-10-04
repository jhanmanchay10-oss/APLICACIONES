// Edge Function: estima los nutrientes de un alimento escrito por el usuario
// (ej. "2 huevos cocidos", "1 vaso de chicha morada") cuando no está en la base local.
import {
  authorize,
  callOpenAIJson,
  corsHeaders,
  FOOD_SCHEMA,
  type Food,
  json,
  NUTRITION_RULES,
  openAIErrorResponse,
  readBody,
  sanitizeFoods,
} from "../_shared/common.ts";

const MAX_PER_HOUR = 60;

const SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["foods"],
  properties: { foods: { type: "array", items: FOOD_SCHEMA } },
};

const SYSTEM_PROMPT = `Eres un nutricionista experto en comida peruana, latinoamericana e internacional.
El usuario escribe lo que comió. Devuelve un alimento por cada componente mencionado.
- Corrige errores de escritura y usa el nombre correcto en español.
- Si indica cantidad (gramos, unidades, tazas, vasos), conviértela a gramos en estimated_grams.
  Si no, usa una porción habitual.
- Si menciona un plato compuesto (ej. "lomo saltado"), puedes devolverlo como un solo plato.
- confidence (0-1): qué tan claro es el alimento escrito.
- Si el texto no es un alimento, devuelve foods vacío.
${NUTRITION_RULES}`;

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const caller = await authorize(request, "estimate", MAX_PER_HOUR);
  if (caller instanceof Response) return caller;

  const body = await readBody(request);
  const query = typeof body?.query === "string" ? body.query.replace(/[\x00-\x1F\x7F]/g, "").trim() : "";
  if (query.length < 2 || query.length > 200) return json({ error: "invalid_query" }, 400);

  try {
    const result = await callOpenAIJson<{ foods: Food[] }>(
      SYSTEM_PROMPT,
      [{ type: "input_text", text: `Alimento: ${query}` }],
      "food_estimate",
      SCHEMA,
    );
    if (!result) return json({ error: "analysis_failed" }, 422);
    return json({ overall_confidence: 1, notes: "", foods: sanitizeFoods(result.foods) });
  } catch (error) {
    return openAIErrorResponse(error);
  }
});
