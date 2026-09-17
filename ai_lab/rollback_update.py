#!/usr/bin/env python3
from __future__ import annotations

import datetime as dt
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REQUEST = ROOT / "runtime" / "rollback_request.json"
GATE = ROOT / "runtime" / "development_gate.json"
FLAGS = ROOT / "runtime" / "flagged_features.json"

SAFE_PREFIXES = (
    "scripts/",
    "game_data/",
    "assets/",
    "tests/",
    "tests_ai_lab/",
    "streamlit_lab/",
)
SAFE_EXACT = {"project.godot", "main.tscn", "export_presets.cfg", "streamlit_app.py"}
DENY_PREFIXES = ("runtime/", "reports/", "codex_backlog/", ".github/")


class RollbackError(RuntimeError):
    pass


def run(*args: str, check: bool = True) -> str:
    proc = subprocess.run(args, cwd=ROOT, text=True, capture_output=True)
    if check and proc.returncode != 0:
        raise RollbackError((proc.stderr or proc.stdout or "command failed").strip())
    return proc.stdout.strip()


def load(path: Path, default):
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
        return value if isinstance(value, dict) else default
    except Exception:
        return default


def save(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False), encoding="utf-8")


def allowed_path(path: str) -> bool:
    path = path.strip().replace("\\", "/")
    if not path or path.startswith(DENY_PREFIXES):
        return False
    return path in SAFE_EXACT or path.startswith(SAFE_PREFIXES)


def valid_sha(value: str) -> bool:
    return bool(re.fullmatch(r"[0-9a-fA-F]{40}", value or ""))


def main() -> int:
    request = load(REQUEST, {})
    gate = load(GATE, {})
    flags = load(FLAGS, {"schema": 1, "features": []})

    if request.get("status") != "requested":
        print(json.dumps({"ok": True, "action": "none", "reason": "no pending rollback"}))
        return 0

    bundle = str(request.get("bundle_id", ""))
    if bundle != str(gate.get("bundle_id", "")):
        raise RollbackError("Rollback request does not match the active accepted bundle.")
    if str(gate.get("decision", "")) != "accepted":
        raise RollbackError("Rollback requires an accepted bundle.")
    checkpoint = str(request.get("checkpoint_sha", ""))
    if checkpoint != str(gate.get("rollback_checkpoint_sha", "")) or not valid_sha(checkpoint):
        raise RollbackError("Rollback checkpoint is missing or does not match the accepted gate.")

    # Critical safety invariant: never infer the implementation file set from all
    # commits since acceptance. That could erase unrelated work. The implementation
    # worker/agent must record exactly which files it changed for this bundle.
    changed = [str(x).replace("\\", "/") for x in gate.get("implementation_changed_files", [])]
    changed = sorted({x for x in changed if allowed_path(x)})
    if not changed:
        request["status"] = "blocked"
        request["blocked_reason"] = (
            "No implementation_changed_files manifest exists. Rollback stopped safely "
            "instead of reverting unrelated changes."
        )
        request["updated_utc"] = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        save(REQUEST, request)
        save(GATE, {**gate, "rollback_status": "blocked_no_manifest"})
        print(json.dumps({"ok": False, "action": "blocked", "reason": request["blocked_reason"]}))
        return 3

    # Check checkpoint exists and is an ancestor of current HEAD.
    run("git", "cat-file", "-e", f"{checkpoint}^{{commit}}")
    ancestor = subprocess.run(
        ["git", "merge-base", "--is-ancestor", checkpoint, "HEAD"],
        cwd=ROOT,
        capture_output=True,
    )
    if ancestor.returncode != 0:
        raise RollbackError("Checkpoint is not an ancestor of the current development HEAD.")

    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    backup_branch = f"rollback-backup/{bundle[:40]}-{stamp}".replace(" ", "-")
    run("git", "branch", backup_branch, "HEAD")
    run("git", "push", "origin", backup_branch)

    # Restore only the implementation manifest paths from the checkpoint. This
    # creates a forward rollback commit and leaves repository history intact.
    for path in changed:
        exists_at_checkpoint = subprocess.run(
            ["git", "cat-file", "-e", f"{checkpoint}:{path}"],
            cwd=ROOT,
            capture_output=True,
        ).returncode == 0
        if exists_at_checkpoint:
            run("git", "checkout", checkpoint, "--", path)
        else:
            current = ROOT / path
            if current.exists():
                run("git", "rm", "-f", "--", path)

    reason = str(request.get("reason", "rollback requested"))[:800]
    selected_features = request.get("selected_features", []) if isinstance(request.get("selected_features"), list) else []
    selected_ids = {str(x) for x in request.get("selected_feature_ids", [])}

    existing_flags = {
        str(item.get("id", "")): item
        for item in flags.get("features", [])
        if isinstance(item, dict) and str(item.get("id", ""))
    }
    for item in selected_features:
        if not isinstance(item, dict):
            continue
        fid = str(item.get("id", ""))
        if not fid or fid not in selected_ids:
            continue
        existing_flags[fid] = {
            "id": fid,
            "title": str(item.get("title", ""))[:160],
            "category": str(item.get("category", ""))[:80],
            "status": "rollback_flagged",
            "flagged_utc": dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "bundle_id": bundle,
            "reason": reason,
            "autonomous_reintroduction_allowed": False,
            "manual_clear_required": True,
        }

    flags = {
        "schema": 1,
        "updated_utc": dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "features": sorted(existing_flags.values(), key=lambda x: str(x.get("id", ""))),
    }
    save(FLAGS, flags)

    request.update({
        "status": "completed",
        "completed_utc": dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "restored_files": changed,
        "backup_branch": backup_branch,
    })
    gate.update({
        "implementation_authorized": False,
        "rollback_status": "completed",
        "rollback_completed_utc": request["completed_utc"],
        "rolled_back_files": changed,
        "flagged_feature_ids": sorted(selected_ids),
    })
    save(REQUEST, request)
    save(GATE, gate)

    run("git", "add", "--", *changed, str(REQUEST.relative_to(ROOT)), str(GATE.relative_to(ROOT)), str(FLAGS.relative_to(ROOT)))
    if run("git", "diff", "--cached", "--quiet", check=False) == "":
        # diff --quiet emits no output; use return code explicitly below.
        pass
    proc = subprocess.run(["git", "diff", "--cached", "--quiet"], cwd=ROOT)
    if proc.returncode == 0:
        raise RollbackError("Rollback produced no repository changes.")
    run("git", "commit", "-m", f"rollback: restore pre-implementation state for {bundle}")
    run("git", "push", "origin", "HEAD:ai-development")
    print(json.dumps({
        "ok": True,
        "action": "rolled_back",
        "bundle_id": bundle,
        "files": changed,
        "backup_branch": backup_branch,
        "flagged_features": sorted(selected_ids),
    }))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except RollbackError as exc:
        print(json.dumps({"ok": False, "error": str(exc)}))
        raise SystemExit(2)
