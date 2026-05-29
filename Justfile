help:
    @just --list

doctor:
    @echo "repo: apex-cathedral"
    @git --version
    @elixir --version
    @node --version
    @npm --version
    @ak repo show .

check:
    python3 -m json.tool policy/engineering-lane.json >/tmp/apex-cathedral-engineering-lane.json
    python3 scripts/check_docs_strict.py
    python3 scripts/validate_repo.py

test:
    mix test

build:
    cd apps/ts-sdk && npm run build
    cd apps/ui && npm run build

lint:
    python3 scripts/check_docs_strict.py

fmt:
    @echo "use mix format and package-local TypeScript formatters when explicitly in scope"

ci:
    python3 -m json.tool policy/engineering-lane.json >/tmp/apex-cathedral-engineering-lane.json
    ./scripts/ci/full.sh
    python3 scripts/validate_repo.py

loop-doctor:
    @echo "phase=loop-doctor result=diagnostic scope=repo:apex-cathedral"
    @echo "tooling:"
    @git --version || true
    @elixir --version || true
    @node --version || true
    @npm --version || true
    @just --version || true
    @echo "git-status:"
    @git status --short || true
    @echo "ak-binding:"
    @ak repo show . || true
    @echo "authority-boundary: diagnostic only; AK/CI/release/runtime authority is unchanged"

loop-verify-fast:
    just check

loop-impact-plan:
    @echo "phase=loop-impact-plan result=passed scope=changed-files"
    @echo "impact=bounded"
    @echo "changed-files:"
    @git status --short || true
    @echo "next=just loop-impact-run"
    @echo "wide-if=Elixir runtime, gateway API/OpenAPI, policy/resource supervision, TS SDK/UI, ontology, package-manager metadata, or release surfaces change"

loop-impact-run:
    just loop-verify-fast

loop-impact-wide:
    just ci

loop-landing-check:
    just ci
