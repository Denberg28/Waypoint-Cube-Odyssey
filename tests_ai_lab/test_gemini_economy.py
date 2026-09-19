from __future__ import annotations

from pathlib import Path


def test_all_scheduled_gemini_workflows_are_economized():
    workflows = {
        "development": Path(".github/workflows/ai-development-cycle.yml").read_text(encoding="utf-8"),
        "beta": Path(".github/workflows/beta-tester-council.yml").read_text(encoding="utf-8"),
        "music": Path(".github/workflows/music-director.yml").read_text(encoding="utf-8"),
    }

    for text in workflows.values():
        assert 'GEMINI_MAX_RETRIES: "0"' in text
        assert 'GEMINI_MAX_REQUESTS_PER_RUN: "1"' in text
        assert 'GEMINI_MAX_REQUESTS_PER_DAY: "3"' in text
        assert 'GEMINI_DAILY_USAGE_FILE: "runtime/gemini_daily_usage.json"' in text
        assert 'GEMINI_ECONOMY_MODE: "true"' in text

    assert 'cron: "17 1 * * *"' in workflows["development"]
    assert 'AI_MAX_DAILY_CYCLES: "1"' in workflows["development"]

    assert 'cron: "5 12 * * *"' in workflows["beta"]
    assert 'BETA_MAX_DAILY_COUNCILS: "1"' in workflows["beta"]

    assert 'cron: "37 18 * * *"' in workflows["music"]


def test_beta_council_uses_one_live_persona_in_economy_mode():
    beta = Path("ai_lab/beta_testers.py").read_text(encoding="utf-8")
    architect = Path("ai_lab/world_architect.py").read_text(encoding="utf-8")

    assert "GEMINI_ECONOMY_MODE" in beta
    assert "live_persona" in beta
    assert "persona_id != live_persona" in beta
    assert "offline_report(persona_id, trace)" in beta

    assert "GEMINI_ECONOMY_MODE" in architect
    assert "Economy mode: World Architect held without an API request." in architect


def test_common_gemini_client_has_shared_daily_cap_and_429_cooldown():
    common = Path("ai_lab/common.py").read_text(encoding="utf-8")

    assert "DEFAULT_MAX_REQUESTS_PER_DAY = 3" in common
    assert "GEMINI_MAX_REQUESTS_PER_DAY" in common
    assert "Gemini shared daily request cap reached" in common
    assert "_mark_daily_quota_blocked" in common
    assert "HTTP 429 quota/rate limit" in common
