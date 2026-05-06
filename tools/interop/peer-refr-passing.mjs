#!/usr/bin/env node
//
// peer-refr-passing.mjs — Phase 34f: refr-in-args interop.
//
// Tests Racket's auto-track-and-release flow for imported refrs.
//
// Wire flow:
//   1. Connect; send our op:start-session.
//   2. Send op:deliver target=<desc:export 0> args=("ping",<desc:export 7>)
//      answer-pos=<desc:answer 100> resolver=false.
//      The args carry a refr (desc:export 7) — from Racket's POV this
//      is an IMPORT. Racket's bridge auto-increments imports-refcount[7].
//   3. Read frames from Racket. Expect (in any order):
//        a. Racket's op:start-session
//        b. Racket's reply to our Q (target=<desc:answer 100>, echoed args)
//        c. Racket's op:gc-export 7 1 (the release-import bytes)
//   4. Verify all 3 frames; print summary; exit 0.

import '@endo/init';
import net from 'node:net';
import {
  encodeSyrup,
  decodeSyrup,
} from './node_modules/@endo/ocapn/src/syrup/js-representation.js';

const port = Number(process.argv[2]);
if (!Number.isInteger(port) || port < 1) {
  process.stderr.write(`peer-refr-passing: bad port ${process.argv[2]}\n`);
  process.exit(2);
}

const ANSWER_POS = 100n;
const REFR_ID = 7n;       // The refr we'll embed in args.
const TARGET_EXPORT = 0n;

const mkRec = (label, values) => ({
  [Symbol.toStringTag]: 'Record',
  label,
  values,
});

const startSession = mkRec('op:start-session', [
  '0.1',
  'tcp-testing-only:peer-node-refr-passing',
]);

// args = (syrup-list ["ping", <desc:export 7>])
// In Racket's syrup model, syrup-list maps to JS array.
const exportRefr = mkRec('desc:export', [REFR_ID]);
const argsArray = ['ping', exportRefr];

// op:deliver with refr-in-args.
const deliverWithRefr = mkRec('op:deliver', [
  mkRec('desc:export', [TARGET_EXPORT]),
  argsArray,
  mkRec('desc:answer', [ANSWER_POS]),
  false,
]);

let startBytes, deliverBytes;
try {
  startBytes = Buffer.from(encodeSyrup(startSession));
  deliverBytes = Buffer.from(encodeSyrup(deliverWithRefr));
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

const summarize = () => {
  if (summarized) return;
  summarized = true;

  const session = receivedFrames.find(f => f && f.label === 'op:start-session');
  const replyToOurQ = receivedFrames.find(f =>
    f && f.label === 'op:deliver'
      && f.values && f.values[0]
      && f.values[0].label === 'desc:answer'
      && f.values[0].values && f.values[0].values[0] === ANSWER_POS);
  const gcExport = receivedFrames.find(f =>
    f && f.label === 'op:gc-export'
      && Array.isArray(f.values)
      && f.values.length >= 2
      && typeof f.values[0] === 'bigint'
      && f.values[0] === REFR_ID);

  const gcExportPos = gcExport ? Number(gcExport.values[0]) : null;
  const gcExportCnt = gcExport ? Number(gcExport.values[1]) : null;

  const sessionLocator = session && Array.isArray(session.values)
    ? String(session.values[1]) : null;

  process.stdout.write(JSON.stringify({
    ok: !!(session && replyToOurQ && gcExport),
    saw_session: sessionLocator,
    saw_reply_to_our_q: !!replyToOurQ,
    saw_gc_export: !!gcExport,
    gc_export_pos: gcExportPos,
    gc_export_cnt: gcExportCnt,
  }) + '\n');

  sock.end();
  process.exit(session && replyToOurQ && gcExport ? 0 : 1);
};

sock.on('connect', () => {
  // Send session + deliver (with refr-in-args) immediately.
  sock.write(startBytes);
  sock.write('\n');
  sock.write(deliverBytes);
  sock.write('\n');
});

sock.on('data', d => {
  inBuf = Buffer.concat([inBuf, d]);
  while (tryConsumeFrame()) { /* keep going */ }
  // Wait until all 3 expected Racket frames are in.
  const haveSession = receivedFrames.some(f => f && f.label === 'op:start-session');
  const haveReply = receivedFrames.some(f =>
    f && f.label === 'op:deliver'
      && f.values && f.values[0]
      && f.values[0].label === 'desc:answer');
  const haveGcExport = receivedFrames.some(f => f && f.label === 'op:gc-export');
  if (haveSession && haveReply && haveGcExport) summarize();
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
      error: 'connection ended before all 3 expected frames received',
      received_count: receivedFrames.length,
      received_labels: receivedFrames.map(f => f && f.label),
    }) + '\n');
    process.exit(1);
  }
});

// 60 s safety timeout.
setTimeout(() => {
  process.stderr.write('peer-refr-passing: timeout\n');
  process.exit(3);
}, 60_000).unref();
