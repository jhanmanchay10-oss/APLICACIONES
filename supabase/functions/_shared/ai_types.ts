// Tipos comunes a los proveedores de IA (OpenAI y Claude).

/** Error HTTP devuelto por el proveedor de IA. */
export class AIError extends Error {
  constructor(readonly status: number) {
    super(`AI provider ${status}`);
  }
}

export type AIResult = {
  text: string | null;
  refused: boolean;
  citations: { title: string; url: string }[];
};

/** Contenido de un mensaje del usuario (texto o imagen como data URL). */
export type ContentPart =
  | { type: "input_text"; text: string }
  | { type: "input_image"; image_url: string; detail?: "low" | "high" | "auto" };
