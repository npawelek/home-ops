# Hermes Agent upgrades (`nousresearch/hermes-agent`)

Read this when a PR bumps the `nousresearch/hermes-agent` image (`kubernetes/apps/ai/hermes/app/helmrelease.yaml`).
Release notes alone miss the risk that matters most here: an upgrade changes **what the agent can
do**, not only how the code behaves. New skills get seeded enabled, plugins can register toolsets,
and config migrations rewrite `config.yaml`. The repo's `kubernetes/apps/ai/hermes/app/resources/config.yaml`
is the source of truth (`init.sh` installs it over the live file on every boot), so any churn that
needs a decision has to land as a config.yaml edit, ideally in the same PR before merge.

## How each surface behaves on upgrade

| Surface | Upgrade behaviour | Repo control |
|---|---|---|
| Bundled skills (`skills/`) | New ones are copied to the PVC and **enabled**. Deleted ones stay deleted (`.bundled_manifest`). Skills removed upstream leave an orphan PVC copy that stays enabled and never updates. | `skills.disabled` (denylist; there is no allowlist). `hermes-agent` is essential and cannot be disabled. |
| Optional skills (`optional-skills/`) | Only present if hub-installed. | `skills.disabled` or `hermes skills uninstall`. |
| Built-in toolsets | Buzz uses an explicit `platform_toolsets.buzz` list, so a new toolset stays off, **except** when a config migration appends it (v0.21→0.23 `_migrate_to_45` appended `connections`) or it is in `_RECENTLY_SHIPPED_TOOLSETS`. | `agent.disabled_toolsets` (subtracted last) or `known_builtin_toolsets.buzz` (recorded decline). |
| Plugin toolsets | A plugin that calls `register_tool(toolset=…)` is **on by default** for a platform unless that toolset is known for it. | `known_plugin_toolsets.buzz` and/or `agent.disabled_toolsets`. |
| Config schema | `_migrate_to_N` functions run at load and rewrite the live config; the repo copy then differs from live until the repo adopts the result. | Bump `_config_version` and adopt the migration's output in the repo config. |
| Defaults | Changed defaults apply silently to every key the repo does not pin. | Pin the key in config.yaml if the new default is unwanted. |

## Procedure

1. Take the old and new tags from the diff: the `tag:` value before `@sha256:` (e.g. `v0.23.3`).
2. Run the churn script from the repo root (needs `gh` auth; about 30 s; static parsing only, nothing upstream runs):
   ```bash
   mise x -- uv run --quiet --script .agents/skills/pr-upgrade-validation/scripts/hermes_churn.py <old> <new>
   ```
   If it exits with "tree … truncated", fall back to a blobless clone
   (`git clone --filter=blob:none --no-checkout https://github.com/NousResearch/hermes-agent`, then
   `git diff --name-status <old> <new> -- skills optional-skills plugins`).
3. Turn every flagged line into a decision. The script reports facts; the value of this stage is the
   judgement about each one against how Hermes is used here (Buzz chat agent, local terminal in the
   pod, SearXNG search, Camofox browser, no delegation/cron/browser toolsets, all egress through the
   VPN proxy, privacy-pinned):
   - **`NEW, ENABLED` skill**: read its description, `requires_toolsets` and `prerequisites`. A skill
     whose required toolset is off for Buzz, or that needs a macOS app, a mailbox or third-party API
     credentials, is inert, so recommend adding it to `skills.disabled`. A skill that would act through tools
     Buzz already has (terminal, file, web) is live the moment the pod rolls; say so explicitly.
     For anything non-obvious, fetch its SKILL.md at the new tag
     (`gh api "repos/NousResearch/hermes-agent/contents/<path>/SKILL.md?ref=<new>" -H "Accept: application/vnd.github.raw"`).
   - **Orphan PVC copy**: recommend adding the name to `skills.disabled` (or keep it if the owner relies on it,
     noting it no longer updates).
   - **Migration `[touches gating keys]`**: fetch `hermes_cli/config_migrations.py` at the new tag and read that
     function. State concretely what it will change in *this* config (e.g. "appends `foo` to
     `platform_toolsets.buzz`"), and whether `agent.disabled_toolsets` / `known_builtin_toolsets` already blocks it.
     Every new migration means `_config_version` in the repo must be bumped and the live config diff
     checked after rollout.
   - **`_RECENTLY_SHIPPED_TOOLSETS` … AUTO-ENABLES**: it turns on for Buzz at runtime. Recommend
     `agent.disabled_toolsets` unless the owner wants it.
   - **Plugin `default ON`**: describe what the toolset's tools do and recommend recording it in
     `known_plugin_toolsets.buzz` (off) or `agent.disabled_toolsets`. `kind=platform` plugins are
     gateway adapters; they matter only if a platform is configured. Config-backend or auth plugins
     change where config or credentials come from, so give those a privacy note.
   - **Dropped pinned key**: the repo sets it but the new defaults no longer have it. Check whether it
     was renamed, moved into a plugin (still read there), or removed (the pin silently stops working).
     If removed, find the replacement in the release notes.
   - **New privacy-term default**: anything that sends data out (telemetry, update checks, catalogs,
     remote config, sharing) should be pinned off in config.yaml. Hermes' own OTLP `monitoring.*`
     exporter is self-hosted and not a privacy concern.
   - **Changed default not pinned**: say what behaviour changes for this deployment and whether to pin it.
4. Plugins installed outside the image (`plugins.enabled`, e.g. `camofox` from
   `NousResearch/hermes-official-plugins`) are versioned separately. Note when the new tag's
   `plugin-catalog/` changes their pinned version or compatibility range.
5. Escalate the component's risk to at least 🟡 MEDIUM and the recommendation to REVIEW REQUIRED when
   any of these appear: a `NEW, ENABLED` skill that acts through enabled tools, an auto-enabling or
   default-ON toolset, a migration touching gating keys, a dropped pinned key, or a new outbound default.
   List the exact config.yaml edits so they can land before the merge.

## Report addition

Add this block under the Hermes component in the Stage 6 report:

```
**Capability churn** (`hermes_churn.py <old> <new>`):

| Surface | Change | Effect on Buzz | Recommended config.yaml edit |
|---------|--------|----------------|------------------------------|
| skill | `foo` added (bundled) | enabled; uses terminal | add `foo` to `skills.disabled` |
| migration | `_migrate_to_55` appends `bar` to platform lists | enables `bar` | add `bar` to `agent.disabled_toolsets`; set `_config_version: 55` |

**Post-merge checks** (after Flux rolls `hermes-0`; never restart it yourself):
- live config matches the ConfigMap:
  `diff <(kubectl -n ai get cm hermes-config -o jsonpath='{.data.config\.yaml}') <(kubectl -n ai exec hermes-0 -c app -- cat /opt/data/config.yaml)`
- Buzz toolsets as expected: `kubectl -n ai exec hermes-0 -c app -- su - hermes -c 'HERMES_HOME=/opt/data hermes tools list --platform buzz'`
- skills as expected: `… hermes skills list`
- no new errors in `/opt/data/logs/errors.log` since the rollout
```

Omit rows for surfaces with no change, but keep the post-merge checks.
