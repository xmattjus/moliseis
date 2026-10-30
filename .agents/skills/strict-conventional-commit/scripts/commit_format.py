#!/usr/bin/env python3
"""Deterministic formatter for strict-conventional-commit.

Reads one JSON object from stdin and prints exactly one shell-ready `git commit`
command on success, or one `ERROR ...` line on validation failure.

This program never invokes Git and never modifies repository state.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import textwrap
from typing import Any

TYPES = {
    "feat",
    "fix",
    "docs",
    "style",
    "refactor",
    "perf",
    "test",
    "build",
    "ci",
    "ai",
    "chore",
    "revert",
}

HEADER_TARGET = 50
HEADER_MAX = 60
LINE_MAX = 72
SCOPE_RE = re.compile(r"^[a-z0-9][a-z0-9._/-]*$")
BREAKING_PREFIX_RE = re.compile(r"^BREAKING(?:[ -])CHANGE:\s*", re.IGNORECASE)


def normalize(value: Any) -> str:
    if value is None:
        return ""
    return " ".join(str(value).strip().split())


def sentence(value: Any) -> str:
    text = normalize(value)
    text = re.sub(r"[.!?]+$", "", text)
    return f"{text}." if text else ""


def clean_description(value: Any) -> str:
    return re.sub(r"[.]+$", "", normalize(value))


def clean_breaking(value: Any) -> str:
    text = normalize(value)
    return BREAKING_PREFIX_RE.sub("", text).strip()


def wrap(value: str, width: int = LINE_MAX) -> str:
    text = normalize(value)
    if not text:
        return ""

    for word in text.split(" "):
        if len(word) > width:
            raise ValueError(f"word exceeds {width} characters: {word}")

    return textwrap.fill(
        text,
        width=width,
        break_long_words=False,
        break_on_hyphens=False,
        replace_whitespace=False,
        drop_whitespace=True,
    )


def build_header(
    commit_type: str,
    scope: str,
    description: str,
    breaking: bool,
) -> tuple[str, int]:
    scope_part = f"({scope})" if scope else ""
    bang = "!" if breaking else ""
    header = f"{commit_type}{scope_part}{bang}: {description}"
    return header, len(header)


def choose_header(
    commit_type: str,
    scope: str,
    description: str,
    short_description: str,
    breaking: bool,
) -> tuple[str, int] | None:
    # A supplied scope was chosen for semantic value. Prefer shortening the
    # equivalent description before discarding that scope. Only omit scope when
    # neither scoped description satisfies the current length tier.
    raw_candidates = [
        build_header(commit_type, scope, description, breaking),
        build_header(commit_type, scope, short_description, breaking),
        build_header(commit_type, "", description, breaking),
        build_header(commit_type, "", short_description, breaking),
    ]

    candidates: list[tuple[str, int]] = []
    seen: set[str] = set()
    for candidate in raw_candidates:
        if candidate[0] not in seen:
            candidates.append(candidate)
            seen.add(candidate[0])

    for candidate in candidates:
        if candidate[1] <= HEADER_TARGET:
            return candidate
    for candidate in candidates:
        if candidate[1] <= HEADER_MAX:
            return candidate
    return None


def posix_quote(value: str) -> str:
    return "'" + value.replace("'", "'\"'\"'") + "'"


def powershell_quote(value: str) -> str:
    # PowerShell single-quoted strings escape an apostrophe by doubling it.
    return "'" + value.replace("'", "''") + "'"


def error(code: str, detail: str = "") -> str:
    return f"ERROR {code}{': ' + detail if detail else ''}"


def determine_shell(requested: str) -> str:
    if requested != "auto":
        return requested
    return "powershell" if os.name == "nt" else "posix"


def parse_input() -> dict[str, Any] | str:
    raw = sys.stdin.read()
    if not raw.strip():
        return error("invalid_input", "expected one JSON object on stdin")

    try:
        payload = json.loads(raw)
    except json.JSONDecodeError as exc:
        return error("invalid_json", f"{exc.msg} at line {exc.lineno} column {exc.colno}")

    if not isinstance(payload, dict):
        return error("invalid_input", "expected a JSON object")
    return payload


def format_commit(
    payload: dict[str, Any], shell: str, pr_title: bool = False
) -> str:
    commit_type = normalize(payload.get("type")).lower()
    scope = normalize(payload.get("scope")).lower()
    description = clean_description(payload.get("description"))
    short_description = clean_description(payload.get("short_description"))
    body = sentence(payload.get("body"))
    breaking = clean_breaking(payload.get("breaking"))

    if commit_type not in TYPES:
        return error("invalid_type", f"use one of {', '.join(sorted(TYPES))}")
    if scope and not SCOPE_RE.fullmatch(scope):
        return error("invalid_scope", "use lowercase letters, digits, ., _, /, or -")
    if not description:
        return error("empty_description")
    if not short_description:
        return error("empty_short_description")
    if not body and not pr_title:
        return error("empty_body")

    selected = choose_header(
        commit_type,
        scope,
        description,
        short_description,
        bool(breaking),
    )
    if selected is None:
        return error(
            "header_too_long",
            f"both descriptions exceed {HEADER_MAX} characters even without scope; "
            "make short_description substantially shorter",
        )

    if pr_title:
        return selected[0]

    try:
        wrapped_body = wrap(body)
        wrapped_footer = wrap(f"BREAKING CHANGE: {sentence(breaking)}") if breaking else ""
    except ValueError as exc:
        return error("unwrappable_word", str(exc))

    quote = posix_quote if shell == "posix" else powershell_quote
    parts = [
        f"git commit -m {quote(selected[0])}",
        f"-m {quote(wrapped_body)}",
    ]
    if wrapped_footer:
        parts.append(f"-m {quote(wrapped_footer)}")

    return " ".join(parts)


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Build a safe Conventional Commit command from JSON on stdin. "
            "Never executes Git."
        )
    )
    parser.add_argument(
        "--shell",
        choices=("auto", "posix", "powershell"),
        default="auto",
        help="quoting style for the generated command (default: auto)",
    )
    parser.add_argument(
        "--pr-title",
        action="store_true",
        help="emit only a Conventional Commit PR title; no body required",
    )
    args = parser.parse_args()

    payload = parse_input()
    if isinstance(payload, str):
        print(payload)
        return

    shell = determine_shell(args.shell)
    print(format_commit(payload, shell, pr_title=args.pr_title))


if __name__ == "__main__":
    main()
