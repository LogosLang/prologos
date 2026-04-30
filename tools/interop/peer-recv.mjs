#!/usr/bin/env node
//
// peer-recv.mjs — Node side of Phase 5 Test A.
//
// Usage: node peer-recv.mjs <port>
//
// 1. TCP-connect to 127.0.0.1:<port>
// 2. Read until newline (Phase-3 framing convention from
//    racket-side tcp-testing.prologos: each CapTP frame is one
//    Syrup-encoded record terminated by '\n').
// 3. Strip the terminating '\n', decode the bytes via
//    @endo/ocapn's decodeSyrup.
// 4. Print a single-line JSON summary on stdout, then exit 0.
//
// Output JSON shape:
//   {"ok":true,  "label":"op:abort", "values":["..."], "raw_hex":"..."}
//   {"ok":false, "error":"...", "raw_hex":"..."}
//
// The Racket test (test-ocapn-live-interop.rkt) reads this
// stdout and asserts on the JSON.

import '@endo/init';
import net from 'node:net';
import { decodeSyrup } from './node_modules/@endo/ocapn/src/syrup/js-representation.js';

const port = Number(process.argv[2]);
if (!Number.isInteger(port) || port < 1) {
  process.stderr.write(`peer-recv: bad port ${process.argv[2]}\n`);
  process.exit(2);
}

const sock = net.createConnection({ host: '127.0.0.1', port });
const chunks = [];

sock.on('data', d => chunks.push(d));
sock.on('error', err => {
  process.stdout.write(JSON.stringify({ ok: false, error: String(err) }) + '\n');
  process.exit(1);
});
sock.on('end', () => {
  const buf = Buffer.concat(chunks);
  // Strip a single trailing 0x0A if present, then COPY into a
  // fresh ArrayBuffer-backed Uint8Array — @endo/ocapn's
  // BufferReader rejects views with a non-zero byteOffset.
  const sliced = buf[buf.length - 1] === 0x0a ? buf.subarray(0, buf.length - 1) : buf;
  const payload = new Uint8Array(sliced.length);
  payload.set(sliced);
  const hex = Buffer.from(payload).toString('hex');
  try {
    const value = decodeSyrup(payload);
    // value for our test inputs is a Record-shaped object:
    //   { [Symbol.toStringTag]: 'Record', label, values }
    // Coerce values to plain JSON-serialisable types.
    const out = {
      ok: true,
      label: value && value.label != null ? String(value.label) : null,
      values: value && Array.isArray(value.values)
        ? value.values.map(v => {
            if (typeof v === 'bigint') return { type: 'int', value: v.toString() };
            if (typeof v === 'string') return { type: 'string', value: v };
            if (typeof v === 'boolean') return { type: 'bool', value: v };
            return { type: 'other', value: String(v) };
          })
        : [],
      raw_hex: hex,
    };
    process.stdout.write(JSON.stringify(out) + '\n');
    process.exit(0);
  } catch (err) {
    process.stdout.write(JSON.stringify({
      ok: false,
      error: String(err),
      raw_hex: hex,
    }) + '\n');
    process.exit(1);
  }
});
