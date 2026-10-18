#!/usr/bin/env python3
"""SW-27 / DEFERRED 160 mutation check: each mutation must turn tests/test-file-unit-isolation.rkt red;
the restore must be byte-identical and green."""
import subprocess, shutil, glob, os, re
R = "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/deferred-sweep-146-149/racket/prologos"
S = "/Users/avanti/.hermes/profiles/logos-language-designer/cache/scratch/sw25"
RK = "/Applications/Racket v9.3/bin/racket"; RC = "/Applications/Racket v9.3/bin/raco"
env = dict(os.environ, PLT_CS_COMPILE_LIMIT="1000000")
files = {"driver.rkt": f"{S}/mut-driver.bak", "tests/test-support.rkt": f"{S}/mut-ts.bak"}
for f, b in files.items(): shutil.copy(f"{R}/{f}", b)

def build():
    r = subprocess.run(["timeout", "-k", "10", "900", RC, "make", "-j", "8", "driver.rkt", "tools/batch-worker.rkt",
                        "tests/test-support.rkt", "tests/test-file-unit-isolation.rkt"], cwd=R, env=env, capture_output=True, text=True)
    if r.returncode: print("  BUILD FAILED:", (r.stderr or r.stdout)[-400:])
def run():
    r = subprocess.run(["timeout", "-k", "10", "300", RK, "tools/run-affected-tests.rkt", "--no-record", "--tests",
                        "tests/test-file-unit-isolation.rkt"], cwd=R, capture_output=True, text=True)
    print("  " + "".join(l for l in r.stdout.splitlines(True) if "tests in" in l).strip())
    for log in glob.glob(f"{R}/data/benchmarks/failures/test-file-unit-isolation*.log"):
        for l in open(log):
            if l.startswith(("name:", "message:")): print("    " + l.strip()[:150])
def mutate(f, old, new):
    t = open(f"{R}/{f}").read(); assert t.count(old) == 1, (f, t.count(old), old[:60])
    open(f"{R}/{f}", "w").write(t.replace(old, new, 1))
def restore():
    for f, b in files.items(): shutil.copy(b, f"{R}/{f}")

M = [
 ("M1 process-file runs WITHOUT the unit scope", "driver.rkt",
  "    (call-with-file-registry-scope\n     (λ ()\n       (begin0 (process-file-inner",
  "    ((λ (th) (th))\n     (λ ()\n       (begin0 (process-file-inner"),
 ("M2 run-ns-last runs without the unit scope (fresh box kept)", "tests/test-support.rkt",
  "    (call-with-file-registry-scope  ;; SW-27\n     (λ ()\n       (with-forked-network current-prop-net-box\n         (install-module-loader!)\n         (last (process-string s)))))))",
  "    ((λ (th) (th))\n     (λ ()\n       (with-forked-network current-prop-net-box\n         (install-module-loader!)\n         (last (process-string s)))))))"),
 ("M3 the unit scope omits current-spec-store", "driver.rkt",
  "  (append (macros-registry-params)", "  (append (remove current-spec-store (macros-registry-params))"),
 ("M4 the unit scope omits current-attribute-map-cell-id", "driver.rkt",
  "                current-attribute-map-cell-id)))", "                )))"),
]
for label, f, old, new in M:
    print(label, flush=True)
    try:
        mutate(f, old, new); build(); run()
    finally:
        restore()
print("RESTORE")
same = all(open(f"{R}/{f}", "rb").read() == open(b, "rb").read() for f, b in files.items())
print("  byte-identical" if same else "  !! DIFFERS")
build(); run()
