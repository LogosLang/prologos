const fs = require('fs');
const html = fs.readFileSync(process.argv[2], 'utf8');
const m = html.match(/\/\* @PURE-BEGIN \*\/([\s\S]*?)\/\* @PURE-END \*\//);
if (!m) { console.error('PURE block not found'); process.exit(1); }
eval(m[1]);
let failures = 0;
const check = (cond, msg) => { if (!cond) { console.error('FAIL: ' + msg); failures++; } };
for (const file of process.argv.slice(3)) {
  const env = JSON.parse(fs.readFileSync(file, 'utf8'));
  check(env.vizTrace === 1, 'vizTrace version');
  const scopes = buildScopes(env);
  check(scopes.length > 0, 'scopes exist');
  let selfLoops = 0, maxNodes = 0;
  for (const s of scopes) {
    const g = buildGraph(s.section);
    maxNodes = Math.max(maxNodes, g.nodes.length);
    for (const e of g.edges) {
      check(g.byId.has(e.from) && g.byId.has(e.to), 'edge endpoints exist');
      if (e.from === e.to) selfLoops++;
    }
    const lay = layoutGraph(g);
    check(lay.componentCount >= 1 || g.nodes.length === 0, 'components');
    for (const n of g.nodes) {
      const p = lay.pos.get(n.key);
      check(p && isFinite(p.x) && isFinite(p.y), 'node positioned: ' + n.key);
    }
    // no two nodes at identical coords within a scope
    const seen = new Set();
    for (const n of g.nodes) {
      const p = lay.pos.get(n.key); const k = p.x + ',' + p.y;
      check(!seen.has(k), 'overlap at ' + k + ' in ' + s.id);
      seen.add(k);
    }
  }
  const bucketed = (env.epochs || []).reduce((s, e) => s + roundsForEpoch(env, e.epoch).length, 0);
  check(bucketed <= env.validation.roundsTotal, 'bucketed rounds <= total');
  console.log(`${file}: scopes=${scopes.length} maxNodes=${maxNodes} selfLoopEdges=${selfLoops} bucketedRounds=${bucketed}/${env.validation.roundsTotal}`);
}
console.log(failures === 0 ? 'ALL CHECKS PASS' : failures + ' FAILURES');
process.exit(failures === 0 ? 0 : 1);
