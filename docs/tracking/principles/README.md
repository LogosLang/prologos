- [Overview](#org558388a)
- [Documents](#orgb813f16)
- [How These Relate to Other Docs](#org34c389d)
- [Maintenance](#org0cc3d2d)



<a id="org558388a"></a>

# Overview

This directory contains the canonical articulation of Prologos's design philosophy, conventions, and accumulated wisdom. These documents are *living* &#x2014; they should be updated as the language evolves.


<a id="orgb813f16"></a>

# Documents

| File                          | Purpose                                           |
|----------------------------- |------------------------------------------------- |
| <DESIGN_PRINCIPLES.md>        | Core values, decomplection, layered architecture  |
| <LANGUAGE_VISION.md>          | What Prologos is, why it exists, where it's going |
| <LANGUAGE_DESIGN.md>          | Syntax innovations, type system, session types    |
| <PATTERNS_AND_CONVENTIONS.md> | Naming, coding style, import patterns             |
| <ERGONOMICS.md>               | Progressive disclosure, surface syntax, UX        |
| <DEVELOPMENT_LESSONS.md>      | Accumulated implementation wisdom                 |
| <MISC.md>                     | Miscellaneous notes and preferences               |


<a id="org34c389d"></a>

# How These Relate to Other Docs

-   **`CLAUDE.md` + `.claude/rules/`**: Machine-readable instructions for AI assistants. Terse, prescriptive. These principles docs explain the *why* behind those rules.

-   **`docs/spec/grammar.org`**: The formal syntax specification. The LANGUAGE<sub>DESIGN</sub> doc explains the design *rationale* for syntax choices; the grammar is the *specification*.

-   **~docs/tracking/**.md~\*: Phase-specific tracking documents for individual features. The DEVELOPMENT<sub>LESSONS</sub> doc distills cross-cutting lessons from those efforts.

-   **~docs/research/**.md~\*: Deep technical research reports. The LANGUAGE<sub>VISION</sub> doc synthesizes the vision that those research reports inform.

-   **`my_notes.org`**: Personal working notes (read-only reference). These principles docs are the cleaned-up, canonical distillation.


<a id="org0cc3d2d"></a>

# Maintenance

When making significant design decisions:

1.  Check if the decision aligns with DESIGN<sub>PRINCIPLES</sub>
2.  If it introduces a new pattern, add it to PATTERNS<sub>AND</sub><sub>CONVENTIONS</sub>
3.  If it teaches a lesson, add it to DEVELOPMENT<sub>LESSONS</sub>
4.  If it changes the language's direction, update LANGUAGE<sub>VISION</sub>
