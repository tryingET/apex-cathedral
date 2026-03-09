from __future__ import annotations

import argparse
import dataclasses
import json
import shutil
from pathlib import Path
from typing import Iterable

REPO_ROOT = Path(__file__).resolve().parents[1]
BLUEPRINT_PATH = REPO_ROOT / "scripts" / "runtime_blueprint.json"

@dataclasses.dataclass
class Architecture:
    version: str
    summary: str
    strengths: list[str]
    weaknesses: list[str]
    decisions: list[str]

class Architect:
    def draft_v1(self, blueprint: dict) -> Architecture:
        return Architecture(
            version="v1",
            summary="A full control plane with event sourcing, command routing, provider indirection, and resource leases.",
            strengths=[
                "clear separation between capabilities, policies, approvals, and resources",
                "strong audit spine",
                "explicit domain models",
            ],
            weaknesses=[
                "too many moving parts for a first implementation",
                "too much indirection between capability and execution",
                "recovery design is underspecified",
            ],
            decisions=[
                "use an append-only audit log",
                "model execution as a visible state machine",
                "make resources supervised processes",
            ],
        )

    def revise_v2(self, blueprint: dict, critique: list[str]) -> Architecture:
        return Architecture(
            version="v2",
            summary="The control plane is collapsed into a registry, a policy engine, an approval manager, an execution manager, and supervised resources.",
            strengths=[
                "much smaller surface area",
                "no hidden tool access",
                "approvals are now the primary pause/resume edge",
            ],
            weaknesses=[
                "single execution manager may be a hotspot",
                "generator still needs repository invariants",
            ],
            decisions=[
                "first-match-wins policy rules",
                "ETS for hot execution state",
                "disk-backed JSONL audit for persistence",
            ],
        )

class Skeptic:
    def review(self, architecture: Architecture) -> list[str]:
        findings = []
        if "too many" in " ".join(architecture.weaknesses):
            findings.append("remove any layer that only forwards messages")
        if "recovery" in " ".join(architecture.weaknesses):
            findings.append("prefer audit replay and explicit failure marking over hidden retries")
        findings.append("deny by default when policy is unclear")
        findings.append("keep runtime logic in Elixir only")
        return findings

class Simplifier:
    def finalize_v3(self, blueprint: dict, critique: list[str]) -> Architecture:
        return Architecture(
            version="v3",
            summary="A cathedral-style local-first runtime with fewer than 20 core modules, a direct capability-to-resource/provider execution path, and append-only audit logging.",
            strengths=[
                "explicit authority boundaries",
                "stable execution lifecycle",
                "small enough to understand in one sitting",
            ],
            weaknesses=[
                "horizontal sharding of the execution manager is future work",
            ],
            decisions=[
                "capabilities map directly to handlers",
                "policy remains pure and deterministic",
                "resources own local state and concurrency",
                "gateway stays thin and stateless",
            ],
        )

class Validator:
    REQUIRED_DIRS = [
        "apps/runtime",
        "apps/gateway",
        "apps/providers",
        "apps/resources",
        "apps/policy",
        "apps/audit",
        "apps/ui",
        "apps/ts-sdk",
        "docs",
        "examples",
        "scripts",
    ]

    def validate(self, root: Path) -> None:
        missing = [path for path in self.REQUIRED_DIRS if not (root / path).exists()]
        if missing:
            raise RuntimeError("missing required directories: " + ", ".join(missing))

class Builder:
    COPY_PATHS = [
        "README.md",
        "LICENSE",
        "Makefile",
        "docker-compose.yml",
        "mix.exs",
        "mix.lock",
        ".gitignore",
        "config",
        "apps",
        "docs",
        "examples",
        "scripts",
    ]

    def write_iteration_docs(self, out: Path, iterations: Iterable[Architecture]) -> None:
        docs_dir = out / "docs" / "architecture"
        docs_dir.mkdir(parents=True, exist_ok=True)

        for architecture in iterations:
            target = docs_dir / f"generated_{architecture.version}.md"
            lines = [
                f"# Generated architecture {architecture.version}",
                "",
                architecture.summary,
                "",
                "## Strengths",
                "",
                *[f"- {item}" for item in architecture.strengths],
                "",
                "## Weaknesses",
                "",
                *[f"- {item}" for item in architecture.weaknesses],
                "",
                "## Decisions",
                "",
                *[f"- {item}" for item in architecture.decisions],
                "",
            ]
            target.write_text("\n".join(lines), encoding="utf-8")

    def copy_repo(self, out: Path) -> None:
        out.mkdir(parents=True, exist_ok=True)
        for rel in self.COPY_PATHS:
            src = REPO_ROOT / rel
            dst = out / rel
            if src.is_dir():
                if dst.exists():
                    shutil.rmtree(dst)
                shutil.copytree(src, dst)
            else:
                dst.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(src, dst)

        manifest = {
            "generator": "apex-cathedral",
            "source_repo": str(REPO_ROOT),
            "generated_paths": self.COPY_PATHS,
        }
        (out / ".apex-cathedral").mkdir(exist_ok=True)
        (out / ".apex-cathedral" / "manifest.json").write_text(
            json.dumps(manifest, indent=2),
            encoding="utf-8",
        )

def main() -> int:
    parser = argparse.ArgumentParser(description="Generate an Apex Cathedral repository snapshot")
    parser.add_argument("--out", required=True, help="Output directory")
    args = parser.parse_args()

    blueprint = json.loads(BLUEPRINT_PATH.read_text(encoding="utf-8"))
    architect = Architect()
    skeptic = Skeptic()
    simplifier = Simplifier()
    validator = Validator()
    builder = Builder()

    v1 = architect.draft_v1(blueprint)
    critique_1 = skeptic.review(v1)
    v2 = architect.revise_v2(blueprint, critique_1)
    critique_2 = skeptic.review(v2)
    v3 = simplifier.finalize_v3(blueprint, critique_2)

    out = Path(args.out).resolve()
    builder.copy_repo(out)
    builder.write_iteration_docs(out, [v1, v2, v3])
    validator.validate(out)

    report = {
        "iterations": [
            dataclasses.asdict(v1),
            dataclasses.asdict(v2),
            dataclasses.asdict(v3),
        ],
        "critiques": {
            "v1": critique_1,
            "v2": critique_2,
        },
        "out": str(out),
    }
    print(json.dumps(report, indent=2))
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
