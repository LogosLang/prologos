#!/bin/bash
# Print each file:line D.2 cites, at HEAD (production racket/prologos identical to c1f389ab)
cd /Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos
p() { f=$1; l=$2; printf '%-32s ' "$f:$l"; sed -n "${l}p" "$f" | cut -c1-150; }
for l in 333 368 377 576 623 701 809 1235 1326 1371 1452 1498 1885 2231 2343 2517 2876 2884 2990 3084 3202 3220 3295 3401 3431 3446 3452 3465 3505 3516 3530 3543 3557 3585 3675 3767 3899; do p propagator.rkt $l; done
p decision-cell.rkt 526; p decision-cell.rkt 938
p relations.rkt 1990; p relations.rkt 2132; p relations.rkt 2353; p relations.rkt 2824; p relations.rkt 2859
p metavar-store.rkt 504; p metavar-store.rkt 692; p metavar-store.rkt 850; p metavar-store.rkt 1063
p bilattice.rkt 167
p atms.rkt 631; p atms.rkt 641; p atms.rkt 644
p typing-propagators.rkt 447; p typing-propagators.rkt 622; p typing-propagators.rkt 634
for l in 1299 1699 1768 1778 1789 2546 2586 2605 2642 2665 2686 2781 2854 2882 2913; do p typing-propagators.rkt $l; done
p qtt.rkt 60; p qtt.rkt 93
p type-lattice.rkt 156; p type-lattice.rkt 172; p type-lattice.rkt 173; p type-lattice.rkt 203; p type-lattice.rkt 217; p type-lattice.rkt 218
p resolution.rkt 371; p resolution.rkt 387
p session-runtime.rkt 517
for l in 2469 2689 2712 2804 2817; do p sre-core.rkt $l; done
p narrowing.rkt 296; p narrowing.rkt 348
p elaborator-network.rkt 897; p constraint-propagators.rkt 288
