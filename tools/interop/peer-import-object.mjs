#!/usr/bin/env node
//
// peer-import-object.mjs — Phase 37: desc:import-object cross-impl gate.
//
// Verifies Racket decodes <desc:import-object N> without crashing and
// reflects it intact when the echo actor resolves the question — full
// wire round-trip with @endo/ocapn as the encoder/decoder counterparty.
//
// Wire flow:
//   1. Connect; send our op:start-session.
//   2. Send op:deliver target=<desc:export 0>
//        args = ["hello-import", <desc:import-object 11>]
//        answer-pos=<desc:answer 200>
//        resolver=false.
//   3. Read frames from Racket. Expect:
//        a. Racket's op:start-session (handshake reply).
//        b. Racket's reply to our Q: op:deliver target=<desc:answer 200>
//           args echoed back, INCLUDING the desc:import-object 11 intact.
//   4. Verify both frames + that the echoed args contain a Record
//      labeled "desc:import-object" with value 11n; print summary;
//      exit 0.
//
// This is the symmetric test to peer-refr-passing.mjs (which exercises
// desc:export) — Phase 37 added desc:import-object as a 5th refr kind
// and this gate validates the cross-impl encode/decode contract.

import '@endo/init';
import net from 'node:net';
import {
  encodeSyrup,
  decodeSyrup,
} from './node_modules/@endo/ocapn/src/syrup/js-representation.js';

const port = Number(process.argv[2]);
if (!Number.isInteger(port) || port < 1) {
  process.stderr.write(`peer-import-object: bad port ${process.argv[2]}\n`);
  process.exit(2);
}

const ANSWER_POS = 200n;
const IMPORT_OBJECT_ID = 11n;
const TARGET_EXPORT = 0n;

const mkRec = (label, values) => ({
  [Symbol.toStringTag]: 'Record',
  label,
  values,
});

const startSession = mkRec('op:start-session', [
  '0.1',
  'tcp-testing-only:peer-node-import-object',
]);

// args = ["hello-import", <desc:import-object 11>]
const importObjectRefr = mkRec('desc:import-object', [IMPORT_OBJECT_ID]);
const argsArray = ['hello-import', importObjectRefr];

const deliverWithImportObject = mkRec('op:deliver', [
  mkRec('desc:export', [TARGET_EXPORT]),
  argsArray,
  mkRec('desc:answer', [ANSWER_POS]),
  false,
]);

let startBytes, deliverBytes;
try {
  startBytes = Buffer.from(encodeSyrup(startSession));
  deliverBytes = Buffer.from(encodeSyrup(deliverWithImportObject));
} catch (err) {
  process.stdout.write(JSON.stringify({ ok: false, error: `encode: ${err.message}` }) + '\n');
  process.exit(1);
}

const sock = net.createConnection({ host: '127.0.0.1', port });
let inBuf = Buffer.alloc(0);
let receivedFrames = [];
let summarized = false;

const tryConsumeFrame = () => {
  for (let i = 0; i < inBuf.length; i++) {
    if (inBuf[i] === 0x0a) {
      if (i > 0) {
        const sliced = inBuf.subarray(0, i);
        const payload = new Uint8Array(sliced.length);
        payload.set(sliced);
        try {
          const v = decodeSyrup(payload);
          receivedFrames.push(v);
        } catch (err) {
          process.stdout.write(JSON.stringify({
            ok: false,
            error: `decode: ${err.message}`,
            raw_hex: Buffer.from(payload).toString('hex'),
          }) + '\n');
          process.exit(1);
        }
      }
      inBuf = inBuf.subarray(i + 1);
      return true;
    }
  }
  return false;
};

// Walk a decoded value once, looking for a Record labeled "desc:import-object"
// whose first value === IMPORT_OBJECT_ID. Shallow walk one level into arrays.
const findImportObjectInArgs = (args) => {
  if (!Array.isArray(args)) return null;
  for (const v of args) {
    if (v && v.label === 'desc:import-object'
        && Array.isArray(v.values)
        && typeof v.values[0] === 'bigint'
        && v.values[0] === IMPORT_OBJECT_ID) {
      return v;
    }
  }
  return null;
};

const summarize = () => {
  if (summarized) return;
  summarized = true;

  const session = receivedFrames.find(f => f && f.label === 'op:start-session');
  const replyToOurQ = receivedFrames.find(f =>
    f && f.label === 'op:deliver'
      && f.values && f.values[0]
      && f.values[0].label === 'desc:answer'
      && f.values[0].values && f.values[0].values[0] === ANSWER_POS);

  // The reply's args is f.values[1] — the echoed args from Racket.
  const replyArgs = replyToOurQ ? replyToOurQ.values[1] : null;
  const echoedImportObject = findImportObjectInArgs(replyArgs);

  const sessionLocator = session && Array.isArray(session.values)
    ? String(session.values[1]) : null;

  process.stdout.write(JSON.stringify({
    ok: !!(session && replyToOurQ && echoedImportObject),
    saw_session: sessionLocator,
    saw_reply_to_our_q: !!replyToOurQ,
    saw_import_object_in_reply: !!echoedImportObject,
    import_object_id: echoedImportObject ? Number(echoedImportObject.values[0]) : null,
  }) + '\n');

  sock.end();
  process.exit(session && replyToOurQ && echoedImportObject ? 0 : 1);
};

sock.on('connect', () => {
  sock.write(startBytes);
  sock.write('\n');
  sock.write(deliverBytes);
  sock.write('\n');
});

sock.on('data', d => {
  inBuf = Buffer.concat([inBuf, d]);
  while (tryConsumeFrame()) { /* keep going */ }
  const haveSession = receivedFrames.some(f => f && f.label === 'op:start-session');
  const haveReply = receivedFrames.some(f =>
    f && f.label === 'op:deliver'
      && f.values && f.values[0]
      && f.values[0].label === 'desc:answer');
  if (haveSession && haveReply) summarize();
});

sock.on('error', err => {
  if (summarized) return;
  process.stdout.write(JSON.stringify({
    ok: false,
    error: `socket: ${err.message}`,
    received_count: receivedFrames.length,
    received_labels: receivedFrames.map(f => f && f.label),
  }) + '\n');
  process.exit(1);
});

sock.on('end', () => {
  if (!summarized) {
    process.stdout.write(JSON.stringify({
      ok: false,
      error: 'connection ended before all expected frames received',
      received_count: receivedFrames.length,
      received_labels: receivedFrames.map(f => f && f.label),
    }) + '\n');
    process.exit(1);
  }
});

setTimeout(() => {
  process.stderr.write('peer-import-object: timeout\n');
  process.exit(3);
}, 60_000).unref();
