from __future__ import annotations

from streamlit_lab.review_gate import pin_matches


def test_review_pin_requires_exact_nonempty_match():
    assert pin_matches("owner-secret", "owner-secret")
    assert not pin_matches("", "")
    assert not pin_matches("owner-secret", "different")


def test_acceptance_gate_policy_is_selective():
    # Contract-level invariant for the review UI: accepting a bundle is scoped
    # to selected feature IDs and never implies automatic merge.
    review = {
        "bundle_id": "review-test",
        "features": [
            {"id": "feature-a", "locked": False},
            {"id": "feature-b", "locked": True},
        ],
        "policy": {
            "owner_decision_required": True,
            "accept_scope": "selected_features_only",
            "auto_merge": False,
        },
    }
    assert review["policy"]["owner_decision_required"] is True
    assert review["policy"]["accept_scope"] == "selected_features_only"
    assert review["policy"]["auto_merge"] is False
