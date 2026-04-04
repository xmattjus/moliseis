---
name: git-commit-writer
description: Writes conventional commit messages by analyzing staged git changes. Use when the user asks to commit, write a commit message, or after completing code changes that need to be committed. Supports Conventional Commits format with scope detection and breaking change identification.
_agensi: "3168d680-c73c-4c26-a779-b5c3477119fa"
---

Write precise, informative commit messages following the Conventional Commits specification by analyzing the actual staged changes.

## Step 1: Check for staged changes

Run `git diff --cached --stat` to see what files are staged. If nothing is staged, exit.

## Step 2: Analyze the diff

Run `git diff --cached` to read the actual changes. For large diffs (>500 lines), use `git diff --cached --stat` combined with `git diff --cached -- <file>` for the most important files.

## Step 3: Determine the commit type based on what changed:

Select ONE type that best describes the overall change:
- `feat`: New functionality visible to users
- `fix`: Bug fix
- `refactor`: Code change that neither fixes a bug nor adds a feature
- `docs`: Documentation only
- `style`: Formatting, semicolons, whitespace (no logic change)
- `test`: Adding or updating tests
- `chore`: Build process, dependencies, tooling
- `perf`: Performance improvement
- `ci`: CI/CD configuration changes

## Step 4: Detect the scope from the primary area of change

Use the module name, component name, or directory. Keep it to one word when possible. Omit the scope if changes span too many areas.

## Step 5: Write the commit message

Use the Conventional Commits format:
- Subject line: `type(scope): imperative description` — max 72 characters
- Body (if needed): Explain *what* changed and *why*, not *how*. Wrap at 72 characters.
- Footer: Add `BREAKING CHANGE:` if the commit introduces incompatible changes.

## Step 6: Present the message to the user

Ask for confirmation before committing

## Rules

- Always use imperative mood in the subject ("add" not "added", "fix" not "fixes")
- Never capitalize the first letter after the colon
- Never end the subject with a period
- If multiple logical changes are staged, suggest splitting into separate commits
- If the diff reveals a breaking change (removed public API, changed function signatures, renamed exports), always flag it
- Keep the subject line genuinely descriptive. "update code" or "fix bug" are never acceptable

## Examples

```
feat(auth): add OAuth2 login with Google provider

Implements Google OAuth2 flow using passport-google-oauth20.
Adds callback route, session persistence, and logout endpoint.
Closes #142.
```

```
fix(api): prevent duplicate webhook deliveries on retry

The retry logic was not checking for idempotency keys, causing
duplicate event processing. Added deduplication check using the
X-Idempotency-Key header before dispatching.
```

```
chore(deps): upgrade React from 18.2 to 19.1

BREAKING CHANGE: React 19 removes legacy context API support.
Components using contextType must migrate to useContext hook.
```

```
refactor(db): extract query builder into standalone module
```

```
docs: add API rate limiting section to README
```
