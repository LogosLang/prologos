# Path Algebra Design Document

**Date**: 2026-03-03
**Status**: Implementation complete (Phases 3d, 3e)
**Scope**: Selection path extensions + general-purpose path expressions

---

## Overview

The path algebra is Prologos's system for navigating and transforming nested data
structures. Originally designed for `selection` declarations (declaring which fields
are accessible), it has been promoted to a general-purpose language feature via
`get-in` and `update-in` expression forms.

## Path Syntax

### Core Grammar (EBNF)

```ebnf
field-path    = ':' , identifier , { '.' , path-segment } ;
path-segment  = identifier
              | '*'                                      (* wildcard *)
              | '**'                                     (* globstar *)
              | '{' , branch , { ' ' , branch } , '}'   (* brace expansion *)
              ;
branch        = identifier , { '.' , path-segment } ;   (* sub-path *)
```

### Path Forms

| Form | Example | Expansion |
|------|---------|-----------|
| Simple | `:name` | `((#:name))` |
| Deep | `:address.zip` | `((#:address #:zip))` |
| Three-level | `:a.b.c` | `((#:a #:b #:c))` |
| Wildcard | `:address.*` | `((#:address *))` |
| Globstar | `:address.**` | `((#:address **))` |
| Brace | `:address.{zip city}` | `((#:address #:zip) (#:address #:city))` |
| Branch sub-path | `:a.{b.c d.e}` | `((#:a #:b #:c) (#:a #:d #:e))` |
| Nested braces | `:a.{b.{c d} e}` | `((#:a #:b #:c) (#:a #:b #:d) (#:a #:e))` |
| Post-brace suffix | `:a.{b c}.**` | `((#:a #:b **) (#:a #:c **))` |
| Cartesian product | `:a.{b c}.{d e}` | 4 paths (cons-dot normalization) |

### Key Design Insight

**Brace items are paths, not just field names.** This single generalization enables:
- Per-branch continuation: `{foo.waz bar.quux}` — each branch navigates differently
- Mixed depth: `{name address.zip age}` — some branches are leaves, some are deep
- Recursive nesting: `{name address.{zip city.{name abbrev}}}` — braces within braces
- Wildcards in branches: `{name address.** settings}` — glob within a branch

---

## Examples by Feature

All examples are shown in both sexp mode and WS (indentation) mode. In WS mode,
path expressions live inside `[...]` brackets, where indentation is ignored and the
`.` / `{...}` path syntax works inline.

### 1. Schema Definitions

Schemas declare named map types with typed fields and optional properties.

**Sexp mode:**
```scheme
(schema Geo
  :lat Int
  :lon Int)

(schema Address
  :street String
  :city   String
  :state  String
  :zip    Int)

(schema User
  :name    String
  :age     Int
  :email   String
  :address Address)

;; Schema with properties
(schema Config
  :host  String :default "localhost"
  :port  Int    :default 8080 :check [pos?]
  :debug Bool   :default false
  :closed)
```

**WS (indentation) mode:**
```prologos
schema Geo
  :lat Int
  :lon Int

schema Address
  :street String
  :city   String
  :state  String
  :zip    Int

schema User
  :name    String
  :age     Int
  :email   String
  :address Address

;; Schema with properties
schema Config
  :host  String :default "localhost"
  :port  Int    :default 8080 :check [pos?]
  :debug Bool   :default false
  :closed
```

**Constructing schema-typed values** (implicit map syntax in WS mode):
```prologos
;; WS mode — indentation-based keyword block desugars to map literal
def home-address
  :street "742 Evergreen Terrace"
  :city   "Springfield"
  :state  "OR"
  :zip    97403

def alice
  :name    "Alice"
  :age     30
  :email   "alice@example.com"
  :address home-address
```

**Sexp equivalent:**
```scheme
(def home-address := {:street "742 Evergreen Terrace" :city "Springfield"
                      :state "OR" :zip 97403})

(def alice := {:name "Alice" :age 30 :email "alice@example.com"
               :address home-address})
```

### 2. Selection Definitions

Selections declare which fields are accessible through a given view of a schema.

**Sexp mode:**
```scheme
;; Only name and email visible
(selection PublicProfile from User
  :requires [:name :email])

;; Deep path: only address.zip (not street/city/state)
(selection ShippingZip from User
  :requires [:address.zip])

;; Branched deep path: address.{zip city} — two fields
(selection ShippingLabel from User
  :requires [:name :address.{zip city state}])

;; Wildcard: all of address
(selection FullAddress from User
  :requires [:name :address.*])

;; Globstar: all descendants of address (same as wildcard for flat schemas,
;; but recurses into nested schemas)
(selection DeepAddress from User
  :requires [:address.**])

;; Composition via :includes
(selection ExtendedProfile from User
  :includes [PublicProfile]
  :requires [:age])
```

**WS (indentation) mode:**
```prologos
;; Only name and email visible
selection PublicProfile from User
  :requires [:name :email]

;; Deep path: only address.zip
selection ShippingZip from User
  :requires [:address.zip]

;; Branched: address.{zip city state}
selection ShippingLabel from User
  :requires [:name :address.{zip city state}]

;; Wildcard: all of address
selection FullAddress from User
  :requires [:name :address.*]

;; Globstar: all descendants
selection DeepAddress from User
  :requires [:address.**]

;; Composition
selection ExtendedProfile from User
  :includes [PublicProfile]
  :requires [:age]
```

**Using selections to restrict access:**
```prologos
;; A function typed with a selection can only access declared fields
spec get-name PublicProfile -> String
defn get-name [u]
  u.name                           ;; OK — :name is in PublicProfile

spec get-age PublicProfile -> Int
defn get-age [u]
  u.age                            ;; ERROR — :age is NOT in PublicProfile

spec get-zip ShippingZip -> Int
defn get-zip [u]
  u.address.zip                    ;; OK — :address.zip is declared

spec get-city ShippingZip -> String
defn get-city [u]
  u.address.city                   ;; ERROR — only :address.zip, not :city
```

### 3. `get-in` — Navigate and Extract

#### Simple paths

**Sexp mode:**
```scheme
;; Single field
(get-in alice :name)               ;; → "Alice"

;; Two-level deep
(get-in alice :address.zip)        ;; → 97403

;; Three-level (with nested schemas)
(get-in response :data.user.name)  ;; → "Alice"
```

**WS mode:**
```prologos
;; Inline in bracket expressions
def name := [get-in alice :name]

def zip := [get-in alice :address.zip]

def deep-name := [get-in response :data.user.name]

;; In a pipe
alice |> [get-in _ :address.zip]
```

#### Branched paths (field projection)

When `get-in` receives a branched path, it projects a subset of fields into a new map.

**Sexp mode:**
```scheme
;; Project two fields from address
(get-in alice :address.{zip city})
;; → {:zip 97403 :city "Springfield"}

;; Mixed depth: some branches are deep, some shallow
(get-in alice :address.{zip city.** state})
;; → {:zip 97403 :city (...all of city...) :state "OR"}

;; Per-branch sub-paths
(get-in alice :{name address.zip})
;; NOTE: :{...} at root level is not valid syntax.
;; For root-level branching, use multiple get-in calls or a selection.
```

**WS mode:**
```prologos
;; Project zip and city from address
def label-info := [get-in alice :address.{zip city}]

;; Use projected map
label-info.zip                     ;; → 97403
label-info.city                    ;; → "Springfield"
```

#### Complex nested paths

**Sexp mode — modeling an API response:**
```scheme
(schema Geo      :lat Int :lon Int)
(schema Location :name String :geo Geo)
(schema Venue    :id Int :location Location :capacity Int)
(schema Event    :title String :venue Venue :attendees Int)

(def concert := {:title "Symphony No. 9"
                 :venue {:id 42
                         :location {:name "Concert Hall"
                                    :geo {:lat 45 :lon -122}}
                         :capacity 2000}
                 :attendees 1500})

;; Deep navigation — four levels
(get-in concert :venue.location.geo.lat)   ;; → 45

;; Branch at the deepest level
(get-in concert :venue.location.geo.{lat lon})
;; → {:lat 45 :lon -122}

;; Branch at intermediate level — mixed depths
(get-in concert :venue.{id location.name capacity})
;; Expands to three paths:
;;   :venue.id              → 42
;;   :venue.location.name   → "Concert Hall"
;;   :venue.capacity        → 2000
;; Result: {:id 42 :name "Concert Hall" :capacity 2000}

;; Nested braces — select within select
(get-in concert :venue.{id location.{name geo.{lat lon}}})
;; Expands to four paths:
;;   :venue.id                   → 42
;;   :venue.location.name        → "Concert Hall"
;;   :venue.location.geo.lat     → 45
;;   :venue.location.geo.lon     → -122
;; Result: {:id 42 :name "Concert Hall" :lat 45 :lon -122}
```

**WS mode equivalent:**
```prologos
schema Geo
  :lat Int
  :lon Int

schema Location
  :name String
  :geo  Geo

schema Venue
  :id       Int
  :location Location
  :capacity Int

schema Event
  :title     String
  :venue     Venue
  :attendees Int

def concert
  :title "Symphony No. 9"
  :venue
    :id 42
    :location
      :name "Concert Hall"
      :geo
        :lat 45
        :lon -122
    :capacity 2000
  :attendees 1500

;; Deep navigation
def lat := [get-in concert :venue.location.geo.lat]

;; Branched projection at depth
def coords := [get-in concert :venue.location.geo.{lat lon}]

;; Mixed-depth branching
def venue-summary := [get-in concert :venue.{id location.name capacity}]

;; Nested braces — select within select
def flat-view := [get-in concert :venue.{id location.{name geo.{lat lon}}}]
```

### 4. `update-in` — Navigate and Transform

`update-in` applies a function at a path leaf and rebuilds the structure above it.

#### Simple updates

**Sexp mode:**
```scheme
;; Increment a nested field
(update-in concert :attendees (fn [n] [add n 1]))

;; Replace a deep value
(update-in concert :venue.location.name (fn [_] "New Venue"))

;; Transform deeply nested field
(update-in concert :venue.capacity (fn [c] [mul c 2]))
```

**WS mode:**
```prologos
;; Increment attendees
def sold-one-more := [update-in concert :attendees (fn [n] [add n 1])]

;; Rename venue
def renamed := [update-in concert :venue.location.name (fn [_] "New Venue")]

;; Double capacity
def expanded := [update-in concert :venue.capacity (fn [c] [mul c 2])]
```

#### Multi-level rebuild

The desugaring shows how `update-in` reconstructs each level:

```scheme
;; (update-in concert :venue.location.geo.lat (fn [x] 0))
;;
;; Desugars to:
;; (map-assoc concert :venue
;;   (map-assoc (map-get concert :venue) :location
;;     (map-assoc (map-get (map-get concert :venue) :location) :geo
;;       (map-assoc (map-get (map-get (map-get concert :venue) :location) :geo) :lat
;;         ((fn [x] 0) (map-get (map-get (map-get (map-get concert :venue) :location) :geo) :lat))))))
;;
;; Each level: get the current sub-value, recurse, wrap in map-assoc to rebuild.
;; At the leaf: apply the function to the current value.
```

#### Composition: `get-in` after `update-in`

```scheme
;; Verify the update took effect
(get-in
  (update-in concert :venue.location.geo.lat (fn [_] 0))
  :venue.location.geo.lat)
;; → 0

;; Chain multiple updates
(get-in
  (update-in
    (update-in concert :venue.capacity (fn [c] [mul c 2]))
    :attendees (fn [a] [add a 100]))
  :venue.capacity)
;; → 4000
```

**WS mode:**
```prologos
;; Verify update
def zeroed-lat
  [get-in
    [update-in concert :venue.location.geo.lat (fn [_] 0)]
    :venue.location.geo.lat]
;; → 0

;; Chain updates and extract
def new-capacity
  [get-in
    [update-in
      [update-in concert :venue.capacity (fn [c] [mul c 2])]
      :attendees (fn [a] [add a 100])]
    :venue.capacity]
;; → 4000
```

#### Error: branched `update-in` is rejected

```scheme
;; Branched paths in update-in are a static error.
;; Which branch should the function apply to? Ambiguous.
(update-in concert :venue.{capacity attendees} inc)
;; ERROR: "update-in requires exactly one path (no branching)"
```

### 5. Selections with Path Algebra

Selections use the full path algebra to declare fine-grained access policies.

#### Real-world API scenario

**Sexp mode:**
```scheme
(schema GeoPoint :lat Int :lon Int)
(schema Address  :street String :city String :state String :zip Int :geo GeoPoint)
(schema Profile  :bio String :avatar String :website String)
(schema Account  :id Int :name String :email String :address Address :profile Profile)

;; Public API: only name and profile.{bio avatar}
(selection PublicAPI from Account
  :requires [:name :profile.{bio avatar}])
;; Accessible: name, profile.bio, profile.avatar
;; Blocked:    id, email, address.*, profile.website

;; Shipping: name + address minus geo
(selection ShippingInfo from Account
  :requires [:name :address.{street city state zip}])
;; Accessible: name, address.street, address.city, address.state, address.zip
;; Blocked:    id, email, profile.*, address.geo

;; Admin: everything
(selection AdminView from Account
  :requires [:*])
;; Or equivalently: :requires [:**]

;; Geo-only: just the coordinates
(selection GeoOnly from Account
  :requires [:address.geo.{lat lon}])
;; Accessible: address.geo.lat, address.geo.lon
;; Blocked:    everything else

;; Composed: shipping + public
(selection CustomerFacing from Account
  :includes [ShippingInfo PublicAPI])
;; Union of both — name, address.{street city state zip}, profile.{bio avatar}
```

**WS mode:**
```prologos
schema GeoPoint
  :lat Int
  :lon Int

schema Address
  :street String
  :city   String
  :state  String
  :zip    Int
  :geo    GeoPoint

schema Profile
  :bio     String
  :avatar  String
  :website String

schema Account
  :id      Int
  :name    String
  :email   String
  :address Address
  :profile Profile

;; Public API
selection PublicAPI from Account
  :requires [:name :profile.{bio avatar}]

;; Shipping
selection ShippingInfo from Account
  :requires [:name :address.{street city state zip}]

;; Admin
selection AdminView from Account
  :requires [:*]

;; Geo-only
selection GeoOnly from Account
  :requires [:address.geo.{lat lon}]

;; Composed
selection CustomerFacing from Account
  :includes [ShippingInfo PublicAPI]
```

**Functions constrained by selections:**
```prologos
;; A handler that can only see public data
spec render-profile PublicAPI -> String
defn render-profile [account]
  ;; account.name           OK
  ;; account.profile.bio    OK
  ;; account.profile.avatar OK
  ;; account.email          BLOCKED — not in PublicAPI
  ;; account.address.zip    BLOCKED — not in PublicAPI
  [string-append account.name ": " account.profile.bio]

;; A handler that can only see shipping data
spec format-label ShippingInfo -> String
defn format-label [account]
  [string-append
    account.name "\n"
    account.address.street "\n"
    account.address.city ", " account.address.state " "
    [int-to-string account.address.zip]]
```

### 6. Path Algebra Interaction with Dot-Access

Prologos has two complementary systems for field access:

| System | Syntax | Use case |
|--------|--------|----------|
| Dot-access | `user.name`, `user.address.zip` | Point access at use site |
| Path algebra | `:address.{zip city}` | Declarative paths in selections, bulk navigation |
| `get-in` | `(get-in user :address.zip)` | Programmatic path-based access |
| `update-in` | `(update-in user :address.zip f)` | Programmatic path-based update |

They compose naturally:

```prologos
;; Dot-access on get-in result
[get-in concert :venue.location].name        ;; → "Concert Hall"

;; get-in to project, then dot-access on the projection
def coords := [get-in concert :venue.location.geo.{lat lon}]
coords.lat                                   ;; → 45
coords.lon                                   ;; → -122

;; update-in then dot-access
[update-in concert :venue.capacity (fn [c] [mul c 2])].venue.capacity
;; → 4000
```

### 7. Wildcard and Globstar Semantics

```scheme
;; * (wildcard): all immediate fields — equivalent to listing every field
(selection AllAddress from User
  :requires [:address.*])
;; Same as: :requires [:address.{street city state zip geo}]
;; But doesn't require knowing the field names — forward-compatible.

;; ** (globstar): all fields at all depths — recursive
(selection EverythingUnder from User
  :requires [:address.**])
;; Includes: address.street, address.city, ..., address.geo.lat, address.geo.lon
;; Recurses into nested schemas.

;; Globstar in branches
(selection Mixed from User
  :requires [:name :address.{geo.** zip}])
;; Includes: name, address.geo.lat, address.geo.lon, address.zip
;; Blocks:   address.street, address.city, address.state

;; Post-brace globstar
(selection EverythingDeep from Account
  :requires [:address.{street city}.**])
;; Appends ** to each branch: address.street.**, address.city.**
;; (For leaf fields like String, ** is a no-op. For nested schemas, it recurses.)
```

---

## Architecture

### Parser (`parser.rkt`)

The path algebra parser is shared between `selection` declarations and `get-in`/`update-in`
expressions. The core function `validate-selection-paths` handles all path parsing:

- **`parse-path-string`**: Splits dotted strings on `.`, converts segments to keywords/wildcards
- **`expand-brace-branches`**: Handles brace expansion with sub-paths and nested braces
- **`consume-post-brace-continuation`**: Detects and appends post-brace suffixes
- **`normalize-cons-dot-braces`**: Repairs cons-dot garbling from Racket's `.{` reader

### Elaborator (`elaborator.rkt`)

Pure desugaring — no new AST nodes emitted downstream:

- `surf-get-in` → chains of `expr-map-get` (single path) or `expr-map-empty`/`expr-map-assoc` (branched)
- `surf-update-in` → nested `expr-map-get`/`expr-map-assoc` with `expr-app` at leaf
- Keyword conversion: path segments are Racket keywords (`#:zip`); `expr-keyword` takes symbols (`'zip`)

### Type Checking

No new type checking code needed. Since `get-in`/`update-in` desugar to existing
`map-get`/`map-assoc` operations, the existing type checker handles them automatically.

### WS Mode (Deferred)

In sexp mode, `:address.{zip city}` tokenizes as `:address.` + `($brace-params zip city)`.
In WS mode, `.{` is the `dot-lbrace` token for mixfix expressions (e.g. `.{a + b * c}`).
The disambiguation is deferred; sexp mode is the canonical surface for complex paths, and
WS mode uses `[...]` brackets around path expressions where the sexp tokenizer applies.
See DEFERRED.md.

---

## Prior Art

| System | Comparison |
|--------|------------|
| **Clojure** `get-in`/`update-in`/`assoc-in` | Same concept, vector-of-keys instead of path syntax, no brace expansion |
| **Specter** (Clojure) | Composable navigators for nested transforms — more powerful but heavier API |
| **Lenses** (Haskell) | Get/set/modify with composable optics — theoretically elegant, operationally similar |
| **GraphQL** | Field selection with nested projections — `selection` declarations directly inspired by this |
| **jq** | Path expressions for JSON — wildcards (`.[]`) and recursive descent (`..`) similar to `*`/`**` |
| **XPath** | XML navigation — `/foo/bar`, `//bar` (recursive), `foo/*` (wildcard) — similar concepts |
| **CSS Selectors** | `.class > .child`, `.parent .descendant` — structural navigation in a tree |
| **JSONPath** | `$.store.book[*].author`, `$..author` — direct analogy to `:store.book.*.author` |

Prologos's path algebra is unique in combining:
1. Brace expansion with per-branch sub-paths (no prior art for this)
2. Integration with a type system (selections enforce path-based access control)
3. Desugaring to first-class language operations (not a separate query language)

---

## Sexp Tokenization Details

Understanding how Racket's sexp reader tokenizes path syntax is critical:

| Input | Sexp tokens |
|-------|-------------|
| `:address.zip` | Symbol `:address.zip` (one token) |
| `:address.{zip city}` | `:address.` + `($brace-params zip city)` |
| `:a.{b.{c d} e}` | `:a.` + `($brace-params b. ($brace-params c d) e)` |
| `[:a.{b c}.{d e}]` | `(:a. ($brace-params b c) $brace-params d e)` (cons-dot!) |

The cons-dot issue occurs because `.{...}` at the tail of a bracket list triggers Racket's
cons-dot reader. The `normalize-cons-dot-braces` pass detects the bare `$brace-params` symbol
and re-wraps it.

---

## Test Coverage

- **56 tests** in `test-selection-paths.rkt` — parser + E2E selection path tests
- **20 tests** in `test-path-expressions.rkt` — parser + E2E get-in/update-in tests

## Commits

| Phase | Description | Commit |
|-------|-------------|--------|
| 3d-a | Branch items as sub-paths | `1d342a9` |
| 3d-b | Nested braces inside branches | `b288922` |
| 3d-c | Uniform post-brace continuation | `91528fe` |
| 3d-d | Cons-dot normalization | `5b4d4dc` |
| 3d-e | E2E pipeline tests | `994d9fb` |
| 3e-a | AST nodes and parsing | `32993ad` |
| 3e-b/c | Elaboration (get-in + update-in) | `f5749c8` |
| 3e-f | Path expression tests | `93af4bc` |
| 3f | Design doc + grammar | `3c2f730` |
