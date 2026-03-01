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
  ;; Handle double-backtick inline code first: `` `content` ``
  ;; Content may include single backticks, so use .*? (non-greedy)
  (define step2 (regexp-replace* #rx"``[ ](.+?)[ ]``" step1 "<code>\\1</code>"))
  ;; Then single-backtick: `content`
  (regexp-replace* #rx"`([^`]+)`" step2 "<code>\\1</code>"))

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

;; ========================================
;; Syntax Highlighting
;; ========================================
;;
;; Regex-based highlighter. Works on HTML-escaped text using a sentinel-based
;; approach: first pass replaces tokens with sentinels (\x00class\x00text\x01),
;; then a second pass converts sentinels to <span> tags. This avoids double-
;; wrapping since regexes only match un-sentineled text.

;; Keyword regex: word-boundary matched list of all Prologos keywords.
;; The regex is compiled once at module load time.
(define hl-keyword-rx
  (regexp
   (string-append
    "(?<=^|[ \\[\\]{}(),])"  ;; lookbehind: start of line or delimiter
    "("
    (string-join
     '("defn" "def" "data" "spec-?" "trait-?" "impl-?"
       "match" "fn" "let" "do" "if" "the" "forall" "exists"
       "check" "eval" "infer" "defmacro" "bundle" "property" "functor"
       "relation" "clause" "query" "foreign" "require" "provide"
       "ns" "module" "deftype" "subtype" "transient" "persist!"
       "with-transient" "defr")
     "|")
    ")"
    "(?=$|[ \\[\\]{}(),:])")))  ;; lookahead: end of line or delimiter

;; Highlight an already-HTML-escaped code line using regex replacements.
;; Order matters: strings and comments first (highest priority), then other tokens.
;; Uses #px (Perl-compatible) regexes for lookbehind/lookahead support.
;; Highlight uses a placeholder approach: strings and comments are extracted
;; first (replaced with unique tokens), then keyword/type/etc highlighting
;; runs on the placeholder-ified text, then placeholders are restored.
;; This prevents keywords inside strings from being highlighted.
(define (highlight-code-line line)
  ;; Phase A: Extract comments and strings into placeholders
  (define stash '())  ;; list of (placeholder . replacement) pairs
  (define counter 0)
  (define (make-placeholder! cls content)
    (set! counter (add1 counter))
    (define tok (format "\x00~a\x00" counter))
    (set! stash (cons (cons tok (format "<span class=\"~a\">~a</span>" cls content))
                      stash))
    tok)

  ;; Step 1: Comments (;; to end of line)
  ;; Use #px lookbehind to avoid matching ; in HTML entities like &lt; &gt; &amp;
  (define s1
    (regexp-replace #px"(?<![a-z]);.*$" line
                    (lambda (m) (make-placeholder! "hl-cmt" m))))

  ;; Step 2: Strings ("...") — replace with placeholders
  (define s2
    (regexp-replace* #rx"\"[^\"]*\""
                     s1
                     (lambda (m) (make-placeholder! "hl-str" m))))

  ;; Phase B: Highlight remaining tokens (safe — no strings/comments to interfere)

  ;; Step 3: Keyword literals (:name, :refer, etc.)
  (define s3
    (regexp-replace* #px"(?<![a-zA-Z0-9_:]):[a-zA-Z][a-zA-Z0-9_?!*+-]*"
                     s2
                     (lambda (m) (string-append "<span class=\"hl-kwlit\">" m "</span>"))))

  ;; Step 4: Number literals (42N, 3/4, ~3.14)
  (define s4
    (regexp-replace* #px"(?<=[[ (]|^)[~]?[0-9]+(?:/[0-9]+|\\.[0-9]+|N)?"
                     s3
                     (lambda (m) (string-append "<span class=\"hl-num\">" m "</span>"))))

  ;; Step 5: Operators (-&gt; is HTML-escaped ->)
  (define s5
    (regexp-replace* #rx"-&gt;|&gt;&gt;|:="
                     s4
                     (lambda (m) (string-append "<span class=\"hl-op\">" m "</span>"))))

  ;; Step 6: Keywords (word-boundary matched)
  (define s6
    (regexp-replace* #px"(?<=^|[ \\[\\]{}(),\n])(?:defn|def|data|spec-?|trait-?|impl-?|match|fn|let|do|if|the|forall|exists|check|eval|infer|defmacro|bundle|property|functor|relation|clause|query|foreign|require|provide|ns|module|deftype|subtype|transient|persist!|with-transient|defr)(?=$|[ \\[\\]{}(),:])"
                     s5
                     (lambda (m) (string-append "<span class=\"hl-kw\">" m "</span>"))))

  ;; Step 7: Type identifiers (start with uppercase, not already in a span tag)
  (define s7
    (regexp-replace* #px"(?<![a-z\">])[A-Z][a-zA-Z0-9_*+!?'-]*"
                     s6
                     (lambda (m) (string-append "<span class=\"hl-ty\">" m "</span>"))))

  ;; Phase C: Restore placeholders
  (for/fold ([result s7])
            ([pair (in-list stash)])
    (string-replace result (car pair) (cdr pair))))

(define (render-code-block code-lines)
  (define trimmed
    (let* ([fwd (dropf code-lines (lambda (l) (string=? (string-trim l) "")))]
           [rev (dropf (reverse fwd) (lambda (l) (string=? (string-trim l) "")))])
      (reverse rev)))
  (if (null? trimmed)
      ""
      (format "<pre><code class=\"prologos\">~a</code></pre>"
              (string-join (map (lambda (l) (highlight-code-line (html-escape l)))
                                trimmed)
                           "\n"))))

;; ========================================
;; CSS
;; ========================================

(define book-css "
/* ── Light theme (default) ── */
:root, [data-theme='light'] {
  --fg: #2c2c2c; --bg: #fefefe; --accent: #1a6fa8;
  --badge-bg: #e8f4fd; --badge-border: #b8d9f3;
  --code-bg: #f5f5f0; --code-inline-bg: #f0f0ea;
  --border: #ccc; --muted: #666;
  --heading: #333; --heading-muted: #444;
  --nav-border: #eee; --nav-dim: #ccc;
  --title-rule: #888; --section-border: #aaa;
}
/* ── Dark theme ── */
[data-theme='dark'] {
  --fg: #d4d4d4; --bg: #1a1a2e; --accent: #6db3f2;
  --badge-bg: #1e2d3d; --badge-border: #2a4a6b;
  --code-bg: #16162a; --code-inline-bg: #222240;
  --border: #3a3a5c; --muted: #8888a8;
  --heading: #ccc; --heading-muted: #aaa;
  --nav-border: #2a2a48; --nav-dim: #4a4a6a;
  --title-rule: #5a5a7a; --section-border: #5a5a7a;
}
/* Respect OS preference when no explicit toggle */
@media (prefers-color-scheme: dark) {
  :root:not([data-theme='light']) {
    --fg: #d4d4d4; --bg: #1a1a2e; --accent: #6db3f2;
    --badge-bg: #1e2d3d; --badge-border: #2a4a6b;
    --code-bg: #16162a; --code-inline-bg: #222240;
    --border: #3a3a5c; --muted: #8888a8;
    --heading: #ccc; --heading-muted: #aaa;
    --nav-border: #2a2a48; --nav-dim: #4a4a6a;
    --title-rule: #5a5a7a; --section-border: #5a5a7a;
  }
}
* { box-sizing: border-box; }
body {
  font-family: Georgia, 'Times New Roman', serif;
  max-width: 880px; margin: 0 auto; padding: 2rem 1.5rem;
  color: var(--fg); line-height: 1.72; background: var(--bg);
  transition: background .2s, color .2s;
}
h1.chapter-title {
  font-size: 2rem; border-bottom: 3px double var(--title-rule);
  padding-bottom: .5rem; margin-bottom: .3rem;
}
h2.part-header {
  font-size: 1.35rem; border-top: 1px solid var(--border);
  margin-top: 2.5rem; padding-top: 1rem; color: var(--heading-muted);
}
h3.section-title {
  font-size: 1.08rem; color: var(--heading); border-left: 3px solid var(--section-border);
  padding-left: .6rem; margin-top: 1.8rem; margin-bottom: .2rem;
}
.module-container {
  border: 1px solid var(--border); border-radius: 6px;
  padding: .8rem 1.2rem; margin: 1.5rem 0;
}
.module-badge {
  display: inline-block; font-family: 'Menlo','Consolas',monospace;
  font-size: .78rem; background: var(--badge-bg); color: var(--accent);
  border: 1px solid var(--badge-border); border-radius: 3px;
  padding: .1rem .45rem; margin: 0 0 .5rem;
}
pre {
  background: var(--code-bg); border-left: 3px solid var(--border);
  padding: .9rem 1rem; overflow-x: auto; border-radius: 0 4px 4px 0;
  margin: .5rem -1.5rem 1.2rem;
  font-size: .8rem;
}
code { font-family: 'Menlo','Consolas',monospace; font-size: .87rem; }
pre code { background: none; color: var(--fg); }
p code {
  background: var(--code-inline-bg); padding: .1em .3em; border-radius: 2px;
  font-size: .88em;
}
.prose { margin: .5rem 0; }
.prose p { margin: .6rem 0; }
nav.chapter-nav {
  font-size: .9rem; color: var(--muted);
  border-bottom: 1px solid var(--nav-border); padding-bottom: .5rem; margin-bottom: 1.5rem;
  display: flex; align-items: center; gap: .1rem;
}
nav.chapter-nav a { color: var(--accent); text-decoration: none; }
nav.chapter-nav a:hover { text-decoration: underline; }
nav.chapter-nav .sep { margin: 0 .5rem; color: var(--nav-dim); }
nav.chapter-nav .spacer { flex: 1; }
nav.bottom-nav {
  margin-top: 3rem; padding-top: 1rem; border-top: 1px solid var(--nav-border);
  font-size: .9rem; color: var(--muted);
}
nav.bottom-nav a { color: var(--accent); text-decoration: none; }
nav.bottom-nav a:hover { text-decoration: underline; }
.preamble { margin-bottom: 1.5rem; }
/* Theme toggle */
.theme-toggle {
  background: none; border: 1px solid var(--border); border-radius: 4px;
  color: var(--muted); cursor: pointer; font-size: 1rem;
  padding: .15rem .4rem; line-height: 1;
  transition: border-color .2s, color .2s;
}
.theme-toggle:hover { color: var(--accent); border-color: var(--accent); }
/* TOC page */
.toc-part-label {
  font-size: 1.15rem; font-weight: bold; color: var(--heading-muted);
  margin-top: 1.8rem; margin-bottom: .3rem;
}
ol.toc-chapters { margin-top: .2rem; padding-left: 1.5rem; }
ol.toc-chapters li { margin: .3rem 0; }
ol.toc-chapters a { color: var(--accent); text-decoration: none; }
ol.toc-chapters a:hover { text-decoration: underline; }
.toc-modules { font-size: .82rem; color: var(--muted); margin-left: .4rem; }
.book-subtitle { color: var(--muted); font-size: 1rem; margin-top: -.5rem; margin-bottom: 2rem; }
/* ── Syntax highlighting (light) ── */
.hl-kw  { color: #7c4dff; font-weight: 600; }
.hl-ty  { color: #0d7377; }
.hl-str { color: #2e7d32; }
.hl-num { color: #c75000; }
.hl-cmt { color: var(--muted); font-style: italic; }
.hl-kwlit { color: #6f42c1; }
.hl-op  { color: #d63384; }
.hl-br  { color: var(--muted); }
/* ── Syntax highlighting (dark) ── */
[data-theme='dark'] .hl-kw  { color: #c792ea; }
[data-theme='dark'] .hl-ty  { color: #80cbc4; }
[data-theme='dark'] .hl-str { color: #c3e88d; }
[data-theme='dark'] .hl-num { color: #f78c6c; }
[data-theme='dark'] .hl-kwlit { color: #b39ddb; }
[data-theme='dark'] .hl-op  { color: #ff80ab; }
[data-theme='dark'] .hl-br  { color: #888; }
@media (prefers-color-scheme: dark) {
  :root:not([data-theme='light']) .hl-kw  { color: #c792ea; }
  :root:not([data-theme='light']) .hl-ty  { color: #80cbc4; }
  :root:not([data-theme='light']) .hl-str { color: #c3e88d; }
  :root:not([data-theme='light']) .hl-num { color: #f78c6c; }
  :root:not([data-theme='light']) .hl-kwlit { color: #b39ddb; }
  :root:not([data-theme='light']) .hl-op  { color: #ff80ab; }
  :root:not([data-theme='light']) .hl-br  { color: #888; }
}
")

;; Tiny script: toggle dark/light, persist to localStorage
(define theme-js "
<script>
(function(){
  var h=document.documentElement, k='prologos-theme';
  var s=localStorage.getItem(k);
  if(s) h.setAttribute('data-theme',s);
  window.toggleTheme=function(){
    var c=h.getAttribute('data-theme');
    var n;
    if(c==='dark') n='light';
    else if(c==='light') n='dark';
    else n=(matchMedia('(prefers-color-scheme:dark)').matches?'light':'dark');
    h.setAttribute('data-theme',n);
    localStorage.setItem(k,n);
    document.querySelectorAll('.theme-toggle').forEach(function(b){
      b.textContent=n==='dark'?'\\u2600':'\\u263E';
    });
  };
  // Set initial icon
  document.addEventListener('DOMContentLoaded',function(){
    var isDark=s==='dark'||(!s&&matchMedia('(prefers-color-scheme:dark)').matches);
    document.querySelectorAll('.theme-toggle').forEach(function(b){
      b.textContent=isDark?'\\u2600':'\\u263E';
    });
  });
})();
</script>
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
   theme-js
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
  (format "<nav class=\"~a\">~a<span class=\"sep\">|</span><a href=\"index.html\">Table of Contents</a><span class=\"sep\">|</span>~a<span class=\"spacer\"></span><button class=\"theme-toggle\" onclick=\"toggleTheme()\" title=\"Toggle dark/light mode\">&#x263E;</button></nav>\n"
          cls prev-link next-link))

;; ========================================
;; Chapter Page Renderer
;; ========================================

(define (render-chapter-page elements chapter-name prev-name next-name)
  (define out '())
  (define last-module "")
  (define module-open? #f)

  (define (emit! s) (set! out (cons s out)))

  (define (close-module!)
    (when module-open?
      (emit! "</section>\n")
      (set! module-open? #f)))

  (define (open-module! name)
    (close-module!)
    (emit! (format "<section class=\"module-container\">\n<div class=\"module-badge\">~a</div>\n"
                   (html-escape name)))
    (set! module-open? #t)
    (set! last-module name))

  ;; Top nav
  (emit! (nav-bar prev-name next-name))
  (emit! "<article>\n")

  (for ([e (in-list elements)])
    (match e
      [(elem:chapter-title text)
       (emit! (format "<h1 class=\"chapter-title\">~a</h1>\n" (html-escape text)))]

      [(elem:part-header text)
       (close-module!)
       (emit! (format "<h2 class=\"part-header\">~a</h2>\n" (html-escape text)))]

      [(elem:section text)
       (emit! (format "<h3 class=\"section-title\">~a</h3>\n" (html-escape text)))]

      [(elem:module name flags)
       (unless (string=? name last-module)
         (open-module! name))]

      [(elem:prose lines)
       (define rendered (render-prose-lines lines))
       (unless (string=? rendered "")
         (emit! (format "<div class=\"prose\">~a</div>\n" rendered)))]

      [(elem:code lines mod)
       (define rendered (render-code-block lines))
       ;; Open module container if module changed
       (when (and (not (string=? mod "")) (not (string=? mod last-module)))
         (open-module! mod))
       (unless (string=? rendered "")
         (emit! rendered)
         (emit! "\n"))]))

  (close-module!)
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
     "<div style=\"display:flex;align-items:center\"><h1 style=\"flex:1;margin:0\">Prologos Standard Library</h1><button class=\"theme-toggle\" onclick=\"toggleTheme()\" title=\"Toggle dark/light mode\">&#x263E;</button></div>\n"
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
