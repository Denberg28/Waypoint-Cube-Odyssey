from __future__ import annotations

PERSONAS = {
    "first_time_player": {
        "name": "First-Time Player",
        "focus": "onboarding, clarity, route choice, controls, first-session friction",
    },
    "explorer_collector": {
        "name": "Explorer & Collector",
        "focus": "route variety, discoveries, collectibles, cosmetics, reasons to revisit routes",
    },
    "combat_challenger": {
        "name": "Combat Challenger",
        "focus": "encounter pacing, enemy friction, risk/reward, challenge and mastery",
    },
    "economy_optimizer": {
        "name": "Economy Optimizer",
        "focus": "coin flow, marketplace value, reward pacing, meaningful spending decisions",
    },
    "accessibility_ux": {
        "name": "Accessibility & UI Tester",
        "focus": "readability, button clarity, cognitive load, feedback, keyboard/mouse usability",
    },
    "qa_edge_cases": {
        "name": "QA Edge-Case Tester",
        "focus": "state transitions, repeatability, blocking states, exploit risks and regressions",
    },
}

CATEGORIES = [
    "onboarding", "ux", "accessibility", "exploration", "combat", "economy",
    "progression", "marketplace", "content", "stability", "retention",
]
SEVERITIES = ["low", "medium", "high"]

BETA_REPORT_SCHEMA = {
    "type": "object",
    "properties": {
        "session_summary": {"type": "string"},
        "fun_score": {"type": "integer", "minimum": 1, "maximum": 5},
        "clarity_score": {"type": "integer", "minimum": 1, "maximum": 5},
        "friction_score": {"type": "integer", "minimum": 1, "maximum": 5},
        "observations": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "category": {"type": "string", "enum": CATEGORIES},
                    "severity": {"type": "string", "enum": SEVERITIES},
                    "evidence": {"type": "string"},
                    "recommendation": {"type": "string"},
                },
                "required": ["category", "severity", "evidence", "recommendation"],
            },
        },
        "bugs": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "title": {"type": "string"},
                    "severity": {"type": "string", "enum": SEVERITIES},
                    "repro_steps": {"type": "array", "items": {"type": "string"}},
                    "expected": {"type": "string"},
                    "observed": {"type": "string"},
                },
                "required": ["title", "severity", "repro_steps", "expected", "observed"],
            },
        },
        "feature_requests": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "title": {"type": "string"},
                    "category": {"type": "string", "enum": CATEGORIES},
                    "player_value": {"type": "string"},
                    "rationale": {"type": "string"},
                    "safe_content_only": {"type": "boolean"},
                    "desired_outcome": {"type": "string"},
                },
                "required": ["title", "category", "player_value", "rationale", "safe_content_only", "desired_outcome"],
            },
        },
        "keep": {"type": "array", "items": {"type": "string"}},
    },
    "required": [
        "session_summary", "fun_score", "clarity_score", "friction_score",
        "observations", "bugs", "feature_requests", "keep",
    ],
}


def _clip_text(value, max_len: int = 500) -> str:
    return str(value or "").strip()[:max_len]


def validate_beta_report(data: dict) -> dict:
    data = dict(data or {})
    for key in ("fun_score", "clarity_score", "friction_score"):
        try:
            data[key] = max(1, min(5, int(data.get(key, 3))))
        except Exception:
            data[key] = 3
    data["session_summary"] = _clip_text(data.get("session_summary"), 800)

    obs = []
    for item in list(data.get("observations", []))[:6]:
        if not isinstance(item, dict):
            continue
        obs.append({
            "category": item.get("category") if item.get("category") in CATEGORIES else "ux",
            "severity": item.get("severity") if item.get("severity") in SEVERITIES else "low",
            "evidence": _clip_text(item.get("evidence")),
            "recommendation": _clip_text(item.get("recommendation")),
        })
    data["observations"] = obs

    bugs = []
    for item in list(data.get("bugs", []))[:4]:
        if not isinstance(item, dict):
            continue
        bugs.append({
            "title": _clip_text(item.get("title"), 160),
            "severity": item.get("severity") if item.get("severity") in SEVERITIES else "low",
            "repro_steps": [_clip_text(x, 220) for x in list(item.get("repro_steps", []))[:6]],
            "expected": _clip_text(item.get("expected")),
            "observed": _clip_text(item.get("observed")),
        })
    data["bugs"] = bugs

    requests = []
    for item in list(data.get("feature_requests", []))[:5]:
        if not isinstance(item, dict):
            continue
        requests.append({
            "title": _clip_text(item.get("title"), 160),
            "category": item.get("category") if item.get("category") in CATEGORIES else "content",
            "player_value": _clip_text(item.get("player_value"), 260),
            "rationale": _clip_text(item.get("rationale")),
            "safe_content_only": bool(item.get("safe_content_only", False)),
            "desired_outcome": _clip_text(item.get("desired_outcome")),
        })
    data["feature_requests"] = requests
    data["keep"] = [_clip_text(x, 220) for x in list(data.get("keep", []))[:5]]
    return data
