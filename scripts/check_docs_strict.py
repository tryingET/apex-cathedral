from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT_MARKDOWN = [
    "AGENTS.md",
    "README.md",
    "next_session_prompt.md",
]

MARKDOWN_DIRS = [
    "apps/ts-sdk",
    "diary",
    "docs",
    "governance",
    "ontology",
]

EXCLUDED_DIR_NAMES = {
    ".git",
    ".venv",
    "__pycache__",
    "_build",
    "deps",
    "dist",
    "node_modules",
    "tmp",
    "var",
    "venv",
}

TOP_LEVEL_KEY_RE = re.compile(r"^([A-Za-z0-9_-]+):\s*(.*)$")
BULLET_RE = re.compile(r"^\s*-\s+(.*)$")


def normalize_scalar(value: str) -> str:
    value = value.strip()
    if (value.startswith('"') and value.endswith('"')) or (value.startswith("'") and value.endswith("'")):
        value = value[1:-1].strip()
    return re.sub(r"\s+", " ", value).strip()


def parse_inline_list(value: str) -> list[str]:
    trimmed = value.strip()
    if not (trimmed.startswith("[") and trimmed.endswith("]")):
        scalar = normalize_scalar(trimmed)
        return [scalar] if scalar else []

    inner = trimmed[1:-1].strip()
    if not inner:
        return []

    items: list[str] = []
    current = []
    quote: str | None = None

    for ch in inner:
        if quote:
            current.append(ch)
            if ch == quote:
                quote = None
            continue

        if ch in {'"', "'"}:
            quote = ch
            current.append(ch)
            continue

        if ch == ",":
            item = normalize_scalar("".join(current))
            if item:
                items.append(item)
            current = []
            continue

        current.append(ch)

    item = normalize_scalar("".join(current))
    if item:
        items.append(item)
    return items


def extract_frontmatter(text: str) -> tuple[list[str] | None, str | None]:
    lines = text.lstrip("\ufeff").splitlines()

    start = 0
    while start < len(lines) and lines[start].strip() == "":
        start += 1

    if start >= len(lines) or lines[start].strip() != "---":
        return None, "missing front matter"

    for end in range(start + 1, len(lines)):
        if lines[end].strip() == "---":
            return lines[start + 1 : end], None

    return None, "unterminated front matter"


def validate_markdown(path: Path) -> list[str]:
    frontmatter, error = extract_frontmatter(path.read_text(encoding="utf-8"))
    if error:
        return [error]

    assert frontmatter is not None

    summary_seen = False
    summary = ""
    read_when: list[str] = []
    collecting_read_when = False

    for raw_line in frontmatter:
        if collecting_read_when:
            bullet = BULLET_RE.match(raw_line)
            if bullet:
                hint = normalize_scalar(bullet.group(1))
                if hint:
                    read_when.append(hint)
                continue
            if raw_line.strip() == "":
                continue
            if TOP_LEVEL_KEY_RE.match(raw_line):
                collecting_read_when = False
            else:
                continue

        match = TOP_LEVEL_KEY_RE.match(raw_line)
        if not match:
            continue

        key = match.group(1).lower()
        value = match.group(2)

        if key == "summary":
            summary_seen = True
            summary = normalize_scalar(value)
        elif key == "read_when":
            trimmed = value.strip()
            if not trimmed:
                collecting_read_when = True
            else:
                read_when.extend(parse_inline_list(trimmed))

    issues: list[str] = []
    if not summary_seen:
        issues.append("summary key missing")
    elif not summary:
        issues.append("summary is empty")

    if not read_when:
        issues.append("read_when missing")

    return issues


def iter_owned_markdown(root: Path):
    seen: set[Path] = set()

    for rel in ROOT_MARKDOWN:
        path = root / rel
        if path.is_file() and path not in seen:
            seen.add(path)
            yield path

    for rel_dir in MARKDOWN_DIRS:
        base = root / rel_dir
        if not base.is_dir():
            continue

        stack = [base]
        while stack:
            current = stack.pop()
            entries = sorted(current.iterdir(), key=lambda item: item.name)
            subdirs = []
            for entry in entries:
                if entry.name.startswith("."):
                    continue
                if entry.is_dir():
                    if entry.name in EXCLUDED_DIR_NAMES:
                        continue
                    subdirs.append(entry)
                elif entry.is_file() and entry.suffix.lower() == ".md" and entry not in seen:
                    seen.add(entry)
                    yield entry
            stack.extend(reversed(subdirs))


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    violations: list[tuple[str, list[str]]] = []
    checked = 0

    for path in iter_owned_markdown(root):
        checked += 1
        issues = validate_markdown(path)
        if issues:
            violations.append((path.relative_to(root).as_posix(), issues))

    if violations:
        print("Apex Cathedral docs strict check failed:")
        for rel_path, issues in violations:
            print(f" - {rel_path}: {', '.join(issues)}")
        return 1

    print(json.dumps({
        "status": "ok",
        "checked_files": checked,
    }, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
