// Smoke test: node scripts/smoke.mjs [baseUrl]
// Calls every endpoint once and saves the image next to this script.
import { writeFileSync } from "node:fs";

const base = process.argv[2] || "http://localhost:8787";

async function post(path, body) {
  const t = Date.now();
  const res = await fetch(base + path, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
  });
  const ms = Date.now() - t;
  if (!res.ok) throw new Error(`${path} -> ${res.status}: ${await res.text()}`);
  return { res, ms };
}

const cell = {
  x: 3, y: 2, biome: "prato fiorito", timeOfDay: "mattina",
  neighbors: [{ dir: "n", biome: "bosco" }, { dir: "e", biome: "ruscello" }],
};

console.log("health:", await (await fetch(base + "/health")).json());

let { res, ms } = await post("/v1/region", { cell, worldTheme: "una valle incantata con animali parlanti" });
const reg = await res.json();
console.log(`\nregion (${ms}ms):`, reg);

const state = { ...cell, name: reg.name, features: reg.features, items: reg.items, npcs: reg.npcs, events: [] };
({ res, ms } = await post("/v1/describe", { cell: state }));
const d1 = await res.json();
console.log(`\ndescribe (${ms}ms):`, d1);

for (const text of ["vai a nord", "raccolgo un fiore", "costruisco una casetta sull'albero", "voglio uccidere il drago"]) {
  ({ res, ms } = await post("/v1/interpret", { text, context: state }));
  console.log(`\ninterpret "${text}" (${ms}ms):`, await res.json());
}

state.features = [...state.features, "una casetta sull'albero"];
state.events = ["il giocatore ha costruito una casetta sull'albero"];
({ res, ms } = await post("/v1/describe", { cell: state }));
const d2 = await res.json();
console.log(`\ndescribe after change (${ms}ms):`, d2);

({ res, ms } = await post("/v1/image", { prompt: d2.imagePrompt }));
const img = Buffer.from(await res.arrayBuffer());
const out = new URL("./smoke.jpg", import.meta.url);
writeFileSync(out, img);
console.log(`\nimage (${ms}ms): ${img.length} bytes -> ${out.pathname}`);
