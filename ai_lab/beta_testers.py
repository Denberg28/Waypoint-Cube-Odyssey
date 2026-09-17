#!/usr/bin/env python3
from __future__ import annotations
import argparse
import datetime as dt
import json
from collections import Counter
from pathlib import Path

from ai_lab.beta_contracts import BETA_REPORT_SCHEMA, PERSONAS, validate_beta_report
from ai_lab.common import call_gemini
from ai_lab.simulation import simulate_trace

ROOT = Path(__file__).resolve().parents[1]

BASE_SYSTEM = """You are one member of the Waypoint: Cube Odyssey synthetic beta tester council. You are not a developer and you must not write source code. Review the supplied executable play trace, current AI world state, route catalog, and your assigned player persona. Be specific and evidence-based. Do not pretend you observed graphics, timing, audio, or behavior that is absent from the trace. Feedback is advisory. Distinguish bugs from feature requests. Prefer small, testable improvements. Safe content-only requests may adjust narrative, content packs, route incentives, temporary modifiers, or marketplace specials. Engine/source changes must be described only as requests."""


def load(path: Path, default):
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
        return value
    except Exception:
        return default


def offline_report(persona_id: str, trace: dict) -> dict:
    name = PERSONAS[persona_id]["name"]
    base = {
        "session_summary": f"Offline synthetic review by {name}. The trace was completed without source changes.",
        "fun_score": 3,
        "clarity_score": 4 if persona_id == "first_time_player" else 3,
        "friction_score": 2,
        "observations": [],
        "bugs": [],
        "feature_requests": [],
        "keep": ["Keep route preview before starting an adventure.", "Keep Jump as a distinct obstacle-clearing action."],
    }
    if persona_id == "first_time_player":
        base["observations"] = [{"category":"onboarding","severity":"medium","evidence":"The trace starts immediately after route selection and relies on button labels to teach movement.","recommendation":"Add a one-session contextual hint explaining Walk versus Jump."}]
        base["feature_requests"] = [{"title":"First-run movement hint","category":"onboarding","player_value":"Reduces early uncertainty.","rationale":"The core distinction between walking and obstacle jumping is important to learn immediately.","safe_content_only":True,"desired_outcome":"Show a brief non-blocking hint on the first route."}]
    elif persona_id == "explorer_collector":
        base["feature_requests"] = [{"title":"Route-specific collectible rumor","category":"exploration","player_value":"Adds a reason to revisit routes.","rationale":"The trace has route identity but few explicit collection goals.","safe_content_only":True,"desired_outcome":"Feature a rotating collectible rumor tied to one route."}]
    elif persona_id == "combat_challenger":
        base["feature_requests"] = [{"title":"Temporary elite hunt challenge","category":"combat","player_value":"Creates a mastery target without permanent balance changes.","rationale":"Combat rewards are readable but can benefit from a short-term goal.","safe_content_only":True,"desired_outcome":"Offer a bounded elite-focused Night Watch challenge."}]
    elif persona_id == "economy_optimizer":
        base["observations"] = [{"category":"economy","severity":"medium","evidence":"Marketplace purchases compete with route rewards, but there is no rotating value proposition.","recommendation":"Experiment with a small temporary marketplace discount rather than permanent price changes."}]
        base["feature_requests"] = [{"title":"Rotating marketplace discount","category":"marketplace","player_value":"Makes accumulated coins feel purposeful.","rationale":"A temporary discount creates spending decisions while preserving baseline prices.","safe_content_only":True,"desired_outcome":"Discount cosmetics modestly for one AI world cycle."}]
    elif persona_id == "accessibility_ux":
        base["feature_requests"] = [{"title":"Persistent control legend","category":"accessibility","player_value":"Improves control discoverability.","rationale":"The development lab uses several movement buttons and state-dependent actions.","safe_content_only":False,"desired_outcome":"Keep a compact Walk / Jump legend visible during an active route."}]
    else:
        base["observations"] = [{"category":"stability","severity":"medium","evidence":"Walking into an obstacle intentionally causes damage and does not advance, which is valid but should remain covered by tests.","recommendation":"Retain regression coverage for obstacle blocking, enemy blocking, and route completion."}]
        base["feature_requests"] = [{"title":"Expand deterministic state-transition tests","category":"stability","player_value":"Reduces regressions as AI content grows.","rationale":"Autonomous content cycles increase the importance of predictable game-state boundaries.","safe_content_only":False,"desired_outcome":"Add tests for blocked movement, completion rewards, and market ownership."}]
    return validate_beta_report(base)


def report_ids(persona_id: str, stamp: str, report: dict) -> dict:
    report = dict(report)
    report["tester_id"] = persona_id
    report["tester_name"] = PERSONAS[persona_id]["name"]
    report["focus"] = PERSONAS[persona_id]["focus"]
    for index, item in enumerate(report.get("observations", []), 1):
        item["id"] = f"{stamp}-{persona_id}-obs-{index}"
    for index, item in enumerate(report.get("bugs", []), 1):
        item["id"] = f"{stamp}-{persona_id}-bug-{index}"
    for index, item in enumerate(report.get("feature_requests", []), 1):
        item["id"] = f"{stamp}-{persona_id}-feature-{index}"
    return report


def build_council(stamp: str, reports: list[dict]) -> dict:
    observations = []
    bugs = []
    features = []
    for report in reports:
        for item in report.get("observations", []):
            observations.append({**item, "tester_id": report["tester_id"], "tester_name": report["tester_name"]})
        for item in report.get("bugs", []):
            bugs.append({**item, "tester_id": report["tester_id"], "tester_name": report["tester_name"]})
        for item in report.get("feature_requests", []):
            features.append({**item, "tester_id": report["tester_id"], "tester_name": report["tester_name"]})

    categories = Counter(x.get("category", "content") for x in observations + features)
    high_bugs = [x for x in bugs if x.get("severity") == "high"]
    safe_features = [x for x in features if x.get("safe_content_only")]
    return {
        "schema": 1,
        "council_id": f"beta-{stamp}",
        "created_utc": stamp,
        "tester_count": len(reports),
        "scores": {
            "fun_average": round(sum(r["fun_score"] for r in reports) / max(1, len(reports)), 2),
            "clarity_average": round(sum(r["clarity_score"] for r in reports) / max(1, len(reports)), 2),
            "friction_average": round(sum(r["friction_score"] for r in reports) / max(1, len(reports)), 2),
        },
        "category_signal": dict(categories.most_common()),
        "high_severity_bugs": high_bugs[:10],
        "safe_content_feature_requests": safe_features[:15],
        "all_feature_requests": features[:30],
        "observations": observations[:30],
        "reports": reports,
    }


def write_markdown(council: dict) -> str:
    lines = [
        f"# Waypoint Beta Tester Council — {council['created_utc']}", "",
        f"Synthetic Gemini beta testers: **{council['tester_count']}**", "",
        f"Average fun: **{council['scores']['fun_average']}/5** · clarity: **{council['scores']['clarity_average']}/5** · friction: **{council['scores']['friction_average']}/5**", "",
        "## Safe content feature requests",
    ]
    safe = council.get("safe_content_feature_requests", [])
    if not safe:
        lines.append("- None this council.")
    for item in safe:
        lines.append(f"- `{item['id']}` **{item['title']}** — {item['desired_outcome']} ({item['tester_name']})")
    lines += ["", "## Source/review feature requests"]
    review = [x for x in council.get("all_feature_requests", []) if not x.get("safe_content_only")]
    if not review:
        lines.append("- None this council.")
    for item in review[:15]:
        lines.append(f"- `{item['id']}` **{item['title']}** — {item['desired_outcome']} ({item['tester_name']})")
    lines += ["", "## High severity bugs"]
    if not council.get("high_severity_bugs"):
        lines.append("- None reported.")
    for item in council.get("high_severity_bugs", []):
        lines.append(f"- `{item['id']}` **{item['title']}** — {item['observed']}")
    lines += ["", "## Per-agent summaries"]
    for report in council.get("reports", []):
        lines.append(f"- **{report['tester_name']}** — {report['session_summary']}")
    lines += ["", "> These are synthetic AI beta-test reports based on executable play traces and data snapshots, not human playtest results or direct observation of rendered Godot visuals.", ""]
    return "\n".join(lines)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--offline", action="store_true")
    ap.add_argument("--persona", choices=sorted(PERSONAS), action="append")
    args = ap.parse_args()

    persona_ids = args.persona or list(PERSONAS)
    routes = load(ROOT / "game_data/routes.json", {})
    cosmetics = load(ROOT / "game_data/cosmetics.json", [])
    world = load(ROOT / "runtime/ai_world_state.json", {})
    recent_telemetry = load(ROOT / "runtime/telemetry_snapshot.json", [])
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    reports = []

    for index, persona_id in enumerate(persona_ids):
        trace = simulate_trace(persona_id, seed=5000 + index)
        payload = {
            "persona": {"id": persona_id, **PERSONAS[persona_id]},
            "play_trace": trace,
            "current_world_state": world,
            "routes": routes,
            "cosmetics_count": len(cosmetics),
            "recent_shared_telemetry": recent_telemetry[-40:] if isinstance(recent_telemetry, list) else [],
        }
        system = BASE_SYSTEM + f"\nYour assigned role is {PERSONAS[persona_id]['name']}. Focus on {PERSONAS[persona_id]['focus']}."
        if args.offline:
            report = offline_report(persona_id, trace)
        else:
            report = validate_beta_report(call_gemini(json.dumps(payload, ensure_ascii=False), BETA_REPORT_SCHEMA, system))
        reports.append(report_ids(persona_id, stamp, report))

    council = build_council(stamp, reports)
    folder = ROOT / "beta_feedback" / stamp
    folder.mkdir(parents=True, exist_ok=True)
    for report in reports:
        (folder / f"{report['tester_id']}.json").write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    (folder / "council.json").write_text(json.dumps(council, indent=2, ensure_ascii=False), encoding="utf-8")
    (ROOT / "runtime").mkdir(exist_ok=True)
    (ROOT / "reports").mkdir(exist_ok=True)
    (ROOT / "runtime/beta_council.json").write_text(json.dumps(council, indent=2, ensure_ascii=False), encoding="utf-8")
    (ROOT / "reports/BETA_COUNCIL_LATEST.md").write_text(write_markdown(council), encoding="utf-8")
    print(json.dumps({"ok": True, "council_id": council["council_id"], "testers": len(reports), "safe_features": len(council["safe_content_feature_requests"])}, ensure_ascii=False))


if __name__ == "__main__":
    main()
