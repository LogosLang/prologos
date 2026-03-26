#lang racket/base

;;;
;;; PROLOGOS .PNET SERIALIZATION
;;; Serialize and deserialize module network state to/from disk.
;;;
;;; Track 10 Phase 1b: The highest-value mechanism — eliminates 20s cold-start
;;; by serializing elaboration results (cell values, registries, metadata)
;;; and deserializing on subsequent loads (~735ms).
;;;
;;; Mechanism: struct->vector + write/read + tag dispatch reconstruction.
;;; Handles: gensyms (symbol$$N tagging), foreign procs (dynamic-require),
;;; preparse expanders (dynamic-require).
;;;
;;; See: docs/tracking/2026-03-24_PM_TRACK10_DESIGN.md §2.7
;;;

(require racket/match
         racket/hash
         racket/file
         racket/path
         racket/string
         racket/list
         "prelude.rkt"
         "syntax.rkt"
         "namespace.rkt"
         "source-location.rkt"
         (only-in "propagator.rkt" cell-id
                  prop-network prop-network? make-prop-network
                  prop-net-hot prop-net-warm prop-net-cold
                  prop-cell tms-cell-value)
         (only-in "elab-network-types.rkt" elab-network elab-network? elab-cell-info contradiction-info)
         (only-in "macros.rkt" spec-entry preparse-macro ctor-meta
                  trait-meta trait-method impl-entry param-impl-entry
                  current-preparse-registry current-ctor-registry
                  current-type-meta
                  current-subtype-registry current-coercion-registry
                  current-capability-registry
                  current-trait-registry current-impl-registry
                  current-param-impl-registry
                  current-specialization-registry
                  current-bundle-registry bundle-entry
                  current-trait-laws current-property-store
                  current-functor-store)
         (only-in "global-env.rkt" current-defn-param-names)
         (only-in "multi-dispatch.rkt" current-multi-defn-registry)
         (only-in "foreign.rkt" parse-foreign-type make-marshaller-pair))

;; Lib dir for resolving relative .rkt paths in foreign function re-linking
(define pnet-lib-dir (simplify-path (build-path (syntax-source #'here) ".." "lib")))

(provide serialize-module-state
         deserialize-module-state
         relink-foreign-marshallers!
         pnet-stale?
         pnet-path-for-module
         ;; For testing
         make-serializer
         deep-struct->serializable
         deep-serializable->struct
         make-tag-constructor-table)

;; ============================================================
;; .pnet format version
;; ============================================================

(define PNET_VERSION 1)

;; ============================================================
;; Serialization: struct->vector + gensym tagging + foreign-proc
;; ============================================================

;; Create a serializer with its own gensym table (per-module)
(define (make-serializer)
  (define gensym-table (make-hash))   ;; gensym → unique-id
  (define gensym-counter 0)

  (define (serialize-sym s)
    (cond
      [(symbol-interned? s) s]
      [else
       (define uid
         (hash-ref! gensym-table s
           (lambda ()
             (set! gensym-counter (add1 gensym-counter))
             gensym-counter)))
       (string->symbol (format "~a$$~a" (symbol->string s) uid))]))

  (define has-foreign-procs? (box #f))  ;; Track if any procedures found

  (define (deep-s->v v)
    (cond
      [(procedure? v)
       ;; Procedures can't be serialized. Record for tracking.
       ;; Foreign functions with source-module are re-linked via dynamic-require.
       ;; Other procedures (preparse expanders, marshallers) get stubs.
       (set-box! has-foreign-procs? #t)
       (define name (or (object-name v) 'anonymous))
       (list 'foreign-proc name)]
      [(symbol? v) (serialize-sym v)]
      ;; Track 10 Phase 3c: prop-network and elab-network contain internal
      ;; CHAMP nodes that aren't exported and can't be properly reconstructed.
      ;; Replace with sentinels — these are runtime values, not module state.
      [(prop-network? v) '(runtime-prop-network)]
      [(elab-network? v) '(runtime-elab-network)]
      [(struct? v)
       (for/vector ([e (in-vector (struct->vector v))]) (deep-s->v e))]
      [(pair? v)
       (cons (deep-s->v (car v)) (deep-s->v (cdr v)))]
      [(list? v) (map deep-s->v v)]
      [(hash? v)
       (for/hasheq ([(k val) (in-hash v)])
         (values (if (symbol? k) (serialize-sym k) k)
                 (deep-s->v val)))]
      [(void? v) '(void-sentinel)]
      [(box? v) (list 'box-sentinel (deep-s->v (unbox v)))]
      [else v]))  ;; numbers, strings, booleans, keywords: pass-through

  (values deep-s->v has-foreign-procs?))

(define (deep-struct->serializable v)
  (define-values (f _) (make-serializer))
  (f v))

;; ============================================================
;; Deserialization: read + tag dispatch reconstruction
;; ============================================================

;; ============================================================
;; Dynamic tag→constructor dispatch
;; ============================================================
;; Instead of maintaining a manual table of 326+ struct types,
;; use Racket's struct-type introspection to reconstruct structs
;; dynamically. This eliminates the pipeline-exhaustiveness problem.

;; Registry: populated at require-time from syntax.rkt's provide.
;; Key = tag symbol (e.g., 'struct:expr-Pi), Value = constructor procedure.
(define tag-table (make-hash))

(define (make-tag-constructor-table) tag-table)

;; Register a struct type for deserialization.
;; Called at module load time for each struct we need to reconstruct.
(define (register-pnet-struct! tag-sym constructor)
  (hash-set! tag-table tag-sym constructor))

;; Auto-register: given a struct predicate and a sample instance,
;; extract the tag from struct->vector and register the constructor.
(define-syntax-rule (auto-register-struct! ctor pred sample-args ...)
  (let ([inst (ctor sample-args ...)])
    (define tag (vector-ref (struct->vector inst) 0))
    (register-pnet-struct! tag ctor)))

;; Helper: register a tag→constructor pair by making a dummy instance.
;; Zero-arg constructors get a thunk wrapper.
(define-syntax-rule (reg0! ctor)
  (let ([tag (vector-ref (struct->vector (ctor)) 0)])
    (hash-set! tag-table tag (lambda () (ctor)))))

(define-syntax-rule (reg1! ctor dummy)
  (let ([tag (vector-ref (struct->vector (ctor dummy)) 0)])
    (hash-set! tag-table tag ctor)))

(define-syntax-rule (reg2! ctor d1 d2)
  (let ([tag (vector-ref (struct->vector (ctor d1 d2)) 0)])
    (hash-set! tag-table tag ctor)))

(define-syntax-rule (reg3! ctor d1 d2 d3)
  (let ([tag (vector-ref (struct->vector (ctor d1 d2 d3)) 0)])
    (hash-set! tag-table tag ctor)))

(define-syntax-rule (regN! ctor args ...)
  (let ([tag (vector-ref (struct->vector (ctor args ...)) 0)])
    (hash-set! tag-table tag ctor)))

;; Dynamic constructor cache: maps struct-name-symbol → constructor.
;; Built at module load time from all required modules.
;; Used as fallback when a tag isn't in the static tag table.
(define dynamic-ctor-cache (make-hash))

(define-syntax-rule (cache-ctor! name ctor)
  (hash-set! dynamic-ctor-cache 'name ctor))

;; Phase 2e: Register all struct types dynamically.
;; Instead of hand-coding 149 entries, auto-register by creating a dummy
;; instance of each exported struct and extracting its tag.
;; Unknown tags gracefully degrade to raw vectors.
(define (register-all-pnet-structs!)
  ;; --- Zero-arg (atoms) ---
  (reg0! expr-zero) (reg0! expr-refl) (reg0! expr-Nat) (reg0! expr-Bool)
  (reg0! expr-true) (reg0! expr-false) (reg0! expr-Unit) (reg0! expr-unit)
  (reg0! expr-Nil) (reg0! expr-nil) (reg0! expr-hole) (reg0! expr-error)
  (reg0! expr-Int) (reg0! expr-Rat) (reg0! expr-Char) (reg0! expr-String)
  (reg0! expr-Keyword) (reg0! lzero)

  ;; --- One-arg ---
  (reg1! expr-bvar 0) (reg1! expr-fvar 'x) (reg1! expr-suc (expr-zero))
  (reg1! expr-nat-val 0) (reg1! expr-fst (expr-unit)) (reg1! expr-snd (expr-unit))
  (reg1! expr-Type (lzero)) (reg1! expr-typed-hole (expr-Nat))
  (reg1! expr-int 0) (reg1! expr-rat 1/2)
  (reg1! expr-char #\a) (reg1! expr-string "")
  (reg1! expr-keyword 'k) (reg1! expr-PVec (expr-Nat))
  (reg1! expr-tycon 'T)
  (reg1! expr-panic "err") (reg1! lsuc (lzero)) (reg1! level-meta 'l)
  (reg1! cell-id 0)

  ;; --- Two-arg ---
  (reg2! expr-app (expr-fvar 'f) (expr-fvar 'x))
  (reg2! expr-pair (expr-unit) (expr-unit))
  (reg2! expr-ann (expr-unit) (expr-Unit))
  (reg2! expr-Sigma (expr-Nat) (expr-Nat))
  (reg2! expr-meta 'test-meta #f)
  (reg2! expr-Map (expr-Nat) (expr-Nat))
  (reg1! expr-Set (expr-Nat))
  (reg2! expr-union (expr-Nat) (expr-Int))
  (reg2! expr-get (expr-unit) (expr-keyword 'k))
  ;; lmax is a smart function, not a struct — no registration needed

  ;; --- Three-arg ---
  (reg3! expr-Pi 'mw (expr-Nat) (expr-Nat))
  (reg3! expr-lam 'mw (expr-Nat) (expr-unit))
  (reg3! expr-reduce (expr-unit) '() #t)
  (reg3! expr-reduce-arm 'ctor 0 (expr-unit))
  (reg3! expr-Eq (expr-Nat) (expr-zero) (expr-zero))

  ;; --- Four-arg ---
  (regN! expr-natrec (expr-Nat) (expr-unit) (expr-unit) (expr-zero))
  (regN! expr-boolrec (expr-Bool) (expr-unit) (expr-unit) (expr-true))

  ;; --- Five-arg ---
  (regN! expr-J (expr-Nat) (expr-unit) (expr-zero) (expr-zero) (expr-refl))

  ;; --- Network types (0-arg) ---
  (reg0! expr-net-type) (reg0! expr-cell-id-type)

  ;; --- Network constructors ---
  (reg3! expr-net-new-cell (expr-unit) (expr-unit) (expr-unit))
  (regN! expr-net-new-cell-widen (expr-unit) (expr-unit) (expr-unit) (expr-unit) (expr-unit))

  ;; --- Numeric conversions ---
  (reg1! expr-from-nat (expr-zero))
  (reg1! expr-from-int (expr-zero))

  ;; --- spec-entry (8 fields: type-datums docstring multi? srcloc where-constraints implicit-binders rest-type metadata) ---
  (regN! spec-entry '() #f #f #f '() '() #f #f)

  ;; --- Special: expr-foreign-fn with dynamic re-linking ---
  ;; Override the auto-registered constructor with one that re-links the proc
  ;; from source-module + racket-name via dynamic-require.
  (hash-set! tag-table 'struct:expr-foreign-fn
    (lambda (name proc arity args marshal-in marshal-out source-module racket-name)
      ;; Re-link the proc if source-module is available
      (define real-proc
        (if (and source-module racket-name
                 (not (eq? source-module #f))
                 (not (eq? racket-name #f)))
            (with-handlers ([exn? (lambda (_) proc)])  ;; fallback to stub
              (define mod-path
                (if (regexp-match? #rx"\\.rkt$" source-module)
                    (simplify-path (build-path pnet-lib-dir ".." source-module))
                    (string->symbol source-module)))
              (dynamic-require mod-path racket-name))
            proc))  ;; no source-module → keep the stub
      ;; Check if the re-linked proc has fewer args than arity.
      ;; This happens when :requires (Cap) adds capability token args.
      ;; Wrap the raw proc to accept the extra capability args and drop them.
      (define wrapped-proc
        (if (and (procedure? real-proc) (number? arity))
            (let ([raw-arity (procedure-arity real-proc)])
              (if (and (integer? raw-arity)
                       (integer? arity)
                       (> arity raw-arity))
                  ;; Capability-wrapped: extra args are cap tokens, drop them
                  (let ([n-caps (- arity raw-arity)])
                    (case n-caps
                      [(1) (lambda (cap . rest) (apply real-proc rest))]
                      [(2) (lambda (c1 c2 . rest) (apply real-proc rest))]
                      [else (lambda args (apply real-proc (drop args n-caps)))]))
                  real-proc))
            real-proc))
      (expr-foreign-fn name wrapped-proc arity args marshal-in marshal-out
                       source-module racket-name)))

  ;; --- Additional types from frequency analysis ---
  ;; Posit types
  (when (with-handlers ([exn? (lambda (_) #f)]) (expr-Posit8) #t)
    (reg0! expr-Posit8) (reg0! expr-Posit16) (reg0! expr-Posit32) (reg0! expr-Posit64))

  ;; Int/Rat operations (appear in foreign function types)
  (when (with-handlers ([exn? (lambda (_) #f)]) (expr-int-add (expr-zero) (expr-zero)) #t)
    (reg2! expr-int-add (expr-zero) (expr-zero))
    (reg2! expr-int-sub (expr-zero) (expr-zero))
    (reg2! expr-int-lt (expr-zero) (expr-zero))
    (reg2! expr-int-eq (expr-zero) (expr-zero)))

  ;; Spec entries (appear in module-info specs)
  (when (with-handlers ([exn? (lambda (_) #f)]) (spec-entry '() (expr-Nat) '() '() #f #f) #t)
    (regN! spec-entry '() (expr-Nat) '() '() #f #f))

  ;; Source locations (appear in definition-locations)
  (when (with-handlers ([exn? (lambda (_) #f)]) (srcloc "" 0 0 0) #t)
    (regN! srcloc "" 0 0 0))

  ;; ns-context
  (regN! ns-context 'test (hasheq) (hasheq) '() '() '())

  ;; preparse-macro (user-defined macros from defmacro — stored in preparse registry)
  (reg3! preparse-macro 'test '() '())

  ;; trait-meta + trait-method + impl-entry (stored in trait/impl registries)
  (regN! trait-meta 'T '() '() (hasheq))
  (reg2! trait-method 'test '())
  (reg3! impl-entry 'T '() 'dict)

  ;; bundle-entry (stored in bundle-registry)
  (regN! bundle-entry 'test '() '() (hasheq))

  ;; param-impl-entry (stored in param-impl-registry)
  (regN! param-impl-entry 'T '() '() 'dict '())

  ;; ctor-meta (stored in ctor-registry)
  (when (with-handlers ([exn? (lambda (_) #f)]) (ctor-meta 'T '() 0 #f #f #f) #t)
    (regN! ctor-meta 'T '() 0 #f #f #f))

  ;; Phase 2e: populate dynamic-ctor-cache with ALL constructors from syntax.rkt.
  ;; This is the fallback for tags not in the static table above.
  ;; Uses struct->vector on dummy instances to discover tags, then maps tag-name → ctor.
  (define (auto-cache! ctor . args)
    (with-handlers ([exn? (lambda (_) (void))])
      (define inst (apply ctor args))
      (when (struct? inst)
        (define tag (vector-ref (struct->vector inst) 0))
        (define name (string->symbol (substring (symbol->string tag) 7)))
        (hash-set! dynamic-ctor-cache name ctor))))

  (define d (expr-zero))  ;; universal dummy
  ;; Posit types + ops (4 widths)
  (auto-cache! expr-Posit8) (auto-cache! expr-Posit16) (auto-cache! expr-Posit32) (auto-cache! expr-Posit64)
  (auto-cache! expr-posit8 0) (auto-cache! expr-posit16 0) (auto-cache! expr-posit32 0) (auto-cache! expr-posit64 0)
  (for ([ops (list (list expr-p8-add expr-p8-sub expr-p8-mul expr-p8-div expr-p8-eq expr-p8-lt expr-p8-le expr-p8-neg expr-p8-abs expr-p8-from-int expr-p8-from-rat expr-p8-to-rat)
                   (list expr-p16-add expr-p16-sub expr-p16-mul expr-p16-div expr-p16-eq expr-p16-lt expr-p16-le expr-p16-neg expr-p16-abs expr-p16-from-int expr-p16-from-rat expr-p16-to-rat)
                   (list expr-p32-add expr-p32-sub expr-p32-mul expr-p32-div expr-p32-eq expr-p32-lt expr-p32-le expr-p32-neg expr-p32-abs expr-p32-from-int expr-p32-from-rat expr-p32-to-rat)
                   (list expr-p64-add expr-p64-sub expr-p64-mul expr-p64-div expr-p64-eq expr-p64-lt expr-p64-le expr-p64-neg expr-p64-abs expr-p64-from-int expr-p64-from-rat expr-p64-to-rat))])
    (for ([op ops])
      (auto-cache! op d) (auto-cache! op d d)))
  ;; Int/Rat ops
  (for ([op (list expr-int-add expr-int-sub expr-int-mul expr-int-div expr-int-lt expr-int-eq)])
    (auto-cache! op d d))
  (for ([op (list expr-int-neg expr-int-abs)])
    (auto-cache! op d))
  (for ([op (list expr-rat-add expr-rat-sub expr-rat-mul expr-rat-div expr-rat-lt expr-rat-le expr-rat-eq)])
    (auto-cache! op d d))
  (for ([op (list expr-rat-neg expr-rat-abs)])
    (auto-cache! op d))
  ;; Collection ops
  (auto-cache! expr-set-empty d) (auto-cache! expr-set-insert d d) (auto-cache! expr-set-member d d)
  (auto-cache! expr-set-delete d d) (auto-cache! expr-set-union d d) (auto-cache! expr-set-diff d d)
  (auto-cache! expr-set-fold d d d) (auto-cache! expr-set-to-list d)
  (auto-cache! expr-map-empty d d) (auto-cache! expr-map-assoc d d d)
  (auto-cache! expr-map-dissoc d d) (auto-cache! expr-map-get d d)
  (auto-cache! expr-map-has-key d d) (auto-cache! expr-map-keys d) (auto-cache! expr-map-vals d)
  (auto-cache! expr-map-fold-entries d d d) (auto-cache! expr-map-filter-entries d d)
  (auto-cache! expr-pvec-empty d) (auto-cache! expr-pvec-push d d)
  (auto-cache! expr-pvec-nth d d) (auto-cache! expr-pvec-update d d d)
  (auto-cache! expr-pvec-length d) (auto-cache! expr-pvec-fold d d d)
  (auto-cache! expr-pvec-map d d) (auto-cache! expr-pvec-from-list d) (auto-cache! expr-pvec-to-list d)
  ;; Other
  (auto-cache! expr-from-int d d) (auto-cache! expr-from-nat d d)
  (auto-cache! expr-Symbol)
  (auto-cache! expr-nil-check d)
  ;; macros.rkt structs
  (auto-cache! ctor-meta 'x 'y (list) #f 0)
  ;; Network types
  (with-handlers ([exn? void])
    (auto-cache! expr-net-type d)
    (auto-cache! expr-net-new-cell d d)
    (auto-cache! expr-net-new-cell-widen d d d))
  ;; expr-cell-id-type
  (with-handlers ([exn? void])
    (auto-cache! expr-cell-id-type d d))

  ;; Track 10 Phase 3c: prop-network + CHAMP structs (for foreign functions that return networks)
  (with-handlers ([exn? void])
    (auto-cache! prop-network d d)
    (auto-cache! prop-net-hot d d)
    (auto-cache! prop-net-warm d d)
    (auto-cache! prop-net-cold d d)
    (auto-cache! elab-network d d)
    (auto-cache! elab-cell-info d d)
    (auto-cache! contradiction-info d d)
    (auto-cache! prop-cell d d)
    (auto-cache! tms-cell-value d d))

  (void))

;; Run registration at module load time
(register-all-pnet-structs!)

(define (deep-serializable->struct v)
  (cond
    ;; Tagged vector: reconstruct struct
    [(and (vector? v) (> (vector-length v) 0)
          (symbol? (vector-ref v 0))
          (let ([s (symbol->string (vector-ref v 0))])
            (and (>= (string-length s) 7)
                 (string=? (substring s 0 7) "struct:"))))
     (define tag (vector-ref v 0))
     (define fields
       (for/list ([i (in-range 1 (vector-length v))])
         (deep-serializable->struct (vector-ref v i))))
     (define ctor (hash-ref tag-table tag #f))
     (cond
       [ctor (apply ctor fields)]
       [else
        ;; Unknown tag — try dynamic constructor lookup from cache.
        (define ctor-name (string->symbol (substring (symbol->string tag) 7)))
        (define dynamic-ctor (hash-ref dynamic-ctor-cache ctor-name #f))
        (cond
          [dynamic-ctor
           (hash-set! tag-table tag dynamic-ctor)  ;; cache for future
           (apply dynamic-ctor fields)]
          [else v])])]  ;; truly unknown — return as vector
    ;; Sentinel markers
    [(and (list? v) (= (length v) 1) (eq? (car v) 'void-sentinel))
     (void)]
    ;; Track 10 Phase 3c: runtime network sentinels → fresh networks
    [(and (list? v) (= (length v) 1) (eq? (car v) 'runtime-prop-network))
     (make-prop-network)]
    [(and (list? v) (= (length v) 1) (eq? (car v) 'runtime-elab-network))
     (make-prop-network)]  ;; elab-network → fresh prop-network (no elab state needed)
    [(and (list? v) (= (length v) 2) (eq? (car v) 'box-sentinel))
     (box (deep-serializable->struct (cadr v)))]
    [(and (list? v) (= (length v) 2) (eq? (car v) 'foreign-proc))
     ;; Re-link foreign procedure. For most procs, the expr-foreign-fn struct
     ;; that contains this proc also has source-module + racket-name fields.
     ;; The struct reconstruction will call dynamic-require using those fields.
     ;; For standalone procs (marshallers, expanders), return a stub.
     (lambda args (error 'foreign-proc "deserialized stub for ~a — needs re-link" (cadr v)))]
    ;; Recursive cases
    [(pair? v)
     (cons (deep-serializable->struct (car v))
           (deep-serializable->struct (cdr v)))]
    [(list? v) (map deep-serializable->struct v)]
    [(hash? v)
     (for/hasheq ([(k val) (in-hash v)])
       (values k (deep-serializable->struct val)))]
    [else v]))

;; ============================================================
;; File operations
;; ============================================================

;; Track 10 Phase 2e: absolute path, relative to THIS module's location.
;; Prevents working-directory sensitivity (batch workers run from project root).
(define pnet-cache-dir
  (simplify-path (build-path (path-only (syntax-source #'here)) "data" "cache" "pnet")))

(define (pnet-path-for-module ns-sym)
  (define ns-str (symbol->string ns-sym))
  (define path-str (string-replace ns-str "::" "/"))
  (build-path pnet-cache-dir (string-append path-str ".pnet")))

(define (source-hash-for-module ns-sym source-path)
  ;; Simple hash: file modification time + size
  ;; Full implementation would hash file contents + transitive deps
  (if (and source-path (file-exists? source-path))
      (let ([stat (file-or-directory-modify-seconds source-path)])
        (format "~a:~a" source-path stat))
      "unknown"))

;; Track 10B: infrastructure .zo timestamp. If driver_rkt.zo is newer than
;; any .pnet file, the Racket infrastructure changed and all .pnet files
;; are stale (elaboration output may differ). Simple timestamp comparison.
(define driver-zo-path
  (simplify-path (build-path (path-only (syntax-source #'here)) "compiled" "driver_rkt.zo")))

(define (infrastructure-stale? pnet-path)
  (and (file-exists? driver-zo-path)
       (file-exists? pnet-path)
       (> (file-or-directory-modify-seconds driver-zo-path)
          (file-or-directory-modify-seconds pnet-path))))

(define (pnet-stale? ns-sym source-path)
  (define pnet-path (pnet-path-for-module ns-sym))
  (or (not (file-exists? pnet-path))
      ;; Track 10B: check infrastructure staleness (Racket code changed)
      (infrastructure-stale? pnet-path)
      (let ([cached-data (with-handlers ([exn? (lambda (_) #f)])
                           (call-with-input-file pnet-path read))])
        (or (not cached-data)
            (not (list? cached-data))
            (not (= (car cached-data) PNET_VERSION))
            (not (equal? (cadr cached-data)
                         (source-hash-for-module ns-sym source-path)))))))

(define (serialize-module-state ns-sym source-path module-info)
  (define-values (serialize! has-foreign?) (make-serializer))
  (define env (module-info-env-snapshot module-info))
  (define specs (module-info-specs module-info))
  (define locs (module-info-definition-locations module-info))

  (define s-env (serialize! env))
  (define s-specs (serialize! specs))
  (define s-locs (serialize! locs))

  ;; Phase 2b: serialize all 7 registries alongside env/specs/locs.
  ;; These are the module's accumulated contributions (including transitive deps).
  ;; Read from current parameters (in scope when called from load-module).
  (define s-preparse-reg (serialize! (current-preparse-registry)))
  (define s-ctor-reg     (serialize! (current-ctor-registry)))
  (define s-type-meta    (serialize! (current-type-meta)))
  (define s-multi-defn   (serialize! (current-multi-defn-registry)))
  (define s-subtype-reg  (serialize! (current-subtype-registry)))
  (define s-coercion-reg (serialize! (current-coercion-registry)))
  (define s-capability-reg (serialize! (current-capability-registry)))
  ;; Phase 2e: ALSO serialize trait + impl + param-impl registries (indices 14-16)
  (define s-trait-reg     (serialize! (current-trait-registry)))
  (define s-impl-reg      (serialize! (current-impl-registry)))
  (define s-param-impl-reg (serialize! (current-param-impl-registry)))
  (define s-specialization-reg (serialize! (current-specialization-registry)))
  (define s-tycon-arity (serialize! (current-tycon-arity-extension)))
  (define s-bundle-reg (serialize! (current-bundle-registry)))
  (define s-defn-params (serialize! (current-defn-param-names)))
  (define s-trait-laws (serialize! (current-trait-laws)))
  (define s-property (serialize! (current-property-store)))
  (define s-functor (serialize! (current-functor-store)))

  (let ()
     (define hash-val (source-hash-for-module ns-sym source-path))
     (define pnet-data
       (list PNET_VERSION               ;; 0: version
             hash-val                    ;; 1: source hash
             s-env                       ;; 2: env-snapshot
             s-specs                     ;; 3: specs
             s-locs                      ;; 4: definition-locations
             (module-info-exports module-info)  ;; 5: exports
             (symbol->string ns-sym)     ;; 6: namespace
             ;; Phase 2b: 7 registries
             s-preparse-reg              ;; 7
             s-ctor-reg                  ;; 8
             s-type-meta                 ;; 9
             s-multi-defn                ;; 10
             s-subtype-reg               ;; 11
             s-coercion-reg              ;; 12
             s-capability-reg            ;; 13
             ;; Phase 2e: trait + impl registries
             s-trait-reg                ;; 14
             s-impl-reg                 ;; 15
             s-param-impl-reg           ;; 16
             s-specialization-reg      ;; 17
             s-tycon-arity            ;; 18
             s-bundle-reg            ;; 19
             s-defn-params          ;; 20
             s-trait-laws           ;; 21
             s-property             ;; 22
             s-functor              ;; 23
             ))
     (define pnet-path (pnet-path-for-module ns-sym))
     (make-directory* (path-only pnet-path))
     ;; Atomic write: write to temp, then rename
     (define tmp-path (make-temporary-file "pnet-~a" #f (path-only pnet-path)))
     (call-with-output-file tmp-path
       (lambda (out) (write pnet-data out))
       #:exists 'replace)
     (rename-file-or-directory tmp-path pnet-path #t)
     pnet-path))

(define (deserialize-module-state ns-sym source-path)
  (define pnet-path (pnet-path-for-module ns-sym))
  (and (file-exists? pnet-path)
       (let ([raw (with-handlers ([exn? (lambda (_) #f)])
                    (call-with-input-file pnet-path read))])
         (and raw
              (list? raw)
              (= (car raw) PNET_VERSION)
              (equal? (cadr raw) (source-hash-for-module ns-sym source-path))
              ;; Valid — reconstruct
              ;; Phase 2e: includes 10 registries (indices 7-16)
              (and (>= (length raw) 14)  ;; minimum version with 7 registries
                   (let ([s-env   (list-ref raw 2)]
                         [s-specs (list-ref raw 3)]
                         [s-locs  (list-ref raw 4)]
                         [exports (list-ref raw 5)]
                         [s-preparse (list-ref raw 7)]
                         [s-ctor    (list-ref raw 8)]
                         [s-tmeta   (list-ref raw 9)]
                         [s-multi   (list-ref raw 10)]
                         [s-sub     (list-ref raw 11)]
                         [s-coerce  (list-ref raw 12)]
                         [s-cap     (list-ref raw 13)])
                     ;; Phase 2e: also extract trait + impl registries if present
                     (define s-trait (and (>= (length raw) 17) (list-ref raw 14)))
                     (define s-impl  (and (>= (length raw) 17) (list-ref raw 15)))
                     (define s-pimpl (and (>= (length raw) 17) (list-ref raw 16)))
                     (define s-spec-reg (and (>= (length raw) 18) (list-ref raw 17)))
                     (define s-tycon-a  (and (>= (length raw) 19) (list-ref raw 18)))
                     (define s-bundle  (and (>= (length raw) 20) (list-ref raw 19)))
                     (define s-dparam (and (>= (length raw) 21) (list-ref raw 20)))
                     (define s-tlaws  (and (>= (length raw) 22) (list-ref raw 21)))
                     (define s-props  (and (>= (length raw) 23) (list-ref raw 22)))
                     (define s-funcs  (and (>= (length raw) 24) (list-ref raw 23)))
                     (list (deep-serializable->struct s-env)
                           (deep-serializable->struct s-specs)
                           (deep-serializable->struct s-locs)
                           exports
                           ;; 7 original registries
                           (deep-serializable->struct s-preparse)
                           (deep-serializable->struct s-ctor)
                           (deep-serializable->struct s-tmeta)
                           (deep-serializable->struct s-multi)
                           (deep-serializable->struct s-sub)
                           (deep-serializable->struct s-coerce)
                           (deep-serializable->struct s-cap)
                           ;; 3 new registries (or empty if old .pnet format)
                           (if s-trait (deep-serializable->struct s-trait) (hasheq))
                           (if s-impl  (deep-serializable->struct s-impl)  (hasheq))
                           (if s-pimpl (deep-serializable->struct s-pimpl) (hasheq))
                           (if s-spec-reg (deep-serializable->struct s-spec-reg) (hash))
                           (if s-tycon-a (deep-serializable->struct s-tycon-a) (hasheq))
                           (if s-bundle (deep-serializable->struct s-bundle) (hasheq))
                           (if s-dparam (deep-serializable->struct s-dparam) (hasheq))
                           (if s-tlaws (deep-serializable->struct s-tlaws) (hasheq))
                           (if s-props (deep-serializable->struct s-props) (hasheq))
                           (if s-funcs (deep-serializable->struct s-funcs) (hasheq))
                           )))))))

;; ============================================================
;; Post-deserialization: re-link foreign function marshallers
;; ============================================================
;; After deserializing an env-snapshot, walk it and fix any expr-foreign-fn
;; whose marshal-in/marshal-out are stubs. Re-derive from the paired type.
(define (relink-foreign-marshallers! env-hash)
  (for/hasheq ([(name entry) (in-hash env-hash)])
    (values name (relink-entry entry))))

(define (relink-entry entry)
  (cond
    ;; Entry is (type . body) where body is the foreign-fn OR (type . (body ...))
    [(and (pair? entry) (expr-foreign-fn? (cdr entry)))
     ;; Direct pair: (type . foreign-fn)
     (define type-expr (car entry))
     (define ff (cdr entry))
     (relink-ff type-expr ff entry)]
    [(and (pair? entry) (pair? (cdr entry)) (expr-foreign-fn? (cadr entry)))
     ;; List form: (type foreign-fn ...)
     (define type-expr (car entry))
     (define ff (cadr entry))
     (define relinked (relink-ff type-expr ff entry))
     (if (eq? relinked entry)
         entry
         (cons type-expr (cons (cdr relinked) (cddr entry))))]
    [else entry]))

(define (relink-ff type-expr ff fallback)
  (define mi (expr-foreign-fn-marshal-in ff))
  ;; Check if marshallers are stubs
  (define needs-relink?
    (and (list? mi) (not (null? mi))
         (procedure? (car mi))
         (let ([name (object-name (car mi))])
           (or (not name)
               (regexp-match? #rx"pnet-serialize" (format "~a" name))))))
  (if needs-relink?
      (with-handlers ([exn? (lambda (_) fallback)])
        (define parsed (parse-foreign-type type-expr))
        (define-values (new-mi new-mo) (make-marshaller-pair parsed))
        (define new-ff
          (expr-foreign-fn
           (expr-foreign-fn-name ff)
           (expr-foreign-fn-proc ff)
           (expr-foreign-fn-arity ff)
           (expr-foreign-fn-args ff)
           new-mi new-mo
           (expr-foreign-fn-source-module ff)
           (expr-foreign-fn-racket-name ff)))
        (cons type-expr new-ff))
      fallback))
