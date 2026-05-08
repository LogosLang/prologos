#!/usr/bin/env node
//
// peer-plain-value-error.mjs — Phase 49: cross-impl gate for the
// plain-value-as-error path (Phase 46) end-to-end against
// @endo/ocapn.
//
//   1. Node sends our op:start-session.
//   2. Node sends Q1: op:deliver target=<desc:export 0>
//        args="i-am-a-string"             ;; PLAIN value (not desc:*)
//        answer-pos=<desc:answer 7> false.
//   3. Node sends Q2 (pipelined): op:deliver
//        target=<desc:answer 7>
//        args="forward-me"
//        answer-pos=<desc:answer 88>      ;; ap=some 88
//        false.
//
//   Racket processes via drive-handshake-q-and-pipeline:
//     - Q1 → echo actor → resolves promise(7) with the plain string
//       (echo returns args verbatim; the resolution has shape that
//       does NOT match desc:export or desc:answer).
//     - Q2 → bs-add-pipeline-msg with ap=some 88.
//     - Drain: echo runs, promise fulfilled with plain string.
//     - Pump-outbound:
//       a. resolution bytes for Q1 (op:deliver desc:answer 7 "i-am-a-string")
//       b. Phase 46 fall-through: resolution-value isn't
//          desc:export / desc:answer → dispatch-plain-value-resolution
//          → break-forward-loop emits an error answer at peer's
//          queued ap=88 with reason "deliver-to-non-callable".
//
//   4. Node receives 3 frames, verifies:
//      - Q1 reply at desc:answer 7 with the plain string echoed
//      - Plain-value error at desc:answer 88 with
//        <Error "deliver-to-non-callable"> args

import '@endo/init';
import net from 'node:net';
import {
  encodeSyrup,
  decodeSyrup,
} from './node_modules/@endo/ocapn/src/syrup/js-representation.js';

const port = Number(process.argv[2]);
if (!Number.isInteger(port) || port < 1) {
  process.stderr.write(`peer-plain-value-error: bad port ${process.argv[2]}\n`);
  process.exit(2);
}

const Q1_ANSWER_POS = 7n;
const Q2_QUEUED_AP = 88n;
const TARGET_EXPORT = 0n;
const Q1_PAYLOAD = 'i-am-a-string';
const Q2_PAYLOAD = 'forward-me';
const EXPECTED_ERROR_REASON = 'deliver-to-non-callable';

const mkRec = (label, values) => ({
  [Symbol.toStringTag]: 'Record',
  label,
  values,
});

const startSession = mkRec('op:start-session', [
  '0.1',
  'tcp-testing-only:peer-node-plain-value-error',
]);

const q1 = mkRec('op:deliver', [
  mkRec('desc:export', [TARGET_EXPORT]),
  Q1_PAYLOAD,                  // PLAIN string — not a refr
  mkRec('desc:answer', [Q1_ANSWER_POS]),
  false,
]);

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

  const findDeliverToAnswer = (n) => receivedFrames.find(f =>
    f && f.label === 'op:deliver'
      && f.values && f.values[0]
      && f.values[0].label === 'desc:answer'
      && f.values[0].values && f.values[0].values[0] === n);

  const replyToQ1 = findDeliverToAnswer(Q1_ANSWER_POS);
  const errorAnswer = findDeliverToAnswer(Q2_QUEUED_AP);

  // Q1 reply args is the plain string (echoed verbatim).
  const replyEchoesString = replyToQ1
    && replyToQ1.values && replyToQ1.values[1] === Q1_PAYLOAD;

  // Error answer args is <Error "deliver-to-non-callable">.
  const errorIsErrorWrapped = errorAnswer && isErrorFrame(errorAnswer.values[1]);
  const errorReason = errorIsErrorWrapped && errorAnswer.values[1].values
    ? errorAnswer.values[1].values[0] : null;

  const ok = !!(session && replyToQ1 && errorAnswer
    && replyEchoesString && errorIsErrorWrapped
    && errorReason === EXPECTED_ERROR_REASON);

  const sessionLocator = session && Array.isArray(session.values)
    ? String(session.values[1]) : null;

  process.stdout.write(JSON.stringify({
    ok,
    saw_session: sessionLocator,
    saw_reply_to_q1: !!replyToQ1,
    saw_error_answer: !!errorAnswer,
    reply_echoes_string: replyEchoesString,
    error_is_error_wrapped: errorIsErrorWrapped,
    error_reason: errorReason,
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
  const haveErrorAnswer = receivedFrames.some(f =>
    f && f.label === 'op:deliver'
      && f.values && f.values[0]
      && f.values[0].label === 'desc:answer'
      && f.values[0].values && f.values[0].values[0] === Q2_QUEUED_AP);
  if (haveSession && haveReplyToQ1 && haveErrorAnswer) summarize();
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
  process.stderr.write('peer-plain-value-error: timeout\n');
  process.exit(3);
}, 60_000).unref();
