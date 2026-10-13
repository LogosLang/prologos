#lang racket/base

;;; pnet-dump.rkt — print a `.pnet` module cache as human-readable text.
;;;
;;; Usage:
;;;   racket tools/pnet-dump.rkt [option ...] MODULE-OR-FILE ...
;;;
;;;   MODULE-OR-FILE  a module name (`prologos::core`, found in this checkout's
;;;                   cache directory) or the path of a .pnet file
;;;   (no option)     a summary: layout, header, the loader's verdict (fresh or
;;;                   STALE, and why), then one line per body slot
;;;   --slot S        print body slot S in full: a slot name from the summary
;;;                   (`trait-registry`) or its number (14). Repeatable.
;;;   --text          print the WHOLE file as text: the header datum, then the
;;;                   body datum, pretty-printed. `read`ing the output twice gives
;;;                   back the file's data (lines starting `;;` are comments).
;;;   --width N       pretty-print width in columns (default 100)
;;;
;;; Since PNET_VERSION 12 (DEFERRED 151 fix b) the body is fasl — Racket's binary
;;; S-expression format — so a cache file is no longer readable in an editor.
;;; This is its reader. It uses pnet-serialize.rkt's own header and body readers
;;; and its slot names (PNET-BODY-SLOTS), so what it prints is what the loader
;;; reads. It also reads a v11 file (text body), to compare old caches with new.
;;;
;;; What is printed is the SERIALIZED form, i.e. the data on disk: a struct is a
;;; vector headed by `struct:NAME`, a gensym is an interned `NAME$$N` tag, and a
;;; CHAMP/RRB value is a `champ-sentinel`/`rrb-sentinel` list. The loader rebuilds
;;; all three; this tool does not (it never runs the loader).
;;;
;;; Output is deterministic for diffing: Racket's printer sorts orderable hash
;;; keys (symbols, numbers, strings), and three processes printed the largest
;;; cache byte-identically. Tables with PAIR keys (subtype, specialization)
;;; print in table order, stable so far but not guaranteed; compare data with
;;; `pnet-canonical`, not `equal?` — two separately-read `hasheq`s with pair
;;; keys are never `equal?` (eq? key lookup), see driver.rkt:2888.
;;;
;;; Exit status: 0 ok; 1 a file is missing or is not a v11+ .pnet; 64 usage
;;; (unknown option or slot), as the test runner uses 64 (suite-plan.rkt).

(require racket/cmdline
         racket/list
         racket/path
         racket/pretty
         racket/string
         "../pnet-serialize.rkt")

(provide (struct-out pnet-file)
         read-pnet-file
         resolve-pnet-arg
         slot-index
         pnet-summary-lines
         write-pnet-slot
         write-pnet-text
         pnet-canonical
         EXIT-USAGE)

(define EXIT-USAGE 64)

;; Racket's fasl output starts with this; the byte after the header's newline
;; tells a v12 (fasl) body from a v11 (text) one.
(define FASL-MAGIC #"racket/fasl:")

;; path : path   size : bytes on disk   header : (pnet-header VERSION KEY)
;; layout : 'fasl | 'text   body : the list of slots 2..30
(struct pnet-file (path size header layout body) #:transparent)

;; read-pnet-file : path-string -> pnet-file
;; Raises exn:fail:user with the reason when the file is missing, has no
;; header (a v10-or-older cache, or not a cache), or has an unreadable body.
(define (read-pnet-file path-in)
  (define path (if (path? path-in) path-in (string->path path-in)))
  (unless (file-exists? path)
    (raise-user-error 'pnet-dump "no such file: ~a" path))
  (call-with-input-file path
    (lambda (in)
      (define h (read-pnet-header in))
      (unless h
        (raise-user-error
         'pnet-dump
         "~a: not a v11+ .pnet: the file does not start with a `(pnet-header VERSION KEY)` datum (a v10-or-older cache, or not a cache)"
         path))
      (define fasl? (equal? (peek-bytes (bytes-length FASL-MAGIC) 1 in) FASL-MAGIC))
      (define body
        (with-handlers ([exn:fail? (lambda (e)
                                     (raise-user-error 'pnet-dump "~a: unreadable ~a body: ~a"
                                                       path (if fasl? "fasl" "text") (exn-message e)))])
          (if fasl?
              (read-pnet-body in)
              (begin (read-char in) (read in)))))
      (unless (list? body)
        (raise-user-error 'pnet-dump "~a: the body is not a list of slots (got ~a)"
                          path (if (eof-object? body) "end of file" (short (format "~s" body) 60))))
      (pnet-file path (file-size path) h (if fasl? 'fasl 'text) body))))

;; The cache directory of THIS checkout (where the loader looks).
(define (cache-dir) (path-only (pnet-path-for-module 'x)))

;; resolve-pnet-arg : string -> (values path (or/c symbol #f))
;; A path (exists, or ends in .pnet) is taken as is; anything else is a module
;; name. The module symbol is also recovered for a file inside the cache
;; directory, so the loader's verdict can be computed for it.
(define (resolve-pnet-arg arg)
  (cond
    [(or (file-exists? arg) (regexp-match? #rx"[.]pnet$" arg))
     (define p (simplify-path (path->complete-path arg)))
     (values p (path->module-sym p))]
    [else
     (define ns (string->symbol arg))
     (values (pnet-path-for-module ns) ns)]))

(define (path->module-sym p)
  (define dir (path->string (simplify-path (cache-dir))))
  (define s (path->string p))
  (and (string-prefix? s dir)
       (regexp-match? #rx"[.]pnet$" s)
       (string->symbol
        (string-replace (substring s (string-length dir) (- (string-length s) 5)) "/" "::"))))

;; slot-index : string -> (or/c natural #f)   — position in the body (0-based)
;; Accepts a name from PNET-BODY-SLOTS or the raw slot number 2..30.
(define (slot-index spec)
  (define n (string->number spec))
  (cond
    [(exact-integer? n)
     (and (<= 2 n (+ 1 (length PNET-BODY-SLOTS))) (- n 2))]
    [else (index-of PNET-BODY-SLOTS (string->symbol spec))]))

(define (slot-name i)
  (if (< i (length PNET-BODY-SLOTS)) (list-ref PNET-BODY-SLOTS i) '?))

;; pnet-canonical : any -> any — a form for comparing pnet data: each hash
;; becomes (H kind sorted-entries), so data read twice compares equal? even
;; through pair-keyed hasheqs.
(define (pnet-canonical v)
  (cond
    [(hash? v)
     (list 'H (cond [(hash-eq? v) 'eq] [(hash-eqv? v) 'eqv] [else 'equal])
           (sort (for/list ([(k x) (in-hash v)])
                   (cons (format "~s" (pnet-canonical k)) (pnet-canonical x)))
                 string<? #:key car))]
    [(pair? v) (cons (pnet-canonical (car v)) (pnet-canonical (cdr v)))]
    [(vector? v) (for/vector #:length (vector-length v) ([x (in-vector v)]) (pnet-canonical x))]
    [(box? v) (box (pnet-canonical (unbox v)))]
    [else v]))

;; ---- summary ---------------------------------------------------------------

(define (group n)                      ; 1234567 -> "1 234 567"
  (define s (number->string n))
  (define k (string-length s))
  (string-append*
   (for/list ([c (in-string s)] [i (in-naturals)])
     (if (and (> i 0) (zero? (modulo (- k i) 3))) (string #\space c) (string c)))))

(define (short s n) (if (> (string-length s) n) (string-append (substring s 0 (- n 1)) "…") s))
(define (pad s n) (string-append s (make-string (max 0 (- n (string-length s))) #\space)))
(define (lpad s n) (string-append (make-string (max 0 (- n (string-length s))) #\space) s))

(define (text-size v) (bytes-length (string->bytes/utf-8 (format "~s" v))))

;; kind, entry count, and (for a scalar) the value itself, shown at line end
(define (kind+entries v)
  (cond
    [(hash? v)   (values "hash" (group (hash-count v)) "")]
    [(list? v)   (values "list" (group (length v)) "")]
    [(vector? v) (values "vector" (group (vector-length v)) "")]
    [(string? v) (values "string" "-" (format "  ~s" (short v 60)))]
    [else        (values "datum" "-" (format "  ~a" (short (format "~s" v) 60)))]))

;; The source key is `source-hash-for-module`'s "PATH:MTIME".
(define (key->source key)
  (define m (and (string? key) (regexp-match #rx"^(.*):[0-9]+$" key)))
  (and m (cadr m)))

;; The loader's verdict, and the first reason it would give.
(define (verdict-line pf ns)
  (define h (pnet-file-header pf))
  (define src (key->source (caddr h)))
  (cond
    [(not ns) "n/a (the file is not in this checkout's cache directory)"]
    [(not (equal? (cadr h) PNET_VERSION))
     (format "STALE: version ~s, this build reads ~a (exact equality)" (cadr h) PNET_VERSION)]
    [(not src) (format "STALE: no source path in the key ~s" (caddr h))]
    [(not (equal? (caddr h) (source-hash-for-module ns src)))
     (format "STALE: the source changed since the cache was written (now ~a)"
             (if (file-exists? src) (source-hash-for-module ns src) "missing"))]
    [(pnet-stale? ns src)
     "STALE: the compiler was rebuilt after the cache was written (driver_rkt.zo is newer)"]
    [else "fresh: a load will use this cache"]))

;; pnet-summary-lines : pnet-file (or/c symbol #f) -> (listof string)
(define (pnet-summary-lines pf ns)
  (define h (pnet-file-header pf))
  (define body (pnet-file-body pf))
  (define text-total (text-size body))
  (append
   (list (format "~a~a" (pnet-file-path pf) (if ns (format "  (~a)" ns) ""))
         (format "  layout   ~a" (if (eq? (pnet-file-layout pf) 'fasl)
                                     "text header + fasl body (v12+)"
                                     "text header + text body (v11)"))
         (format "  version  ~s   (this build reads ~a)" (cadr h) PNET_VERSION)
         (format "  key      ~s" (caddr h))
         (format "  loader   ~a" (verdict-line pf ns))
         (format "  size     ~a bytes on disk; the body is ~a bytes as text"
                 (group (pnet-file-size pf)) (group text-total))
         (format "  ~a  ~a~a~a~a" (lpad "slot" 6) (pad "name" 26) (pad "kind" 8)
                 (lpad "entries" 10) (lpad "text bytes" 14)))
   (for/list ([v (in-list body)] [i (in-naturals)])
     (define-values (kind entries value) (kind+entries v))
     (format "  ~a  ~a~a~a~a~a"
             (lpad (number->string (+ i 2)) 6) (pad (symbol->string (slot-name i)) 26)
             (pad kind 8) (lpad entries 10) (lpad (group (text-size v)) 14) value))
   (if (= (length body) (length PNET-BODY-SLOTS))
       '()
       (list (format "  NOTE: the body has ~a slots; this build names ~a"
                     (length body) (length PNET-BODY-SLOTS))))))

;; ---- full output -------------------------------------------------------------

(define (write-pnet-slot pf i out #:width [width 100])
  (define v (list-ref (pnet-file-body pf) i))
  (fprintf out ";; ~a — slot ~a: ~a\n" (pnet-file-path pf) (+ i 2) (slot-name i))
  (parameterize ([pretty-print-columns width]) (pretty-write v out)))

(define (write-pnet-text pf out #:width [width 100])
  (fprintf out ";; ~a — ~a body, printed as text by tools/pnet-dump.rkt\n"
           (pnet-file-path pf) (pnet-file-layout pf))
  (fprintf out ";; header: (pnet-header VERSION SOURCE-KEY); body: slots 2..~a, in order:\n"
           (+ 1 (length PNET-BODY-SLOTS)))
  (for ([chunk (in-list (chunk-list (for/list ([n (in-list PNET-BODY-SLOTS)] [i (in-naturals 2)])
                                      (format "~a ~a" i n))
                                    6))])
    (fprintf out ";;   ~a\n" (string-join chunk ", ")))
  (write (pnet-file-header pf) out)
  (newline out)
  (parameterize ([pretty-print-columns width]) (pretty-write (pnet-file-body pf) out)))

(define (chunk-list xs n)
  (if (<= (length xs) n) (list xs) (cons (take xs n) (chunk-list (drop xs n) n))))

;; ---- command line --------------------------------------------------------------

(module+ main
  (define slots '())
  (define text? #f)
  (define width 100)
  (define (usage-error fmt . args)
    (eprintf "pnet-dump: ~a\n" (apply format fmt args))
    (exit EXIT-USAGE))
  (define args
    (with-handlers ([exn:fail:user? (lambda (e) (usage-error "~a" (exn-message e)))])
      (command-line
       #:program "pnet-dump"
       #:multi
       [("--slot") s "Print body slot S in full (a name, or its number 2-30)"
                   (set! slots (append slots (list s)))]
       #:once-each
       [("--text") "Print the whole file as text (header datum, then body datum)"
                   (set! text? #t)]
       [("--width") n "Pretty-print width in columns (default 100)"
                    (define w (string->number n))
                    (unless (exact-positive-integer? w) (usage-error "--width wants a positive integer, got ~s" n))
                    (set! width w)]
       #:args module-or-file
       module-or-file)))
  (when (null? args) (usage-error "name at least one module (prologos::core) or .pnet file"))
  (define slot-ixs
    (for/list ([s (in-list slots)])
      (or (slot-index s)
          (usage-error "unknown slot ~s; slots are 2-~a: ~a" s (+ 1 (length PNET-BODY-SLOTS))
                       (string-join (map symbol->string PNET-BODY-SLOTS) " ")))))
  (define failed? #f)
  (for ([arg (in-list args)] [k (in-naturals)])
    (when (> k 0) (newline))
    (with-handlers ([exn:fail:user? (lambda (e) (eprintf "~a\n" (exn-message e)) (set! failed? #t))])
      (define-values (path ns) (resolve-pnet-arg arg))
      (define pf (read-pnet-file path))
      (cond
        [text? (write-pnet-text pf (current-output-port) #:width width)]
        [(pair? slot-ixs)
         (for ([i (in-list slot-ixs)])
           (if (< i (length (pnet-file-body pf)))
               (write-pnet-slot pf i (current-output-port) #:width width)
               (eprintf "pnet-dump: ~a has no slot ~a\n" path (+ i 2))))]
        [else (for ([l (in-list (pnet-summary-lines pf ns))]) (displayln l))])))
  (exit (if failed? 1 0)))
