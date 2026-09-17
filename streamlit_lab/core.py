from __future__ import annotations
import json, random
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ROUTES = json.loads((ROOT / "game_data/routes.json").read_text(encoding="utf-8"))
COSMETICS = json.loads((ROOT / "game_data/cosmetics.json").read_text(encoding="utf-8"))


def new_state() -> dict:
    return {
        "coins": 100, "gems": 0, "hp": 100, "max_hp": 100,
        "route": None, "step": 0, "distance": 12, "lane": 1,
        "inventory": [], "owned_cosmetics": [], "equipped": {},
        "telemetry": [], "message": "Choose a route at the crossroads.",
        "encounter": None, "completed_routes": 0,
    }


def log_event(state: dict, event: str, **data) -> None:
    state.setdefault("telemetry", []).append({"event": event, **data})
    if len(state["telemetry"]) > 250:
        state["telemetry"] = state["telemetry"][-250:]


def choose_route(state: dict, route_id: str) -> None:
    if route_id not in ROUTES:
        raise ValueError("unknown route")
    state["route"] = route_id
    state["step"] = 0
    state["encounter"] = None
    state["message"] = f"Entered {ROUTES[route_id]['name']}."
    log_event(state, "route_start", route=route_id)


def route_preview(route_id: str) -> dict:
    return dict(ROUTES[route_id])


def _experiment(world: dict | None) -> dict:
    exp = (world or {}).get("experiment", {})
    return exp if isinstance(exp, dict) else {}


def _spawn_encounter(state: dict, rng: random.Random, world: dict | None = None) -> None:
    obstacle_rate = 0.20
    enemy_rate = 0.18
    exp = _experiment(world)
    if exp.get("route") == state.get("route"):
        value = max(-10, min(10, int(exp.get("value", 0)))) / 100.0
        if exp.get("kind") == "obstacle_pressure":
            obstacle_rate = max(0.05, min(0.35, obstacle_rate + value))
        elif exp.get("kind") == "enemy_pressure":
            enemy_rate = max(0.05, min(0.35, enemy_rate + value))
    roll = rng.random()
    if roll < obstacle_rate:
        state["encounter"] = {"kind": "obstacle", "name": "Thorn Barrier"}
    elif roll < obstacle_rate + enemy_rate:
        state["encounter"] = {"kind": "enemy", "name": rng.choice(["Slime", "Goblin", "Kobold"]), "hp": 1}
    elif roll < obstacle_rate + enemy_rate + 0.12:
        reward = rng.randint(4, 12)
        state["coins"] += reward
        state["message"] = f"Found {reward} coins."
        log_event(state, "coin_collect", amount=reward)
    else:
        state["encounter"] = None


def move(state: dict, action: str, seed: int | None = None, world: dict | None = None) -> None:
    if not state.get("route"):
        state["message"] = "Choose a route first."
        return
    rng = random.Random(seed)
    enc = state.get("encounter")
    if enc and enc.get("kind") == "enemy":
        state["message"] = "An enemy blocks the road. Resolve it first."
        return
    if enc and enc.get("kind") == "obstacle":
        if action != "jump":
            state["hp"] = max(0, state["hp"] - 8)
            state["message"] = "The obstacle blocks walking. Use Jump."
            log_event(state, "obstacle_hit", route=state["route"], damage=8)
            return
        state["step"] += 2
        state["encounter"] = None
        state["message"] = "Jumped over the obstacle."
        log_event(state, "obstacle_jump", route=state["route"])
    else:
        state["step"] += 1
        state["message"] = "Jumped forward." if action == "jump" else "Walked forward."
        log_event(state, "move", action=action, route=state["route"])
    if state["step"] >= state["distance"]:
        rid = state["route"]
        reward = 25
        exp = _experiment(world)
        if exp.get("kind") == "route_coin_bonus" and exp.get("route") == rid:
            reward += max(0, min(15, int(exp.get("value", 0))))
        state["coins"] += reward
        state["completed_routes"] += 1
        state["route"] = None
        state["encounter"] = None
        state["message"] = f"Route complete: {ROUTES[rid]['name']}. +{reward} coins."
        log_event(state, "route_complete", route=rid, reward=reward)
        return
    _spawn_encounter(state, rng, world)


def resolve_enemy(state: dict) -> None:
    enc = state.get("encounter")
    if not enc or enc.get("kind") != "enemy":
        return
    state["coins"] += 8
    log_event(state, "enemy_defeat", enemy=enc.get("name"), route=state.get("route"))
    state["encounter"] = None
    state["message"] = "Enemy defeated. +8 coins."


def cosmetic_price(item: dict, world: dict | None = None) -> int:
    price = int(item["price"])
    exp = _experiment(world)
    if exp.get("kind") == "market_discount":
        discount = max(0, min(25, int(exp.get("value", 0))))
        return max(1, round(price * (100 - discount) / 100))
    return price


def buy_cosmetic(state: dict, item_id: str, world: dict | None = None) -> tuple[bool, str]:
    item = next((x for x in COSMETICS if x["id"] == item_id), None)
    if not item:
        return False, "Unknown cosmetic."
    if item_id in state["owned_cosmetics"]:
        state["equipped"][item["slot"]] = item_id
        return True, f"Equipped {item['name']}."
    price = cosmetic_price(item, world)
    if state["coins"] < price:
        return False, "Not enough coins."
    state["coins"] -= price
    state["owned_cosmetics"].append(item_id)
    state["equipped"][item["slot"]] = item_id
    log_event(state, "market_purchase", item=item_id, price=price)
    return True, f"Purchased and equipped {item['name']} for {price} coins."
