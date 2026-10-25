// Documentation validation only: compose the fixed PR #12 change sequence in a fresh temporary copy.
// Usage: node spec-composition-check.mjs <repository> <installed specs-apply.js>
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import {spawnSync} from 'node:child_process';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
const repository = path.resolve(process.argv[2]);
const moduleFile = path.resolve(process.argv[3]);
const {findSpecUpdates, buildUpdatedSpec} = await import(pathToFileURL(moduleFile).href);
const parserFile = path.join(path.dirname(moduleFile), 'parsers/requirement-blocks.js');
const {parseDeltaSpec, extractRequirementsSection, foldRequirementName, diffScenarioNames} = await import(pathToFileURL(parserFile).href);
const temporary = await fs.mkdtemp(path.join(os.tmpdir(), 'pr12-effective-spec-'));
await fs.cp(path.join(repository, 'openspec'), path.join(temporary, 'openspec'), {recursive: true});
const specs = path.join(temporary, 'openspec/specs');
const order = ['migrate-simple-view-model-commands', 'migrate-category-view-model-commands', 'migrate-content-view-model-commands', 'migrate-search-map-commands', 'migrate-content-submission-commands', 'migrate-admin-session-commands', 'migrate-admin-editor-commands'];
const results = [];
for (const change of order) {
  for (const update of await findSpecUpdates(path.join(temporary, 'openspec/changes', change), specs)) {
    const built = await buildUpdatedSpec(update, change, {silent: true});
    assert.deepEqual(built.warnings ?? [], [], `Unexpected prior composition warning for ${change}/${update.id}`);
    await fs.mkdir(path.dirname(update.target), {recursive: true});
    await fs.writeFile(update.target, built.rebuilt);
    results.push({change, spec: update.id, counts: built.counts});
  }
}
const change = 'simplify-migrated-view-model-commands';
const targetSpec = 'command-execution-concurrency';
const targetedOriginalNames = [
  'Only authoritative completion can commit asynchronous data',
  'Search history preserves accepted mutation order',
  'Accepted history persistence survives presentation disposal',
  'Search history deduplication respects repository identity and knowledge',
  'Search history rollback rebases later accepted intentions',
  'History read authority changes at mutation acceptance',
  'Runtime write failure requests bounded history reconciliation',
  'History read demands distinguish stale errors from retry loops',
  'Explicit history refresh registers independent read demand',
  'Editor changes retain an owner-local refresh obligation',
  'Dashboard entry and refresh consumers retain behavior',
  'Admin editor results preserve failure kind and original reporting',
  'Admin editor revocation preserves private physical settlement',
];
const readBlocks = (content) => extractRequirementsSection(content).bodyBlocks;
const scenarioNames = (block) => diffScenarioNames(block, {raw: ''}).missing;
function assertUnique(blocks, label) {
  const names = blocks.map((b) => foldRequirementName(b.name));
  assert.equal(new Set(names).size, names.length, `Duplicate requirement: ${label}`);
  for (const b of blocks) {
    const scenarios = scenarioNames(b);
    assert(scenarios.length > 0, `Orphaned requirement without scenarios: ${label}/${b.name}`);
    assert.equal(new Set(scenarios).size, scenarios.length, `Duplicate scoped scenario: ${label}/${b.name}`);
  }
}
async function inventory(directory, prefix = '') {
  const entries = [];
  for (const e of await fs.readdir(directory, {withFileTypes: true})) {
    if (e.isDirectory()) entries.push(...await inventory(path.join(directory, e.name), path.join(prefix, e.name)));
    else if (e.name === 'spec.md') {
      const text = await fs.readFile(path.join(directory, e.name), 'utf8');
      const blocks = readBlocks(text);
      assertUnique(blocks, prefix);
      entries.push({spec: prefix, text, blocks});
    }
  }
  return entries.sort((a, b) => a.spec.localeCompare(b.spec));
}
const before = await inventory(specs);
const previous = before.find((x) => x.spec === targetSpec);
assert(previous);
for (const name of targetedOriginalNames) assert(previous.blocks.some((b) => b.name === name), `Original target missing from effective baseline: ${name}`);
const updates = await findSpecUpdates(path.join(temporary, 'openspec/changes', change), specs);
assert.equal(updates.length, 1);
const update = updates[0];
assert.equal(update.id, targetSpec);
const delta = parseDeltaSpec(await fs.readFile(update.source, 'utf8'));
assert.equal(delta.modified.length, 13);
assert.equal(delta.renamed.length, 7);
assert.equal(delta.added.length + delta.removed.length, 0);
assert.equal(delta.orphanedRequirements.length + delta.unpairedRenames.length + delta.unappliedContent.length, 0);
const renameMap = new Map(delta.renamed.map(({from, to}) => [from, to]));
assert.equal(renameMap.size, 7);
assert.equal(new Set(renameMap.values()).size, 7);
for (const [from, to] of renameMap) {
  assert(targetedOriginalNames.includes(from));
  assert(!previous.blocks.some((b) => b.name === to), `Rename target already exists: ${to}`);
}
const targetNames = targetedOriginalNames.map((n) => renameMap.get(n) ?? n);
assert.deepEqual(delta.modified.map((b) => b.name).sort(), [...targetNames].sort());
const cli = spawnSync('openspec', ['validate', change, '--type', 'change', '--strict', '--no-interactive'], {cwd: temporary, encoding: 'utf8'});
assert.equal(cli.status, 0, cli.stdout + cli.stderr);
assert.equal(cli.stderr.trim(), '');
assert(!/warning|\[INFO\]/i.test(cli.stdout), 'Unreported validation diagnostic');
const built = await buildUpdatedSpec(update, change, {silent: true});
assert.deepEqual(built.warnings ?? [], []);
assert.deepEqual(built.counts, {added: 0, modified: 13, removed: 0, renamed: 7});
await fs.writeFile(update.target, built.rebuilt);
const after = await inventory(specs);
const current = after.find((x) => x.spec === targetSpec);
const additions = [];
for (const old of previous.blocks) {
  const name = renameMap.get(old.name) ?? old.name;
  const block = current.blocks.find((b) => b.name === name);
  assert(block, `Effective requirement lost: ${name}`);
  if (renameMap.has(old.name)) assert(!current.blocks.some((b) => b.name === old.name), `Old renamed requirement survives: ${old.name}`);
  const oldScenarios = scenarioNames(old);
  const newScenarios = scenarioNames(block);
  for (const scenario of oldScenarios) assert(newScenarios.includes(scenario), `Scenario lost: ${name}/${scenario}`);
  for (const scenario of newScenarios) if (!oldScenarios.includes(scenario)) additions.push({requirement: name, scenario});
  if (!targetedOriginalNames.includes(old.name)) assert.equal(block.raw, old.raw, `Untargeted requirement changed: ${name}`);
}
for (const modified of delta.modified) assert.equal(current.blocks.find((b) => b.name === modified.name)?.raw.trim(), modified.raw.trim(), `Modified body not applied: ${modified.name}`);
for (const spec of before) if (spec.spec !== targetSpec) assert.equal(after.find((x) => x.spec === spec.spec)?.text, spec.text, `Unrelated capability changed: ${spec.spec}`);
assert.equal(current.blocks.length, previous.blocks.length);
assert.equal(additions.length, 3);
const counts = (items) => ({capabilities: items.length, requirements: items.reduce((n, s) => n + s.blocks.length, 0), scenarios: items.reduce((n, s) => n + s.blocks.reduce((sum, b) => sum + scenarioNames(b).length, 0), 0)});
const packageJson = JSON.parse(await fs.readFile(path.resolve(path.dirname(moduleFile), '../../package.json'), 'utf8'));
console.log(JSON.stringify({
  tool: 'Installed OpenSpec buildUpdatedSpec and parseDeltaSpec; no archive/sync command',
  version: packageJson.version,
  applicationOrder: 'RENAMED -> REMOVED -> MODIFIED -> ADDED; MODIFIED uses TO header',
  implementationSha256: createHash('sha256').update(await fs.readFile(moduleFile)).digest('hex'),
  parserSha256: createHash('sha256').update(await fs.readFile(parserFile)).digest('hex'),
  order: [...order, change], priorDeltas: results.length, priorWarnings: [],
  strictChangeValidation: {exit: cli.status, output: cli.stdout.trim(), stderr: cli.stderr.trim()},
  replacements: delta.modified.length, renameLedger: delta.renamed,
  counts: built.counts, warnings: [],
  targetCapability: {name: targetSpec, before: counts([previous]), after: counts([current])},
  allCapabilities: {before: counts(before), after: counts(after)},
  targetedOriginalNames, finalTargetNames: targetNames, addedScenarios: additions,
  checks: {allOriginalTargetsPresent: true, allPreviousRequirementsAvailable: true, originalScenariosPreserved: true, allModifiedBodiesApplied: true, obsoleteRenameHeadersAbsent: true, duplicateOrOrphanRequirements: 0, duplicateScopedScenarios: 0, unrelatedCapabilitiesUnchanged: true},
}, null, 2));
