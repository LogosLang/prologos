/**
 * mini-prologos — a tiny stratified bottom-up Datalog engine that speaks a
 * subset of Prologos WS-mode surface syntax.
 *
 * Origin: built as the live in-browser engine for the interactive explainer
 * "First, Choose Your Lattice — Prologos, Interactive" (an architect-oriented
 * tour of the lattice/CALM foundations). Packaged here as a self-contained
 * teaching/demo artifact. It is a faithful *miniature* of the evaluation
 * story — monotone joins to a Tarski fixpoint per stratum, negation only at
 * stratum boundaries — NOT the Hyperlattice Compiler, and it deliberately
 * knows nothing about types, traits, tabling internals, or the propagator
 * substrate.
 *
 * Supported subset:
 *   ns <name>                        -- accepted and ignored
 *   defr <name> [?a +b -c]          -- relation declaration (modes ignored)
 *     || "v" "v" ...                 -- fact rows (quoted strings, arity-grouped)
 *     &> (goal) (goal) ...           -- rule clause; goals conjoined
 *   goals: (rel a b) | (= a b) | (not (rel a b))
 *   args : "quoted"  = constant · bare-symbol = variable
 *   query: solve (rel "c" x)   — via parseQuery
 *
 * Semantics:
 *   - Naive/round-based bottom-up evaluation per stratum (rounds are the
 *     BSP-flavored trace), derived tuples accumulate in set-union cells.
 *   - Stratification by negation; cyclic negation is refused with an error
 *     (that program wants the well-founded solver, which this mini is not).
 *   - `not` goals require ground arguments at evaluation time; they are
 *     deferred behind positive goals within a clause where possible.
 *   - evalProgram(rels, {shuffle}) accepts a reordering function so callers
 *     can demonstrate the CALM property: any firing order, same fixpoint.
 */

/* ---------------- tokenizer ---------------- */

export function tokenize(src) {
  const toks = [];
  src = src.replace(/;;[^\n]*/g, '');
  const re = /"([^"]*)"|\|\||&>|[()\[\]]|[^\s()\[\]"]+/g;
  let m;
  while ((m = re.exec(src))) {
    if (m[1] !== undefined) toks.push({ t: 'str', v: m[1] });
    else toks.push({ t: 'sym', v: m[0] });
  }
  return toks;
}

/* ---------------- parser ---------------- */

export function parseProgram(src) {
  const toks = tokenize(src);
  let i = 0;
  const peek = () => toks[i], next = () => toks[i++];
  const rels = {};   // name -> {arity, facts:[[c,...]], rules:[{head:[args], goals:[...]}]}
  function need(cond, msg) { if (!cond) throw new Error(msg); }
  function ensureRel(name, arity) {
    if (!rels[name]) rels[name] = { arity, facts: [], rules: [] };
    else need(rels[name].arity === arity, `arity mismatch for ${name}: ${rels[name].arity} vs ${arity}`);
    return rels[name];
  }
  function parseGoal() { // at '('
    need(peek() && peek().v === '(', 'expected ( to open a goal');
    next();
    const head = next();
    need(head, 'unterminated goal');
    if (head.v === 'not') {
      const inner = parseGoal();
      need(peek() && peek().v === ')', 'expected ) after not-goal');
      next();
      need(inner.kind === 'call', 'not(...) must wrap a relation goal');
      return { kind: 'not', goal: inner };
    }
    if (head.v === '=') {
      const a = parseArg(), b = parseArg();
      need(peek() && peek().v === ')', 'expected ) after (= a b)');
      next();
      return { kind: 'unify', a, b };
    }
    need(head.t === 'sym', 'goal must start with a relation name');
    const args = [];
    while (peek() && peek().v !== ')') args.push(parseArg());
    need(peek(), 'unterminated goal ' + head.v);
    next(); // )
    return { kind: 'call', rel: head.v, args };
  }
  function parseArg() {
    const tk = next();
    need(tk, 'unexpected end of input in goal');
    if (tk.t === 'str') return { c: tk.v };
    need(!'()[]'.includes(tk.v), 'unexpected ' + tk.v + ' in goal arguments');
    return { v: tk.v };
  }
  while (i < toks.length) {
    const tk = next();
    if (tk.v === 'ns') { next(); continue; }
    if (tk.v === 'solve') { // top-level solve in a program file: parse & ignore
      if (peek() && peek().v === '(') parseGoal();
      continue;
    }
    if (tk.v === 'defr') {
      const nameTok = next();
      need(nameTok && nameTok.t === 'sym', 'defr needs a name');
      const name = nameTok.v;
      need(peek() && peek().v === '[', `defr ${name}: expected [params]`);
      next();
      const params = [];
      while (peek() && peek().v !== ']') {
        const p = next();
        need(p.t === 'sym', `defr ${name}: bad param`);
        params.push(p.v);
      }
      need(peek(), `defr ${name}: unterminated [params]`);
      next(); // ]
      const rel = ensureRel(name, params.length);
      while (peek() && (peek().v === '||' || peek().v === '&>')) {
        const sig = next().v;
        if (sig === '||') {
          while (peek() && peek().t === 'str') {
            const row = [];
            for (let k = 0; k < params.length; k++) {
              const c = next();
              need(c && c.t === 'str', `fact row for ${name}: expected ${params.length} quoted values per row`);
              row.push(c.v);
            }
            rel.facts.push(row);
          }
        } else { // &>
          const goals = [];
          while (peek() && peek().v === '(') goals.push(parseGoal());
          need(goals.length > 0, `&> clause of ${name} has no goals`);
          rel.rules.push({ head: params.map(p => ({ v: p.replace(/^[?+\-]/, '') })), goals });
        }
      }
      continue;
    }
    throw new Error(`unexpected token “${tk.v}” at top level (this engine speaks the defr/||/&>/solve subset)`);
  }
  // reference check
  for (const [name, rel] of Object.entries(rels))
    for (const rule of rel.rules)
      for (const g of rule.goals) {
        const call = g.kind === 'not' ? g.goal : g;
        if (call.kind === 'call') {
          if (!rels[call.rel]) throw new Error(`unknown relation (${call.rel} …) in a clause of ${name}`);
          if (rels[call.rel].arity !== call.args.length)
            throw new Error(`(${call.rel} …) called with ${call.args.length} args; declared arity ${rels[call.rel].arity}`);
        }
      }
  return rels;
}

export function parseQuery(src, rels) {
  const m = src.match(/solve\s*(\(.*\))\s*$/s) || src.match(/^\s*(\(.*\))\s*$/s);
  if (!m) throw new Error('query should look like: solve (needs "CS401" req)');
  const toks = tokenize(m[1]);
  let i = 0;
  if (toks[i].v !== '(') throw new Error('query: expected (goal …)');
  i++;
  const name = toks[i++].v;
  if (!rels[name]) throw new Error(`query: unknown relation ${name}`);
  const args = [];
  while (i < toks.length && toks[i].v !== ')') {
    const tk = toks[i++];
    args.push(tk.t === 'str' ? { c: tk.v } : { v: tk.v });
  }
  if (rels[name].arity !== args.length) throw new Error(`query: ${name} has arity ${rels[name].arity}`);
  return { rel: name, args };
}

/* ---------------- stratification ---------------- */

export function stratify(rels) {
  const names = Object.keys(rels);
  const S = {};
  names.forEach(n => S[n] = 0);
  const maxS = names.length + 1;
  for (let pass = 0; pass <= maxS + 1; pass++) {
    let changed = false;
    for (const [h, rel] of Object.entries(rels))
      for (const rule of rel.rules)
        for (const g of rule.goals) {
          if (g.kind === 'call' && S[h] < S[g.rel]) { S[h] = S[g.rel]; changed = true; }
          if (g.kind === 'not' && S[h] < S[g.goal.rel] + 1) { S[h] = S[g.goal.rel] + 1; changed = true; }
        }
    if (!changed) break;
    if (pass === maxS + 1 || Math.max(...Object.values(S)) > maxS)
      throw new Error('non-stratifiable: cyclic negation — the stratified engine refuses this program. It wants a well-founded solver (solver … :semantics well-founded).');
  }
  return S;
}

/* ---------------- evaluation ---------------- */

export const keyOf = t => JSON.stringify(t);

function unifyGoal(goal, tuple, env) {
  const e = { ...env };
  for (let k = 0; k < goal.args.length; k++) {
    const a = goal.args[k];
    if (a.c !== undefined) { if (tuple[k] !== a.c) return null; }
    else {
      if (e[a.v] !== undefined) { if (e[a.v] !== tuple[k]) return null; }
      else e[a.v] = tuple[k];
    }
  }
  return e;
}
const argVal = (a, env) => a.c !== undefined ? a.c : env[a.v];

/**
 * Evaluate a parsed program to its stratified fixpoint.
 * opts.shuffle: optional (array => array) reordering applied to rule sets and
 *               tuple iteration each round — for CALM order-independence demos.
 * Returns {DB, trace, S, fires, strata}:
 *   DB     : name -> Map(key -> tuple)
 *   trace  : [{type:'gate',stratum} | {type:'round',stratum,round,adds,factsOnly?}]
 *   S      : name -> stratum index
 *   fires  : total rule-fire count (varies with order; the fixpoint does not)
 */
export function evalProgram(rels, opts = {}) {
  const S = stratify(rels);
  const strata = Object.keys(rels).length ? Math.max(...Object.values(S)) : 0;
  const DB = {};
  const trace = [];
  let fires = 0;
  for (const [n, rel] of Object.entries(rels)) {
    DB[n] = new Map();
    rel.facts.forEach(f => DB[n].set(keyOf(f), f));
  }
  const ord = opts.shuffle || (a => a);
  function solveGoals(goals, env, out) {
    if (!goals.length) { out.push(env); return; }
    const [g, ...rest] = goals;
    if (g.kind === 'unify') {
      const av = argVal(g.a, env), bv = argVal(g.b, env);
      if (av !== undefined && bv !== undefined) { if (av === bv) solveGoals(rest, env, out); }
      else if (av !== undefined && g.b.v) solveGoals(rest, { ...env, [g.b.v]: av }, out);
      else if (bv !== undefined && g.a.v) solveGoals(rest, { ...env, [g.a.v]: bv }, out);
      else throw new Error('(= a b): both sides unbound');
      return;
    }
    if (g.kind === 'not') {
      const call = g.goal;
      if (call.args.some(a => a.v !== undefined && env[a.v] === undefined)) {
        // defer behind remaining positive goals if any exist
        if (rest.some(r => r.kind !== 'not')) { solveGoals([...rest, g], env, out); return; }
        throw new Error(`(not (${call.rel} …)) reached with unbound variables — ground them with a positive goal first`);
      }
      const tuple = call.args.map(a => argVal(a, env));
      if (!DB[call.rel].has(keyOf(tuple))) solveGoals(rest, env, out);
      return;
    }
    for (const tuple of ord([...DB[g.rel].values()])) {
      const e2 = unifyGoal(g, tuple, env);
      if (e2) solveGoals(rest, e2, out);
    }
  }
  for (let s = 0; s <= strata; s++) {
    if (s > 0) trace.push({ type: 'gate', stratum: s });
    const factAdds = {};
    for (const [n, rel] of Object.entries(rels))
      if (S[n] === s && rel.facts.length) factAdds[n] = rel.facts;
    if (Object.keys(factAdds).length)
      trace.push({ type: 'round', stratum: s, round: 0, adds: factAdds, factsOnly: true });
    const ruleset = [];
    for (const [h, rel] of Object.entries(rels))
      if (S[h] === s) rel.rules.forEach(r => ruleset.push({ head: h, rule: r }));
    let round = 0;
    while (true) {
      round++;
      const adds = {};
      let any = false;
      for (const { head, rule } of ord(ruleset.slice())) {
        fires++;
        const envs = [];
        solveGoals(rule.goals, {}, envs);
        for (const env of envs) {
          const tuple = rule.head.map(a => {
            const v = argVal(a, env);
            if (v === undefined) throw new Error(`unbound variable ${a.v} in the head of a ${head} clause`);
            return v;
          });
          const k = keyOf(tuple);
          if (!DB[head].has(k)) {
            DB[head].set(k, tuple);
            (adds[head] = adds[head] || []).push(tuple);
            any = true;
          }
        }
      }
      if (ruleset.length && (any || round === 1)) trace.push({ type: 'round', stratum: s, round, adds });
      if (!any) break;
      if (round > 500) throw new Error('runaway (500 rounds) — is the fact universe infinite?');
    }
  }
  return { DB, trace, S, fires, strata };
}

/** Match a parsed query against the fixpoint DB → array of binding envs. */
export function answers(q, DB) {
  const out = [];
  for (const tuple of DB[q.rel].values()) {
    const e = unifyGoal(q, tuple, {});
    if (e) out.push(e);
  }
  return out;
}

/** Canonical signature of a DB — equal iff the fixpoints are equal. */
export function dbSignature(DB) {
  return Object.entries(DB)
    .map(([n, m]) => n + ':' + [...m.keys()].sort().join('|'))
    .sort().join('§');
}

/** Fisher–Yates, non-mutating — a ready-made opts.shuffle for CALM demos. */
export function shuffled(a) {
  a = a.slice();
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

/** Convenience: parse + eval + query in one call. */
export function solve(programSrc, querySrc, opts = {}) {
  const rels = parseProgram(programSrc);
  const q = parseQuery(querySrc, rels);
  const res = evalProgram(rels, opts);
  return { answers: answers(q, res.DB), ...res, query: q };
}
