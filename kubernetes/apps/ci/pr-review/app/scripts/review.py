#!/usr/bin/env python3
"""PR reviewer: detects chart version bumps, fetches release notes, posts AI analysis."""

import json
import os
import re
import ssl
import sys
import urllib.request
from urllib.error import HTTPError

GH_TOKEN = os.environ["GH_TOKEN"]
GH_REPO = os.environ["GH_REPO"]
OLLAMA_URL = os.environ.get("OLLAMA_URL", "http://ollama.network.svc.cluster.local:11434")
OLLAMA_MODEL = os.environ.get("OLLAMA_MODEL", "gemma4:e4b")
BOT_MARKER = "<!-- pr-review-bot -->"


def gh(path, method="GET", data=None, accept="application/vnd.github+json"):
    req = urllib.request.Request(
        f"https://api.github.com{path}",
        headers={
            "Authorization": f"Bearer {GH_TOKEN}",
            "Accept": accept,
            "X-GitHub-Api-Version": "2022-11-28",
        },
        method=method,
    )
    if data:
        req.data = json.dumps(data).encode()
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            if accept == "application/vnd.github.diff":
                return r.read().decode()
            return json.loads(r.read())
    except HTTPError as e:
        print(f"GitHub API error {e.code}: {path}", file=sys.stderr)
        return None


def k8s(path):
    token = open("/var/run/secrets/kubernetes.io/serviceaccount/token").read()
    ctx = ssl.create_default_context(
        cafile="/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
    )
    req = urllib.request.Request(
        f"https://kubernetes.default.svc{path}",
        headers={"Authorization": f"Bearer {token}"},
    )
    try:
        with urllib.request.urlopen(req, context=ctx, timeout=10) as r:
            return json.loads(r.read())
    except Exception as e:
        print(f"k8s API error {path}: {e}", file=sys.stderr)
        return None


def ollama(system, user):
    data = {
        "model": OLLAMA_MODEL,
        "stream": False,
        "keep_alive": -1,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
    }
    req = urllib.request.Request(
        f"{OLLAMA_URL}/api/chat",
        data=json.dumps(data).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=300) as r:
        return json.loads(r.read())["message"]["content"]


def find_bumps(diff):
    """Extract version bumps from HelmRelease and OCIRepository files, including container images."""
    bumps = []
    current_file = None
    old_ver = new_ver = None
    resource_name = None
    repository = None

    for line in diff.splitlines():
        if line.startswith("diff --git"):
            if old_ver and new_ver and old_ver != new_ver:
                bumps.append({
                    "file": current_file,
                    "old": old_ver,
                    "new": new_ver,
                    "name": resource_name,
                    "repository": repository,
                })
            current_file = line.split(" b/")[-1]
            old_ver = new_ver = None
            resource_name = None
            repository = None
            continue

        if not current_file:
            continue
        if not re.search(r"helmrelease\.yaml|ocirepository\.yaml", current_file, re.I):
            continue

        # Capture metadata.name and image repository from context lines
        if line.startswith(" "):
            if m := re.match(r'   name:\s+(\S+)', line):
                resource_name = m.group(1)
            if m := re.match(r'.*repository:\s+(\S+)', line):
                repository = m.group(1)

        if m := re.match(r'^-\s+(version|tag):\s+"?([^"#\s]+)', line):
            old_ver = m.group(2)
        elif m := re.match(r'^\+\s+(version|tag):\s+"?([^"#\s]+)', line):
            new_ver = m.group(2)

    if old_ver and new_ver and old_ver != new_ver:
        bumps.append({
            "file": current_file,
            "old": old_ver,
            "new": new_ver,
            "name": resource_name,
            "repository": repository,
        })

    return bumps


def oci_source(oci_url, tag):
    """Resolve org.opencontainers.image.source from an OCI registry manifest."""
    url = oci_url.removeprefix("oci://")
    registry, *parts = url.split("/")
    image = "/".join(parts)

    # Get anonymous pull token (works for public ghcr.io packages)
    try:
        token_url = f"https://{registry}/token?scope=repository:{image}:pull"
        with urllib.request.urlopen(token_url, timeout=10) as r:
            token = json.loads(r.read()).get("token", "")
    except Exception:
        token = ""

    try:
        manifest_url = f"https://{registry}/v2/{image}/manifests/{tag}"
        req = urllib.request.Request(
            manifest_url,
            headers={
                "Accept": "application/vnd.oci.image.manifest.v1+json",
                **({"Authorization": f"Bearer {token}"} if token else {}),
            },
        )
        with urllib.request.urlopen(req, timeout=10) as r:
            manifest = json.loads(r.read())
        return manifest.get("annotations", {}).get("org.opencontainers.image.source")
    except Exception as e:
        print(f"OCI registry error for {oci_url}@{tag}: {e}", file=sys.stderr)
        return None


def resolve_github_repo(bump):
    """Resolve upstream GitHub owner/repo for a version bump."""
    file_path = bump["file"]
    parts = file_path.split("/")
    # Expected: kubernetes/apps/{namespace}/{app}/app/{resource}.yaml
    if len(parts) < 5:
        return None
    namespace = parts[2]
    # Prefer name captured from diff metadata; fall back to directory name
    resource_name = bump.get("name") or parts[3]

    # Container image bump: repository field captured directly from diff (e.g. ghcr.io/owner/repo)
    if bump.get("repository"):
        img = bump["repository"]
        # Strip registry prefix — works for ghcr.io/owner/repo and docker.io/owner/repo
        path = re.sub(r'^[^/]+/', '', img)
        m = re.match(r'([\w.-]+/[\w.-]+)', path)
        return m.group(1) if m else None

    if "ocirepository" in file_path.lower():
        result = k8s(
            f"/apis/source.toolkit.fluxcd.io/v1/namespaces/{namespace}/ocirepositories/{resource_name}"
        )
        if result:
            oci_url = result.get("spec", {}).get("url", "")
            source = oci_source(oci_url, bump["new"])
            if source:
                m = re.search(r"github\.com[/:]([\w.-]+/[\w.-]+?)(?:\.git)?$", source)
                return m.group(1) if m else None

    elif "helmrelease" in file_path.lower():
        result = k8s(
            f"/apis/helm.toolkit.fluxcd.io/v2/namespaces/{namespace}/helmreleases/{resource_name}"
        )
        if result:
            source_ref = (
                result.get("spec", {}).get("chart", {}).get("spec", {}).get("sourceRef", {})
            )
            repo_ns = source_ref.get("namespace", namespace)
            repo_name = source_ref.get("name", "")
            repo = k8s(
                f"/apis/source.toolkit.fluxcd.io/v1/namespaces/{repo_ns}/helmrepositories/{repo_name}"
            )
            if repo:
                url = repo.get("spec", {}).get("url", "")
                m = re.search(r"github\.com[/:]([\w.-]+/[\w.-]+?)(?:\.git)?$", url)
                return m.group(1) if m else None

    return None


def get_release_notes(github_repo, new_version):
    """Fetch release notes for new_version, trying common tag prefix patterns."""
    for prefix in ["", "v", "helm-chart-", "chart-v"]:
        tag = f"{prefix}{new_version}"
        result = gh(f"/repos/{github_repo}/releases/tags/{tag}")
        if result and result.get("body"):
            return result["body"], tag

    releases = gh(f"/repos/{github_repo}/releases?per_page=30")
    if releases:
        for release in releases:
            if new_version in release.get("tag_name", ""):
                return release.get("body", ""), release["tag_name"]

    return None, None


def already_reviewed(pr_number, head_sha):
    comments = gh(f"/repos/{GH_REPO}/issues/{pr_number}/comments?per_page=100")
    if not comments:
        return False
    marker = f"{BOT_MARKER}<!-- sha:{head_sha} -->"
    return any(marker in c.get("body", "") for c in comments)


def post_comment(pr_number, head_sha, body):
    marker = f"{BOT_MARKER}<!-- sha:{head_sha} -->"
    gh(
        f"/repos/{GH_REPO}/issues/{pr_number}/comments",
        method="POST",
        data={"body": f"{marker}\n{body}"},
    )


def review_pr(pr):
    number = pr["number"]
    title = pr["title"]

    print(f"PR #{number}: {title}")

    diff = gh(f"/repos/{GH_REPO}/pulls/{number}", accept="application/vnd.github.diff")
    if not diff:
        return

    bumps = find_bumps(diff)
    if not bumps:
        print("  No chart version bumps detected")
        return

    print(f"  Found {len(bumps)} version bump(s)")
    findings = []

    for bump in bumps:
        label = f"`{bump['file'].split('/')[-2]}` {bump['old']} → {bump['new']}"
        print(f"  {label}")

        github_repo = resolve_github_repo(bump)
        if not github_repo:
            findings.append(f"**{label}** — could not resolve upstream GitHub repo")
            continue

        notes, tag = get_release_notes(github_repo, bump["new"])
        if not notes:
            findings.append(
                f"**{label}** — no release notes found at "
                f"[{github_repo}](https://github.com/{github_repo})"
            )
            continue

        system = (
            "You review Helm chart release notes for a home Kubernetes cluster. "
            "Be concise and technical. Focus only on breaking changes, removed options, "
            "renamed fields, or required migrations. Ignore minor fixes and additions."
        )
        user = (
            f"Chart: {github_repo}\n"
            f"Version: {bump['old']} → {bump['new']} (tag: {tag})\n\n"
            f"Release notes:\n{notes[:6000]}\n\n"
            f"List only breaking changes or required migrations a user must act on when upgrading "
            f"from {bump['old']}. If none exist, say so in one sentence."
        )

        try:
            analysis = ollama(system, user)
            findings.append(f"### {github_repo} — {bump['old']} → {bump['new']}\n\n{analysis}")
        except Exception as e:
            findings.append(f"**{label}** — Ollama error: {e}")

    if findings:
        print("  --- analysis ---")
        for finding in findings:
            print(finding)
        print("  --- end ---")


def main():
    prs = gh(f"/repos/{GH_REPO}/pulls?state=open&per_page=50")
    if not prs:
        print("No open PRs or API error")
        return

    print(f"Checking {len(prs)} open PR(s)")
    for pr in prs:
        try:
            review_pr(pr)
        except Exception as e:
            print(f"Error on PR #{pr['number']}: {e}", file=sys.stderr)


if __name__ == "__main__":
    main()
