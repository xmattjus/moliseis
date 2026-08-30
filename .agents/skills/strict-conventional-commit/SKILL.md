---
name: strict-conventional-commit
description: Generate exactly one copy-pasteable git commit command from staged changes. Uses Conventional Commits 1.0.0, Pro Git 50/72 style, a mandatory body, conservative breaking-change detection, and commit_format for deterministic formatting. Never execute the commit.
compatibility: opencode
metadata:
  standard: conventional-commits-1.0.0+pro-git-50-72
  formatter: commit_format
  language: english
---
# Strict Conventional Commit

Generate one shell-ready `git commit` command from staged changes.
This skill is READ-ONLY and GENERATION-ONLY.

## Safety

`git commit` is OUTPUT TEXT, never a tool command.

- Never execute `git commit`.
- Never send `git commit` to Bash or another execution tool.
- Never request approval to execute the generated command.
- Never stage, edit, reset, restore, checkout, or modify repository state.
- After a successful `commit_format` result, output it verbatim and STOP.

## Inspect staged changes

Use staged content as the source of truth. Read-only inspection is allowed:

- `git status --short`
- `git diff --cached --stat`
- `git diff --cached`

Do not describe unstaged-only changes.

Determine only:

1. primary intent
2. type
3. optional short scope
4. preferred description
5. short fallback description
6. body
7. breaking or non-breaking

## Conventional Commit

The formatter builds `type(scope)!: description`.

Use one type:

- `feat` — new capability
- `fix` — bug or incorrect behavior
- `docs` — documentation only
- `style` — formatting only
- `refactor` — restructure without intended behavior change
- `perf` — performance improvement
- `test` — tests only
- `build` — build, packaging, dependencies
- `ci` — CI configuration
- `chore` — maintenance not covered above
- `revert` — revert a previous change

Choose the PRIMARY INTENT, not every changed file.

## Scope

Scope is optional. Prefer one short repository term when it adds clarity.
Repository-native underscores are allowed; Conventional Commits does not require
kebab-case.

Prefer short scopes such as `auth`, `parser`, `ui`, `content_submission`.
Omit scope when it is vague or competes with a useful description.

## Descriptions

Provide TWO semantically equivalent descriptions to `commit_format`:

- `description`: preferred form, normally 3-6 words
- `short_description`: compact fallback, normally 2-4 words

Both must:

- be English
- use concise imperative wording
- describe the primary change
- have no final period

Do NOT count characters. The formatter chooses the best candidate.

Example:

- description: `extract toolbar and asset widgets`
- short_description: `extract reusable widgets`

Do not put the type into the description.

Bad for `refactor`: `refactor asset handling`
Good: `extract asset widgets`

## Pro Git 50/72 style

Formatting is deterministic and belongs to `commit_format`:

- header target: <=50 characters
- header hard maximum: <=60 characters
- body/footer hard maximum: <=72 characters per line

Never manually count or wrap text.
Never use Bash, `printf`, `wc`, Python, calculators, or another length tool.

`commit_format` tries preferred/short descriptions with and without scope,
preferring a <=50 header and allowing 51-60 only when needed.

## Mandatory body

Always provide a body. One concise sentence is usually enough.
It must add useful context beyond the header and stay grounded in the staged diff.

Pass ordinary UNWRAPPED text to `commit_format`.
The formatter adds the final period if needed and wraps at 72 characters.

Good:

Header intent: `fix(auth): reject expired tokens`
Body: `Validate token expiry before requests reach protected handlers`

Bad body: `Reject expired tokens`

## Breaking classifier

BREAKING means an existing correct consumer must change code, commands,
configuration, data, or integration behavior after this commit.

If clearly YES: breaking.
If NO: non-breaking.
If ambiguous: non-breaking.

Large changes and refactors are not automatically breaking.

### Decision matrix

| Before -> After | Breaking? |
| --- | --- |
| public API added | NO |
| optional parameter added | NO |
| required parameter added | YES |
| public parameter removed | YES |
| public rename without compatible alias | YES |
| public rename with compatible alias | NO |
| public symbol/export removed | YES |
| public return field removed/renamed | YES |
| public return field added | usually NO |
| accepted public value removed | YES |
| accepted public value added | NO |
| CLI command/flag removed or renamed | YES |
| optional CLI flag added | NO |
| CLI argument becomes required | YES |
| config/env key removed without fallback | YES |
| optional config key added | NO |
| optional config becomes required | YES |
| HTTP/RPC endpoint removed/renamed | YES |
| request field becomes required | YES |
| response field removed/renamed | YES |
| additive endpoint/optional field | NO |
| event payload changes incompatibly | YES |
| persisted data becomes unreadable | YES |
| manual data migration becomes required | YES |
| documented runtime/platform support dropped | YES |
| internal rename/refactor only | NO |
| implementation replaced behind same contract | NO |
| bug fix restoring documented behavior | NO |
| tests/docs/CI only | NO |

Look for aliases, fallbacks, adapters, deprecated APIs that still work, and
transparent migrations. If existing consumers still work unchanged, it is not
breaking.

## Breaking text

For a breaking change, pass `breaking` containing only the incompatibility or
migration text. Do not add the `BREAKING CHANGE:` prefix yourself.

The formatter automatically adds:

- `!` to the header
- `BREAKING CHANGE:` footer
- final punctuation
- 72-character wrapping

For non-breaking changes omit `breaking`.

## Formatter protocol

Call `commit_format` ONCE after semantic analysis with:

- `type`
- optional `scope`
- `description`
- `short_description`
- `body`
- optional `breaking`

A successful tool result starts with `git commit`.
Output that entire result VERBATIM and STOP.

Do not recount, rewrap, rebuild, explain, or call another tool after success.

If the tool returns `ERROR`, fix only the reported semantic input and retry once.
Do not perform manual counting.

## Output contract

Final response = only the successful `commit_format` result.

No Markdown fences.
No prose.
No XML or JSON.
No alternatives.
No validation report.
No extra commands.

The command may contain physical newlines inside a quoted body/footer because
those are wrapped message lines, not additional shell commands.

Never execute it. Output it and STOP.
