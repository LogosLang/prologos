# OCapN implementation — known gaps, shortcomings and workarounds

**Written 2026-07-28 against `ad673edb`. Remediated 2026-07-29; see § Status.**
Upstream conformance suite: 24/24. Unit suite: 9623 pass.

Passing the conformance suite is the *premise* of this document, not its
conclusion. Everything below is something that passed and was nevertheless
wrong, fragile, unfinished, or in the wrong place.

Findings are ranked:

| | |
|---|---|
| **CRITICAL** | wrong answers or data loss on input a peer can send |
| **HIGH** | breaks on realistic non-test input |
| **MEDIUM** | fragile; will bite a future change |
| **LOW** | tidiness, stale docs |

Each entry says **what breaks it** concretely. An entry without a concrete
failing input is not a finding and should be deleted rather than softened.

---

## Status (2026-07-29)

The inventory below was written first and fixed second. **Most of it is now
fixed**; §"Still open" lists what is not, with the reason in each case.
Sections 0 and 1 are preserved AS WRITTEN on 2026-07-28 — they are the record
of what was found, not a description of the code today. Where a finding's text
is now false because the finding was acted on, that is the intended outcome.

Three commits: `bae33ae3` (Prologos library + FFI), `beeb3855` (test server,
CI, Node peers), `29591985` (acting on the adversarial verification pass).

### The three critical themes are closed

**A. The handoff trust chain.** The exporter verified a `desc:handoff-receive`
against a key it read out of the `desc:handoff-give` nested inside that same
receive, and never checked the give's own signature — so a withdrawal was
entirely self-attested. Closing it needed a key the attacker does not choose,
and there is exactly one: the public key of the peer that deposited the gift.
`op:start-session` now carries the peer's session pubkey, `BridgeState`
retains it, a `GiftEntry` records the key of the peer that deposited it, and a
parked withdrawal keeps the signed give until the deposit arrives to supply
the key. Chain: gifter's session key → the give; the give's receiver-key → the
receive. Verified against the reference, which signs the give with
`g2e_session.private_key` — exactly the key we now record.

**B. The gift namespace.** `used:` and `park:` prefixes shared one
String-keyed table with peer-supplied gift ids, under a comment reasoning that
a constructed prefix "cannot collide with a gift id, because gift ids come
from the peer as opaque bytes". That is backwards. The kind is now a FIELD,
so collision is unrepresentable rather than unlikely; park and used entries
are per-connection (publishing them globally was a live cross-connection bug
needing no attacker, since every connection's vat seeds its promise ids the
same); and the replay identity length-prefixes its parts.

**C. The codec.** Latin-1 length prefixes throughout; `encode` and `re-encode`
collapsed to one payload reading once `decode-record-with` stopped conflating
`<tag [a b]>` with `<tag a b>`; no null on the wire; a poison record instead of
the empty string for values that must never reach it; strict `decode-value`;
canonical dict ordering outbound only. `int-to-nat` is O(1), which closes the
18-byte remote stall.

### What the fixes exposed, and what that cost

Fixing the encoder took the conformance suite from 24 to 23, and the failure
was worth more than the fix. Enlivening a sturdyref opens a socket, so export
position 5 deliberately has no vat actor and the driver answers it out of
band — but `run-step` handed the op to `connection-step` as well, the vat found
no actor, and captp-core BROKE the peer's promise on the enliven frame itself,
beating the driver's `fulfill`. That break had always been emitted. It was
invisible because it was unparseable: the old encoder wrapped a record's
argument sequence in a list, so upstream dropped the frame. A correct encoder
turned a silently-ignored malformed break into a well-formed one.

It took a worktree-pinned baseline and a diff of the outbound frames to find;
three attempts to reason it out from the code alone were all wrong. **The
lesson is the one the document already argues elsewhere: a malformed frame and
an absent frame are indistinguishable to everything except the bytes.**

Two more of the same shape: the args slot and the answer position were each
wrong in one encoder and right in another, and had stayed wrong because
in-tree JS fixtures pinned the wrong forms. §1.10 finding 9 called that out
in the abstract; it turned out to be load-bearing.

### Corrections to this document

Three claims below are wrong, and are left in place with the correction here
rather than quietly edited:

- **§0.3 says the enlivener "works because the *server* intercepts the deliver
  in `run-step` before `connection-step` ever sees it."** `connection-step` did
  see it. The interception queued a dial and then fell through. The substance —
  that position 5 has no actor and this is load-bearing — was right; the
  mechanism was not.
- **§1.2 finding 19 lists six functions as having "no caller anywhere".** True
  as stated (`lib/` and `tools/`), but five of them have test callers and are
  public API, not dead code. Only `deliver-with-ap` was genuinely unreferenced.
- **§1.3 finding 10's exemplar was already corrected in its own note**, and the
  note is right: the realistic dropped input is a pipelined gift, not a
  `desc:import-object`.

One further correction, to the fix rather than the finding: **§1.2 M3 was
"fixed" by echoing the queued deliver's `ap`/`rm` into the forwarded frame, and
that was wrong.** A forwarded deliver is a new message with us as the sender,
so those slots name our tables, not the peer's. The verification pass caught
it (our own decoder rejected the result); it is reverted, and the finding is
open below.

### Still open

Thirteen entries were open after the first remediation pass. **Ten are closed,
two dissolved under premises that stopped holding, and one is half closed.**
What is left is a single architectural problem and the two entries downstream
of it.

**Genuinely open — one problem, three entries:**

| Finding | Why it is still open |
|---|---|
| §0.2 gifter/receiver roles live in Racket | **First primitive built.** `eff-connect` exists, the vat carries a pending-dial list, and `beh-sturdyref-enlivener` is a real behaviour that asks for its own connection. Seeding it at export 5 is blocked on one thing, in the vat model rather than the driver — see below. `eff-send-on` and `eff-sign` are untouched, and the connection registry is still a Racket hash. |
| §1.7 M8 every frame is processed twice | Same root. Narrowed — the Racket side now only acts on frames it can match structurally, and `run-step` no longer hands an enliven to captp-core at all — but both halves still run on the same bytes. |
| §1.7 M7 enliven slots 900+ are unregistered | Same root: the enlivener must hand out a real exported resolve-me from the connection's export table instead of a Racket counter. Its two live consequences are gone — captp-core no longer breaks on the answer (a deliver with no reply channel to an export we lack is dropped, not reflected), and the slot base is above anything the vat allocates until ~890 allocations on one connection. What remains is that the reservation is by convention, not construction. |

**§0.2 — an enlivener cannot answer, and `ActStep` cannot say so.** This is
the concrete blocker, found by building the thing and running the gate:

`eff-connect` is done. A behaviour describes the connection it wants, the vat
records it in a pending-dial list, and the driver drains it between steps —
the same shape `eff-send-remote`/`vat-outbound` already uses, so the vat stays
pure. `beh-sturdyref-enlivener` is a real behaviour, and it gates on the
`ocapn-sturdyref` label because this is the one path that opens an outbound
TCP connection on peer-chosen bytes.

What it cannot do is *not answer*. The reply the peer waits for is a signed
`desc:handoff-give`, which only the driver can build — it needs the keypair
and the exporter connection. The behaviour's job ends at "please connect". But
every `ActStep` carries a return value and `step-after-act` settles the answer
promise with it unconditionally, so seeding the actor at export 5 makes
captp-core answer the enliven immediately with the wrong thing, beating the
real reply. Measured, not predicted: the conformance suite goes 24 → 23, with
the peer receiving an echoed sturdyref where it expects a sig-envelope.

So the driver interception stays, and the next step is a MODEL change:
`ActStep` needs a third outcome beside a value and a break — "no answer yet".
Returning `syrup-null` is not it; `no-op` already returns null and several
behaviours rely on that settling their promise.

That one change unblocks seeding the enlivener, which is most of §1.7 M8 (the
two implementations stop both acting on the enliven frame) and all of §1.7 M7
(export 5 gets a real actor, so the slot stops being reserved by convention).

**§1.2 M3 — closed, on the second attempt.** A forwarded deliver is a NEW
message with us as the sender, so the queued deliver's `ap`/`rm` cannot be
echoed — they name the peer's tables. What is correct is to allocate a fresh
promise P for the forwarded send and register it in BOTH question tables:
`bs-add-outbound-question P P` so the peer answers our question, and
`bs-add-question <peer's ap> P` so that when P settles the pump emits
`<op:deliver <desc:answer ap> value f f>` with no new code at all. The peer's
resolver, if it named one, becomes a listener on P. Both tables pointing at
the same promise is what makes the round trip work.

It took two attempts, and the first one is the part worth keeping:

The whole change (~25 sites threading `BridgeState` through `ForwardEffect`,
`PumpResult` and the four pump loops) was written in one go, elaborated
cleanly, and then failed at IMPORT with a bare "Unbound variable". One cause
was `bs-handle-listen-with-late-fire` taking four arguments where I passed
three — **under-application in Prologos produces a stuck term, not an arity
error**. Fixing that one call did not clear it, and with no location in the
message I reverted rather than leave the tree red.

The second attempt landed the identical design by applying it in four steps
and testing the import after each: widen `ForwardEffect`; thread it into
`pump-one`; add the helpers; wire them in and widen `PumpResult`. Every step
was clean. Whatever the second mistake was, it did not survive being written
a second time — which is the actual lesson: at the import boundary an
under-application, an unbound name and a stale `.pnet` all present as the
same bare message with no location, so bisecting by construction beats
diagnosing by inspection.

`dispatch-answer-target` (resolution to `<desc:answer M>`) still forwards
without a reply channel. That case chains the pipeline onto the peer's own
question rather than terminating it, so it is a different shape; it is not
covered by this fix and is not claimed to be.

**Closed:** §1.1 #5 / §1.10 #3 (floats and sets), §1.4 #6 (`wants_partial`),
§1.6 M8 (undecodable frames abort), §1.10 #10 (the plain-value reason names
its value), §1.10 #12 (locator hints are a map), §1.10 #11 residue (fixture
coverage and the Latin-1 harness), §1.2 M3 (the forwarded reply channel).
§1.10 #8 is half closed — the signed handshake now has direct unit coverage,
which was the real hole; the Node peers' dialect is redundancy.

**Two entries dissolved rather than fixed**, because their premises stopped
holding — recorded here rather than silently dropped:

- **§1.9 #4 (`:requires (CryptoCap)`) is a LANGUAGE gap, not an OCapN one.**
  Annotating an FFI binding makes the whole module unimportable from a
  `.prologos` file: the requirement propagates to the caller and nothing can
  introduce a root capability. Wrapping the bindings in same-module functions
  does not help, and neither does importing the capability type — both were
  tried. And `prologos::ocapn::tcp-testing`, cited in this document as proof
  the convention is live, **cannot be imported either**; nothing imports it,
  and its test loads it through the sexp path, which does not hit the check.
  That module now carries a characterization test asserting the WS-mode
  failure, so the gap has a witness and will fail loudly when the language
  grows a root capability form.
- **§1.8 M2 (one process-wide session keypair) has lost its consequence.** The
  stated failure was that session-ids collapse and the handoff replay guard,
  keyed on session, then refuses a peer's legitimate second handoff. That
  guard is per-connection now (theme B), so two connections no longer share a
  replay set. What remains is a conformance deviation — upstream mints a key
  per session — with no failing input, which by this document's own standard
  is not a finding. Minting per connection also costs a `process-string` per
  accept, which the suite's wall-clock budget would notice.

### Newly found, while fixing

Not in the original inventory:

1. **HIGH | `finish-fetch-answer!` spliced an integer into `bytes-append`.** Raised
   on every gifter-side enliven and was swallowed by the surrounding guard, so
   the fulfill was never sent — the mechanism by which theme A's fix first
   looked like a regression.
2. **HIGH | `op:gc-answers` had no arity gate** where every other op got one, so
   `<op:gc-answers [1+] [2+]>` decoded as `[1]` and dropped the second list.
3. **MEDIUM | `try-enliven!` accepted only `desc:import-object` as a resolve-me**,
   silently dropping an enliven whose resolver was a promise — a new silent
   drop introduced while fixing silent drops.
4. **MEDIUM | `tools/check-parens.sh` hardcoded a macOS Racket path**, so on any
   other machine it reported a delimiter error for every balanced file and the
   pre-commit hook that calls it was a silent no-op. Fixed.
5. **LOW | the `.pnet` cache masquerades as a forward reference.** After a struct
   arity change, importing a module fails with a bare "Unbound variable" while
   the module itself processes with zero errors. `rm -rf data/cache/pnet` is
   the fix; this is the second sighting (pitfall #47) and it cost time again.
   It cost time a THIRD way later: an arm with a genuinely unbound variable
   presents identically, so the cache is both a cause of that symptom and a
   plausible-looking excuse for it. Clearing twice is what separates them.
6. **MEDIUM | `prologos::ocapn::tcp-testing` cannot be imported**, and neither
   can any module whose FFI bindings carry `:requires`. See § Still open.
   Its test did not catch this because it loads through the sexp `imports`
   path; the WS `require` path is the one that fails. A module with no
   importers has no witness for its own breakage.
7. **LOW | a non-exhaustive match in `behavior.prologos`** — the elaborator
   reports `Hole ??__match-fail : ActStep` on every load of anything that
   depends on it. It predates all of this work and is not in the inventory,
   but it is the same silent-wrong-answer class the inventory is about.

### Method note on the fix pass

Seven repair agents on file-disjoint surfaces, each followed by an adversarial
verifier that re-opened every file and tried to refute the report. The
verifiers earned their place: they caught a claimed fix that was not in the
file at all, the `forward-deliver-bytes` error above, four comments that my own
fixes had falsified in the same sweep, a missing arity gate, and a large
behavioural change that shipped with zero tests. Every "BROKEN" they reported
that I could reproduce was real.

---

## 0. The three structural gaps

> **As-written 2026-07-28.** 0.1 is fixed (the allow-list is drift-checked
> against the modules it targets). 0.2 is unchanged and is still the largest
> piece of debt here. 0.3's substance was right and its stated mechanism was
> wrong — see § Corrections.

These are not bugs. They are places where the implementation is shaped by the
test suite rather than by the protocol, and no amount of local fixing addresses
them.

### 0.1 The conformance gate is an allow-list, not the suite — MEDIUM

`tools/interop/ocapn-run-tests.py` names all 24 tests explicitly. Upstream's own
`test_runner.py` can only load a whole *module*, and it imports the Tor onion
netlayer unconditionally, which is unbuildable in our containers — hence the
allow-list.

**Consequence**: "24/24" means *all 24 tests in the four modules we target, each
named in that file*. It does not mean "everything upstream ships", and a test
added upstream will not appear here until someone adds it by hand.

**Fix shape**: a periodic job that diffs the upstream module's `test_*` methods
against `SELECTED` and fails on drift. Cheap, and it converts a silent omission
into a loud one.

### 0.2 Two roles live in Racket, not in Prologos — HIGH (architectural)

The third-party-handoff **gifter** and **receiver** roles, the crossed-hellos
mitigation, and outbound connection management all live in
`tools/interop/run-ocapn-test-server.rkt` — hand-built frame bytes, hand-rolled
Syrup slicing, Racket hash tables.

The exporter role, by contrast, lives in `captp-core.prologos` and is expressed
in the language.

**Why it happened**: a Prologos behaviour is pure and cannot open a socket, sign
with a held key, or write to a connection other than the one being serviced. The
FFI-queue pattern (`ocapn-dial-ffi.rkt`) covers the first; nothing covers the
rest.

**Consequence**: those roles are not self-hosting, are not covered by the unit
suite, and cannot be reasoned about with the rest of the language. This is the
single largest piece of debt in the OCapN work.

**Fix shape**: the effect vocabulary needs `eff-connect`, `eff-send-on` (a named
connection) and `eff-sign`, plus a connection registry as a first-class cell.
That is a design task, not a refactor.

### 0.3 Export position 5 has no vat actor — MEDIUM

`swiss-num-export` maps the sturdyref enlivener's swiss-num to export `5N`
(`racket/prologos/lib/prologos/ocapn/captp-core.prologos`), but `seeded-vat`
(`interop-driver.prologos`) seeds actors at 1, 2, 3, 4 and 7 only. The enlivener
"works" because the *server* intercepts the deliver in `run-step` before
`connection-step` ever sees it.

**What breaks it**: any peer that fetches position 5 and then delivers to it
expecting an ordinary actor response. Also: anything that later seeds a real
actor at 5 will find the server intercepting its messages first.

---


## 1. Findings by surface

> **As-written 2026-07-28, preserved unedited.** Most of what follows is now
> fixed; § Status above is authoritative for the current state. Read this
> section as the record of what was found and why it mattered, not as a
> description of the code today.

Each subsection holds the findings that **survived adversarial verification** —
a second agent opened every cited file, checked every line number and quote, and
was asked to refute rather than agree. Its **MISSED** list follows: things the
first pass should have caught and did not, found by the verifier while checking.

Claims the verifier refuted or demoted have been dropped; where it corrected a
severity or a citation, the corrected form is what appears here.

---

### 1.1 Syrup value model + wire codec

#### Verified findings

(copy verbatim)

1. **CRITICAL | wrong-encoding** | `syrup-wire.prologos:88-89` | `syrup-string`/`syrup-symbol` prefix with `str::bytes-length` (UTF-8) while the entire stack is Latin-1-one-byte-per-code-point, so our encoder emits frames our own decoder rejects. Verified: `encode (syrup-string "é")` → `"2\"é"` (3 code points), `decode-value` of it → `none`, `str::length` of it → 3; and `(string->bytes/latin-1 (string (integer->char #x3B1)))` raises `string cannot be encoded in Latin-1`, so the value pinned by `tests/test-ocapn-syrup-wire.rkt:193-197` can never be sent. Latin-1 convention asserted at `racket/prologos/ocapn-frame-ffi.rkt:14-16` and applied outbound at `tools/interop/run-ocapn-test-server.rkt:151`, `:249`.

2. **CRITICAL | data-loss** | `syrup-wire.prologos:217`, `:229-233`, `decode-record-with:443` | `re-encode` splices away the brackets of a record whose single argument is a list, turning a 1-arg record into an n-arg one, while its own `:doc` at `:230` claims "Inverse of `decode-value`". Verified: `re-encode (decode-value "<1'f[1+2+]>")` → `"<1'f1+2+>"`. On the signature path at `captp-core.prologos:1709` and `interop-driver.prologos:220`.

3. **HIGH | silent-failure** | `syrup-wire.prologos:110-111`, `:78-79` | `encode` returns `""` for `syrup-refr`/`syrup-promise`, deleting the value from its enclosing list/record with no error; the documented mitigation `encode-safe` has zero production callers (`grep encode-safe|encodable?` over all `.prologos` hits only `examples/2026-04-29-syrup-wire-acceptance.prologos:100,103`). Verified: `encode (syrup-list [syrup-refr 3, syrup-int 1])` → `"[1+]"`. `syrup-promise` is live actor state at `captp-core.prologos:2870` and `interop-driver.prologos:159`.

4. **HIGH | spec-deviation** | `handshake.prologos:142-151` | `ocapn-peer` hints are emitted as a syrup-list of 2-element lists with **symbol** keys; the reference requires a dict with string keys (`contrib/syrup.py:104-107`, consumed as `ocapn_peer.hints["host"]` at `netlayers/testing_only_tcp.py:66`). Passes only because the suite's `connect()` is always called on the command-line URI (`test_runner.py:26-36`), never on a peer parsed from our wire.

5. **MEDIUM | unimplemented** | `syrup-wire.prologos:466-505` | Sets (`#…$`) and floats (`D`/`F`) have no arm in `decode-at`; both return a bare `none`. Verified: `decode-value "#1+2+$"` → `none`, `decode-value "D12345678"` → `none`. Reference implements both (`contrib/syrup.py:120-125`, `:230-255`).

6. **MEDIUM | silent-failure** | `syrup-wire.prologos:509-515` | `decode-value` never consults `d-consumed`, so trailing garbage after a valid value parses clean. Verified: `decode-value "nGARBAGE!!"` → `some syrup-null`; `decode-value "5+xyz"` → `syrup-int 5`. Compounded by every failure in the codec collapsing to the same undiscriminated `none` (`:328`, `:383`, `:446`, `:505`).

7. **MEDIUM | duplication/drift** | `syrup-wire.prologos:466` vs `handshake.prologos:314-332` vs `run-ocapn-test-server.rkt:281` vs `ocapn-framing.rkt:170-185` | Four independent Syrup scanners with four *different* form-coverage sets and nothing forcing agreement — see the drift table under MISSED M1.

8. **MEDIUM | spec-deviation** | `syrup-wire.prologos:108`, `:235` | Outbound dicts are never sorted; Syrup canonicalises by sorted encoded key (`contrib/syrup.py:90-103`). Verified: `encode` of a `{port…host…}` dict → `"{4\"port1\"14\"host1\"h}"`, non-canonical. `syrup.prologos:53-56`'s "we neither re-sort nor re-order" justification is valid for the inbound path only. Also nothing enforces even parity: `decode-value "{1+}"` → a one-element `syrup-dict`.

9. **LOW | stale-comments** | `syrup.prologos:17-18`; `syrup-wire.prologos:22`; `syrup-wire.prologos:24-28`; `handshake.prologos:241-245`; `handshake.prologos:143` | Five header comments contradict the code they head; the dangerous one is `syrup-wire.prologos:24-28`, which claims "We use `str::length` (code-point count)" while `:88` uses `str::bytes-length` — a reader would conclude finding 1 is already handled correctly.

10. **LOW | robustness** | `syrup-wire.prologos:302-316` | `read-digits` accepts unbounded leading zeros; `decode-value "00000000005\"hello"` → `syrup-string "hello"`. Non-canonical, and canonicality is load-bearing on the signature path.

---

#### Also missed by the first pass

The report claims all findings are "VERIFIED"; it under-covered **resource/lifecycle (7)**, **concurrency (8)**, **silent failure (4)** in the Racket harness, and it stopped at three parsers when the drift is four-way.

**M1. HIGH | resource/DoS | `syrup.prologos:250-262` + `:264-280` | `int-to-nat` is unary structural recursion over a fully peer-controlled integer; the comment asserting the bound enforces nothing.** The comment at `:250-252` says "Only used for table-position decoding (small Nats) so the cost is acceptable" — nothing bounds it. `wire-nat` is applied to inbound `desc:export` / `desc:answer` / `desc:import-object` payloads at `captp-core.prologos:983`, `:990`, `:1002`, `:1218`, `:1533`. Measured on the real module:

| N | wall |
|---|---|
| 10 | 2 ms |
| 1 000 | 36 ms |
| 5 000 | 193 ms |
| 20 000 | 1 398 ms |

Superlinear. `<op:deliver <desc:export 100000000+> …>` — 18 wire bytes — hangs the connection handler indefinitely. This is exactly the report's own category 5 (invariant asserted, not enforced) plus 7 (unbounded growth), and it is more severe than anything it listed at HIGH.

**M2. HIGH | spec-deviation + drift | `syrup-wire.prologos:83` / `decode-at:473-474` vs `ocapn-framing.rkt:170-185` | `syrup-null` is not in the OCapN Syrup dialect, yet we both emit and accept it — and our own production frame reader chokes on it.** `contrib/syrup.py` (264 lines) contains **zero** occurrences of `null`/`None`/`b'n'` — the reference has no null form. `ocapn-framing.rkt`'s byte dispatch (`:164-185`) has arms for `[<{`, `]>}`, `t`/`f`, `F`, `D`, digits, and errors on everything else. Verified against `read-frame` under `'raw-syrup` (the production default, `run-ocapn-test-server.rkt:56`, `:70`):
```
#"<2'opn>"  => EXN: read-syrup-frame: unexpected byte 110 at depth 1
#"n"        => EXN: read-syrup-frame: unexpected byte 110 at depth 0
#"<1'a[n]>" => EXN: read-syrup-frame: unexpected byte 110 at depth 2
#"#1+$"     => EXN: read-syrup-frame: unexpected byte 35  at depth 0
```
And `test-ocapn-syrup-wire.rkt:118-120` *pins* `encode (syrup-tagged "op" syrup-null)` → `<2'opn>` — a frame our own reader cannot read back and upstream would reject. Full drift table (each scanner has a different hole):

| form | `ocapn-framing.rkt:164` | `handshake.rkt skip-value:314` | `syrup-wire decode-at:466` | `run-ocapn-test-server syrup-skip:281` |
|---|---|---|---|---|
| `n` null | **ERROR** | ok | ok | ok |
| `t`/`f` | ok | ok | ok | ok |
| `F`/`D` | ok | ok | **none** | **CRASH** |
| `#…$` set | **ERROR** | **none** | **none** | **CRASH** |

**M3. HIGH | data-loss | `syrup-wire.prologos:215` | `re-encode` DROPS a record's explicit `null` argument — the report found only the list-splice case.** Verified: `re-encode (decode-value "<2'opn>")` → `"<2'op>"`, and `re-encode (decode-value "<2'op>")` → `"<2'op>"` — a 1-arg and a 0-arg record collapse to the same bytes. Root cause is `decode-record-with:440` encoding "no args" as a `syrup-null` payload, which `re-encode-payload:215` then erases. Same byte-corruption on the signature path as CONFIRMED #2, distinct case, distinct fix.

**M4. HIGH | wrong-answer | `captp-wire.prologos:113` | the `encode`-wraps-vs-`re-encode`-splices ambiguity is live on the ECHO/FORWARD path, not just signature verification.** `op-deliver tgt args ap rm -> wire::encode-record "op:deliver" [cons [desc-export tgt] [cons args …]]` renders `args` — which for an echo came from `decode-at` — through `encode` (`encode-record:177-180` → `encode-many encode`). Any nested multi-arg record inside an echoed argument goes back out as `<label [a b c]>`. Verified shape: `re-encode (decode-value "<1'a<1'b[1+2+]>>")` → `"<1'a<1'b1+2+>>"` vs `encode` of the same → the wrapped reading. The report tied this only to `verify-receive-with-msg`.

**M5. MEDIUM | duplication/drift | `run-ocapn-test-server.rkt:459-461` vs `syrup-wire.prologos:89` | two symbol encoders in the same stack disagree on the length rule, and the Racket one is right.** `(define (syrup-symbol s) … (bytes-length (string->bytes/latin-1 s)) … #"'" b)` — the Latin-1 byte count. `syrup-wire.prologos:89` uses `str::bytes-length` — the UTF-8 count. Same wire form, two rules, nothing forcing agreement. This pair is the direct evidence for which side of CONFIRMED #1 is correct; the report argued it from first principles and never noticed the counter-example already in the tree.

**M6. MEDIUM | wrong-layer + silent-failure | `run-ocapn-test-server.rkt:528-539` | `peer-hint` locates hints by an unanchored byte-substring scan with no structural position, and hardcodes the string-key marker so it cannot parse the hints we ourselves emit.** It builds `needle = <len>"host` and scans the whole sturdyref for the first match (`:530-534`). A swiss-num, address, or any nested payload containing those bytes yields a wrong host with no error (`and idx` → silently `#f` otherwise). And because it fixes marker `34` (`"`), it structurally cannot read `handshake.prologos:105`'s symbol-keyed hints — our own dialer cannot dial our own advertised location.

**M7. MEDIUM | wrong-layer | `syrup.prologos:63` | the model has `syrup-dict` but Prologos has no dict accessor at all — every dict field read in the system is done by Racket byte-scanning.** `get-nat`/`get-string`/`get-refr`/`get-promise`/`get-tag`/`get-payload` (`syrup.prologos:160-248`) all return `none` for `syrup-dict`; there is no `dict-get`. The only hint lookup in the codebase is `peer-hint` in Racket (M6). Moving it is ~15 lines of Prologos (walk the flat alternating list, compare keys), which is exactly the "logic in the Racket test server that belongs in Prologos" category the brief asked for.

**M8. MEDIUM | silent-failure | `run-ocapn-test-server.rkt:230-252` | `drive-step` wraps the entire Prologos step in a blanket `with-handlers ([exn:fail? …])` that prints and returns `#""` — this is the mechanism by which every finding above stays silent.** The comment at `:227-229` states the intent openly ("A step that errors … must not take down the connection handler"). Consequence: a type error, a reducer hang-then-crash, the `string->bytes/latin-1` throw from CONFIRMED #1, and a legitimate "nothing to send" are all indistinguishable — the peer sees silence and the conformance test times out instead of failing. The two `#""` returns at `:246` and `:252` do the same for "no String" and "unparsable". Any audit of this surface should have led with this.

**M9. LOW | concurrency | `run-ocapn-test-server.rkt:721`, `:551` spawn per-connection threads over unguarded shared state.** `half-open-dials` (`:311`), `open-conns` (`:339`), `pubkey-by-port` (`:341`), `pending-enlivens` (`:350`), `pending-gives` (`:497`) are plain `make-hash`/`make-hasheq`; `next-conn-id!` (`:215-219`) and `next-enliven-slot!` (`:351-354`) are unguarded read-modify-write on boxes. Tempered to LOW because `validate-sema` (`:189`) serializes `drive-step` — but it does *not* cover these tables, which are touched outside it. The report listed concurrency as a category and returned nothing under it.

---

### 1.2 CapTP bridge — questions, answers, listeners, GC

#### Verified findings

1. `captp-core.prologos:2022-2023` asserts "No overlap: outbound q-pos ids are allocated by us, inbound by peer", but both tables are keyed by plain `Nat` from the same vat counter (`:898` `bs-add-outbound-question pid pid`, `:2871` same; `vat.prologos:224` `next-id = zero`), and `dispatch-incoming-answer:2237` checks outbound first — nothing partitions the two id spaces.
2. `captp-core.prologos:3136-3144` emits singular scalar `op:gc-answer` / `op:gc-export`, which are absent from upstream's `CAPTP_TYPES` (`captp_types.py:558-576`) and would abort the peer's receive loop; the correct plural encoders already exist at `:167` and `:1179`, and `:1127-1133` documents the discrepancy without fixing the public path.
3. `captp-core.prologos:139-144` wraps the answer position as `<desc:answer N>` while its sibling `:162` writes it bare, with the rule spelled out at `:150-157` and nothing forcing the two encoders to agree.
4. `captp-core.prologos:2727-2746` unconditionally emits the `<desc:answer N>` frame from `outbound-from-resolution` **and** the `listener-notify-bytes` frame for the same settled pid, so the `ap`+`rm` shape (`:2108-2113`) produces two frames per answer.
5. `captp-core.prologos:1512-1518` claims the `used:` prefix "cannot collide with a gift id, because gift ids come from the peer as opaque bytes" — peer-controlled opaque bytes are precisely what can equal a constructed key, and `bs-add-gift` (`:804-809`) rejects no prefix; the same table also holds `park:` keys (`:1814`).
6. `captp-core.prologos:1359-1363` takes `ap` and never reads it, so a `deposit-gift` carrying an answer position records the gift and leaves the peer's answer unresolved forever; and `maybe-bootstrap-method` is reachable only from `dispatch-deliver:1959`, which `deliver-with-answer-pos:2119` and `incoming-deliver:2144` both bypass when an `rm` is present — so a deposit with a resolve-me is never recorded at all.
7. `captp-core.prologos:2729-2730` short-circuits `pump-one` on `emitted`, while `bs-gc-pipelined-msgs-by-emitted:2633-2639` drops queue entries keyed by that same set — a pipelined deliver arriving after its answer was emitted is queued and then silently garbage-collected without being forwarded.
8. `captp-core.prologos:3302-3338` runs `run-vat` exactly once (`:3308`) before `pump-outbound` (`:3317`), so messages `deliver-locally-loop:2421-2427` enqueues on the vat queue during the pump make no progress until an unrelated inbound frame arrives.
9. `captp-core.prologos:1966-1967` reuses a stale QEntry's local pid for a re-used answer position, and since that pid is already in `emitted` (`:2729-2730`) and `resolve-promise` no-ops on settled promises (`vat.prologos:308-309`), neither side sees an error.
10. `captp-core.prologos:102-103` claims "every other producer of this slot in this module already wraps", but `as-args-list` has exactly one call site (`:114`) and `:139-144`, `:162`, `:2382-2388` and `:184-189` all pass their args slot through unwrapped.
11. `captp-core.prologos:2282-2285` (`op-deliver-only`) is the one inbound arm that increments imports without calling `maybe-release-imports`, even though the policy comment at `:1135-1141` describes the no-reply-channel shape that `deliver-only` most exactly is.
12. `captp-core.prologos:1052-1055` and `:1081` return no refrs for `syrup-dict` and for nested `syrup-list`, so imports inside a dict or one level deeper in a list are never refcounted and never released — and dicts are decoded on the wire (`syrup-wire.prologos:498`).
13. `captp-core.prologos:2414-2417` asserts actor ids and peer-export ids "don't collide", directly contradicting `vat.prologos:338-342` ("collides with them freely"), and `dispatch-export-target:2517` routes on exactly that `lookup-actor` discrimination.
14. `captp-core.prologos:2746`, `:2822` and `:3337` grow `emitted` monotonically with no filter, while `pump-one:2729` runs an O(|emitted|) `member-nat?` per question per step; `bs-gc-exports`/`bs-gc-answers` (`:525-531`, written at `:569-577`) have no reader outside their accessors, and `bs-decr-import:726-728` self-documents that zeroed entries "persist harmlessly".
15. `captp-core.prologos:1798-1803` (`settle-parked`) has exactly one call site, the `op-listen` arm at `:2307`; with no deposit and no listen, the promise, the `park:` entry (`:1814`) and the `used:` marker (`:1815`) leak and the peer hangs with no timeout and no rejection path.
16. `vat.prologos:477-478` returns the vat unchanged when fuel hits zero with no signal, and `captp-core.prologos:3283-3290` records that the previous bound "silently left the send undelivered on the queue with no error" — raising 5→20 moved the threshold, not the failure mode.
17. `captp-core.prologos:1524-1527` builds the single-use handoff identity by unescaped concatenation of peer-supplied `sess`, `side` and a decimal count with `"|"` separators, so `("A|B","C",n)` and `("A","B|C",n)` produce the same key.
18. `captp-core.prologos:3103` returns `conn-ask cs zero ""` on an aborted connection — indistinguishable from a genuine promise 0 — behind a comment at `:3097-3099` stating a caller obligation nothing enforces.
19. `captp-core.prologos:34-55` (`incoming-captp-op`), `:927-939` (`deliver-with-ap`), `:375-422` (`refr-eq?`/`refr-to-syrup`), `:3252-3258` (`connection-pipeline`), `:525-531`, `:748-750` have no caller anywhere in `lib/prologos/ocapn/` or `tools/` — verified by grep — and `incoming-captp-op` in particular is a second full inbound dispatcher that no-ops `op-deliver-to-answer`, `op-listen` and both GC ops.
20. `captp-core.prologos:3316-3317` computes `[prepend-pending-list [od-bytes drain] [od-state drain]]` twice in adjacent lines with nothing recording that the two must stay in lockstep.
21. `tools/interop/run-ocapn-test-server.rkt:215,311,339,341,350,351,497` are process-global mutable boxes/hashes read and mutated from per-connection `(thread …)` handlers (`:551`, `:721`) with no synchronisation; `:393-399` is a `for/first` scan followed by `hash-remove!` — a check-then-act across threads — and `next-enliven-slot!` (`:352-354`) is an unsynchronised read-modify-write on a box (the report listed seven globals while saying "six", and missed the box RMW).

---

#### Also missed by the first pass

The report under-covered **cross-connection state** (it noticed the gift table is exporter-global but only chased forgery), **`ap`/`rm` loss in the pipeline queue**, and **ordering**.

**M1 — CRITICAL | cross-connection confusion | `interop-driver.prologos:181-195` + `captp-core.prologos:2307`, `:1780-1782`, `:154`.** `with-global-gifts` *replaces* a connection's whole gift table with the process-global one (`:184`) and `publish-gifts` publishes the whole post-step table back (`:193`), so `park:<P>:<gid>` keys are global — while promise ids `P` are **per-connection** (every connection starts from `seeded-vat` with `next-id 8N`, `:154`). `settle-parked` runs on **every** inbound `op:listen` (`captp-core.prologos:2307`), and `parked-gid-for` is a bare prefix match (`:1776-1782`).
*What breaks it:* connection A parks a withdrawal on its promise 9 → global entry `park:9:<gid>`. Connection B — an unrelated session — sends an ordinary `op:listen` on **its** promise 9. B's promise is resolved with A's gift export (`do-settle-parked:1787-1790`), and A's park entry and gift are consumed. A capability is delivered to the wrong session and A's pending handoff is destroyed. No adversary, no forgery, no id guessing — just two concurrent connections.
*Fix shape:* key park entries by (connection-id, promise-id), or keep park state in the per-connection `BridgeState` and publish only real gifts globally.

**M2 — HIGH | unimplemented behind a passing test | `captp-core.prologos:782-787`, `:1999-2013`.** `PipeMsg` is `(pid, args, ap)` — it has **no resolve-me field**, and `dispatch-pipeline-on-our-q` never receives `rm` at all. So a pipelined `op:deliver` carrying a resolve-me that gets *queued* (target answer not yet settled) has its reply channel dropped on the floor; only the break path (`pipeline-or-break:2223-2227` → `forward-break:2217-2221`) ever uses `rm`. Every upstream Car-Factory op carries a `resolve_me_desc` (`op_deliver.py:73,83,92`); it passes only because our answers settle immediately and the rescue path at `:2231-2233` runs instead of the queue.

**M3 — HIGH | silent failure | `captp-core.prologos:2395-2401`, `:2421-2427`.** Both forwarding loops destructure `[pipe-msg p args _]`, discarding the stored `ap`. `forward-deliver-bytes` (`:2382-2388`) then hardcodes `false` in slot 2, so a forwarded pipelined deliver goes to the peer with no answer position and the peer's answer at that position never resolves. Only `break-step-matched-pid:2445-2449` reads `ap`, so an error is deliverable but a success is not.

**M4 — MEDIUM | wrong comment + ordering | `captp-core.prologos:593-596`, `:2924-2929`.** `bs-append-pending-out` is named "append" but does `[cons bytes p]` (`:596`). `prepend-pending-list` (`:2926-2929`) walks the drained list head-first appending each, so `[b1,b2,b3]` becomes `[b3,b2,b1]` and goes out **reversed**. Its own doc line reads "Stage the drained ask-bytes for the pump to flush, in order" (`:2924`), and it silently defeats `vat.prologos:328-329` ("append, not cons — a behaviour that sends twice must have them emitted in that order"). Unexercised only because the greeter sends exactly one message per turn.

**M5 — MEDIUM-HIGH | spec deviation / confused deputy | `vat.prologos:441-446` → `captp-core.prologos:2863-2871`.** An inbound `op:deliver` to an export position we do not have, with no answer position, is not rejected — `deliver-msg` treats "no local actor" as "a behaviour originating a message to a peer export" and enqueues it to `vat-outbound`, which `drain-questions` then re-emits to the peer as `<op:deliver <desc:export N> args <pid> <desc:import-object R>>`. We reflect the peer's own bad target back at it, reinterpreted in the peer's namespace. Any peer typo becomes a message delivered to an unrelated object on the peer side.

**M6 — MEDIUM | resource | `vat.prologos:163-165`, `:179-181`, `captp-core.prologos:2870`.** `actor-table-set` and `promise-table-set` are shadowing conses — `resolve-promise` (`vat.prologos:311`) *adds* an entry rather than replacing, so every settled promise leaves two, forever. `lookup-promise` scans that list linearly and `pump-one` (`:2732`) calls it per question per step. `drain-questions` also spawns a fresh `beh-resolver` actor per outbound message (`:2870`) that is never reclaimed. This is a larger monotone cost than the `emitted` list the report flagged, and it invalidates the "fewer than ~5 actors" premise at `vat.prologos:155-162`.

**M7 — LOW-MEDIUM | in-tree source of the duplicate keys finding 9 blames on the peer | `captp-core.prologos:2112`, `:1901`.** `deliver-resolve-me-with-answer` and `do-fetch-pipelined` both call `bs-add-question apos …` unconditionally, bypassing the existing-entry check that `dispatch-deliver:1966` performs. So the `ap`+`rm` and pipelined-fetch shapes can create duplicate q-pos keys without any peer misbehaviour, and `list-remove-q-by-key:637-643` removes only one.

---

### 1.3 Third-party handoff + gift table (exporter side)

#### Verified findings

Restated one line each, verbatim-copyable, with corrected coordinates where the original cite was wrong.

1. **CRITICAL | unimplemented-behind-passing-test | `captp-core.prologos:1676-1718`** — the exporter verifies the handoff-receive against a public key it reads out of the `desc:handoff-give` *nested inside the message being verified* (`give-receiver-key-of :1676-1680` → `signed-give-receiver-key :1682-1686` → `receive-receiver-key-of :1688-1692` → `verify-receive-with-key :1695-1699`), and the gifter's signature over that give is never verified at all — `grep -n verify captp-core.prologos` yields exactly one `verify-raw` call site (`:1699`), so any peer can self-sign a give naming its own key and redeem any gift whose id it knows.

2. **CRITICAL | invariant-asserted-but-not-enforced | `captp-core.prologos:1517-1518`** — the comment *"The prefix cannot collide with a gift id, because gift ids come from the peer as opaque bytes and this key is only ever CONSTRUCTED here"* is inverted: peer-supplied gift ids reach the same `List GiftEntry` verbatim via `dispatch-deposit-gift-rest`→`syrup-bytes-of` (`:1336-1347`, `:1301-1313`) and `bs-add-gift` (`:804-809`), so a withdraw naming gift-id `used:<own-sess>|<own-side>|0` makes `do-withdraw` (`:1824-1829`) delete its own single-use replay marker and re-enable the replay that `test_handoff_receive_invalid_handoff_count` exists to forbid.

3. **HIGH | hardcoded / test-shaped + wrong-layer | `run-ocapn-test-server.rkt:589-614`** — the receiver side detects an incoming handoff by substring-scanning raw frame bytes for `#"<17'desc:sig-envelope<17'desc:handoff-give"` (`:593`, `find-subbytes` over the whole frame at `:602`, called on every inbound frame at `:637` and `:582`), and the comment at `:591-592` claiming the marker "appears nowhere else on the wire" is false — a bytestring argument carrying those bytes plus an attacker-chosen `ocapn-peer` makes `note-handoff-give!` (`:601-614`) hand the location to `ocapn-dial-request` and open a TCP connection to it (`dial-sturdyref!:542-556`).

4. **MEDIUM | hardcoded / test-shaped | `run-ocapn-test-server.rkt:484` and `:407`** — the outbound handoff count is the literal `#"0+"` in `withdraw-gift-frame` (`:479-486`) and the gift id the literal `#"prologos-gift"` in `try-fetch-answer!` (`:407`), so a second handoff against the same exporter replays identity `(session, side, 0)` and any correct exporter — including our own `withdraw-with-identity` (`captp-core.prologos:1843-1847`) — must reject it, while two concurrent gifts collide on the id and `gift-remove-loop` (`:825-832`) removes *all* matching entries so redeeming one destroys the other.

5. **MEDIUM | resource / lifecycle | `captp-core.prologos:1810-1815`, `:1786-1790`, `:1824-1829`** — every parked withdraw adds two entries (`park:` + `used:`) and allocates a fresh vat promise, no path ever removes a `used:` entry, `bs-add-gift` (`:804-809`) is an unconditional `cons` with no cap, all three scans are linear (`:811-818`, `:825-832`, `:1771-1778`), and the backing table is a process-global `make-hash` (`ocapn-gift-ffi.rkt:28`) with no clear API, so N unmatched withdraws leave 2N permanent entries at Θ(n²) cost for the life of the process.

6. **MEDIUM | wrong-answer | `captp-core.prologos:1771-1778` + `:2307`** — `settle-parked` fires on *any* inbound `op:listen` with the peer-supplied target (`op-listen` arm `:2294`, `listen-after-settle tgt resolver [settle-parked tgt v st]` `:2307`) and locates the park by bare string-prefix over the same peer-writable keyspace, so a deposited gift keyed `park:<P>:<gid>` lets a peer drive `resolve-promise P` (`do-settle-parked :1786-1790`) on a promise it did not park.

7. **MEDIUM | silent-failure | `crypto-ffi.rkt:163-166` reached from `captp-core.prologos:1699`** — `crypto-verify` **raises** rather than returning `#f` on a pubkey ≠ 32 bytes or a signature ≠ 64 bytes, the extracted `q`/`r`/`s` are never length-checked in Prologos (`public-key-q-of :1643-1647`, `eddsa-rs-of :1656-1660`), and `drive-step`'s `with-handlers ([exn:fail? …])` (`run-ocapn-test-server.rkt:233-237`) turns the exception into `#""` — so a give with a 31-byte `q` yields *silence*, not `break`, and the comment at `:1711-1712` ("A malformed handoff verifies as FALSE, never as true") is contradicted for wrong-length fields.

8. **LOW | duplication / drift-risk | `captp-core.prologos:1649-1666` vs `run-ocapn-test-server.rkt:465-470`** — the gcrypt `[sig-val [eddsa [r …][s …]]]` shape is parsed by name in Prologos (`eddsa-rs-of`, `sig-val-bytes-of`) and constructed by hardcoded position in Racket (`gcrypt-sig`), with no shared definition and — confirmed by grep — **no round-trip test**: the only occurrence of `sig-val` anywhere under `racket/prologos/tests/` is a comment at `test-ocapn-bridge.rkt:2309`.

9. **LOW | stale-comment | `captp-core.prologos:446-462` (field decl at `:441`, not `:444`) and `:799-802`** — the `BridgeState` doc says the gift ops are "deferred to Phase 52b" and that the field is "`(List QEntry` — pair of Nat)", but the field is `[List GiftEntry]` (`:441`, `data GiftEntry` at `:429-430`) and `:1258-1260` records that the dedicated `op-deposit-gift`/`op-withdraw-gift` variants "were reverted because they didn't interop with the canonical model"; the identical stale `List QEntry` sentence is repeated at `:799-802`.

10. **LOW | silent-failure | `captp-core.prologos:1322-1347`** — four distinct malformed-`deposit-gift` shapes (`:1325`, `:1332`, `:1339`, `:1345`) all return `bridge-step v st` unchanged and indistinguishable from success, and the in-code comment at `:1341-1343` documents that this exact silent-drop class already shipped once. *(Note: the report's exemplar is wrong — a peer would not deposit `<desc:import-object N>`; upstream's `fetch_object` returns `fetched_object.to_desc_export()` (`utils/captp.py:185`), so `<desc:export N>` is the conforming shape. The realistic dropped input is a **pipelined** gift, `<desc:answer N>` from `fetch_object(pipeline=True)` (`utils/captp.py:178-179`), which `syrup-as-export-target` (`:1236-1238`) rejects and which `:799-802` itself names as unsupported.)*

---

#### Also missed by the first pass

The report under-covered **category 7/8 interactions with the process-global table**, **category 3 at the access-control layer**, and **test coverage** entirely. Five items:

**M1 — CRITICAL | wrong-answer / concurrency | `interop-driver.prologos:154` + `captp-core.prologos:1766-1768`, `:1780-1782`.** *Park keys collide across connections because promise ids restart per connection.* `seeded-vat` fixes `next-id` at `8N` for **every** connection (`:154`, used by `seeded-connection :164` in `init-connection :168-169`), so `fresh-promise` (`vat.prologos:259-262`) hands out promise 8 on connection A *and* connection B. Park entries are keyed `park:<P>:<gid>` (`:1766-1768`) and live in the **process-global** table (`ocapn-gift-ffi.rkt:28`, seeded/published wholesale at `interop-driver.prologos:184`/`:193`). `parked-gid-loop` (`:1771-1778`) prefix-matches `park:8:` and returns the **first** match; `bs-add-gift` conses newest-first (`:809`), so whichever connection parked *last* wins for *both*. B's `op:listen` on its promise 8 then settles with A's gift and `do-settle-parked` (`:1786-1790`) removes A's park entry **and** A's gift. This is deterministic, needs no attacker, and is exactly the two-connection topology `HandoffRemoteAsExporter` sets up — it is masked today only because upstream runs one parked withdraw at a time. *What breaks it:* two overlapping `test_valid_handoff_wait_deposit_gift` runs, or any two peers parking concurrently. *Fix shape:* namespace park keys by connection id (the driver has `cid`), or make promise ids globally unique.

**M2 — MEDIUM | spec-deviation | `captp-core.prologos:1957-1968`.** *There is no per-session import/export table at all.* `dispatch-deliver` routes any `tgt` to `enqueue-msg [vmsg-deliver tgt args …]` (`:1964`) with no check that this session ever received that export; the only positional gates in the module are `nat-eq? tgt zero` for the bootstrap methods (`:1371`, `:1940`). Any peer can `op:deliver` to export 3 (car-factory-builder), 5 (sturdyref-enlivener), 6 (resolver-vow) or 7 (resolver-actor) without fetching them (`interop-driver.prologos:133-140`). This is the structural reason the report's #3 is not an escalation, and it is the larger deviation the report should have found instead.

**M3 — MEDIUM | test-coverage | `racket/prologos/tests/`.** *The entire parked-withdrawal path and the single-use replay guard have zero unit tests.* `grep -rn "settle-parked\|withdraw-park\|handoff-identity\|park:\|used:" racket/prologos/tests/*.rkt` returns nothing relevant. `test-ocapn-bridge.rkt:2163-2299` covers only `bs-add-gift`/`bs-lookup-gift`/`bs-remove-gift` and malformed dispatch; `:2363-2399` cover signature verify/reject on one captured frame. Everything in findings 2, 5, 6 and M1 is exercised **only** by the upstream conformance suite, which drives exactly one shape.

**M4 — MEDIUM | concurrency | `run-ocapn-test-server.rkt:637-639` vs `:230-231`.** *The driver's per-connection hashes are mutated from multiple threads entirely outside the semaphore.* `run-frame-loop` calls `note-handoff-give!` (`:637`), `try-enliven!` (`:638`) and `try-fetch-answer!` (`:639`) **before** the `call-with-semaphore`-wrapped `drive-step` (`:640`), and each connection runs on its own thread (`:721`), as does each dial (`:551`). `try-fetch-answer!` does `for/first` over `pending-enlivens` then `hash-remove!` (`:393-399`) — a check-then-act two threads can both win. The report mentions this in passing inside #12 but does not raise it as a finding; it is the *verifiable* concurrency defect, whereas #12's clobber claim is conditional on removing the semaphore.

**M5 — LOW | resource / lifecycle | `run-ocapn-test-server.rkt:497/611` and `:311/561`.** *Two driver hashes leak and one silently overwrites.* `pending-gives` is `hash-set!` keyed by exporter **location** (`:611`) and removed only when that peer's start-session arrives (`:576`) — a failed dial (handler at `:553-555`) leaves the entry forever, and a second give from the same location before the first is redeemed silently replaces it. `half-open-dials` is `hash-set!` at `:561` and `hash-remove!`d **only** on the crossed-hellos ours-first? branch (`:690`), so every successful dial without a crossback leaks an entry holding both ports for the process lifetime.

**M6 — LOW | stale-comment | `racket/prologos/tests/test-ocapn-bridge.rkt:2260`.** The test named `"gift/withdraw-gift for an unknown id BREAKS"` passes `syrup-null` as the receive, so it never reaches the gift lookup — `withdraw-with-receive` (`captp-core.prologos:1863-1867`) rejects it at `signed-receive-valid?` first. The test exercises the bad-signature path and its name asserts coverage that does not exist; the unknown-id path (`withdraw-known-gid :1831-1837` → park) is untested.

---

### 1.4 Op encoding / decoding

#### Verified findings

Each of these I re-read and, where marked (probe), re-ran independently.

1. **HIGH | spec-deviation | `captp-wire.prologos:108-128`** — `encode-op` emits bytes upstream rejects for 4 of 8 ops and silently corrupts the 5th. (probe) Our bytes fed to `decode_captp_message`: `op:listen` `<9'op:listen<11'desc:export3+><11'desc:export7+>>` → AssertionError; `op:start-session` `<16'op:start-session3"1.03'loc>` → AssertionError; `op:gc-export` → "Unknown captp type"; `op:gc-answer` → "Unknown captp type"; `op:deliver` ACCEPTED with `answer_position = <Record desc:answer: [5]>` (spec: bare int) and `exported_resolve_me_desc` raising `AttributeError: 'DescAnswer' object has no attribute 'to_desc_export'` when `rm` is present. Cause: `opt-pos` (`:71-75`) wraps both slots in `desc-answer`. Correct form is one function away at `captp-core.prologos:161-163`. Severity per O1: MEDIUM-as-live-bug / HIGH-as-drift.

2. **HIGH | unimplemented behind a passing test | `captp-wire.prologos:435-457`** — `dispatch-op` has no `op:gc-exports` / `op:gc-answers` arm (`grep -c` in that file = **0**); a conformant peer's GC is silently dropped to `none` → `""` at `interop-driver.prologos:268`. (probe) both frames → `"GC-EXPORTS DROPPED (none)"` / `"GC-ANSWERS DROPPED (none)"`. `bs-decr-export`'s sole call site is `captp-core.prologos:2313`, inside the singular arm, so it can never fire for a real peer. Hidden because upstream's GC tests only *expect* GC from us (`tests/op_gc.py:32-47`); `grep -c gc utils/captp.py` = 0.

3. **MEDIUM | wrong decode | `captp-wire.prologos:397-407`, `message.prologos:37`** — `dispatch-start-session-args` binds `args[1]` as `loc`; in the real 4-field record `args[1]` is the pubkey s-expression (`captp_types.py:378`). (probe) a 4-field frame `<op:start-session "1.0" 'PUBKEY-SEXPR 'LOCATION 'SIG>` decodes with the `loc` slot holding `"PUBKEY-SEXPR"`. Header at `captp-wire.prologos:14` documents a 2-field form no peer sends. Latent only because `captp-core.prologos:2288` discards both fields.

4. **HIGH | resource | `syrup.prologos:250-262`, reached via `captp-wire.prologos:186,241-243`** — peer-chosen table positions become unary Peano via `int-to-nat-loop`; the comment at `:250-252` asserts "small Nats so the cost is acceptable" with nothing enforcing it. (probe) forcing a decoded position: 3028 / 8305 / 60561 reduce steps at N=20/200/2000 ≈ 29 steps per unit. `tests/test-from-nat-computed.rkt:20` records this class already biting once via an `op:gc-exports` wire-delta. Per W7, the cost is lazy — paid at first full-depth comparison, not at decode.

5. **HIGH | invariant asserted but not enforced | `captp-wire.prologos:184-197`** — `unwrap-desc`'s only non-`none` arm is `| syrup-tagged _ p -> wire-nat p`; the label is discarded, and the comment at `:181-182` ("desc:export / desc:answer / etc.") is the only thing asserting a constraint. (probe) `<op:deliver <totally-bogus 3> [] f f>` → `"BOGUS TARGET ACCEPTED"`, routed to export position 3. Upstream guards at `captp_types.py:472`. `desc-is-answer?` (`:204-217`) is then the sole discriminator between the answer table and the export table.

6. **MEDIUM | unimplemented behind a passing test | `captp-wire.prologos:325-338`, `message.prologos:51`** — `op:listen`'s `wants_partial` (upstream `captp_types.py:429-433`, field 3) is dropped; `op-listen : Nat -> Nat` has no third field. (probe) a 3-field frame with `wants_partial=true` → `"listen decoded, wants-partial dropped"`; `true` and `false` are indistinguishable downstream. Hidden because all three upstream tests hardcode `wants_partial=False` (`tests/op_listen.py:61,91,131` — verified exact).

7. **MEDIUM | silent failure | `captp-wire.prologos:86-95`** — `op-to-syrup` has 7 arms for `CapTPOp`'s 8 constructors and no wildcard; the `op-deliver-to-answer` arm added to `encode-op` at `:123` was never added to its twin. (probe) `op-to-syrup [op-deliver-to-answer …]` returns a stuck `reduce` node well-typed as `SyrupValue`, no diagnostic.

8. **MEDIUM | duplication / drift | `captp-core.prologos:3136-3144` vs `:1178-1180` and `:166-168`** — two live GC-emitter families. The singular `gc-answer-bytes` / `gc-export-bytes` emit ops upstream rejects (confirmed in C1) and are **not dead**: called at `:3163`, `:3179`, `:3205-3208`, re-exported as public API `captp-release-answer` / `captp-release-import` (`core.prologos:137-145` — exact), used at `captp-interop-helpers.prologos:190` (exact), and asserted on by `tools/interop/peer-refr-passing.mjs:111,153` (not `:16`, per W3). The comment at `:1126-1133` openly says the singular form "is not what any peer reads" and that plural was added *alongside* rather than replacing it.

9. **MEDIUM | resource leak | `captp-core.prologos:1042-1055`, `1071-1085`** — the refr walk is one level deep. `shallow-refr:1054` is `| syrup-list _ -> [nil Refr]    ;; SHALLOW: nested lists not walked` (line number exact), limitation stated at `:1037-1041` (exact). `| syrup-dict _ -> [nil Refr]` at `:1051` means dict values are also unwalked. Consequence: `bs-incr-imports` misses the descriptor, `refr-import-tally` (`:1109-1117`) tallies 0, `bs-release-tally` (`:1184`) emits nothing → the peer's export is held open forever. Hidden because `test_gc_export_with_multiple_refrences` sends a **flat** `args=[a_local_obj]*4`.

10. **MEDIUM | no arity validation | `captp-wire.prologos:364-380, 298-308, 325-338, 397-407`** — every `dispatch-*-args` reads positionally via `list-fst`/`2nd`/`3rd`/`4th` and never checks the tail is empty. (probe) `<op:deliver <desc:export 1> [] f f "EXTRA">` → `"ACCEPTED despite 5 fields"`. Upstream asserts exact arity on all 13 types (`grep -n "assert len(record.args)"` → 13 hits).

11. **MEDIUM | silent failure | `interop-driver.prologos:266-269`** — every decode failure funnels into `| none -> ""`: no abort, no log, connection stays up. `syrup.prologos:58-62` records that this exact silence already cost a debugging cycle; the fix added dict support and left the silence.

12. **LOW | stale comment | `captp-wire.prologos:148`** — describes `wire-positive`, an identifier that has never existed (`grep -rn wire-positive racket/prologos/` → this comment plus `wf-wire-positive-clause` in the well-founded engine). Lines `:138-140` also claim "we keep it as Int internally rather than converting to Nat — Nat conversions are O(n)… and unnecessary," which is the exact opposite of `wire-nat` (`syrup.prologos:264-269`, calls `int-to-nat`).

13. **LOW | stale comment | `captp-wire.prologos:22-33`** — "that bookkeeping is Phase 3+" is stale: `refr-syrup-tag` (`captp-core.prologos:411-418`) now does exactly the table-driven descriptor selection. Simultaneously an accurate description of the bug in C1.

14. **LOW | type confusion in a selector | `message.prologos:153,158`** — `deliver-target` returns `some t` for both `op-deliver` (export-table index) and `op-deliver-to-answer` (question-table index), and `deliver?` (`:105,110`) returns `true` for both, with no discriminator.

---

#### Also missed by the first pass

The report's own categories 6, 7, and 8 got the thinnest coverage; 8 got none.

**M1. STALE/WRONG DOC | `captp-wire.prologos:9-20` | the one comment that explicitly claims spec authority is the most wrong one.**
It reads "Per the OCapN spec:" and then lists `op:start-session <ver locator>` (spec: **4 fields**), `op:listen <to-desc resolver-desc>` (spec: **3**), and two ops — `op:gc-export`, `op:gc-answer` — **that do not exist in the spec at all** (`captp_types.py:566-567` has only `op:gc-exports` / `op:gc-answers`). The report flagged the three softer comments (13/14/15) and left this one.

**M2. DUPLICATION / DRIFT | nine byte-identical 12-arm `SyrupValue` matches in one file.**
`grep -c "syrup-promise _" captp-wire.prologos` → **9**: `unwrap-desc:185`, `desc-is-answer?:205`, `unwrap-opt-desc:238`, `dispatch-gc-export:284`, `dispatch-deliver-only:311`, `dispatch-listen:341`, `dispatch-deliver:383`, `dispatch-start-session:410`, `syrup-to-op:460`. Seven are the identical "`syrup-list xs -> helper`, everything else `-> none`" wrapper. Adding a `SyrupValue` constructor requires 9 edits with nothing forcing agreement — this is exactly the "~50 pattern sites" cost the report cites (finding 8) as the *reason* the wrong plural ops were never added, but it never located the cost in the file under review.

**M3. SILENT FAILURE / SPEC | `captp-wire.prologos:480-483` + `syrup-wire.prologos:509-514` | `decode-op` accepts arbitrary trailing garbage.**
`decode-value` is documented "Parse a single Syrup value **from the start of** `s`" and discards `decode-at`'s offset. (probe) `"<10'op:deliver<11'desc:export1+>[]ff>" ++ "GARBAGE-TRAILING-BYTES"` → `"ACCEPTED WITH TRAILING GARBAGE"`. Nothing at the codec layer rejects a frame with residue.

**M4. SILENT FAILURE | `captp-wire.prologos:243` | a negative answer position silently becomes fire-and-forget.**
`| syrup-int i -> wire-nat [syrup-int i]`, and `wire-nat` (`syrup.prologos:266-269`) returns `none` on negatives. So `<op:deliver <desc:export 1> [] -5+ f>` decodes with `ap = none` — indistinguishable from `false`. This is the *same* silent-drop the file's own `:225-236` comment block was written to close for the tagged case, still open for the malformed case.

**M5. INVARIANT NOT ENFORCED | `captp-wire.prologos:241` | the resolve-me slot's label is discarded too.**
Upstream sends `<desc:import-object R>` in slot 3, documented on our side at `captp-core.prologos:157-160`. `unwrap-opt-desc` reduces it to a bare Nat, and the bridge unconditionally re-addresses it as `<desc:export R>` (`captp-core.prologos:1808`; tag chosen by `refr-syrup-tag:411-418`). A peer sending `<desc:answer R>` as resolve-me is silently routed into the export table. Finding 5 covered the target slot only.

**M6. RESOURCE | `captp-core.prologos:569-572, 574-577` | peer-driven unbounded diagnostic-list growth.**
`bs-add-gc-export` / `bs-add-gc-answer` `cons` onto lists that nothing ever prunes, one entry per inbound GC frame, called from `:2313` and `:2319`. Comments call them "audit log" / "preserves diagnostic visibility" — an unbounded, peer-controlled accumulator described as a feature.

**M7. RESOURCE | `racket/prologos/ocapn-conn-ffi.rkt:35-38` | `ocapn-conn-reset` is provided and never called.**
`grep -rn conn-reset` over `.rkt`/`.prologos` returns only its own `provide` (`:21`) and definition (`:35`). `conn-table` (`:25`, a `make-hash`) therefore retains one full `ConnectionState` — vat, all four tables, promises, pipeline queue — per connection id for the process lifetime.

**M8. SILENT FAILURE / TYPE HOLE | `ocapn-conn-ffi.rkt:32-33` vs `interop-driver.prologos:46`.**
The FFI declares `[ocapn-conn-fetch :as conn-fetch : Nat -> ConnectionState]` — total. The implementation is `(hash-ref conn-table conn-id #f)`. A frame for a never-seeded cid hands Racket `#f` to `interop-driver.prologos:269`'s `[conn-fetch cid]` with no `Option` and no check; `connection-step` then pattern-matches a `ConnectionState` against `#f`. Passthrough FFI erases the failure into the type.

**M9. CONCURRENCY — zero coverage in the report.**
`tools/interop/run-ocapn-test-server.rkt:721` spawns `(thread (lambda () (handle-connection cin cout)))` per accepted connection. Those threads concurrently mutate unsynchronized `make-hash` tables: `conn-table` (`ocapn-conn-ffi.rkt:25`), and server-side `half-open-dials:311`, `open-conns:339`, `pubkey-by-port:341` (`make-hasheq`), `pending-enlivens:350`, `pending-gives:497`. The only lock in the file is `validate-sema` (`:189`), used at `:194,223,231`. Racket's `make-hash` is not safe for concurrent mutation without external synchronization. Not a demonstrated race (the conformance suite drives one connection at a time), but it is the whole of category 8 and the report reports nothing.

**M10. UNIMPLEMENTED | inbound `desc:import-promise` is not refcounted — the surviving half of the report's finding 11.**
`extract-refrs-from-tagged` (`captp-core.prologos:1023-1027`) and `dispatch-non-export-tag` (`:1011-1018`) recognize only `desc:export`, `desc:answer`, `desc:import-object`. A peer passing a promise reference as an argument — a tag we ourselves emit at `:1808` and upstream ships at `captp_types.py:560` — is accepted blindly by `unwrap-desc`, contributes no `Refr`, is never counted, and is never released.

**M11. LOW | effects-via-forced-match | `interop-driver.prologos:258-261`.**
`run-step` matches `[maybe-dial op]` and both arms are byte-identical (`| true -> run-step-inner cid op cs` / `| false -> run-step-inner cid op cs`). The comment at `:252-257` explains it: the match exists solely to force the `dial-request` FFI side effect past lazy reduction. Documented, but nothing prevents a future optimizer from collapsing identical arms and silently deleting the effect — and the comment says the failure mode is "a queue that stays empty with no error anywhere."

---

### 1.5 Vat, behaviours, promises

#### Verified findings

Restate-ready, one line each, file:line preserved.

1. **`tools/interop/run-ocapn-test-server.rkt:217-220`** — `next-conn-id!` is a non-atomic `unbox`/`set-box!` pair called outside `validate-sema` (`:563`, `:691`, `:698`), so two accepts preempted between the two forms share one connection id and therefore one `ConnectionState`. *(MEDIUM)*
2. **`racket/prologos/lib/prologos/ocapn/captp-core.prologos:1676-1699`** — the `desc:handoff-give`'s own signature is never verified and the give supplies the very key used to verify the receive (`receive-receiver-key-of` → `signed-give-receiver-key` → give arg0), making a withdrawal entirely self-attested; `grep verify-raw` over `lib/prologos/ocapn/*.prologos` yields exactly two sites, `handshake.prologos:434` and `captp-core.prologos:1699`, and neither covers the give. *(HIGH)*
3. **`racket/prologos/lib/prologos/ocapn/captp-wire.prologos:440-444`** — `dispatch-op` recognises only the SINGULAR `op:gc-export`/`op:gc-answer`; upstream and the spec send PLURAL `op:gc-exports`/`op:gc-answers` (`utils/captp_types.py:519-553`, `:571-572`), so every inbound GC frame decodes to `none` and `step-connection` returns `""` with no log (`interop-driver.prologos:266-269`). *(HIGH)*
4. **`racket/prologos/lib/prologos/ocapn/captp-core.prologos:2308-2320`** — consequently `bs-decr-export` and `bs-remove-question` are reachable only from ops no conforming peer can send, so `exports-refcount` and `bs-questions` grow monotonically for the life of every session. *(HIGH)*
5. **`racket/prologos/lib/prologos/ocapn/captp-core.prologos:2022, 2236-2239, 2871`** — the "(No overlap: outbound q-pos ids are allocated by us, inbound by peer.)" comment is unenforced: our outbound q-pos IS a vat promise id starting at `8N` (`interop-driver.prologos:154`) while upstream's answer positions start at 0 (`utils/captp.py:34`), and `dispatch-incoming-answer` checks the outbound table first. *(HIGH)*
6. **`tools/interop/run-ocapn-test-server.rkt:230-252`** — `drive-step` swallows every `exn:fail?` and every non-String result into `#""`, so an elaboration error, a fuel exhaustion and a stuck `[reduce …]` term are indistinguishable from "no reply needed". *(MEDIUM)*
7. **`tools/interop/run-ocapn-test-server.rkt:364-381`, called at `:638`** — `try-enliven!` byte-scans the whole frame for `<15'ocapn-sturdyref` with no check of the deliver's `to`, so any frame carrying both a sturdyref and a `desc:import-object` triggers a `fetch` on another connection; contrast `interop-driver.prologos:223-227`, which does gate on `sturdyref-enlivener-pos`. *(MEDIUM)*
8. **`tools/interop/run-ocapn-test-server.rkt:343-346`** — `open-conns` is keyed by the peer's self-declared location bytes with an unconditional `hash-set!` and no removal on close (only occurrences: `:339`, `:344`, `:371`), so a later connection claiming the same location silently becomes the target of every gifter-side write. *(HIGH)*
9. **`tools/interop/run-ocapn-test-server.rkt:561, 690`** — the `half-open-dials` entry is removed only on the `ours-first?` branch and never by the outbound thread on close, so after a lost crossed-hellos tie every future inbound connection from that peer is aborted for the life of the process. *(MEDIUM)*
10. **`racket/prologos/lib/prologos/ocapn/vat.prologos:475-482`** — `run-vat` returns the vat unchanged at fuel zero with no signal, leaving messages on the queue; `drain-fuel` was raised 5→20 (`captp-core.prologos:3282-3290`) precisely because that silence hid a lost send, and the mechanism is unchanged at 20. *(MEDIUM)*
11. **`racket/prologos/lib/prologos/ocapn/captp-core.prologos:102-103`** — "every other producer of this slot in this module already wraps" is false: only `outbound-deliver-bytes` calls `as-args-list`; `outbound-question-bytes` (`:139-148`), `outbound-ask-bytes` (`:162-163`) and `listener-notify-bytes` (`:184-190`) place `args` raw. *(LOW)*
12. **`racket/prologos/lib/prologos/ocapn/captp-core.prologos:123-127`** — `our-session-bytes` emits a two-field `op:start-session` while the spec, upstream and our own `ParsedSS` (`handshake.prologos:420-423`) all require four; `dispatch-start-session-args` (`captp-wire.prologos:397-407`) correspondingly mis-reads field 1 (the pubkey) as the location. *(MEDIUM)*
13. **`racket/prologos/ocapn-conn-ffi.rkt:35-38`** — `ocapn-conn-reset` has zero callers anywhere in the tree, so every connection ever accepted keeps its entire vat (actors, promises, gifts) resident for the process lifetime. *(MEDIUM)*
14. **`racket/prologos/lib/prologos/ocapn/captp-core.prologos:2746, 2822`** — `conn-emitted` only ever grows (`[cons local emitted]` / `[cons tgt emitted]`) and is scanned linearly by `member-nat?` (`:2601-2607`) on every pump pass. *(MEDIUM)*
15. **`racket/prologos/lib/prologos/ocapn/vat.prologos:153-155, 173-175`** — `actor-table-set`/`promise-table-set` cons at head and never remove, with the file's own comment (`:150-162`) naming the test-shape justification: "acceptable for Phase 0 because each test scenario uses fewer than ~5 actors." *(MEDIUM)*
16. **`racket/prologos/lib/prologos/ocapn/captp-core.prologos:1139-1146`** — `maybe-release-imports` releases every peer import-object on a no-reply-channel deliver, justified by an invariant about actor state that nothing enforces and the code itself declines to call a theorem. *(LOW, latent)*
17. **`racket/prologos/lib/prologos/ocapn/captp-core.prologos:2004-2013`** — pipelined messages are written to two independent queues (`pipeline-deliver` vat-side + `bs-add-pipeline-msg` bridge-side) that must agree, and the vat-side copy is silently discarded by `fulfill` (`promise.prologos:69-73`); `deliver-to-promise` drops outright on a settled promise (`pipelining.prologos:25-26`) and `pipeline-deliver`'s local-actor arm loses the answer-pos via `send-only` (`:37-38`). *(MEDIUM)*
18. **`racket/prologos/lib/prologos/ocapn/captp-core.prologos:2864-2871`** — every outbound send allocates a promise AND spawns a `beh-resolver` actor that is exported to the peer and never revoked, and the accumulator uses `[append acc …]` per item. *(MEDIUM)*
19. **`tools/interop/run-ocapn-test-server.rkt:281-297`** — `syrup-skip` and `record-field` index `bytes-ref` with no bounds check on attacker-controlled post-handshake frames, while the sibling `syrup-lenstr` (`:513-523`) does bounds-check; a truncated `desc:sig-envelope` kills the connection via `handle-connection`'s handler. *(MEDIUM)*
20. **`racket/prologos/ocapn-dial-ffi.rkt:40-44` + `run-ocapn-test-server.rkt:647`** — `ocapn-dial-request` runs under `validate-sema` (inside `drive-step`) but `drain-dials!` runs outside it from every connection thread, so a request appended between `(define out pending)` and `(set! pending '())` is dropped. *(LOW)*
21. **`racket/prologos/lib/prologos/ocapn/captp-wire.prologos:238-241`** — `unwrap-opt-desc` discards the descriptor label (`| syrup-tagged _ p -> wire-nat p`), so `desc:answer`, `desc:export`, `desc:import-object` and `desc:import-promise` all collapse to the same `some N`. *(LOW)*
22. **`racket/prologos/lib/prologos/ocapn/captp-core.prologos:2945-2948` vs `:2864-2871`** — two different encodings exist for "a vat outbound message" (ask-with-answer-position vs fire-and-forget `false false`), reachable through different drains, with nothing forcing them to agree. *(MEDIUM)*
23. **`racket/prologos/lib/prologos/ocapn/captp-core.prologos:2286-2287`** — the `op:abort` arm discards its reason and never signals end-of-session to the transport, so `run-frame-loop` keeps the socket open; upstream's `test_abort_after_setup` is commented out (`tests/op_abort.py:38-50`), which is why this passes. *(MEDIUM)*
24. **`racket/prologos/lib/prologos/ocapn/captp-core.prologos:1411-1428` + `interop-driver.prologos:153-161`** — the object table is five literal upstream swiss-nums and `seeded-vat`'s `next-id` is a hand-maintained literal `8N` whose "above every seeded id" property is load-bearing (`interop-driver.prologos:85-88`) and derived by hand. *(LOW; the code declares itself scaffolding at `:1403-1409`)*
25. **`racket/prologos/lib/prologos/ocapn/captp-core.prologos:1512-1526, 1814, 1828`** — `used:` replay markers are added on every withdrawal and never removed (only `park:` entries are, at `:1789`), and the whole table is copied in and out of every connection's `BridgeState` on every step (`interop-driver.prologos:181-195`). *(LOW)*
26. **`racket/prologos/lib/prologos/ocapn/interop-driver.prologos:95-98`** — "Still unseeded: Car Factory must SPAWN … `Effect` has no spawn variant" is stale: `eff-spawn` is `behavior.prologos:111` and `car-factory-builder-pos := 3N` is seeded at `interop-driver.prologos:138, 157`. *(LOW)*
27. **`racket/prologos/lib/prologos/ocapn/behavior.prologos:18-26`** — the header enumerates seven behaviours as the file's index; `data BehaviorTag` (`:43-62`) has eleven. *(LOW)*
28. **`racket/prologos/lib/prologos/ocapn/promise.prologos:84-92`** — "Phase 0's only consumer of the queue is the test suite" is stale: `dispatch-pipeline-on-our-q` (`captp-core.prologos:2011`) writes it on the production path via `pipeline-deliver`, and the storage is LIFO. *(LOW)*

---

#### Also missed by the first pass

The report over-indexed on `captp-core.prologos` and under-covered: (a) the Racket server's **outbound** path entirely, (b) concurrency beyond the two counters it found, (c) stale comments in the file it audited hardest, (d) our own outbound spec conformance.

**M1 — MEDIUM | stale docs | `tools/interop/run-ocapn-test-server.rkt:22-26`.** The file header states: *"Limitation: the server does NOT yet dispatch post-handshake frames through captp-core's connection-step. The full ocapn-test-suite needs swiss-num-addressed objects + op:deliver dispatch — that's Phase 59."* It does exactly that at `:230-252` and `:637-648`. A flat contradiction in the first 26 lines of the most-audited file. Fix: delete it.

**M2 — HIGH | concurrency | `tools/interop/run-ocapn-test-server.rkt:474-478`.** `sign-with-our-key` calls `run-prologos` (→ `process-string`) with **no semaphore**, from connection threads via `try-fetch-answer!` (`:427`) and `withdraw-gift-frame` (`:487`). The file's own comment at `:189-191` states the reason this is unsafe: *"`process-string` shares elaborator state across calls; serialise per-connection validation so concurrent connections cannot race."* Two concurrent handoffs — which is exactly the gifter scenario, two sessions by construction — re-enter the elaborator concurrently. This is a far wider window than #1's two-form race. Fix: wrap in `call-with-semaphore validate-sema`.

**M3 — HIGH | spec deviation / security | `tools/interop/run-ocapn-test-server.rkt:566-573`.** The outbound dial loop reads the peer's `op:start-session` at `n=0` and never calls `validate-incoming` — no version check, no location-signature verification. Every *inbound* peer is validated (`:663`); every peer we *dial* is trusted unconditionally. And we dial on nothing stronger than a location lifted out of a (per C2, unverified) handoff-give (`:601-614`). Fix: run `validate-incoming` on the outbound first frame and abort on non-empty reply.

**M4 — MEDIUM | silent failure | `tools/interop/run-ocapn-test-server.rkt:691-693`.** The crossed-hellos survivor enters `run-frame-loop` **without** `record-open-conn!` (the normal accept path calls it at `:702`), and the dial thread never calls it either. A session that survived a tie, or one we opened, is invisible to `try-enliven!`'s `open-conns` lookup (`:371`) — the gifter path silently no-ops with no log.

**M5 — MEDIUM | duplication / drift | `tools/interop/run-ocapn-test-server.rkt:571-583` vs `:622-648`.** Two frame loops with divergent behaviour: the outbound loop runs only `note-handoff-give!` + `drive-step`; the inbound loop adds `try-enliven!`, `try-fetch-answer!`, `drain-dials!` and `OCAPN_FRAME_HEX` logging. Nothing forces them to agree, and every future per-frame hook has to be added twice.

**M6 — MEDIUM | spec deviation | `racket/prologos/lib/prologos/ocapn/captp-core.prologos:3136-3144`.** The plural/singular GC drift is **bidirectional**, not inbound-only as #4 implies: `gc-answer-bytes` and `gc-export-bytes` still *emit* `"op:gc-answer"` / `"op:gc-export"` on the wire, reachable through the public `release-answer` / `release-import` / `bs-queue-release-import` API documented in `core.prologos:138-143`. Anything that calls those writes a frame no conforming peer parses. (The interop path is safe only because `connection-step` never calls them.)

**M7 — LOW-MEDIUM | spec deviation | `racket/prologos/lib/prologos/ocapn/syrup-wire.prologos:108, 235`.** `syrup-dict` is encoded and re-encoded in list order with no key sorting. Syrup requires canonically ordered dict keys, and every signature over a dict-bearing record is therefore order-sensitive. The server already works around this by *copying* the peer's location bytes rather than re-encoding them — and says so: *"our encoder writes hints as a syrup list where Python writes a dict, and the assertion compares encoded forms"* (`run-ocapn-test-server.rkt:411-413`). That workaround is the tell; the encoder is the bug.

**M8 — LOW | invariant asserted but not enforced | `racket/prologos/lib/prologos/ocapn/crypto.prologos:30`.** *"The caller must release via crypto-close-keypair when done."* `grep -rn close-keypair` over `lib/prologos/ocapn/` and `tools/interop/` returns only the declaration (`:52`) and the FFI side (`crypto-ffi.rkt:169`). Zero callers; the handle at `run-ocapn-test-server.rkt:154` is held for process lifetime by design, so the invariant is not merely unenforced but contradicted by the one real user.

**M9 — LOW | stale comment | `racket/prologos/lib/prologos/ocapn/captp-core.prologos:3282`.** *"Drain fuel: 5 successive turns is plenty for our test cases."* sits directly above `def drain-fuel : Nat := 20N`. The next line corrects it, but the lead sentence is the one a reader indexes on.

---

### 1.6 Interop driver + FFI queues

#### Verified findings

Each line is copy-pasteable; severity is my adjudicated value, not the report's where they differ.

1. **HIGH** | invariant asserted but not enforced | `captp-core.prologos:1517-1518` — the comment "The prefix cannot collide with a gift id, because gift ids come from the peer as opaque bytes" is false: gift-ids arrive unvalidated via `syrup-bytes-of` at `:1344-1346` and land in the same `[List GiftEntry]` that `parked-gid-loop` prefix-scans at `:1771-1782`, so a deposit of gift-id `"park:6:G"` + a deposit of `"G"` lets a peer resolve promise 6 (`interop-driver.prologos:133`, seeded on **every** connection) to an export of its choosing when any peer sends `op:listen 6` (`captp-core.prologos:2307`).
2. **HIGH** | same keyspace, second exploit | `captp-core.prologos:1828` + `:1845` — the single-use marker is stored as an ordinary gift entry (`bs-add-gift ident zero`), so a peer that deposits a gift whose id is literally `"used:<sess>|<side>|0"` (format at `:1524-1527`) makes the legitimate withdraw answer `withdraw-break-bytes rm-pos "replayed-handoff"` forever; the used-set is peer-writable and never pruned.
3. **HIGH** | spec deviation / missing authentication | `run-ocapn-test-server.rkt:570-580` vs `:670` — connections we dial never run `validate-incoming` on the peer's `op:start-session`: frame 0 is consumed only for `location-of-start-session`/`side-id-of-start-session` and we immediately send a signed `withdraw-gift` (`:577-579`) to an unauthenticated peer.
4. **HIGH** | hardcoded / test-shaped | `run-ocapn-test-server.rkt:407` — every gift is deposited under the constant id `#"prologos-gift"`, and since `bs-add-gift` conses at head (`captp-core.prologos:806-809`), `gift-lookup-loop` returns the newest (`:811-818`) and `gift-remove-loop` removes **all** matches (`:825-832`), so two concurrent enlivens cross-wire and then deadlock.
5. **HIGH** | wrong layer + duplication/drift | `run-ocapn-test-server.rkt:365-372` — the Racket enlivener fires on a raw substring `#"<15'ocapn-sturdyref"` found *anywhere* in a frame with no op-code or target check, while the Prologos twin gates on `nat-eq? tgt sturdyref-enlivener-pos` (`interop-driver.prologos:225`); same class at `:394` and `:602`.
6. **HIGH** | resource/lifecycle | `ocapn-conn-ffi.rkt:35-38` + `run-ocapn-test-server.rkt:631-632` — `ocapn-conn-reset` has zero call sites in the tree, and `run-frame-loop`'s exit branch is a bare `printf`, so `conn-table` retains a full seeded vat + bridge state for every connection ever accepted *and* every dial (`:563-564` inits before frame 0).
7. **MEDIUM** | resource/lifecycle + O(n) | `captp-core.prologos:1828` — used-markers are never removed (`bs-remove-gift` exists only at `:1789`, `:1790`, `:1829`, all keyed on `gid` or the park key), so the exporter-global list grows monotonically and every `op:listen` pays a linear scan through it via `parked-gid-for` (`:2307`).
8. **LOW** | concurrency | `run-ocapn-test-server.rkt:217-220` — `next-conn-id!` is a non-atomic `unbox`/`set-box!` called from the accept thread (`:698`, `:691`) and from dial threads (`:563`), so two connections can share a cid and clobber each other's `ConnectionState`.
9. **MEDIUM** | concurrency | `ocapn-dial-ffi.rkt:32`, `:36`, `:41-43` — the dial queue is an unsynchronised module-level `set!`, and its two writers are on different threads (`interop-driver.prologos:243` under `validate-sema`; `run-ocapn-test-server.rkt:612` **not** under it) while `ocapn-dial-drain` runs unguarded from `:647`, so a request can be dropped silently; `(append pending (list …))` at `:36` is also O(n) per push.
10. **LOW** | silent failure / asymmetry | `ocapn-conn-ffi.rkt:33` — `ocapn-conn-fetch` returns `#f` for an unknown connection while its sibling `ocapn-gift-fetch` takes an `empty` fallback for exactly this reason (`ocapn-dial-ffi.rkt:23-25`: "returning #f from an FFI crashes `nf` rather than erroring, which is a defect that has already cost one debugging session").
11. **LOW** | invariant asserted but not enforced | `vat.prologos:344-351` — the comment names the exact failure ("If a future caller passes an arbitrary id that stops being true and this needs a max") and `:351` is a bare `[suc id]`; neither the max nor the one-spawn-per-turn constraint is enforced, and `apply-effects` (`:366-369`) does not count spawns.
12. **MEDIUM** | resource/lifecycle | `run-ocapn-test-server.rkt:553-587` — the dial thread's `with-handlers` wraps the port closes at `:586-587`, so any exception (refused connect, malformed frame, write to a closed socket) leaks both ports; separately `open-conns` (`:339`) and `pubkey-by-port` (`:341`) are written at `:344-346` and never removed, and `half-open-dials` (`:311`) is removed only in the `ours-first?` branch (`:690`).
13. **MEDIUM** | silent failure | `run-ocapn-test-server.rkt:406` and `:422` — an exporter answer with no `<18'desc:import-object` drops the enliven entirely (the `(when obj …)` has no else, and `pending-enlivens` was already removed at `:399`), and an unknown receiving-port pubkey defaults to `#""`, producing a `desc:handoff-give` with an empty receiver-key that is then signed at `:428-429` and sent as valid.
14. **MEDIUM** | fragile / unenforced discipline | `interop-driver.prologos:174-177`, `:193-195`, `:259-261` — three side-effecting FFI calls are forced only by hand-written `| true -> X | false -> X` matches whose comment at `:253-257` states the failure mode ("dropped outright and the side effect never happens — which presents as a queue that stays empty with no error anywhere"); nothing detects the next author writing the natural `let`.
15. **MEDIUM** | silent failure | `run-ocapn-test-server.rkt:233-237`, `:243-252` — `drive-step` converts every exception and every unparsable result into `#""` and keeps the connection alive, so the peer cannot distinguish "no reply needed" from "the step blew up", and the only signal is a `printf` the interop gate does not assert on.
16. **LOW** | dead code / drift risk | `interop-driver.prologos:56-57` — the `ocapn-dial-drain` foreign declaration is unused (`dial-drain` appears nowhere else; the server calls the Racket function directly at `run-ocapn-test-server.rkt:617`), so its declared Prologos signature is never checked against the implementation.
17. **LOW** | stale comment | `interop-driver.prologos:95-98` — "Still unseeded: Car Factory must SPAWN and the promise resolver must return a PAIR… `Effect` has no spawn variant" is false on all three counts: `seeded-vat` seeds `beh-car-factory-builder` at `:157` and the pair at `:158-159`, and `apply-effect` has an `eff-spawn` arm at `vat.prologos:364`.
18. **LOW** | stale comment | `captp-core.prologos:794-797` — "wire-level op:deposit-gift / op:withdraw-gift dispatch is deferred to Phase 52b (requires new CapTPOp variants)" is contradicted by the dispatch at `:1356-1363` and `:1855-1876` and by `:1258-1260`, which records that the dedicated variants were added and then reverted.

---

#### Also missed by the first pass

The report under-covered **category 10 (spec deviation vs the reference)**, **category 6 (duplication)** and **category 1 (test-shaped input handling)** on the Racket side. Everything below is verified at HEAD.

**M1. HIGH | spec deviation | `run-ocapn-test-server.rkt:281-296` | The hand-rolled `syrup-skip` implements a strict subset of Syrup and throws on legal input.**
What breaks it: any frame containing a float, a set, or a `(`/`l`/`d`-opened container. Upstream's own encoder emits `b'D' + struct.pack('>d', obj)` for floats (`/tmp/ocapn-test-suite/contrib/syrup.py:114-115`), `b'F'` for float32 (`:228`), `b'#'…b'$'` for sets (`:123-125`), and its reader accepts `(`/`l` as list openers and `d` as a dict opener (`:192`, `:203`). `syrup-skip` handles only `< [ {` (`:284-287`) and `n t f` (`:288`); on `D` (byte 68) it falls to `:289-296`, where the digit loop consumes nothing and `(string->number (bytes->string/latin-1 (subbytes bs i j)))` on the empty string yields `#f`, so `(+ j 1 #f)` raises a contract violation.
Evidence: `:284` `[(or (= b 60) (= b 91) (= b 123))` — three openers only; `:296` `(+ j 1 (string->number …))` with no `#f` guard.
Fix shape: either extend the skipper to the full Syrup grammar, or delete it and call the Prologos decoder (`prologos::ocapn::syrup-wire`) through the same `run-prologos` path everything else uses.

**M2. HIGH | silent failure | `run-ocapn-test-server.rkt:300-303` + `:652` | `record-field` has no bounds check, and every parse failure kills the connection with no `op:abort`.**
What breaks it: an `op:start-session` with fewer than three fields — `location-of-start-session` (`:308`) asks for field 2, `record-field`'s loop `(if (= k n) … (loop j (add1 k)))` never terminates on short input and walks `syrup-skip` off the end into a `bytes-ref` range error. Called at `:673`, `:680`, `:702` inside `handle-connection`'s body, so the exception is swallowed by `:652-654`, which prints and falls through to `:708-709` — the peer sees a bare socket close, never the `op:abort` the spec expects. Same for every M1 throw.
Fix shape: bound the field loop and return `#f`; on any frame-parse failure send `build-abort-bytes` (already defined at `:318-322`) before closing.

**M3. MEDIUM | duplication / drift | `run-ocapn-test-server.rkt:356-361`, `:456-470`, `:281-303` | A second, independent Syrup implementation with nothing forcing it to agree with the first.**
`syrup-nat` (`:356`), `syrup-bytestring` (`:456`), `syrup-symbol` (`:459`), `desc-record` (`:359`), `gcrypt-sig` (`:465`) and the skipper/field-reader duplicate `prologos::ocapn::syrup-wire`. The comment at `:417-419` even documents a *known* divergence ("our encoder writes hints as a syrup list where Python writes a dict") and works around it by copying peer bytes verbatim — an acknowledged drift with no test pinning either side. The report's #5 names the enlivener duplication but never names the codec duplication, which is larger.

**M4. MEDIUM | hardcoded / test-shaped | `run-ocapn-test-server.rkt:528-537` | `peer-hint` substring-scans for the key and only reads string-marked values.**
What breaks it: (a) a sturdyref whose swiss-num bytes happen to contain `4"host` — the scan at `:531-534` matches anywhere in the buffer, so the wrong bytes become the host; (b) an integer-valued `port` hint — `syrup-lenstr` is called with marker `34` (`"`) at `:536`, so a `+`-terminated nat returns `(values #f #f)` and the dial is silently abandoned at `:547-548` with a printf. It passes today only because upstream builds hints via `urllib.parse.parse_qsl` (`/tmp/ocapn-test-suite/utils/ocapn_uris.py:45`), which yields strings.

**M5. MEDIUM | resource / DoS | `captp-core.prologos:1810-1815` | Parked withdrawals grow the exporter-GLOBAL table without bound, peer-driven.**
`park-reply` adds **two** entries per withdraw (park key `:1814` + ident `:1815`), and the only removals (`:1789-1790`) require the deposit to arrive and `op:listen` to fire. A peer withdrawing gift-ids that will never be deposited grows the shared list forever, across all connections, degrading every subsequent `op:listen` (`:2307`). Privilege required: a signature that passes `signed-receive-valid?` (`:1713-1718`) — self-signing sufficiency is INFERRED (see U2). The report's #7 covers only the used-marker half.

**M6. MEDIUM | resource / lifecycle | `run-ocapn-test-server.rkt:601-618` + `:551-556` | Unbounded dial amplification from replayed frames.**
`note-handoff-give!` queues a dial for **every** frame containing `give-marker` with no dedup (`:602-614`), and it is called on every inbound frame at `:637` and again in the outbound loop at `:582`; `drain-dials!` (`:616-618`) then spawns one thread and one TCP connection per request (`:551-556`). A peer replaying one `handoff-give` N times gets N threads and N sockets — and per **CONFIRMED 12** they leak on any exception. `try-enliven!` has the same shape: one `pending-enlivens` slot per matching frame (`:375`), removed only on a matching answer (`:399`).

**M7. MEDIUM | silent failure | `run-ocapn-test-server.rkt:222-225` | `drive-init!` discards its result — and this is the reachable route to the `#f` in CONFIRMED 10.**
`drive-step` inspects the result shape carefully at `:242-252` precisely because `run-prologos` can return a non-`String` error result *without raising*. `drive-init!` performs no such check and ignores the return value entirely, so an `init-connection` that fails to stash is completely invisible; the next `step-connection` then calls `conn-fetch cid` (`interop-driver.prologos:269`) and receives `#f` from `ocapn-conn-ffi.rkt:33`. This is the failing sequence the report's #10 needed and did not find.

**M8. MEDIUM | silent failure | `interop-driver.prologos:267-268` | An undecodable frame returns `""` with no log and no abort.**
`match [decode-op [hex-to-bytes hex-frame]] | none -> ""`. Combined with `drive-step`'s three `#""` returns (`:237`, `:246`, `:251`), the server has four distinct "produced nothing" paths that are indistinguishable both on the wire and in the logs. A peer sending an op we have no `CapTPOp` variant for gets silence rather than the abort the spec calls for.

**M9. MEDIUM | spec deviation / reflection | `vat.prologos:441-446` + `captp-core.prologos:2964-2966` | An `op:deliver` to a nonexistent export with no answer-pos is echoed back to the peer.**
`deliver-msg`'s `none` arm with `ap = none` falls to `enqueue-outbound m v` (`:446`), and `drain-outbound` turns `vat-outbound` into wire bytes aimed at the same position. So addressing any position we don't hold makes us emit an `op:deliver` at that position — attacker-selected traffic amplification, and the mechanism that silently swallows the exporter's `fulfill` to enliven slots ≥900 (`run-ocapn-test-server.rkt:351-354`), since no actor is ever placed there. The report flags the 900 constant in its cross-cutting note but not this consequence.

**M10. MEDIUM | unimplemented behind a passing test | `captp-core.prologos:1322-1326` | A gift whose refr is not `<desc:export N>` is silently accepted and dropped.**
`deposit-with-gid`'s `none` arm returns `bridge-step v st` unchanged — no gift recorded, no break, no log. Since `deposit-gift` is fire-and-forget by design (`:1356-1357`), the gifter believes it succeeded and the receiver parks forever. Note this is the *same* class of bug the code comment at `:1341-1343` says was already fixed once for the gift-id ("bridged through unchanged when that returned none, so no gift was ever recorded and nothing said so") — the sibling arm two functions away was never given the same treatment.

**M11. MEDIUM | hardcoded / test-shaped | `run-ocapn-test-server.rkt:366` and `:404-405` | The resolve-me and the answered object are both taken as the FIRST `<18'desc:import-object` anywhere in the frame.**
`op:deliver`'s fields are ordered `(to, args, answer-pos, resolve-me)`, so any `desc:import-object` appearing **inside args** precedes the resolve-me descriptor. `rm` at `:366` therefore picks the argument, and we answer the enliven at that wrong export position (`:433`). It passes only because the suite's enliven message carries exactly one import-object; a peer that passes an object reference alongside the sturdyref redirects our signed `handoff-give` to a position of its choosing. Same defect at `:404-405` for `obj`.

---

### 1.7 Test server — handshake, crossed hellos, Syrup slicing

#### Verified findings

(verbatim-ready, one line each)

1. HIGH | lifecycle/test-shaped | `run-ocapn-test-server.rkt:561,673,690,696` | `half-open-dials` entries are removed only in the `ours-first?` branch (`:690`), so a completed dial leaves a permanent entry; a later ordinary connection from that same location hits `:673`, and when `our-side-id > theirs` we abort the peer's legitimate connection at `:696` without clearing the entry — permanently. The suite cannot see it: `netlayers/testing_only_tcp.py:49-56` mints `uuid.uuid4().hex` per netlayer, so two locations never collide.
2. HIGH | silent failure/spec deviation | `run-ocapn-test-server.rkt:593,595-599,601-614` | `note-handoff-give!` byte-scans the raw frame for `<17'desc:sig-envelope<17'desc:handoff-give`, which cannot distinguish structure from the interior of a length-prefixed bytestring, so a peer can embed the marker in a bytestring argument and make us `tcp-connect` (`:556`) to a host:port of its choosing; the comment at `:589-592` asserts "appears nowhere else on the wire" and nothing enforces it. Same defect in `try-enliven!` (`:365`) and `try-fetch-answer!` (`:394`).
3. HIGH | incomplete parser | `run-ocapn-test-server.rkt:281-296` | `syrup-skip` covers 6 of 11 Syrup forms; **executed**: sets `#3"abc$`, `D`+8, `F`+4, `l…e`, `(…)`, `d…e` all raise `+: contract violation` from `:296`, and a truncated record `<1'x` raises `bytes-ref: index is out of range` — while upstream *does* emit `D` (`contrib/syrup.py:115`) and `#…$` (`:125`) and accepts `[(l` / `{d` (`:192`, `:203`).
4. HIGH | silent failure | `tools/interop/ocapn-framing.rkt:164-185` | `read-syrup-frame` has no `#`/`$` (set) case and no underflow guard on `depth` (`:168`); **executed**: `#"<10'op:deliver#3:abc$>"` raises `unexpected byte 35 at depth 1` (reported by `run-ocapn-test-server.rkt:631-632` as "peer closed", a parse error disguised as a disconnect), and `#"]<1'a><1'b>"` returns the garbage frame `#"]<1'a"` **with no error**, leaving `><1'b>` misaligned in the stream forever.
5. MEDIUM | concurrency | `run-ocapn-test-server.rkt:472-476` | `sign-with-our-key` calls `run-prologos` without `validate-sema`, which the file's own comment at `:192-193` declares mandatory ("`process-string` shares elaborator state across calls; serialise…"), and it is reached from a connection thread (`:429`) and a dial thread (`:489`) while `drive-step` (`:232`) holds the semaphore.
6. MEDIUM | concurrency | `run-ocapn-test-server.rkt:217-220, 352-354` | `next-conn-id!` and `next-enliven-slot!` are unsynchronised read-modify-writes across the per-connection threads spawned at `:719-722`; a colliding conn-id aliases the whole `ConnectionState` keyed at `ocapn-conn-ffi.rkt:24`.
7. HIGH | silent failure | `run-ocapn-test-server.rkt:691-693 vs :702` | The crossed-hellos survivor enters `run-frame-loop` without `record-open-conn!` (and outbound dials never register either, `:562-565`), so a later enliven for that peer finds `(hash-ref open-conns loc #f)` = `#f` at `:371` and the `(when exporter …)` at `:373` falls through with no log and no reply — the enlivening peer waits forever.
8. MEDIUM | resource/lifecycle | `racket/prologos/ocapn-conn-ffi.rkt:35-38` + `run-ocapn-test-server.rkt:339,341,350,497` | `ocapn-conn-reset` is defined and documented ("Drop a connection's state once it closes") but **verified unreferenced** — grep returns only its definition and its `provide`, and `interop-driver.prologos:43-46` declares only `conn-stash`/`conn-fetch` — so every connection's export+import tables are retained for the process lifetime, alongside `open-conns`, `pubkey-by-port` (a `hasheq` keyed on the output *port object*, pinning closed ports), `pending-enlivens` and `pending-gives`.
9. MEDIUM | fault isolation | `run-ocapn-test-server.rkt:637-639 vs :624-628` | `run-frame-loop`'s `with-handlers` wraps only the `(read-frame cin)` expression, so a `write-frame` to another connection's stale port from `try-enliven!` (`:377`) or `try-fetch-answer!` (`:409`, `:431`) unwinds to `handle-connection`'s handler at `:652` and tears down the *healthy* connection that merely carried the enliven.
10. MEDIUM | unimplemented behind a passing test | `interop-driver.prologos:266-269` | `step-connection` returns `""` for any frame `decode-op` cannot decode (`| none -> ""`, `:268`), indistinguishable from "decoded fine, nothing to send"; the server logs `0 out bytes` (`:641-642`) and the peer, which the spec entitles to `op:abort`, sees silence.
11. LOW | invariant asserted not enforced | `interop-driver.prologos:46` + `ocapn-conn-ffi.rkt:31-33` | The FFI type `Nat -> ConnectionState` is unsound — the implementation returns `#f` on a miss — and the sibling `ocapn-gift-ffi.rkt:35-38` documents *exactly this defect* ("returning `#f` would put a non-list where a `[List GiftEntry]` is expected — which crashes `nf` rather than erroring") and takes a fallback argument to avoid it, while `conn-fetch` (`:46`) does not.
12. MEDIUM | wrong extraction | `run-ocapn-test-server.rkt:366,372,404` | `try-enliven!` and `try-fetch-answer!` take the *first* `desc:import-object` in the whole frame as the resolve-me, so an imported reference passed as an argument is picked instead; and `:367` guards only on `(and i rm)` — nothing checks the frame is even an `op:deliver` of `enliven` to export 5.
13. MEDIUM | spec deviation | `syrup-wire.prologos:14,83` | The encoder emits `"n"` for `syrup-null`, which upstream's decoder has no case for (`contrib/syrup.py:257-260` raises `SyrupEncodeError`), and which our own framing reader also rejects — **executed**: `read-frame` on `#"<1'xn>"` → `read-syrup-frame: unexpected byte 110 at depth 1`.
14. MEDIUM | silent failure | `run-ocapn-test-server.rkt:147-151,191-202,708-709` | A validation failure that is not a clean reject — `check-incoming-start-session` raising, or a result not matching `#px"^(\".*\") : String$"` at `:148` — propagates to `handle-connection`'s handler (`:652`) and produces a bare TCP close with no `op:abort` and no reason, with the regexp on `pretty-print` output as the load-bearing discriminator.
15. MEDIUM | drift risk / no coverage | `run-ocapn-test-server.rkt:305-308,451-454` | `side-id-of-start-session` *slices* field 1 out of the frame and hashes it while the peer computes the same value by *re-encoding* (`utils/captp.py:114-117` `self.public_key.to_syrup()`), and the session-id derivation (`:451-454`) independently reimplements `utils/captp.py:125-146` — **verified zero unit coverage**: `grep -rn "side-id-of\|session-id-of\|crossed" racket/prologos/tests/` returns nothing; the only gate is the two upstream tests allow-listed at `tools/interop/ocapn-run-tests.py:50-51`.
16. MEDIUM | concurrency + stall | `ocapn-dial-ffi.rkt:34-43` + `run-ocapn-test-server.rkt:581-585 vs :645-647` | The global dial queue uses bare `set!` read-modify-write for both append and drain, so concurrent drains lose requests queued between the reads; and the dial thread's own frame loop calls `drive-step` (`:583`) but never `drain-dials!`, so a dial queued on an outbound connection sits until some inbound connection happens to step.
17. LOW | stale comment | `syrup-wire.prologos:22` | "Floats / dicts / sets / bytes are deferred" contradicts the code — dicts are encoded at `:108`, re-encoded at `:235`, decoded at `:489-498`, and bytes are encoded at `:106`; only floats and sets are genuinely absent.
18. LOW | resource | `run-ocapn-test-server.rkt:551-587,688-689` | The dial thread's `with-handlers` (`:553-555`) wraps the close calls at `:586-587`, so any raise from `write-frame`, `drive-step` or `withdraw-gift-frame` leaks both ports; and `(with-handlers ([exn:fail? void]) …)` at `:688-689` discards the crossed-hellos abort write, hiding exactly the dead-port signal that would expose finding 1's stale entry.

---

#### Also missed by the first pass

The report has **zero findings under category 2 (wrong layer)** and found only one category-9 stale comment — in a *secondary* file, while the primary file's header is stale. Its category-1 coverage stopped at the crossed-hellos keying and missed a hardcoded constant with worse blast radius.

**M1 — MEDIUM | stale comment | `run-ocapn-test-server.rkt:25-28`.** The file header states "Limitation: the server does NOT yet dispatch post-handshake frames through captp-core's `connection-step`. … that's Phase 59." It does — `drive-step` (`:230-252`) calls `step-connection`, invoked on every frame at `:640` and `:583`. The audit hunted stale comments in `syrup-wire.prologos` and missed the one at the top of the file it was auditing. `:22-23` ("read peer frames, log, close") is stale in the same way.

**M2 — HIGH | remote DoS | `run-ocapn-test-server.rkt:300-303`.** `record-field` has no bounds check: it walks past the closing `>` and calls `syrup-skip` on byte 62. **Executed**: `record-field #"<17'desc:handoff-give>" 1` → `+: contract violation`; `record-field #"<17'op:start-session3\"1.0>" 2` → same. This is reachable from every attacker-controlled byte-scan path (`:370`, `:372`, `:405`, `:607`, `:608`) with *no* prior validation, and from `:673`/`:680` on a short `op:start-session`. A peer sending `<desc:sig-envelope <desc:handoff-give>>` raises out of `note-handoff-give!` (`:637`) — which sits *outside* `run-frame-loop`'s handler — into `handle-connection`'s handler at `:652`, closing the connection.

**M3 — HIGH | hardcoded/test-shaped + correctness | `run-ocapn-test-server.rkt:407`.** `(define gid #"prologos-gift")` is a **process-wide constant** used for every gift we deposit (`:413`) and every give we sign (`:426`). The gift table is keyed *by gift-id* — `captp-core.prologos:429-430` (`gift-entry : String -> Nat`), looked up by `gift-lookup-loop` (`:811-823`) and dropped by `gift-remove-loop` (`:825-828`). Two outstanding handoffs alias into one key; a withdraw redeems whichever entry the list walk reaches first. It passes only because upstream's handoff tests run one gift at a time. What breaks it: two `HandoffRemoteAsExporter` flows overlapping.

**M4 — MEDIUM | silent failure | `run-ocapn-test-server.rkt:422`.** `(hash-ref pubkey-by-port r2g-out #"")` splices an **empty byte string** into the middle of the `desc:handoff-give` record when the lookup misses — producing a record with one *fewer field*, not merely a wrong receiver-key. `pubkey-by-port` is populated only by `record-open-conn!` (`:346`), so this is precisely reachable in report #7's crossed-hellos-survivor case. The peer sees a malformed give and a signature over it.

**M5 — MEDIUM | invariant asserted but not enforced | `run-ocapn-test-server.rkt:561,611 vs :574,673`.** `half-open-dials` and `pending-gives` are keyed on bytes that came from **our** re-encoder (`interop-driver.prologos:220` → `wire::re-encode`), and are looked up against the peer's **verbatim** `op:start-session` field 2. The comment at `:274-278` asserts the two "slice to identical bytes"; nothing checks it. It holds today only because `re-encode` is byte-identical (`syrup-wire.prologos:199`, test-pinned) — which is also why the comment the report leaned on at `:417-419` is stale. On mismatch, `(when env …)` at `:575` is a **silent no-op**: the withdraw never goes out, the handoff hangs, and nothing is logged.

**M6 — MEDIUM | lifecycle/correctness | `run-ocapn-test-server.rkt:344`.** `open-conns` is keyed by location, so a second session from the same peer location silently `hash-set!`s over the first's out-port. A stable-location peer with two concurrent sessions loses the first one's routing entry with no error.

**M7 — MEDIUM | wrong layer / unimplemented | `run-ocapn-test-server.rkt:351-354,381,394`.** `next-enliven-slot!` invents export positions from 900 upward and advertises them to the exporter as `<desc:import-object slot>` (`:381`), but they are **never registered in captp-core's export table** — they exist only as a byte pattern matched by `find-subbytes` at `:394`. The exporter's answer, addressed `<desc:export 900>`, is then *also* handed to `drive-step` (`:640`), where captp-core sees a deliver to an export it has never heard of. (INFERRED — I did not exhibit captp-core's response to an unknown export.) Moving this to Prologos means giving the enlivener a real exported resolve-me from the connection's export table instead of a Racket counter.

**M8 — MEDIUM | duplication/drift | `run-ocapn-test-server.rkt:637-640`.** Every inbound frame is processed **twice by two independent handoff implementations**: the Racket byte-scanners (`note-handoff-give!`, `try-enliven!`, `try-fetch-answer!`) and then captp-core via `drive-step`. Nothing forces them to agree on what a frame means; the Racket side acts on frames the Prologos side may reject, and both can emit for the same frame. This is the sharp form of the already-known "gifter-side handoff lives in Racket" — the problem is not the location alone, it is that both run unconditionally on the same bytes.

**M9 — LOW | concurrency | `run-ocapn-test-server.rkt:352-354`.** `next-enliven-slot!` is strictly worse than `next-conn-id!`: it does `(set-box! (add1 (unbox …)))` and then a **separate** `(unbox …)`, so two threads can read back the *same* slot even with no interleaving inside the first statement — T1 sets 901, T2 sets 902, both then read 902.

**M10 — MEDIUM | unvalidated input | `interop-driver.prologos:214-221`.** The sturdyref enlivener does no validation of its argument: `first-arg-bytes` re-encodes whatever the first element is and hands it to `dial-request` (`:243`); nothing checks it is an `ocapn-sturdyref` record. Combined with M2/report #2 this is a second, fully *legitimate* outbound-connect path — deliver to export 5 with any record whose bytes contain `4"host` and `4"port` and `dial-sturdyref!` will connect there.

**M11 — LOW | wrong extraction | `run-ocapn-test-server.rkt:528-537`.** `peer-hint` scans for the key's length-prefixed form (`4"host`) anywhere in the byte string, including inside a hint *value*, and accepts a hit in a list as readily as in a dict — so a value string containing `4"host` yields the wrong host for the dial.

---

### 1.8 Test server — handoff receiver + gifter

#### Verified findings

— copy verbatim

1. **CRITICAL** | spec deviation / capability theft | `captp-core.prologos:1699` — the `desc:handoff-give` envelope's own signature is never verified and the key that verifies the receive is extracted from that unverified give (`receive-receiver-key-of` → `signed-give-receiver-key` → `give-receiver-key-of` = `handoff-give` arg 0), so the entire verification chain is attacker-supplied; `verify-raw` has exactly two production call sites tree-wide (`handshake.prologos:434`, `captp-core.prologos:1699`) and neither checks a give.
2. **CRITICAL** | invariant not enforced | `captp-core.prologos:804-809` — `bs-add-gift` records `gid → pos` only, so nothing binds a gift to the session that deposited it and `withdraw-with-receive` (`:1866-1869`) can therefore never check that the give's `session`/`gifter-side` match a session that actually deposited.
3. **HIGH** | hardcoded | `run-ocapn-test-server.rkt:407` — every gift we deposit as gifter uses the literal id `#"prologos-gift"`, so two concurrent handoffs from this process collide on one id at the exporter.
4. **HIGH** | correctness | `captp-core.prologos:825-832` — `gift-remove-loop` removes **all** entries matching a gift-id (`| true -> gift-remove-loop rest gid`), so one withdrawal deletes every same-id gift including undelivered ones.
5. **HIGH** | unimplemented behind a passing test | `run-ocapn-test-server.rkt:484` — the `handoff-count` we send as receiver is the hardcoded byte string `#"0+"`, so a second gift redeemed on the same exporter session is rejected as a replay by our own exporter (`captp-core.prologos:1843-1847`) and by upstream (`utils/captp.py:107-109`).
6. **HIGH** | silent failure / stream corruption | `run-ocapn-test-server.rkt:422` — `(hash-ref pubkey-by-port r2g-out #"")` splices an empty receiver-key into a signed `desc:handoff-give`, producing a 4-field record where `captp_types.py:289` asserts 5; `record-open-conn!` (`:343-346`) is called from exactly one site (`:702`) and never on the crossed-hellos-winner path (`:691-693`) nor in `dial-sturdyref!` (`:542-587`).
7. **HIGH** | silent failure / security | `run-ocapn-test-server.rkt:601-614` — `note-handoff-give!` dials whatever host:port a byte-pattern match yields with no signature check, no check that the give names our key, and no allow-list; the outbound dial reaches arbitrary endpoints even though the listener is loopback-only (`:715`).
8. **HIGH** | test-shaped scanning | `run-ocapn-test-server.rkt:366, 372` — `try-enliven!` takes the first `desc:import-object` anywhere in the frame as the reply target (args precede `resolve-me` on the wire) and fires on any frame containing a sturdyref, with no check that the deliver targets the enlivener export.
9. **HIGH** | false-positive byte scanning | `run-ocapn-test-server.rkt:593, 601` — a peer that relays an opaque encoded give inside a bytestring makes `note-handoff-give!` treat the payload as a live give and dial its exporter; the comment at `:591-592` asserts `desc:handoff-give` "appears nowhere else on the wire", which nothing enforces and the peer controls.
10. **HIGH** | parser gap | `run-ocapn-test-server.rkt:281-296` — `syrup-skip` has no case for Syrup floats (`F`/`D`), which `ocapn-framing.rkt:172-179` does handle; verified empirically that it raises `+: contract violation … given: #f` via the `(+ j 1 (string->number ""))` fallthrough at `:296`.
11. **HIGH** | resource lifecycle / wrong layer | `run-ocapn-test-server.rkt:645-647` + `interop-driver.prologos:259-262` — every gifter enliven fires both the Racket-side connection reuse and the Prologos-side dial (`maybe-dial` is unconditional in `run-step`), and the dial blocks forever per the file's own comment at `:330-333`, leaking a thread, a socket, a conn-id and a `half-open-dials` entry each time.
12. **HIGH** | wrong key / drift | `run-ocapn-test-server.rkt:339, 702` — `open-conns` is keyed by peer location, which identifies a peer and not a connection, and `hash-remove!` on it appears zero times in the file, so a peer's second session overwrites its first and a stale closed port at `:377` raises into `handle-connection`'s handler (`:652`), killing the connection currently being serviced.
13. **HIGH** | concurrency | `run-ocapn-test-server.rkt:352-354` — `next-enliven-slot!` does `set-box!` then a *separate* `unbox`, so two interleaved callers both return the same slot; `next-conn-id!` (`:217-220`) is a non-atomic read-modify-write outside `validate-sema`, and duplicate cids collide in `ocapn-conn-ffi.rkt`'s `conn-table`.
14. **MEDIUM** | concurrency | `run-ocapn-test-server.rkt:393, 399` — `try-fetch-answer!` iterates `pending-enlivens` with `in-hash` while another connection thread may `hash-set!` it, and the `hit` test at `:393` and `hash-remove!` at `:399` are not atomic, so two threads can both pass and send the give twice.
15. **MEDIUM** | duplication / drift | `run-ocapn-test-server.rkt:565-585` vs `:622-649` — two copies of the frame loop with different hook sets; the outbound loop runs only `note-handoff-give!` + `drive-step`, so a give arriving on a dialled connection queues a dial that `drain-dials!` never drains on that thread, a gifter enliven on a dialled connection is ignored, and `OCAPN_FRAME_HEX` is blind on outbound connections.
16. **MEDIUM** | silent accept / crash | `run-ocapn-test-server.rkt:571-580` — the outbound handshake never runs `validate-incoming` (`:191-202`, called only at `:670`) and calls `location-of-start-session` unconditionally on frame 0; verified empirically that `record-field` on a 1-arg `op:abort` asking for field 2 raises `+: contract violation … given: #f`, which `:553` swallows and leaves the `pending-gives` entry permanently.
17. **MEDIUM** | silent failure | `run-ocapn-test-server.rkt:528-537, 546-548` — `peer-hint` reads only string-valued hints, by naive substring scan over the whole sturdyref rather than by parsing the hints dict, and a hint it cannot read silently cancels the dial with one printf and leaves the handoff stalled.
18. **MEDIUM** | resource lifecycle | `ocapn-conn-ffi.rkt:35` + `run-ocapn-test-server.rkt:311, 339, 341, 350, 497` — `ocapn-conn-reset` has zero call sites tree-wide, and `open-conns`, `pubkey-by-port` and `pending-gives` are never removed from at all, so one full `ConnectionState` plus several table rows leak per connection in a long-running server.
19. **MEDIUM** | silent failure | `run-ocapn-test-server.rkt:233-237` — `drive-step` converts any exception from `connection-step` into `#""`, indistinguishable from the two other `#""` returns at `:245` and `:251` and from a legitimate no-reply, so a real defect presents to the peer as a 60s timeout.
20. **MEDIUM** | drift risk | `run-ocapn-test-server.rkt:351, 394` — `enliven-slot` starts at 900 with nothing reserving that range from `captp-core`'s per-connection export allocator, and the match at `:394` is a raw byte scan for `<11'desc:export{slot}+`.
21. **LOW/MEDIUM** | stale comment contradicting the code | `run-ocapn-test-server.rkt:417-419` — the comment claims "our encoder writes hints as a syrup list where Python writes a dict"; both `encode` (`syrup-wire.prologos:108`) and `re-encode` (`:235`) emit `{…}` for `syrup-dict` and the decoder produces `syrup-dict` for byte 123 (`:489-498`), so the stated reason is false. The genuine issue it obscures: `half-open-dials` is keyed by re-encoded bytes at `:561` and looked up by raw peer bytes at `:673`.
22. **LOW** | wrong layer | `run-ocapn-test-server.rkt:281-322, 356-370, 456-493` — ~90 lines of hand-rolled Syrup reimplement encoders that already exist in `syrup-wire.prologos` / `captp-wire.prologos`, both already imported at `:88-89`; the two parsers have already diverged on float handling.

---

#### Also missed by the first pass

The report is ~85% server-side. It under-covered categories **5 (invariant asserted but not enforced)**, **8 (concurrency)** beyond the box counters, and the **Prologos library** half of the surface entirely apart from claim 1. Nine findings it should have caught:

**M1 — CRITICAL | invariant asserted but not enforced | `captp-core.prologos:1517-1518` | The comment's reasoning is exactly backwards, and the gift table is a shared namespace an unrelated peer can write into.**
The comment reads: *"The prefix cannot collide with a gift id, because gift ids come from the peer as opaque bytes and this key is only ever CONSTRUCTED here."* Peer-supplied opaque bytes is precisely what lets the peer **choose** bytes equal to a constructed key. `do-deposit-gift` (`:1317-1319`) stores the raw peer gid with no escaping or prefix rejection, `deposit-gift` is dispatched on the bootstrap object by method name (`:1361-1362`) so any connected peer can call it, and the table is **process-global across all connections** (`ocapn-gift-ffi.rkt` + `interop-driver.prologos:181-195`).
*What breaks it (a) — replay-guard poisoning:* attacker deposits gid `"used:" ++ SESS ++ "|" ++ SIDE ++ "|0"`. The legitimate receiver's **first** withdraw with that triple hits `withdraw-with-identity` (`:1843-1847`) → `bs-lookup-gift ident` → `some _` → `break "replayed-handoff"`. A capability handoff between two other parties is denied.
*What breaks it (b) — park hijack:* attacker deposits gid `"park:" ++ digits(p) ++ ":" ++ chosen-gid`. `bs-add-gift` **prepends** (`:806-809`) and `parked-gid-loop` (`:1771-1777`) returns the **first** prefix match, so the forged entry shadows a real park; `settle-parked` (`:1798-1803`, reachable from `op:listen` at `:2307`) then resolves promise `p` with the export of the attacker's chosen gift-id.
*Fix shape:* length-prefix or tag the namespaces (`bs-add-gift` should reject/escape a gid matching a reserved prefix), or give the used-set and park-set their own BridgeState fields as the comment itself says was the rejected alternative.

**M2 — HIGH | test-shaped / spec deviation | `run-ocapn-test-server.rkt:160-165, 167-174, 313` | One process-wide session keypair is used for every connection.**
`keypair-handle` and `start-session-bytes` are built once and the same signed start-session is written to every accepted connection (`:657`) and every dialled one (`:557`); `our-side-id` (`:313`) is a process constant. Upstream mints a **fresh Ed25519 key per session** (`utils/captp.py:49-50`). Consequence: `session-id-of` (`:451-454`) depends only on the peer's side-id, so any peer reusing a session key across two connections to us produces identical session-ids — and the replay guard is keyed on session (`used:sess|side|count`), so its legitimate second handoff is refused. It passes only because every Python `CapTPSession` mints a fresh key.

**M3 — HIGH | concurrency | `run-ocapn-test-server.rkt:377, 409, 431` vs `:644` | Two threads write frames to the same output port with no lock.**
`try-enliven!` and `try-fetch-answer!` write to *another* connection's output port from the servicing connection's thread, while that connection's own thread writes at `:644`. Under `--framing newline` (`:65`) `write-frame` is two separate operations — `(write-bytes payload port)` then `(write-byte #x0a port)` (`ocapn-framing.rkt:53-55`) — so an interleave splits a frame trivially. The file's own comment at `:334-336` flags "writing to a connection other than the one being serviced, which is the first thing here to do so" and does not mention the race.

**M4 — HIGH | concurrency / silent failure | `ocapn-dial-ffi.rkt:34-42` + `run-ocapn-test-server.rkt:616-618` | The dial queue is an unlocked global read-modify-write across the semaphore boundary.**
`ocapn-dial-request` does `(set! pending (append pending (list sturdyref)))` from inside `drive-step` (under `validate-sema`), but `drain-dials!` calls `ocapn-dial-drain` **outside** the semaphore — and drain is itself `(define out pending)` then `(set! pending '())`. A request queued between those two steps is silently dropped; a lost dial is a handoff that stalls with no error anywhere. Contrast worth stating: `ocapn-gift-ffi.rkt`'s table *is* safe, because every access sits inside `drive-step`.

**M5 — MEDIUM | hardcoded | `run-ocapn-test-server.rkt:171` | The peer designator is the literal `"0123456789abcdef0123456789abcdef"`.**
Upstream uses `uuid.uuid4().hex` (`testing_only_tcp.py:54`) precisely so it is unique per peer. Every instance of this server advertises the same designator; only the port hint distinguishes two of them. Since `open-conns` (`:339`), `half-open-dials` (`:311`) and `pending-gives` (`:497`) are **all keyed by location bytes**, this is one hint-collision away from cross-peer confusion.

**M6 — MEDIUM | silent failure | `captp-core.prologos:1322-1326` | A gift whose reference is not `desc:export` is accepted on the wire and silently discarded.**
`deposit-with-gid` returns `bridge-step v st` unchanged when `syrup-as-export-target` (`:1223-1239`) rejects the shape — so `deposit-gift` carrying a `<desc:import-promise N>` or an answer position is dropped with no reply and no error. The withdrawer then parks forever. Same silent-nil shape at `dispatch-deposit-with-refr` (`:1329-1334`) and `dispatch-deposit-gift-rest` (`:1336-1340`).

**M7 — MEDIUM | silent failure | `interop-driver.prologos:266-269` | An op we cannot decode produces zero output and zero log line.**
`step-connection` returns `""` when `decode-op` yields `none`. This is *quieter* than the exception path claim 16 covers — that one at least prints. An unparseable or unsupported frame is indistinguishable from a frame that legitimately needs no reply, at both the Prologos and the Racket layer.

**M8 — MEDIUM | test-shaped scanning | `run-ocapn-test-server.rkt:404-405` | The same first-match defect as claim 6, at a second site the report did not name.**
`try-fetch-answer!` takes the **first** `desc:import-object` in the exporter's frame as the object to deposit. An exporter whose `fulfill` carries any other reference ahead of the payload causes us to deposit — and then hand a signed give to — the wrong capability.

**M9 — LOW/MEDIUM | invariant not enforced | `captp-core.prologos:1524-1527` | The replay key joins two attacker-controlled byte strings with an unescaped `"|"`.**
`handoff-identity-parts` builds `"used:" ++ sess ++ "|" ++ side ++ "|" ++ digits(count)` with no length prefixing, so `(sess="A|B", side="C")` and `(sess="A", side="B|C")` collide. Same class as M1, weaker, and fixed by the same change.

---

### 1.9 Crypto + handshake

#### Verified findings

— copy verbatim

1. `captp-core.prologos:1863-1867` — the gifter's signature on `desc:handoff-give` is never verified; `verify-raw` has exactly two call sites in the tree (`captp-core.prologos:1699`, `handshake.prologos:434`), and the receive's verifying key is read from *inside* the unverified give (`give-receiver-key-of`, `:1676-1680`), so a self-signed receive naming its own pubkey passes `signed-receive-valid?` (`:1713-1718`).
2. `captp-core.prologos:1861-1862` — the comment "a forged receive can neither consume a gift nor learn whether one was deposited" is false for exactly the forgery above; `gifter-side`, `session` and `exporter-location` are never compared to anything.
3. `run-ocapn-test-server.rkt:570-580` — on connections we dial, the peer's `op:start-session` is never validated (no version check, no signature check); `validate-incoming` is called only at `:670`, on the accept path.
4. `crypto.prologos:11` — "ALL FFI bindings carry a `:requires (CryptoCap)` annotation" is false: none of the five `foreign` declarations at `:31-32, :36-37, :42-43, :47-48, :51-52` carry it, and the `CryptoCap` import at `:22` is dead; the sibling convention is live at `tcp-testing.prologos:57-64`.
5. `syrup-wire.prologos:88-89` vs `:323-341` — `encode` measures `syrup-string`/`syrup-symbol` in UTF-8 bytes (`str::bytes-length` = `string-utf-8-length`, `data/string.prologos:19`) while `decode-string-tail`/`decode-symbol-tail` measure code points, so `re-encode` (used for signature verification at `captp-core.prologos:1709`) produces wrong bytes for any non-ASCII address or hint.
6. `captp-core.prologos:1517-1518` — "The prefix cannot collide with a gift id … this key is only ever CONSTRUCTED here" is unenforced: gift ids arrive as arbitrary peer bytes via `syrup-bytes-of` (`:1301-1314`, `dispatch-deposit-gift-rest:1336-1346`) into the same `String -> Nat` table the `"used:"` replay markers live in.
7. `run-ocapn-test-server.rkt:472-476` — `sign-with-our-key` calls `run-prologos`/`process-string` with no `call-with-semaphore`, bypassing the `validate-sema` serialisation its own comment at `:192-193` says is required.
8. `run-ocapn-test-server.rkt:311, 339, 341, 350, 497` — five plain `make-hash`/`make-hasheq` tables are mutated from every connection thread (thread-per-connection at `:721`) with no lock.
9. `captp-core.prologos:2288-2293` — a second `op:start-session` mid-session is a silent no-op; `CapTPOp`'s `op-start-session` carries only `String -> SyrupValue` (`message.prologos:37`), no pubkey or signature, so the core structurally *cannot* validate one.
10. `interop-driver.prologos:266-269` — an undecodable frame returns `""`, indistinguishable from "handled, nothing to say"; same shape at `captp-core.prologos:1921, 1924, 1934, 1941, 1948` for unknown swiss-nums and unknown bootstrap methods.
11. `run-ocapn-test-server.rkt:230-252` — `drive-step` swallows every exception (and every unparsable result) into `#""` and keeps the connection alive.
12. `captp-core.prologos:1411-1428` — `swiss-num-export` is a literal five-way string comparison against the upstream suite's swiss-nums; the self-labelled "scaffolding … Retirement plan: replace with a cell" at `:1402-1409` names a cell that does not exist.
13. `run-ocapn-test-server.rkt:281-296` vs `handshake.prologos:283-299` — two Syrup skippers must agree and already don't: the Racket one has no `F`/`D` float arms and no bounds guard, so a float byte reaches `(+ j 1 #f)` and any truncated record reaches an out-of-range `bytes-ref`.
14. `ocapn-conn-ffi.rkt:35-37` — `ocapn-conn-reset` is provided and has zero callers (grep: definition, provide, nothing else), so a full `ConnectionState` is retained per connection forever; `handle-connection` closes ports at `:708-709` but never drops `open-conns`/`pubkey-by-port` entries.
15. `crypto-ffi.rkt:169-174` — `crypto-close-keypair` has zero callers anywhere and drops the table reference without overwriting the 64-byte secret; `crypto.prologos:30` says "The caller must release … when done".
16. `handshake.prologos:194-197` — `mk-handshake-bytes` generates a keypair into a `let` and discards the handle, leaking it into `crypto-table` (`crypto-ffi.rkt:107`) unreachably on every call.
17. `interop-driver.prologos:154, 181-195` + `captp-core.prologos:1771-1782` — park keys are `"park:<promise-id>:<gift-id>"` in a process-global table, while `seeded-vat` starts `next-id` at `8N` on *every* connection, so `settle-parked` prefix-matches across connections.
18. `handshake.prologos:142-151` — we emit `ocapn-peer` hints as a Syrup list of key/value sub-lists; upstream subscripts them as a dict (`netlayers/testing_only_tcp.py:66`, after `OCapNPeer.from_syrup_record`, `utils/ocapn_uris.py:50-53`), and `syrup-dict` has existed since `syrup.prologos:63`.
19. `run-ocapn-test-server.rkt:160-165, 313` — one process-wide Ed25519 keypair makes `our-side-id` a constant, so `session-id-of` (`:451-454`) collapses two sessions with the same stable-keyed peer to one id and their `handoff-count 0` collides in the global replay set.
20. `handshake.prologos:488-496` — `parse-start-session` never checks byte 0 is `<`, never checks record arity, and never checks the closing `>`; it fails open into `decide-signature`, so this is hygiene, not a bypass.
21. `handshake.prologos:143` and `:243-244` — two comments deny Syrup dict support that `syrup.prologos:63` and `syrup-wire.prologos:489-498` both provide.

---

#### Also missed by the first pass

— categories the report under-covered

The report is strongest on crypto/verification and weakest on **peer-directed side effects, unenforced byte-scan invariants, and the non-hash concurrency state.** Eleven items it should have caught:

**M1. HIGH | peer-directed outbound connect (SSRF) | `run-ocapn-test-server.rkt:601-614` + `:542-556`.** `note-handoff-give!` runs on **every** inbound frame (`:637`) and on every dial-loop frame (`:582`); it takes `loc` straight out of the peer's bytes and queues a dial, and `dial-sturdyref!` does `tcp-connect` on host/port scraped from the peer's own hints (`:544-545, :556`) with no allow-list, no loopback restriction, and no rate limit. **What breaks it:** any authenticated peer post-handshake sends one frame whose `desc:handoff-give` names `host=10.0.0.5, port=6379` — we open the socket and write our start-session. The report's #2 reaches this code and frames it only as "no validation on the peer's reply."

**M2. HIGH | invariant asserted but not enforced | `run-ocapn-test-server.rkt:589-592`.** *"the marker is unambiguous — `desc:handoff-give` appears nowhere else on the wire."* Nothing enforces it: `find-subbytes` (`:595-599`) scans raw bytes, and a `syrup-bytes` payload may contain any bytes. **What breaks it:** a peer sends any op carrying a bytestring whose contents are `<17'desc:sig-envelope<17'desc:handoff-give…` — `note-handoff-give!` fires on a non-give, `record-field env 0` / `record-field give 1` walk garbage, and M1's dial fires on whatever those bytes decode as.

**M3. HIGH | concurrency | `run-ocapn-test-server.rkt:215-220` and `:351-354`.** `next-conn-id!` and `next-enliven-slot!` are non-atomic unbox/`set-box!`, called from accept threads (`:691, :698`) *and* dial threads (`:563`). **What breaks it:** two peers connecting simultaneously both receive cid *N*; `drive-init!` (`:222-225`) then stashes over the other's `ConnectionState` in `conn-table`, and the two sessions share one vat, one gift list, one export refcount table. This is strictly worse than the hash races in #7, which the report ranked HIGH.

**M4. MEDIUM | crash / remote connection kill | `run-ocapn-test-server.rkt:300-303`.** `record-field` loops `(syrup-skip bs i)` counting fields with **no check for the closing `>`**. **What breaks it:** `<15'ocapn-sturdyref>` (zero args) reaching `try-enliven!`, or `<17'desc:sig-envelope<17'desc:handoff-give>>` reaching `note-handoff-give!` — the walk runs past `>` into `bytes-ref` out-of-range, caught only by `handle-connection`'s blanket handler (`:652`), killing the connection.

**M5. MEDIUM | hardcoded / spec deviation | `run-ocapn-test-server.rkt:484`.** The `handoff-count` we emit is the literal `#"0+"`. Upstream increments per session (`utils/captp.py:163-166`) and any conformant exporter rejects a repeat (`utils/captp.py:107-109`, and our own `withdraw-with-identity`, `captp-core.prologos:1843-1847`). **What breaks it:** a second handoff to the same exporter in one process lifetime — refused as `replayed-handoff` by a correct peer.

**M6. MEDIUM | hardcoded | `run-ocapn-test-server.rkt:407`.** `(define gid #"prologos-gift")` — every gift we deposit uses the same id, in a table keyed by gift-id that is explicitly process-global (`ocapn-gift-ffi.rkt:28`). **What breaks it:** two handoffs in flight; the second `bs-add-gift` shadows the first and one withdrawal redeems the wrong export.

**M7. MEDIUM | test-shaped | `run-ocapn-test-server.rkt:364-381` and `:404-405`.** `try-enliven!` never inspects the deliver's **target** — it fires on any frame containing both `<15'ocapn-sturdyref` and `<18'desc:import-object`, and takes `rm-pos` from the *first* `desc:import-object` in the frame. `try-fetch-answer!` takes `obj` the same way (`:404`) and picks its pending entry with `for/first` over a hash (`:392-395`, nondeterministic order). **What breaks it:** any deliver that carries a sturdyref as an ordinary argument, or one whose resolve-me is not the first import-object.

**M8. MEDIUM | duplication / drift | `handshake.prologos:103-106, 149-150` vs `run-ocapn-test-server.rkt:528-537`.** Our hint keys are Syrup **symbols** (`gcrypt-pair-str-bytes` → `wire::encode [syrup-symbol key]`); the server's own `peer-hint` scans for a **string** key (needle built with marker `"` at `:529-530`). So the process cannot dial a location it generated itself. The report's #15 names the list-vs-dict half and misses the symbol-vs-string half — which also means its fix shape ("build the hints with `syrup-dict`") is insufficient: the keys must become `syrup-string` too.

**M9. MEDIUM | stale docs | three sites.** `run-ocapn-test-server.rkt:25-28` — *"the server does NOT yet dispatch post-handshake frames through captp-core's connection-step … that's Phase 59"* — it does (`drive-step:230`, `run-frame-loop:622`). `:12-14` and `:20` say the server calls `mk-handshake-bytes`; it calls `handshake-bytes-with-key` (`:171`). `tools/interop/ocapn-run-tests.py:38-40` says crossed-hellos and op_deliver *"need … Phase 59+"* while both are in `SELECTED` (`:43-53`). The report caught only the `mk-handshake-bytes` half, in passing, under #19.

**M10. MEDIUM | resource / lifecycle | `run-ocapn-test-server.rkt:561, 586-587`.** `half-open-dials` entries are removed only on the crossed-hellos branch (`:690`); the ordinary dial path never removes them, so `hash-ref half-open-dials` at `:673` can report a crossed-hello against a long-dead dial. And the dial thread's `close-input-port`/`close-output-port` (`:586-587`) sit *inside* the `with-handlers` body at `:553`, so any exception in the frame loop skips both. The report's #13 covers `conn-table` and `open-conns` only.

**M11. MEDIUM | the #5 + #14 composition is worse than either alone.** A peer deposits gift-id `"park:8:X"` and also `"X" → <desc:export N>`. `parked-gid-loop` (`captp-core.prologos:1771-1778`) prefix-scans the *process-global* list, `settle-parked` (`:1798-1803`) is invoked on every `op:listen` (`:2307`), and `do-settle-parked` (`:1786-1790`) resolves the listened promise with `<desc:import-object N>` and increments that export's refcount. **What breaks it:** any *other* connection's `op:listen` on its promise 8 — a cross-connection promise-resolution injection, not merely the denial the report describes.

---

### 1.10 Test + CI infrastructure

#### Verified findings

— copyable, with corrections folded in

1. **HIGH | spec deviation | `handshake.prologos:144-151`** — `ocapn-peer-bytes` emits hints as a list-of-lists with *symbol* keys where the spec and every peer use a Syrup dict with *string* keys. Verified by execution: `(ocapn-peer-bytes "tcp-testing-only" "abc" "127.0.0.1" "22045")` → `<10'ocapn-peer16'tcp-testing-only3"abc[[4'host9"127.0.0.1][4'port5"22045]]>`; canonical is `…3"abc{4"host9"127.0.0.14"port5"22045}>` (`contrib/syrup.py:92-103`). Our own decoder pins the correct form (`test-ocapn-syrup-wire.rkt:230`). Hidden because nothing in the suite reads our hints (not because of signature verification — see W1).
2. **HIGH | silent failure | `run-ocapn-test-suite.sh:144`** — the gate is `[ "$N_PASS" -ge "$EXPECTED_PASS" ]`; `N_FAIL`/`N_ERROR` (`:132-133`) are echoed at `:136-137` and never referenced, and `SUITE_EXIT` (`:128`) is echoed at `:140` and never compared. A 25th failing test passes the gate.
3. **HIGH | spec deviation | `syrup-wire.prologos:466-505`** — no float (`D`) and no set (`#…$`) in `decode-at`; both hit `| false -> none` at `:505` and the whole frame is dropped with no diagnostic. Neither exists in `SyrupValue` (`syrup.prologos:40-69`) nor in `encode` (`:84-111`). Upstream emits both (`contrib/syrup.py:114-115`, `:123-125`).
4. **HIGH | silent failure | `syrup-wire.prologos:110-111`** — `| syrup-refr _ -> ""` / `| syrup-promise _ -> ""`: a refr inside a list contributes zero bytes, so a 2-element list encodes as a well-formed 1-element list that the peer decodes at the wrong arity. `handshake.prologos:43` imports bare `encode`.
5. **HIGH | test-shaped / SSRF-shaped | `run-ocapn-test-server.rkt:528-537`** — `peer-hint` is a linear byte-scan for `<len>"<key>` from offset 0, not a parse; the attacker-controlled `address` field precedes `hints` in `<ocapn-peer transport address hints>`, so an address containing `4"host9"1.2.3.4` wins the scan and we dial it (`:544-556`). Failure is a bare `printf` at `:547-548`. Comment at `:525-527` asserts "good enough for `{host …, port …}`" with nothing enforcing it.
6. **HIGH | drift risk / CI | `tools/interop/.gitignore:2`** — `package-lock.json` is gitignored and untracked (`git ls-files --error-unmatch` → "did you forget to `git add`"), while `package.json:11-12` uses caret ranges `^1.1.0`/`^1.0.0` and both workflows run `npm install` (`interop.yml:55`, `test.yml:49`). The drift gate's own diagnostic (`interop.yml:69-70`) blames a bump that cannot have happened.
7. **MEDIUM | duplication / drift | `captp-core.prologos:16,43,118-127,2288` vs `handshake.prologos:518-523`** — two `op:start-session` implementations with incompatible wire shapes: `our-session-bytes` builds 2 fields with the location as a bare `syrup-string` (`:125-127`), `handshake` builds the 4-field signed form with an `<ocapn-peer>` record. Nothing forces agreement; no test crosses them.
8. **MEDIUM | test-shaped | 16 `peer-*.mjs`, e.g. `peer-abort.mjs:45`, `peer-handshake.mjs:42-45`, `peer-plain-value-error.mjs:65-68`** — every Node peer speaks 2-field unsigned `op:start-session` at version `'0.1'` with a bare string location, while the conformance gate drives `"1.0"` signed (`run-ocapn-test-suite.sh:127`). The 13 interop steps would stay green if the signed path broke entirely.
9. **MEDIUM | fixture no longer pins behaviour | `peer-break-forwarding.mjs:43`, `peer-pipelining.mjs:41`, `peer-plain-value-error.mjs:45`** — `argsHead` accepts both the correct list form and the previously-broken bare value ("Racket used to send a bare value there … unwrapping one level reads both"), so reverting the bug keeps all three green.
10. **MEDIUM | self-confirming test | `peer-plain-value-error.mjs:57`** — the "external" peer asserts on `'deliver-to-non-callable'`, a string that exists only at `captp-core.prologos:2491` and in our own scripts; zero occurrences in `/tmp/ocapn-test-suite`.
11. **MEDIUM | coverage gap | `tests/fixtures/syrup-cross-impl.txt`** — 22 cases, all bool/int/string/symbol/list/single-arg-record. No dicts (key ordering), no byte-strings (the `str::length` vs `str::bytes-length` bug documented at `syrup-wire.prologos:90-105`), no floats, no sets, no nested or multi-arg records. Findings 1 and 3 are both invisible to it. Generator: `gen-syrup-vectors.mjs:46-95`.
12. **MEDIUM | hardcoded | `locator.prologos:53-60`** — `locator : Transport -> String -> String -> Nat` fixes `host`/`port` instead of carrying a hints map; upstream ships an onion netlayer (`netlayers/onion.py`) whose hints are unrepresentable, with no error when they are dropped.
13. **LOW | lifecycle | `run-ocapn-test-server.rkt:339-346`** — `open-conns` (`:339`/`:344`/`:371`) and `pubkey-by-port` (`:341`/`:346`/`:422`, keyed on the output port object) are never removed, while siblings `pending-enlivens` (`:399`), `pending-gives` (`:576`) and `half-open-dials` (`:690`) all are. The teardown site exists (`:708-709`).
14. **LOW | concurrency | `run-ocapn-test-server.rkt:311,339,341,350,497`** — five plain `make-hash`/`make-hasheq` tables shared across per-connection threads (`:721`) and the dialer thread (`:551`); `validate-sema` (`:189`) guards only the `process-string` calls. `hash-ref` at `:574` → `hash-remove!` at `:576` is an unsynchronized read-modify-write.
15. **LOW | lifecycle | `peer-recv.mjs`, `peer-conversation.mjs`, `peer-handshake.mjs`** — the only three peers with no `setTimeout(...).unref()` safety exit; `peer-recv.mjs:40` waits on `sock.on('end')` forever. Combined with zero `subprocess-kill` in all 36 `test-ocapn-*.rkt` files, these three are the only ones that can orphan indefinitely.
16. **LOW | timeout budget | `run-ocapn-test-suite.sh:119-127`** — `timeout 600` against a documented ~25 s/test × 24 = 600 s exactly; `|| true` at `:127` discards exit 124 and the gate reports "MILESTONE NOT MET" for a timeout — the exact misdiagnosis the comment at `:121-123` records happening before at 90 s.
17. **LOW | stale comments** — `interop.yml:141-142` says "milestone (>= 3 selected tests passing)" vs `EXPECTED_PASS=24`; `run-ocapn-test-suite.sh:106-110` enumerates 5 tests directly above `EXPECTED_PASS=24` (the real `SELECTED` count is 24, `ocapn-run-tests.py:42-135`); `:19-20` documents the default as `./tmp/ocapn-test-suite` vs `/tmp/...` at `:43`.
18. **LOW | shell bug | `run-ocapn-test-suite.sh:131-133`** — `$(grep -c … || echo 0)` yields the two-line string `"0\n0"`. Reproduced: `[: 0\n0: integer expression expected`. Fires exactly when zero tests pass.
19. **LOW | invariant not enforced | `syrup.prologos:51-56`** — the comment claims re-encoding a decoded dict is byte-identical "since we neither re-sort nor re-order"; `syrup-wire.prologos:108` performs no sort while upstream sorts unconditionally. Latent only (W6), but the claim is broader than what holds.

---

#### Also missed by the first pass

The report under-covered categories **3 (unimplemented behind a passing test)**, **4 (silent failure)** and **5 (asserted-not-enforced)** inside `run-ocapn-test-server.rkt` and `captp-core.prologos` — it treated the server as a lifecycle/concurrency surface and stopped.

**M1 — `encode-safe` has ZERO production call sites, and a comment mandates it.** The report said "nothing forces callers to use it"; it did not establish that *no* caller uses it. `grep -rn "encode-safe" lib/ tools/` returns only its own definition (`syrup-wire.prologos:151-156`) and comments; the only real callers are `tests/test-ocapn-syrup-wire.rkt:126-131`. And `syrup-wire.prologos:79` states *"callers should pre-validate via `encode-safe`"* — an asserted invariant with zero enforcers. This is the correct, much stronger framing of F4: the safety valve was built, documented as mandatory, and wired to nothing.

**M2 — `handshake.prologos:143` is a stale comment that is the direct cause of F1.** The doc-string says hints are a list *"until the SyrupValue model gains [a real syrup dict]"* — but `syrup-dict` already exists (`syrup.prologos:63`), is decoded (`syrup-wire.prologos:495-498`), is encoded (`:108`), and is covered by the encodability check (`:149`, with a comment at `:146-148` about nearly getting it wrong). The report cited `:143` for its own quote and did not notice the rationale is false, which turns F1 from "a deferred lift" into "a lift whose blocker was removed and nobody went back."

**M3 — `run-ocapn-test-server.rkt:566`: a completely silent read-error swallow, mislabelled as a clean close.** `(define frame (with-handlers ([exn:fail? (lambda (e) #f)]) (read-frame din)))` — no printf, and `:568-569` then prints `"outbound closed after ~a frames"`. Any framing or socket error on a dialled connection is indistinguishable from EOF. Contrast `:624-628` and `:661-664`, which at least print the message. This is the report's own category 4 and its severest instance in the file.

**M4 — a second byte-scan-instead-of-parse, with an explicitly asserted invariant: `:589-593`.** `give-marker` = `#"<17'desc:sig-envelope<17'desc:handoff-give"`, found via `find-subbytes` (`:595-599`), under the comment *"the marker is unambiguous — `desc:handoff-give` appears nowhere else on the wire."* Nothing enforces that. A peer embedding those literal bytes in a bytestring arg drives `hash-set! pending-gives` + `ocapn-dial-request` (`:611-614`) → an outbound TCP dial. Same defect class as F7 but a distinct site the report never opened. Two further sub-defects: `find-subbytes` returns only the first match, so a frame carrying two gives notes one; and `try-enliven!` (`:364-381`) does the same marker-scan trick for `<15'ocapn-sturdyref` / `<18'desc:import-object`.

**M5 — peer-driven unbounded outbound dials.** `note-handoff-give!` runs on *every* inbound frame (`:582` and `:637`) with no dedup and no cap. A peer that re-sends one frame N times queues N dials; each `dial-sturdyref!` spawns a thread and a TCP connection (`:551-556`). This is a resource/lifecycle finding strictly worse than F11's never-pruned hashes, and the report missed it while auditing the same 200 lines.

**M6 — `captp-core.prologos:2486-2491` is a stub with a dead parameter.** `defn plain-value-error-reason [_msg]` ignores its argument and returns the constant `syrup-string "deliver-to-non-callable"`; its sole caller (`:2495`) passes `""`. The comment concedes it: *"Caller passes a hint string for now."* The report reached line `:2491` for F10's string-matching argument and did not notice that the function producing it does no work — a textbook category-3 finding sitting under its cursor. It also compounds F10: the peer asserts on a constant that *cannot* vary.

---

## Appendix: how this document was produced

Ten read-only review agents, one per surface, each followed by an adversarial
verification agent that opened every cited file and tried to refute the report.
Only findings that survived verification appear above; the verification pass
also demoted several severities and removed claims that did not hold.

That second pass is not ceremony. In the earlier scoping audit for this same
work it caught a "verified" claim that Racket has no built-in SHA-256 (it is in
`racket/base`) and two accessors attributed to the wrong descriptor record —
either of which would have produced real wasted work.
