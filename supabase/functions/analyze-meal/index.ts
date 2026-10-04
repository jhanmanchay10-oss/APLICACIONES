// Supabase Edge Function: analiza la foto de un plato con GPT (visión de OpenAI).
// La clave OPENAI_API_KEY vive solo en el servidor:
//   supabase secrets set OPENAI_API_KEY=sk-...
//   supabase functions deploy analyze-meal
// Opcional: cambiar de modelo sin tocar código con OPENAI_MODEL.
import { createClient } from "npm:@supabase/supabase-js@2";

const DEFAULT_MODEL = "gpt-5.4-mini";
const MAX_IMAGE_BYTES = 5 * 1024 * 1024;
const MAX_ANALYSES_PER_HOUR = 20;
const ALLOWED_MEDIA_TYPES = ["image/jpeg", "image/png", "image/webp"] as const;

const CATEGORIES = [
  "vegetable", "fruit", "legume", "wholeGrain", "refinedGrain", "tuber", "leanProtein",
  "redMeat", "processedMeat", "fish", "egg", "dairy", "nutsSeeds", "fatsOils", "sweets",
  "sugaryDrink", "beverage", "snack", "fastFood", "mixedDish", "other",
] as const;

const NUTRIENT_KEYS = [
  "calories", "protein", "carbohydrates", "fat", "saturated_fat", "fiber", "sugar", "sodium_mg",
] as const;

// Salida estructurada estricta: todos los campos obligatorios, sin campos extra.
const ANALYSIS_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["is_food", "overall_confidence", "notes", "foods"],
  properties: {
    is_food: { type: "boolean" },
    overall_confidence: { type: "number" },
    notes: { type: "string" },
    foods: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["name", "estimated_grams", "confidence", "category", "nova_group", "per_100g"],
        properties: {
          name: { type: "string" },
          estimated_grams: { type: "number" },
          confidence: { type: "number" },
          category: { type: "string", enum: CATEGORIES },
          nova_group: { type: "integer" },
          per_100g: {
            type: "object",
            additionalProperties: false,
            required: [...NUTRIENT_KEYS],
            properties: Object.fromEntries(NUTRIENT_KEYS.map((key) => [key, { type: "number" }])),
          },
        },
      },
    },
  },
};

type Food = {
  name: string;
  estimated_grams: number;
  confidence: number;
  category: string;
  nova_group: number;
  per_100g: Record<string, number>;
};
type Analysis = { is_food: boolean; overall_confidence: number; notes: string; foods: Food[] };

class OpenAIError extends Error {
  constructor(readonly status: number) {
    super(`OpenAI ${status}`);
  }
}

async function analyzeWithOpenAI(image: string, mediaType: string): Promise<Analysis | null> {
  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${Deno.env.get("OPENAI_API_KEY")}`,
    },
    body: JSON.stringify({
      model: Deno.env.get("OPENAI_MODEL") ?? DEFAULT_MODEL,
      instructions: SYSTEM_PROMPT,
      input: [{
        role: "user",
        content: [
          { type: "input_text", text: "Identifica todos los alimentos de este plato." },
          { type: "input_image", image_url: `data:${mediaType};base64,${image}`, detail: "high" },
        ],
      }],
      text: {
        format: { type: "json_schema", name: "meal_analysis", schema: ANALYSIS_SCHEMA, strict: true },
      },
    }),
    signal: AbortSignal.timeout(60_000),
  });

  if (!response.ok) {
    console.error("OpenAI error", response.status, await response.text());
    throw new OpenAIError(response.status);
  }

  const data = await response.json();
  const parts: { type: string; text?: string }[] = (data.output ?? [])
    .filter((item: { type: string }) => item.type === "message")
    .flatMap((item: { content?: unknown[] }) => item.content ?? []);
  if (parts.some((part) => part.type === "refusal")) return null;
  const text = parts.find((part) => part.type === "output_text")?.text;
  if (!text) return null;
  try {
    return JSON.parse(text) as Analysis;
  } catch {
    return null;
  }
}

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

Separa SIEMPRE los componentes del plato (arroz, carne, ensalada, papas) en lugar de un solo plato.
Identifica TODOS los alimentos visibles, incluidos alimentos simples (un huevo cocido, una fruta,
un pan), bebidas, salsas y postres. Cuenta las unidades y estima su peso (ej. 2 huevos ≈ 100 g).
Nunca omitas un alimento por no estar seguro: da tu mejor opción con confidence baja.
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

  // 4. Análisis con GPT y salida estructurada.
  try {
    const result = await analyzeWithOpenAI(image, mediaType as string);
    if (!result) return json({ error: "analysis_failed" }, 422);

    const clamp = (value: number, min: number, max: number) => Math.min(Math.max(value, min), max);
    return json({
      overall_confidence: result.is_food ? clamp(result.overall_confidence, 0, 1) : 0,
      notes: result.notes,
      foods: result.is_food
        ? result.foods.slice(0, 20).map((food) => ({
          ...food,
          estimated_grams: clamp(food.estimated_grams, 1, 3000),
          confidence: clamp(food.confidence, 0, 1),
          nova_group: clamp(food.nova_group, 1, 4),
        }))
        : [],
    });
  } catch (error) {
    if (error instanceof OpenAIError) {
      return json({ error: error.status === 429 ? "rate_limited" : "analysis_unavailable" }, error.status === 429 ? 429 : 502);
    }
    if (error instanceof DOMException && error.name === "TimeoutError") {
      return json({ error: "analysis_unavailable" }, 504);
    }
    console.error("Unexpected error", error);
    return json({ error: "analysis_failed" }, 500);
  }
});
