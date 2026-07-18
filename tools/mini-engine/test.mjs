/** Tests for mini-prologos. Run: node test.mjs */
import assert from 'node:assert/strict';
import { parseProgram, parseQuery, evalProgram, answers, dbSignature, shuffled, solve } from './mini-prologos.mjs';

let n = 0;
const test = (name, fn) => { fn(); n++; console.log('ok - ' + name); };

const PREREQS = `
ns demo::prereqs
defr prereq [?course ?requires]
  || "CS201" "CS101"
     "CS301" "CS201"
     "CS301" "MA301"
     "CS401" "CS301"
     "MA301" "MA101"
defr needs [?course ?req]
  &> (prereq course req)
  &> (prereq course mid) (needs mid req)
`;

const ROUTING = `
defr edge [?from ?to]
  || "a" "b"
     "b" "c"
     "c" "d"
     "d" "e"
defr blocked [?node]
  || "c"
defr reachable [?from ?to]
  &> (edge from to) (not (blocked to))
  &> (edge from mid) (not (blocked mid)) (reachable mid to)
`;

test('transitive closure: all prerequisites of CS401', () => {
  const { answers: ans } = solve(PREREQS, 'solve (needs "CS401" req)');
  const got = ans.map(e => e.req).sort();
  assert.deepEqual(got, ['CS101', 'CS201', 'CS301', 'MA101', 'MA301']);
});

test('ground query returns truth, not bindings', () => {
  const { answers: ans } = solve(PREREQS, 'solve (needs "CS401" "MA101")');
  assert.equal(ans.length, 1);
});

test('no-answer query yields nil (empty)', () => {
  const { answers: ans } = solve(PREREQS, 'solve (needs "CS101" req)');
  assert.equal(ans.length, 0);
});

test('stratified negation: blocked node cuts reachability', () => {
  const { answers: ans, strata } = solve(ROUTING, 'solve (reachable "a" dest)');
  assert.deepEqual(ans.map(e => e.dest).sort(), ['b']);
  assert.equal(strata, 1); // edge/blocked in S0, reachable in S1
});

test('removing the blocked fact restores the path', () => {
  const src = ROUTING.replace('|| "c"', '|| "zzz"');
  const { answers: ans } = solve(src, 'solve (reachable "a" dest)');
  assert.deepEqual(ans.map(e => e.dest).sort(), ['b', 'c', 'd', 'e']);
});

test('gate appears in the trace before the negation stratum', () => {
  const rels = parseProgram(ROUTING);
  const { trace } = evalProgram(rels);
  const gate = trace.findIndex(ev => ev.type === 'gate');
  assert.ok(gate > 0, 'expected an S0→S1 gate event');
  assert.ok(trace.slice(0, gate).every(ev => ev.stratum === 0));
});

test('cyclic negation is refused (points at well-founded semantics)', () => {
  const src = ROUTING + '\ndefr win [?x]\n  &> (edge x y) (not (win y))\n';
  assert.throws(() => solve(src, 'solve (win x)'), /non-stratifiable/);
});

test('CALM: 25 shuffled schedules reach the identical fixpoint', () => {
  const rels = parseProgram(PREREQS);
  const sig0 = dbSignature(evalProgram(rels).DB);
  const fireCounts = new Set();
  for (let t = 0; t < 25; t++) {
    const r = evalProgram(rels, { shuffle: shuffled });
    fireCounts.add(r.fires);
    assert.equal(dbSignature(r.DB), sig0, 'fixpoint diverged under shuffle');
  }
  // not asserted (schedules *may* coincide), but typically >1 distinct count:
  console.log(`  # fire-count spread across schedules: {${[...fireCounts].sort((a, b) => a - b).join(', ')}}`);
});

test('unification goal (= x y) binds and filters', () => {
  const src = 'defr pairish [?x ?y]\n  || "a" "a"\n     "a" "b"\ndefr same [?x]\n  &> (pairish x y) (= x y)\n';
  const { answers: ans } = solve(src, 'solve (same v)');
  assert.deepEqual(ans.map(e => e.v), ['a']);
});

test('parse errors are informative', () => {
  assert.throws(() => parseProgram('defr broken [?x ?y]\n  || "a"'), /expected 2 quoted values per row/);
  assert.throws(() => parseProgram('defr r [?x]\n  &> (nosuch x)'), /unknown relation/);
  const rels = parseProgram('defr r [?x]\n  || "a"');
  assert.throws(() => parseQuery('solve (r "a" "b")', rels), /arity/);
});

console.log(`\n${n} tests passed`);
