#!/usr/bin/env python3
"""Offsite backup: copy RustFS buckets to the NAS, back up to a restic repo on the NAS, mirror the repo to Proton Drive.

Usage:
 offsite-backup.py run                 run the steps in OFFSITE_STEPS (default: stage,backup,mirror)
 offsite-backup.py mirror --dry-run    show what the Proton mirror would upload and delete
 offsite-backup.py proton ARGS...      run the Proton Drive CLI (e.g. `proton auth login`)
 offsite-backup.py restic ARGS...      run restic against the NAS repo (e.g. `restic snapshots`)
"""

import datetime
import fcntl
import hashlib
import itertools
import json
import os
import re
import subprocess
import sys
import urllib.request
from pathlib import Path

env = os.environ.get

TOOLS = Path(env("TOOLS_DIR", "/tools"))
OFFSITE = Path(env("OFFSITE_DIR", "/offsite"))
RESTIC_REPO = OFFSITE / "restic"
STAGING = OFFSITE / "staging" / "rustfs"
STATE_DIR = Path(env("STATE_DIR", "/state"))
MIRROR_STATE = OFFSITE / "mirror-state.json"
LAST_RUN = STATE_DIR / "last-run.json"

RESTIC_HOST = "home-ops"
SOURCES = [
  ("longhorn", Path("/sources/longhorn-backupstore"), []),
  ("immich", Path("/sources/immich"), ["thumbs", "encoded-video"]),
  ("rustfs", STAGING, []),
  ("services", Path("/sources/services"), []),
]
RESTIC_KEEP = env("RESTIC_KEEP", "--keep-daily 7 --keep-weekly 4")
PRUNE_WEEKDAY = env("PRUNE_WEEKDAY", "6")
CHECK_WEEKDAY = env("CHECK_WEEKDAY", "6")
CHECK_SUBSET = env("RESTIC_CHECK_SUBSET", "5%")

BUCKETS = env("RUSTFS_BUCKETS", "").split()

PROTON_ROOT = env("PROTON_ROOT", "/my-files/offsite-backups/home-ops").rstrip("/")
PROTON_REPO = f"{PROTON_ROOT}/restic"
PROTON_CLI_VERSION = env("PROTON_CLI_VERSION", "")
PROTON_CLI_SHA512 = env("PROTON_CLI_SHA512", "")
UPLOAD_BATCH = int(env("MIRROR_UPLOAD_BATCH", "25"))
DELETE_BATCH = int(env("MIRROR_DELETE_BATCH", "50"))
MAX_DELETE_FRACTION = float(env("MIRROR_MAX_DELETE_FRACTION", "0.25"))
ALLOW_MASS_DELETE = env("MIRROR_ALLOW_MASS_DELETE", "") == "1"
MAX_BYTES = int(float(env("MIRROR_MAX_GB", "0")) * 1e9)
UPLOAD_ORDER = {"data": 0, "index": 1, "snapshots": 2, "keys": 3, "config": 4}
RESTIC_NAME = re.compile(r"[0-9a-f]{64}")

NOTIFY_URL = env("OFFSITE_NOTIFY_URL", "")


class StepError(Exception):
  pass


def log(msg):
  print(f"{datetime.datetime.now(datetime.UTC):%Y-%m-%dT%H:%M:%SZ} {msg}", flush=True)


def run(cmd, ok=(0,), capture=False):
  log("+ " + " ".join(str(c) for c in cmd))
  p = subprocess.run([str(c) for c in cmd], text=True, capture_output=capture)
  if p.returncode not in ok:
    detail = (p.stderr or p.stdout or "").strip()[-500:] if capture else ""
    raise StepError(f"{Path(str(cmd[0])).name} exited {p.returncode}{': ' + detail if detail else ''}")
  return p


def rclone(*args):
  return run([TOOLS / "rclone", *args, "--config=", "--stats=60s", "--stats-one-line", "--stats-log-level=NOTICE",
              "--transfers=8", "--checkers=16", "--retries=5", "--retries-sleep=30s"])


def restic(*args, ok=(0,)):
  return run([TOOLS / "restic", "--repo", RESTIC_REPO, "--no-cache", *args], ok=ok)


def stage():
  if not BUCKETS:
    raise StepError("RUSTFS_BUCKETS is empty")
  for bucket in BUCKETS:
    rclone("sync", f"rustfs:{bucket}", STAGING / bucket)


def backup():
  if not (RESTIC_REPO / "config").exists():
    if RESTIC_REPO.exists() and any(RESTIC_REPO.iterdir()):
      raise StepError(f"{RESTIC_REPO} is not empty but has no restic config; refusing to init")
    restic("init")
  restic("unlock")
  for tag, path, excludes in SOURCES:
    if not path.is_dir() or not any(path.iterdir()):
      raise StepError(f"source {tag} at {path} is missing or empty")
    args = ["backup", "--host", RESTIC_HOST, "--tag", tag, path]
    for name in excludes:
      args += ["--exclude", path / name]
    restic(*args, ok=(0, 3))
  for tag, _, _ in SOURCES:
    keep = env(f"RESTIC_KEEP_{tag.upper()}", RESTIC_KEEP).split()
    restic("forget", "--host", RESTIC_HOST, "--tag", tag, "--group-by", "host,tags", *keep)
  if is_today(PRUNE_WEEKDAY):
    restic("prune")
  if is_today(CHECK_WEEKDAY):
    restic("check", f"--read-data-subset={CHECK_SUBSET}")


def is_today(weekday):
  return weekday == "*" or int(weekday) == datetime.datetime.now(datetime.UTC).weekday()


def proton_cli():
  if not PROTON_CLI_VERSION or not PROTON_CLI_SHA512:
    raise StepError("PROTON_CLI_VERSION and PROTON_CLI_SHA512 must be set")
  path = STATE_DIR / "bin" / f"proton-drive-{PROTON_CLI_VERSION}"
  if path.exists() and sha512(path) == PROTON_CLI_SHA512:
    return path
  url = f"https://proton.me/download/drive/cli/{PROTON_CLI_VERSION}/linux-x64/proton-drive"
  log(f"downloading {url}")
  path.parent.mkdir(parents=True, exist_ok=True)
  tmp = path.with_suffix(".part")
  with urllib.request.urlopen(url, timeout=300) as r, open(tmp, "wb") as f:
    while chunk := r.read(1 << 20):
      f.write(chunk)
  if sha512(tmp) != PROTON_CLI_SHA512:
    tmp.unlink()
    raise StepError(f"checksum mismatch for {url}")
  tmp.chmod(0o755)
  tmp.replace(path)
  for old in path.parent.glob("proton-drive-*"):
    if old != path:
      old.unlink()
  return path


def sha512(path):
  h = hashlib.sha512()
  with open(path, "rb") as f:
    while chunk := f.read(1 << 20):
      h.update(chunk)
  return h.hexdigest()


def proton(*args, ok=(0,), capture=False):
  return run([proton_cli(), *args], ok=ok, capture=capture)


def local_repo_files():
  files = {}
  for p in RESTIC_REPO.rglob("*"):
    rel = p.relative_to(RESTIC_REPO)
    if rel.parts[0] == "locks" or any(part[0] in ".@#" for part in rel.parts):
      continue
    if p.is_file():
      files[rel.as_posix()] = p.stat().st_size
  return files


def load_state():
  if MIRROR_STATE.exists():
    state = json.loads(MIRROR_STATE.read_text())
  else:
    state = {}
  state.setdefault("files", {})
  state.setdefault("folders", [])
  trashed = state.get("trashed", {})
  state["trashed"] = {n: 0 for n in trashed} if isinstance(trashed, list) else trashed
  return state


def save_state(state):
  tmp = MIRROR_STATE.with_suffix(".tmp")
  tmp.write_text(json.dumps(state, sort_keys=True))
  tmp.replace(MIRROR_STATE)


def upload_key(rel):
  parent = rel.rpartition("/")[0]
  return (UPLOAD_ORDER.get(rel.split("/")[0], 9), parent)


def ensure_folder(path, known):
  if path in known or path == "/my-files":
    return
  parent, _, name = path.rpartition("/")
  ensure_folder(parent, known)
  if proton("filesystem", "info", "--json", path, ok=range(256), capture=True).returncode != 0:
    proton("filesystem", "create-folder", "--json", parent, name, capture=True)
  known.add(path)


def batches(items, size):
  it = iter(items)
  while batch := list(itertools.islice(it, size)):
    yield batch


def gb(n):
  return f"{n / 1e9:.1f} GB"


def mirror(dry_run=False):
  local = local_repo_files()
  if "config" not in local:
    raise StepError(f"{RESTIC_REPO} has no config file; refusing to mirror")
  state = load_state()
  remote = state["files"]
  trashed = state["trashed"]
  uploads = sorted((r for r, s in local.items() if remote.get(r) != s), key=lambda r: (upload_key(r), r))
  deletes = sorted(r for r in remote if r not in local)

  mirrored = sum(remote.values())
  upload_bytes = sum(local[r] for r in uploads)
  delete_bytes = sum(remote[r] for r in deletes)
  pending = sum(trashed.values())
  peak = mirrored + upload_bytes + pending
  final = mirrored - delete_bytes + upload_bytes - sum(remote.get(r, 0) for r in uploads)
  log(f"mirror: {len(local)} local files, {len(remote)} mirrored ({gb(mirrored)}), {len(uploads)} to upload "
      f"({gb(upload_bytes)}), {len(deletes)} to delete ({gb(delete_bytes)}), {len(trashed)} awaiting purge "
      f"({gb(pending)}); peak {gb(peak)}, after {gb(final)}, cap {gb(MAX_BYTES) if MAX_BYTES else 'none'}")

  limit = max(50, int(len(remote) * MAX_DELETE_FRACTION))
  if len(deletes) > limit and not ALLOW_MASS_DELETE:
    raise StepError(f"refusing to delete {len(deletes)} of {len(remote)} remote files (limit {limit}); "
                    "set MIRROR_ALLOW_MASS_DELETE=1 if this is expected")
  delete_first = False
  if MAX_BYTES and peak > MAX_BYTES:
    if final + pending > MAX_BYTES:
      raise StepError(f"mirror would leave {gb(final + pending)} in Proton, over the {gb(MAX_BYTES)} cap; "
                      "nothing uploaded. Shorten retention, prune, or raise MIRROR_MAX_GB")
    delete_first = True
    log("mirror: uploading first would pass the cap, so deleting first; "
        "the remote copy is incomplete until this run finishes")
  if dry_run:
    for r in uploads[:20]:
      print(f"  upload {r} ({local[r]} bytes)")
    for r in deletes[:20]:
      print(f"  delete {r}")
    return

  try:
    proton("filesystem", "list", "--json", "/my-files", capture=True)
  except StepError as e:
    raise StepError(f"Proton CLI cannot list /my-files (sign in with `task offsite:login`): {e}") from e

  if delete_first:
    delete_remote(deletes, state)
  upload_remote(uploads, local, state)
  if not delete_first:
    delete_remote(deletes, state)
  log("mirror: done")


def upload_remote(uploads, local, state):
  remote = state["files"]
  known = set(state["folders"])
  for (_, parent), group in itertools.groupby(uploads, key=upload_key):
    target = f"{PROTON_REPO}/{parent}" if parent else PROTON_REPO
    ensure_folder(target, known)
    state["folders"] = sorted(known)
    for batch in batches(group, UPLOAD_BATCH):
      res = proton_json("filesystem", "upload", "--json", "-f", "replace", "-d", "merge", "-t",
                        *(RESTIC_REPO / r for r in batch), target)
      if res.get("failedItems") or res.get("transferredItems", 0) + res.get("skippedItems", 0) != len(batch):
        raise StepError(f"upload of {len(batch)} files to {target} reported {json.dumps(res)[-500:]}")
      for r in batch:
        remote[r] = local[r]
      save_state(state)
  log(f"mirror: uploads complete, {len(remote)} files mirrored")


def proton_json(*args):
  p = proton(*args, capture=True)
  try:
    return json.loads(p.stdout)
  except ValueError as e:
    raise StepError(f"proton {' '.join(args[:2])} printed unexpected output: {p.stdout.strip()[-300:]!r}") from e


def expect_all_ok(results, what):
  failed = [r for r in results if not r.get("ok")]
  if failed:
    raise StepError(f"{what}: {len(failed)} items failed: {json.dumps(failed)[-500:]}")


def trash_paths(paths):
  while paths:
    p = proton("filesystem", "trash", "--json", *paths, ok=range(256), capture=True)
    if p.returncode == 0:
      expect_all_ok(json.loads(p.stdout), "trash")
      return
    missing = re.search(r"Node not found: (\S+)", p.stdout + p.stderr)
    rest = [x for x in paths if missing and x.rpartition("/")[2] != missing.group(1)]
    if not missing or len(rest) == len(paths):
      raise StepError(f"trash exited {p.returncode}: {(p.stderr or p.stdout).strip()[-300:]}")
    log(f"mirror: {missing.group(1)} is already gone from its folder")
    paths = rest


def delete_remote(deletes, state):
  remote, trashed = state["files"], state["trashed"]
  for batch in batches(deletes, DELETE_BATCH):
    trash_paths([f"{PROTON_REPO}/{r}" for r in batch])
    for r in batch:
      trashed[r.rpartition("/")[2]] = remote.pop(r)
    save_state(state)
  in_trash = {}
  for n in proton_json("filesystem", "list", "--json", "/trash"):
    if n.get("type") == "file" and n.get("name", {}).get("ok"):
      in_trash[n["name"]["value"]] = n.get("totalStorageSize", 0)
  gone = [n for n in trashed if n not in in_trash]
  for n in gone:
    del trashed[n]
  if gone:
    save_state(state)
  stray = sorted(n for n in in_trash if RESTIC_NAME.fullmatch(n) and n not in trashed)
  if stray:
    log(f"mirror: purging {len(stray)} replaced copies from the trash ({gb(sum(in_trash[n] for n in stray))})")
  for batch in batches(sorted(trashed) + stray, DELETE_BATCH):
    expect_all_ok(proton_json("filesystem", "delete", "--json", *(f"/trash/{n}" for n in batch)), "delete")
    for n in batch:
      trashed.pop(n, None)
    save_state(state)


def notify(step, error):
  if not NOTIFY_URL:
    return
  body = json.dumps({
    "involvedObject": {"kind": "CronJob", "namespace": "storage", "name": "offsite-backup"},
    "severity": "error",
    "reason": "OffsiteBackupFailed",
    "message": f"step {step} failed: {error}",
    "reportingController": "offsite-backup",
    "metadata": {"cluster": "home-ops"},
  }).encode()
  req = urllib.request.Request(NOTIFY_URL, data=body, headers={"Content-Type": "application/json"})
  try:
    urllib.request.urlopen(req, timeout=15).close()
  except OSError as e:
    log(f"could not deliver failure notification: {e}")


def run_steps():
  steps = {"stage": stage, "backup": backup, "mirror": mirror}
  wanted = env("OFFSITE_STEPS", "stage,backup,mirror").split(",")
  record = {"started": datetime.datetime.now(datetime.UTC).isoformat(), "steps": {}}
  for name in wanted:
    log(f"== step {name}")
    try:
      steps[name]()
    except Exception as e:
      log(f"step {name} failed: {e}")
      notify(name, e)
      return 1
    record["steps"][name] = datetime.datetime.now(datetime.UTC).isoformat()
  LAST_RUN.write_text(json.dumps(record, indent=2))
  log("all steps succeeded")
  return 0


def acquire_lock():
  STATE_DIR.mkdir(parents=True, exist_ok=True)
  f = open(STATE_DIR / "run.lock", "w")
  try:
    fcntl.flock(f, fcntl.LOCK_EX | fcntl.LOCK_NB)
  except BlockingIOError:
    f.close()
    return None
  return f


def main(argv):
  cmd = argv[1] if len(argv) > 1 else "run"
  if cmd in ("run", "mirror"):
    held = acquire_lock()
    if held is None:
      log(f"another run holds {STATE_DIR / 'run.lock'}; not starting")
      return 0 if cmd == "run" else 1
  if cmd == "run":
    return run_steps()
  if cmd == "mirror":
    mirror(dry_run="--dry-run" in argv[2:])
    return 0
  if cmd == "proton":
    return subprocess.run([str(proton_cli()), *argv[2:]]).returncode
  if cmd == "restic":
    return subprocess.run([str(TOOLS / "restic"), "--repo", str(RESTIC_REPO), "--no-cache", *argv[2:]]).returncode
  print(__doc__, file=sys.stderr)
  return 2


if __name__ == "__main__":
  sys.exit(main(sys.argv))
