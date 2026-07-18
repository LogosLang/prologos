#!/usr/bin/env node
/**
 * mini-prologos CLI
 *
 *   node cli.mjs <file.prologos> 'solve (rel "c" x)' [--trace] [--shuffle N]
 *
 *   --trace      print the per-stratum BSP round log
 *   --shuffle N  re-run N times with randomized firing orders and verify the
 *                fixpoint is identical every time (the CALM check)
 */
import { readFileSync } from 'node:fs';
import { parseProgram, parseQuery, evalProgram, answers, dbSignature, shuffled } from './mini-prologos.mjs';

const args = process.argv.slice(2);
const flags = { trace: false, shuffle: 0 };
const pos = [];
for (let i = 0; i < args.length; i++) {
  if (args[i] === '--trace') flags.trace = true;
  else if (args[i] === '--shuffle') flags.shuffle = +args[++i] || 20;
  else pos.push(args[i]);
}
if (pos.length < 2) {
  console.error('usage: node cli.mjs <file.prologos> \'solve (rel "c" x)\' [--trace] [--shuffle N]');
  process.exit(2);
}

const src = readFileSync(pos[0], 'utf8');
try {
  const rels = parseProgram(src);
  const q = parseQuery(pos[1], rels);
  const res = evalProgram(rels, {});

  const vars = q.args.filter(a => a.v !== undefined).map(a => a.v);
  const ans = answers(q, res.DB);
  if (!ans.length) console.log('nil');
  else if (!vars.length) console.log(`true  ;; goal holds (${ans.length} matching tuple${ans.length > 1 ? 's' : ''})`);
  else for (const e of ans) console.log('{' + vars.map(v => `:${v} ${JSON.stringify(e[v])}`).join(' ') + '}');

  if (flags.trace) {
    console.log('\n;; --- trace ---');
    for (const ev of res.trace) {
      if (ev.type === 'gate') { console.log(`;; ⟡ S${ev.stratum - 1} quiesced (Tarski fixpoint) — gate opens → S${ev.stratum}`); continue; }
      const parts = Object.entries(ev.adds).map(([r, ts]) => `${r} +${ts.length}`);
      console.log(`;; S${ev.stratum} ${ev.factsOnly ? 'ground facts' : 'round ' + ev.round}: ${parts.join(' · ') || '(no new tuples)'}`);
    }
    console.log(`;; quiescent — ${res.fires} rule-fires, ${Object.values(res.DB).reduce((n, m) => n + m.size, 0)} tuples, ${res.strata + 1} strat${res.strata ? 'a' : 'um'}`);
  }

  if (flags.shuffle) {
    const sig0 = dbSignature(res.DB);
    let minF = Infinity, maxF = 0, ok = true;
    for (let t = 0; t < flags.shuffle; t++) {
      const r = evalProgram(rels, { shuffle: shuffled });
      minF = Math.min(minF, r.fires); maxF = Math.max(maxF, r.fires);
      if (dbSignature(r.DB) !== sig0) ok = false;
    }
    console.log(`\n;; CALM check: ${flags.shuffle} shuffled schedules, fire counts ${minF}–${maxF}, fixpoint ${ok ? 'IDENTICAL every run ✓' : 'DIVERGED ✗ (engine bug!)'}`);
    process.exit(ok ? 0 : 1);
  }
} catch (e) {
  console.error('error: ' + e.message);
  process.exit(1);
}
