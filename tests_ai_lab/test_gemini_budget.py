import json

import pytest

from ai_lab import common
from ai_lab.codex_backlog import fingerprint, priority_rank


def test_request_budget_stays_below_configured_caps(monkeypatch):
    monkeypatch.setenv("GEMINI_SAFE_INPUT_TOKENS", "32000")
    monkeypatch.setenv("GEMINI_SAFE_OUTPUT_TOKENS", "4096")
    budget = common.request_budget(
        "small prompt",
        {"type": "object", "properties": {}},
        "system instruction",
        9000,
    )
    assert budget["estimated_input_tokens"] < 32000
    assert budget["max_output_tokens"] == 4096


def test_request_budget_blocks_oversized_prompt_before_network(monkeypatch):
    monkeypatch.setenv("GEMINI_SAFE_INPUT_TOKENS", "1024")
    with pytest.raises(common.GeminiBudgetError):
        common.request_budget(
            "x" * 5000,
            {"type": "object", "properties": {}},
            "system",
            1000,
        )


def test_codex_fingerprint_is_stable_and_priority_is_ordered():
    assert fingerprint("UI cleanup", "Remove duplication") == fingerprint("UI cleanup", "Remove duplication")
    assert fingerprint("UI cleanup", "Remove duplication") != fingerprint("UI cleanup", "Different reason")
    assert priority_rank("P1") < priority_rank("P2") < priority_rank("P3")
