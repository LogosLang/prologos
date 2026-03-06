#lang racket/base

;;;
;;; test-io-bridge-01.rkt — IO bridge infrastructure tests
;;;
;;; Phase IO-B: Tests for IO state lattice (B1), IO bridge propagator (B2),
;;; and FFI bridge wrappers (B3).
;;;
;;; Pattern: Direct struct construction, no shared fixtures, no process-string.
;;; Uses temporary files for IO tests.
;;;

(require rackunit
         racket/file
         racket/port
         racket/string
         "../io-bridge.rkt"
         "../io-ffi.rkt"
         "../propagator.rkt"
         "../sessions.rkt"
         "../session-runtime.rkt"
         "../syntax.rkt")

;; ========================================
;; Group 1: IO State Lattice (IO-B1)
;; ========================================

(test-case "io-state-lattice: bot is identity"
  ;; io-bot ⊔ x = x and x ⊔ io-bot = x
  (define opening (io-opening "/tmp/test" 'read))
  (define mock-port (open-input-string "mock"))
  (define open-st (io-open mock-port 'read))
  ;; bot ⊔ x = x
  (check-equal? (io-state-merge io-bot io-bot) io-bot)
  (check-equal? (io-state-merge io-bot opening) opening)
  (check-equal? (io-state-merge io-bot open-st) open-st)
  (check-equal? (io-state-merge io-bot io-closed) io-closed)
  ;; x ⊔ bot = x
  (check-equal? (io-state-merge opening io-bot) opening)
  (check-equal? (io-state-merge open-st io-bot) open-st)
  (check-equal? (io-state-merge io-closed io-bot) io-closed)
  (close-input-port mock-port))

(test-case "io-state-lattice: top is absorbing"
  ;; io-top ⊔ x = io-top and x ⊔ io-top = io-top
  (define opening (io-opening "/tmp/test" 'read))
  (check-true (io-top? (io-state-merge io-top io-bot)))
  (check-true (io-top? (io-state-merge io-top opening)))
  (check-true (io-top? (io-state-merge io-top io-closed)))
  (check-true (io-top? (io-state-merge io-bot io-top)))
  (check-true (io-top? (io-state-merge opening io-top)))
  (check-true (io-top? (io-state-merge io-closed io-top))))

(test-case "io-state-lattice: valid transitions"
  ;; io-opening → io-open
  (define mock-port (open-input-string "data"))
  (define opening (io-opening "/tmp/test" 'read))
  (define open-st (io-open mock-port 'read))
  (define result1 (io-state-merge opening open-st))
  (check-true (io-open? result1))
  (check-eq? (io-open-port result1) mock-port)
  ;; io-open → io-closed
  (define result2 (io-state-merge open-st io-closed))
  (check-true (io-closed? result2))
  (close-input-port mock-port))

(test-case "io-state-lattice: idempotent"
  ;; merge(x, x) = x for all state values
  (check-equal? (io-state-merge io-bot io-bot) io-bot)
  (check-equal? (io-state-merge io-closed io-closed) io-closed)
  (check-equal? (io-state-merge io-top io-top) io-top)
  (define opening (io-opening "/tmp/test" 'read))
  (check-equal? (io-state-merge opening opening) opening)
  (define mock-port (open-input-string "data"))
  (define open-st (io-open mock-port 'read))
  (check-equal? (io-state-merge open-st open-st) open-st)
  (close-input-port mock-port))

(test-case "io-state-lattice: invalid transitions → contradiction"
  (define mock-port (open-input-string "data"))
  (define opening (io-opening "/tmp/test" 'read))
  (define open-st (io-open mock-port 'read))
  ;; Backward transitions are contradictions
  (check-true (io-top? (io-state-merge io-closed opening)))    ; closed → opening
  (check-true (io-top? (io-state-merge io-closed open-st)))    ; closed → open
  (check-true (io-top? (io-state-merge open-st opening)))      ; open → opening
  ;; Two different openings are contradictions
  (define opening2 (io-opening "/tmp/other" 'write))
  (check-true (io-top? (io-state-merge opening opening2)))
  ;; Contradiction predicate
  (check-true (io-state-contradicts? io-top))
  (check-false (io-state-contradicts? io-bot))
  (check-false (io-state-contradicts? io-closed))
  (check-false (io-state-contradicts? opening))
  (check-false (io-state-contradicts? open-st))
  (close-input-port mock-port))

;; ========================================
;; Group 2: IO Bridge Propagator (IO-B2)
;; ========================================

(test-case "io-bridge-cell: creates cell at io-bot"
  (define net (make-prop-network))
  (define-values (net* cid) (make-io-bridge-cell net))
  (check-true (io-bot? (net-cell-read net* cid))))

(test-case "io-bridge-open-file: read mode opens input port"
  ;; Create a temp file with known content
  (define tmp (make-temporary-file))
  (call-with-output-file tmp
    (lambda (out) (write-string "hello world" out))
    #:exists 'truncate/replace)
  ;; Set up a network with an io-cell at io-opening
  (define net0 (make-prop-network))
  (define-values (net1 io-cid) (make-io-bridge-cell net0))
  (define net2 (net-cell-write net1 io-cid (io-opening (path->string tmp) 'read)))
  ;; Open the file
  (define net3 (io-bridge-open-file net2 io-cid))
  (define state (net-cell-read net3 io-cid))
  (check-true (io-open? state))
  (check-equal? (io-open-mode state) 'read)
  (check-true (input-port? (io-open-port state)))
  ;; Clean up
  (close-input-port (io-open-port state))
  (delete-file tmp))

(test-case "io-bridge-open-file: nonexistent file → io-top"
  (define net0 (make-prop-network))
  (define-values (net1 io-cid) (make-io-bridge-cell net0))
  (define net2 (net-cell-write net1 io-cid
                 (io-opening "/nonexistent/path/does-not-exist.txt" 'read)))
  (define net3 (io-bridge-open-file net2 io-cid))
  (check-true (io-top? (net-cell-read net3 io-cid))))

(test-case "io-bridge-propagator: read delivers data to msg-in"
  ;; Create a temp file with known content
  (define tmp (make-temporary-file))
  (call-with-output-file tmp
    (lambda (out) (write-string "test data" out))
    #:exists 'truncate/replace)
  ;; Open the file to get a real port
  (define port (open-input-file tmp))
  ;; Set up a mini propagator network:
  ;;   io-cell: io-open (with real port)
  ;;   session-cell: sess-recv String sess-end (expecting to receive data)
  ;;   msg-out-cell: msg-bot (nothing outgoing)
  ;;   msg-in-cell: msg-bot (where read result should arrive)
  (define net0 (make-prop-network))
  (define-values (net1 io-cid)      (make-io-bridge-cell net0))
  (define-values (net2 sess-cid)    (net-new-cell net1 (sess-recv (expr-String) (sess-end))
                                      (lambda (o n) n)))  ; simple overwrite merge
  (define-values (net3 msg-out-cid) (net-new-cell net2 msg-bot msg-lattice-merge))
  (define-values (net4 msg-in-cid)  (net-new-cell net3 msg-bot msg-lattice-merge))
  ;; Write io-open state
  (define net5 (net-cell-write net4 io-cid (io-open port 'read)))
  ;; Install the IO bridge propagator
  (define fire-fn (make-io-bridge-propagator io-cid sess-cid msg-in-cid msg-out-cid))
  (define-values (net6 _pid) (net-add-propagator net5
                               (list io-cid sess-cid msg-out-cid)
                               (list msg-in-cid io-cid)
                               fire-fn))
  ;; Run to quiescence — the bridge should read from the file
  (define net7 (run-to-quiescence net6))
  ;; Verify msg-in-cell received the file contents
  (define result (net-cell-read net7 msg-in-cid))
  (check-true (expr-string? result))
  (check-equal? (expr-string-val result) "test data")
  ;; Clean up
  (close-input-port port)
  (delete-file tmp))

(test-case "io-bridge-propagator: session end closes port"
  ;; Create a temp file
  (define tmp (make-temporary-file))
  (define port (open-input-file tmp))
  ;; Set up network with io-open and sess-end
  (define net0 (make-prop-network))
  (define-values (net1 io-cid)      (make-io-bridge-cell net0))
  (define-values (net2 sess-cid)    (net-new-cell net1 (sess-end)
                                      (lambda (o n) n)))
  (define-values (net3 msg-out-cid) (net-new-cell net2 msg-bot msg-lattice-merge))
  (define-values (net4 msg-in-cid)  (net-new-cell net3 msg-bot msg-lattice-merge))
  ;; Write io-open state
  (define net5 (net-cell-write net4 io-cid (io-open port 'read)))
  ;; Install bridge propagator
  (define fire-fn (make-io-bridge-propagator io-cid sess-cid msg-in-cid msg-out-cid))
  (define-values (net6 _pid) (net-add-propagator net5
                               (list io-cid sess-cid msg-out-cid)
                               (list msg-in-cid io-cid)
                               fire-fn))
  ;; Run to quiescence
  (define net7 (run-to-quiescence net6))
  ;; Verify io-cell is now io-closed
  (check-true (io-closed? (net-cell-read net7 io-cid)))
  ;; Verify the Racket port is actually closed
  (check-true (port-closed? port))
  ;; Clean up
  (delete-file tmp))

;; ========================================
;; Group 3: FFI Bridge Wrappers (IO-B3)
;; ========================================

(test-case "io-ffi-registry: all entries present"
  ;; Registry should contain 12 entries, each a (cons procedure type-desc)
  (define expected-keys
    '(io-open-input io-open-output io-read-string io-read-line
      io-write-string io-close io-port-closed?
      io-display io-displayln io-read-ln
      io-file-exists? io-directory?))
  (for ([key (in-list expected-keys)])
    (define entry (hash-ref io-ffi-registry key #f))
    (check-not-false entry (format "missing key: ~a" key))
    (check-true (pair? entry) (format "entry for ~a should be a pair" key))
    (check-true (procedure? (car entry))
                (format "car of ~a should be a procedure" key))))

(test-case "io-ffi: port-read-string reads content"
  (define tmp (make-temporary-file))
  (call-with-output-file tmp
    (lambda (out) (write-string "hello from file" out))
    #:exists 'truncate/replace)
  (define port (open-input-file tmp))
  (define result (port-read-string port))
  (check-equal? result "hello from file")
  (close-input-port port)
  (delete-file tmp))

(test-case "io-ffi: port-read-string returns empty on EOF"
  (define tmp (make-temporary-file))
  ;; Write nothing — the file will be empty from make-temporary-file
  (call-with-output-file tmp
    (lambda (out) (void))
    #:exists 'truncate/replace)
  (define port (open-input-file tmp))
  (define result (port-read-string port))
  (check-equal? result "")
  (close-input-port port)
  (delete-file tmp))

(test-case "io-ffi: port-write-string writes content"
  (define tmp (make-temporary-file))
  (define port (open-output-file tmp #:exists 'truncate/replace))
  (port-write-string port "written content")
  (close-output-port port)
  ;; Read back and verify
  (define content (file->string tmp))
  (check-equal? content "written content")
  (delete-file tmp))

(test-case "io-ffi: display/displayln wrappers"
  ;; display-wrapper should produce "hello" without newline
  (define display-out
    (with-output-to-string (lambda () (display-wrapper "hello"))))
  (check-equal? display-out "hello")
  ;; displayln-wrapper should produce "hello\n" with newline
  (define displayln-out
    (with-output-to-string (lambda () (displayln-wrapper "hello"))))
  (check-equal? displayln-out "hello\n"))
