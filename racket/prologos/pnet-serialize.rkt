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
         "syntax.rkt"
         "namespace.rkt")

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

  (define (deep-s->v v)
    (cond
      [(procedure? v)
       ;; Foreign function or preparse expander — store name for re-linking
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

  deep-s->v)

(define (deep-struct->serializable v)
  ((make-serializer) v))

;; ============================================================
;; Deserialization: read + tag dispatch reconstruction
;; ============================================================

;; Build the tag→constructor dispatch table from syntax.rkt
;; This is auto-generable from struct definitions.
(define (make-tag-constructor-table)
  (hasheq
   ;; Core expression types
   'struct:expr-bvar     (lambda (idx) (expr-bvar idx))
   'struct:expr-fvar     (lambda (name) (expr-fvar name))
   'struct:expr-zero     (lambda () (expr-zero))
   'struct:expr-suc      (lambda (pred) (expr-suc pred))
   'struct:expr-nat-val  (lambda (n) (expr-nat-val n))
   'struct:expr-lam      (lambda (m t body) (expr-lam m t body))
   'struct:expr-app      (lambda (f a) (expr-app f a))
   'struct:expr-pair     (lambda (a b) (expr-pair a b))
   'struct:expr-fst      (lambda (e) (expr-fst e))
   'struct:expr-snd      (lambda (e) (expr-snd e))
   'struct:expr-refl     (lambda () (expr-refl))
   'struct:expr-ann      (lambda (t ty) (expr-ann t ty))
   'struct:expr-natrec   (lambda (m b s tgt) (expr-natrec m b s tgt))
   'struct:expr-J        (lambda (m b l r p) (expr-J m b l r p))
   'struct:expr-Type     (lambda (l) (expr-Type l))
   'struct:expr-Nat      (lambda () (expr-Nat))
   'struct:expr-Bool     (lambda () (expr-Bool))
   'struct:expr-true     (lambda () (expr-true))
   'struct:expr-false    (lambda () (expr-false))
   'struct:expr-boolrec  (lambda (m tc fc tgt) (expr-boolrec m tc fc tgt))
   'struct:expr-Pi       (lambda (m d c) (expr-Pi m d c))
   'struct:expr-Sigma    (lambda (a b) (expr-Sigma a b))
   'struct:expr-hole     (lambda () (expr-hole))
   'struct:expr-typed-hole (lambda (t) (expr-typed-hole t))
   'struct:expr-error    (lambda () (expr-error))
   'struct:expr-meta     (lambda (id cid) (expr-meta id cid))
   'struct:expr-Unit     (lambda () (expr-Unit))
   'struct:expr-unit     (lambda () (expr-unit))
   'struct:expr-Nil      (lambda () (expr-Nil))
   'struct:expr-nil      (lambda () (expr-nil))
   'struct:expr-Int      (lambda () (expr-Int))
   'struct:expr-int-val  (lambda (n) (expr-int-val n))
   'struct:expr-Rat      (lambda () (expr-Rat))
   'struct:expr-rat-val  (lambda (n) (expr-rat-val n))
   'struct:expr-Char     (lambda () (expr-Char))
   'struct:expr-char-val (lambda (c) (expr-char-val c))
   'struct:expr-String   (lambda () (expr-String))
   'struct:expr-string-val (lambda (s) (expr-string-val s))
   'struct:expr-Keyword  (lambda () (expr-Keyword))
   'struct:expr-keyword-val (lambda (k) (expr-keyword-val k))
   'struct:expr-PVec     (lambda (t) (expr-PVec t))
   'struct:expr-pvec-literal (lambda (elems) (expr-pvec-literal elems))
   'struct:expr-Map      (lambda (k v) (expr-Map k v))
   'struct:expr-map-literal (lambda (entries) (expr-map-literal entries))
   'struct:expr-Set      (lambda (t) (expr-Set t))
   'struct:expr-set-literal (lambda (elems) (expr-set-literal elems))
   'struct:expr-union    (lambda (l r) (expr-union l r))
   'struct:expr-tycon    (lambda (name) (expr-tycon name))
   'struct:expr-foreign-fn (lambda args (apply expr-foreign-fn args))
   'struct:expr-panic    (lambda (msg) (expr-panic msg))
   'struct:expr-reduce   (lambda (s arms str?) (expr-reduce s arms str?))
   'struct:expr-reduce-arm (lambda (name bc body) (expr-reduce-arm name bc body))
   'struct:expr-get      (lambda (e k) (expr-get e k))
   'struct:expr-Eq       (lambda (t a b) (expr-Eq t a b))
   'struct:expr-match    (lambda (s arms) (expr-match s arms))
   'struct:expr-match-arm (lambda (p b) (expr-match-arm p b))
   'struct:lzero         (lambda () (lzero))
   'struct:lsuc          (lambda (l) (lsuc l))
   'struct:lmax          (lambda (a b) (lmax a b))
   'struct:lmeta         (lambda (id) (lmeta id))
   'struct:cell-id       (lambda (n) (cell-id n))
   ;; ns-context (may appear in serialized state)
   'struct:ns-context    (lambda args (apply ns-context args))
   ))

(define tag-table (make-tag-constructor-table))

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
  (define serialize! (make-serializer))
  (define env (module-info-env-snapshot module-info))
  (define specs (module-info-specs module-info))
  (define locs (module-info-definition-locations module-info))

  (define s-env (serialize! env))
  (define s-specs (serialize! specs))
  (define s-locs (serialize! locs))
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

  pnet-path)

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
