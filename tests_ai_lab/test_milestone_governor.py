from ai_lab.milestone_governor import (
    MILESTONES,
    cadence_for,
    default_state,
    evaluate,
    stable_council,
)


def council(stamp: str, *, fun=4.0, clarity=4.0, friction=2.0, high=False):
    return {
        "created_utc": stamp,
        "council_id": f"beta-{stamp}",
        "scores": {
            "fun_average": fun,
            "clarity_average": clarity,
            "friction_average": friction,
        },
        "high_severity_bugs": [{"id": "bug"}] if high else [],
    }


def test_stable_council_requires_scores_and_no_high_bug():
    assert stable_council(council("20260101T000000Z"))
    assert not stable_council(council("20260101T000000Z", high=True))
    assert not stable_council(council("20260101T000000Z", clarity=3.0))


def test_cadence_slows_as_milestones_lock():
    assert cadence_for(0, False) == (1, 3)
    assert cadence_for(1, False) == (2, 6)
    assert cadence_for(2, False) == (4, 8)
    assert cadence_for(3, False) == (6, 12)
    assert cadence_for(4, True) == (12, 24)


def test_six_stable_councils_lock_first_milestone_and_advance():
    councils = [
        council(f"20260101T0{hour}0000Z")
        for hour in range(6)
    ]
    state = default_state(councils[:1], "20260101T000000Z")
    # Ensure activation includes all six deterministic test councils.
    state["milestones"][0]["activated_utc"] = "20260101T000000Z"
    out = evaluate(state, councils, "20260101T060000Z")

    assert out["milestones"][0]["status"] == "locked"
    assert out["milestones"][0]["lock_reason"] == "stable-threshold"
    assert out["milestones"][1]["status"] == "active"
    assert out["active_milestone_id"] == MILESTONES[1]["id"]
    assert "ux" in out["locked_categories"]
    assert out["beta_cadence_hours"] == 2
    assert out["development_cadence_hours"] == 6


def test_high_severity_finding_breaks_stable_streak():
    councils = [
        council("20260101T000000Z"),
        council("20260101T010000Z"),
        council("20260101T020000Z", high=True),
        council("20260101T030000Z"),
        council("20260101T040000Z"),
        council("20260101T050000Z"),
    ]
    state = default_state(councils[:1], "20260101T000000Z")
    state["milestones"][0]["activated_utc"] = "20260101T000000Z"
    out = evaluate(state, councils, "20260101T060000Z")

    assert out["milestones"][0]["status"] == "active"
    assert out["milestones"][0]["stable_streak"] == 3
    assert out["beta_cadence_hours"] == 1
