#lang info

;; Pre-0 micro-benchmarks for tracks that were implemented after this
;; file was last updated. `bench-bsp-le-track2.rkt` references the
;; pre-D.5b TMS API (`tms-write`, `tms-cell-value`, `tms-read`,
;; `tms-commit`) that no longer exists; since the file is a historical
;; baseline-measurement artifact (not code that runs in CI or
;; regression suites), we simply skip it during `raco setup` compilation
;; so it does not fail the build. To re-enable the benchmark, migrate
;; its calls to the current `tms-cell` / `atms-write-cell` API in
;; `atms.rkt` and remove this omit directive.
(define compile-omit-paths '("bench-bsp-le-track2.rkt"))
