"""Compare Flutter diagnostics against an independently analyzed PR base."""

import collections
import json
import os
from pathlib import Path
import re
import subprocess
import sys


DIAGNOSTIC = re.compile(
    r"^\s*(info|warning|error) • (.+) • (.+):(\d+):(\d+) • ([a-z0-9_]+)\s*$"
)
SUMMARY = re.compile(r"^(\d+) issues? found\. \(ran in .+\)$")
HUNK = re.compile(r"^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@")


def parse_diagnostics(root, output, returncode):
    """Fail closed on tool errors, incomplete output, or analyzer errors."""
    diagnostics = collections.Counter()
    count = 0
    errors = 0
    summaries = []
    for line in output.splitlines():
        match = DIAGNOSTIC.fullmatch(line)
        if match:
            severity, message, filename, row, column, code = match.groups()
            path = (root / filename).resolve()
            relative = path.relative_to(root.resolve()).as_posix()
            source = path.read_text().splitlines()
            if not 1 <= int(row) <= len(source) or int(column) < 1:
                raise ValueError("Invalid analyzer source location")
            diagnostics[(relative, severity, code, message, int(row), int(column))] += 1
            count += 1
            errors += severity == "error"
        elif " • " in line:
            raise ValueError(f"Unrecognized analyzer diagnostic: {line}")
        elif SUMMARY.fullmatch(line.strip()):
            summaries.append(int(SUMMARY.fullmatch(line.strip()).group(1)))
        elif re.fullmatch(r"No issues found! \(ran in .+\)", line.strip()):
            summaries.append(0)
    if summaries != [count]:
        raise ValueError("Missing/inconsistent analyzer summary; baseline is unusable")
    if errors:
        raise ValueError(f"Analyzer reported {errors} error(s); errors are always blocking")
    # Default flutter analyze exits 1 for warnings/infos. Accept that status only
    # after verifying a complete diagnostic report, never for a runtime failure.
    expected_status = 1 if count else 0
    if returncode != expected_status:
        raise ValueError(f"Unexpected analyzer exit status: {returncode}")
    return diagnostics


def analyze(root, label):
    print(f"::group::Flutter analyze: {label}", flush=True)
    result = subprocess.run(
        ["flutter", "analyze", "--no-pub"],
        cwd=root,
        env={**os.environ, "NO_COLOR": "1", "TERM": "dumb"},
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        check=False,
    )
    print(result.stdout, end="", flush=True)
    print("::endgroup::", flush=True)
    return parse_diagnostics(root, result.stdout, result.returncode)


def analyzer_options(root):
    tracked = subprocess.check_output(
        ["git", "ls-files", "-z"], cwd=root
    ).decode().split("\0")
    return {
        name: (root / name).read_bytes()
        for name in tracked
        if Path(name).name == "analysis_options.yaml"
    }


def unchanged_rows(old_file, new_file):
    # Patience diff uses unique surrounding lines (e.g. declarations) as anchors,
    # avoiding matches of repeated lint-bearing lines across unrelated scopes.
    diff = subprocess.run(
        ["git", "-c", "color.ui=false", "diff", "--no-index", "--no-ext-diff",
         "--no-textconv", "--diff-algorithm=patience", "--unified=0", "--",
         str(old_file), str(new_file)],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=False,
    )
    if diff.returncode not in (0, 1):
        raise ValueError(f"Cannot map source changes: {diff.stderr}")
    rows = {}
    old_cursor = new_cursor = 1
    hunks = [HUNK.match(line) for line in diff.stdout.splitlines() if line.startswith("@@")]
    if any(hunk is None for hunk in hunks) or (diff.returncode == 1 and not hunks):
        raise ValueError("Unrecognized source diff; baseline is unusable")
    for hunk in hunks:
        old_start, old_count, new_start, new_count = hunk.groups()
        old_count = int(old_count) if old_count is not None else 1
        new_count = int(new_count) if new_count is not None else 1
        old_start = int(old_start) + (old_count == 0)
        new_start = int(new_start) + (new_count == 0)
        for row in range(old_cursor, old_start):
            rows[row] = new_cursor + row - old_cursor
        old_cursor, new_cursor = old_start + old_count, new_start + new_count
    for row in range(old_cursor, len(old_file.read_text().splitlines()) + 1):
        rows[row] = new_cursor + row - old_cursor
    return rows


def compare(baseline, candidate, base_root, candidate_root):
    mapped = collections.Counter()
    for path in {item[0] for item in baseline}:
        old_file, new_file = base_root / path, candidate_root / path
        if not new_file.is_file():
            continue
        rows = unchanged_rows(old_file, new_file)
        for (filename, severity, code, message, row, column), count in baseline.items():
            if filename == path and row in rows:
                mapped[(path, severity, code, message, rows[row], column)] += count
    added = candidate - mapped
    removed = sum(baseline.values()) - sum((candidate & mapped).values())
    print(
        f"Baseline: {sum(baseline.values())}; candidate: {sum(candidate.values())}; "
        f"new: {sum(added.values())}; removed: {removed}"
    )
    for (path, severity, code, message, row, column), count in sorted(added.items()):
        print(f"NEW ({count}): {path}:{row}:{column}: {severity} {code}: {message}")
    return not added


def main():
    if len(sys.argv) != 3:
        raise ValueError("Usage: analyzer_baseline.py BASE_DIRECTORY PR_DIRECTORY")
    base, candidate = (Path(arg).resolve() for arg in sys.argv[1:])
    for label, root in (("base", base), ("candidate", candidate)):
        sha = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root).decode().strip()
        print(f"{label} commit: {sha}")
    if analyzer_options(base) != analyzer_options(candidate):
        raise ValueError(
            "Analyzer configuration changed; explicit baseline/policy review is required"
        )
    version = subprocess.check_output(["flutter", "--version", "--machine"], text=True)
    sdk = json.loads(version)
    if sdk["frameworkVersion"] != "3.47.5":
        raise ValueError("This diagnostic parser requires Flutter 3.47.5")
    print(f"SDK: Flutter {sdk['frameworkVersion']}, Dart {sdk['dartSdkVersion']}")
    baseline = analyze(base, "verified PR base")
    current = analyze(candidate, "PR candidate")
    return 0 if compare(baseline, current, base, candidate) else 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, OSError, IndexError, subprocess.SubprocessError) as error:
        print(f"Analyzer gate failed: {error}", file=sys.stderr)
        sys.exit(1)
