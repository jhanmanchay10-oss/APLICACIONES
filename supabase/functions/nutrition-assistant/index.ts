// Edge Function: asistente de nutrición con respuestas fundamentadas.
// Usa la búsqueda web de OpenAI limitada a fuentes de salud confiables y devuelve las citas.
import {
  authorize,
  callOpenAI,
  corsHeaders,
  json,
  model,
  OpenAIError,
  openAIErrorResponse,
  readBody,
} from "../_shared/common.ts";

const MAX_PER_HOUR = 40;
const MAX_MESSAGES = 12;
const MAX_MESSAGE_LENGTH = 2000;
const MAX_CONTEXT_LENGTH = 4000;

/** Fuentes oficiales y académicas de nutrición y salud. */
const TRUSTED_DOMAINS = [
  "who.int", "paho.org", "fao.org", "unicef.org",
  "minsa.gob.pe", "gob.pe", "ins.gob.pe",
  "nih.gov", "medlineplus.gov", "cdc.gov", "usda.gov", "fda.gov", "dietaryguidelines.gov",
  "hsph.harvard.edu", "nutritionsource.hsph.harvard.edu", "mayoclinic.org", "clevelandclinic.org",
  "nhs.uk", "efsa.europa.eu", "eatright.org", "cochranelibrary.com", "bmj.com", "thelancet.com",
];

const SYSTEM_PROMPT = `Eres "Nutri", el asistente de nutrición de la app NutriSemáforo (Perú).
Respondes en español claro, cálido y práctico, para cualquier persona.

Principios:
- Basa tus respuestas en evidencia y en fuentes confiables (OMS/OPS, FAO, MINSA e INS-CENAN del Perú,
  Guías Alimentarias para la Población Peruana, NIH, Harvard T.H. Chan, etc.). Usa la búsqueda web
  para verificar datos concretos (cifras, recomendaciones oficiales) y apóyate en ella.
- Enfócate en la calidad de la alimentación: verduras y frutas, fibra, legumbres, cereales integrales,
  fuentes de proteína variadas, agua; y en reducir azúcares añadidos, sodio, grasas saturadas y
  ultraprocesados. Da ejemplos con alimentos peruanos accesibles.
- NO promuevas dietas restrictivas, conteo obsesivo de calorías, ayunos extremos ni pérdida de peso
  rápida. No uses lenguaje que culpe o avergüence. La comida no es "buena" o "mala".
- No diagnostiques ni indiques tratamientos o dosis. Ante enfermedades (diabetes, hipertensión,
  enfermedad renal, embarazo, alergias, niños pequeños) da información general y recomienda
  consultar a un profesional de la salud.
- Si la persona muestra señales de una relación difícil con la comida (miedo a comer, culpa intensa,
  restricción extrema, atracones, vómitos), responde con empatía, no des cifras ni planes, y anímala
  con calidez a buscar apoyo de un profesional de la salud.
- Si te preguntan algo ajeno a la alimentación y la salud, redirige amablemente.

Formato:
- Respuestas breves: máximo unas 180 palabras, salvo que pidan más detalle.
- Texto plano. Para listas usa "• " al inicio de cada línea. Sin títulos, sin tablas, sin negritas.
- No escribas URLs ni enlaces en el texto: las fuentes se muestran aparte en la app.
- Cuando uses datos del resumen del usuario, menciónalo con naturalidad ("esta semana registraste…").`;

type Message = { role: "user" | "assistant"; content: string };

function cleanMessages(raw: unknown): Message[] | null {
  if (!Array.isArray(raw) || raw.length === 0) return null;
  const messages: Message[] = [];
  for (const item of raw.slice(-MAX_MESSAGES)) {
    if (!item || typeof item !== "object") return null;
    const { role, content } = item as Record<string, unknown>;
    if ((role !== "user" && role !== "assistant") || typeof content !== "string") return null;
    const text = content.replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g, "").trim().slice(0, MAX_MESSAGE_LENGTH);
    if (text) messages.push({ role, content: text });
  }
  return messages.length && messages[messages.length - 1].role === "user" ? messages : null;
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const caller = await authorize(request, "assistant", MAX_PER_HOUR);
  if (caller instanceof Response) return caller;

  const body = await readBody(request);
  const messages = cleanMessages(body?.messages);
  if (!messages) return json({ error: "invalid_messages" }, 400);
  const context = typeof body?.context === "string" ? body.context.slice(0, MAX_CONTEXT_LENGTH) : "";

  const instructions = context
    ? `${SYSTEM_PROMPT}\n\nResumen de los registros del usuario en la app (úsalo para personalizar):\n${context}`
    : SYSTEM_PROMPT;

  const input = messages.map((message) => ({ role: message.role, content: message.content }));
  const request_body: Record<string, unknown> = {
    model: model("OPENAI_ASSISTANT_MODEL"),
    instructions,
    input,
    tools: [{
      type: "web_search",
      filters: { allowed_domains: TRUSTED_DOMAINS },
      user_location: { type: "approximate", country: "PE", timezone: "America/Lima" },
    }],
  };

  try {
    let result;
    try {
      result = await callOpenAI(request_body, 90_000);
    } catch (error) {
      // Si el modelo no admite la búsqueda web, respondemos sin ella.
      if (!(error instanceof OpenAIError) || error.status !== 400) throw error;
      delete request_body.tools;
      result = await callOpenAI(request_body, 60_000);
    }
    if (!result.text) return json({ error: "analysis_failed" }, 422);
    return json({ reply: result.text.trim(), sources: result.citations });
  } catch (error) {
    return openAIErrorResponse(error);
  }
});
