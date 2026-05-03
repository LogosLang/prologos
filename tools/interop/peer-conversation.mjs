#!/usr/bin/env node
//
// peer-conversation.mjs — Phase 7: multi-message conversation.
//
// Usage: node peer-conversation.mjs <port>
//
// Protocol (Phase 7 minimum, three frames each direction):
//   1. Connect to 127.0.0.1:<port>
//   2. Send op:start-session ver="0.1" loc="tcp-testing-only:peer-node"
//   3. Send op:deliver-only target=<desc:export 0> args="ping"
//   4. Send op:abort reason="goodbye"
//   5. Read three '\n'-terminated frames from the parent.
//   6. Decode each via @endo/ocapn.
//   7. Print one-line JSON summary on stdout — one entry per
//      received frame plus an `ok` flag indicating all three
//      decoded successfully with the expected labels.
//
// JSON shape:
//   {
//     "ok": true,
//     "received": [
//       {"label": "op:start-session", "raw_hex": "..."},
//       {"label": "op:deliver-only",  "raw_hex": "..."},
//       {"label": "op:abort",         "raw_hex": "..."}
//     ]
//   }

import '@endo/init';
import net from 'node:net';
import {
  encodeSyrup,
  decodeSyrup,
} from './node_modules/@endo/ocapn/src/syrup/js-representation.js';

const port = Number(process.argv[2]);
if (!Number.isInteger(port) || port < 1) {
  process.stderr.write(`peer-conversation: bad port ${process.argv[2]}\n`);
  process.exit(2);
}

const mkRec = (label, values) => ({
  [Symbol.toStringTag]: 'Record',
  label,
  values,
});

// Three messages we send.
const ourFrames = [
  mkRec('op:start-session', ['0.1', 'tcp-testing-only:peer-node']),
  mkRec('op:deliver-only', [mkRec('desc:export', [0n]), 'ping']),
  mkRec('op:abort', ['goodbye']),
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

sock.on('connect', () => {
  sock.write(outBuf);
});

sock.on('data', d => {
  inBuf = Buffer.concat([inBuf, d]);
});

sock.on('error', err => {
  process.stdout.write(JSON.stringify({ ok: false, error: `socket: ${err.message}` }) + '\n');
  process.exit(1);
});

sock.on('end', () => {
  // Split inBuf by '\n', decode each non-empty frame.
  const received = [];
  let start = 0;
  for (let i = 0; i < inBuf.length; i++) {
    if (inBuf[i] === 0x0a) {
      if (i > start) {
        const sliced = inBuf.subarray(start, i);
        const payload = new Uint8Array(sliced.length);
        payload.set(sliced);
        try {
          const v = decodeSyrup(payload);
          received.push({
            label: v && v.label != null ? String(v.label) : null,
            raw_hex: Buffer.from(payload).toString('hex'),
          });
        } catch (err) {
          received.push({
            label: null,
            raw_hex: Buffer.from(payload).toString('hex'),
            error: String(err),
          });
        }
      }
      start = i + 1;
    }
  }
  const expectedLabels = ['op:start-session', 'op:deliver-only', 'op:abort'];
  const ok =
    received.length === expectedLabels.length &&
    received.every((r, i) => r.label === expectedLabels[i]);
  process.stdout.write(JSON.stringify({ ok, received }) + '\n');
  process.exit(ok ? 0 : 1);
});
