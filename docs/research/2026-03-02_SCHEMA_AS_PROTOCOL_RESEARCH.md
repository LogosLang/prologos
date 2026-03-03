# Schema as Protocol: GraphQL and the Schema-Session Interaction

**Supplementary Research Document to Schema Type Design Research**
**Date**: 2026-03-02
**Phase**: 1 (Deep Research) — Design Methodology
**Focus**: How schema mediates between subsystems, with GraphQL as the primary case study

---

## 1. Motivation

The first research document surveyed 10 schema/validation systems and identified three orthogonal concerns: shape, presence requirements, and openness. This supplementary document explores a fourth dimension that becomes critical when schema interacts with Prologos's three co-equal languages:

> **Schema is the object (sub)language usable by all three co-equal paradigms: Functional (`defn`), Relational (`defr`), and Process/Session (`defproc`).**

The question is: **what can we learn from GraphQL**, which is perhaps the most successful real-world system where a schema language mediates between producers and consumers across a protocol boundary?

---

## 2. GraphQL: Schema as Protocol Contract

### 2.1 The Three Layers

GraphQL has three distinct layers that map remarkably well to Prologos's specification triple:

| GraphQL | Purpose | Prologos Analog |
|---|---|---|
| **Schema (SDL)** | Defines the shape of all possible data | `schema` |
| **Query/Selection** | Specifies which fields are needed in context | `selection` / `require` |
| **Operation (Query/Mutation/Subscription)** | Defines what the interaction *does* | `session` / `defproc` |

This is not coincidental. Both systems face the same fundamental challenge: how do you describe data shapes that flow through typed communication protocols?

### 2.2 GraphQL Schema Definition Language (SDL)

GraphQL's SDL defines types, fields, and relationships:

```graphql
type User {
  id: ID!
  name: String!
  email: String
  address: Address
  posts: [Post!]!
}

type Address {
  street: String!
  city: String!
  state: String
  zip: String!
}

type Post {
  id: ID!
  title: String!
  body: String!
  author: User!
}
```

**Key design decisions:**
- **Nullable by default for outputs** — resilience and evolution trump strictness
- **Required by default for inputs** — explicit intent at boundaries
- **No optionality on the schema itself** — the query decides what's needed
- **Interfaces and Unions** for polymorphic shapes

### 2.3 Query as Selection

A GraphQL query is a *selection over the schema* — the client specifies exactly which fields it needs:

```graphql
query GetMovieTimes($userId: ID!) {
  user(id: $userId) {
    id
    address {
      zip
    }
  }
}

query PlaceOrder($userId: ID!) {
  user(id: $userId) {
    name
    email
    address {
      street
      city
      state
      zip
    }
  }
}
```

This is *exactly* Hickey's schema/select separation:
- The `User` type defines what CAN exist (shape)
- Each query selects what's NEEDED in context (requirements)
- The schema itself has no notion of "optional" vs "required" — that's determined by the consumer

### 2.4 The Input/Output Type Asymmetry

GraphQL enforces a fundamental separation between types used for *sending data in* versus types used for *receiving data out*:

```graphql
# Output type — what the server returns
type User {
  id: ID!
  name: String!
  email: String
  createdAt: DateTime!
}

# Input type — what the client sends
input CreateUserInput {
  name: String!
  email: String!
}

input UpdateUserInput {
  name: String
  email: String
}
```

**Why this separation exists:**
- Output types can have circular references (User -> Post -> User)
- Input types cannot (they must form a DAG)
- Output types support interfaces and unions
- Input types are simpler — pure data, no computed fields
- The same conceptual entity (`User`) has different shapes in different directions

**Prologos implication**: This maps directly to the `require`/`provide` distinction from the earlier conversation. A `session` that receives a `User` may need different fields than one that sends a `User`. The type system should distinguish *what I require from you* from *what I provide to you*.

### 2.5 Nullability: The Evolution-Safety Valve

GraphQL's nullability defaults are deliberately asymmetric:

| Position | Default | Rationale |
|---|---|---|
| **Output fields** | Nullable | A field that was non-null can't become nullable without breaking clients. Start nullable, tighten later. |
| **Input arguments** | Required | An input that was optional can't become required without breaking clients. Start required, relax later. |

This is the Proto3 lesson ("all fields optional for evolution safety") applied with nuance: **the direction of compatibility depends on whether you're producing or consuming**.

- **For outputs**: nullable → non-null is safe (clients that handled null still work)
- **For inputs**: required → optional is safe (clients that provided the field still work)
- The opposite directions are breaking changes

**Prologos implication**: When a schema crosses a session boundary, the direction of the channel determines which nullability/optionality semantics apply. On a `send`, the sender provides and the requirements can only *relax* over time. On a `recv`, the receiver requires and the requirements can only *tighten* over time. This is variance in action — and it maps perfectly to session type duality.

---

## 3. GraphQL Operations as Session Types

### 3.1 Query/Mutation = Degenerate Session

A GraphQL query or mutation is a *single-step session*:

```
Client → Server: { query, variables }   (send)
Server → Client: { data, errors }       (recv)
end
```

In Prologos session type notation:

```prologos
;; A GraphQL query is:
session GraphQLQuery
  ! request : QueryRequest     ;; client sends query + variables
  ? response : QueryResponse   ;; server responds with data
  end
```

This is the simplest possible session — one send, one receive, done. But GraphQL builds richer protocols on top of this primitive.

### 3.2 Subscription = Ongoing Session

GraphQL subscriptions are genuinely session-typed communication. The `graphql-transport-ws` protocol defines this message exchange:

```
Client → Server: ConnectionInit { payload }
Server → Client: ConnectionAck { payload }
— connection established —

Client → Server: Subscribe { id, payload: { query, variables } }
Server → Client: Next { id, payload: ExecutionResult }    (repeated)
Server → Client: Next { id, payload: ExecutionResult }
...
Client → Server: Complete { id }    — OR —
Server → Client: Complete { id }
Server → Client: Error { id, payload: [GraphQLError] }
```

As a Prologos session type:

```prologos
session GraphQLSubscription
  ! init : ConnectionPayload
  ? ack : ConnectionPayload
  rec Loop
    &>                                ;; external choice (client decides)
      | :subscribe
          ! sub : SubscribePayload    ;; client subscribes
          rec Stream
            +>                        ;; internal choice (server decides)
              | :next
                  ? data : ExecutionResult
                  Stream              ;; continue streaming
              | :complete
                  end                 ;; server ends stream
              | :error
                  ? err : [GraphQLError]
                  end                 ;; server errors
      | :ping
          ! ping : PingPayload
          ? pong : PongPayload
          Loop
      | :complete
          end                         ;; client closes
```

**Key insight**: The graphql-ws protocol IS a session type, written informally in a protocol specification document. Prologos makes this formal.

### 3.3 Fragments = Reusable Selections

GraphQL fragments define reusable "shapes" that can be included in multiple queries:

```graphql
fragment UserBasic on User {
  id
  name
}

fragment UserFull on User {
  ...UserBasic
  email
  address {
    street
    city
    state
    zip
  }
}

query GetUser($id: ID!) {
  user(id: $id) {
    ...UserFull
  }
}
```

**Prologos mapping**: Fragments are named selections that compose:

```prologos
selection UserBasic from User
  require id
  require name

selection UserFull from User
  include UserBasic
  require email
  require address { * }
```

The composition algebra is: `include` = set union of required fields. This is clean and predictable.

### 3.4 Interfaces and Unions = Schema Polymorphism

GraphQL supports polymorphic shapes:

```graphql
interface Node {
  id: ID!
}

type User implements Node {
  id: ID!
  name: String!
}

type Post implements Node {
  id: ID!
  title: String!
}

union SearchResult = User | Post
```

With *type conditions* in queries:

```graphql
query Search($query: String!) {
  search(query: $query) {
    ... on User { name }
    ... on Post { title }
  }
}
```

**Prologos mapping**: This interacts with both traits and union types:

```prologos
;; Interface analog: trait with schema constraint
trait Identifiable
  spec id : Self -> Id

;; Union analog: already have union types
type SearchResult := User | Post

;; Selection with type conditions
selection SearchDisplay from SearchResult
  on User: require name
  on Post: require title
```

---

## 4. Schema Evolution and Session Type Duality

### 4.1 The Evolution Principle

GraphQL's core evolution strategy: **additive changes only, deprecation for removal**. This is why GraphQL APIs are "versionless" — new fields, types, and arguments are added; old ones are marked `@deprecated` and eventually removed after monitoring shows zero usage.

```graphql
type User {
  id: ID!
  name: String! @deprecated(reason: "Use firstName and lastName")
  firstName: String!
  lastName: String!
}
```

**The covariance/contravariance principle**:
- Output fields: can add new fields (covariant — more data is safe)
- Input fields: can add optional fields (contravariant — fewer requirements is safe)
- Breaking: removing output fields, adding required input fields

### 4.2 Mapping to Session Types

In Prologos, session type duality means:
- `send A . S` is dual to `recv A . S`
- What one endpoint sends, the other receives

When a schema flows over a session channel, evolution safety depends on direction:

```prologos
session EmployeeService
  ? request : EmployeeQuery        ;; Client sends (input)
  ! response : Employee            ;; Server sends (output)
  end

;; Server-side evolution:
;; - Adding a field to Employee (response) is SAFE
;;   (client ignores what it doesn't select)
;; - Adding a required field to EmployeeQuery is BREAKING
;;   (existing clients don't provide it)
;; - Adding an optional field to EmployeeQuery is SAFE
;;   (existing clients work, new clients can use it)
```

**This is exactly GraphQL's nullability asymmetry, but expressed through session type duality.** The direction of the channel determines which changes are compatible:

| Channel Direction | Safe Addition | Breaking Addition |
|---|---|---|
| `send` (you provide) | New field with default | New required field |
| `recv` (you consume) | New optional field | Removing a field you used |

### 4.3 Open Schemas at Boundaries, Closed Schemas at Validation

GraphQL's schema is intrinsically open — adding fields never breaks existing queries because clients only receive the fields they selected. This suggests:

> **Schemas should be open at protocol boundaries (for evolution) and closed at validation boundaries (for correctness).**

In Prologos:

```prologos
;; Open schema: for protocol boundaries (session types)
schema Employee
  :name   String
  :dept   Department
  :salary Int

;; New version adds a field — existing sessions still work
schema Employee       ;; v2
  :name   String
  :dept   Department
  :salary Int
  :email  String      ;; new field

;; Closed variant: for local validation
schema Config :closed
  :host  String
  :port  Int
;; Extra keys rejected — correct for configuration parsing
```

---

## 5. GraphQL Federation and Multi-Service Schemas

### 5.1 The Composition Problem

Real systems have schemas that span multiple services. GraphQL Federation solves this by letting each service own part of the schema:

```graphql
# Users service
type User @key(fields: "id") {
  id: ID!
  name: String!
}

# Posts service
extend type User @key(fields: "id") {
  id: ID! @external
  posts: [Post!]!
}

type Post @key(fields: "id") {
  id: ID!
  title: String!
  author: User!
}
```

A gateway composes these into a unified "supergraph." Each service declares which types it owns (`@key`) and which it extends.

### 5.2 Prologos Multi-Process Schema Coordination

In Prologos, multiple `defproc`s may need to share schema definitions. The current module system handles this naturally — schemas defined in library modules are importable. But session types add a constraint: when two processes communicate, they must agree on the schema that flows between them.

```prologos
;; Shared schema (in a library module)
ns prologos.data.employee
schema Employee
  :name   String
  :dept   Department
  :salary Int

;; Service A: creates employees
ns service.hr
use prologos.data.employee

session HRProtocol
  ? request : Employee
  ! id : EmployeeId
  end

defproc hr-service : HRProtocol
  recv self req : Employee
    let id := [create-employee req]
    send id self
      stop

;; Service B: queries employees
ns service.directory
use prologos.data.employee

session DirectoryProtocol
  ? query : DeptQuery
  ! results : [List Employee]
  end
```

The schema acts as the *contract* — both services import the same `Employee` schema, ensuring type-safe communication. This is exactly Federation's @key pattern, but enforced by the type system rather than a gateway runtime.

---

## 6. The Relay Connection Pattern: Protocol Over Schema

### 6.1 Cursor Connections as Protocol

The Relay Connection specification imposes a protocol structure on top of GraphQL for pagination:

```graphql
type UserConnection {
  edges: [UserEdge!]!
  pageInfo: PageInfo!
}

type UserEdge {
  node: User!
  cursor: String!
}

type PageInfo {
  hasNextPage: Boolean!
  hasPreviousPage: Boolean!
  startCursor: String
  endCursor: String
}

type Query {
  users(first: Int, after: String, last: Int, before: String): UserConnection!
}
```

This is **a session type hiding in a schema**. The pagination protocol is:

```prologos
;; The Relay Connection pattern as a session type
session PaginatedQuery {A}
  ! query : PaginationArgs         ;; first/after or last/before
  ? page : Connection A            ;; edges + pageInfo
  rec Paginate
    +>                             ;; client decides
      | :next-page
          ! cursor : String
          ? page : Connection A
          Paginate
      | :done
          end
```

**Key insight**: GraphQL encodes what should be a *sequential protocol* into a *single request-response schema*. The Connection type is an encoding of "there might be more data; here's how to get it." In a language with real session types, this becomes an explicit typed protocol.

### 6.2 The Encoding Problem

GraphQL must encode protocols into schemas because it has no built-in protocol primitive. Everything is either a query (request-response), mutation (request-response with side effects), or subscription (server push). Complex multi-step protocols are encoded as sequences of queries/mutations.

Prologos doesn't have this limitation. With first-class session types, protocols are expressed directly:

```prologos
;; GraphQL: encodes state machine into schema
;; Prologos: expresses state machine as session type

session OrderWorkflow
  ? order : OrderRequest
  ! quote : Quote
  &>
    | :accept
        ? payment : PaymentInfo
        +>
          | :approved
              ! confirmation : Confirmation
              end
          | :declined
              ! error : PaymentError
              end
    | :reject
        end
    | :modify
        ? changes : OrderModification
        ! revised-quote : Quote
        ;; ... continues
```

This can't be expressed as a single GraphQL schema — it would require multiple mutations with client-side state management. Session types make the protocol structure explicit and type-checked.

---

## 7. Comparison: Schema-as-Protocol Approaches

### 7.1 Taxonomy

| System | Schema Language | Protocol Primitive | Selection Mechanism | Type Safety |
|---|---|---|---|---|
| **GraphQL** | SDL types | Query/Mutation/Subscription | Field selection in query | Runtime (schema validation) |
| **gRPC/Protobuf** | `.proto` messages | `service`/`rpc` | None (send entire message) | Compile-time (codegen) |
| **tRPC** | TypeScript types | Procedure calls | None (TypeScript inference) | Compile-time (type sharing) |
| **Prologos** | `schema` | `session`/`defproc` | `selection`/`require` | Compile-time (dependent types) |

### 7.2 What Prologos Unifies

Prologos is unique in combining:

1. **First-class schema** (like GraphQL SDL, but as a type)
2. **First-class selection** (like GraphQL queries, but as a refinement type)
3. **First-class session types** (like gRPC services, but with duality and linearity)
4. **Dependent types** (schema shape can depend on values)
5. **Logic programming** (schemas as relations, selections as constraints)

No existing system has all five. GraphQL has 1+2+partial-3. gRPC has 1+3. tRPC has compile-time safety but no schema language or protocol types. Prologos can have them all.

### 7.3 The CUE Connection

CUE language deserves special mention. CUE unifies types and values into a single concept — a type IS a constraint, a value IS a fully-specified constraint. Unification is the core operation: combining two CUE values produces a new value satisfying both constraints, or an error if they conflict.

```cue
// CUE: types and values unify
#User: {
    name:  string
    email: string
    age:   int & >0 & <150
}

// A value is just a more-constrained type
alice: #User & {
    name:  "Alice"
    email: "alice@example.com"
    age:   30
}
```

**Prologos implication**: CUE's insight that "types and values live on the same lattice" resonates with Prologos's dependent type system, where types can depend on values. A schema with a `:check [> _ 0]` constraint is exactly this — a type that is also a constraint. The logic programming side of Prologos (where types are first-class values that can be unified) makes this natural.

---

## 8. Row Polymorphism: The Theoretical Foundation

### 8.1 Open vs. Closed Records in Type Theory

Row polymorphism provides the theoretical foundation for the open/closed distinction. In a row-polymorphic type system:

```
// Open record: has at least these fields
{ name : String, age : Int | r }    -- 'r' is the row variable (extra fields)

// Closed record: has exactly these fields
{ name : String, age : Int }        -- no row variable
```

A function that takes an open record can accept any record with *at least* the specified fields:

```
getName : { name : String | r } -> String
getName rec = rec.name

-- Works with User, Employee, any record with .name
```

**This is exactly GraphQL's field selection at the type level.** A GraphQL query `{ user { name } }` says "I need a type with at least a `name` field" — this is an open record type `{ name : String | r }`.

### 8.2 Prologos Design Choice

For Prologos schemas, row polymorphism provides the mechanism for open schemas:

```prologos
;; Open schema (default): has a row variable
schema User
  :name  String
  :email String
;; Type: { :name String, :email String | r }

;; Closed schema: no row variable
schema Config :closed
  :host String
  :port Int
;; Type: { :host String, :port Int }

;; Selection narrows the row variable
selection UserBasic from User
  require name
;; Type: { :name String | r }  (keeps the row variable, drops email from "required")
```

Row polymorphism gives us:
- **Open schemas** = record types with row variable
- **Closed schemas** = record types without row variable
- **Schema extension** (`:extends`) = row concatenation
- **Selection** = row restriction (keep some fields, leave others in the row variable)

### 8.3 Academic Foundation

Key references for the type-theoretic foundations:
- Wand (1987): Original row polymorphism for record types
- Remy (1989): Typing record concatenation
- Morris & McKinna (2019): "Rows by Any Other Name" — generalizes row types to row theories, handling varying notions of extension
- Harper & Pierce (1991): Record calculus with subtyping
- Cardelli (1988): Extensible records in a pure calculus of subtyping

The STScript work (Angiuli et al., 2021) on "Communication-Safe Web Programming in TypeScript with Routed Multiparty Session Types" is directly relevant — it generates typed APIs from session type specifications, ensuring web clients communicate safely with servers.

---

## 9. The `&` Operator: Schema Meets Selection Meets Session

### 9.1 The Unified Notation

The existing Prologos design conversation proposed `User & MovieTimesReq` as "a User with the MovieTimesReq selection applied." This notation beautifully unifies:

```prologos
;; Schema: what CAN exist
schema User
  id : UserId
  name : String
  email : Email
  address : Address

;; Selection: what MUST exist in context
selection MovieTimesReq from User
  require id
  require address { zip }

;; Session: how it flows
session MovieService
  ? req : User & MovieTimesReq      ;; client sends User with at least id, address.zip
  ! times : List MovieTime          ;; server responds
  end

;; Function: how it's consumed
spec get-times : User & MovieTimesReq -> List MovieTime
defn get-times [user]
  lookup-times user.address.zip     ;; type-safe: zip is guaranteed present
```

### 9.2 Type-Theoretic Reading

`User & MovieTimesReq` is a *refinement type*:

```
User & MovieTimesReq ≡ Σ (u : User) . HasKeys u #{:id, :address.zip}
```

Where `HasKeys` is a type-level predicate ensuring the specified keys are present. This is:
- **Structurally**: an intersection of the User type with the MovieTimesReq constraint
- **Operationally**: the User type, checked at construction to have the required keys
- **In row terms**: `{ :id UserId, :address { :zip ZipCode | s } | r }` — an open record with at least id and address.zip

### 9.3 Variance and Session Duality

When `User & Selection` appears in a session type, the direction determines variance:

```prologos
session UserService
  ? input : User & InputSelection     ;; CONTRAVARIANT: caller provides, service requires
  ! output : User & OutputSelection   ;; COVARIANT: service provides, caller receives
  end

;; Evolution:
;; - InputSelection can RELAX (remove requirements) — callers still satisfy
;; - OutputSelection can STRENGTHEN (add provisions) — callers ignore extras
;; This is exactly GraphQL's input/output asymmetry!
```

---

## 10. Lessons for Prologos Schema Design

### 10.1 From GraphQL

| GraphQL Lesson | Prologos Application |
|---|---|
| Schema is the contract between producer and consumer | `schema` mediates between `defproc` endpoints |
| Queries select over schemas (not schemas declaring optionality) | `selection`/`require` separate from `schema` |
| Input types ≠ Output types | `require` (what I need from you) ≠ `provide` (what I give you) |
| Nullable-by-default for outputs (evolution safety) | Open schemas at session boundaries |
| Required-by-default for inputs (explicit intent) | Closed validation at function boundaries |
| Fragments = reusable selections | Named `selection` with `include` composition |
| No versioning — additive evolution only | Schema extension via `:extends`, never breaking removal |
| Federation = multi-service schema ownership | Module system + shared schema types |
| Subscriptions ≈ ongoing typed channels | First-class `session` types (already designed!) |
| Connection pattern = encoded protocol | Explicit `session` types (no encoding needed) |

### 10.2 From the Protocol-Comparison Landscape

| System | Key Lesson |
|---|---|
| **gRPC** | `service` blocks with `rpc` methods are session types with only single-step interactions. Prologos sessions generalize this to multi-step. |
| **tRPC** | When types ARE the protocol (no separate SDL), there's zero impedance mismatch. Prologos's dependent types make schemas-as-types similarly direct. |
| **CUE** | Types and values on the same lattice; constraints compose via unification. Prologos's logic programming side naturally supports this (types as first-class values). |
| **Row polymorphism** | The theoretical foundation for open/closed records. Gives precise type-theoretic semantics to schema openness. |
| **STScript** | Academic proof that session types can generate type-safe web APIs. Validates Prologos's approach of session types for protocol correctness. |

### 10.3 The Central Insight for Prologos

> **Schema is the lingua franca that all three Prologos sub-languages speak.**

- **Functional**: `spec f : Employee -> Result` — schema as function parameter type
- **Relational**: `defr employee : Employee` — schema as relation column types
- **Process**: `session S = ? Employee . ! Confirmation . end` — schema as message shape

And in each context, the schema serves a different role:

| Context | Schema Role | Openness | Selection |
|---|---|---|---|
| **Function parameter** | Input validation | Can be closed | `require` specifies what's needed |
| **Function return** | Output guarantee | Should be open | `provide` specifies what's guaranteed |
| **Relation fact** | Column types | Closed (positional) | All fields present (fact = complete row) |
| **Session send** | Message shape | Open (evolution safe) | Provider determines what to send |
| **Session recv** | Message validation | Open (evolution safe) | Receiver selects what to use |
| **Schema constructor** | Object creation | User choice | All required fields + defaults |

---

## 11. Open Questions (Carried Forward)

### From the GraphQL comparison:

1. **Should schemas have a `@deprecated` analog?** GraphQL's deprecation directive enables evolution. Should Prologos schemas support marking fields as deprecated for tooling warnings?

2. **Should selections be expressible inline?** GraphQL queries select inline. The existing Prologos design proposed both named selections and inline syntax: `defn f [u : User { id, address { zip } }]`. How does inline selection interact with the session type syntax?

3. **How do dependent schemas interact with sessions?** If a session type depends on a value (dependent session type), and the message shape also depends on a value, can we combine both? `session S = ? (n : Nat) . ! (Vec String n) . end` — this sends a number, then sends a vector of exactly that length.

4. **Resolver pattern**: In GraphQL, each field has a resolver function. Should Prologos schema fields support computed values (derived from other fields via a function)?

5. **Introspection**: GraphQL schemas are introspectable at runtime. Should Prologos schemas be first-class values that can be inspected, queried, and manipulated programmatically? (Yes — this follows from homoiconicity and code-as-data.)

### Refinements to the main research document:

6. **Approach B/D synthesis**: The user prefers leaning toward Approach B (schema + select separation) over Approach D (layered schema with key properties). The GraphQL comparison supports this — GraphQL keeps the schema clean and puts all selection in the query. But Approach B needs ergonomic inline syntax for the simple case.

7. **`require` vs `select` naming**: Given that `require` is already used for module imports, and GraphQL's precedent is "query" (selection), consider `select` or `selection` as the keyword for contextual requirements.

---

## 12. Bibliography

### GraphQL

- [GraphQL Schema and Types](https://graphql.org/learn/schema/) — Official learning guide
- [GraphQL Queries and Fields](https://graphql.org/learn/queries/) — Selection semantics
- [GraphQL Schema Design](https://graphql.org/learn/schema-design/) — Evolution best practices
- [GraphQL October 2021 Specification](https://spec.graphql.org/October2021/) — Formal spec
- [Using Nullability in GraphQL — Apollo Blog](https://www.apollographql.com/blog/using-nullability-in-graphql) — Nullability design rationale
- [GraphQL Nullability — Yelp Guidelines](https://yelp.github.io/graphql-guidelines/nullability.html) — Practical nullability guidance
- [Why GraphQL Distinguishes Input and Output Types — Spec Discussion #1038](https://github.com/graphql/graphql-spec/discussions/1038)
- [Input & Output Type Definition PR #462 — Lee Byron](https://github.com/graphql/graphql-spec/pull/462/files)
- [GraphQL Schema Deprecations — Apollo Docs](https://www.apollographql.com/docs/graphos/schema-design/guides/deprecations)
- [GraphQL Nullability Working Group — Semantic Nullability Discussion #58](https://github.com/graphql/nullability-wg/discussions/58)

### GraphQL Subscriptions and WebSocket Protocol

- [GraphQL Subscriptions](https://graphql.org/learn/subscriptions/) — Official guide
- [graphql-ws Protocol Specification](https://github.com/enisdenjo/graphql-ws/blob/master/PROTOCOL.md) — Full message exchange protocol
- [subscriptions-transport-ws Protocol](https://github.com/apollographql/subscriptions-transport-ws/blob/master/PROTOCOL.md) — Legacy protocol

### GraphQL Federation and Composition

- [GraphQL Schema Stitching vs Federation — Tyk](https://tyk.io/blog/graphql-schema-stitching-vs-federation/)
- [Introduction to Apollo Federation — Apollo Blog](https://www.apollographql.com/blog/introduction-to-apollo-federation)
- [What is GraphQL Federation — IBM](https://www.ibm.com/think/topics/graphql-federation)

### Relay Specification

- [GraphQL Cursor Connections Specification](https://relay.dev/graphql/connections.htm)
- [Relay-Style Connections — Apollo Docs](https://www.apollographql.com/docs/graphos/schema-design/guides/relay-style-connections)
- [GraphQL Pagination](https://graphql.org/learn/pagination/)

### Protocol Comparison

- [REST vs GraphQL vs tRPC vs gRPC 2026](https://dev.to/pockit_tools/rest-vs-graphql-vs-trpc-vs-grpc-in-2026-the-definitive-guide-to-choosing-your-api-layer-1j8m)
- [What Is tRPC? Comparison with GraphQL and gRPC — Wallarm](https://www.wallarm.com/what/trpc-protocol)
- [When to use gRPC vs GraphQL — Stack Overflow Blog](https://stackoverflow.blog/2022/11/28/when-to-use-grpc-vs-graphql/)

### Session Types and Web Services (Academic)

- Angiuli et al., "Communication-Safe Web Programming in TypeScript with Routed Multiparty Session Types" (2021) — [arXiv:2101.04622](https://ar5iv.labs.arxiv.org/html/2101.04622)
- Scalas et al., "Comprehensive Multiparty Session Types" (2019) — [arXiv:1902.00544](https://arxiv.org/pdf/1902.00544)
- Hu & Yoshida, "Hybrid Session Verification Through Endpoint API Generation" (2016) — [Springer](https://link.springer.com/chapter/10.1007/978-3-662-49665-7_24)
- Deniélou & Yoshida, "Multiparty Session Types Meet Communicating Automata" (2012) — [PDF](https://www.cs.rhul.ac.uk/~malo/papers/multiparty-session-automata.pdf)
- Yoshida et al., "A Gentle Introduction to Multiparty Asynchronous Session Types" — [PDF](http://mrg.doc.ic.ac.uk/publications/a-gentle-introduction-to-multiparty-asynchronous-session-types/paper.pdf)
- "Programming Language Implementations with Multiparty Session Types" (2024) — [Springer](https://link.springer.com/chapter/10.1007/978-3-031-51060-1_6)

### Row Polymorphism and Extensible Records

- [Row Polymorphism — Wikipedia](https://en.wikipedia.org/wiki/Row_polymorphism)
- Morris & McKinna, "Abstracting Extensible Data Types; or, Rows by Any Other Name" (2019) — [ACM](https://dl.acm.org/doi/10.1145/3290325)
- [Executable Specification of Typing Rules for Extensible Records Based on Row Polymorphism](https://arxiv.org/abs/1707.07872) (2017)
- Leijen, "First-class Labels for Extensible Rows" — [Microsoft Research](https://www.microsoft.com/en-us/research/publication/first-class-labels-for-extensible-rows/)
- [Record Row Type and Row Polymorphism](https://hgiasac.github.io/posts/2018-11-18-Record-Row-Type-and-Row-Polymorphism.html) — Tutorial

### CUE Language

- [CUE Introduction](https://cuelang.org/docs/introduction/)
- [The Logic of CUE](https://cuelang.org/docs/concept/the-logic-of-cue/)
- [CUE Schema Definition Use Case](https://cuelang.org/docs/concept/schema-definition-use-case/)
- [How CUE Enables Data Validation](https://cuelang.org/docs/concept/how-cue-enables-data-validation/)

### Prologos Internal References

- `docs/tracking/principles/RELATIONAL_LANGUAGE_VISION.org` — Schema as "The Object Language"
- `docs/conversations/otto_conversation.org` — Schema/session/process design discussion
- `docs/conversations/20260206_dependent_types_2.md` §§ "Schema vs Selection: Decomplecting Shape from Requirements" — Full schema+selection syntax exploration
- `docs/research/2026-03-02_SCHEMA_TYPE_DESIGN_RESEARCH.md` — Primary research document (companion to this one)
- `racket/prologos/sessions.rkt` — Current session type implementation
- `racket/prologos/typing-sessions.rkt` — Current process typing judgment
- `racket/prologos/processes.rkt` — Current process constructors
