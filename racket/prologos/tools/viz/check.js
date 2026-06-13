// Headless verification of the viewer's pure core (the @PURE block) against
// real exported envelopes. Runs in node (no browser): extracts the pure
// functions, exercises the unified-timeline model, asserts invariants.
//   node tools/viz/check.js tools/viz/index.html trace1.vizjson trace2.vizjson ...
const fs = require('fs');
const html = fs.readFileSync(process.argv[2], 'utf8');
const m = html.match(/\/\* @PURE-BEGIN \*\/([\s\S]*?)\/\* @PURE-END \*\//);
if (!m) { console.error('PURE block not found'); process.exit(1); }
eval(m[1]);

let failures = 0;
const check = (cond, msg) => { if (!cond) { console.error('FAIL: ' + msg); failures++; } };

for (const file of process.argv.slice(3)) {
  if (!fs.existsSync(file)) { console.log(file, 'MISSING'); continue; }
  const env = JSON.parse(fs.readFileSync(file, 'utf8'));
  check(env.vizTrace === 1, 'vizTrace version');

  const union = buildUnion(env);
  const wired = wiredCellIds(union);
  const visDefault = visibleCellIds(env, union, false);
  const visAll = visibleCellIds(env, union, true);
  check(visAll.size >= visDefault.size, 'show-all ⊇ default');
  for (const w of wired) check(visDefault.has(w), 'wired cell ' + w + ' visible by default');

  const g = buildGraph(union, visDefault, env);
  const touched = new Set();
  for (const e of g.edges) { check(g.byId.has(e.from) && g.byId.has(e.to), 'edge endpoints'); touched.add(e.from); touched.add(e.to); }
  const cellNodes = g.nodes.filter(n => n.kind === 'cell');
  const connCells = cellNodes.filter(n => touched.has(n.key) || (union.identity.wellKnownCells || {})[String(n.id)]);
  const connPct = cellNodes.length ? Math.round(100 * connCells.length / cellNodes.length) : 100;

  const labeled = g.nodes.filter(n => n.kind === 'prop' && !/^p\d+$/.test(n.label)).length;
  const propCount = g.nodes.filter(n => n.kind === 'prop').length;

  const lay = layoutGraph(g);
  const seen = new Set();
  for (const n of g.nodes) { const p = lay.pos.get(n.key); check(p && isFinite(p.x) && isFinite(p.y), 'positioned ' + n.key);
    const k = p.x + ',' + p.y; check(!seen.has(k), 'overlap ' + k); seen.add(k); }

  const rounds = timelineRounds(env);
  const presence = epochPresence(env);
  let prevRN = -Infinity, anyFired = false, anyGrowth = false;
  for (let i = 0; i < rounds.length; i++) {
    check(rounds[i].roundNumber >= prevRN, 'rounds ordered'); prevRN = rounds[i].roundNumber;
    const fr = frameAt(env, rounds, presence, i);
    if (fr.fired.size) anyFired = true;
    if (i > 0 && (fr.born.cells.size || fr.born.props.size)) anyGrowth = true;
    for (const p of fr.present.props) check(union.props.has(p), 'present prop in union ' + p);
  }
  check(anyFired, 'some round fires a propagator');
  check(anyGrowth || rounds.length <= 1, 'network grows across the timeline');
  const series = growthSeries(env, rounds, presence);
  check(series.length === rounds.length, 'growth series length');

  console.log(`${file.split('/').pop()}: cells(union)=${union.cells.size} props=${union.props.size} ` +
              `| default-view cells=${cellNodes.length} (${connPct}% connected) ` +
              `| propLabels=${labeled}/${propCount} from source | rounds=${rounds.length} components=${lay.componentCount}`);
}
console.log(failures === 0 ? 'ALL CHECKS PASS' : failures + ' FAILURES');
process.exit(failures === 0 ? 0 : 1);
