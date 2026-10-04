// Utilidades compartidas por las Edge Functions de NutriSemáforo.
// La clave OPENAI_API_KEY vive solo en los secretos del servidor.
import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

export const DEFAULT_MODEL = "gpt-5.4-mini";

export function model(envName = "OPENAI_MODEL"): string {
  return Deno.env.get(envName) ?? Deno.env.get("OPENAI_MODEL") ?? DEFAULT_MODEL;
}

export type Caller = { admin: SupabaseClient; userId: string };

/**
 * Verifica la sesión del usuario (cuenta normal o invitado anónimo) y aplica
 * un límite de usos por hora para cada tipo de función.
 * Devuelve el usuario o una respuesta de error lista para enviar.
 */
export async function authorize(request: Request, kind: string, maxPerHour: number): Promise<Caller | Response> {
  if (!Deno.env.get("OPENAI_API_KEY")) return json({ error: "ai_not_configured" }, 503);

  const token = request.headers.get("Authorization")?.replace("Bearer ", "");
  if (!token) return json({ error: "unauthorized" }, 401);

  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const { data, error } = await admin.auth.getUser(token);
  if (error || !data.user) return json({ error: "unauthorized" }, 401);
  const userId = data.user.id;

  const since = new Date(Date.now() - 60 * 60 * 1000).toISOString();
  const { count } = await admin
    .from("ai_usage")
    .select("id", { count: "exact", head: true })
    .eq("user_id", userId)
    .eq("kind", kind)
    .gte("created_at", since);
  if ((count ?? 0) >= maxPerHour) return json({ error: "rate_limited" }, 429);

  await admin.from("ai_usage").insert({ user_id: userId, kind });
  return { admin, userId };
}

export async function readBody(request: Request): Promise<Record<string, unknown> | null> {
  try {
    const body = await request.json();
    return body && typeof body === "object" ? body as Record<string, unknown> : null;
  } catch {
    return null;
  }
}

const ALLOWED_MEDIA_TYPES = ["image/jpeg", "image/png", "image/webp"];
const MAX_IMAGE_BYTES = 5 * 1024 * 1024;

/** Valida la imagen en base64 y devuelve un data URL, o un código de error. */
export function imageDataUrl(body: Record<string, unknown>): { url: string } | { error: string; status: number } {
  const image = body.image_base64;
  const mediaType = body.media_type;
  if (typeof image !== "string" || image.length === 0 || !/^[A-Za-z0-9+/=]+$/.test(image)) {
    return { error: "invalid_image", status: 400 };
  }
  if (image.length * 0.75 > MAX_IMAGE_BYTES) return { error: "image_too_large", status: 413 };
  if (typeof mediaType !== "string" || !ALLOWED_MEDIA_TYPES.includes(mediaType)) {
    return { error: "invalid_media_type", status: 400 };
  }
  return { url: `data:${mediaType};base64,${image}` };
}

export class OpenAIError extends Error {
  constructor(readonly status: number) {
    super(`OpenAI ${status}`);
  }
}

export type OpenAIResult = {
  text: string | null;
  refused: boolean;
  citations: { title: string; url: string }[];
};

/** Llama a la Responses API de OpenAI y extrae el texto y las citas. */
export async function callOpenAI(body: Record<string, unknown>, timeoutMs = 60_000): Promise<OpenAIResult> {
  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${Deno.env.get("OPENAI_API_KEY")}`,
    },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(timeoutMs),
  });

  if (!response.ok) {
    console.error("OpenAI error", response.status, await response.text());
    throw new OpenAIError(response.status);
  }

  const data = await response.json();
  type Part = {
    type: string;
    text?: string;
    annotations?: { type: string; url?: string; title?: string }[];
  };
  const parts: Part[] = (data.output ?? [])
    .filter((item: { type: string }) => item.type === "message")
    .flatMap((item: { content?: Part[] }) => item.content ?? []);

  const texts = parts.filter((part) => part.type === "output_text" && part.text).map((part) => part.text!);
  const seen = new Set<string>();
  const citations: { title: string; url: string }[] = [];
  for (const part of parts) {
    for (const annotation of part.annotations ?? []) {
      if (annotation.type !== "url_citation" || !annotation.url || seen.has(annotation.url)) continue;
      if (!/^https:\/\//.test(annotation.url)) continue;
      seen.add(annotation.url);
      citations.push({ title: (annotation.title ?? annotation.url).slice(0, 140), url: annotation.url });
    }
  }

  return {
    text: texts.length ? texts.join("\n") : null,
    refused: parts.some((part) => part.type === "refusal"),
    citations: citations.slice(0, 6),
  };
}

/** Respuesta JSON estructurada (Structured Outputs en modo estricto). */
export async function callOpenAIJson<T>(
  instructions: string,
  content: Record<string, unknown>[],
  schemaName: string,
  schema: Record<string, unknown>,
): Promise<T | null> {
  const result = await callOpenAI({
    model: model(),
    instructions,
    input: [{ role: "user", content }],
    text: { format: { type: "json_schema", name: schemaName, schema, strict: true } },
  });
  if (result.refused || !result.text) return null;
  try {
    return JSON.parse(result.text) as T;
  } catch {
    return null;
  }
}

export function openAIErrorResponse(error: unknown): Response {
  if (error instanceof OpenAIError) {
    if (error.status === 429) return json({ error: "rate_limited" }, 429);
    if (error.status === 401) return json({ error: "ai_not_configured" }, 503);
    return json({ error: "analysis_unavailable" }, 502);
  }
  if (error instanceof DOMException && error.name === "TimeoutError") {
    return json({ error: "analysis_unavailable" }, 504);
  }
  console.error("Unexpected error", error);
  return json({ error: "analysis_failed" }, 500);
}

export const clamp = (value: number, min: number, max: number) =>
  Number.isFinite(value) ? Math.min(Math.max(value, min), max) : min;

// Esquema de un alimento (compartido por análisis de fotos y estimación por texto).
export const CATEGORIES = [
  "vegetable", "fruit", "legume", "wholeGrain", "refinedGrain", "tuber", "leanProtein",
  "redMeat", "processedMeat", "fish", "egg", "dairy", "nutsSeeds", "fatsOils", "sweets",
  "sugaryDrink", "beverage", "snack", "fastFood", "mixedDish", "other",
] as const;

export const NUTRIENT_KEYS = [
  "calories", "protein", "carbohydrates", "fat", "saturated_fat", "fiber", "sugar", "sodium_mg",
] as const;

export const PER_100G_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: [...NUTRIENT_KEYS],
  properties: Object.fromEntries(NUTRIENT_KEYS.map((key) => [key, { type: "number" }])),
};

export const FOOD_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["name", "estimated_grams", "confidence", "category", "nova_group", "per_100g"],
  properties: {
    name: { type: "string" },
    estimated_grams: { type: "number" },
    confidence: { type: "number" },
    category: { type: "string", enum: CATEGORIES },
    nova_group: { type: "integer" },
    per_100g: PER_100G_SCHEMA,
  },
};

export type Food = {
  name: string;
  estimated_grams: number;
  confidence: number;
  category: string;
  nova_group: number;
  per_100g: Record<string, number>;
};

/** Limpia los valores de la IA antes de enviarlos a la app. */
export function sanitizeFoods(foods: Food[]): Food[] {
  return foods.slice(0, 20).map((food) => ({
    ...food,
    name: String(food.name ?? "").slice(0, 80),
    estimated_grams: clamp(food.estimated_grams, 1, 3000),
    confidence: clamp(food.confidence, 0, 1),
    nova_group: Math.round(clamp(food.nova_group, 1, 4)),
    per_100g: Object.fromEntries(
      NUTRIENT_KEYS.map((key) => [key, clamp(Number(food.per_100g?.[key] ?? 0), 0, key === "sodium_mg" ? 40000 : 1000)]),
    ),
  }));
}

export const NUTRITION_RULES = `
Valores nutricionales por 100 g (sodio en mg), típicos y realistas. Usa como referencia las
Tablas Peruanas de Composición de Alimentos (INS/CENAN) y USDA FoodData Central.
category: el grupo de alimento más adecuado. nova_group: 1 sin procesar o mínimamente procesado
(huevo cocido, arroz, fruta, carne), 2 ingrediente culinario (aceite, azúcar), 3 procesado
(queso, pan, conservas), 4 ultraprocesado (gaseosas, galletas, embutidos, snacks de bolsa).
Escribe los nombres en español, en minúsculas y sin marcas salvo que sean visibles.`;
