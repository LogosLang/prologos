// Headless verification of the viewer's pure core (the @PURE block) against
// real vizTrace 2 envelopes. node tools/viz/check.js index.html t1.vizjson ...
const fs = require('fs');
const html = fs.readFileSync(process.argv[2], 'utf8');
const m = html.match(/\/\* @PURE-BEGIN \*\/([\s\S]*?)\/\* @PURE-END \*\//);
if (!m) { console.error('PURE block not found'); process.exit(1); }
eval(m[1]);

let failures = 0;
const check = (c, msg) => { if (!c) { console.error('FAIL: ' + msg); failures++; } };

// ---- music-synced playback: parseTimings + stepForTime --------------------
const arrEq = (a, b) => a.length === b.length && a.every((x, i) => Math.abs(x - b[i]) < 1e-9);
check(arrEq(parseTimings('[0.5, 0.9, 1.3]'), [0.5, 0.9, 1.3]), 'parseTimings bare JSON array');
check(arrEq(parseTimings('{"hits":[1.3,0.5,0.9]}'), [0.5, 0.9, 1.3]), 'parseTimings .hits sorted');
check(arrEq(parseTimings('{"onsets":[2,1]}'), [1, 2]), 'parseTimings .onsets alias');
check(arrEq(parseTimings('0.5 0.9\n1.3,2.0'), [0.5, 0.9, 1.3, 2.0]), 'parseTimings plain text');
check(arrEq(parseTimings('{"hits":[{"time":0.9},{"time":0.1}]}'), [0.1, 0.9]), 'parseTimings object entries');
check(arrEq(parseTimings(''), []), 'parseTimings empty');
check(arrEq(parseTimings('garbage'), []), 'parseTimings non-numeric');
const T = [1.0, 2.0, 3.0];
check(stepForTime(T, 0.0, 10) === 0, 'stepForTime before first hit = 0');
check(stepForTime(T, 1.0, 10) === 1, 'stepForTime at first hit = 1');
check(stepForTime(T, 2.5, 10) === 2, 'stepForTime mid = count elapsed');
check(stepForTime(T, 99, 10) === 3, 'stepForTime all hits elapsed');
check(stepForTime(T, 99, 2) === 1, 'stepForTime clamps to nRounds-1');
check(stepForTime([], 5, 10) === 0, 'stepForTime no timings = 0');
check(stepForTime(T, 5, 0) === 0, 'stepForTime no rounds = 0');

for (const file of process.argv.slice(3)) {
  if (!fs.existsSync(file)) { console.log(file, 'MISSING'); continue; }
  const env = JSON.parse(fs.readFileSync(file, 'utf8'));
  check(env.vizTrace === 2, 'vizTrace 2');
  const rounds = timelineRounds(env);
  const changed = changedCellIdsGlobal(env);

  let prevRN = -Infinity, anyFired = false, anyGrowth = false, maxFired = 0, labeledOK = true;
  // per-round invariants (cheap) over every round
  for (let i = 0; i < rounds.length; i++) {
    const r = rounds[i];
    check(r.roundNumber >= prevRN, 'rounds ordered'); prevRN = r.roundNumber;
    check(env.topologies[r.topo] !== undefined, 'round topo ref valid');
    const topo = env.topologies[r.topo].topology;
    const propIds = new Set(topo.propagators.map(p => p.id));
    const cellIds = new Set(topo.cells.map(c => c.id));
    for (const pid of r.propagatorsFired) check(propIds.has(pid), `fired prop ${pid} in round's own topo`);
    for (const d of (r.cellDiffs || [])) check(cellIds.has(d.cell ?? d.cellId), `diff cell in round's own topo`);
    maxFired = Math.max(maxFired, r.propagatorsFired.length);
    if (r.propagatorsFired.length) anyFired = true;
    if (i > 0 && r.topo !== rounds[i - 1].topo) anyGrowth = true;
  }
  // graph + both layouts: ONCE per distinct topology (layout is expensive)
  for (let ti = 0; ti < env.topologies.length; ti++) {
    const g = buildGraphFromTopo(env.topologies[ti], env.source, changed, false);
    for (const e of g.edges) check(g.byId.has(e.from) && g.byId.has(e.to), 'edge endpoints');
    for (const lay of [layoutLayered(g), layoutForce(g, null, 800, 600)])
      for (const n of g.nodes) { const p = lay.pos.get(n.key); check(p && isFinite(p.x) && isFinite(p.y), 'positioned ' + n.key); }
    const labeled = g.nodes.filter(n => n.kind === 'prop' && !/^p\d+$/.test(n.label)).length;
    const props = g.nodes.filter(n => n.kind === 'prop').length;
    if (props && labeled === 0) labeledOK = false;
  }
  check(anyFired, 'some round fires a propagator');
  check(rounds.length <= 1 || anyGrowth, 'network changes across timeline');

  console.log(`${file.split('/').pop()}: vizTrace${env.vizTrace} rounds=${rounds.length} ` +
              `topologies=${env.topologies.length} commands=${(env.commands||[]).length} ` +
              `maxFired/round=${maxFired} propLabelsFromSource=${labeledOK}`);
}
console.log(failures === 0 ? 'ALL CHECKS PASS' : failures + ' FAILURES');
process.exit(failures === 0 ? 0 : 1);
