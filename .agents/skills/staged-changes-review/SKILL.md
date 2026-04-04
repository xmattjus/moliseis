---
name: staged-changes-review
description: Run all code review agents in parallel (bugs, coverage, maintainability, simplicity, type-safety, docs).
---

Run a comprehensive code review.

## Step 1: Check copilot-instructions.md for Reviewer Preferences

Check loaded copilot-instructions.md content for any guidance about which reviewers to run or skip. copilot-instructions.md file is auto-loaded — do NOT search for it.

**Available reviewers** (use your judgment matching user intent):
- `code-bugs-reviewer` - bugs, logic errors
- `code-coverage-reviewer` - test coverage
- `code-maintainability-reviewer` - DRY, dead code, coupling
- `code-simplicity-reviewer` - over-engineering, complexity
- `code-testability-reviewer` - testability, mocking friction
- `copilot-instructions-md-adherence-reviewer` - copilot-instructions.md compliance
- `docs-reviewer` - documentation accuracy
- `type-safety-reviewer` - type safety

**If no preferences stated:** Use defaults (all core agents).

## Step 2: Launch Agents

### Core Agents (launch IN PARALLEL):

1. **code-bugs-reviewer** - Logical bugs, race conditions, edge cases
2. **code-coverage-reviewer** - Test coverage for code changes
3. **code-maintainability-reviewer** - DRY violations, dead code, coupling
4. **code-simplicity-reviewer** - Over-engineering, complexity
5. **code-testability-reviewer** - Testability, mocking friction
6. **copilot-instructions-md-adherence-reviewer** - copilot-instructions.md compliance
7. **docs-reviewer** - Documentation accuracy
8. **type-safety-reviewer** - Type safety, dynamic/Object abuse

**Scope:** $ARGUMENTS

If no arguments provided, all agents should run `git diff --cached` to see what files are staged.

## Step 3: Verification Agent (Final Pass)

After all review agents complete, launch a "plan model" **verification agent** to reconcile and validate findings:

**Purpose**: The review agents run in parallel and are unaware of each other's findings. This can lead to:
- Conflicting recommendations (one agent suggests X, another suggests opposite)
- Duplicate findings reported by multiple agents
- Low-confidence or vague issues that aren't actionable
- False positives that would waste time fixing

**Verification Agent Task**:

Use the Task tool to launch a verification agent with this prompt:

```
You are a Review Reconciliation Expert. Analyze the combined findings from all review agents and produce a final, consolidated report.

## Input
[Include all agent reports here]

## Your Tasks

1. **Identify Conflicts**: Find recommendations that contradict each other across agents. Resolve by:
   - Analyzing which recommendation is more appropriate given the context
   - Noting when both perspectives have merit (flag for user decision)
   - Removing the weaker recommendation if clearly inferior

2. **Remove Duplicates**: Multiple agents may flag the same underlying issue. Consolidate into single entries, keeping the most detailed/actionable version.

3. **Filter Low-Confidence Issues**: Remove or downgrade issues that:
   - Are vague or non-actionable ("could be improved" without specifics)
   - Rely on speculation rather than evidence
   - Would require significant effort for minimal benefit
   - Are stylistic preferences not backed by project standards

4. **Validate Severity**: Ensure severity ratings are consistent and justified:
   - Critical: Will cause production failures or data loss
   - High: Significant bugs or violations that should block release
   - Medium: Real issues worth fixing but not blocking
   - Low: Nice-to-have improvements

5. **Flag Uncertain Items**: For issues where you're uncertain, mark them as "Needs Human Review" rather than removing them.

## Output

Produce a **Final Consolidated Review Report** with:
- Executive summary (overall code health assessment)
- Issues by severity (Critical → Low), deduplicated and validated
- Conflicts resolved (note any that need user decision)
- Items removed with brief reasoning (transparency)
- Recommended fix order (dependencies, quick wins first)
```

## Step 4: Follow-up Action

Ask the user what they'd like to address:

```
header: "Next Steps"
question: "Would you like to address any of these findings?"
options:
  - "Critical/High only (Recommended)" - Focus on issues that should block release
  - "All issues" - Address everything including medium and low severity
  - "Skip" - No fixes needed right now
```

**Based on selection:**
- **Critical/High only**: `Skill("vibe-workflow:fix-review-issues", "--severity critical,high")`
- **All issues**: `Skill("vibe-workflow:fix-review-issues")`
- **Skip**: End workflow

## Execution

1. Check loaded copilot-instructions.md content for reviewer configuration
2. Build final agent list: start with core agents then add custom agents
3. Launch all agents simultaneously in a single message (do NOT run sequentially)
4. After all agents complete, launch the verification agent with all findings
5. Present the final consolidated report to the user
6. Ask user about next steps using AskUserQuestion
7. If user chooses to fix, invoke /fix-review-issues with appropriate scope
