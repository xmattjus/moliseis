---
name: staged-changes-code-review
description: Run a comprehensive (bugs, coverage, maintainability, simplicity, testability, guidelines-adherence, docs, type-safety) code review on staged changes.
---

## Step 1: Define Agents to Launch

Define a list of **code review agents** to launch (IN PARALLEL) from the following:
1. `code-bugs-reviewer` - logical bugs, race conditions, edge cases
2. `code-coverage-reviewer` - test coverage
3. `code-maintainability-reviewer` - DRY violations, dead code, coupling
4. `code-simplicity-reviewer` - over-engineering, complexity
5. `code-testability-reviewer` - testability, mocking friction
6. `guidelines-adherence-reviewer` - CLAUDE.md compliance
7. `docs-reviewer` - documentation accuracy
8. `type-safety-reviewer` - type safety, dynamic/Object abuse

**If no user intent detected:** the list must contain all code review agents.

## Step 2: Launch Agents

**Scope:** $ARGUMENTS

If no arguments provided, all agents should run `git diff --cached` to focus only on staged changes.

## Step 3: Verification Agent (Final Pass)

After all code review agents complete, launch an Opus plan **verification agent** to reconcile and validate findings:

**Purpose**: The code review agents run in parallel and are unaware of each other's findings. This can lead to:
- Conflicting recommendations (one agent suggests X, another suggests opposite)
- Duplicate findings reported by multiple agents
- Low-confidence or vague issues that aren't actionable
- False positives that would waste time fixing

**Verification Agent Task**:

Use the Task tool to launch a verification agent with this prompt:

```
You are a Review Reconciliation Expert. Analyze the combined findings from all code review agents and produce a final, consolidated report.

## Input
[Include all code review agent reports here]

## Your Tasks

1. **Identify Conflicts**: Find recommendations that contradict each other across code review agents. Resolve by:
   - Analyzing which recommendation is more appropriate given the context
   - Noting when both perspectives have merit (flag for user decision)
   - Removing the weaker recommendation if clearly inferior

2. **Remove Duplicates**: Multiple code review agents may flag the same underlying issue. Consolidate into single entries, keeping the most detailed/actionable version.

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

1. Define the code review agent list to launch
3. Launch all code review agents defined in the list IN PARALLEL in a single message (do NOT run sequentially)
4. After all code review agents complete, launch the verification agent with all findings
5. Present the final consolidated report to the user
6. Ask user about next steps using AskUserQuestion
7. If user chooses to fix, invoke /fix-review-issues with appropriate scope
