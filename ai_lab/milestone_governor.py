#!/usr/bin/env python3
from __future__ import annotations

import datetime as dt
import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
STATE_PATH = ROOT / "runtime" / "development_governance.json"
REPORT_PATH = ROOT / "reports" / "DEVELOPMENT_GOVERNANCE.md"

# These are optimization milestones, not release claims. Locking a milestone means
# autonomous agents stop polishing it unless a material regression appears.
MILESTONES = [
    {
        "id": "M1-core-playability-ui",
        "title": "Core playability and UI stability",
        "categories": ["onboarding", "ux", "accessibility", "stability"],
        "min_stable_councils": 6,
        "max_councils": 12,
    },
    {
        "id": "M2-progression-economy",
        "title": "Progression and economy",
        "categories": ["progression", "economy", "marketplace"],
        "min_stable_councils": 6,
        "max_councils": 12,
    },
    {
        "id": "M3-exploration-content",
        "title": "Exploration, content, and retention",
        "categories": ["exploration", "content", "retention"],
        "min_stable_councils": 6,
        "max_councils": 12,
    },
    {
        "id": "M4-release-hardening",
        "title": "Release hardening and regression watch",
        "categories": ["stability", "ux", "accessibility"],
        "min_stable_councils": 8,
        "max_councils": 16,
    },
]

SCORE_FLOOR = {"fun": 3.4, "clarity": 3.6, "friction": 2.6}
DEBT_FLOOR = {"fun": 3.0, "clarity": 3.0, "friction": 3.0}


def load_json(path: Path, default: Any) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return default


def utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def parse_stamp(value: str) -> dt.datetime | None:
    try:
        return dt.datetime.strptime(value, "%Y%m%dT%H%M%SZ").replace(tzinfo=dt.timezone.utc)
    except Exception:
        return None


def council_stamp(council: dict[str, Any]) -> str:
    return str(council.get("created_utc", ""))


def load_councils() -> list[dict[str, Any]]:
    councils: list[dict[str, Any]] = []
    root = ROOT / "beta_feedback"
    if root.exists():
        for path in sorted(root.glob("*/council.json")):
            value = load_json(path, {})
            if isinstance(value, dict) and parse_stamp(council_stamp(value)):
                councils.append(value)
    councils.sort(key=lambda item: council_stamp(item))
    return councils


def _milestone_state(spec: dict[str, Any], status: str = "queued") -> dict[str, Any]:
    return {
        **spec,
        "status": status,
        "activated_utc": "",
        "locked_utc": "",
        "lock_reason": "",
        "councils_seen": 0,
        "stable_streak": 0,
        "optimization_freeze": False,
        "last_evaluation": {},
    }


def default_state(councils: list[dict[str, Any]], now: str) -> dict[str, Any]:
    milestones = [_milestone_state(spec) for spec in MILESTONES]
    milestones[0]["status"] = "active"
    # Count the council that first creates the governance state, but do not use
    # older historical councils to instantly lock a milestone.
    activation = council_stamp(councils[-1]) if councils else now
    milestones[0]["activated_utc"] = activation
    return {
        "schema": 1,
        "policy_version": "1.0",
        "updated_utc": now,
        "active_milestone_id": milestones[0]["id"],
        "locked_categories": [],
        "beta_cadence_hours": 1,
        "development_cadence_hours": 3,
        "milestones": milestones,
    }


def normalized_state(raw: Any, councils: list[dict[str, Any]], now: str) -> dict[str, Any]:
    if not isinstance(raw, dict) or not isinstance(raw.get("milestones"), list):
        return default_state(councils, now)

    by_id = {str(item.get("id")): item for item in raw.get("milestones", []) if isinstance(item, dict)}
    merged = []
    for spec in MILESTONES:
        current = dict(_milestone_state(spec))
        current.update(by_id.get(spec["id"], {}))
        # Policy-owned fields cannot drift through generated state.
        current.update(spec)
        merged.append(current)

    raw = dict(raw)
    raw["schema"] = 1
    raw["policy_version"] = "1.0"
    raw["milestones"] = merged
    raw.setdefault("locked_categories", [])
    return raw


def stable_council(council: dict[str, Any]) -> bool:
    if council.get("high_severity_bugs"):
        return False
    scores = council.get("scores", {}) if isinstance(council.get("scores"), dict) else {}
    try:
        fun = float(scores.get("fun_average", 0))
        clarity = float(scores.get("clarity_average", 0))
        friction = float(scores.get("friction_average", 5))
    except (TypeError, ValueError):
        return False
    return fun >= SCORE_FLOOR["fun"] and clarity >= SCORE_FLOOR["clarity"] and friction <= SCORE_FLOOR["friction"]


def debt_floor_ok(council: dict[str, Any]) -> bool:
    if council.get("high_severity_bugs"):
        return False
    scores = council.get("scores", {}) if isinstance(council.get("scores"), dict) else {}
    try:
        fun = float(scores.get("fun_average", 0))
        clarity = float(scores.get("clarity_average", 0))
        friction = float(scores.get("friction_average", 5))
    except (TypeError, ValueError):
        return False
    return fun >= DEBT_FLOOR["fun"] and clarity >= DEBT_FLOOR["clarity"] and friction <= DEBT_FLOOR["friction"]


def councils_for_milestone(councils: list[dict[str, Any]], milestone: dict[str, Any]) -> list[dict[str, Any]]:
    activated = parse_stamp(str(milestone.get("activated_utc", "")))
    if activated is None:
        return councils
    scoped = []
    for council in councils:
        stamp = parse_stamp(council_stamp(council))
        if stamp is not None and stamp >= activated:
            scoped.append(council)
    return scoped


def stable_streak(councils: list[dict[str, Any]]) -> int:
    streak = 0
    for council in reversed(councils):
        if not stable_council(council):
            break
        streak += 1
    return streak


def cadence_for(locked_count: int, complete: bool) -> tuple[int, int]:
    if complete:
        return 12, 24
    table = {
        0: (1, 3),
        1: (2, 6),
        2: (4, 8),
        3: (6, 12),
    }
    return table.get(locked_count, (6, 12))


def active_index(state: dict[str, Any]) -> int | None:
    for index, milestone in enumerate(state.get("milestones", [])):
        if milestone.get("status") == "active":
            return index
    return None


def evaluate(state: dict[str, Any], councils: list[dict[str, Any]], now: str) -> dict[str, Any]:
    state = dict(state)
    milestones = [dict(item) for item in state.get("milestones", [])]
    state["milestones"] = milestones
    index = active_index(state)

    if index is not None:
        current = milestones[index]
        scoped = councils_for_milestone(councils, current)
        streak = stable_streak(scoped)
        count = len(scoped)
        current["councils_seen"] = count
        current["stable_streak"] = streak
        recent_three = scoped[-3:]
        recent_high = sum(1 for item in recent_three if item.get("high_severity_bugs"))
        current["last_evaluation"] = {
            "council_id": scoped[-1].get("council_id", "") if scoped else "",
            "stable": stable_council(scoped[-1]) if scoped else False,
            "recent_high_severity_councils": recent_high,
        }

        lock_reason = ""
        if streak >= int(current["min_stable_councils"]):
            lock_reason = "stable-threshold"
        elif count >= int(current["max_councils"]) and len(recent_three) == 3 and all(debt_floor_ok(x) for x in recent_three):
            # Bounded-optimization stop: once enough councils have run, accept
            # small remaining imperfections instead of polishing forever.
            lock_reason = "bounded-optimization-threshold"
        elif count >= int(current["max_councils"]):
            # Do not keep generating cosmetic optimization churn. Only material
            # regressions should be worked until the blocking signal clears.
            current["optimization_freeze"] = True

        if lock_reason:
            current["status"] = "locked"
            current["locked_utc"] = now
            current["lock_reason"] = lock_reason
            current["optimization_freeze"] = True
            locked = set(str(x) for x in state.get("locked_categories", []))
            locked.update(str(x) for x in current.get("categories", []))
            state["locked_categories"] = sorted(locked)

            if index + 1 < len(milestones):
                nxt = milestones[index + 1]
                nxt["status"] = "active"
                nxt["activated_utc"] = now
                state["active_milestone_id"] = nxt["id"]
            else:
                state["active_milestone_id"] = ""

    locked_count = sum(1 for item in milestones if item.get("status") == "locked")
    complete = locked_count == len(milestones)
    beta_hours, dev_hours = cadence_for(locked_count, complete)
    state["beta_cadence_hours"] = beta_hours
    state["development_cadence_hours"] = dev_hours
    state["updated_utc"] = now
    return state


def write_report(state: dict[str, Any]) -> str:
    active = state.get("active_milestone_id") or "stability watch"
    lines = [
        "# Development Milestone Governor",
        "",
        f"Active milestone: **{active}**",
        f"Beta council cadence: **every {state.get('beta_cadence_hours', 1)} hour(s)**",
        f"AI development cadence: **every {state.get('development_cadence_hours', 3)} hour(s)**",
        "",
        "## Policy",
        "A milestone is optimization-locked after a sustained stable council streak. A bounded stop also prevents endless polishing after the maximum council window when recent councils have no high-severity regression and remain above the debt floor.",
        "Locked categories reject ordinary optimization requests; high-severity regressions may still create engineering work.",
        "",
        "## Milestones",
    ]
    for item in state.get("milestones", []):
        lines.append(
            f"- **{item.get('id')} — {item.get('title')}**: `{item.get('status')}` · "
            f"councils `{item.get('councils_seen', 0)}` · stable streak `{item.get('stable_streak', 0)}` · "
            f"freeze `{bool(item.get('optimization_freeze'))}`"
        )
    locked = state.get("locked_categories", [])
    lines += ["", "## Locked optimization categories", "- " + (", ".join(locked) if locked else "None yet."), ""]
    return "\n".join(lines)


def main() -> None:
    now = utc_now()
    councils = load_councils()
    state = normalized_state(load_json(STATE_PATH, {}), councils, now)
    state = evaluate(state, councils, now)
    STATE_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    STATE_PATH.write_text(json.dumps(state, indent=2, ensure_ascii=False), encoding="utf-8")
    REPORT_PATH.write_text(write_report(state), encoding="utf-8")
    print(json.dumps({
        "ok": True,
        "active_milestone": state.get("active_milestone_id"),
        "locked_categories": state.get("locked_categories", []),
        "beta_cadence_hours": state.get("beta_cadence_hours"),
        "development_cadence_hours": state.get("development_cadence_hours"),
    }))


if __name__ == "__main__":
    main()
