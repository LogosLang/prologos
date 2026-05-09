#!/usr/bin/env node
//
// peer-handshake.mjs — Phase 6: bidirectional op:start-session handshake.
//
// Usage: node peer-handshake.mjs <port>
//
// Roles: this script is the CONNECTING peer (the Racket parent
// is the listening peer on `port`).
//
// Protocol (Phase 6 minimum):
//   1. Connect to 127.0.0.1:<port>
//   2. Send our op:start-session — version "0.1", locator
//      "tcp-testing-only:peer-node"
//   3. Read one line (Racket's op:start-session)
//   4. Decode via @endo/ocapn, verify it's also op:start-session
//   5. Print one-line JSON summary on stdout, exit 0
//
// JSON shape on stdout:
//   {"ok":true, "sent_label":"op:start-session", "recv_label":"...",
//    "recv_version":"0.1", "recv_locator":"tcp-testing-only:peer-racket"}

import '@endo/init';
import net from 'node:net';
import {
  encodeSyrup,
  decodeSyrup,
} from './node_modules/@endo/ocapn/src/syrup/js-representation.js';

const port = Number(process.argv[2]);
if (!Number.isInteger(port) || port < 1) {
  process.stderr.write(`peer-handshake: bad port ${process.argv[2]}\n`);
  process.exit(2);
}

const mkRec = (label, values) => ({
  [Symbol.toStringTag]: 'Record',
  label,
  values,
});

// Our op:start-session payload.
const ourStart = mkRec('op:start-session', [
  '0.1',
  'tcp-testing-only:peer-node',
]);
let ourBytes;
try {
  ourBytes = Buffer.from(encodeSyrup(ourStart));
} catch (err) {
  process.stdout.write(JSON.stringify({ ok: false, error: `encode: ${err.message}` }) + '\n');
  process.exit(1);
}

const sock = net.createConnection({ host: '127.0.0.1', port });
const chunks = [];

sock.on('connect', () => {
  sock.write(ourBytes);
  sock.write('\n');
});

sock.on('data', d => chunks.push(d));

sock.on('error', err => {
  process.stdout.write(JSON.stringify({ ok: false, error: `socket: ${err.message}` }) + '\n');
  process.exit(1);
});

sock.on('end', () => {
  const buf = Buffer.concat(chunks);
  // Strip trailing 0x0A.
  const sliced = buf[buf.length - 1] === 0x0a ? buf.subarray(0, buf.length - 1) : buf;
  const payload = new Uint8Array(sliced.length);
  payload.set(sliced);
  try {
    const value = decodeSyrup(payload);
    const label = value && value.label != null ? String(value.label) : null;
    const values = value && Array.isArray(value.values) ? value.values : [];
    const out = {
      ok: label === 'op:start-session',
      sent_label: 'op:start-session',
      recv_label: label,
      recv_version: typeof values[0] === 'string' ? values[0] : null,
      recv_locator: typeof values[1] === 'string' ? values[1]
                    : (values[1] && typeof values[1].toString === 'function')
                      ? String(values[1]) : null,
      raw_hex: Buffer.from(payload).toString('hex'),
    };
    process.stdout.write(JSON.stringify(out) + '\n');
    process.exit(out.ok ? 0 : 1);
  } catch (err) {
    process.stdout.write(JSON.stringify({
      ok: false,
      error: `decode: ${err.message}`,
      raw_hex: Buffer.from(payload).toString('hex'),
    }) + '\n');
    process.exit(1);
  }
});
