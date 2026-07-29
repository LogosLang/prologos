#!/usr/bin/env node
//
// peer-bootstrap-gift.mjs — Phase 52b: cross-impl wire-shape check.
//
// Listens on a TCP port. The Racket-side test connects and sends:
//   1. op:start-session
//   2. op:deliver to <desc:export 0> with args = (symbol "deposit-gift",
//      nat 99, desc:export 7) — i.e., a deposit-gift method call on
//      bootstrap.
//   3. op:deliver to <desc:export 0> with args = (symbol "withdraw-gift",
//      nat 99) and ap = <desc:answer 4> — i.e., a withdraw-gift method
//      call on bootstrap, asking for the gift to be delivered at q-pos 4.
//
// This script decodes each frame via `@endo/ocapn`'s Syrup decoder and
// verifies the structural shape matches what @endo would treat as the
// canonical bootstrap-method dispatch. Emits JSON summary on stdout
// and exits 0 if shape matches, 1 otherwise. (We do NOT exercise
// @endo's deposit-gift / withdraw-gift HANDLERS — those require signed
// HandoffReceive envelopes + key pair management beyond this gate's
// scope. The wire-shape compatibility is what's being validated.)

import '@endo/init';
import net from 'node:net';
import {
  decodeSyrup,
} from './node_modules/@endo/ocapn/src/syrup/js-representation.js';

const port = Number(process.argv[2]);
if (!Number.isInteger(port) || port < 1) {
  process.stderr.write(`peer-bootstrap-gift: bad port ${process.argv[2]}\n`);
  process.exit(2);
}

const GIFT_ID = 10n;
const GIFT_REFR_ID = 7n;
const RESOLVER_ANSWER_POS = 4n;
const BOOTSTRAP_EXPORT = 0n;

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

const isRecord = (v, label) =>
  v && v[Symbol.toStringTag] === 'Record' && v.label === label;

const summarize = () => {
  if (summarized) return;
  summarized = true;

  const session = receivedFrames.find(f => isRecord(f, 'op:start-session'));

  // Find op:deliver frames targeting bootstrap (desc:export 0).
  const delivers = receivedFrames.filter(f =>
    isRecord(f, 'op:deliver')
      && f.values && f.values[0]
      && isRecord(f.values[0], 'desc:export')
      && f.values[0].values && f.values[0].values[0] === BOOTSTRAP_EXPORT);

  // Find the deposit-gift call: args[0] should be a symbol whose
  // description is "syrup:deposit-gift" — @endo's syrup decoder
  // prefixes decoded symbols with the "syrup:" namespace.
  const isSymWithSuffix = (v, suffix) =>
    typeof v === 'symbol'
      && (v.description === suffix
          || v.description === `syrup:${suffix}`);

  const deposit = delivers.find(f => {
    const args = f.values && f.values[1];
    if (!Array.isArray(args)) return false;
    return isSymWithSuffix(args[0], 'deposit-gift');
  });

  const withdraw = delivers.find(f => {
    const args = f.values && f.values[1];
    if (!Array.isArray(args)) return false;
    return isSymWithSuffix(args[0], 'withdraw-gift');
  });

  // Verify shape: deposit args = (Symbol deposit-gift, BigInt gift-id, Record desc:export)
  let depositShapeOk = false;
  let depositGiftId = null;
  let depositGiftRefrId = null;
  if (deposit) {
    const args = deposit.values[1];
    if (args.length >= 3
        && typeof args[1] === 'bigint'
        && isRecord(args[2], 'desc:export')
        && args[2].values && typeof args[2].values[0] === 'bigint') {
      depositShapeOk = true;
      depositGiftId = args[1];
      depositGiftRefrId = args[2].values[0];
    }
  }

  // Verify shape: withdraw args = (Symbol withdraw-gift, BigInt gift-id),
  // and op:deliver's ap = <desc:answer N>.
  let withdrawShapeOk = false;
  let withdrawGiftId = null;
  let withdrawApPos = null;
  if (withdraw) {
    const args = withdraw.values[1];
    const ap = withdraw.values[2];
    // The answer position is a BARE integer per the spec; this used to
    // require `<desc:answer N>`, which is the form our encoder wrongly
    // produced and no conforming peer sends.
    if (args.length >= 2
        && typeof args[1] === 'bigint'
        && typeof ap === 'bigint') {
      withdrawShapeOk = true;
      withdrawGiftId = args[1];
      withdrawApPos = ap;
    }
  }

  const ok = !!(session && deposit && withdraw && depositShapeOk && withdrawShapeOk
                && depositGiftId === GIFT_ID
                && depositGiftRefrId === GIFT_REFR_ID
                && withdrawGiftId === GIFT_ID
                && withdrawApPos === RESOLVER_ANSWER_POS);

  process.stdout.write(JSON.stringify({
    ok,
    saw_session: !!session,
    saw_deposit: !!deposit,
    saw_withdraw: !!withdraw,
    deposit_shape_ok: depositShapeOk,
    withdraw_shape_ok: withdrawShapeOk,
    deposit_gift_id: depositGiftId !== null ? Number(depositGiftId) : null,
    deposit_gift_refr: depositGiftRefrId !== null ? Number(depositGiftRefrId) : null,
    withdraw_gift_id: withdrawGiftId !== null ? Number(withdrawGiftId) : null,
    withdraw_ap_pos: withdrawApPos !== null ? Number(withdrawApPos) : null,
  }) + '\n');

  sock.end();
  process.exit(ok ? 0 : 1);
};

sock.on('connect', () => {
  // Nothing to send; we just receive Racket's frames.
});

sock.on('data', d => {
  inBuf = Buffer.concat([inBuf, d]);
  while (tryConsumeFrame()) { /* keep going */ }
  if (receivedFrames.length >= 3) summarize();
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
  process.stderr.write('peer-bootstrap-gift: timeout\n');
  process.exit(3);
}, 60_000).unref();
