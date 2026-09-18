#!/usr/bin/env python3
from __future__ import annotations

import datetime as dt
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "runtime" / "development_review.json"
TALLY = ROOT / "runtime" / "recommendation_tally.json"

STOPWORDS = {
    "a", "an", "and", "the", "of", "for", "to", "in", "on", "with", "from",
    "add", "new", "feature", "features", "system", "option", "improved", "improve",
    "enhanced", "enhance", "support",
}


def load_json(path: Path, default):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return default


def norm(text: str) -> str:
    return " ".join(str(text).strip().lower().replace("&", "and").split())


def title_tokens(text: str) -> set[str]:
    tokens = re.findall(r"[a-z0-9]+", norm(text))
    return {token for token in tokens if token not in STOPWORDS and len(token) > 1}


def recommendation_similarity(a: str, b: str) -> float:
    na, nb = norm(a), norm(b)
    if not na or not nb:
        return 0.0
    if na == nb:
        return 1.0
    ta, tb = title_tokens(a), title_tokens(b)
    if not ta or not tb:
        return 0.0
    overlap = len(ta & tb)
    if overlap < 2:
        return 0.0
    jaccard = overlap / max(1, len(ta | tb))
    containment = overlap / max(1, min(len(ta), len(tb)))
    return max(jaccard, containment)


def categories_compatible(feature_category: str, family: dict) -> bool:
    category = norm(feature_category)
    categories = {norm(x) for x in family.get("categories", []) if str(x).strip()}
    if not categories:
        return True
    if category in categories:
        return True
    # Development-analysis entries often restate a beta finding under the
    # generic "development" category. Allow title similarity to bridge it.
    return category == "development" or "development" in categories


def family_key(title: str) -> str:
    return "finding-" + hashlib.sha1(norm(title).encode("utf-8")).hexdigest()[:12]


def find_family(feature: dict, families: list[dict]) -> dict | None:
    title = str(feature.get("title", ""))
    category = str(feature.get("category", ""))
    best = None
    best_score = 0.0
    for family in families:
        score = recommendation_similarity(title, str(family.get("canonical_title", "")))
        if score < 0.60:
            continue
        if not categories_compatible(category, family) and score < 0.85:
            continue
        if score > best_score:
            best = family
            best_score = score
    return best


def update_recommendation_tally(
    features: list[dict],
    *,
    council_id: str,
    created_utc: str,
    tally: dict,
) -> tuple[list[dict], dict]:
    families = [
        dict(item) for item in tally.get("families", [])
        if isinstance(item, dict) and str(item.get("key", "")).strip()
    ]

    assigned: dict[str, dict] = {}
    for item in features:
        family = find_family(item, families)
        if family is None:
            family = {
                "key": family_key(str(item.get("title", ""))),
                "canonical_title": str(item.get("title", "Untitled recommendation"))[:160],
                "latest_title": str(item.get("title", "Untitled recommendation"))[:160],
                "categories": [],
                "sources": [],
                "testers": [],
                "council_ids": [],
                "count": 0,
                "first_seen_utc": created_utc,
                "last_seen_utc": created_utc,
            }
            families.append(family)

        category = str(item.get("category", "")).strip()
        source = str(item.get("source", "")).strip()
        tester = str(item.get("tester", "")).strip()
        for field, value in [("categories", category), ("sources", source), ("testers", tester)]:
            values = [str(x) for x in family.get(field, []) if str(x).strip()]
            if value and value not in values:
                values.append(value)
            family[field] = values[-20:]

        councils = [str(x) for x in family.get("council_ids", []) if str(x).strip()]
        if council_id and council_id not in councils:
            councils.append(council_id)
        family["council_ids"] = councils[-100:]
        family["count"] = len(family["council_ids"])
        family["latest_title"] = str(item.get("title", family.get("canonical_title", "")))[:160]
        family["last_seen_utc"] = created_utc
        if not family.get("first_seen_utc"):
            family["first_seen_utc"] = created_utc
        assigned[str(item.get("id", ""))] = family

    annotated: list[dict] = []
    for raw in features:
        item = dict(raw)
        family = assigned.get(str(item.get("id", "")))
        if family:
            item["recommendation_key"] = str(family.get("key", ""))
            item["repeat_count"] = int(family.get("count", 0))
            item["first_seen_utc"] = str(family.get("first_seen_utc", ""))
            item["last_seen_utc"] = str(family.get("last_seen_utc", ""))
        annotated.append(item)

    families.sort(key=lambda x: (-int(x.get("count", 0)), str(x.get("canonical_title", ""))))
    return annotated, {
        "schema": 1,
        "updated_utc": created_utc,
        "families": families[:200],
    }


def normalize_council_utc(value: str, fallback: str = "") -> str:
    raw = str(value or "").strip()
    if re.fullmatch(r"\d{8}T\d{6}Z", raw):
        try:
            parsed = dt.datetime.strptime(raw, "%Y%m%dT%H%M%SZ").replace(tzinfo=dt.timezone.utc)
            return parsed.strftime("%Y-%m-%dT%H:%M:%SZ")
        except ValueError:
            pass
    return raw or fallback


def council_request_features(council: dict) -> list[dict]:
    out: list[dict] = []
    if not isinstance(council, dict):
        return out
    for item in council.get("all_feature_requests", []):
        if not isinstance(item, dict):
            continue
        title = str(item.get("title", "")).strip()
        if not title:
            continue
        out.append({
            "id": feature_id(item, "beta"),
            "title": title[:160],
            "category": str(item.get("category", "feature")),
            "source": "beta_council",
            "tester": str(item.get("tester_name", "")),
        })
    return out


def rebuild_recommendation_tally_from_history(
    *,
    root: Path,
    current_council: dict,
    generated_utc: str,
) -> dict:
    """Rebuild repeat counts from immutable beta-council evidence.

    The tally is derived from council history on every review generation instead
    of trusting the previous tally file. This makes a stale or partially
    committed tally self-healing on the next successful council.
    """
    tally: dict = {"schema": 1, "updated_utc": generated_utc, "families": []}
    seen_councils: set[str] = set()

    for path in sorted((root / "beta_feedback").glob("*/council.json")):
        historical = load_json(path, {})
        if not isinstance(historical, dict):
            continue
        council_id = str(historical.get("council_id", "")).strip()
        if not council_id or council_id in seen_councils:
            continue
        seen_councils.add(council_id)
        seen_utc = normalize_council_utc(
            str(historical.get("created_utc", "")),
            fallback=generated_utc,
        )
        _, tally = update_recommendation_tally(
            council_request_features(historical),
            council_id=council_id,
            created_utc=seen_utc,
            tally=tally,
        )

    current_id = str(current_council.get("council_id", "")).strip() if isinstance(current_council, dict) else ""
    if current_id and current_id not in seen_councils:
        seen_utc = normalize_council_utc(
            str(current_council.get("created_utc", "")),
            fallback=generated_utc,
        )
        _, tally = update_recommendation_tally(
            council_request_features(current_council),
            council_id=current_id,
            created_utc=seen_utc,
            tally=tally,
        )

    # updated_utc describes when this full rebuild was produced, while each
    # family's first/last seen fields describe the actual council chronology.
    tally["updated_utc"] = generated_utc
    return tally


def annotate_features_from_tally(
    features: list[dict],
    *,
    tally: dict,
    generated_utc: str,
) -> list[dict]:
    families = [
        item for item in tally.get("families", [])
        if isinstance(item, dict) and str(item.get("key", "")).strip()
    ]
    annotated: list[dict] = []
    for raw in features:
        item = dict(raw)
        family = find_family(item, families)
        if family:
            item["recommendation_key"] = str(family.get("key", ""))
            item["repeat_count"] = max(1, int(family.get("count", 1)))
            item["first_seen_utc"] = str(family.get("first_seen_utc", generated_utc))
            item["last_seen_utc"] = str(family.get("last_seen_utc", generated_utc))
        else:
            item["recommendation_key"] = family_key(str(item.get("title", "")))
            item["repeat_count"] = 1
            item["first_seen_utc"] = generated_utc
            item["last_seen_utc"] = generated_utc
        annotated.append(item)
    return annotated


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
    flags = load_json(ROOT / "runtime" / "flagged_features.json", {"features": []})
    locked = {str(x) for x in governance.get("locked_categories", [])}
    flagged = {
        str(item.get("id", "")): item
        for item in flags.get("features", [])
        if isinstance(item, dict) and str(item.get("id", ""))
    }

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
            "rollback_flagged": feature_id(item, "beta") in flagged,
            "rollback_flag_reason": str(flagged.get(feature_id(item, "beta"), {}).get("reason", ""))[:800],
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
                "rollback_flagged": feature_id(item, "dev") in flagged,
                "rollback_flag_reason": str(flagged.get(feature_id(item, "dev"), {}).get("reason", ""))[:800],
            }
            features.append(match)
        else:
            match["priority"] = str(item.get("priority", match.get("priority", "P2"))).upper()
            match["requires_code_change"] = bool(item.get("requires_code_change", False))
            if item.get("reason"):
                match["reason"] = str(item.get("reason"))[:800]

    features = dedupe(features)

    for item in features:
        if item.get("requires_code_change") is True:
            item["implementation_class"] = "source_change"
        elif item.get("safe_content_only_reported"):
            item["implementation_class"] = "bounded_content"
        else:
            item["implementation_class"] = "review_required"
        if item.get("rollback_flagged"):
            item["implementation_class"] = "rollback_flagged"
            item["locked"] = True

    created = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    council_id = str(council.get("council_id", ""))
    tally = rebuild_recommendation_tally_from_history(
        root=ROOT,
        current_council=council,
        generated_utc=created,
    )
    features = annotate_features_from_tally(
        features,
        tally=tally,
        generated_utc=created,
    )
    sync_id = "sync-" + hashlib.sha256(
        f"{council_id}\n{created}".encode("utf-8")
    ).hexdigest()[:12]
    tally["sync_id"] = sync_id

    review = {
        "schema": 2,
        "sync_id": sync_id,
        "bundle_id": bundle_id(council_id, features),
        "created_utc": created,
        "council_id": council_id,
        "status": "prepared",
        "locked_categories": sorted(locked),
        "rollback_flagged_feature_ids": sorted(flagged),
        "features": features[:20],
        "policy": {
            "mode": "advisory_monitoring_only",
            "owner_tracking_enabled": True,
            "statuses": ["open", "pending", "close"],
            "auto_implementation": False,
            "note": "AI beta-test recommendations are advisory. The owner manually implements changes with ChatGPT and uses Development Review only to monitor status.",
        },
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(review, indent=2, ensure_ascii=False), encoding="utf-8")
    TALLY.write_text(json.dumps(tally, indent=2, ensure_ascii=False), encoding="utf-8")
    print(json.dumps({
        "ok": True,
        "bundle_id": review["bundle_id"],
        "features": len(review["features"]),
        "repeated_findings": sum(1 for x in tally["families"] if int(x.get("count", 0)) > 1),
    }))


if __name__ == "__main__":
    main()
