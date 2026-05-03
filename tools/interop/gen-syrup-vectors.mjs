#!/usr/bin/env node
//
// gen-syrup-vectors.mjs — Phase 4 of OCapN interop.
//
// Emits a deterministic, hand-curated set of canonical Syrup
// wire-byte vectors using `@endo/ocapn`'s reference encoder.
// Each line of the output file has three tab-separated columns:
//
//   <label>          short human-readable description
//   <hex-bytes>      lowercase hex, no spaces — what the JS encoder produced
//   <prologos-sexp>  sexp form of the SyrupValue, parseable by Prologos
//
// The Racket-side test (tests/test-ocapn-syrup-cross-impl.rkt)
// reads this file, parses the sexp through the prologos test
// fixture, encodes it via Prologos's syrup-wire::encode, and
// asserts byte-equality with the hex.
//
// Output: stdout (caller redirects to fixtures/syrup-cross-impl.txt).

import '@endo/init';
import {
  encodeSyrup,
  SyrupSelectorFor,
} from './node_modules/@endo/ocapn/src/syrup/js-representation.js';

// Records in @endo/ocapn's JS representation are plain objects with
// Symbol.toStringTag === 'Record', plus a `label` symbol-or-string
// and a `values` array.
const mkRec = (label, values) => ({
  [Symbol.toStringTag]: 'Record',
  label,
  values,
});

/**
 * @param {string} label
 * @param {unknown} value
 * @param {string} prologosSexp
 */
const addCase = (cases, label, value, prologosSexp) => {
  cases.push({ label, value, prologosSexp });
};

const cases = [];

// ---- Atoms ------------------------------------------------------
// (null intentionally omitted — @endo/ocapn doesn't represent the
// Syrup `n` atom in JS values; it's part of the wire format but
// the JS encoder rejects it. Prologos has `syrup-null`; we test it
// separately in test-ocapn-syrup-wire.rkt without the JS check.)

addCase(cases, 'bool true',  true,  '(syrup-bool true)');
addCase(cases, 'bool false', false, '(syrup-bool false)');

addCase(cases, 'int 0',    0n, '(syrup-int 0)');
addCase(cases, 'int 1',    1n, '(syrup-int 1)');
addCase(cases, 'int 42',   42n, '(syrup-int 42)');
addCase(cases, 'int 1000', 1000n, '(syrup-int 1000)');
addCase(cases, 'int -1',   -1n, '(syrup-int (int-neg 1))');
addCase(cases, 'int -7',   -7n, '(syrup-int (int-neg 7))');
addCase(cases, 'int -100', -100n, '(syrup-int (int-neg 100))');

addCase(cases, 'string empty',     '',          '(syrup-string "")');
addCase(cases, 'string hi',        'hi',        '(syrup-string "hi")');
addCase(cases, 'string hello',     'hello',     '(syrup-string "hello")');
addCase(cases, 'string with-dash', 'phase-3',   '(syrup-string "phase-3")');

addCase(cases, 'symbol foo',  SyrupSelectorFor('foo'),  '(syrup-symbol "foo")');
addCase(cases, 'symbol bar',  SyrupSelectorFor('bar'),  '(syrup-symbol "bar")');
addCase(cases, 'symbol op:abort', SyrupSelectorFor('op:abort'),
  '(syrup-symbol "op:abort")');

// ---- Lists ------------------------------------------------------

addCase(cases, 'list empty',
  [],
  '(syrup-list nil)');
addCase(cases, 'list bools',
  [true, false],
  '(syrup-list (cons (syrup-bool true) (cons (syrup-bool false) nil)))');
addCase(cases, 'list ints',
  [1n, 2n, 3n],
  '(syrup-list (cons (syrup-int 1) (cons (syrup-int 2) (cons (syrup-int 3) nil))))');

// ---- Records (Prologos's syrup-tagged maps to a 2-elem record) -

addCase(cases, 'record op:abort hello',
  mkRec('op:abort', ['hello']),
  '(syrup-tagged "op:abort" (syrup-string "hello"))');
addCase(cases, 'record op:gc-answer 3',
  mkRec('op:gc-answer', [3n]),
  '(syrup-tagged "op:gc-answer" (syrup-int 3))');
addCase(cases, 'record desc:export 5',
  mkRec('desc:export', [5n]),
  '(syrup-tagged "desc:export" (syrup-int 5))');

// ---- Output -----------------------------------------------------

let stderr = 0;
for (const { label, value, prologosSexp } of cases) {
  try {
    const bytes = encodeSyrup(value);
    const hex = Buffer.from(bytes).toString('hex');
    process.stdout.write(`${label}\t${hex}\t${prologosSexp}\n`);
  } catch (e) {
    process.stderr.write(`SKIP\t${label}\t${e.message}\n`);
    stderr += 1;
  }
}
if (stderr > 0) {
  process.stderr.write(`gen-syrup-vectors: ${stderr} cases failed\n`);
  process.exit(1);
}
