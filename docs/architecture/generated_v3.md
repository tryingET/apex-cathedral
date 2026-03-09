# Generated architecture v3

A cathedral-style local-first runtime with fewer than 20 core modules, a direct capability-to-resource/provider execution path, and append-only audit logging.

## Strengths

- explicit authority boundaries
- stable execution lifecycle
- small enough to understand in one sitting

## Weaknesses

- horizontal sharding of the execution manager is future work

## Decisions

- capabilities map directly to handlers
- policy remains pure and deterministic
- resources own local state and concurrency
- gateway stays thin and stateless
