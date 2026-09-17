#!/usr/bin/env python3
from __future__ import annotations
import datetime as dt
import json
import re
from pathlib import Path

from ai_lab.common import call_gemini

ROOT = Path(__file__).resolve().parents[1]
MAP_PATH = ROOT / "runtime/world_map.json"
COUNCIL_PATH = ROOT / "runtime/beta_council.json"
TELEMETRY_PATH = ROOT / "runtime/telemetry_snapshot.json"
REPORT_PATH = ROOT / "reports/WORLD_ARCHITECT_LATEST.md"
MAX_PLANNED_NODES = 12

ARCHITECT_SCHEMA = {
    "type": "object",
    "properties": {
        "decision": {"type": "string", "enum": ["hold", "expand"]},
        "summary": {"type": "string"},
        "council_basis": {"type": "array", "items": {"type": "string"}},
        "expansion": {
            "type": "object",
            "properties": {
                "id": {"type": "string"},
                "name": {"type": "string"},
                "theme": {"type": "string"},
                "difficulty": {"type": "integer", "minimum": 1, "maximum": 4},
                "x": {"type": "number", "minimum": 0.05, "maximum": 0.95},
                "y": {"type": "number", "minimum": 0.05, "maximum": 0.95},
                "connect_to": {"type": "array", "items": {"type": "string"}},
                "landmark": {"type": "string"},
                "hazard": {"type": "string"},
                "collectible": {"type": "string"},
                "rationale": {"type": "string"}
            },
            "required": ["id", "name", "theme", "difficulty", "x", "y", "connect_to", "landmark", "hazard", "collectible", "rationale"]
        }
    },
    "required": ["decision", "summary", "council_basis", "expansion"]
}

SYSTEM = """You are the Waypoint World Architect & Cartographer, a seventh specialist that resolves spatial-development implications after the six synthetic beta testers have reported. You are not a playtester and you do not score the game. Use the six-agent council, current map, route catalog, and aggregate anonymous human telemetry as evidence. Your authority is bounded: you may propose at most ONE new planned region per council. You may not delete, rename, move, or rewrite existing playable routes; change combat/economy; write source code; or mark a new region playable. Prefer expansion only when the council shows exploration, retention, route-variety, discovery, or navigation demand. New regions should connect coherently to 1-3 existing map nodes, avoid overlapping existing coordinates, and add a distinct biome/landmark/hazard/collectible concept. If evidence is weak, decision must be hold."""


def load(path: Path, default):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return default


def council_supports_expansion(council: dict) -> bool:
    categories = council.get("category_signal", {}) if isinstance(council, dict) else {}
    if int(categories.get("exploration", 0) or 0) > 0 or int(categories.get("retention", 0) or 0) > 0:
        return True
    text = json.dumps(council.get("all_feature_requests", []), ensure_ascii=False).lower()
    return any(term in text for term in ["route", "map", "region", "explor", "discover", "biome", "world"])


def validate_candidate(raw: dict, world_map: dict) -> dict | None:
    if not isinstance(raw, dict):
        return None
    node_id = str(raw.get("id", "")).strip().lower()
    if not re.fullmatch(r"[a-z][a-z0-9_]{2,23}", node_id):
        return None
    existing = {str(n.get("id", "")) for n in world_map.get("nodes", []) if isinstance(n, dict)}
    if node_id in existing:
        return None
    links = []
    for value in raw.get("connect_to", []):
        value = str(value).strip()
        if value in existing and value not in links:
            links.append(value)
    if not links:
        return None
    planned_count = sum(1 for n in world_map.get("nodes", []) if isinstance(n, dict) and n.get("status") == "planned")
    limit = min(MAX_PLANNED_NODES, int(world_map.get("planned_limit", MAX_PLANNED_NODES) or MAX_PLANNED_NODES))
    if planned_count >= limit:
        return None
    x = max(0.08, min(0.92, float(raw.get("x", 0.5))))
    y = max(0.08, min(0.92, float(raw.get("y", 0.5))))
    # Keep proposals visibly separated from existing nodes.
    for n in world_map.get("nodes", []):
        if not isinstance(n, dict):
            continue
        dx = x - float(n.get("x", 0.5))
        dy = y - float(n.get("y", 0.5))
        if dx * dx + dy * dy < 0.018:
            return None
    return {
        "id": node_id,
        "name": str(raw.get("name", "New Region")).strip()[:48],
        "kind": "region",
        "status": "planned",
        "playable": False,
        "difficulty": max(1, min(4, int(raw.get("difficulty", 2)))),
        "theme": str(raw.get("theme", "unknown frontier")).strip()[:80],
        "x": round(x, 3),
        "y": round(y, 3),
        "landmark": str(raw.get("landmark", "")).strip()[:100],
        "hazard": str(raw.get("hazard", "")).strip()[:100],
        "collectible": str(raw.get("collectible", "")).strip()[:100],
        "rationale": str(raw.get("rationale", "")).strip()[:320],
        "connect_to": links[:3],
    }


def apply_candidate(world_map: dict, candidate: dict) -> dict:
    result = json.loads(json.dumps(world_map))
    result.setdefault("nodes", []).append(candidate)
    result.setdefault("edges", [])
    existing_edges = {(str(e.get("from")), str(e.get("to"))) for e in result["edges"] if isinstance(e, dict)}
    for target in candidate.get("connect_to", []):
        edge = (target, candidate["id"])
        rev = (candidate["id"], target)
        if edge not in existing_edges and rev not in existing_edges:
            result["edges"].append({"from": target, "to": candidate["id"]})
    result["revision"] = int(result.get("revision", 0)) + 1
    result["updated_utc"] = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    return result


def write_report(decision: dict, candidate: dict | None, reason: str) -> str:
    lines = [
        "# Waypoint World Architect — Latest Council Resolution",
        "",
        f"Decision: **{decision.get('decision', 'hold').upper()}**",
        "",
        str(decision.get("summary", reason)).strip() or reason,
        "",
        "## Council basis",
    ]
    basis = decision.get("council_basis", []) if isinstance(decision, dict) else []
    for item in basis[:8]:
        lines.append(f"- {str(item)[:240]}")
    if not basis:
        lines.append("- No strong map-expansion signal was present.")
    lines += ["", "## Map action"]
    if candidate:
        lines += [
            f"- Added planned region **{candidate['name']}** (`{candidate['id']}`)",
            f"- Difficulty concept: {candidate['difficulty']}",
            f"- Theme: {candidate['theme']}",
            f"- Connections: {', '.join(candidate['connect_to'])}",
            f"- Landmark: {candidate['landmark']}",
            f"- Hazard: {candidate['hazard']}",
            f"- Collectible: {candidate['collectible']}",
            "- Status remains **planned / non-playable** until a later core-route promotion step validates gameplay support.",
        ]
    else:
        lines.append(f"- No map node added. {reason}")
    lines += ["", "> Guardrail: the World Architect may expand the planning graph but cannot delete or rewrite existing playable routes and cannot promote a proposal to playable by itself.", ""]
    return "\n".join(lines)


def main() -> None:
    world_map = load(MAP_PATH, {"schema": 1, "revision": 0, "nodes": [], "edges": [], "planned_limit": MAX_PLANNED_NODES})
    council = load(COUNCIL_PATH, {})
    telemetry = load(TELEMETRY_PATH, [])
    support = council_supports_expansion(council)
    payload = {
        "six_agent_council": council,
        "current_world_map": world_map,
        "aggregate_public_telemetry": telemetry[-40:] if isinstance(telemetry, list) else telemetry,
        "rule": "At most one planned non-playable region may be added. Preserve every existing node and edge."
    }
    try:
        decision = call_gemini(json.dumps(payload, ensure_ascii=False), ARCHITECT_SCHEMA, SYSTEM)
    except Exception as exc:
        decision = {"decision": "hold", "summary": "World Architect unavailable; map held safely.", "council_basis": [], "expansion": {}}
        reason = f"Gemini call failed safely: {type(exc).__name__}."
    else:
        reason = "Council evidence did not justify expansion."

    candidate = None
    if support and decision.get("decision") == "expand":
        candidate = validate_candidate(decision.get("expansion", {}), world_map)
        if candidate:
            world_map = apply_candidate(world_map, candidate)
            MAP_PATH.parent.mkdir(exist_ok=True)
            MAP_PATH.write_text(json.dumps(world_map, indent=2, ensure_ascii=False), encoding="utf-8")
            reason = "Validated one bounded planned-region expansion."
        else:
            decision["decision"] = "hold"
            reason = "Expansion proposal failed map guardrails or the planned-region cap."
    elif decision.get("decision") == "expand" and not support:
        decision["decision"] = "hold"
        reason = "The six-agent council did not contain enough exploration/navigation evidence."

    resolution = {
        "decision": decision.get("decision", "hold"),
        "summary": str(decision.get("summary", reason))[:800],
        "map_node_added": candidate.get("id") if candidate else None,
        "map_revision": int(world_map.get("revision", 0)),
        "specialist": "World Architect & Cartographer",
    }
    council["world_architect"] = resolution
    COUNCIL_PATH.write_text(json.dumps(council, indent=2, ensure_ascii=False), encoding="utf-8")
    REPORT_PATH.parent.mkdir(exist_ok=True)
    REPORT_PATH.write_text(write_report(decision, candidate, reason), encoding="utf-8")
    print(json.dumps({"ok": True, **resolution}, ensure_ascii=False))


if __name__ == "__main__":
    main()
