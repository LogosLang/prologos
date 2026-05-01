#!/usr/bin/env node
//
// peer-pipelined.mjs — Phase 9: multi-turn pipelined RPC.
//
// Usage: node peer-pipelined.mjs <port>
//
// Like peer-responder.mjs but loops: keeps responding to incoming
// op:deliver frames until it receives op:abort. Each response is
// computed from the request's args.
//
// Protocol on this connection:
//   1. Connect.
//   2. Send our op:start-session.
//   3. Loop: read frame; if op:deliver, send reply; if op:abort, exit.
//   4. The parent's op:start-session is read but not echoed —
//      we already sent ours on connect.
//
// Reply rule:  request args=S, answer-pos=N → reply args=S+"-ack",
//              target=<desc:answer N>, ap=false, rm=false
//
// JSON summary on stdout (one line):
//   {
//     "ok": true,
//     "rounds_completed": <count>,
//     "saw_abort": true|false,
//     "args_seen":  ["ping", "ping-ack-tail", ...],
//     "args_replied":["ping-ack", "ping-ack-tail-ack", ...]
//   }

import '@endo/init';
import net from 'node:net';
import {
  encodeSyrup,
  decodeSyrup,
} from './node_modules/@endo/ocapn/src/syrup/js-representation.js';

const port = Number(process.argv[2]);
if (!Number.isInteger(port) || port < 1) {
  process.stderr.write(`peer-pipelined: bad port ${process.argv[2]}\n`);
  process.exit(2);
}

const mkRec = (label, values) => ({
  [Symbol.toStringTag]: 'Record',
  label,
  values,
});

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
const argsSeen = [];
const argsReplied = [];
let sawAbort = false;
let done = false;

const tryConsumeFrame = () => {
  for (let i = 0; i < inBuf.length; i++) {
    if (inBuf[i] === 0x0a) {
      const sliced = inBuf.subarray(0, i);
      inBuf = inBuf.subarray(i + 1);
      if (sliced.length === 0) return null;
      const payload = new Uint8Array(sliced.length);
      payload.set(sliced);
      try {
        return decodeSyrup(payload);
      } catch (err) {
        process.stdout.write(JSON.stringify({
          ok: false,
          error: `decode: ${err.message}`,
          raw_hex: Buffer.from(payload).toString('hex'),
        }) + '\n');
        process.exit(1);
      }
    }
  }
  return undefined;   // no complete frame yet
};

const handleFrame = (frame) => {
  if (!frame || frame.label == null) return;
  if (frame.label === 'op:start-session') {
    return; // ignore
  }
  if (frame.label === 'op:abort') {
    sawAbort = true;
    done = true;
    return;
  }
  if (frame.label === 'op:deliver') {
    // values = [target-desc, args, answer-pos, resolve-me]
    const argsValue = frame.values[1];
    const apDesc = frame.values[2];
    let answerN = null;
    if (apDesc && apDesc.label === 'desc:answer'
        && Array.isArray(apDesc.values)
        && typeof apDesc.values[0] === 'bigint') {
      answerN = apDesc.values[0];
    }
    if (answerN === null) {
      process.stdout.write(JSON.stringify({
        ok: false,
        error: 'deliver had no parseable answer-pos',
      }) + '\n');
      process.exit(1);
    }
    const inStr = typeof argsValue === 'string' ? argsValue : '?';
    const replyStr = `${inStr}-ack`;
    argsSeen.push(inStr);
    argsReplied.push(replyStr);

    const desc = mkRec('desc:answer', [answerN]);
    const reply = mkRec('op:deliver', [desc, replyStr, false, false]);
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
  }
};

sock.on('connect', () => {
  sock.write(startBytes);
  sock.write('\n');
});

sock.on('data', d => {
  inBuf = Buffer.concat([inBuf, d]);
  while (!done) {
    const f = tryConsumeFrame();
    if (f === undefined) break;
    if (f === null) continue;
    handleFrame(f);
  }
  if (done) {
    process.stdout.write(JSON.stringify({
      ok: true,
      rounds_completed: argsSeen.length,
      saw_abort: sawAbort,
      args_seen: argsSeen,
      args_replied: argsReplied,
    }) + '\n');
    sock.end();
    process.exit(0);
  }
});

sock.on('error', err => {
  process.stdout.write(JSON.stringify({
    ok: false,
    error: `socket: ${err.message}`,
    rounds_completed: argsSeen.length,
  }) + '\n');
  process.exit(1);
});

sock.on('end', () => {
  if (!done) {
    process.stdout.write(JSON.stringify({
      ok: false,
      error: 'connection ended before abort',
      rounds_completed: argsSeen.length,
      args_seen: argsSeen,
      args_replied: argsReplied,
    }) + '\n');
    process.exit(1);
  }
});

setTimeout(() => {
  process.stderr.write('peer-pipelined: timeout\n');
  process.exit(3);
}, 30_000).unref();
