from __future__ import annotations
import random
from streamlit_lab.core import ROUTES, COSMETICS, new_state, choose_route, move, resolve_enemy, buy_cosmetic

PERSONA_ROUTES = {
    "first_time_player": "moss",
    "explorer_collector": "sunken_grotto",
    "combat_challenger": "cinder_caldera",
    "economy_optimizer": "treasure",
    "accessibility_ux": "shrine",
    "qa_edge_cases": "galecrest_spire",
}


def simulate_trace(persona_id: str, seed: int = 42, max_actions: int = 28) -> dict:
    rng = random.Random(seed)
    state = new_state()
    route = PERSONA_ROUTES.get(persona_id, rng.choice(list(ROUTES)))
    choose_route(state, route)
    actions = []

    for _ in range(max_actions):
        if not state.get("route"):
            break
        enc = state.get("encounter")
        if enc and enc.get("kind") == "enemy":
            actions.append({"action": "fight", "enemy": enc.get("name")})
            resolve_enemy(state)
            continue
        if enc and enc.get("kind") == "obstacle":
            action = "jump" if persona_id != "qa_edge_cases" or rng.random() > 0.35 else "walk"
        else:
            action = "jump" if rng.random() < (0.35 if persona_id == "combat_challenger" else 0.16) else "walk"
        before = state["step"]
        move(state, action, seed=rng.randint(0, 999999))
        actions.append({"action": action, "from_step": before, "to_step": state["step"], "message": state["message"]})

    market = []
    if persona_id in {"explorer_collector", "economy_optimizer", "accessibility_ux"}:
        for item in COSMETICS[:3]:
            ok, msg = buy_cosmetic(state, item["id"])
            market.append({"item": item["id"], "ok": ok, "message": msg, "coins_after": state["coins"]})
            if persona_id != "economy_optimizer":
                break

    return {
        "persona_id": persona_id,
        "starting_route": route,
        "actions": actions,
        "market_actions": market,
        "final": {
            "coins": state["coins"],
            "hp": state["hp"],
            "route": state.get("route"),
            "step": state["step"],
            "completed_routes": state["completed_routes"],
            "owned_cosmetics": list(state["owned_cosmetics"]),
            "message": state["message"],
        },
        "telemetry": state["telemetry"],
    }
