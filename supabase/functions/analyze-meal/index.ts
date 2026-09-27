// Supabase Edge Function: analiza la foto de un plato con Claude (visión).
// La clave ANTHROPIC_API_KEY vive solo en el servidor:
//   supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
//   supabase functions deploy analyze-meal
import Anthropic from "npm:@anthropic-ai/sdk@0.128.0";
import { zodOutputFormat } from "npm:@anthropic-ai/sdk@0.128.0/helpers/zod";
import { createClient } from "npm:@supabase/supabase-js@2";
import { z } from "npm:zod@4";

const MODEL = "claude-opus-5";
const MAX_IMAGE_BYTES = 5 * 1024 * 1024;
const MAX_ANALYSES_PER_HOUR = 20;
const ALLOWED_MEDIA_TYPES = ["image/jpeg", "image/png", "image/webp"] as const;

const CATEGORIES = [
  "vegetable", "fruit", "legume", "wholeGrain", "refinedGrain", "tuber", "leanProtein",
  "redMeat", "processedMeat", "fish", "egg", "dairy", "nutsSeeds", "fatsOils", "sweets",
  "sugaryDrink", "beverage", "snack", "fastFood", "mixedDish", "other",
] as const;

const Per100g = z.object({
  calories: z.number(),
  protein: z.number(),
  carbohydrates: z.number(),
  fat: z.number(),
  saturated_fat: z.number(),
  fiber: z.number(),
  sugar: z.number(),
  sodium_mg: z.number(),
});

const Analysis = z.object({
  is_food: z.boolean(),
  overall_confidence: z.number(),
  notes: z.string(),
  foods: z.array(
    z.object({
      name: z.string(),
      estimated_grams: z.number(),
      confidence: z.number(),
      category: z.enum(CATEGORIES),
      nova_group: z.number().int(),
      per_100g: Per100g,
    }),
  ),
});

const SYSTEM_PROMPT = `Eres un asistente de nutrición que identifica alimentos en fotos de platos
para una app educativa latinoamericana. Responde siempre en español.

Para cada alimento visible:
- name: nombre común en español, corto y en minúsculas (ej. "arroz blanco", "pollo a la plancha").
  Usa nombres de la cocina peruana/latinoamericana cuando corresponda (ej. "lomo saltado", "ceviche").
- estimated_grams: estima la porción en gramos a partir de referencias visuales (tamaño del plato,
  cubiertos). Es una estimación: no inventes precisión.
- confidence: entre 0 y 1, qué tan seguro estás de que ese alimento está presente.
- category: el grupo de alimento más adecuado.
- nova_group: 1 sin procesar, 2 ingrediente culinario, 3 procesado, 4 ultraprocesado.
- per_100g: valores nutricionales típicos por 100 g (sodio en mg).

Separa los componentes del plato cuando sea posible (arroz, carne, ensalada) en lugar de un solo plato.
Si la imagen no contiene comida, devuelve is_food=false y foods vacío.
overall_confidence refleja la calidad de la foto y la certeza global (0-1).
notes: una frase breve para el usuario sobre supuestos importantes (ej. salsas o aceite no visibles).`;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

const anthropic = new Anthropic({ apiKey: Deno.env.get("ANTHROPIC_API_KEY") });

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  // 1. Autenticación: solo usuarios con sesión pueden usar la IA.
  const token = request.headers.get("Authorization")?.replace("Bearer ", "");
  if (!token) return json({ error: "unauthorized" }, 401);

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  const { data: userData, error: userError } = await admin.auth.getUser(token);
  if (userError || !userData.user) return json({ error: "unauthorized" }, 401);
  const userId = userData.user.id;

  // 2. Límite de uso por usuario.
  const since = new Date(Date.now() - 60 * 60 * 1000).toISOString();
  const { count } = await admin
    .from("ai_usage")
    .select("id", { count: "exact", head: true })
    .eq("user_id", userId)
    .gte("created_at", since);
  if ((count ?? 0) >= MAX_ANALYSES_PER_HOUR) return json({ error: "rate_limited" }, 429);

  // 3. Validación de la entrada.
  let body: { image_base64?: unknown; media_type?: unknown };
  try {
    body = await request.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }
  const image = body.image_base64;
  const mediaType = body.media_type;
  if (typeof image !== "string" || image.length === 0 || !/^[A-Za-z0-9+/=]+$/.test(image)) {
    return json({ error: "invalid_image" }, 400);
  }
  if (image.length * 0.75 > MAX_IMAGE_BYTES) return json({ error: "image_too_large" }, 413);
  if (!ALLOWED_MEDIA_TYPES.includes(mediaType as typeof ALLOWED_MEDIA_TYPES[number])) {
    return json({ error: "invalid_media_type" }, 400);
  }

  await admin.from("ai_usage").insert({ user_id: userId });

  // 4. Análisis con Claude y salida estructurada.
  try {
    const response = await anthropic.messages.parse({
      model: MODEL,
      max_tokens: 16000,
      system: SYSTEM_PROMPT,
      messages: [
        {
          role: "user",
          content: [
            {
              type: "image",
              source: {
                type: "base64",
                media_type: mediaType as typeof ALLOWED_MEDIA_TYPES[number],
                data: image,
              },
            },
            { type: "text", text: "Identifica los alimentos de este plato." },
          ],
        },
      ],
      output_config: { format: zodOutputFormat(Analysis) },
    });

    if (response.stop_reason === "refusal" || !response.parsed_output) {
      return json({ error: "analysis_failed" }, 422);
    }

    const result = response.parsed_output;
    const clamp = (value: number, min: number, max: number) => Math.min(Math.max(value, min), max);
    return json({
      overall_confidence: result.is_food ? clamp(result.overall_confidence, 0, 1) : 0,
      notes: result.notes,
      foods: result.is_food
        ? result.foods.slice(0, 12).map((food) => ({
          ...food,
          estimated_grams: clamp(food.estimated_grams, 1, 3000),
          confidence: clamp(food.confidence, 0, 1),
          nova_group: clamp(food.nova_group, 1, 4),
        }))
        : [],
    });
  } catch (error) {
    if (error instanceof Anthropic.RateLimitError) return json({ error: "rate_limited" }, 429);
    if (error instanceof Anthropic.APIError) {
      console.error("Anthropic API error", error.status, error.message);
      return json({ error: "analysis_unavailable" }, 502);
    }
    console.error("Unexpected error", error);
    return json({ error: "analysis_failed" }, 500);
  }
});
