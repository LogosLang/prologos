#!/usr/bin/env node
//
// peer-send.mjs — Node side of Phase 5 Test B.
//
// Usage: node peer-send.mjs <case>
//   <case> ∈ { "op-abort", "op-gc-answer", "op-deliver-only" }
//
// 1. TCP-listen on an ephemeral localhost port.
// 2. Print the chosen port on stdout (one line, "<port>\n") so
//    the Racket parent can dial it.
// 3. On the FIRST inbound connection: encode the chosen CapTP
//    op via @endo/ocapn's encodeSyrup, write the bytes + '\n',
//    close, exit 0.
// 4. If anything goes wrong, print "ERR <reason>" on stdout and
//    exit non-zero.
//
// Hardcoded test cases (must match the Racket test's expectations):
//   op-abort         → <op:abort "phase-5-says-hi">
//   op-gc-answer     → <op:gc-answer 7>
//   op-deliver-only  → <op:deliver-only <desc:export 0> "ping">

import '@endo/init';
import net from 'node:net';
import { encodeSyrup, SyrupSelectorFor } from './node_modules/@endo/ocapn/src/syrup/js-representation.js';

const mkRec = (label, values) => ({
  [Symbol.toStringTag]: 'Record',
  label,
  values,
});

const cases = {
  'op-abort': mkRec('op:abort', ['phase-5-says-hi']),
  'op-gc-answer': mkRec('op:gc-answer', [7n]),
  'op-deliver-only': mkRec('op:deliver-only', [
    [mkRec('desc:export', [0n]), 'ping'],
  ]),
};

const which = process.argv[2];
const value = cases[which];
if (!value) {
  process.stdout.write(`ERR unknown-case ${which}\n`);
  process.exit(2);
}

let bytes;
try {
  bytes = Buffer.from(encodeSyrup(value));
} catch (err) {
  process.stdout.write(`ERR encode ${err.message}\n`);
  process.exit(2);
}

const server = net.createServer(sock => {
  sock.write(bytes);
  sock.write('\n');
  sock.end();
  // Defer server close until the socket is fully flushed.
  sock.on('close', () => {
    server.close();
    process.exit(0);
  });
});

server.listen(0, '127.0.0.1', () => {
  const port = server.address().port;
  process.stdout.write(`${port}\n`);
});

// Safety: 30s overall timeout in case the parent never connects.
setTimeout(() => {
  process.stderr.write('peer-send: timeout — no parent connection within 30s\n');
  process.exit(3);
}, 30_000).unref();
