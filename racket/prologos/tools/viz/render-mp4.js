// render-mp4.js — render a vizTrace 2 timeline to one SVG per round, reusing
// the viewer's @PURE core (force-directed layout) so the video matches the
// browser. Pipeline (driven by the sibling shell command): node -> frames/*.svg
// -> rsvg-convert -> *.png -> ffmpeg -> mp4.
//   node tools/viz/render-mp4.js index.html trace.vizjson outdir [W H]
const fs = require('fs'), path = require('path');
const html = fs.readFileSync(process.argv[2], 'utf8');
const m = html.match(/\/\* @PURE-BEGIN \*\/([\s\S]*?)\/\* @PURE-END \*\//);
if (!m) { console.error('PURE block not found'); process.exit(1); }
eval(m[1]);

const env = JSON.parse(fs.readFileSync(process.argv[3], 'utf8'));
const outdir = process.argv[4];
const W = +(process.argv[5] || 1280), H = +(process.argv[6] || 720);
fs.mkdirSync(outdir, { recursive: true });

const rounds = timelineRounds(env);
const changed = changedCellIdsGlobal(env);
const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
const trim = (s, n) => { s = String(s); return s.length > n ? s.slice(0, n - 1) + '…' : s; };

// Build + force-layout each topology once (seed from previous for stability).
const built = new Map(); let prevPos = null;
function GL(topoIdx) {
  if (built.has(topoIdx)) return built.get(topoIdx);
  const graph = buildGraphFromTopo(env.topologies[topoIdx], env.source, changed, false);
  const layout = layoutForce(graph, prevPos, 1000, 700);
  prevPos = layout.pos;
  const v = { graph, layout }; built.set(topoIdx, v); return v;
}

const tfCache = new Map();
function tf(topoIdx) {
  if (tfCache.has(topoIdx)) return tfCache.get(topoIdx);
  const { graph, layout } = GL(topoIdx); const M = 70, TOP = 70;
  const keys = graph.nodes.map(n => n.key);
  if (!keys.length) { const t = { k: 1, tx: M, ty: TOP }; tfCache.set(topoIdx, t); return t; }
  const xs = keys.map(k => layout.pos.get(k).x), ys = keys.map(k => layout.pos.get(k).y);
  const minX = Math.min(...xs), maxX = Math.max(...xs), minY = Math.min(...ys), maxY = Math.max(...ys);
  const k = Math.min(1.7, Math.max(0.08, Math.min((W - 2 * M) / Math.max(maxX - minX, 1), (H - TOP - M) / Math.max(maxY - minY, 1))));
  const t = { k, tx: M - minX * k + (W - 2 * M - (maxX - minX) * k) / 2, ty: TOP - minY * k + (H - TOP - M - (maxY - minY) * k) / 2 };
  tfCache.set(topoIdx, t); return t;
}

function bornKeys(i) {
  if (i === 0) return topoNodeKeys(env, rounds[0].topo);
  const prev = topoNodeKeys(env, rounds[i - 1].topo), cur = topoNodeKeys(env, rounds[i].topo);
  const b = new Set(); for (const k of cur) if (!prev.has(k)) b.add(k); return b;
}

function svgFrame(i) {
  const r = rounds[i], { graph, layout } = GL(r.topo), t = tf(r.topo);
  const P = (x, y) => [t.tx + x * t.k, t.ty + y * t.k];
  const fired = new Set(r.propagatorsFired), born = bornKeys(i), changedC = new Set((r.cellDiffs || []).map(d => 'c' + d.cellId));
  const showLabels = t.k > 0.42;
  let s = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}" font-family="monospace">`;
  s += `<rect width="${W}" height="${H}" fill="#1e1e1e"/>`;
  for (const e of graph.edges) {
    const a = layout.pos.get(e.from), b = layout.pos.get(e.to); if (!a || !b) continue;
    const [ax, ay] = P(a.x, a.y), [bx, by] = P(b.x, b.y), live = fired.has(e.pid);
    if (e.kind === "containment") {  // reduction DAG — dashed violet
      s += `<line x1="${ax.toFixed(1)}" y1="${ay.toFixed(1)}" x2="${bx.toFixed(1)}" y2="${by.toFixed(1)}" stroke="#c586c0" stroke-width="1.1" stroke-dasharray="5,4"/>`;
      continue;
    }
    if (e.from === e.to) s += `<circle cx="${(ax + 10).toFixed(1)}" cy="${(ay - 10).toFixed(1)}" r="9" fill="none" stroke="${live ? '#4ec9b0' : '#3a3a3a'}" stroke-width="${live ? 2.4 : 0.8}"/>`;
    else { s += `<line x1="${ax.toFixed(1)}" y1="${ay.toFixed(1)}" x2="${bx.toFixed(1)}" y2="${by.toFixed(1)}" stroke="${live ? '#4ec9b0' : '#3a3a3a'}" stroke-width="${live ? 2.4 : 0.7}"/>`;
      if (live) { const dx = bx - ax, dy = by - ay, L = Math.hypot(dx, dy) || 1, ux = dx / L, uy = dy / L, hx = bx - ux * 12, hy = by - uy * 12;
        s += `<polygon points="${bx.toFixed(1)},${by.toFixed(1)} ${(hx - uy * 4).toFixed(1)},${(hy + ux * 4).toFixed(1)} ${(hx + uy * 4).toFixed(1)},${(hy - ux * 4).toFixed(1)}" fill="#4ec9b0"/>`; } }
  }
  for (const n of graph.nodes) {
    const p = layout.pos.get(n.key); const [x, y] = P(p.x, p.y);
    const isFired = n.kind === 'prop' && fired.has(n.id), wrote = changedC.has(n.key), isBorn = born.has(n.key);
    const stroke = isFired ? '#ff6b6b' : isBorn ? '#4ec9b0' : wrote ? '#e9c46a' : '#222', sw = (isFired || isBorn || wrote) ? 2.6 : 1, fill = wrote ? '#e9c46a' : n.color;
    if (n.kind === 'cell') s += `<circle cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="8" fill="${fill}" stroke="${stroke}" stroke-width="${sw}"/>`;
    else s += `<polygon points="${x.toFixed(1)},${(y - 9).toFixed(1)} ${(x + 9).toFixed(1)},${y.toFixed(1)} ${x.toFixed(1)},${(y + 9).toFixed(1)} ${(x - 9).toFixed(1)},${y.toFixed(1)}" fill="${fill}" stroke="${stroke}" stroke-width="${sw}"/>`;
    if (showLabels) s += `<text x="${(x + 12).toFixed(1)}" y="${(y + 4).toFixed(1)}" font-size="11" fill="${n.kind === 'prop' ? '#bcd' : '#bbb'}">${esc(trim(n.label, 30))}</text>`;
  }
  const cmds = env.commands || [], seq = (cmds.findIndex(c => c.label === r.command) + 1) || '?';
  const st = env.topologies[r.topo].topology.stats;
  s += `<rect x="0" y="0" width="${W}" height="48" fill="#252526"/>`;
  s += `<text x="16" y="30" font-size="18" fill="#9cdcfe">Prologos network</text>`;
  s += `<text x="220" y="30" font-size="16" fill="#dcdcaa">● command ${seq}/${cmds.length}: ${esc(trim(r.command, 42))}</text>`;
  s += `<text x="${W - 380}" y="30" font-size="14" fill="#ddd">round ${r.roundNumber} (${i + 1}/${rounds.length}) · fired ${fired.size} · ${st.totalCells}c/${st.totalPropagators}p</text>`;
  s += `<rect x="0" y="${H - 5}" width="${(W * (i + 1) / rounds.length).toFixed(0)}" height="5" fill="#4ec9b0"/></svg>`;
  return s;
}

for (let i = 0; i < rounds.length; i++) fs.writeFileSync(path.join(outdir, 'f' + String(i).padStart(4, '0') + '.svg'), svgFrame(i));
console.log('wrote ' + rounds.length + ' svg frames to ' + outdir);
