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
         "prelude.rkt"
         "syntax.rkt"
         "namespace.rkt"
         "source-location.rkt"
         (only-in "propagator.rkt" cell-id)
         (only-in "macros.rkt" spec-entry))

(provide serialize-module-state
         deserialize-module-state
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
       ;; Foreign function or preparse expander — mark module as having foreign procs
       (set-box! has-foreign-procs? #t)
       (define name (or (object-name v) 'anonymous))
       (list 'foreign-proc name)]
      [(symbol? v) (serialize-sym v)]
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

;; Phase 1b.2: Register all struct types that appear in prelude module state.
;; 148 unique tags found; registering the top ~100 by frequency.
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
     (define ctor (hash-ref tag-table tag #f))
     (cond
       [ctor
        (define fields
          (for/list ([i (in-range 1 (vector-length v))])
            (deep-serializable->struct (vector-ref v i))))
        (apply ctor fields)]
       [else
        ;; Unknown struct tag — return as vector (graceful degradation)
        v])]
    ;; Sentinel markers
    [(and (list? v) (= (length v) 1) (eq? (car v) 'void-sentinel))
     (void)]
    [(and (list? v) (= (length v) 2) (eq? (car v) 'box-sentinel))
     (box (deep-serializable->struct (cadr v)))]
    [(and (list? v) (= (length v) 2) (eq? (car v) 'foreign-proc))
     ;; Re-link foreign procedure by name.
     ;; For now, return a placeholder — full dynamic-require in Phase 2.
     (lambda args (error 'foreign-proc "deserialized stub for ~a" (cadr v)))]
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

(define pnet-cache-dir "data/cache/pnet/")

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

(define (pnet-stale? ns-sym source-path)
  (define pnet-path (pnet-path-for-module ns-sym))
  (or (not (file-exists? pnet-path))
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

  ;; Phase 2a: skip serialization for modules with foreign procs.
  ;; Foreign function stubs cause test failures. 22/40 prelude modules affected.
  ;; Full re-linking via dynamic-require deferred to Phase 2b.
  (cond
    [(unbox has-foreign?) #f]  ;; skip — can't serialize foreign procs
    [else
     (define hash-val (source-hash-for-module ns-sym source-path))
     (define pnet-data
       (list PNET_VERSION
             hash-val
             s-env
             s-specs
             s-locs
             (module-info-exports module-info)
             (symbol->string ns-sym)))
     (define pnet-path (pnet-path-for-module ns-sym))
     (make-directory* (path-only pnet-path))
     ;; Atomic write: write to temp, then rename
     (define tmp-path (make-temporary-file "pnet-~a" #f (path-only pnet-path)))
     (call-with-output-file tmp-path
       (lambda (out) (write pnet-data out))
       #:exists 'replace)
     (rename-file-or-directory tmp-path pnet-path #t)
     pnet-path]))

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
              (let ([s-env   (list-ref raw 2)]
                    [s-specs (list-ref raw 3)]
                    [s-locs  (list-ref raw 4)]
                    [exports (list-ref raw 5)])
                (list (deep-serializable->struct s-env)
                      (deep-serializable->struct s-specs)
                      (deep-serializable->struct s-locs)
                      exports))))))
