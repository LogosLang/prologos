#!/usr/bin/env node
//
// peer-pipeline-forwarding.mjs — Phase 43: cross-impl gate for the
// wire-out forwarding closure (Phase 41/42).
//
// Where peer-pipelining.mjs (Phase 40) just verified Racket processes a
// pipelined msg without crashing, this gate verifies the FULL forwarding
// loop:
//
//   1. Node sends our op:start-session.
//   2. Node sends Q1: op:deliver target=<desc:export 0>
//        args=<desc:export 99>            ;; a refr in args
//        answer-pos=<desc:answer 7> false.
//   3. Node sends Q2: op:deliver target=<desc:answer 7>
//        args="forwardable" false false.  ;; pipelined onto Q1
//
//   Racket processes:
//     - Q1 → echo actor → resolves local promise(7) with <desc:export 99>.
//     - Q2 → pipeline-deliver queues "forwardable" on local promise(7),
//            bs-add-pipeline-msg records it at bridge level.
//     - Drain: echo runs, promise resolves to <desc:export 99>.
//     - Pump-outbound: emits resolution bytes for Q1 + walks pipelined-msgs.
//        syrup-as-export-target sees <desc:export 99>, lookup-actor 99 = none
//        (no local actor at id 99) → Phase 41 wire forwarding kicks in:
//        emits <op:deliver <desc:export 99> "forwardable" false false>.
//
//   4. Node receives 3 frames: session, Q1 reply, forwarding bytes.
//   5. Verifies all three; prints summary; exits 0.

import '@endo/init';
import net from 'node:net';
import {
  encodeSyrup,
  decodeSyrup,
} from './node_modules/@endo/ocapn/src/syrup/js-representation.js';

const port = Number(process.argv[2]);
if (!Number.isInteger(port) || port < 1) {
  process.stderr.write(`peer-pipeline-forwarding: bad port ${process.argv[2]}\n`);
  process.exit(2);
}

const ANSWER_POS = 7n;
const TARGET_EXPORT = 0n;
const REFR_ID = 99n;            // The export-id Q1 will resolve to.
const Q2_PAYLOAD = 'forwardable';

const mkRec = (label, values) => ({
  [Symbol.toStringTag]: 'Record',
  label,
  values,
});

const startSession = mkRec('op:start-session', [
  '0.1',
  'tcp-testing-only:peer-node-pipeline-forwarding',
]);

// Q1 args is a desc:export refr — echo will resolve the promise with
// this exact SyrupValue, triggering the Phase 41 forwarding path.
const refrArgs = mkRec('desc:export', [REFR_ID]);

const q1 = mkRec('op:deliver', [
  mkRec('desc:export', [TARGET_EXPORT]),
  refrArgs,
  mkRec('desc:answer', [ANSWER_POS]),
  false,
]);

// Q2 pipelined: target = desc:answer 7, args = string.
const q2 = mkRec('op:deliver', [
  mkRec('desc:answer', [ANSWER_POS]),
  Q2_PAYLOAD,
  false,
  false,
]);

let startBytes, q1Bytes, q2Bytes;
try {
  startBytes = Buffer.from(encodeSyrup(startSession));
  q1Bytes = Buffer.from(encodeSyrup(q1));
  q2Bytes = Buffer.from(encodeSyrup(q2));
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

  // Q1 reply: op:deliver targeting <desc:answer 7> with echoed args.
  const replyToQ1 = receivedFrames.find(f =>
    f && f.label === 'op:deliver'
      && f.values && f.values[0]
      && f.values[0].label === 'desc:answer'
      && f.values[0].values && f.values[0].values[0] === ANSWER_POS);

  // Forwarding: op:deliver targeting <desc:export 99> with Q2 payload.
  const forwarding = receivedFrames.find(f =>
    f && f.label === 'op:deliver'
      && f.values && f.values[0]
      && f.values[0].label === 'desc:export'
      && f.values[0].values && f.values[0].values[0] === REFR_ID
      && f.values[1] === Q2_PAYLOAD);

  const sessionLocator = session && Array.isArray(session.values)
    ? String(session.values[1]) : null;

  process.stdout.write(JSON.stringify({
    ok: !!(session && replyToQ1 && forwarding),
    saw_session: sessionLocator,
    saw_reply_to_q1: !!replyToQ1,
    saw_forwarding: !!forwarding,
    forwarding_target: forwarding ? Number(forwarding.values[0].values[0]) : null,
    forwarding_payload: forwarding ? forwarding.values[1] : null,
  }) + '\n');

  sock.end();
  process.exit(session && replyToQ1 && forwarding ? 0 : 1);
};

sock.on('connect', () => {
  sock.write(startBytes);
  sock.write('\n');
  sock.write(q1Bytes);
  sock.write('\n');
  sock.write(q2Bytes);
  sock.write('\n');
});

sock.on('data', d => {
  inBuf = Buffer.concat([inBuf, d]);
  while (tryConsumeFrame()) { /* keep going */ }
  // Wait until we have all 3 expected frames.
  const haveSession = receivedFrames.some(f => f && f.label === 'op:start-session');
  const haveReply = receivedFrames.some(f =>
    f && f.label === 'op:deliver'
      && f.values && f.values[0]
      && f.values[0].label === 'desc:answer');
  const haveForward = receivedFrames.some(f =>
    f && f.label === 'op:deliver'
      && f.values && f.values[0]
      && f.values[0].label === 'desc:export'
      && f.values[0].values && f.values[0].values[0] === REFR_ID);
  if (haveSession && haveReply && haveForward) summarize();
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
  process.stderr.write('peer-pipeline-forwarding: timeout\n');
  process.exit(3);
}, 60_000).unref();
