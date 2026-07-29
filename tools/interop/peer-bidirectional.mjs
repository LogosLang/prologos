#!/usr/bin/env node
//
// peer-bidirectional.mjs — Phase 29: bidirectional peer-to-peer interop.
//
// Both sides act as questioner AND responder on the same connection:
//   Node   QUESTIONS Racket → Racket answers (responder side)
//   Racket QUESTIONS Node   → Node answers   (questioner side)
//
// Wire flow:
//   1. Connect to 127.0.0.1:<port>.
//   2. Send our op:start-session.
//   3. Send our op:deliver <desc:export 0> "node-q" <desc:answer 100> false
//      (Node's question to Racket; Racket has an echo actor at export 0).
//   4. Read 3 frames from Racket:
//        a. Racket's op:start-session
//        b. Racket's reply to OUR question:
//           op:deliver <desc:answer 100> "node-q" false false
//        c. Racket's OWN question:
//           op:deliver <desc:export 0> "racket-q" <desc:answer N> false
//      (N is Racket's q-pos; Racket targets one of OUR exports — we
//      don't actually have any exports tabled, but for this test we
//      just compute a reply from the args string.)
//   5. Reply to Racket's question:
//        op:deliver <desc:answer N> "racket-q-bidi-ack" false false
//   6. Print one-line JSON summary; exit 0.

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
// conforming peer sends. The spec form ONLY is accepted: taking both would
// keep these green if the wrapping came back.
const answerPosOf = (v) => (typeof v === 'bigint' ? v : null);

// The args slot is a LIST, always -- a peer iterates it directly.
const argsList = (a) => (Array.isArray(a) ? a : (a && Array.isArray(a.values) ? a.values : null));
const argsFirst = (a) => { const l = argsList(a); return l && l.length ? l[0] : null; };


const port = Number(process.argv[2]);
if (!Number.isInteger(port) || port < 1) {
  process.stderr.write(`peer-bidirectional: bad port ${process.argv[2]}\n`);
  process.exit(2);
}

const NODE_Q_POS = 100n;
const NODE_Q_ARGS = 'node-q';

const mkRec = (label, values) => ({
  [Symbol.toStringTag]: 'Record',
  label,
  values,
});

const startSession = mkRec('op:start-session', [
  '0.1',
  'tcp-testing-only:peer-node-bidirectional',
]);

const nodeQuestion = mkRec('op:deliver', [
  mkRec('desc:export', [0n]),
  NODE_Q_ARGS,
  mkRec('desc:answer', [NODE_Q_POS]),
  false,
]);

let startBytes, nodeQBytes;
try {
  startBytes = Buffer.from(encodeSyrup(startSession));
  nodeQBytes = Buffer.from(encodeSyrup(nodeQuestion));
} catch (err) {
  process.stdout.write(JSON.stringify({ ok: false, error: `encode-out: ${err.message}` }) + '\n');
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

  // Find Racket's three frames: session + reply-to-our-Q + Racket's Q.
  // Reply-to-our-Q targets desc:answer NODE_Q_POS.
  // Racket's Q targets desc:export and has a desc:answer answer-pos.
  const session = receivedFrames.find(f => f && f.label === 'op:start-session');
  const replyToNodeQ = receivedFrames.find(f =>
    f && f.label === 'op:deliver'
      && f.values && f.values[0] && f.values[0].label === 'desc:answer'
      && f.values[0].values && f.values[0].values[0] === NODE_Q_POS);
  const racketQ = receivedFrames.find(f =>
    f && f.label === 'op:deliver'
      && f.values && f.values[0] && f.values[0].label === 'desc:export'
      // and it has an answer-pos (third element is desc:answer or desc:export, not bool false)
      && answerPosOf(f.values[2]) !== null);

  const sessionLocator = session && Array.isArray(session.values)
    ? String(session.values[1]) : null;

  const replyArgs0 = replyToNodeQ && replyToNodeQ.values
    ? replyToNodeQ.values[1] : null;

  // Extract Racket's q-pos from racketQ's answer-pos field.
  let racketQPos = null;
  let racketQArgs = null;
  if (racketQ && Array.isArray(racketQ.values) && racketQ.values.length >= 3) {
    const firstArg = argsFirst(racketQ.values[1]);
    racketQArgs = typeof firstArg === 'string' ? firstArg : null;
    racketQPos = answerPosOf(racketQ.values[2]);
  }

  if (racketQPos === null) {
    process.stdout.write(JSON.stringify({
      ok: false,
      error: 'no parseable Racket question in received frames',
      frame_labels: receivedFrames.map(f => f && f.label),
    }) + '\n');
    process.exit(1);
  }

  // Reply to Racket's question. We compute "<racketQArgs>-bidi-ack".
  const replyArgs = (typeof racketQArgs === 'string' ? racketQArgs : 'racket-q') + '-bidi-ack';
  const replyToRacketQ = mkRec('op:deliver', [
    mkRec('desc:answer', [racketQPos]),
    replyArgs,
    false,
    false,
  ]);

  let replyBytes;
  try {
    replyBytes = Buffer.from(encodeSyrup(replyToRacketQ));
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
    saw_reply_to_node_q: replyArgs0,
    saw_racket_q_args: racketQArgs,
    saw_racket_q_pos: Number(racketQPos),
    sent_reply_to_racket_q: replyArgs,
  }) + '\n');

  sock.end();
  process.exit(0);
};

sock.on('connect', () => {
  // Send our session + our question immediately.
  sock.write(startBytes);
  sock.write('\n');
  sock.write(nodeQBytes);
  sock.write('\n');
});

sock.on('data', d => {
  inBuf = Buffer.concat([inBuf, d]);
  while (tryConsumeFrame()) { /* keep going */ }
  // Wait until we have all 3 expected Racket frames.
  const haveSession = receivedFrames.some(f => f && f.label === 'op:start-session');
  const haveReplyToOurQ = receivedFrames.some(f =>
    f && f.label === 'op:deliver'
      && f.values && f.values[0] && f.values[0].label === 'desc:answer'
      && f.values[0].values && f.values[0].values[0] === NODE_Q_POS);
  const haveRacketQ = receivedFrames.some(f =>
    f && f.label === 'op:deliver'
      && f.values && f.values[0] && f.values[0].label === 'desc:export'
      && answerPosOf(f.values[2]) !== null);
  if (haveSession && haveReplyToOurQ && haveRacketQ) summarize();
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
      error: 'connection ended before all 3 expected frames received',
      received_count: receivedFrames.length,
      received_labels: receivedFrames.map(f => f && f.label),
    }) + '\n');
    process.exit(1);
  }
});

// 60 s safety timeout.
setTimeout(() => {
  process.stderr.write('peer-bidirectional: timeout\n');
  process.exit(3);
}, 60_000).unref();
