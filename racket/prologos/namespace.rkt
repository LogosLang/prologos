#lang racket/base

;;;
;;; PROLOGOS NAMESPACE SYSTEM
;;; Module registry, namespace contexts, and name resolution.
;;;
;;; Namespaces use Clojure-style naming:
;;;   prologos::data::nat::add — :: for both hierarchy and qualified names
;;;
;;; The module registry caches loaded modules.
;;; The namespace context tracks per-file imports, aliases, and exports.
;;; Name resolution maps short/aliased names to fully-qualified symbols.
;;;

(require racket/match
         racket/string
         racket/list
         racket/set
         racket/path)

(provide
 ;; Module info
 (struct-out module-info)
 ;; Module registry
 current-module-registry
 register-module!
 lookup-module
 module-loaded?
 ;; Namespace context
 (struct-out ns-context)
 current-ns-context
 make-empty-ns-context
 ns-context-add-alias
 ns-context-add-refer
 ns-context-add-refer-all
 ns-context-set-exports
 ns-context-add-auto-export
 ;; Name resolution
 resolve-name
 qualify-name
 split-qualified-name
 ;; File resolution
 ns->path-segments
 resolve-ns-path
 current-lib-paths
 ;; Cycle detection
 current-loading-set
 ;; Module loader callback (set by driver.rkt)
 current-module-loader
 ;; Pre-parse directive processing
 process-ns-declaration
 process-require
 process-provide
 ;; Foreign import handler (callback set by driver.rkt)
 current-foreign-handler
 process-foreign
 ;; Spec propagation callback (set by driver.rkt for HKT implicit arg insertion)
 current-spec-propagation-handler)

;; ========================================
;; Module Info — describes a loaded module
;; ========================================

(struct module-info
  (namespace      ; symbol: e.g., 'prologos::data::nat
   exports        ; (listof symbol): short names exported, e.g., '(add mult zero)
   env-snapshot   ; hasheq: fully-qualified-symbol → (cons type value)
   file-path      ; path-string or #f (for built-in modules)
   macros         ; hasheq: short-name → preparse-macro or procedure
   type-aliases   ; hasheq: short-name → alias body
   specs)         ; hasheq: short-name → spec-entry (for implicit arg insertion)
  #:transparent)

;; ========================================
;; Module Registry — caches loaded modules
;; ========================================

;; Maps namespace-symbol → module-info
(define current-module-registry (make-parameter (hasheq)))

;; Register a loaded module in the registry
(define (register-module! ns-sym mod-info)
  (current-module-registry
   (hash-set (current-module-registry) ns-sym mod-info)))

;; Look up a module by namespace symbol
(define (lookup-module ns-sym)
  (hash-ref (current-module-registry) ns-sym #f))

;; Check if a module is already loaded
(define (module-loaded? ns-sym)
  (hash-has-key? (current-module-registry) ns-sym))

;; ========================================
;; Namespace Context — per-file import state
;; ========================================

(struct ns-context
  (current-ns      ; symbol: this file's namespace (e.g., 'prologos::data::nat)
   alias-map       ; hasheq: alias-symbol → namespace-symbol
                   ;   e.g., 'nat → 'prologos::data::nat
   refer-map       ; hasheq: short-name → fully-qualified-name
                   ;   e.g., 'add → 'prologos::data::nat::add
   refer-all-nses  ; (listof symbol): namespaces where all exports are available unqualified
   exports         ; (listof symbol): names this module provides (short names) — from explicit provide
   auto-exports)   ; (listof symbol): names auto-exported by public def/defn/data/deftype/defmacro
  #:transparent)

;; The current namespace context (parameterized per-file)
;; When #f, the system is in legacy mode (no namespace resolution)
(define current-ns-context (make-parameter #f))

;; Create an empty namespace context for a given namespace
(define (make-empty-ns-context ns-sym)
  (ns-context ns-sym (hasheq) (hasheq) '() '() '()))

;; Add an alias: (require [prologos::data::nat :as nat])
;; Maps alias → namespace-symbol
(define (ns-context-add-alias ctx alias ns-sym)
  (struct-copy ns-context ctx
    [alias-map (hash-set (ns-context-alias-map ctx) alias ns-sym)]))

;; Add specific referred names: (require [prologos::data::nat :refer [add mult]])
;; Maps each short name → fully-qualified name
(define (ns-context-add-refer ctx ns-sym names)
  (define new-refer
    (for/fold ([rm (ns-context-refer-map ctx)])
              ([name (in-list names)])
      (hash-set rm name (qualify-name name ns-sym))))
  (struct-copy ns-context ctx [refer-map new-refer]))

;; Add a namespace for :refer-all
(define (ns-context-add-refer-all ctx ns-sym)
  (struct-copy ns-context ctx
    [refer-all-nses (cons ns-sym (ns-context-refer-all-nses ctx))]))

;; Set the exports list
(define (ns-context-set-exports ctx export-names)
  (struct-copy ns-context ctx [exports export-names]))

;; Add a name to the auto-exports list (for public definitions).
;; Avoids duplicates.
(define (ns-context-add-auto-export ctx name)
  (if (memq name (ns-context-auto-exports ctx))
      ctx
      (struct-copy ns-context ctx
        [auto-exports (cons name (ns-context-auto-exports ctx))])))

;; ========================================
;; Name Qualification
;; ========================================

;; Create a fully-qualified name: short-name + namespace → fqn
;; e.g., 'add + 'prologos::data::nat → 'prologos::data::nat::add
(define (qualify-name short-name ns-sym)
  (string->symbol
   (string-append (symbol->string ns-sym) "::" (symbol->string short-name))))

;; Split a qualified name into prefix and short-name
;; Splits on the LAST :: so that hierarchical paths work:
;; 'nat::add → (values 'nat 'add)
;; 'prologos::data::nat::add → (values 'prologos::data::nat 'add)
;; 'add (no ::) → (values #f 'add)
(define (split-qualified-name sym)
  (define s (symbol->string sym))
  (define idx (string-find-last-substring s "::"))
  (if idx
      (values (string->symbol (substring s 0 idx))
              (string->symbol (substring s (+ idx 2))))
      (values #f sym)))

;; Helper: find the index of the FIRST occurrence of a substring, or #f
(define (string-find-substring s sub)
  (define sub-len (string-length sub))
  (define s-len (string-length s))
  (for/first ([i (in-range (+ 1 (- s-len sub-len)))]
              #:when (string=? (substring s i (+ i sub-len)) sub))
    i))

;; Helper: find the index of the LAST occurrence of a substring, or #f
(define (string-find-last-substring s sub)
  (define sub-len (string-length sub))
  (define s-len (string-length s))
  (for/last ([i (in-range (+ 1 (- s-len sub-len)))]
             #:when (string=? (substring s i (+ i sub-len)) sub))
    i))

;; ========================================
;; Name Resolution
;; ========================================

;; Resolve a symbol to its fully-qualified form.
;; Returns the resolved symbol, or #f if unresolvable.
;;
;; Algorithm:
;;   1. If ns-ctx is #f (legacy mode), return sym as-is
;;   2. If symbol contains '/', split into prefix + name:
;;      a. If prefix is an alias → resolve to aliased-ns/name
;;      b. If prefix looks like a full namespace → return as-is
;;   3. Check refer-map for direct import
;;   4. Check refer-all namespaces' exports
;;   5. Qualify with current-ns (own definitions)
;;   6. Return sym as fallback (may be a built-in like Nat, Bool, etc.)
(define (resolve-name sym ns-ctx)
  (cond
    ;; Legacy mode: no namespace resolution
    [(not ns-ctx) sym]
    [else
     (define-values (prefix short-name) (split-qualified-name sym))
     (cond
       ;; Qualified name: prefix/name
       [prefix
        (define aliased-ns (hash-ref (ns-context-alias-map ns-ctx) prefix #f))
        (cond
          ;; Prefix is a known alias
          [aliased-ns (qualify-name short-name aliased-ns)]
          ;; Prefix might be a full namespace name — return as-is
          [else sym])]

       ;; Unqualified name: try various resolution strategies
       [else
        (or
         ;; 1. Check explicit refer-map
         (hash-ref (ns-context-refer-map ns-ctx) sym #f)

         ;; 2. Check refer-all namespaces
         (resolve-in-refer-all sym ns-ctx)

         ;; 3. Qualify with current namespace (own definitions)
         (let ([fqn (qualify-name sym (ns-context-current-ns ns-ctx))])
           ;; We return the fqn but the caller must verify it exists in global-env
           fqn)

         ;; 4. Fallback: return sym as-is (might be a built-in type/keyword)
         sym)])]))

;; Search refer-all namespaces for a name
;; Returns the fqn if found in any module's exports, or #f
(define (resolve-in-refer-all sym ns-ctx)
  (for/or ([ns-sym (in-list (ns-context-refer-all-nses ns-ctx))])
    (define mod (lookup-module ns-sym))
    (and mod
         (member sym (module-info-exports mod))
         (qualify-name sym ns-sym))))

;; ========================================
;; File Resolution
;; ========================================

;; Convert a namespace symbol to path segments
;; 'prologos::data::nat → '("prologos" "data" "nat")
(define (ns->path-segments ns-sym)
  (string-split (symbol->string ns-sym) "::"))

;; Library search paths (list of directories)
;; First path is the standard library, additional paths can be added
(define current-lib-paths (make-parameter '()))

;; Resolve a namespace symbol to an absolute file path
;; Searches:
;;   1. Relative to base-dir (for project-local modules)
;;   2. Each directory in current-lib-paths
;; Returns the absolute path or #f if not found
(define (resolve-ns-path ns-sym base-dir)
  (define segments (ns->path-segments ns-sym))
  (define filename (string-append (last segments) ".prologos"))
  (define dir-segments (drop-right segments 1))

  (define (try-dir root)
    (define candidate
      (apply build-path root (append dir-segments (list filename))))
    (and (file-exists? candidate) candidate))

  ;; Search order: base-dir first, then lib paths
  (or (and base-dir (try-dir base-dir))
      (for/or ([lib-dir (in-list (current-lib-paths))])
        (try-dir lib-dir))))

;; ========================================
;; Cycle Detection
;; ========================================

;; Set of namespace symbols currently being loaded
;; Used to detect circular dependencies
(define current-loading-set (make-parameter (seteq)))

;; ========================================
;; Module Loader Callback
;; ========================================

;; A procedure: (ns-sym base-dir) → module-info
;; Set by driver.rkt to avoid circular dependency.
;; When #f, require will error (module loading not available).
(define current-module-loader (make-parameter #f))

;; Callback for propagating specs from imported modules.
;; Signature: (module-info (listof symbol)) → void
;; Called when :refer or :refer-all imports names that may have specs.
;; Set by driver.rkt to bridge namespace.rkt ↔ current-spec-store.
(define current-spec-propagation-handler (make-parameter #f))

;; ========================================
;; Prelude System
;; ========================================
;; When a user module declares (ns foo), the prelude auto-imports a curated
;; set of modules — data types, list ops, traits, and numeric instances.
;; Library modules (prologos::data::* and prologos::core::*) skip the prelude
;; to avoid circular loading and only get prologos::core::
;;
;; Modeled after: Haskell Prelude, Idris Prelude, Clojure core.
;; Name conflicts resolved: List ops win unqualified; Option/Result via aliases.

;; Modules that are direct/transitive dependencies of the prelude.
;; These must NOT auto-import the prelude (would cause circular loading).
;; They get prologos::core instead (the pre-prelude behavior).
(define (prelude-dependency? ns-sym)
  (define s (symbol->string ns-sym))
  (or (string-prefix? s "prologos::data::")
      (string-prefix? s "prologos::core::")))

;; The prelude: a curated list of require specs emitted into user namespaces.
;; Organized in tiers by dependency order.
(define prelude-requires
  '(;; ---- Tier 0: prologos::core (combinators + macros) ----
    (require [prologos::core :refer-all])

    ;; ---- Tier 0: Foundation data types ----
    (require [prologos::data::ordering :refer [Ordering lt-ord eq-ord gt-ord]])
    (require [prologos::data::bool     :refer [not and or xor bool-eq implies nand nor]])
    (require [prologos::data::nat      :refer [add mult double pred zero? sub pow
                                              le? lt? gt? ge? nat-eq? min max
                                              bool-to-nat clamp]])
    (require [prologos::data::pair     :refer [swap map-fst map-snd bimap dup uncurry]])
    (require [prologos::data::eq       :refer [sym cong trans]])

    ;; ---- Tier 1: Container data types ----
    ;; Option: types + predicates unqualified; ops via opt:: alias
    (require [prologos::data::option :as opt :refer [Option none some some? none? flatten]])
    ;; Result: types + predicates unqualified; ops via result:: alias
    (require [prologos::data::result :as result :refer [Result ok err ok? err?]])
    ;; List: full API unqualified (wins all name-conflict tiebreaks)
    (require [prologos::data::list :refer [List nil cons foldr reduce length
                                          map filter append head tail singleton
                                          reverse sum product any? all? find
                                          nth last replicate range concat
                                          concat-map take drop split-at
                                          take-while drop-while partition
                                          zip-with zip unzip intersperse sort
                                          elem dedup count scanl iterate-n
                                          intercalate sort-on reduce1 foldr1
                                          init span break prefix-of? suffix-of?
                                          delete find-index]])

    ;; ---- Tier 2: Core traits (type class definitions) ----
    (require [prologos::core::eq-trait  :refer [Eq eq-neq nat-eq]])
    (require [prologos::core::ord-trait :refer [Ord nat-ord ord-lt ord-le
                                              ord-gt ord-ge ord-eq
                                              ord-min ord-max]])
    (require [prologos::core::add-trait      :refer [Add]])
    (require [prologos::core::sub-trait      :refer [Sub]])
    (require [prologos::core::mul-trait      :refer [Mul]])
    (require [prologos::core::neg-trait      :refer [Neg]])
    (require [prologos::core::abs-trait      :refer [Abs]])
    (require [prologos::core::fromint-trait  :refer [FromInt]])
    (require [prologos::core::numeric-bundles :refer [Num Fractional]])

    ;; ---- Tier 1b: Additional container types + operations ----
    (require [prologos::data::lseq     :as lseq :refer [LSeq lseq-nil lseq-cell]])
    (require [prologos::data::lseq-ops :refer [list-to-lseq lseq-to-list lseq-map
                                              lseq-filter lseq-take lseq-drop
                                              lseq-append lseq-fold lseq-length]])
    (require [prologos::data::set      :refer [set-singleton set-from-list set-symmetric-diff]])

    ;; ---- Tier 2b: Trait definitions (additional) ----
    (require [prologos::core::additive-identity-trait       :refer-all])
    (require [prologos::core::multiplicative-identity-trait  :refer-all])

    ;; ---- Tier 2c: Collection operation modules ----
    (require [prologos::core::pvec-ops :refer [pvec-map pvec-filter pvec-fold
                                              pvec-any? pvec-all?
                                              pvec-from-list-fn pvec-to-list-fn]])
    (require [prologos::core::map-ops  :refer [map-map-vals map-filter-vals
                                              map-fold-entries map-keys-list
                                              map-vals-list map-merge]])
    (require [prologos::core::set-ops  :refer [set-map set-filter set-fold
                                              set-any? set-all?
                                              set-to-list-fn set-from-list-fn]])

    ;; ---- Tier 2d: Collection conversions ----
    (require [prologos::core::collection-conversions :refer [vec list-to-seq pvec-to-seq
                                                            set-to-seq into-vec
                                                            into-list into-set]])

    ;; ---- Tier 2e: Generic numeric operations ----
    (require [prologos::core::generic-numeric-ops :refer [sum product int-range]])

    ;; ---- Tier 3: Instance registration (side-effect only, :refer []) ----
    (require [prologos::core::eq-instances         :refer []])
    (require [prologos::core::eq-numeric-instances  :refer []])
    (require [prologos::core::ord-instances         :refer []])
    (require [prologos::core::ord-numeric-instances :refer []])
    (require [prologos::core::add-instances         :refer []])
    (require [prologos::core::sub-instances         :refer []])
    (require [prologos::core::mul-instances         :refer []])
    (require [prologos::core::neg-instances         :refer []])
    (require [prologos::core::abs-instances         :refer []])

    ;; ---- Tier 3b: Collection trait instances (side-effect only) ----
    (require [prologos::core::seqable-list    :refer []])
    (require [prologos::core::buildable-list  :refer []])
    (require [prologos::core::foldable-list   :refer []])
    (require [prologos::core::indexed-list    :refer []])
    (require [prologos::core::functor-list    :refer []])
    (require [prologos::core::seqable-pvec    :refer []])
    (require [prologos::core::buildable-pvec  :refer []])
    (require [prologos::core::indexed-pvec    :refer []])
    (require [prologos::core::foldable-pvec   :refer []])
    (require [prologos::core::functor-pvec    :refer []])
    (require [prologos::core::keyed-map       :refer []])
    (require [prologos::core::setlike-set     :refer []])
    (require [prologos::core::seqable-set     :refer []])
    (require [prologos::core::buildable-set   :refer []])
    (require [prologos::core::foldable-set    :refer []])
    (require [prologos::core::seq-lseq        :refer []])
    (require [prologos::core::foldable-lseq   :refer []])
    (require [prologos::core::seqable-lseq    :refer []])
    (require [prologos::core::buildable-lseq  :refer []])

    ;; ---- Tier 3c: Identity trait instances (side-effect only) ----
    (require [prologos::core::identity-instances :refer []])

    ;; ---- Tier 3d: Generic collection operations (HKT-dispatched) ----
    (require [prologos::core::collection-bundle :refer [Collection]])
    (require [prologos::core::generic-ops :refer [gmap gfilter gfold glength
                                                 gconcat gany? gall? gto-list]])))

;; ========================================
;; Pre-parse Directive Processing
;; ========================================
;; These functions are called from macros.rkt during preparse-expand-all.
;; They consume ns/require/provide forms and have side effects on
;; current-ns-context, current-global-env, and current-module-registry.

;; (ns namespace-sym)
;; (ns namespace-sym :no-prelude)
;; Sets the current namespace context.
;; Auto-imports the full prelude for user modules, or just prologos::core
;; for library modules and :no-prelude opt-outs.
(define (process-ns-declaration datum)
  (unless (and (list? datum) (>= (length datum) 2) (symbol? (cadr datum)))
    (error 'ns "ns requires: (ns namespace-name) or (ns namespace-name :no-prelude)"))
  (define ns-sym (cadr datum))
  (define no-prelude?
    (and (>= (length datum) 3)
         (memq ':no-prelude (cddr datum))))
  (current-ns-context (make-empty-ns-context ns-sym))
  ;; Decide what to auto-import
  (define skip-prelude?
    (or no-prelude?
        (eq? ns-sym 'prologos::core)
        (prelude-dependency? ns-sym)))
  (when (current-module-loader)
    (with-handlers ([exn:fail? (lambda (e)
                                 ;; Modules might not exist yet during bootstrap
                                 (void))])
      (cond
        [skip-prelude?
         ;; Library modules and :no-prelude: just get prologos::core
         (unless (eq? ns-sym 'prologos::core)
           (process-require '(require [prologos::core :refer-all])))]
        [else
         ;; User modules: get the full prelude
         (for ([req (in-list prelude-requires)])
           (process-require req))]))))

;; (provide name ...)
;; (provide :all)
;; Records the export list in the current namespace context.
(define (process-provide datum)
  (unless (and (list? datum) (>= (length datum) 2))
    (error 'provide "provide requires: (provide name ...) or (provide :all)"))
  (define names (cdr datum))
  (define ctx (current-ns-context))
  (unless ctx
    (error 'provide "provide used without ns declaration"))
  (cond
    [(and (= (length names) 1) (eq? (car names) ':all))
     ;; :all — will be resolved at module finalization time
     (ns-context-set-exports ctx '(:all))]
    [else
     (unless (andmap symbol? names)
       (error 'provide "provide: all names must be symbols"))
     (current-ns-context (ns-context-set-exports ctx names))]))

;; (require spec ...)
;; Where each spec is one of:
;;   [ns-sym :as alias]
;;   [ns-sym :refer [name ...]]
;;   [ns-sym :refer-all]
;;   ns-sym  (shorthand for [ns-sym :refer-all])
(define (process-require datum)
  (unless (and (list? datum) (>= (length datum) 2))
    (error 'require "require requires at least one spec"))
  (for ([spec (in-list (cdr datum))])
    (process-require-spec spec)))

;; Process a single require spec
(define (process-require-spec spec)
  (cond
    ;; Bare symbol: (require prologos::data::nat) → shorthand for :refer-all
    [(symbol? spec)
     (process-require-spec (list spec ':refer-all))]

    ;; List form: [ns-sym :as alias] or [ns-sym :refer [...]] or [ns-sym :refer-all]
    [(and (list? spec) (>= (length spec) 2) (symbol? (car spec)))
     (define ns-sym (car spec))
     (define directives (cdr spec))

     ;; Load the module if not already loaded
     (define mod (ensure-module-loaded ns-sym))

     ;; Process directives
     (let loop ([dirs directives])
       (cond
         [(null? dirs) (void)]

         ;; :as alias (WS reader may strip colon: 'as or ':as)
         [(and (>= (length dirs) 2) (memq (car dirs) '(:as as)) (symbol? (cadr dirs)))
          (define alias (cadr dirs))
          (current-ns-context
           (ns-context-add-alias (current-ns-context) alias ns-sym))
          (loop (cddr dirs))]

         ;; :refer [name ...] (WS reader may strip colon: 'refer or ':refer)
         [(and (>= (length dirs) 2) (memq (car dirs) '(:refer refer)) (list? (cadr dirs)))
          (define names (cadr dirs))
          ;; Validate that all referred names are exported by the module
          (when mod
            (define exports (module-info-exports mod))
            (for ([name (in-list names)])
              (unless (or (member name exports)
                          (and (pair? exports) (eq? (car exports) ':all)))
                (error 'require
                       "~a does not export ~a (exports: ~a)"
                       ns-sym name exports))))
          (current-ns-context
           (ns-context-add-refer (current-ns-context) ns-sym names))
          ;; Propagate specs for imported names (needed for implicit arg insertion
          ;; of where-constraint dicts in HKT generic functions)
          (when (and mod (current-spec-propagation-handler))
            ((current-spec-propagation-handler) mod names))
          (loop (cddr dirs))]

         ;; :refer-all (WS reader may strip colon: 'refer-all or ':refer-all)
         [(memq (car dirs) '(:refer-all refer-all))
          (current-ns-context
           (ns-context-add-refer-all (current-ns-context) ns-sym))
          ;; Also add explicit refers for all exports so they resolve without registry lookup
          (when mod
            (define exports (module-info-exports mod))
            (unless (and (pair? exports) (eq? (car exports) ':all))
              (current-ns-context
               (ns-context-add-refer (current-ns-context) ns-sym exports)))
            ;; Propagate specs for all exported names
            (when (current-spec-propagation-handler)
              ((current-spec-propagation-handler) mod exports)))
          (loop (cdr dirs))]

         [else
          (error 'require "Unknown require directive: ~a" (car dirs))]))]

    [else
     (error 'require "Invalid require spec: ~a" spec)]))

;; Ensure a module is loaded, returning its module-info (or #f if loader unavailable).
;; Always calls load-module (even if cached) so that load-module can import
;; the module's env-snapshot into the caller's current-global-env.
(define (ensure-module-loaded ns-sym)
  (let ([loader (current-module-loader)])
    (cond
      [loader
       (define mod (loader ns-sym #f))
       mod]
      [else
       ;; No loader available — check cache directly
       (lookup-module ns-sym)])))

;; ========================================
;; Foreign Import Handler
;; ========================================
;; Callback pattern: the actual handler is set by driver.rkt because it
;; needs access to parse-datum, elaborate, and dynamic-require.
;; namespace.rkt provides the parameter and thin dispatcher.

(define current-foreign-handler (make-parameter #f))

(define (process-foreign datum)
  (define handler (current-foreign-handler))
  (unless handler
    (error 'foreign "foreign handler not initialized (no driver context)"))
  (handler datum))
