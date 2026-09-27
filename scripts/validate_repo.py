from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

REQUIRED_PATHS = [
    "README.md",
    "LICENSE",
    "Makefile",
    "docker-compose.yml",
    "docs/openapi.yaml",
    "docs/architecture/architecture_v1.md",
    "docs/architecture/architecture_v2.md",
    "docs/architecture/architecture_v3.md",
    "apps/runtime/lib/apex/runtime/execution_manager.ex",
    "apps/gateway/lib/apex/gateway/router.ex",
    "apps/resources/lib/apex/resources/workspace_sqlite.ex",
    "apps/ts-sdk/src/client.ts",
    "apps/ui/src/App.tsx",
]

REQUIRED_ENDPOINTS = [
    "GET /capabilities",
    "GET /capabilities/{name}",
    "POST /executions",
    "GET /executions",
    "GET /executions/{id}",
    "GET /approvals",
    "POST /approvals/{id}/approve",
    "POST /approvals/{id}/deny",
    "GET /resources",
    "GET /events/stream",
]

CORE_MODULE_PATTERN = re.compile(r"defmodule\s+(Apex\.[A-Za-z0-9_.]+)")
CORE_HINTS = {
    "Apex.Runtime.CapabilityRegistry",
    "Apex.Runtime.ExecutionManager",
    "Apex.Runtime.ApprovalManager",
    "Apex.Policy.Engine",
    "Apex.Audit.Store",
    "Apex.Resources.Supervisor",
    "Apex.Resources.WorkspaceFS",
    "Apex.Resources.WorkspaceSQLite",
    "Apex.Resources.AccountSession",
    "Apex.Providers.Registry",
    "Apex.Providers.MockAccount",
    "Apex.Gateway.Router",
}


def find_modules(root: Path) -> set[str]:
    modules = set()
    for path in root.rglob("*.ex"):
        if "/test/" in str(path):
            continue
        text = path.read_text(encoding="utf-8")
        modules.update(CORE_MODULE_PATTERN.findall(text))
    return modules


def run_docs_strict(root: Path) -> list[str]:
    docs_validator = root / "scripts/check_docs_strict.py"
    if not docs_validator.exists():
        return ["missing docs validator: scripts/check_docs_strict.py"]

    result = subprocess.run(
        [sys.executable, str(docs_validator)],
        cwd=root,
        capture_output=True,
        text=True,
    )
    if result.returncode == 0:
        return []

    output = "\n".join(part for part in [result.stdout.strip(), result.stderr.strip()] if part)
    if not output:
        return ["docs strict check failed"]

    return [f"docs strict: {line}" for line in output.splitlines()]



def main() -> int:
    root = Path(__file__).resolve().parents[1]
    errors: list[str] = []

    errors.extend(run_docs_strict(root))

    for rel in REQUIRED_PATHS:
        if not (root / rel).exists():
            errors.append(f"missing required path: {rel}")

    openapi_path = root / "docs/openapi.yaml"
    if openapi_path.exists():
        openapi = openapi_path.read_text(encoding="utf-8")
        for endpoint in REQUIRED_ENDPOINTS:
            method, route = endpoint.split(" ", 1)
            if route not in openapi or method.lower() + ":" not in openapi.lower():
                errors.append(f"openapi missing endpoint hint: {endpoint}")

    modules = find_modules(root)
    missing_core = sorted(CORE_HINTS - modules)
    if missing_core:
        errors.append("missing core modules: " + ", ".join(missing_core))

    if len(CORE_HINTS) >= 20:
        errors.append("core module budget exceeded")

    if errors:
        print("Apex Cathedral validation failed:")
        for error in errors:
            print(f" - {error}")
        return 1

    print(json.dumps({
        "status": "ok",
        "docs_strict": "ok",
        "core_modules": sorted(CORE_HINTS),
        "module_count": len(CORE_HINTS),
    }, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
