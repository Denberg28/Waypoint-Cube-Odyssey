#!/usr/bin/env python3
from __future__ import annotations

import datetime as dt
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
QUEUE_DIR = ROOT / "codex_backlog" / "queue"
ARCHIVE_DIR = ROOT / "codex_backlog" / "archive"
MANIFEST_PATH = ROOT / "codex_backlog" / "manifest.json"
LATEST_PATH = ROOT / "codex_backlog" / "LATEST.md"
MAX_ACTIVE_TASKS = 8


def load_json(path: Path, default):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return default


def slug(text: str) -> str:
    cleaned = "".join(ch.lower() if ch.isalnum() else "-" for ch in str(text))
    while "--" in cleaned:
        cleaned = cleaned.replace("--", "-")
    return cleaned.strip("-")[:64] or "task"


def fingerprint(title: str, reason: str) -> str:
    raw = f"{title.strip().lower()}\n{reason.strip().lower()}".encode("utf-8")
    return hashlib.sha256(raw).hexdigest()[:12]


def priority_rank(value: str) -> int:
    return {"P0": 0, "P1": 1, "P2": 2, "P3": 3}.get(str(value).upper(), 4)


def source_candidates() -> list[dict]:
    council = load_json(ROOT / "runtime" / "beta_council.json", {})
    world = load_json(ROOT / "runtime" / "ai_world_state.json", {})
    candidates: list[dict] = []

    for bug in council.get("high_severity_bugs", []) if isinstance(council, dict) else []:
        if not isinstance(bug, dict):
            continue
        candidates.append({
            "priority": "P1",
            "title": str(bug.get("title", "Investigate high-severity beta finding")),
            "reason": str(bug.get("observed", "Synthetic council reported a high-severity issue.")),
            "acceptance": [
                "Reproduce or falsify the reported issue with deterministic evidence.",
                "Fix the root cause only if reproduced.",
                "Add regression coverage when feasible.",
                "Preserve unrelated gameplay behavior.",
            ],
            "source_ids": [str(bug.get("id", ""))],
            "category": "bug",
        })

    for item in council.get("all_feature_requests", []) if isinstance(council, dict) else []:
        if not isinstance(item, dict) or bool(item.get("safe_content_only", False)):
            continue
        candidates.append({
            "priority": "P2",
            "title": str(item.get("title", "Review beta feature request")),
            "reason": str(item.get("rationale", item.get("desired_outcome", "Synthetic beta council request."))),
            "acceptance": [
                str(item.get("desired_outcome", "Implement the smallest testable version of the requested outcome.")),
                "Use existing architecture before adding a new subsystem.",
                "Keep desktop and Web behavior aligned.",
                "Add or update tests when feasible.",
            ],
            "source_ids": [str(item.get("id", ""))],
            "category": str(item.get("category", "feature")),
        })

    backlog = world.get("development_backlog", []) if isinstance(world, dict) else []
    for item in backlog if isinstance(backlog, list) else []:
        if not isinstance(item, dict) or not bool(item.get("requires_code_change", False)):
            continue
        candidates.append({
            "priority": str(item.get("priority", "P3")).upper(),
            "title": str(item.get("title", "AI development backlog item")),
            "reason": str(item.get("reason", "AI development cycle requested source review.")),
            "acceptance": [
                "Validate the request against current source before editing.",
                "Implement only if it remains relevant to the current build.",
                "Keep the change focused and reversible.",
                "Run relevant tests and report residual risk.",
            ],
            "source_ids": [],
            "category": "development",
        })

    return candidates


def existing_manifest() -> dict:
    value = load_json(MANIFEST_PATH, {})
    return value if isinstance(value, dict) else {}


def build_task(candidate: dict, created: str) -> dict:
    title = candidate["title"].strip()[:160]
    reason = candidate["reason"].strip()[:1200]
    fp = fingerprint(title, reason)
    return {
        "schema": 1,
        "task_id": f"codex-{fp}",
        "fingerprint": fp,
        "status": "queued",
        "priority": candidate.get("priority", "P3"),
        "category": candidate.get("category", "development"),
        "title": title,
        "reason": reason,
        "source_ids": [x for x in candidate.get("source_ids", []) if x][:8],
        "created_utc": created,
        "branch_base": "ai-development",
        "acceptance_criteria": candidate.get("acceptance", [])[:6],
        "constraints": [
            "Read AGENTS.md before implementation.",
            "Do not auto-merge.",
            "Do not modify unrelated gameplay/economy/content.",
            "Prefer deletion/simplification over adding compatibility layers when cleaning architecture.",
            "Preserve Godot 4.7.x Web compatibility.",
        ],
        "validation": [
            "python -m pytest tests_ai_lab -q",
            "Run the repository Godot Web export workflow for Godot/UI changes.",
        ],
    }


def task_markdown(task: dict) -> str:
    lines = [
        f"# {task['priority']} — {task['title']}",
        "",
        f"Task ID: `{task['task_id']}`",
        f"Base branch: `{task['branch_base']}`",
        "",
        "## Why this task exists",
        task["reason"],
        "",
        "## Acceptance criteria",
    ]
    lines.extend(f"- {item}" for item in task["acceptance_criteria"])
    lines += ["", "## Constraints"]
    lines.extend(f"- {item}" for item in task["constraints"])
    lines += ["", "## Validation"]
    lines.extend(f"- `{item}`" if item.startswith("python ") else f"- {item}" for item in task["validation"])
    if task["source_ids"]:
        lines += ["", "## Evidence IDs"]
        lines.extend(f"- `{item}`" for item in task["source_ids"])
    lines += [
        "",
        "## Codex completion contract",
        "Return a focused implementation with a concise summary of root cause, files changed, tests run, and remaining risks. Do not merge automatically.",
        "",
    ]
    return "\n".join(lines)


def main() -> None:
    QUEUE_DIR.mkdir(parents=True, exist_ok=True)
    ARCHIVE_DIR.mkdir(parents=True, exist_ok=True)
    created = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    old = existing_manifest()
    known = {str(item.get("fingerprint", "")) for item in old.get("tasks", []) if isinstance(item, dict)}

    candidates = sorted(source_candidates(), key=lambda x: (priority_rank(x.get("priority", "P3")), x.get("title", "")))
    new_tasks: list[dict] = []
    for candidate in candidates:
        task = build_task(candidate, created)
        if task["fingerprint"] in known:
            continue
        new_tasks.append(task)
        known.add(task["fingerprint"])
        if len(new_tasks) >= MAX_ACTIVE_TASKS:
            break

    manifest_tasks = [item for item in old.get("tasks", []) if isinstance(item, dict)]
    manifest_tasks.extend(new_tasks)
    # Keep manifest bounded; queue files remain the durable handoff artifacts.
    manifest_tasks = manifest_tasks[-100:]
    manifest = {
        "schema": 1,
        "updated_utc": created,
        "active_queue_limit": MAX_ACTIVE_TASKS,
        "tasks": manifest_tasks,
    }
    MANIFEST_PATH.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8")

    for task in new_tasks:
        name = f"{task['priority'].lower()}-{slug(task['title'])}-{task['fingerprint']}.md"
        (QUEUE_DIR / name).write_text(task_markdown(task), encoding="utf-8")

    queued_files = sorted(QUEUE_DIR.glob("*.md"))
    latest = [
        "# Codex Engineering Queue",
        "",
        "This queue is generated from bounded Gemini council/development evidence. It is a handoff for Codex using the ChatGPT product workflow; it does **not** call the OpenAI API from GitHub Actions.",
        "",
        f"Generated: `{created}`",
        f"New tasks this run: **{len(new_tasks)}**",
        f"Queue files present: **{len(queued_files)}**",
        "",
        "## Next tasks",
    ]
    if not queued_files:
        latest.append("- No source-code tasks are currently queued.")
    else:
        for path in queued_files[:MAX_ACTIVE_TASKS]:
            latest.append(f"- `{path.relative_to(ROOT).as_posix()}`")
    latest += [
        "",
        "## Efficient Codex workflow",
        "Open one queue file at a time, ask Codex to implement it on a branch from `ai-development`, run the specified validation, and prepare a reviewable PR. Keep automatic PR review enabled in the Codex/GitHub product settings rather than adding an OpenAI API key to this repository.",
        "",
    ]
    LATEST_PATH.write_text("\n".join(latest), encoding="utf-8")
    print(json.dumps({"ok": True, "new_tasks": len(new_tasks), "queue_files": len(queued_files)}))


if __name__ == "__main__":
    main()
