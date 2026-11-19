// weekend-ai: the AI features of Volo via!, on Cloudflare Workers AI (free tier).
//   GET  /recap  -> news-style recap of the latest job run (cached per run)
//   POST /guide  -> tourist card of a destination for the travel dates (cached per city and month)
//   POST /crazy  -> "Pazzie": cheap weekends, weekend+ and ponti told as a ranking (cached per list)
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
      if (url.pathname === "/crazy" && request.method === "POST") {
        return json(await crazy(env, request, await request.json()));
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

// ---------- Pazzie: trips under 50 euro told as a ranking ----------

// The app sends the (at most 30) most imminent cheap weekends; every field is checked,
// and the answer is cached by the content of the list, so identical lists cost one AI call.
async function crazy(env, request, body) {
  const raw = Array.isArray(body?.items) ? body.items.slice(0, 30) : [];
  const date = /^\d{4}-\d{2}-\d{2}$/;
  const hhmm = (v) => (typeof v === "string" && /^\d{2}:\d{2}$/.test(v) ? v : "");
  const items = raw.map((x, i) => ({
    id: str(x.id, 40, "id"),
    city: str(x.city, 60, "city"),
    country: str(x.country || "", 60, "country", true),
    from: str(x.from || "", 40, "from", true),
    out: str(x.out, 10, "out"),
    ret: str(x.ret, 10, "ret"),
    price: Number(x.price),
    hours: Number(x.hours) > 0 && Number(x.hours) < 200 ? Math.round(Number(x.hours)) : 0,
    dep: hhmm(x.dep),
    arr: hhmm(x.arr),
    kind: ["weekend", "weekend+", "ponte"].includes(x.kind) ? x.kind : "weekend",
    leave: Math.max(0, Math.min(5, Math.round(Number(x.leave) || 0))),
    holidays: str(x.holidays || "", 80, "holidays", true),
    rank: i + 1,
  })).filter((x) => date.test(x.out) && date.test(x.ret) && x.price > 0 && x.price < 1000);
  if (!items.length) throw httpError(400, "bad_input", "items is required");

  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(JSON.stringify(items)));
  const key = "crazy:v5:" + [...new Uint8Array(digest)].slice(0, 12).map((b) => b.toString(16).padStart(2, "0")).join("");
  const cached = await env.CACHE.get(key, "json");
  if (cached) return { ...cached, cached: true };
  await limit(env, request, "crazy");

  const system = `Sei un conduttore radiofonico italiano simpatico che presenta una classifica di "pazzie":
viaggi low cost in aereo sotto i 50 euro andata e ritorno, dal più vicino nel tempo al più lontano.
Per OGNI voce dell'elenco scrivi un titolo brevissimo (massimo 6 parole, evocativo, che richiami il carattere
della città, senza prezzo e senza date) e una frase di 30-45 parole, in italiano naturale e colloquiale, che dica
la città, la nazione, l'aeroporto di partenza, la partenza (giorno e ora del volo di andata) e l'arrivo
(giorno e ora in cui si atterra di nuovo a casa) ESATTAMENTE come li ricevi (es. "si parte venerdì 4 dicembre
alle 19:10 e si torna a casa domenica 6 dicembre alle 22:30"), le ore nette sfruttabili sul posto
(es. "26 ore nette da godersi") e il prezzo esattamente come lo ricevi.
Se un orario manca, scrivi solo il giorno; se mancano le ore nette, non citarle.
Il campo "tipo" dice che viaggio è: chiamalo così ("weekend", "weekend lungo", "ponte") e, se ci sono,
cita i giorni di ferie e la festa come li ricevi. Non chiamare mai "ponte" un viaggio che non è di tipo ponte.
Varia l'inizio delle frasi: non cominciare mai due frasi allo stesso modo e non iniziare con "Un weekend".
Puoi aggiungere un tocco di colore generico e sicuro sulla città (es. tapas, mare, castelli), ma non
inventare eventi, altri orari, compagnie o confronti tra le voci (niente "il più vicino", "il più economico").
Niente elenchi puntati.
Rispondi SOLO con un oggetto JSON {"items":[{"id": "...", "title": "...", "text": "..."}]} con lo stesso id
di ogni voce ricevuta, nello stesso ordine.`;
  // Weekday names are written here: models often get them wrong.
  const day = (iso) => new Date(iso + "T12:00:00Z").toLocaleDateString("it-IT",
    { weekday: "long", day: "numeric", month: "long", timeZone: "UTC" });
  const euro = (p) => p.toFixed(2).replace(".", ",") + " euro";
  const at = (d, t) => (t ? `${d} alle ${t}` : d);
  const kindName = { weekend: "weekend", "weekend+": "weekend lungo", ponte: "ponte" };
  const leaveText = (n) => (n === 0 ? "senza ferie" : n === 1 ? "con 1 giorno di ferie" : `con ${n} giorni di ferie`);
  const user = "Voci della classifica:\n" + JSON.stringify(items.map(({ id, rank, city, country, from, out, ret, price, hours, dep, arr, kind, leave, holidays }) =>
    ({
      id, rank, city, country, tipo: kindName[kind], ferie: leaveText(leave), festa: holidays,
      aeroporto_di_partenza: from,
      partenza: at(day(out), dep), arrivo_a_casa: at(day(ret), arr),
      ore_nette: hours ? `${hours} ore nette` : "", prezzo: euro(price),
    })));
  const out = await chatJson(env, system, user, 4000);
  const byId = new Map(arr(out.items).map((x) => [String(x?.id ?? ""), x]));
  const result = {
    items: items.map((x) => {
      const a = byId.get(x.id) || {};
      return { id: x.id, title: String(a.title || ""), text: String(a.text || "") };
    }),
    generated: new Date().toISOString(),
    model: env.MODEL,
  };
  await env.CACHE.put(key, JSON.stringify(result), { expirationTtl: 3 * DAY });
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
