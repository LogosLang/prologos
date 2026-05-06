#!/usr/bin/env node
//
// peer-questioner.mjs — Phase 24: Node QUESTIONER for the
// bridge-driven responder interop test.
//
// This is the inverse of peer-responder.mjs. Here Node initiates;
// Racket is the responder driven by the CapTP↔Vat bridge
// (`connection-step`).
//
// Usage: node peer-questioner.mjs <port>
//
// Wire flow:
//   1. Connect to 127.0.0.1:<port> (Racket listens)
//   2. Send our op:start-session
//   3. Send op:deliver target=<desc:export 0> args="hello"
//                       answer-pos=<desc:answer 7> resolver=false
//   4. Read 2 frames from Racket. Expect:
//        - Racket's op:start-session
//        - Racket's reply: <op:deliver <desc:answer 7> "hello" n n>
//          (beh-echo returns args unchanged)
//   5. Verify the reply targets desc:answer 7 and args[1] == "hello".
//   6. Print one-line JSON summary on stdout, exit 0/1.
//
// JSON summary on stdout:
//   {
//     "ok": true,
//     "saw_session": "<racket's locator>",
//     "saw_reply_target_pos": 7,
//     "saw_reply_args0": "hello"
//   }

import '@endo/init';
import net from 'node:net';
import {
  encodeSyrup,
  decodeSyrup,
} from './node_modules/@endo/ocapn/src/syrup/js-representation.js';

const port = Number(process.argv[2]);
if (!Number.isInteger(port) || port < 1) {
  process.stderr.write(`peer-questioner: bad port ${process.argv[2]}\n`);
  process.exit(2);
}

const ECHO_PAYLOAD = 'hello';
const ANSWER_POS = 7n;
const TARGET_EXPORT = 0n;

const mkRec = (label, values) => ({
  [Symbol.toStringTag]: 'Record',
  label,
  values,
});

// Outbound frame 1: our start-session
const startSession = mkRec('op:start-session', [
  '0.1',
  'tcp-testing-only:peer-node',
]);

// Outbound frame 2: op:deliver
//   target    = <desc:export 0>           — target the actor at id 0
//   args      = "hello"                    — single string payload
//   answer-pos= <desc:answer 7>            — Node's question pos = 7
//   resolver  = false                       — pitfall #28: false, not null
const targetDesc = mkRec('desc:export', [TARGET_EXPORT]);
const answerDesc = mkRec('desc:answer', [ANSWER_POS]);
const deliver = mkRec('op:deliver', [targetDesc, ECHO_PAYLOAD, answerDesc, false]);

let startBytes, deliverBytes;
try {
  startBytes = Buffer.from(encodeSyrup(startSession));
  deliverBytes = Buffer.from(encodeSyrup(deliver));
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
  const reply   = receivedFrames.find(f => f && f.label === 'op:deliver');

  if (!reply) {
    process.stdout.write(JSON.stringify({
      ok: false,
      error: 'no op:deliver received from Racket bridge',
      received_count: receivedFrames.length,
      received_labels: receivedFrames.map(f => f && f.label),
    }) + '\n');
    process.exit(1);
  }

  // reply.values = [target, args, answer-pos, resolver]
  const replyTarget = reply.values[0];
  const replyArgs   = reply.values[1];

  let replyTargetPos = null;
  if (replyTarget && replyTarget.label === 'desc:answer'
      && Array.isArray(replyTarget.values)
      && typeof replyTarget.values[0] === 'bigint') {
    replyTargetPos = Number(replyTarget.values[0]);
  }

  const ok = replyTargetPos === Number(ANSWER_POS) && replyArgs === ECHO_PAYLOAD;

  const sessionLocator = session && Array.isArray(session.values)
    ? String(session.values[1]) : null;

  process.stdout.write(JSON.stringify({
    ok,
    saw_session: sessionLocator,
    saw_reply_target_pos: replyTargetPos,
    saw_reply_args0: typeof replyArgs === 'string' ? replyArgs : null,
    expected_pos: Number(ANSWER_POS),
    expected_args0: ECHO_PAYLOAD,
  }) + '\n');

  sock.end();
  process.exit(ok ? 0 : 1);
};

sock.on('connect', () => {
  // Fire both outbound frames immediately. Racket bridge will
  // batch-process and reply in one go.
  sock.write(startBytes);
  sock.write('\n');
  sock.write(deliverBytes);
  sock.write('\n');
});

sock.on('data', d => {
  inBuf = Buffer.concat([inBuf, d]);
  while (tryConsumeFrame()) { /* keep going */ }
  // CapTP requires both peers to exchange op:start-session as part
  // of the handshake. Racket's bridge synthesizes its own session
  // reply via prologos::ocapn::captp-bridge#our-session-bytes, then
  // dispatches the deliver via drive-echo-bridge-from-bytes. We
  // gate summarize() on having received BOTH frames to fully
  // verify the handshake + deliver round-trip.
  const haveSession = receivedFrames.some(f => f && f.label === 'op:start-session');
  const haveReply   = receivedFrames.some(f => f && f.label === 'op:deliver');
  if (haveSession && haveReply) summarize();
});

sock.on('error', err => {
  if (summarized) return;
  process.stdout.write(JSON.stringify({
    ok: false,
    error: `socket: ${err.message}`,
    received_count: receivedFrames.length,
  }) + '\n');
  process.exit(1);
});

sock.on('end', () => {
  if (!summarized) {
    process.stdout.write(JSON.stringify({
      ok: false,
      error: 'connection ended before reply was received',
      received_count: receivedFrames.length,
      received_labels: receivedFrames.map(f => f && f.label),
    }) + '\n');
    process.exit(1);
  }
});

// 60 s safety timeout. With the looseBVarRange fix for pitfall #31
// (commits 4f6b3f0 + 6f2e077), the Racket bridge end-to-end
// (decode-op + captp-incoming-with-state + drain + pump-outbound)
// completes in ~3 s in local testing. 60 s leaves a generous margin
// for slower CI hardware while still catching genuine regressions.
setTimeout(() => {
  process.stderr.write('peer-questioner: timeout\n');
  process.exit(3);
}, 60_000).unref();
