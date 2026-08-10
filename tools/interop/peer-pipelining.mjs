#!/usr/bin/env node
//
// peer-pipelining.mjs — Phase 40: cross-impl pipelining gate.
//
// Tests Racket's wire-level promise-pipelining receiver (Phase 38):
// peer can send op:deliver with target=<desc:answer N> where N is
// peer's own question position — chaining a follow-up message onto
// the not-yet-resolved answer.
//
// Wire flow:
//   1. Connect; send our op:start-session.
//   2. Send op:deliver target=<desc:export 0> args="get-greeter"
//        answer-pos=<desc:answer 7> resolver=false.
//      (Q1 — peer asks Racket export 0 for something.)
//   3. Send op:deliver target=<desc:answer 7> args="hi-there"
//        false false.
//      (Q2 — peer pipelines "hi-there" onto Q1's eventual answer.
//       From Racket's POV, the q-pos 7 is in their inbound bs-questions
//       table; they look up the local promise and queue "hi-there"
//       on it — Phase 38 dispatch-pipeline-on-our-q.)
//   4. Read frames from Racket. Expect:
//        a. Racket's op:start-session (handshake reply).
//        b. Racket's reply to Q1: <op:deliver <desc:answer 7>
//             "get-greeter" false false>.
//      The pipelined Q2 doesn't generate outbound bytes — it queues
//      internally on the local promise (vat-side wire-out forwarding
//      from queue-on-resolution is deferred). The cross-impl assertion
//      is "Racket didn't crash on Q2 AND replied correctly to Q1."
//   5. Verify both frames; print summary; exit 0.

import '@endo/init';
import net from 'node:net';
import {
  encodeSyrup,
  decodeSyrup,
} from './node_modules/@endo/ocapn/src/syrup/js-representation.js';

// The op:deliver args slot is a LIST -- the OCapN wire form, and what
// upstream's own suite iterates. This used to also accept a bare value,
// because Racket once sent one there; that made the fixture pass under
// either shape, so it stopped pinning the correct one. It is strict now:
// anything but a list yields `undefined` and the assertion fails.
const argsHead = (a) => Array.isArray(a) ? a[0] : undefined;
const port = Number(process.argv[2]);
if (!Number.isInteger(port) || port < 1) {
  process.stderr.write(`peer-pipelining: bad port ${process.argv[2]}\n`);
  process.exit(2);
}

const ANSWER_POS = 7n;
const TARGET_EXPORT = 0n;
const Q1_PAYLOAD = 'get-greeter';
const Q2_PAYLOAD = 'hi-there';

const mkRec = (label, values) => ({
  [Symbol.toStringTag]: 'Record',
  label,
  values,
});

const startSession = mkRec('op:start-session', [
  '0.1',
  'tcp-testing-only:peer-node-pipelining',
]);

// Q1: ask Racket's export 0 for "get-greeter", answer at peer's q-pos 7.
const q1 = mkRec('op:deliver', [
  mkRec('desc:export', [TARGET_EXPORT]),
  Q1_PAYLOAD,
  mkRec('desc:answer', [ANSWER_POS]),
  false,
]);

// Q2: pipeline "hi-there" onto our q-pos 7 (target = desc:answer).
// From Racket's perspective: target's q-pos 7 is in bs-questions, so
// pipeline-deliver queues "hi-there" on the local promise.
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
  const replyToQ1 = receivedFrames.find(f =>
    f && f.label === 'op:deliver'
      && f.values && f.values[0]
      && f.values[0].label === 'desc:answer'
      && f.values[0].values && f.values[0].values[0] === ANSWER_POS);

  // Verify the echoed args carry Q1's payload (proves Q1 dispatched
  // through the echo actor — Q2 didn't poison the bridge state).
  const echoedPayload = replyToQ1 ? argsHead(replyToQ1.values[1]) : null;
  const payloadMatches = echoedPayload === Q1_PAYLOAD;

  const sessionLocator = session && Array.isArray(session.values)
    ? String(session.values[1]) : null;

  process.stdout.write(JSON.stringify({
    ok: !!(session && replyToQ1 && payloadMatches),
    saw_session: sessionLocator,
    saw_reply_to_q1: !!replyToQ1,
    reply_payload_matches: payloadMatches,
    echoed_payload: typeof echoedPayload === 'string' ? echoedPayload : null,
  }) + '\n');

  sock.end();
  process.exit(session && replyToQ1 && payloadMatches ? 0 : 1);
};

sock.on('connect', () => {
  // Send session + Q1 + Q2 (pipelined) immediately.
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
  process.stderr.write('peer-pipelining: timeout\n');
  process.exit(3);
}, 60_000).unref();
