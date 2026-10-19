#!/usr/bin/env python3
# Share of BSP rounds and fire-ms in rounds of width >= 8 (buckets 3,4,5 = 8-15,16-63,64+)
# input: P0's comparative-stats-bsp.jsonl (corpus, prelude preloaded, B-current) and -B1
import json, sys
for fn in ["comparative-stats-bsp.jsonl", "comparative-stats-bsp-B1.jsonl"]:
    p = "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/data/par4-p0/" + fn
    tot_r = tot_r8 = 0.0; tot_f = tot_f8 = 0.0; n = 0
    rows = []
    for line in open(p):
        d = json.loads(line)
        wr = d.get("width_hist_rounds"); wf = d.get("width_hist_fire_ms")
        if not wr: continue
        n += 1
        r8 = sum(wr[3:]); f8 = sum(wf[3:])
        tot_r += sum(wr); tot_r8 += r8; tot_f += sum(wf); tot_f8 += f8
        rows.append((d["file"].split("/")[-1], int(sum(wr)), int(r8), round(sum(wf),3), round(f8,3), d.get("width_max")))
    print(f"== {fn}: files={n} rounds={int(tot_r)} rounds>=8={int(tot_r8)} ({100*tot_r8/max(tot_r,1):.1f}%) fire_ms={tot_f:.2f} fire_ms_in_rounds>=8={tot_f8:.2f} ({100*tot_f8/max(tot_f,1e-9):.1f}%)")
    for r in rows: print("   ", r)
