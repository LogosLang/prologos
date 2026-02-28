#lang racket/base

;; ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
;; weave-stdlib — generate readable HTML from book chapters
;; ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
;;
;; Reads the OUTLINE manifest and chapter files from lib/prologos/book/,
;; parses prose + code structure, and generates human-readable HTML pages.
;;
;; The weaver is the dual of the tangler: while the tangler extracts
;; compilation units for the machine, the weaver renders the full
;; literate chapter — prose and code together — for the human reader.
;;
;; Usage:
;;   racket tools/weave-stdlib.rkt [--book-dir DIR] [--output-dir DIR]

(require racket/file
         racket/string
         racket/path
         racket/list
         racket/match
         racket/format)

;; ========================================
;; Data Structures
;; ========================================

(struct elem:chapter-title (text)         #:transparent)
(struct elem:part-header   (text)         #:transparent)
(struct elem:section       (text)         #:transparent)
(struct elem:module        (name flags)   #:transparent)
(struct elem:prose         (lines)        #:transparent)
(struct elem:code          (lines module) #:transparent)

(struct toc-part    (label entries)        #:transparent)
(struct toc-chapter (name title ordinal module-count) #:transparent)

;; ========================================
;; Line Classifiers
;; ========================================

(define (heavy-fence? line)
  (define s (string-trim line))
  (and (string-prefix? s ";;")
       (regexp-match? #rx"━━━" s)))

(define (double-fence? line)
  (define s (string-trim line))
  (and (string-prefix? s ";;")
       (regexp-match? #rx"════" s)))

(define (section-header? line)
  (define s (string-trim line))
  (and (string-prefix? s ";;")
       (regexp-match? #px"^;; [─\\-]{2,} .+[─\\-]+" s)))

(define (extract-section-title line)
  (define m (regexp-match #px"^;; [─\\-]{2,} (.+?) [─\\-]+\\s*$" (string-trim line)))
  (if m (cadr m) ""))

(define (module-directive? line)
  (define s (string-trim line))
  (define parts (string-split s))
  (and (pair? parts)
       (string=? (car parts) "module")
       (>= (length parts) 2)))

(define (parse-module-line line)
  (define s (string-trim line))
  (define parts (string-split s))
  (cond
    [(and (pair? parts)
          (string=? (car parts) "module")
          (>= (length parts) 2))
     (values (cadr parts) (string-join (cddr parts) " "))]
    [else (values #f #f)]))

(define (prose-line? line)
  (define s (string-trim line))
  (or (string=? s ";;")
      (string-prefix? s ";; ")))

(define (extract-prose-text line)
  (define s (string-trim line))
  (cond
    [(string=? s ";;") ""]
    [(string-prefix? s ";; ") (substring s 3)]
    [else ""]))

(define (blank-line? line)
  (string=? (string-trim line) ""))

;; ========================================
;; OUTLINE Reader (with part groupings)
;; ========================================

(define (read-outline-with-parts outline-path)
  (define lines (file->lines outline-path))
  (filter-map
   (lambda (line)
     (define stripped (string-trim line))
     (cond
       [(string=? stripped "") #f]
       [(regexp-match #rx"^;; (Part .+)$" stripped)
        => (lambda (m) (list 'part (cadr m)))]
       [(string-prefix? stripped ";;") #f]
       [else stripped]))
   lines))

;; ========================================
;; Chapter Parser
;; ========================================

;; Parse a chapter file into a list of elem: structs.
;; Single-pass state machine over lines.
(define (parse-chapter chapter-path)
  (define lines (file->lines chapter-path))
  (define result '())         ; accumulated elements (reversed)
  (define acc-lines '())      ; current accumulator (reversed)
  (define acc-type #f)        ; 'prose or 'code or #f
  (define current-module "")  ; active module name
  (define state 'preamble)    ; preamble | in-fence-title | in-fence-close-title
                              ; in-fence-part | in-fence-close-part | in-module

  ;; Flush the current accumulator as an element
  (define (flush!)
    (when (and acc-type (not (null? acc-lines)))
      (define lines-out (reverse acc-lines))
      (set! result
            (cons (case acc-type
                    [(prose) (elem:prose lines-out)]
                    [(code)  (elem:code lines-out current-module)]
                    [else (error 'flush "bad acc-type: ~a" acc-type)])
                  result)))
    (set! acc-lines '())
    (set! acc-type #f))

  ;; Accumulate a line into the current buffer, flushing if type changes
  (define (accumulate! type line)
    (when (and acc-type (not (eq? acc-type type)))
      (flush!))
    (set! acc-type type)
    (set! acc-lines (cons line acc-lines)))

  (for ([line (in-list lines)])
    (cond
      ;; ── Fence states (title / part) ──
      [(eq? state 'in-fence-title)
       ;; This line is the chapter title text
       (define title (extract-prose-text line))
       ;; Clean "Chapter: " prefix if present
       (define clean-title
         (let ([m (regexp-match #rx"^Chapter:\\s*(.+)$" title)])
           (if m (string-trim (cadr m)) (string-trim title))))
       (set! state 'in-fence-close-title)
       (set! result (cons (elem:chapter-title clean-title) result))]

      [(eq? state 'in-fence-close-title)
       ;; Expecting closing heavy fence — skip it
       (set! state 'preamble)]

      [(eq? state 'in-fence-part)
       ;; This line is the part title text
       (define title (extract-prose-text line))
       (set! state 'in-fence-close-part)
       (set! result (cons (elem:part-header title) result))]

      [(eq? state 'in-fence-close-part)
       ;; Expecting closing double fence — skip it
       (set! state 'in-module)]

      ;; ── Normal states ──
      [(heavy-fence? line)
       (flush!)
       (set! state 'in-fence-title)]

      [(double-fence? line)
       (flush!)
       (set! state 'in-fence-part)]

      [(module-directive? line)
       (flush!)
       (define-values (name flags) (parse-module-line line))
       (set! current-module (or name ""))
       (set! result (cons (elem:module (or name "") (or flags "")) result))
       (set! state 'in-module)]

      [(section-header? line)
       (flush!)
       (define title (extract-section-title line))
       (set! result (cons (elem:section title) result))]

      [(prose-line? line)
       (accumulate! 'prose (extract-prose-text line))]

      [(blank-line? line)
       ;; Blank lines in prose become paragraph breaks; in code, preserved
       (if (eq? acc-type 'code)
           (accumulate! 'code "")
           (when acc-type
             (accumulate! 'prose "")))]

      [else
       ;; Code line
       (accumulate! 'code line)]))

  ;; Final flush
  (flush!)
  (reverse result))

;; ========================================
;; HTML Escape + Inline Formatting
;; ========================================

(define (html-escape str)
  (define s1 (string-replace str "&" "&amp;"))
  (define s2 (string-replace s1 "<" "&lt;"))
  (string-replace s2 ">" "&gt;"))

(define (render-inline text)
  (define escaped (html-escape text))
  (define step1 (regexp-replace* #rx"\\*\\*([^*]+)\\*\\*" escaped "<strong>\\1</strong>"))
  (regexp-replace* #rx"`([^`]+)`" step1 "<code>\\1</code>"))

;; Split a list of prose strings into paragraphs (separated by "" blank lines).
(define (split-on-blanks lines)
  (define result '())
  (define current '())
  (for ([l (in-list lines)])
    (cond
      [(string=? l "")
       (when (not (null? current))
         (set! result (cons (reverse current) result))
         (set! current '()))]
      [else
       (set! current (cons l current))]))
  (when (not (null? current))
    (set! result (cons (reverse current) result)))
  (reverse result))

(define (render-prose-lines lines)
  (define paragraphs (split-on-blanks lines))
  (string-join
   (for/list ([para (in-list paragraphs)]
              #:when (not (null? para)))
     (format "<p>~a</p>" (string-join (map render-inline para) "\n")))
   "\n"))

(define (render-code-block code-lines)
  (define trimmed
    (let* ([fwd (dropf code-lines (lambda (l) (string=? (string-trim l) "")))]
           [rev (dropf (reverse fwd) (lambda (l) (string=? (string-trim l) "")))])
      (reverse rev)))
  (if (null? trimmed)
      ""
      (format "<pre><code class=\"prologos\">~a</code></pre>"
              (string-join (map html-escape trimmed) "\n"))))

;; ========================================
;; CSS
;; ========================================

(define book-css "
:root {
  --fg: #2c2c2c; --bg: #fefefe; --accent: #1a6fa8;
  --badge-bg: #e8f4fd; --badge-border: #b8d9f3;
  --code-bg: #f5f5f0; --border: #ccc; --muted: #666;
}
* { box-sizing: border-box; }
body {
  font-family: Georgia, 'Times New Roman', serif;
  max-width: 740px; margin: 0 auto; padding: 2rem 1.5rem;
  color: var(--fg); line-height: 1.72; background: var(--bg);
}
h1.chapter-title {
  font-size: 2rem; border-bottom: 3px double #888;
  padding-bottom: .5rem; margin-bottom: .3rem;
}
h2.part-header {
  font-size: 1.35rem; border-top: 1px solid var(--border);
  margin-top: 2.5rem; padding-top: 1rem; color: #444;
}
h3.section-title {
  font-size: 1.08rem; color: #333; border-left: 3px solid #aaa;
  padding-left: .6rem; margin-top: 1.8rem; margin-bottom: .2rem;
}
.module-badge {
  display: inline-block; font-family: 'Menlo','Consolas',monospace;
  font-size: .78rem; background: var(--badge-bg); color: var(--accent);
  border: 1px solid var(--badge-border); border-radius: 3px;
  padding: .1rem .45rem; margin: .6rem 0 .25rem;
}
pre {
  background: var(--code-bg); border-left: 3px solid var(--border);
  padding: .9rem 1rem; overflow-x: auto; border-radius: 0 4px 4px 0;
  margin: .5rem 0 1.2rem;
}
code { font-family: 'Menlo','Consolas',monospace; font-size: .87rem; }
pre code { background: none; }
p code {
  background: #f0f0ea; padding: .1em .3em; border-radius: 2px;
  font-size: .88em;
}
.prose { margin: .5rem 0; }
.prose p { margin: .6rem 0; }
nav.chapter-nav {
  font-size: .9rem; color: var(--muted);
  border-bottom: 1px solid #eee; padding-bottom: .5rem; margin-bottom: 1.5rem;
}
nav.chapter-nav a { color: var(--accent); text-decoration: none; }
nav.chapter-nav a:hover { text-decoration: underline; }
nav.chapter-nav .sep { margin: 0 .5rem; color: #ccc; }
nav.bottom-nav {
  margin-top: 3rem; padding-top: 1rem; border-top: 1px solid #eee;
  font-size: .9rem; color: var(--muted);
}
nav.bottom-nav a { color: var(--accent); text-decoration: none; }
nav.bottom-nav a:hover { text-decoration: underline; }
.preamble { margin-bottom: 1.5rem; }
/* TOC page */
.toc-part-label {
  font-size: 1.15rem; font-weight: bold; color: #444;
  margin-top: 1.8rem; margin-bottom: .3rem;
}
ol.toc-chapters { margin-top: .2rem; padding-left: 1.5rem; }
ol.toc-chapters li { margin: .3rem 0; }
ol.toc-chapters a { color: var(--accent); text-decoration: none; }
ol.toc-chapters a:hover { text-decoration: underline; }
.toc-modules { font-size: .82rem; color: var(--muted); margin-left: .4rem; }
.book-subtitle { color: var(--muted); font-size: 1rem; margin-top: -.5rem; margin-bottom: 2rem; }
")

;; ========================================
;; HTML Page Assembly
;; ========================================

(define (html-page title-text body-html)
  (string-append
   "<!DOCTYPE html>\n"
   "<html lang=\"en\">\n"
   "<head>\n"
   "  <meta charset=\"utf-8\">\n"
   "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n"
   (format "  <title>~a — Prologos Standard Library</title>\n" (html-escape title-text))
   "  <style>" book-css "  </style>\n"
   "</head>\n"
   "<body>\n"
   body-html
   "\n</body>\n"
   "</html>\n"))

;; Navigation bar
(define (nav-bar prev-name next-name #:class [cls "chapter-nav"])
  (define prev-link
    (if prev-name
        (format "<a href=\"~a.html\">← ~a</a>"
                prev-name (string-titlecase (string-replace prev-name "-" " ")))
        "<span style=\"color:#ccc\">← Prev</span>"))
  (define next-link
    (if next-name
        (format "<a href=\"~a.html\">~a →</a>"
                next-name (string-titlecase (string-replace next-name "-" " ")))
        "<span style=\"color:#ccc\">Next →</span>"))
  (format "<nav class=\"~a\">~a<span class=\"sep\">|</span><a href=\"index.html\">Table of Contents</a><span class=\"sep\">|</span>~a</nav>\n"
          cls prev-link next-link))

;; ========================================
;; Chapter Page Renderer
;; ========================================

(define (render-chapter-page elements chapter-name prev-name next-name)
  (define out '())
  (define last-module "")

  (define (emit! s) (set! out (cons s out)))

  ;; Top nav
  (emit! (nav-bar prev-name next-name))
  (emit! "<article>\n")

  (for ([e (in-list elements)])
    (match e
      [(elem:chapter-title text)
       (emit! (format "<h1 class=\"chapter-title\">~a</h1>\n" (html-escape text)))]

      [(elem:part-header text)
       (emit! (format "<h2 class=\"part-header\">~a</h2>\n" (html-escape text)))]

      [(elem:section text)
       (emit! (format "<h3 class=\"section-title\">~a</h3>\n" (html-escape text)))]

      [(elem:module name flags)
       (unless (string=? name last-module)
         (emit! (format "<div class=\"module-badge\">~a</div>\n" (html-escape name)))
         (set! last-module name))]

      [(elem:prose lines)
       (define rendered (render-prose-lines lines))
       (unless (string=? rendered "")
         (emit! (format "<div class=\"prose\">~a</div>\n" rendered)))]

      [(elem:code lines mod)
       (define rendered (render-code-block lines))
       ;; Emit module badge if module changed
       (when (and (not (string=? mod "")) (not (string=? mod last-module)))
         (emit! (format "<div class=\"module-badge\">~a</div>\n" (html-escape mod)))
         (set! last-module mod))
       (unless (string=? rendered "")
         (emit! rendered)
         (emit! "\n"))]))

  (emit! "</article>\n")
  ;; Bottom nav
  (emit! (nav-bar prev-name next-name #:class "bottom-nav"))

  (apply string-append (reverse out)))

;; ========================================
;; Index (TOC) Page Renderer
;; ========================================

(define (build-toc outline-entries chapter-info-map)
  ;; outline-entries: list of string or (list 'part label)
  ;; chapter-info-map: hash chapter-name -> (list title module-count)
  ;; Returns: list of toc-part structs
  (define parts '())
  (define current-label "Chapters")
  (define current-chapters '())
  (define ordinal 0)

  (for ([entry (in-list outline-entries)])
    (match entry
      [(list 'part label)
       ;; Flush current part
       (when (not (null? current-chapters))
         (set! parts (cons (toc-part current-label (reverse current-chapters)) parts)))
       (set! current-label label)
       (set! current-chapters '())]
      [(? string? name)
       (set! ordinal (add1 ordinal))
       (define info (hash-ref chapter-info-map name (list (string-titlecase (string-replace name "-" " ")) 0)))
       (set! current-chapters
             (cons (toc-chapter name (car info) ordinal (cadr info))
                   current-chapters))]))

  ;; Flush final part
  (when (not (null? current-chapters))
    (set! parts (cons (toc-part current-label (reverse current-chapters)) parts)))

  (reverse parts))

(define (render-index-page toc-parts)
  (define body
    (string-append
     "<h1>Prologos Standard Library</h1>\n"
     "<p class=\"book-subtitle\">A literate tour of the standard library, organized for reading.</p>\n"
     "<nav class=\"toc\">\n"
     (apply string-append
            (for/list ([part (in-list toc-parts)])
              (string-append
               (format "<div class=\"toc-part-label\">~a</div>\n" (html-escape (toc-part-label part)))
               "<ol class=\"toc-chapters\">\n"
               (apply string-append
                      (for/list ([ch (in-list (toc-part-entries part))])
                        (format "<li><a href=\"~a.html\">Chapter ~a. ~a</a><span class=\"toc-modules\">(~a module~a)</span></li>\n"
                                (toc-chapter-name ch)
                                (toc-chapter-ordinal ch)
                                (html-escape (toc-chapter-title ch))
                                (toc-chapter-module-count ch)
                                (if (= (toc-chapter-module-count ch) 1) "" "s"))))
               "</ol>\n")))
     "</nav>\n"))
  (html-page "Table of Contents" body))

;; ========================================
;; Weave Orchestrator
;; ========================================

(define (chapter-title-from-elements elements chapter-name)
  (or (for/first ([e (in-list elements)]
                  #:when (elem:chapter-title? e))
        (elem:chapter-title-text e))
      (string-titlecase (string-replace chapter-name "-" " "))))

(define (count-modules elements)
  (for/sum ([e (in-list elements)])
    (if (elem:module? e) 1 0)))

(define (weave-chapter book-dir output-dir chapter-name prev-name next-name)
  (define chapter-path (build-path book-dir (format "~a.prologos" chapter-name)))
  (unless (file-exists? chapter-path)
    (error 'weave "chapter file not found: ~a" chapter-path))

  (define elements (parse-chapter chapter-path))
  (define title (chapter-title-from-elements elements chapter-name))
  (define module-count (count-modules elements))
  (define body (render-chapter-page elements chapter-name prev-name next-name))
  (define page (html-page title body))

  (define out-path (build-path output-dir (format "~a.html" chapter-name)))
  (display-to-file page out-path #:exists 'replace)
  (printf "  ~a → ~a.html (~a modules)~n" chapter-name chapter-name module-count)

  (list title module-count))

(define (weave-all book-dir output-dir)
  (define outline-path (build-path book-dir "OUTLINE"))
  (unless (file-exists? outline-path)
    (error 'weave "OUTLINE not found: ~a" outline-path))

  (define outline-entries (read-outline-with-parts outline-path))
  (define chapter-names
    (filter string? outline-entries))

  (printf "Weaving ~a chapter~a from ~a~n"
          (length chapter-names)
          (if (= (length chapter-names) 1) "" "s")
          book-dir)
  (printf "Output: ~a~n~n" output-dir)

  ;; Ensure output dir exists
  (make-directory* output-dir)

  ;; Weave each chapter
  (define chapter-info (make-hash))
  (for ([i (in-naturals)]
        [name (in-list chapter-names)])
    (define prev (if (> i 0) (list-ref chapter-names (sub1 i)) #f))
    (define next (if (< i (sub1 (length chapter-names)))
                     (list-ref chapter-names (add1 i))
                     #f))
    (define info (weave-chapter book-dir output-dir name prev next))
    (hash-set! chapter-info name info))

  ;; Build and render index
  (define toc-parts (build-toc outline-entries chapter-info))
  (define index-page (render-index-page toc-parts))
  (define index-path (build-path output-dir "index.html"))
  (display-to-file index-page index-path #:exists 'replace)
  (printf "~n  index.html~n")

  (printf "~nDone: ~a chapter~a + index.~n"
          (length chapter-names)
          (if (= (length chapter-names) 1) "" "s")))

;; ========================================
;; CLI
;; ========================================

(module+ main
  (require racket/cmdline)

  (define project-root
    (let loop ([dir (simplify-path (current-directory))])
      (cond
        [(directory-exists? (build-path dir "racket" "prologos"))
         dir]
        [else
         (define parent (simplify-path (build-path dir "..")))
         (if (equal? parent dir)
             (current-directory)
             (loop parent))])))

  (define book-dir
    (make-parameter
     (build-path project-root "racket" "prologos" "lib" "prologos" "book")))
  (define output-dir
    (make-parameter
     (build-path project-root "docs" "stdlib-book")))

  (command-line
   #:program "weave-stdlib"
   #:once-each
   [("--book-dir") dir "Book source directory"
    (book-dir (string->path dir))]
   [("--output-dir") dir "HTML output directory"
    (output-dir (string->path dir))]
   #:args ()
   (weave-all (book-dir) (output-dir))))
