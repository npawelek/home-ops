---
name: pr-upgrade-validation
description: Validate a Renovate PR for breaking changes across the upgrade chain. Parses the diff and PR body, fetches release notes for all intermediate versions, detects breaking change signals, and produces a structured risk report.
argument-hint: <PR#> (e.g. 1389)
allowed-tools: Bash, Read, WebFetch
---

# Skill: PR Upgrade Validation

Validate a Renovate PR for breaking changes before merging. The argument is a PR number.
If no argument was given, ask the user which PR to validate.

---

## Stage 1 — Collect PR data

Run both commands in parallel:

```bash
mise x -- gh pr view <PR#> --json title,body,files
```
```bash
mise x -- gh pr diff <PR#>
```

From the PR body, extract:
- **Package table**: each row gives package name, update type (`major`/`minor`/`patch`/`digest`), and version range (`old → new`)
- **Source URLs**: look for `([source](https://redirect.github.com/<owner>/<repo>))` links in the table — these are the GitHub repos
- **Embedded release notes**: present inside `<details>` blocks under `### Release Notes` — copy them verbatim for Step 3

From the diff, extract for each changed file:
- File path and type (HelmRelease, OCIRepository, HelmRepository, ConfigMap, etc.)
- Removed line (`-`) and added line (`+`) for any `tag:`, `version:`, or `ref:` fields
- The repository/chart name associated with each version change

Build a component list: one entry per changed package with `{name, source_repo, old_version, new_version, update_type, file_path, file_type}`.

---

## Stage 2 — Classify each component

For each component, determine:

**Bump type risk baseline:**
- `major` → HIGH risk baseline regardless of notes
- `minor` → MEDIUM risk baseline
- `patch` / `digest` → LOW risk baseline

**File type determines additional checks:**
- `HelmRelease` with image tag change → container image upgrade; fetch release notes only
- `OCIRepository` or `HelmRepository` with version change → Helm chart upgrade; fetch release notes AND run values diff (Stage 3b)
- `HelmRelease` with chart version change inline → treat as chart upgrade

**App-specific checks** (in addition to Stages 3–5):
- `nousresearch/hermes-agent` → read `references/hermes-agent.md` and run its procedure. Hermes
  upgrades change the agent's skills, toolsets and config schema, and release notes don't show that.

---

## Stage 3 — Fetch release notes

### 3a. Use embedded notes first

If the PR body `### Release Notes` section contains notes for a component, use them directly.
Skip the GitHub API fetch for that component.

### 3b. GitHub API fetch (when notes are missing or incomplete)

Parse the source URL from the PR body table: `https://redirect.github.com/<owner>/<repo>` → `<owner>/<repo>`.

If no source URL is present, infer the GitHub repo from the GHCR image path:
- `ghcr.io/<owner>/<repo>` → try `<owner>/<repo>` as the GitHub repo
- Docker Hub `<owner>/<image>` → try `<owner>/<image>` as the GitHub repo

**Step 1 — Identify release tags in range (bodies stripped to keep output small):**
```bash
mise x -- gh api "repos/<owner>/<repo>/releases?per_page=100" \
  --jq '[.[] | {tag: .tag_name, prerelease: .prerelease}]'
```
Filter to tags between old_version and new_version (inclusive of new, exclusive of old).

**Step 2 — Fetch the full body for each relevant release individually:**

CRITICAL: Never rely on the body field from the list endpoint — it is frequently truncated when many releases are returned in one response. Always fetch each release you intend to scan by its specific tag:
```bash
mise x -- gh api "repos/<owner>/<repo>/releases/tags/<tag>" --jq '.body'
```
Do this for every release in the version range that could contain breaking changes. For a `major` bump, fetch every stable release (prerelease: false) in the range individually. For `minor`/`patch`, at minimum fetch the first and last stable release in range; fetch intermediate ones if the first pass reveals migration language.

If the GitHub repo lookup returns 404, try `<owner>/<repo>-packaging` or `<owner>/<image>` as fallbacks,
then fall back to WebFetch of the project's releases page or CHANGELOG.md.

### 3c. Helm chart values diff (for chart upgrades only)

For each OCIRepository or chart version bump, run:
```bash
mise x -- helm show values oci://<registry>/<chart> --version <old_version> 2>/dev/null > /tmp/helm-old.yaml
mise x -- helm show values oci://<registry>/<chart> --version <new_version> 2>/dev/null > /tmp/helm-new.yaml
diff /tmp/helm-old.yaml /tmp/helm-new.yaml
```

The chart OCI ref is in the OCIRepository manifest at `spec.url` + the version at `spec.ref.tag`.
Read the relevant `ocirepository.yaml` or `helmrepository.yaml` to get the full ref.

Flag any top-level keys or nested value paths that were **removed** or **renamed** — these will
break existing HelmRelease `values:` blocks that reference them.

---

## Stage 4 — Detect breaking change signals

For each component, scan the collected release notes and values diff for these signals:

**Automatic HIGH risk escalation (regardless of semver bump type):**
- Text contains: `breaking change`, `breaking:`, `BREAKING`, `action required`, `migration required`, `must migrate`, `incompatible change`
- Database schema migration is mentioned (e.g. `schema migration`, `db migration`, `run migration`)
- An existing HelmRelease `values:` key was removed or renamed in the chart values diff

**MEDIUM risk signals (note but do not escalate):**
- Text contains: `deprecated`, `removed`, `renamed`, `no longer supported`, `behavior change`
- A default value changed in the chart that the HelmRelease does not override
- Multiple minor versions skipped (gap > 5 releases)

**LOW risk / informational:**
- Only bug fixes and enhancements
- `patch` or `digest` bump with no release notes body

**Do not assume date-encoded tags are nightlies.** Some projects (e.g. Jellyfin 12.x) embed a build
timestamp in their stable image tags (e.g. `12.1.20260915-010956`). If a tag looks date-encoded,
verify by checking the corresponding packaging/release repo: if the matching release is
`prerelease: false`, treat it as stable.

After scanning, set a final risk level per component:
- `🔴 HIGH` — major bump OR breaking change signal detected
- `🟡 MEDIUM` — minor bump with deprecation signals, or large version gap
- `🟢 LOW` — patch/digest with no signals

---

## Stage 5 — Check the changed HelmRelease values

For any component where breaking change signals were found, read the corresponding HelmRelease YAML
file from the diff. Compare the `values:` block against:
- Removed/renamed chart keys (from Stage 3c)
- Any migration instructions found in release notes

Flag specific `values:` keys in the HelmRelease that need to be updated before merging.

---

## Stage 6 — Produce the report

Output a structured markdown report directly in chat. Do not write it to a file unless asked.

### Report format

```
## PR Upgrade Validation: <PR title>

### Summary

| Component | Old Version | New Version | Bump | Risk |
|-----------|-------------|-------------|------|------|
| <name>    | <old>       | <new>       | MAJOR | 🔴 HIGH |

---

### <Component Name> — <Bump Type>: `<old>` → `<new>`

**Risk: 🔴 HIGH / 🟡 MEDIUM / 🟢 LOW**

**Source of notes:** Renovate PR body / GitHub releases API / Web fetch / None found

**Breaking change signals:**
- [list each signal found, with the quote or diff line that triggered it]
- None detected

**Helm values impact:** (chart upgrades only)
- Removed key: `controller.metrics.prometheusRule` — not used in this HelmRelease ✓
- Renamed key: `ingress.className` → `ingress.ingressClassName` — ⚠️ used in HelmRelease line 47

**Release notes summary:**
[2–4 sentence summary of what changed between the versions, focused on operational impact]

**Recommendation:**
- SAFE TO MERGE / REVIEW REQUIRED / DO NOT MERGE
- [specific action items if any, e.g. "Update values key X before merging", "Test DB migration in staging first"]
```

If a component has no release notes available from any source, say so explicitly and mark it
🟡 MEDIUM as a conservative default (unknown risk ≠ no risk).

---

## Error handling

- If `gh pr diff` returns nothing: the PR may have been merged or the branch deleted. Report this and stop.
- If the GitHub API returns 404 for a repo: try the fallback names from Stage 3b, then WebFetch.
- If `helm show values` fails for a version: the chart may not be available in the OCI registry for that version. Note it and skip the values diff for that component.
- If the PR is not a Renovate PR (no package table in body): describe the diff changes found and note that automated release note fetching requires a Renovate-formatted PR body.
- If the PR contains more than 10 components: summarize the table first, then ask the user which components they want deep analysis on before proceeding with Stages 3–5.
