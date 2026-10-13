#lang racket/base

;;; test-suite-lock.rkt — the machine-wide suite queue (tools/suite-lock.rkt).
;;;
;;; ⚠ Every test here uses a PRIVATE lock path (a fresh temp directory). The
;;; suite that runs this file holds the REAL lock (an `--all` holds it
;;; exclusively), so a test that touched the default path would wait on its own
;;; runner.
;;;
;;; Two ports in ONE process on one file conflict under the OS lock this module
;;; uses (flock), so threads in this process stand in for concurrent runners;
;;; the holder-death test spawns a real subprocess, because that is the one
;;; property threads cannot show.

(require rackunit
         racket/file
         racket/list
         racket/port
         racket/string
         racket/os
         setup/dirs
         "../tools/suite-lock.rkt")

(define here (let-values ([(dir _n _d) (split-path (syntax-source #'here))]) dir))
(define suite-lock-module (simplify-path (build-path here ".." "tools" "suite-lock.rkt")))

(define (fresh-lock-path)
  (build-path (make-temporary-directory "suite-lock-test-~a") "suite.lock"))

(define (try mode path) (acquire-suite-lock! mode #:path path #:wait? #f))

;; ========================================
;; Mutual exclusion
;; ========================================

(test-case "suite-lock: exclusive blocks a second exclusive AND a shared taker"
  (define p (fresh-lock-path))
  (define h (try 'exclusive p))
  (check-true (suite-lock? h))
  (check-false (try 'exclusive p))
  (check-false (try 'shared p))
  (release-suite-lock! h)
  (define h2 (try 'shared p))
  (check-true (suite-lock? h2) "released: a shared taker now gets in")
  (release-suite-lock! h2))

(test-case "suite-lock: shared admits shared, and shared blocks exclusive"
  (define p (fresh-lock-path))
  (define s1 (try 'shared p))
  (define s2 (try 'shared p))
  (check-true (and (suite-lock? s1) (suite-lock? s2)))
  (check-false (try 'exclusive p))
  (release-suite-lock! s1)
  (check-false (try 'exclusive p) "one shared holder is still in")
  (release-suite-lock! s2)
  (define e (try 'exclusive p))
  (check-true (suite-lock? e))
  (release-suite-lock! e))

(test-case "suite-lock: release is idempotent; a refused --no-wait try leaves no info file"
  (define p (fresh-lock-path))
  (define h (try 'exclusive p))
  (check-false (try 'shared p))
  (check-equal? (length (suite-lock-holders p)) 1 "only the holder is listed")
  (release-suite-lock! h)
  (release-suite-lock! h)
  (check-equal? (suite-lock-holders p) '()))

;; ========================================
;; Holder death (a real second process)
;; ========================================

(define racket-exe
  (let ([dir (find-console-bin-dir)])
    (or (for/first ([n (in-list '("racket" "racket.exe"))]
                    #:when (file-exists? (build-path dir n)))
          (build-path dir n))
        (find-executable-path "racket"))))

(test-case "suite-lock: a holder that DIES without releasing frees the lock (SIGKILL)"
  (define p (fresh-lock-path))
  (define prog
    (format "~s"
            `(begin
               (define h ((dynamic-require (string->path ,(path->string suite-lock-module))
                                           'acquire-suite-lock!)
                          'exclusive #:path (string->path ,(path->string p)) #:wait? #f))
               (printf "~a\n" (if h "held" "refused"))
               (flush-output)
               (sleep 600))))
  (define-values (proc out in err)
    (subprocess #f #f #f racket-exe "-l" "racket/base" "-e" prog))
  (close-output-port in)
  (define line (sync/timeout 60 (read-line-evt out 'any)))
  (check-equal? line "held" "the child took the lock")
  (check-false (try 'exclusive p) "held by the child")
  (check-false (try 'shared p))
  (define holders (suite-lock-holders p))
  (check-equal? (map (lambda (h) (hash-ref h 'pid)) holders) (list (subprocess-pid proc)))
  (check-equal? (hash-ref (car holders) 'state) "holding")
  ;; No release, no exit handler, no cleanup: the OS must do it.
  (subprocess-kill proc #t)
  (subprocess-wait proc)
  (close-input-port out)
  (close-input-port err)
  (define info-dir (string->path (string-append (path->string p) ".d")))
  (check-equal? (length (directory-list info-dir)) 1 "the dead child's info file is left over")
  (define h (try 'exclusive p))
  (check-true (suite-lock? h) "the dead child's lock was released by the OS")
  ;; The lock probe on the leftover shows it is stale; acquiring swept it.
  (check-equal? (length (directory-list info-dir)) 1 "only our own info file remains")
  (check-equal? (map (lambda (x) (hash-ref x 'pid)) (suite-lock-holders p)) (list (getpid)))
  (release-suite-lock! h))

;; ========================================
;; Writer preference
;; ========================================

(define (wait-until pred [secs 10])
  (let loop ([n (* secs 100)])
    (cond [(pred) #t]
          [(zero? n) #f]
          [else (sleep 0.01) (loop (sub1 n))])))

(test-case "suite-lock: a WAITING exclusive taker is not starved by new shared takers"
  (define p (fresh-lock-path))
  (define s1 (try 'shared p))
  (check-true (suite-lock? s1))
  ;; An exclusive taker starts waiting behind s1 ...
  (define got (box #f))
  (define t (thread (lambda ()
                      (set-box! got (acquire-suite-lock! 'exclusive #:path p #:poll-secs 0.02)))))
  (check-true (wait-until (lambda ()
                            (for/or ([h (in-list (suite-lock-holders p))])
                              (and (equal? (hash-ref h 'mode #f) "exclusive")
                                   (equal? (hash-ref h 'state #f) "waiting")))))
              "the exclusive taker is listed as waiting")
  (sleep 0.1)  ; it has polled at least once: it holds the turnstile
  ;; ... so a NEW shared taker must queue behind it, although s1 (shared) holds
  ;; the lock and shared admits shared. Without the turnstile this succeeds.
  (check-false (try 'shared p) "a shared taker may not overtake a waiting exclusive one")
  (release-suite-lock! s1)
  (check-true (wait-until (lambda () (unbox got))) "the exclusive waiter gets the lock")
  (check-false (try 'shared p))
  (release-suite-lock! (unbox got))
  (thread-wait t)
  (define s2 (try 'shared p))
  (check-true (suite-lock? s2))
  (release-suite-lock! s2))

(test-case "suite-lock: a waiting taker reports the holders it is waiting for"
  (define p (fresh-lock-path))
  (define h (acquire-suite-lock! 'exclusive #:path p #:wait? #f
                                 #:checkout "/some/checkout" #:command "run-affected-tests --all"))
  (define seen (box '()))
  (define t (thread (lambda ()
                      (acquire-suite-lock! 'shared #:path p #:poll-secs 0.02
                                           #:on-wait (lambda (holders waited)
                                                       (set-box! seen holders))))))
  (check-true (wait-until (lambda () (pair? (unbox seen)))))
  (define holder (car (unbox seen)))
  (check-equal? (hash-ref holder 'pid) (getpid))
  (check-equal? (hash-ref holder 'mode) "exclusive")
  (check-equal? (hash-ref holder 'state) "holding")
  (check-equal? (hash-ref holder 'checkout) "/some/checkout")
  (check-equal? (hash-ref holder 'command) "run-affected-tests --all")
  (check-true (exact-integer? (hash-ref holder 'started)))
  (check-false (for/or ([x (in-list (unbox seen))]) (equal? (hash-ref x 'state #f) "waiting"))
               "the waiter does not list itself")
  (check-true (string-contains? (format-holder holder) "/some/checkout"))
  (release-suite-lock! h)
  (thread-wait t))

;; ========================================
;; Release on exit; the path; the mode rule
;; ========================================

(test-case "suite-lock: call-with-suite-lock releases BEFORE (exit N) leaves the process"
  ;; A real `exit` never returns, so no dynamic-wind runs after it: the release
  ;; must happen inside the exit handler. The probe looks at the lock from
  ;; within the outer exit handler, i.e. at the moment the process would end.
  (define p (fresh-lock-path))
  (define free-at-exit? 'not-called)
  (define code
    (let/ec k
      (parameterize ([exit-handler (lambda (c)
                                     (define h (try 'exclusive p))
                                     (set! free-at-exit? (suite-lock? h))
                                     (when h (release-suite-lock! h))
                                     (k c))])
        (call-with-suite-lock 'exclusive (lambda () (exit 3)) #:path p #:wait? #f))))
  (check-equal? code 3)
  (check-equal? free-at-exit? #t "the lock was free when the process would have exited")
  (check-equal? (suite-lock-holders p) '() "and no info file is left for waiters to list"))

(test-case "suite-lock: busy + --no-wait calls on-busy with the holders, runs nothing"
  (define p (fresh-lock-path))
  (define h (try 'exclusive p))
  (define ran? #f)
  (define busy
    (call-with-suite-lock 'shared (lambda () (set! ran? #t))
                          #:path p #:wait? #f
                          #:on-busy (lambda (holders) (length holders))))
  (check-false ran?)
  (check-equal? busy 1)
  (release-suite-lock! h))

(test-case "suite-lock: the path is machine-wide (not per checkout) and env-overridable"
  (parameterize ([current-environment-variables
                  (environment-variables-copy (current-environment-variables))])
    (environment-variables-set! (current-environment-variables) #"PROLOGOS_SUITE_LOCK" #f)
    (define a (parameterize ([current-directory (find-system-path 'temp-dir)]) (suite-lock-path)))
    (define b (parameterize ([current-directory here]) (suite-lock-path)))
    (check-equal? a b "independent of the current directory")
    (define checkout-root (path->string (simplify-path (build-path here ".." ".." ".."))))
    (check-false (string-prefix? (path->string a) checkout-root) "not inside this checkout")
    (putenv "PROLOGOS_SUITE_LOCK" "/tmp/private-suite.lock")
    (check-equal? (suite-lock-path) (string->path "/tmp/private-suite.lock"))))

;; DEFERRED 166 (SW-20): an inherited PROLOGOS_SUITE_LOCK took a run out of the
;; machine-wide queue and nothing on screen said so. Every run now prints where
;; it queues, and a ⚠ line when the env var moved it off the default.
(define (banner-under env-value mode)
  (parameterize ([current-environment-variables
                  (environment-variables-copy (current-environment-variables))])
    (environment-variables-set! (current-environment-variables) #"PROLOGOS_SUITE_LOCK"
                                (and env-value (string->bytes/utf-8 env-value)))
    (suite-lock-banner mode (suite-lock-path))))

(test-case "suite-lock: every run names its lock; an env override is a ⚠ line naming both files (DEFERRED 166)"
  (define dflt (path->string (default-suite-lock-path)))
  (define plain (banner-under #f 'shared))
  (check-equal? (length plain) 1 "default: one line, no warning")
  (check-true (string-contains? (car plain) dflt))
  (check-true (string-contains? (car plain) "shared"))
  (check-false (string-contains? (car plain) "⚠"))
  (define over (banner-under "/tmp/private-suite.lock" 'exclusive))
  (check-equal? (length over) 2)
  (check-true (string-contains? (car over) "/tmp/private-suite.lock") "the header names the file actually used")
  (check-true (string-contains? (cadr over) "⚠"))
  (check-true (string-contains? (cadr over) "PROLOGOS_SUITE_LOCK"))
  (check-true (string-contains? (cadr over) dflt) "the warning names the queue it left")
  (check-equal? (length (banner-under "" 'shared)) 1 "an EMPTY value is no override (suite-lock-path ignores it)")
  (check-equal? (length (banner-under dflt 'shared)) 1 "pointing at the default path is no override"))

(test-case "suite-lock: mode rule — a full suite is exclusive, a targeted run shared"
  (check-equal? (suite-lock-mode #:all? #t #:file-count 3) 'exclusive)
  (check-equal? (suite-lock-mode #:all? #f #:file-count 3) 'shared)
  (check-equal? (suite-lock-mode #:all? #f #:file-count 99) 'shared)
  (check-equal? (suite-lock-mode #:all? #f #:file-count 100) 'exclusive "suite-sized affected run"))
