#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = ["pyyaml"]
# ///
"""Diff Hermes Agent capability churn (skills, toolsets, plugins, config schema) between two
upstream tags and map it against the repo's Hermes config.yaml. Static only: fetches source via
`gh api` and parses it with ast/yaml; nothing from upstream is executed."""
import argparse
import ast
import json
import re
import subprocess
import sys
import urllib.parse

import yaml

REPO = "NousResearch/hermes-agent"
DEFAULTS_FILES = ("hermes_cli/config_defaults.py", "hermes_cli/config.py")
PRIVACY_RE = re.compile(r"telemetry|metric|analytic|update|catalog|share|report|remote|cloud|sync|upload|phone|track", re.I)
GATING_RE = re.compile(r"platform_toolsets|known_builtin_toolsets|known_plugin_toolsets|disabled_toolsets|skills|plugins|toolset", re.I)


def gh(path, raw=False):
  cmd = ["gh", "api", path]
  if raw:
    cmd += ["-H", "Accept: application/vnd.github.raw"]
  r = subprocess.run(cmd, capture_output=True, text=True)
  if r.returncode != 0:
    return None
  return r.stdout


def raw(path, ref):
  return gh(f"repos/{REPO}/contents/{path}?ref={urllib.parse.quote(ref, safe='')}", raw=True)


def tree(ref):
  out = gh(f"repos/{REPO}/git/trees/{urllib.parse.quote(ref, safe='')}?recursive=1")
  if out is None:
    sys.exit(f"cannot read tree for {ref}")
  data = json.loads(out)
  if data.get("truncated"):
    sys.exit(f"tree for {ref} is truncated; fall back to a blobless clone")
  return {e["path"] for e in data["tree"] if e["type"] == "blob"}


def skill_dirs(paths, root):
  return {p[: -len("/SKILL.md")] for p in paths if p.startswith(root + "/") and p.endswith("/SKILL.md")}


def plugin_dirs(paths):
  return {p[: -len("/plugin.yaml")] for p in paths if p.startswith("plugins/") and p.endswith("/plugin.yaml")}


def frontmatter(text):
  if not text or not text.startswith("---"):
    return {}
  try:
    return yaml.safe_load(text.split("---", 2)[1]) or {}
  except yaml.YAMLError:
    return {}


def assigned(tree_, name):
  for n in tree_.body:
    tgt = n.targets[0] if isinstance(n, ast.Assign) else (n.target if isinstance(n, ast.AnnAssign) else None)
    if isinstance(tgt, ast.Name) and tgt.id == name:
      return n.value
  return None


def default_paths(ref):
  for f in DEFAULTS_FILES:
    src = raw(f, ref)
    if not src:
      continue
    node = assigned(ast.parse(src), "DEFAULT_CONFIG")
    if isinstance(node, ast.Dict):
      out = {}

      def walk(d, pre):
        for k, v in zip(d.keys, d.values):
          if isinstance(k, ast.Constant) and isinstance(k.value, str):
            p = pre + (k.value,)
            out[".".join(p)] = v.value if isinstance(v, ast.Constant) else None
            if isinstance(v, ast.Dict):
              walk(v, p)
      walk(node, ())
      return out
  return {}


def configurable_toolsets(ref):
  src = raw("hermes_cli/tools_config.py", ref) or ""
  t = ast.parse(src)
  node = assigned(t, "CONFIGURABLE_TOOLSETS")
  keys = set()
  if isinstance(node, ast.List):
    for el in node.elts:
      if isinstance(el, ast.Tuple) and el.elts and isinstance(el.elts[0], ast.Constant):
        keys.add(el.elts[0].value)
  recent = set()
  node = assigned(t, "_RECENTLY_SHIPPED_TOOLSETS")
  for c in ast.walk(node) if node else []:
    if isinstance(c, ast.Constant) and isinstance(c.value, str):
      recent.add(c.value)
  return keys, recent


def toolset_keys(ref):
  node = assigned(ast.parse(raw("toolsets.py", ref) or ""), "TOOLSETS")
  if not isinstance(node, ast.Dict):
    return set()
  return {k.value for k in node.keys if isinstance(k, ast.Constant)}


def migrations(ref):
  src = raw("hermes_cli/config_migrations.py", ref) or ""
  t = ast.parse(src)
  out = {}
  for n in t.body:
    m = re.fullmatch(r"_migrate_to_(\d+)", getattr(n, "name", "") or "")
    if m:
      out[int(m.group(1))] = ast.get_source_segment(src, n) or ""
  return out


def plugin_toolsets(pdir, paths, ref):
  names = set()
  for p in sorted(paths):
    if p.startswith(pdir + "/") and p.endswith(".py") and p.count("/") == pdir.count("/") + 1:
      src = raw(p, ref) or ""
      if "register_tool(" not in src:
        continue
      found = set(re.findall(r"toolset\s*=\s*[\"']([\w-]+)[\"']", src))
      found |= set(re.findall(r"^TOOLSET\s*=\s*[\"']([\w-]+)[\"']", src, re.M))
      names |= found or {"?"}
  return names


def main():
  ap = argparse.ArgumentParser()
  ap.add_argument("old")
  ap.add_argument("new")
  ap.add_argument("--config", default="kubernetes/apps/ai/hermes/app/resources/config.yaml")
  ap.add_argument("--platform", default="buzz")
  a = ap.parse_args()

  cfg = yaml.safe_load(open(a.config)) or {}
  plat = a.platform
  disabled_skills = set((cfg.get("skills") or {}).get("disabled") or [])
  allowed = set((cfg.get("platform_toolsets") or {}).get(plat) or [])
  disabled_ts = set((cfg.get("agent") or {}).get("disabled_toolsets") or [])
  known_builtin = set((cfg.get("known_builtin_toolsets") or {}).get(plat) or [])
  known_plugin = set((cfg.get("known_plugin_toolsets") or {}).get(plat) or [])
  enabled_plugins = set((cfg.get("plugins") or {}).get("enabled") or [])
  ours_version = cfg.get("_config_version")

  old_t, new_t = tree(a.old), tree(a.new)
  print(f"# Hermes churn {a.old} -> {a.new} (platform: {plat})\n")

  print("## Config schema migrations")
  om, nm = migrations(a.old), migrations(a.new)
  old_v, new_v = max(om, default=0), max(nm, default=0)
  print(f"- latest migration: {a.old}={old_v}, {a.new}={new_v}; repo config `_config_version`={ours_version}")
  new_migs = [v for v in sorted(nm) if v > (ours_version or old_v)]
  if not new_migs:
    print("- no new migrations")
  for v in new_migs:
    body = nm[v]
    flag = " **[touches gating keys]**" if GATING_RE.search(body) else ""
    doc = (ast.get_docstring(ast.parse(body).body[0]) or "").split("\n")[0]
    comments = " ".join(l.strip().lstrip("# ") for l in body.splitlines()[1:6] if l.strip().startswith("#"))
    print(f"- `_migrate_to_{v}`{flag}: {doc or comments or '(no description; read the source)'}")
  print()

  print("## Bundled skills (seeded ENABLED on upgrade unless in skills.disabled)")
  ob, nb = skill_dirs(old_t, "skills"), skill_dirs(new_t, "skills")
  oo, no = skill_dirs(old_t, "optional-skills"), skill_dirs(new_t, "optional-skills")
  base = lambda s: {p.rsplit("/", 1)[1] for p in s}
  added = sorted(nb - ob, key=lambda p: p.rsplit("/", 1)[1])
  if not added:
    print("- none added")
  for p in added:
    fm = frontmatter(raw(p + "/SKILL.md", a.new))
    name = fm.get("name") or p.rsplit("/", 1)[1]
    hermes = ((fm.get("metadata") or {}).get("hermes") or {})
    req = hermes.get("requires_toolsets") or fm.get("requires_toolsets")
    pre = fm.get("prerequisites")
    state = "disabled in config" if name in disabled_skills else "**NEW, ENABLED**"
    extra = [f"{k}={v}" for k, v in (("platforms", fm.get("platforms")), ("requires_toolsets", req), ("prerequisites", pre)) if v]
    print(f"- `{name}` ({p}) — {state}: {str(fm.get('description', '')).strip()}"
          + "".join(f" | {e}" for e in extra))
  for p in sorted(ob - nb):
    n = p.rsplit("/", 1)[1]
    where = "moved to optional-skills" if n in base(no) else "removed upstream"
    state = "disabled in config" if n in disabled_skills else "**orphan PVC copy stays enabled and stops updating**"
    print(f"- removed from bundled: `{n}` — {where}; {state}")
  print(f"- optional-skills: +{len(no - oo)} / -{len(oo - no)} (hub-installable only; matters if installed)")
  stale = sorted(n for n in disabled_skills if n not in base(nb) | base(no))
  if stale:
    print(f"- `skills.disabled` names absent from {a.new} bundled+optional: {stale} (may be local/hub-only or stale)")
  print()

  print(f"## Built-in toolsets ({plat} uses an explicit platform_toolsets list)")
  oc, _ = configurable_toolsets(a.old)
  nc, recent = configurable_toolsets(a.new)
  ok, nk = toolset_keys(a.old), toolset_keys(a.new)
  for k in sorted((nc - oc) | (nk - ok)):
    state = ("enabled (listed)" if k in allowed else "denied (agent.disabled_toolsets)" if k in disabled_ts
             else "declined (known_builtin_toolsets)" if k in known_builtin else "off unless a migration or _RECENTLY_SHIPPED adds it")
    print(f"- new toolset `{k}`{' (configurable)' if k in nc else ''}: {state}")
  for k in sorted((oc - nc) | (ok - nk)):
    ref = [w for w, s in (("platform_toolsets", allowed), ("agent.disabled_toolsets", disabled_ts)) if k in s]
    print(f"- removed toolset `{k}`{' — referenced in ' + ', '.join(ref) if ref else ''}")
  if recent:
    for k in sorted(recent):
      hit = k in disabled_ts or k in known_builtin or k in allowed
      print(f"- `_RECENTLY_SHIPPED_TOOLSETS` has `{k}`: {'covered' if hit else '**AUTO-ENABLES on ' + plat + ' — add to agent.disabled_toolsets if unwanted**'}")
  if not ((nc ^ oc) | (nk ^ ok) | recent):
    print("- no toolset changes; `_RECENTLY_SHIPPED_TOOLSETS` empty")
  print()

  print("## Bundled plugins")
  op, np_ = plugin_dirs(old_t), plugin_dirs(new_t)
  for p in sorted(np_ - op):
    meta = yaml.safe_load(raw(p + "/plugin.yaml", a.new) or "") or {}
    ts = plugin_toolsets(p, new_t, a.new)
    desc = " ".join(str(meta.get("description", "")).split())[:160]
    line = f"- added `{meta.get('name', p)}` ({p}, kind={meta.get('kind', '?')}): {desc}"
    if ts:
      states = []
      for t_ in sorted(ts):
        covered = t_ in disabled_ts or t_ in known_plugin
        states.append(f"`{t_}` {'covered' if covered else '**default ON for ' + plat + ' unless platform-restricted**'}")
      line += " | registers toolset(s): " + ", ".join(states)
    print(line)
  for p in sorted(op - np_):
    n = p.rsplit("/", 1)[1]
    print(f"- removed `{p}`{' — listed in plugins.enabled' if n in enabled_plugins else ''}")
  if not (np_ ^ op):
    print("- no plugin changes")
  print()

  print("## Config keys")
  od, nd = default_paths(a.old), default_paths(a.new)
  mine = set()

  def w(d, pre):
    for k, v in d.items():
      p = pre + (str(k),)
      mine.add(".".join(p))
      if isinstance(v, dict):
        w(v, p)
  w(cfg, ())
  dropped = sorted(k for k in mine if k in od and k not in nd)
  print(f"- repo keys dropped from DEFAULT_CONFIG (renamed, removed, or moved to a plugin; verify still read): {dropped or 'none'}")
  new_priv = sorted(k for k in set(nd) - set(od) if PRIVACY_RE.search(k))
  print(f"- new default keys matching privacy terms ({len(new_priv)}):")
  for k in new_priv:
    print(f"  - `{k}` = {nd[k]!r}{' (pinned in repo)' if k in mine else ''}")
  changed = sorted(k for k in set(od) & set(nd) if od[k] != nd[k] and od[k] is not None and nd[k] is not None and k not in mine)
  print(f"- changed constant defaults not pinned in repo ({len(changed)}):")
  for k in changed:
    print(f"  - `{k}`: {od[k]!r} -> {nd[k]!r}")


if __name__ == "__main__":
  main()
