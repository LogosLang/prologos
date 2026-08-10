#!/usr/bin/env node
//
// peer-responder.mjs — Phase 8: real RPC-style state machine.
//
// Usage: node peer-responder.mjs <port>
//
// Unlike Phase 7's lockstep echo, this peer ACTS on what it
// receives. It implements a tiny CapTP responder:
//
//   1. Connect to 127.0.0.1:<port>
//   2. Send our op:start-session
//   3. Read incoming frames. Expect:
//        - one op:start-session    (the parent's session)
//        - one op:deliver          (the parent's RPC request)
//   4. Extract the answer-pos from the deliver. If args[0] is
//      a string, append "-pong" to form a reply value.
//   5. Send <op:deliver <desc:answer N> "<args[0]>-pong" n n>
//      where N is the answer-pos and `n` is null (no answer-pos
//      for this reply, no resolver).
//   6. Print one-line JSON summary on stdout, exit 0.
//
// JSON summary on stdout:
//   {
//     "ok": true,
//     "saw_session": "<parent's locator>",
//     "saw_deliver_args0": "ping",
//     "answer_pos": 0,
//     "sent_reply_args0": "ping-pong"
//   }

import '@endo/init';
import net from 'node:net';
import {

  encodeSyrup,
  decodeSyrup,
} from './node_modules/@endo/ocapn/src/syrup/js-representation.js';

// --- Spec-shaped accessors for an op:deliver's trailing slots -----------
//
// The answer position is a BARE INTEGER (`utils/captp_types.py` reads
// `record.args[2]` raw). Racket used to wrap it as `<desc:answer N>` and
// these peers were written against that, so they pinned a form no
// conforming peer sends. They accept the spec form ONLY: accepting both
// would keep them green if the wrapping came back.
const answerPosOf = (v) => (typeof v === 'bigint' ? v : null);

// The args slot is a LIST, always -- a peer iterates it directly. Racket
// used to put a bare value there for some replies; that is not a tolerable
// variation and is not accepted here.
const argsList = (a) => (Array.isArray(a) ? a : (a && Array.isArray(a.values) ? a.values : null));
const argsFirst = (a) => { const l = argsList(a); return l && l.length ? l[0] : null; };


const port = Number(process.argv[2]);
if (!Number.isInteger(port) || port < 1) {
  process.stderr.write(`peer-responder: bad port ${process.argv[2]}\n`);
  process.exit(2);
}

const mkRec = (label, values) => ({
  [Symbol.toStringTag]: 'Record',
  label,
  values,
});

// Our outbound start-session (sent immediately on connect).
const startSession = mkRec('op:start-session', [
  '0.1',
  'tcp-testing-only:peer-node',
]);

let startBytes;
try {
  startBytes = Buffer.from(encodeSyrup(startSession));
} catch (err) {
  process.stdout.write(JSON.stringify({ ok: false, error: `encode-start: ${err.message}` }) + '\n');
  process.exit(1);
}

const sock = net.createConnection({ host: '127.0.0.1', port });
let inBuf = Buffer.alloc(0);
let receivedFrames = [];
let replied = false;

const tryConsumeFrame = () => {
  // Find the next '\n' boundary; if found, decode the bytes
  // before it and shift inBuf.
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

const respond = () => {
  // We expect at least one start-session and one deliver.
  const session = receivedFrames.find(f => f && f.label === 'op:start-session');
  const deliver = receivedFrames.find(f => f && f.label === 'op:deliver');
  if (!deliver) return false;

  const sessionLocator = session && Array.isArray(session.values)
    ? String(session.values[1])
    : null;

  // op:deliver's values are: [target-desc, args, answer-pos, resolve-me]
  const args = deliver.values[0]; // wait — Prologos sent record values as
                                   // [<desc:export 0>, "ping", <desc:answer 0>, null]
                                   // i.e. 4 children. Let's read them.
  const targetDesc = deliver.values[0];
  const argsValue  = deliver.values[1];
  const answerN = answerPosOf(deliver.values[2]);
  if (answerN === null) {
    process.stdout.write(JSON.stringify({
      ok: false,
      error: 'deliver had no parseable answer-pos',
      deliver_dump: JSON.stringify(deliver, (k, v) =>
        typeof v === 'bigint' ? v.toString() : v),
    }) + '\n');
    process.exit(1);
  }

  // Compose reply value: <args>-pong (if args is a string).
  const firstArg = argsFirst(argsValue);
  const replyArgs = typeof firstArg === 'string' ? `${firstArg}-pong` : 'reply';

  // Build the response record:
  //   <op:deliver <desc:answer N> reply-args false false>
  // (deliver to the answer position; no nested answer-pos / resolver
  // — encoded as `false` because @endo/ocapn doesn't accept `null`
  // as a record child. Goblin pitfall #28.)
  const desc = mkRec('desc:answer', [answerN]);
  const reply = mkRec('op:deliver', [desc, replyArgs, false, false]);

  let replyBytes;
  try {
    replyBytes = Buffer.from(encodeSyrup(reply));
  } catch (err) {
    process.stdout.write(JSON.stringify({
      ok: false,
      error: `encode-reply: ${err.message}`,
    }) + '\n');
    process.exit(1);
  }
  sock.write(replyBytes);
  sock.write('\n');

  process.stdout.write(JSON.stringify({
    ok: true,
    saw_session: sessionLocator,
    saw_deliver_args0: typeof firstArg === 'string' ? firstArg : null,
    answer_pos: Number(answerN),
    sent_reply_args0: replyArgs,
  }) + '\n');

  sock.end();
  return true;
};

sock.on('connect', () => {
  // Send our start-session immediately.
  sock.write(startBytes);
  sock.write('\n');
});

sock.on('data', d => {
  inBuf = Buffer.concat([inBuf, d]);
  // Consume as many frames as are now complete.
  while (tryConsumeFrame()) { /* keep going */ }
  // If we have both expected frames, respond + close.
  if (!replied) {
    const haveDeliver = receivedFrames.some(f => f && f.label === 'op:deliver');
    if (haveDeliver) {
      replied = true;
      respond();
    }
  }
});

sock.on('error', err => {
  process.stdout.write(JSON.stringify({
    ok: false,
    error: `socket: ${err.message}`,
    received_count: receivedFrames.length,
  }) + '\n');
  process.exit(1);
});

sock.on('end', () => {
  if (!replied) {
    process.stdout.write(JSON.stringify({
      ok: false,
      error: 'connection ended before deliver was received',
      received_count: receivedFrames.length,
    }) + '\n');
    process.exit(1);
  }
});

// 30s safety timeout.
setTimeout(() => {
  process.stderr.write('peer-responder: timeout\n');
  process.exit(3);
}, 30_000).unref();
