from __future__ import annotations

from ai_lab.rollback_update import allowed_path, valid_sha


def test_rollback_scope_allows_source_and_blocks_governance_files():
    assert allowed_path("scripts/main.gd")
    assert allowed_path("game_data/routes.json")
    assert allowed_path("streamlit_app.py")
    assert allowed_path("tests/test_state.py")
    assert not allowed_path("runtime/development_gate.json")
    assert not allowed_path("reports/LATEST_HANDOFF.md")
    assert not allowed_path(".github/workflows/tests.yml")
    assert not allowed_path("codex_backlog/manifest.json")


def test_rollback_checkpoint_requires_full_commit_sha():
    assert valid_sha("a" * 40)
    assert not valid_sha("a" * 12)
    assert not valid_sha("")
