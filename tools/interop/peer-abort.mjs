#!/usr/bin/env node
//
// peer-abort.mjs — Phase 10: bidirectional graceful abort.
//
// Usage: node peer-abort.mjs <port>
//
// Both peers send op:abort and read each other's. Verifies clean
// shutdown: no data lost, both sides exit cleanly, the abort
// reason from the other peer is captured.
//
// Protocol:
//   1. Connect.
//   2. Send op:start-session.
//   3. Send op:abort reason="goodbye-from-node".
//   4. Read frames until receiving op:abort (or EOF).
//   5. Print JSON summary, exit 0 if abort seen, 1 otherwise.
//
// JSON summary:
//   {
//     "ok": true,
//     "saw_session_locator": "tcp-testing-only:peer-racket",
//     "saw_abort_reason": "goodbye-from-racket"
//   }

import '@endo/init';
import net from 'node:net';
import {
  encodeSyrup,
  decodeSyrup,
} from './node_modules/@endo/ocapn/src/syrup/js-representation.js';

const port = Number(process.argv[2]);
if (!Number.isInteger(port) || port < 1) {
  process.stderr.write(`peer-abort: bad port ${process.argv[2]}\n`);
  process.exit(2);
}

const mkRec = (label, values) => ({
  [Symbol.toStringTag]: 'Record',
  label,
  values,
});

const ourFrames = [
  mkRec('op:start-session', ['0.1', 'tcp-testing-only:peer-node']),
  mkRec('op:abort', ['goodbye-from-node']),
];

let outBuf;
try {
  const parts = [];
  for (const frame of ourFrames) {
    parts.push(Buffer.from(encodeSyrup(frame)));
    parts.push(Buffer.from('\n'));
  }
  outBuf = Buffer.concat(parts);
} catch (err) {
  process.stdout.write(JSON.stringify({ ok: false, error: `encode: ${err.message}` }) + '\n');
  process.exit(1);
}

const sock = net.createConnection({ host: '127.0.0.1', port });
let inBuf = Buffer.alloc(0);
let sawSessionLoc = null;
let sawAbortReason = null;
let done = false;

const tryConsumeFrame = () => {
  for (let i = 0; i < inBuf.length; i++) {
    if (inBuf[i] === 0x0a) {
      const sliced = inBuf.subarray(0, i);
      inBuf = inBuf.subarray(i + 1);
      if (sliced.length === 0) return null;
      const payload = new Uint8Array(sliced.length);
      payload.set(sliced);
      try {
        return decodeSyrup(payload);
      } catch (err) {
        process.stdout.write(JSON.stringify({
          ok: false,
          error: `decode: ${err.message}`,
        }) + '\n');
        process.exit(1);
      }
    }
  }
  return undefined;
};

sock.on('connect', () => {
  sock.write(outBuf);
});

sock.on('data', d => {
  inBuf = Buffer.concat([inBuf, d]);
  while (!done) {
    const f = tryConsumeFrame();
    if (f === undefined) break;
    if (f === null) continue;
    if (f.label === 'op:start-session' && Array.isArray(f.values)) {
      sawSessionLoc = typeof f.values[1] === 'string' ? f.values[1] : null;
    } else if (f.label === 'op:abort') {
      sawAbortReason = typeof f.values?.[0] === 'string' ? f.values[0] : null;
      done = true;
    }
  }
  if (done) {
    finish(true);
  }
});

const finish = (ok) => {
  process.stdout.write(JSON.stringify({
    ok,
    saw_session_locator: sawSessionLoc,
    saw_abort_reason: sawAbortReason,
  }) + '\n');
  try { sock.end(); } catch (_) { /* */ }
  process.exit(ok ? 0 : 1);
};

sock.on('error', err => {
  process.stdout.write(JSON.stringify({
    ok: false,
    error: `socket: ${err.message}`,
    saw_session_locator: sawSessionLoc,
    saw_abort_reason: sawAbortReason,
  }) + '\n');
  process.exit(1);
});

sock.on('end', () => {
  if (!done) finish(false);
});

setTimeout(() => {
  process.stderr.write('peer-abort: timeout\n');
  process.exit(3);
}, 30_000).unref();
