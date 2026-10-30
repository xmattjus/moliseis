---
name: strict-conventional-commit
description: Generate exactly one copy-pasteable git commit command from staged changes, or a Conventional Commit PR title when requested. Uses Conventional Commits 1.0.0 plus the local `ai` type for AI harness changes, Pro Git 50/72 style, a mandatory body, semantic scopes, conservative breaking-change detection, and a bundled deterministic formatter. Never execute the commit.
compatibility: Requires git and Python 3. Compatible with Agent Skills hosts that allow read-only repository inspection and execution of the bundled formatter script.
metadata:
  standard: conventional-commits-1.0.0+pro-git-50-72
  formatter: scripts/commit_format.py
  language: english
  version: "4"
---
# Strict Conventional Commit

Generate one shell-ready `git commit` command from staged changes.
This skill is READ-ONLY and GENERATION-ONLY.

## PR titles

When explicitly asked for a pull request title, use PR-title mode instead of
commit-command mode. Inspect the local diff of the entire PR against its stated
base (for example, `git diff main...HEAD`), including relevant uncommitted changes
when the request concerns work not yet committed. Do not fetch or create a PR.
Do not apply the empty-staging check in this mode. If there are no relevant
changes, report that there is insufficient evidence to generate a title.

Apply the same type, semantic scope, English imperative description, breaking
classification, and 50/60-character header rules described below. Provide the
same formatter JSON fields, except that `body` is not required. If breaking,
provide `breaking` as usual so the title includes `!`.

Invoke the bundled formatter with `--pr-title`. Output only its resulting title,
without shell quoting, a command, a body, or commentary. The commit-command
instructions below apply when generating a commit command; that mode remains
the default.

## Safety

`git commit` is OUTPUT TEXT, never a tool command.

- Never execute `git commit`.
- Never send the generated `git commit` command to Bash, PowerShell, or another execution tool.
- Never request approval to execute the generated command.
- Never stage, edit, reset, restore, checkout, or otherwise modify repository state.
- The bundled formatter is the only executable helper this skill may run.
- After a successful formatter result, output it verbatim and STOP.

## Inspect staged changes

Use staged content as the source of truth. Read-only inspection is allowed:

- `git status --short`
- `git diff --cached --stat`
- `git diff --cached`

You may read repository-local commit policy/configuration when needed to determine
whether a type such as `ai` is accepted, but never modify it.

Do not describe unstaged-only changes.

If `git diff --cached` is empty, output exactly:

`ERROR no_staged_changes: no staged changes to commit`

Then STOP.

Determine only:

1. primary intent
2. type
3. optional semantic scope
4. preferred description
5. short fallback description
6. body
7. breaking or non-breaking

## Conventional Commit type

The formatter builds `type(scope)!: description`.

Use one type:

- `feat` — new product or developer-facing capability
- `fix` — bug or incorrect behavior
- `docs` — human/developer documentation only
- `style` — formatting only
- `refactor` — restructure without intended behavior change
- `perf` — performance improvement
- `test` — tests only
- `build` — build, packaging, dependencies
- `ci` — CI configuration
- `ai` — AI agents, harnesses, prompts, skills, model routing, or agent configuration
- `chore` — maintenance not covered above
- `revert` — revert a previous change

`ai` is a local Conventional Commits-compatible extension. Conventional Commits
allows additional types beyond `feat` and `fix`; repository-local tooling may
still impose a narrower allow-list. If an explicit repository policy rejects
`ai`, obey that policy and choose the closest allowed type by semantic intent.
Do not default to `docs` merely because AI configuration is stored in Markdown.

Choose the PRIMARY INTENT, not every changed file.
Choose type from semantic purpose, not file extension or directory alone.

### AI harness classification

Use `ai` when the primary purpose is to configure, instruct, extend, or constrain
AI development agents or their harnesses.

Strong signals include changes primarily concerning:

- `.agents/**`
- `.codex/**`
- `.opencode/**`
- `.claude/**`
- `AGENTS.md`
- `CLAUDE.md`
- agent skills
- system/project prompts
- subagent definitions
- model selection or routing
- tool-use instructions
- AI review/implementation policies
- AI-specific repository conventions

These paths are signals, not absolute rules. If an AI file is only being aligned
to a larger change whose primary intent is `ci`, `build`, `feat`, `fix`, etc., use
the larger semantic intent.

Examples:

Changed:
- `AGENTS.md`
- `.codex/agents/reviewer.toml`

Good: `ai: strengthen adversarial review routing`
Bad: `docs: update agent documentation`

Changed:
- `.agents/skills/strict-conventional-commit/SKILL.md`
- `.agents/skills/strict-conventional-commit/scripts/commit_format.py`

Good: `ai(commit): make commit generation harness-independent`
Bad: `docs: update commit skill`
Bad: `chore: update agent files`

Changed:
- `.github/workflows/verify.yml`
- `.agents/skills/verify/SKILL.md`

If the skill merely follows a changed CI workflow, prefer a `ci` commit rather
than `ai`.

## Scope

Scope is optional. Prefer one short repository-native term when it adds useful
semantic information.

The scope SHOULD identify the affected product domain, feature, subsystem, or
architectural boundary. It SHOULD NOT merely name the tool, framework, or folder
containing the changed artifact when a more informative domain is available.

Prefer scopes such as:

- `auth`
- `parser`
- `ui`
- `content-submission`
- `admin`
- `importer`

Repository-native underscores are also allowed, for example
`content_submission`. Conventional Commits does not require kebab-case.

Avoid generic container scopes such as `openspec`, `docs`, `github`, `codex`, or
`claude` when the staged change clearly belongs to a more useful product domain.
Use those scopes when the tool/framework/harness itself is actually the subject.

Omit scope when it is vague, spans unrelated domains, or competes with a useful
description.

### OpenSpec scope rules

OpenSpec documents often describe another feature. In that case:

- type is normally `docs` when only OpenSpec planning/specification artifacts change;
- scope should normally identify the feature/domain described by those artifacts;
- `openspec` is appropriate only when OpenSpec itself is the subject of the change.

Examples:

Changed:
- `openspec/changes/harden-content-submission-asset-integrity/specs/**`
- `openspec/changes/harden-content-submission-asset-integrity/tasks.md`

Good: `docs(content-submission): define external asset provenance rules`
Bad: `docs(openspec): update asset integrity plan`

Changed:
- `openspec/config.yaml`
- `openspec/schemas/spec-driven/**`

Good: `docs(openspec): tighten change validation requirements`

Changed:
- `AGENTS.md`
- `.codex/agents/planner.toml`

Primary intent: constrain how AI agents operate on OpenSpec changes.

Good: `ai(openspec): protect completed changes from plan updates`

This distinction is intentional:

- **type** = nature of the change
- **scope** = affected semantic domain

## Descriptions

Provide TWO semantically equivalent descriptions to the formatter:

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

Formatting is deterministic and belongs exclusively to the bundled formatter:

- header target: <=50 characters
- header hard maximum: <=60 characters
- body/footer hard maximum: <=72 characters per line

Never manually count or wrap text.
Do not use ad-hoc Bash, `printf`, `wc`, Python snippets, calculators, or other
length tools. Running the bundled formatter script is explicitly allowed.

The formatter prefers a <=50 header and allows 51-60 only when needed. When a
semantic scope was supplied, it tries the short equivalent description before
discarding that scope; scope removal is a later length fallback.

## Mandatory body

Always provide a body. One concise sentence is usually enough.
It must add useful context beyond the header and stay grounded in the staged diff.

Pass ordinary UNWRAPPED text to the formatter.
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
| tests/docs/CI/AI harness only | usually NO |

Look for aliases, fallbacks, adapters, deprecated APIs that still work, and
transparent migrations. If existing consumers still work unchanged, it is not
breaking.

## Breaking text

For a breaking change, provide `breaking` containing only the incompatibility or
migration text. Do not add the `BREAKING CHANGE:` prefix yourself.

The formatter automatically adds:

- `!` to the header
- `BREAKING CHANGE:` footer
- final punctuation
- 72-character wrapping

For non-breaking changes omit `breaking`.

## Formatter protocol

Resolve `scripts/commit_format.py` relative to this `SKILL.md`, not relative to
the repository working directory.

Run the bundled formatter after semantic analysis. Supply a JSON object on
standard input with:

- `type`
- optional `scope`
- `description`
- `short_description`
- `body`
- optional `breaking`

Conceptual invocation:

`python3 <skill-dir>/scripts/commit_format.py --shell auto`

with the structured JSON input passed via stdin by the host execution mechanism.
Do not create a repository file merely to pass formatter input.

`--shell auto` emits POSIX quoting on macOS/Linux and PowerShell quoting on
Windows. `--shell posix` or `--shell powershell` may be used when the target
shell is known explicitly.

A successful formatter result starts with `git commit`.
Output that entire result VERBATIM and STOP.

Do not recount, rewrap, rebuild, explain, or invoke another tool after success.

If the formatter returns `ERROR`, fix only the reported semantic input and retry
once. Do not perform manual counting.

## Output contract

Successful final response = only the formatter result.

No Markdown fences.
No prose.
No XML or JSON.
No alternatives.
No validation report.
No extra commands.

The command may contain physical newlines inside a quoted body/footer because
those are wrapped message lines, not additional shell commands.

Never execute it. Output it and STOP.
