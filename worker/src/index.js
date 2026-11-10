// Explore API: the AI backend of a kid-friendly single-player MUD.
// The game state lives on the player's device; this Worker is stateless and
// only turns state into text/images and player text into structured actions.

const MAX_TEXT = 300; // max chars of player input
const MAX_BODY = 16 * 1024; // max request body bytes

const WORLD_RULES = `Sei il narratore di un gioco di esplorazione per bambini dai 6 ai 10 anni.
Regole del mondo, sempre valide:
- Il mondo è fondamentalmente buono, allegro e pieno di meraviglia.
- Niente violenza, sangue, morte, paura intensa, armi, contenuti per adulti, linguaggio volgare.
- Le "creature strane" sono buffe o timide, mai crudeli; i conflitti si risolvono con gentilezza, astuzia o enigmi.
- Se il giocatore chiede qualcosa di inadatto, reindirizza con dolcezza verso qualcosa di bello da fare.
- Scrivi in italiano semplice, frasi brevi, lessico adatto ai bambini.`;

const ACTIONS = [
  "move", "look", "take", "drop", "use", "talk", "give",
  "change", "inventory", "help", "unknown",
];

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") return cors(new Response(null, { status: 204 }));
    const url = new URL(request.url);
    try {
      if (request.method === "GET" && url.pathname === "/health") {
        return json({ ok: true, models: { text: env.TEXT_MODEL, image: env.IMAGE_MODEL } });
      }
      if (request.method !== "POST") return json({ error: "not_found" }, 404);
      const body = await readJson(request);
      switch (url.pathname) {
        case "/v1/interpret": return json(await interpret(env, body));
        case "/v1/describe": return json(await describe(env, body));
        case "/v1/region": return json(await region(env, body));
        case "/v1/image": return await image(env, body);
        default: return json({ error: "not_found" }, 404);
      }
    } catch (err) {
      const status = err instanceof HttpError ? err.status : 502;
      console.error(err);
      return json({ error: err.code || "ai_error", message: String(err.message || err) }, status);
    }
  },
};

// ---------- endpoints ----------

// Player text -> structured action. The device applies it to the game state.
async function interpret(env, body) {
  const text = str(body.text, MAX_TEXT, "text");
  const ctx = body.context || {};
  if (!(await isSafe(env, text))) {
    return {
      action: "unknown",
      reply: "Hmm, proviamo qualcosa di più gentile! Che ne dici di esplorare un po'?",
      flagged: true,
    };
  }
  const system = `${WORLD_RULES}

Il tuo compito ora: trasformare il comando del giocatore in UNA azione di gioco in formato JSON.
Azioni possibili: ${ACTIONS.join(", ")}.
- move: spostarsi; "direction" è uno tra "n","s","e","o" (nord, sud, est, ovest).
- look: guardarsi intorno o esaminare "object".
- take / drop: prendere o lasciare "object".
- use: usare "object" (eventualmente su "target").
- talk: parlare con "target"; "message" è cosa dice il giocatore.
- give: dare "object" a "target".
- change: il giocatore modifica il luogo (costruisce, pianta, dipinge, ripara...). "effect" descrive il cambiamento in poche parole; "addFeatures" e "removeFeatures" sono elenchi brevi di elementi del luogo (es. "un ponte di legno").
- inventory, help: ovvi.
- unknown: non si capisce.
Usa solo oggetti/personaggi plausibili rispetto al contesto. "reply" è una breve risposta del narratore (max 2 frasi).
Rispondi SOLO con un oggetto JSON, senza testo prima o dopo, con chiavi: action, direction, object, target, message, effect, addFeatures, removeFeatures, reply.`;
  const user = `Contesto del luogo: ${compact(ctx)}
Comando del giocatore: "${text}"`;
  const out = await chatJson(env, system, user);
  if (!ACTIONS.includes(out.action)) out.action = "unknown";
  if (out.action === "move" && !["n", "s", "e", "o"].includes(out.direction)) out.action = "unknown";
  out.addFeatures = arr(out.addFeatures);
  out.removeFeatures = arr(out.removeFeatures);
  return out;
}

// Cell state -> title, description and an image prompt that reflects the state.
async function describe(env, body) {
  const cell = body.cell || {};
  const system = `${WORLD_RULES}

Il tuo compito ora: descrivere un luogo della mappa a partire dal suo stato.
La descrizione deve riflettere TUTTI gli elementi presenti e gli eventi recenti causati dal giocatore.
Rispondi SOLO con un oggetto JSON con chiavi:
- "title": nome breve del luogo,
- "description": 3-5 frasi in italiano, in seconda persona ("Ti trovi..."),
- "imagePrompt": descrizione visiva della scena IN INGLESE, 1-2 frasi, solo cose visibili, nessun testo o scritta.`;
  const user = `Stato del luogo: ${compact(cell)}`;
  const out = await chatJson(env, system, user);
  return {
    title: String(out.title || cell.name || "Luogo misterioso"),
    description: String(out.description || ""),
    imagePrompt: String(out.imagePrompt || ""),
  };
}

// Lazy world generation: give a newly discovered cell a name and content,
// consistent with its biome and neighbours.
async function region(env, body) {
  const cell = body.cell || {};
  const system = `${WORLD_RULES}

Il tuo compito ora: inventare il contenuto di un nuovo luogo della mappa, coerente con il suo terreno e con i luoghi vicini.
Rispondi SOLO con un oggetto JSON con chiavi:
- "name": nome evocativo del luogo,
- "features": 2-4 elementi del paesaggio (stringhe brevi),
- "items": 0-2 oggetti raccoglibili (stringhe brevi),
- "npcs": 0-1 personaggi, ciascuno {"name","kind","mood"}; sempre amichevoli o buffi.`;
  const user = `Nuovo luogo: ${compact(cell)}
Tema del mondo: ${str(body.worldTheme || "una valle incantata", 200, "worldTheme")}`;
  const out = await chatJson(env, system, user);
  return {
    name: String(out.name || "Luogo senza nome"),
    features: arr(out.features),
    items: arr(out.items),
    npcs: Array.isArray(out.npcs) ? out.npcs.slice(0, 2) : [],
  };
}

// Image prompt -> JPEG. FLUX.1 schnell takes no seed, so the fixed style
// prefix is what keeps the look consistent across cells.
async function image(env, body) {
  const scene = str(body.prompt, 600, "prompt");
  const prompt = `Children's picture book illustration, soft watercolor, bright friendly colors, cozy and magical, no text, no letters. ${scene}`;
  const res = await env.AI.run(env.IMAGE_MODEL, { prompt, steps: 4 });
  if (!res || !res.image) throw new HttpError(502, "image_error", "no image returned");
  const bytes = Uint8Array.from(atob(res.image), (c) => c.charCodeAt(0));
  return cors(new Response(bytes, {
    headers: { "content-type": "image/jpeg", "cache-control": "public, max-age=31536000, immutable" },
  }));
}

// ---------- AI helpers ----------

async function chatJson(env, system, user) {
  const res = await env.AI.run(env.TEXT_MODEL, {
    messages: [
      { role: "system", content: system },
      { role: "user", content: user },
    ],
    max_tokens: 600,
    temperature: 0.7,
  });
  return parseJson(textOf(res));
}

async function isSafe(env, text) {
  try {
    const res = await env.AI.run(env.GUARD_MODEL, { messages: [{ role: "user", content: text }] });
    const r = res && res.response;
    if (r && typeof r === "object" && "safe" in r) return Boolean(r.safe);
    return !/unsafe/i.test(typeof r === "string" ? r : JSON.stringify(res));
  } catch (err) {
    console.error("guard failed", err);
    return true; // the narrator prompt still enforces the world rules
  }
}

function textOf(res) {
  if (!res) return "";
  if (typeof res.response === "string") return res.response;
  if (res.response && typeof res.response === "object") return JSON.stringify(res.response);
  const choice = res.choices && res.choices[0];
  if (choice) return choice.message?.content ?? choice.text ?? "";
  return typeof res === "string" ? res : JSON.stringify(res);
}

function parseJson(text) {
  const start = text.indexOf("{");
  const end = text.lastIndexOf("}");
  if (start < 0 || end <= start) throw new HttpError(502, "bad_ai_output", text.slice(0, 200));
  try {
    return JSON.parse(text.slice(start, end + 1));
  } catch {
    throw new HttpError(502, "bad_ai_output", text.slice(0, 200));
  }
}

// ---------- plumbing ----------

class HttpError extends Error {
  constructor(status, code, message) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

async function readJson(request) {
  const raw = await request.text();
  if (raw.length > MAX_BODY) throw new HttpError(413, "too_large", "request body too large");
  try {
    return raw ? JSON.parse(raw) : {};
  } catch {
    throw new HttpError(400, "bad_json", "body is not valid JSON");
  }
}

function str(v, max, name) {
  if (typeof v !== "string" || !v.trim()) throw new HttpError(400, "bad_input", `${name} is required`);
  return v.trim().slice(0, max);
}

function arr(v) {
  return Array.isArray(v) ? v.filter((x) => typeof x === "string" && x.trim()).slice(0, 6) : [];
}

function compact(obj) {
  return JSON.stringify(obj).slice(0, 4000);
}

function json(data, status = 200) {
  return cors(new Response(JSON.stringify(data), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  }));
}

function cors(res) {
  res.headers.set("access-control-allow-origin", "*");
  res.headers.set("access-control-allow-methods", "GET, POST, OPTIONS");
  res.headers.set("access-control-allow-headers", "content-type");
  return res;
}
