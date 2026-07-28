#!/usr/bin/env node
//
// peer-break-forwarding.mjs — Phase 49: cross-impl gate for break-
// forwarding (Phase 45) end-to-end against @endo/ocapn.
//
//   1. Node sends our op:start-session.
//   2. Node sends Q1: op:deliver target=<desc:export 0>
//        args=<desc:export 99>
//        answer-pos=<desc:answer 7> false.
//   3. Node sends Q2 (pipelined onto Q1): op:deliver
//        target=<desc:answer 7>
//        args="forward-me"
//        answer-pos=<desc:answer 88>             ;; ap=some 88
//        false.
//
//   Racket processes Q1 + Q2, then BREAKS the local promise tied to
//   peer's q-pos 7 (drive-handshake-break-q-and-pipeline does this
//   before drain so the actor's resolve never fires).
//
//   Racket's pump emits:
//     - op:start-session (handshake)
//     - op:deliver <desc:answer 7> <Error "rejected"> false false
//       (the broken-resolution to peer's q-pos)
//     - op:deliver <desc:answer 88> <Error "rejected"> false false
//       (Phase 45 break-forwarding to peer's queued ap)
//
//   4. Node receives 3 frames, verifies:
//      - Q1 reply targets desc:answer 7 with Error wrapper
//      - Break-forward targets desc:answer 88 with Error wrapper
//      - Reason matches "rejected"

import '@endo/init';
import net from 'node:net';
import {
  encodeSyrup,
  decodeSyrup,
} from './node_modules/@endo/ocapn/src/syrup/js-representation.js';

// The op:deliver args slot is a LIST -- the OCapN wire form, and what
// upstream's own suite iterates. Racket used to send a bare value there,
// which this script was written against; unwrapping one level here reads
// both, so the fixture no longer pins the older (unparseable) shape.
const argsHead = (a) => Array.isArray(a) ? a[0] : (a && Array.isArray(a.values)) ? a.values[0] : a;
const port = Number(process.argv[2]);
if (!Number.isInteger(port) || port < 1) {
  process.stderr.write(`peer-break-forwarding: bad port ${process.argv[2]}\n`);
  process.exit(2);
}

const Q1_ANSWER_POS = 7n;
const Q2_QUEUED_AP = 88n;
const TARGET_EXPORT = 0n;
const REFR_ID = 99n;
const Q2_PAYLOAD = 'forward-me';
const EXPECTED_REASON = 'rejected';

const mkRec = (label, values) => ({
  [Symbol.toStringTag]: 'Record',
  label,
  values,
});

const startSession = mkRec('op:start-session', [
  '0.1',
  'tcp-testing-only:peer-node-break-forwarding',
]);

const refrArgs = mkRec('desc:export', [REFR_ID]);

const q1 = mkRec('op:deliver', [
  mkRec('desc:export', [TARGET_EXPORT]),
  refrArgs,
  mkRec('desc:answer', [Q1_ANSWER_POS]),
  false,
]);

// Q2 pipelined: target = desc:answer 7 (Q1's q-pos),
// args = string, ap = some 88 (peer wants an answer to this Q).
const q2 = mkRec('op:deliver', [
  mkRec('desc:answer', [Q1_ANSWER_POS]),
  Q2_PAYLOAD,
  mkRec('desc:answer', [Q2_QUEUED_AP]),
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

const isErrorFrame = (val) =>
  val && val[Symbol.toStringTag] === 'Record' && val.label === 'Error';

const summarize = () => {
  if (summarized) return;
  summarized = true;

  const session = receivedFrames.find(f => f && f.label === 'op:start-session');

  // Find op:deliver frames targeting each desc:answer N.
  const findDeliverToAnswer = (n) => receivedFrames.find(f =>
    f && f.label === 'op:deliver'
      && f.values && f.values[0]
      && f.values[0].label === 'desc:answer'
      && f.values[0].values && f.values[0].values[0] === n);

  const replyToQ1 = findDeliverToAnswer(Q1_ANSWER_POS);
  const breakForward = findDeliverToAnswer(Q2_QUEUED_AP);

  // Check both have <Error "rejected"> as the args field.
  const replyArgsAreError = replyToQ1 && isErrorFrame(argsHead(replyToQ1.values[1]));
  const breakArgsAreError = breakForward && isErrorFrame(argsHead(breakForward.values[1]));
  const replyReason = replyArgsAreError && argsHead(replyToQ1.values[1]).values
    ? argsHead(replyToQ1.values[1]).values[0] : null;
  const breakReason = breakArgsAreError && argsHead(breakForward.values[1]).values
    ? argsHead(breakForward.values[1]).values[0] : null;

  const ok = !!(session && replyToQ1 && breakForward
    && replyArgsAreError && breakArgsAreError
    && replyReason === EXPECTED_REASON
    && breakReason === EXPECTED_REASON);

  const sessionLocator = session && Array.isArray(session.values)
    ? String(session.values[1]) : null;

  process.stdout.write(JSON.stringify({
    ok,
    saw_session: sessionLocator,
    saw_reply_to_q1: !!replyToQ1,
    saw_break_forward: !!breakForward,
    reply_is_error: replyArgsAreError,
    break_is_error: breakArgsAreError,
    reply_reason: replyReason,
    break_reason: breakReason,
  }) + '\n');

  sock.end();
  process.exit(ok ? 0 : 1);
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
  const haveSession = receivedFrames.some(f => f && f.label === 'op:start-session');
  const haveReplyToQ1 = receivedFrames.some(f =>
    f && f.label === 'op:deliver'
      && f.values && f.values[0]
      && f.values[0].label === 'desc:answer'
      && f.values[0].values && f.values[0].values[0] === Q1_ANSWER_POS);
  const haveBreakForward = receivedFrames.some(f =>
    f && f.label === 'op:deliver'
      && f.values && f.values[0]
      && f.values[0].label === 'desc:answer'
      && f.values[0].values && f.values[0].values[0] === Q2_QUEUED_AP);
  if (haveSession && haveReplyToQ1 && haveBreakForward) summarize();
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
  process.stderr.write('peer-break-forwarding: timeout\n');
  process.exit(3);
}, 60_000).unref();
