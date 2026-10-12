// Proveedor Claude para las funciones de IA.
// Funciona con la API oficial de Anthropic o con un servicio compatible
// (por ejemplo, un revendedor) configurando estos secretos del servidor:
//   CLAUDE_API_KEY     la clave (obligatoria para activar Claude)
//   CLAUDE_BASE_URL    p. ej. https://api.mwapi.dev/v1 (por defecto https://api.anthropic.com/v1)
//   CLAUDE_MODEL       p. ej. claude-sonnet-5 (por defecto claude-opus-5)
//   CLAUDE_API_FORMAT  anthropic | openai | auto (por defecto auto: prueba el formato
//                      de Anthropic y, si el servicio no lo tiene, el compatible con OpenAI)
import { AIError, type AIResult, type ContentPart } from "./ai_types.ts";

const ANTHROPIC_VERSION = "2023-06-01";
const MAX_TOKENS = 16000;

type Format = "anthropic" | "openai";
let detectedFormat: Format | null = null;

export function claudeConfigured(): boolean {
  return Boolean(Deno.env.get("CLAUDE_API_KEY"));
}

function baseUrl(): string {
  return (Deno.env.get("CLAUDE_BASE_URL") ?? "https://api.anthropic.com/v1").replace(/\/+$/, "");
}

function claudeModel(envName?: string): string {
  return (envName && Deno.env.get(envName)) || Deno.env.get("CLAUDE_MODEL") || "claude-opus-5";
}

function configuredFormat(): Format | "auto" {
  const value = (Deno.env.get("CLAUDE_API_FORMAT") ?? "auto").toLowerCase();
  return value === "anthropic" || value === "openai" ? value : "auto";
}

function isOfficialHost(): boolean {
  return new URL(baseUrl()).hostname === "api.anthropic.com";
}

async function post(path: string, body: unknown, timeoutMs: number, format: Format): Promise<Record<string, unknown>> {
  const key = Deno.env.get("CLAUDE_API_KEY")!;
  const headers: Record<string, string> = { "Content-Type": "application/json" };
  if (format === "anthropic") {
    headers["x-api-key"] = key;
    headers["anthropic-version"] = ANTHROPIC_VERSION;
    // Muchos servicios compatibles aceptan la clave como Bearer; la API oficial no lo necesita.
    if (!isOfficialHost()) headers["Authorization"] = `Bearer ${key}`;
  } else {
    headers["Authorization"] = `Bearer ${key}`;
  }

  const response = await fetch(`${baseUrl()}${path}`, {
    method: "POST",
    headers,
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(timeoutMs),
  });
  if (!response.ok) {
    console.error("Claude error", format, response.status, (await response.text()).slice(0, 500));
    throw new AIError(response.status);
  }
  return await response.json();
}

/** Ejecuta la llamada con el formato configurado o detectado. */
async function withFormat<T>(run: (format: Format) => Promise<T>): Promise<T> {
  const configured = configuredFormat();
  if (configured !== "auto") return run(configured);
  if (detectedFormat) return run(detectedFormat);
  try {
    const result = await run("anthropic");
    detectedFormat = "anthropic";
    return result;
  } catch (error) {
    // 404/405: el servicio no tiene /messages; probamos el formato compatible con OpenAI.
    if (!(error instanceof AIError) || (error.status !== 404 && error.status !== 405)) throw error;
    const result = await run("openai");
    detectedFormat = "openai";
    return result;
  }
}

// --- Conversión de contenido ----------------------------------------------------

function parseDataUrl(url: string): { mediaType: string; data: string } | null {
  const match = /^data:(image\/(?:jpeg|png|webp));base64,([A-Za-z0-9+/=]+)$/.exec(url);
  return match ? { mediaType: match[1], data: match[2] } : null;
}

function anthropicContent(parts: ContentPart[]): Record<string, unknown>[] {
  // Las imágenes van antes del texto, como recomienda Anthropic.
  const images = parts.flatMap((part) => {
    if (part.type !== "input_image") return [];
    const image = parseDataUrl(part.image_url);
    return image ? [{ type: "image", source: { type: "base64", media_type: image.mediaType, data: image.data } }] : [];
  });
  const texts = parts.flatMap((part) => (part.type === "input_text" ? [{ type: "text", text: part.text }] : []));
  return [...images, ...texts];
}

function openAIContent(parts: ContentPart[]): Record<string, unknown>[] {
  return parts.map((part) =>
    part.type === "input_text"
      ? { type: "text", text: part.text }
      : { type: "image_url", image_url: { url: part.image_url } }
  );
}

type AnthropicBlock = {
  type: string;
  text?: string;
  citations?: { type: string; url?: string; title?: string }[];
};

function anthropicResult(data: Record<string, unknown>): AIResult {
  const blocks = (data.content as AnthropicBlock[] | undefined) ?? [];
  const texts = blocks.filter((block) => block.type === "text" && block.text).map((block) => block.text!);
  const seen = new Set<string>();
  const citations: { title: string; url: string }[] = [];
  for (const block of blocks) {
    for (const citation of block.citations ?? []) {
      if (!citation.url || seen.has(citation.url) || !/^https:\/\//.test(citation.url)) continue;
      seen.add(citation.url);
      citations.push({ title: (citation.title ?? citation.url).slice(0, 140), url: citation.url });
    }
  }
  return {
    text: texts.length ? texts.join("") : null,
    refused: data.stop_reason === "refusal",
    citations: citations.slice(0, 6),
  };
}

function openAIResult(data: Record<string, unknown>): AIResult {
  const choice = (data.choices as { message?: { content?: string; refusal?: string } }[] | undefined)?.[0];
  return { text: choice?.message?.content ?? null, refused: Boolean(choice?.message?.refusal), citations: [] };
}

/** Extrae el primer objeto JSON de un texto (por si el modelo añade texto alrededor). */
function parseJsonObject<T>(text: string | null): T | null {
  if (!text) return null;
  const cleaned = text.replace(/^```(?:json)?\s*/i, "").replace(/```\s*$/, "").trim();
  for (const candidate of [cleaned, cleaned.slice(cleaned.indexOf("{"), cleaned.lastIndexOf("}") + 1)]) {
    try {
      const value = JSON.parse(candidate);
      if (value && typeof value === "object") return value as T;
    } catch {
      // Se prueba el siguiente candidato.
    }
  }
  return null;
}

function jsonInstructions(instructions: string, schema: Record<string, unknown>): string {
  return `${instructions}

Responde ÚNICAMENTE con un objeto JSON válido (sin texto adicional ni bloques de código) que cumpla
exactamente este JSON Schema:
${JSON.stringify(schema)}`;
}

// --- API pública ------------------------------------------------------------------

/** Respuesta JSON estructurada con Claude. */
export async function callClaudeJson<T>(
  instructions: string,
  content: ContentPart[],
  schema: Record<string, unknown>,
): Promise<T | null> {
  const model = claudeModel();
  return await withFormat(async (format) => {
    if (format === "openai") {
      const data = await post("/chat/completions", {
        model,
        max_tokens: MAX_TOKENS,
        messages: [
          { role: "system", content: jsonInstructions(instructions, schema) },
          { role: "user", content: openAIContent(content) },
        ],
      }, 120_000, format);
      const result = openAIResult(data);
      return result.refused ? null : parseJsonObject<T>(result.text);
    }

    const messages = [{ role: "user", content: anthropicContent(content) }];
    try {
      // Salida estructurada nativa: el JSON siempre cumple el esquema.
      const data = await post("/messages", {
        model,
        max_tokens: MAX_TOKENS,
        system: instructions,
        messages,
        output_config: { format: { type: "json_schema", schema } },
      }, 120_000, format);
      const result = anthropicResult(data);
      return result.refused ? null : parseJsonObject<T>(result.text);
    } catch (error) {
      // Algunos servicios compatibles no admiten output_config: se pide el JSON en las instrucciones.
      if (!(error instanceof AIError) || error.status !== 400) throw error;
      const data = await post("/messages", {
        model,
        max_tokens: MAX_TOKENS,
        system: jsonInstructions(instructions, schema),
        messages,
      }, 120_000, format);
      const result = anthropicResult(data);
      return result.refused ? null : parseJsonObject<T>(result.text);
    }
  });
}

export type ChatMessage = { role: "user" | "assistant"; content: string };

/**
 * Conversación del asistente. Con el formato de Anthropic usa la búsqueda web
 * limitada a [allowedDomains]; si el servicio no la admite, responde sin ella.
 */
export async function callClaudeChat(
  instructions: string,
  messages: ChatMessage[],
  allowedDomains: string[],
): Promise<AIResult> {
  const model = claudeModel("CLAUDE_ASSISTANT_MODEL");
  return await withFormat(async (format) => {
    if (format === "openai") {
      const data = await post("/chat/completions", {
        model,
        max_tokens: 4000,
        messages: [{ role: "system", content: instructions }, ...messages],
      }, 90_000, format);
      return openAIResult(data);
    }

    const webSearch = {
      type: model.includes("haiku") ? "web_search_20250305" : "web_search_20260209",
      name: "web_search",
      max_uses: 3,
      allowed_domains: allowedDomains,
      user_location: { type: "approximate", country: "PE", timezone: "America/Lima" },
    };
    const conversation: Record<string, unknown>[] = [...messages];
    try {
      // La búsqueda web corre en el servidor de Claude; "pause_turn" pide continuar el turno.
      for (let attempt = 0; attempt < 3; attempt++) {
        const data = await post("/messages", {
          model,
          max_tokens: 8000,
          system: instructions,
          messages: conversation,
          tools: [webSearch],
        }, 110_000, format);
        if (data.stop_reason !== "pause_turn") return anthropicResult(data);
        conversation.push({ role: "assistant", content: data.content });
      }
      throw new AIError(504);
    } catch (error) {
      if (!(error instanceof AIError) || error.status !== 400) throw error;
      const data = await post("/messages", {
        model,
        max_tokens: 4000,
        system: instructions,
        messages,
      }, 90_000, format);
      return anthropicResult(data);
    }
  });
}
