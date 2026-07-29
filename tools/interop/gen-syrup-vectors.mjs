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

// A Syrup bytestring. @endo/ocapn's AnyCodec dispatches bytestrings on
// `value instanceof ArrayBuffer` specifically — a Uint8Array falls through
// to the dictionary branch and encodes as `{}`. Latin-1 in, because that is
// Prologos's byte model for these Strings (see THE BYTE MODEL in
// syrup-wire.prologos): one code point per byte, both sides.
const mkBytes = (latin1) => {
  const buf = Buffer.from(latin1, 'latin1');
  const ab = new ArrayBuffer(buf.length);
  new Uint8Array(ab).set(buf);
  return ab;
};

/**
 * @param {string} label
 * @param {unknown} value
 * @param {string} prologosSexp
 */
const addCase = (cases, label, value, prologosSexp) => {
  cases.push({ label, value, prologosSexp });
};

const cases = [];

// ---- Forms deliberately absent, and why -------------------------
//
// null    — @endo/ocapn doesn't represent the Syrup `n` atom in JS
//           values; it's part of the wire format but the JS encoder
//           rejects it. Prologos has `syrup-null`; we test it
//           separately in test-ocapn-syrup-wire.rkt without the JS
//           check.
// float   — `D` + big-endian double. The JS encoder emits it fine
//           (`encodeSyrup(1.5)` → `443ff8000000000000`), but Prologos's
//           `SyrupValue` has no float constructor, so the third column
//           is unwritable. Gaps doc §1.10 finding 3.
// set     — `#…$`. Same reason: no `syrup-set` constructor.
//
// Non-ASCII payloads are absent for a DIFFERENT reason: the Racket
// harness (test-ocapn-syrup-cross-impl.rkt) hex-encodes via
// `string->bytes/utf-8` and decodes via `bytes->string/utf-8`, while
// this codec's byte model is Latin-1 (one byte per code point). Those
// agree on ASCII only, so a non-ASCII vector would fail on the harness's
// re-measurement regardless of whether the encoder is right. Fixing the
// harness to latin-1 is a prerequisite for covering the `str::length` vs
// `str::bytes-length` divergence here.

// ---- Atoms ------------------------------------------------------

addCase(cases, 'bool true',  true,  '(syrup-bool true)');
addCase(cases, 'bool false', false, '(syrup-bool false)');

addCase(cases, 'int 0',    0n, '(syrup-int 0)');
addCase(cases, 'int 1',    1n, '(syrup-int 1)');
addCase(cases, 'int 42',   42n, '(syrup-int 42)');
addCase(cases, 'int 1000', 1000n, '(syrup-int 1000)');
addCase(cases, 'int -1',   -1n, '(syrup-int (int-neg 1))');
addCase(cases, 'int -7',   -7n, '(syrup-int (int-neg 7))');
addCase(cases, 'int -100', -100n, '(syrup-int (int-neg 100))');
// Past a fixnum, and past 64 bits — the digit prefix is produced by
// `number->string` and consumed by `read-digits`, both of which have to
// stay exact.
addCase(cases, 'int 2^32', 4294967296n, '(syrup-int 4294967296)');
addCase(cases, 'int -2^32', -4294967296n, '(syrup-int (int-neg 4294967296))');
addCase(cases, 'int 2^64-1', 18446744073709551615n,
  '(syrup-int 18446744073709551615)');

addCase(cases, 'string empty',     '',          '(syrup-string "")');
addCase(cases, 'string hi',        'hi',        '(syrup-string "hi")');
addCase(cases, 'string hello',     'hello',     '(syrup-string "hello")');
addCase(cases, 'string with-dash', 'phase-3',   '(syrup-string "phase-3")');
// Content that looks like syrup framing. A codec that scans for the
// marker instead of trusting the length prefix reads these wrong.
addCase(cases, 'string digits-only', '123',     '(syrup-string "123")');
addCase(cases, 'string looks-framed', '3"abc',  '(syrup-string "3\\"abc")');

addCase(cases, 'symbol foo',  SyrupSelectorFor('foo'),  '(syrup-symbol "foo")');
addCase(cases, 'symbol bar',  SyrupSelectorFor('bar'),  '(syrup-symbol "bar")');
addCase(cases, 'symbol op:abort', SyrupSelectorFor('op:abort'),
  '(syrup-symbol "op:abort")');
addCase(cases, 'symbol empty', SyrupSelectorFor(''), '(syrup-symbol "")');

// ---- Bytestrings ------------------------------------------------
//
// Wire form `<len>:<bytes>`, a DIFFERENT marker from a string. The
// 32-byte case is the shape that actually matters: an Ed25519 public
// key or signature half, where a length prefix measured as anything
// but "one byte per code point" desyncs the whole frame.

addCase(cases, 'bytes empty', mkBytes(''), '(syrup-bytes "")');
addCase(cases, 'bytes abc',   mkBytes('abc'), '(syrup-bytes "abc")');
addCase(cases, 'bytes 32 key-sized',
  mkBytes('0123456789abcdef0123456789abcdef'),
  '(syrup-bytes "0123456789abcdef0123456789abcdef")');
addCase(cases, 'bytes with delimiters',
  mkBytes('<[{:}]>'),
  '(syrup-bytes "<[{:}]>")');

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
addCase(cases, 'list nested',
  [[1n], []],
  '(syrup-list (cons (syrup-list (cons (syrup-int 1) nil)) (cons (syrup-list nil) nil)))');
addCase(cases, 'list mixed',
  ['a', 1n, true, SyrupSelectorFor('s')],
  '(syrup-list (cons (syrup-string "a") (cons (syrup-int 1) (cons (syrup-bool true) (cons (syrup-symbol "s") nil)))))');

// ---- Dictionaries -----------------------------------------------
//
// Syrup canonicalises a dict by BYTEWISE-SORTED ENCODED KEY, and both
// implementations sort on write. Prologos represents a dict as a FLAT
// alternating [k1 v1 k2 v2 …] list with no inherent order, so every
// sexp below is deliberately written in the WRONG order: if Prologos
// stops sorting, these are the cases that catch it.
//
// `length-before-lexicographic` is the one that separates sorting on the
// ENCODED key from sorting on the key text: encoded, `1"b` precedes
// `2"aa` (the digit decides), while as text "aa" precedes "b".

addCase(cases, 'dict empty',
  {},
  '(syrup-dict nil)');
addCase(cases, 'dict host/port hints',
  { host: '127.0.0.1', port: '22045' },
  '(syrup-dict (cons (syrup-string "port") (cons (syrup-string "22045") (cons (syrup-string "host") (cons (syrup-string "127.0.0.1") nil)))))');
addCase(cases, 'dict length-before-lexicographic',
  { aa: 1n, b: 2n },
  '(syrup-dict (cons (syrup-string "aa") (cons (syrup-int 1) (cons (syrup-string "b") (cons (syrup-int 2) nil)))))');
addCase(cases, 'dict symbol keys',
  { [SyrupSelectorFor('host')]: 'h', [SyrupSelectorFor('port')]: 'p' },
  '(syrup-dict (cons (syrup-symbol "port") (cons (syrup-string "p") (cons (syrup-symbol "host") (cons (syrup-string "h") nil)))))');
addCase(cases, 'dict nested value',
  { k: { z: 1n } },
  '(syrup-dict (cons (syrup-string "k") (cons (syrup-dict (cons (syrup-string "z") (cons (syrup-int 1) nil))) nil)))');

// ---- Records ----------------------------------------------------
//
// A Prologos `syrup-tagged label payload` SPLICES a `syrup-list`
// payload as the argument sequence and treats `syrup-null` as the
// empty one, so all three arities below are expressible.

addCase(cases, 'record op:abort hello',
  mkRec('op:abort', ['hello']),
  '(syrup-tagged "op:abort" (syrup-string "hello"))');
addCase(cases, 'record op:gc-answer 3',
  mkRec('op:gc-answer', [3n]),
  '(syrup-tagged "op:gc-answer" (syrup-int 3))');
addCase(cases, 'record desc:export 5',
  mkRec('desc:export', [5n]),
  '(syrup-tagged "desc:export" (syrup-int 5))');
addCase(cases, 'record zero-arg',
  mkRec('op:foo', []),
  '(syrup-tagged "op:foo" syrup-null)');
addCase(cases, 'record two-arg',
  mkRec('desc:handoff', [1n, 'x']),
  '(syrup-tagged "desc:handoff" (syrup-list (cons (syrup-int 1) (cons (syrup-string "x") nil))))');
addCase(cases, 'record bytes-arg',
  mkRec('desc:sig', [mkBytes('xyz')]),
  '(syrup-tagged "desc:sig" (syrup-bytes "xyz"))');
// The real four-field op:deliver, args in the LIST slot the OCapN wire
// form requires, plus a nested record and a bool.
addCase(cases, 'record op:deliver four-arg',
  mkRec('op:deliver', [
    mkRec('desc:export', [0n]),
    ['ping'],
    mkRec('desc:answer', [7n]),
    false,
  ]),
  '(syrup-tagged "op:deliver" (syrup-list (cons (syrup-tagged "desc:export" (syrup-int 0)) (cons (syrup-list (cons (syrup-string "ping") nil)) (cons (syrup-tagged "desc:answer" (syrup-int 7)) (cons (syrup-bool false) nil))))))');
// The location record — a record whose last argument is a hints DICT
// with STRING keys. This is the exact shape `handshake::ocapn-peer-bytes`
// has to produce for a signed op:start-session, and the byte string here
// is the canonical one (gaps doc §1.10 finding 1).
addCase(cases, 'record ocapn-peer with hints',
  mkRec('ocapn-peer', [
    SyrupSelectorFor('tcp-testing-only'),
    'abc',
    { host: '127.0.0.1', port: '22045' },
  ]),
  '(syrup-tagged "ocapn-peer" (syrup-list (cons (syrup-symbol "tcp-testing-only") (cons (syrup-string "abc") (cons (syrup-dict (cons (syrup-string "host") (cons (syrup-string "127.0.0.1") (cons (syrup-string "port") (cons (syrup-string "22045") nil))))) nil)))))');

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
