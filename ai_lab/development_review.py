#!/usr/bin/env python3
from __future__ import annotations

import datetime as dt
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "runtime" / "development_review.json"


def load_json(path: Path, default):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return default


def norm(text: str) -> str:
    return " ".join(str(text).strip().lower().replace("&", "and").split())


def bundle_id(council_id: str, features: list[dict]) -> str:
    raw = council_id + "\n" + "\n".join(sorted(norm(x.get("title", "")) for x in features))
    return "review-" + hashlib.sha256(raw.encode("utf-8")).hexdigest()[:12]


def feature_id(item: dict, prefix: str) -> str:
    source_id = str(item.get("id", "")).strip()
    if source_id:
        return source_id
    raw = f"{prefix}:{item.get('title','')}:{item.get('reason','')}"
    return prefix + "-" + hashlib.sha1(raw.encode("utf-8")).hexdigest()[:12]


def dedupe(features: list[dict]) -> list[dict]:
    seen: set[str] = set()
    out: list[dict] = []
    for item in features:
        key = norm(item.get("title", ""))
        if not key or key in seen:
            continue
        seen.add(key)
        out.append(item)
    return out


def main() -> None:
    council = load_json(ROOT / "runtime" / "beta_council.json", {})
    world = load_json(ROOT / "runtime" / "ai_world_state.json", {})
    governance = load_json(ROOT / "runtime" / "development_governance.json", {})
    locked = {str(x) for x in governance.get("locked_categories", [])}

    features: list[dict] = []

    for item in council.get("all_feature_requests", []) if isinstance(council, dict) else []:
        if not isinstance(item, dict):
            continue
        category = str(item.get("category", "feature"))
        features.append({
            "id": feature_id(item, "beta"),
            "title": str(item.get("title", "Untitled request"))[:160],
            "category": category,
            "priority": "P2",
            "source": "beta_council",
            "tester": str(item.get("tester_name", "")),
            "desired_outcome": str(item.get("desired_outcome", ""))[:800],
            "reason": str(item.get("rationale", ""))[:800],
            "safe_content_only_reported": bool(item.get("safe_content_only", False)),
            "requires_code_change": None,
            "locked": category in locked,
        })

    for item in world.get("development_backlog", []) if isinstance(world, dict) else []:
        if not isinstance(item, dict):
            continue
        title = str(item.get("title", "Untitled development task"))[:160]
        match = None
        ntitle = norm(title)
        for existing in features:
            e = norm(existing.get("title", ""))
            if e == ntitle or (e and (e in ntitle or ntitle in e)):
                match = existing
                break
        if match is None:
            match = {
                "id": feature_id(item, "dev"),
                "title": title,
                "category": str(item.get("category", "development")),
                "priority": str(item.get("priority", "P3")).upper(),
                "source": "ai_development_backlog",
                "tester": "",
                "desired_outcome": "",
                "reason": str(item.get("reason", ""))[:800],
                "safe_content_only_reported": False,
                "requires_code_change": bool(item.get("requires_code_change", False)),
                "locked": str(item.get("category", "development")) in locked,
            }
            features.append(match)
        else:
            match["priority"] = str(item.get("priority", match.get("priority", "P2"))).upper()
            match["requires_code_change"] = bool(item.get("requires_code_change", False))
            if item.get("reason"):
                match["reason"] = str(item.get("reason"))[:800]

    features = dedupe(features)

    # Correct the beta "safe_content" label when later development analysis says
    # source/UI/engine work is required.
    for item in features:
        if item.get("requires_code_change") is True:
            item["implementation_class"] = "source_change"
        elif item.get("safe_content_only_reported"):
            item["implementation_class"] = "bounded_content"
        else:
            item["implementation_class"] = "review_required"

    created = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    council_id = str(council.get("council_id", ""))
    review = {
        "schema": 1,
        "bundle_id": bundle_id(council_id, features),
        "created_utc": created,
        "council_id": council_id,
        "status": "prepared",
        "locked_categories": sorted(locked),
        "features": features[:20],
        "policy": {
            "owner_decision_required": True,
            "decisions": ["accept", "hold"],
            "accept_scope": "selected_features_only",
            "auto_merge": False,
            "accept_means": "authorize staged implementation/validation; it does not authorize automatic merge or bypass tests",
        },
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(review, indent=2, ensure_ascii=False), encoding="utf-8")
    print(json.dumps({"ok": True, "bundle_id": review["bundle_id"], "features": len(review["features"])}))


if __name__ == "__main__":
    main()
