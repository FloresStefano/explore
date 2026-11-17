// weekend-ai: the two AI features of Weekend Break, on Cloudflare Workers AI (free tier).
//   GET  /recap  -> news-style recap of the latest job run (cached per run)
//   POST /guide  -> tourist card of a destination for the travel dates (cached per city and month)
// The app has no keys: this Worker is public, rate limited per IP, and caches everything in KV.

const DAY = 86400;

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") return cors(new Response(null, { status: 204 }));
    const url = new URL(request.url);
    try {
      if (url.pathname === "/health") return json({ ok: true, model: env.MODEL });
      if (url.pathname === "/recap" && request.method === "GET") {
        return json(await recap(env, request, url.searchParams.has("refresh")));
      }
      if (url.pathname === "/guide" && request.method === "POST") {
        return json(await guide(env, request, await request.json()));
      }
      return json({ error: "not_found" }, 404);
    } catch (err) {
      const status = err.status || 502;
      return json({ error: err.code || "ai_error", message: String(err.message || err) }, status);
    }
  },
};

// ---------- 7.2 recap ----------

async function recap(env, request, refresh) {
  const res = await fetch(env.DATA_URL + "summary.json", { cf: { cacheTtl: 300 } });
  if (!res.ok) throw httpError(503, "no_data", "Il resoconto sarà disponibile dopo la prossima raccolta.");
  const summary = await res.json();
  const key = `recap:${summary.run_at}`;
  if (!refresh) {
    const cached = await env.CACHE.get(key, "json");
    if (cached) return cached;
  }
  await limit(env, request, "recap");
  const system = `Sei un giornalista di viaggi italiano. Scrivi un breve articolo di cronaca sulle offerte di volo
trovate oggi da un'app che cerca weekend e ponti in partenza da Verona (VRN), Bergamo (BGY) e Treviso (TSF).
Tipi di viaggio: "weekend" (senza ferie), "weekend+" (un giorno di ferie, venerdì o lunedì), "ponte" (intorno a una festività).
Usa SOLO i dati forniti: niente prezzi o mete inventati. Prezzi in euro, andata e ritorno per un adulto, tariffa base senza bagaglio.
Tono vivace ma preciso, italiano corretto, nessun elenco puntato nel corpo.
Rispondi SOLO con un oggetto JSON con chiavi:
"headline" (titolo di massimo 10 parole),
"lead" (2 frasi di sintesi),
"paragraphs" (elenco di 4-6 paragrafi: le mete più economiche, la composizione delle migliori offerte per tipo e per paese, le compagnie, un consiglio finale).`;
  const out = await chatJson(env, system, `Dati dell'ultima raccolta:\n${JSON.stringify(summary)}`, 2000);
  const paragraphs = Array.isArray(out.paragraphs) ? out.paragraphs.map(text) : [String(out.body || "")];
  const result = {
    run_at: summary.run_at,
    headline: String(out.headline || "Le occasioni di oggi"),
    lead: String(out.lead || ""),
    body: paragraphs.filter((p) => p.trim()).join("\n\n"),
  };
  await env.CACHE.put(key, JSON.stringify(result), { expirationTtl: 7 * DAY });
  return result;
}

// ---------- 7.1 guide ----------

async function guide(env, request, body) {
  const city = str(body.city, 80, "city");
  const country = str(body.country || "", 80, "country", true);
  const code = str(body.code || "", 3, "code", true).toUpperCase();
  const out = str(body.out, 10, "out");
  const ret = str(body.ret || out, 10, "ret");
  const month = out.slice(0, 7);
  const key = `guide:v2:${code || city}:${month}`;
  const cached = await env.CACHE.get(key, "json");
  if (cached) return { ...cached, cached: true };
  await limit(env, request, "guide");
  const system = `Sei una guida turistica esperta e onesta. Scrivi in italiano una scheda per chi arriva in aereo
per un breve viaggio (2-5 notti). Considera la città e tutto ciò che è raggiungibile entro 100 km.
Una parte racconta le cose classiche; un'altra esamina il periodo del viaggio: eventi ricorrenti, feste, mercatini,
stagione, clima e cosa cambia in quel mese. Non inventare date precise di eventi che non conosci con certezza:
in quel caso indica che sono ricorrenti e da verificare.
Rispondi SOLO con un oggetto JSON con chiavi:
"title" (es. "Siviglia a dicembre"),
"intro" (2-3 frasi),
"classics": elenco di 5-7 oggetti {"name","distance_km","why"} con distance_km dal centro (0 se in città),
"period": elenco di 2-5 oggetti {"name","when","note"} su ciò che è speciale in quel periodo,
"weather" (1 frase sul clima tipico del periodo),
"tips": elenco di 2-3 consigli pratici brevi (trasporto dall'aeroporto, quartieri, cibo).`;
  const user = `Destinazione: ${city}${country ? ", " + country : ""}${code ? " (aeroporto " + code + ")" : ""}.
Date del viaggio: dal ${out} al ${ret}.`;
  const g = await chatJson(env, system, user, 1500);
  const result = {
    title: String(g.title || city),
    intro: String(g.intro || ""),
    classics: arr(g.classics).slice(0, 8).map((x) => ({
      name: String(x.name || ""), distance_km: Number(x.distance_km) || 0, why: String(x.why || ""),
    })),
    period: arr(g.period).slice(0, 6).map((x) => ({
      name: String(x.name || ""), when: String(x.when || ""), note: String(x.note || ""),
    })),
    weather: String(g.weather || ""),
    tips: arr(g.tips).slice(0, 4).map(text),
    generated: new Date().toISOString().slice(0, 10),
    model: env.MODEL,
  };
  await env.CACHE.put(key, JSON.stringify(result), { expirationTtl: 45 * DAY });
  return result;
}

// ---------- helpers ----------

async function chatJson(env, system, user, maxTokens) {
  const res = await env.AI.run(env.MODEL, {
    messages: [{ role: "system", content: system }, { role: "user", content: user }],
    max_tokens: maxTokens,
    temperature: 0.6,
  });
  const text = typeof res?.response === "string" ? res.response
    : res?.response ? JSON.stringify(res.response)
    : res?.choices?.[0]?.message?.content ?? "";
  const start = text.indexOf("{"), end = text.lastIndexOf("}");
  if (start < 0 || end <= start) throw httpError(502, "bad_ai_output", text.slice(0, 200));
  const raw = text.slice(start, end + 1);
  try {
    return JSON.parse(raw);
  } catch {
    try {
      return JSON.parse(escapeNewlinesInStrings(raw));
    } catch {
      throw httpError(502, "bad_ai_output", text.slice(0, 200));
    }
  }
}

// Models sometimes put raw line breaks inside JSON strings: escape them.
export function escapeNewlinesInStrings(s) {
  let out = "";
  let inString = false;
  let escaped = false;
  for (const c of s) {
    if (inString && !escaped && (c === "\n" || c === "\r")) {
      if (c === "\n") out += "\\n";
      continue;
    }
    if (c === '"' && !escaped) inString = !inString;
    escaped = c === "\\" && !escaped;
    out += c;
  }
  return out;
}

async function limit(env, request, what) {
  if (!env.LIMITER) return;
  const ip = request.headers.get("cf-connecting-ip") || "unknown";
  const { success } = await env.LIMITER.limit({ key: `${what}:${ip}` });
  if (!success) throw httpError(429, "rate_limited", "Troppe richieste, riprova tra un minuto.");
}

function str(v, max, name, optional = false) {
  if (typeof v !== "string" || !v.trim()) {
    if (optional) return "";
    throw httpError(400, "bad_input", `${name} is required`);
  }
  return v.trim().slice(0, max);
}

const arr = (v) => (Array.isArray(v) ? v : []);
// Some models answer list items as objects ({"tip": "..."}): keep their text.
const text = (x) => (typeof x === "string" ? x : x && typeof x === "object" ? Object.values(x).join(": ") : String(x));

function httpError(status, code, message) {
  return Object.assign(new Error(message), { status, code });
}

function json(data, status = 200) {
  return cors(new Response(JSON.stringify(data), {
    status, headers: { "content-type": "application/json; charset=utf-8" },
  }));
}

function cors(res) {
  res.headers.set("access-control-allow-origin", "*");
  res.headers.set("access-control-allow-methods", "GET, POST, OPTIONS");
  res.headers.set("access-control-allow-headers", "content-type");
  return res;
}
