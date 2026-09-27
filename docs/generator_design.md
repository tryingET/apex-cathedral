---
summary: "Design of the self-improving repository generator and its invariants."
read_when:
  - "When changing the repository generator"
  - "When checking which invariants generated output must preserve"
---

# Generator design

The repository includes a **self-improving repository generator** in `scripts/cathedral_generator.py`.

The generator is intentionally deterministic. It does not rely on hidden online services. Instead, it encodes the internal review loop as a set of explicit roles and invariants.

## Internal roles

### Architect

Drafts the initial architecture and preserves the system invariants.

### Skeptic

Finds hidden authority, unnecessary indirection, and failure-handling gaps.

### Simplifier

Reduces the number of layers and modules while keeping the architecture intact.

### Builder

Copies the validated repository template, emits iteration documents, and writes a manifest for the generated snapshot.

## Generator workflow

```text
1. Load blueprint
2. Draft architecture v1
3. Review with Skeptic
4. Revise to architecture v2
5. Review again
6. Simplify to architecture v3
7. Validate repository invariants
8. Emit regenerated repository snapshot
```

## Why the generator copies the repository template

A serious repository generator should not invent files ad hoc. In this design, the repository itself is the source template. The generator's job is to:

- preserve the architecture loop
- validate invariants
- emit a fresh snapshot
- keep the review artifacts attached to the output

This keeps the generator honest and reproducible.

## Invariants enforced

- required repository directories exist
- OpenAPI documentation exists
- core runtime modules exist
- the core module budget remains under 20
- the generated repository retains the same architecture documents

## Output

Running:

```bash
python3 scripts/cathedral_generator.py --out generated
```

produces:

- a copied repository snapshot
- generated architecture iteration docs
- a manifest under `.apex-cathedral/manifest.json`

## Improvement strategy

The improvement loop is conservative:

- remove forwarding layers
- prefer explicit state machines
- centralize authority checks
- keep resources stateful and supervised
- deny by default when uncertain

The generator is therefore less like an autonomous codewriter and more like an **architecture-preserving, review-driven repository emitter**.
