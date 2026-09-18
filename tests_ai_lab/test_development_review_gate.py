from __future__ import annotations

from ai_lab.development_review import recommendation_similarity, update_recommendation_tally
from streamlit_lab.review_gate import pin_matches


def test_review_pin_requires_exact_nonempty_match():
    assert pin_matches("owner-secret", "owner-secret")
    assert not pin_matches("", "")
    assert not pin_matches("owner-secret", "different")


def test_monitoring_policy_has_no_auto_implementation():
    review = {
        "bundle_id": "review-test",
        "features": [{"id": "feature-a"}],
        "policy": {
            "mode": "advisory_monitoring_only",
            "statuses": ["open", "pending", "close"],
            "auto_implementation": False,
        },
    }
    assert review["policy"]["mode"] == "advisory_monitoring_only"
    assert review["policy"]["statuses"] == ["open", "pending", "close"]
    assert review["policy"]["auto_implementation"] is False


def test_similar_recommendation_titles_match():
    assert recommendation_similarity(
        "Route Discovery Log and Collector Milestones",
        "Route Discovery Ledger and Collection Milestones UI",
    ) >= 0.60
    assert recommendation_similarity(
        "Movement Command Input Buffering",
        "Movement Command Validation & Obstacle Input Buffering",
    ) >= 0.60


def test_tally_counts_distinct_councils_only():
    feature = {
        "id": "a",
        "title": "High-Contrast UI Theme Option",
        "category": "accessibility",
        "source": "beta_council",
        "tester": "Accessibility",
    }
    first, tally = update_recommendation_tally(
        [feature],
        council_id="council-1",
        created_utc="2026-09-18T00:00:00Z",
        tally={"schema": 1, "families": []},
    )
    rerun, tally = update_recommendation_tally(
        [feature],
        council_id="council-1",
        created_utc="2026-09-18T00:05:00Z",
        tally=tally,
    )
    second, tally = update_recommendation_tally(
        [{**feature, "id": "b", "title": "High-Contrast UI Theme & Focus States"}],
        council_id="council-2",
        created_utc="2026-09-18T01:00:00Z",
        tally=tally,
    )
    assert first[0]["repeat_count"] == 1
    assert rerun[0]["repeat_count"] == 1
    assert second[0]["repeat_count"] == 2
    assert tally["families"][0]["count"] == 2


def test_elite_behavior_profiles_are_danger_gated_and_distinct():
    from pathlib import Path

    catalog = Path("scripts/catalog.gd").read_text(encoding="utf-8")
    state = Path("scripts/state.gd").read_text(encoding="utf-8")
    world = Path("scripts/world.gd").read_text(encoding="utf-8")

    assert "const ELITE_BEHAVIORS" in catalog
    for profile in ["ambusher", "skirmisher", "bulwark", "crusher"]:
        assert f'"id":"{profile}"' in catalog
    assert "if danger_level() < 3" in state
    assert "func elite_behavior" in state
    assert "place_elite_encounter" in state
    assert '"elite_behavior":elite_behavior_id' in Path("scripts/main.gd").read_text(encoding="utf-8")
    assert 'telegraph = "%s  •  ELITE"' in world
