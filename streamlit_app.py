from __future__ import annotations
import json
import streamlit as st
from streamlit_lab.core import new_state, ROUTES, COSMETICS, choose_route, move, resolve_enemy, buy_cosmetic, cosmetic_price
from streamlit_lab.world_state import load_world_state, load_beta_council
from streamlit_lab.review_gate import ReviewGateError, fetch_remote_json, persist_decision, pin_matches

st.set_page_config(page_title="Waypoint AI Development Lab", page_icon="🧭", layout="wide")
if "game" not in st.session_state:
    st.session_state.game = new_state()
state = st.session_state.game
world = load_world_state()
council = load_beta_council()

st.title("🧭 Waypoint: Cube Odyssey — AI Development Lab")
st.caption("Playable Streamlit laboratory. Godot v0.19 remains the locked production baseline.")

with st.sidebar:
    st.subheader("Character")
    st.metric("HP", f"{state['hp']} / {state['max_hp']}")
    c1,c2=st.columns(2); c1.metric("Coins",state['coins']); c2.metric("Gems",state['gems'])
    st.write("**Night Watch**")
    st.write(world.get("headline","No AI update yet."))
    st.write("Featured route:", ROUTES.get(world.get("featured_route"),{}).get("name","—"))
    st.write("Difficulty offset:", world.get("difficulty_offset",0))
    exp=world.get("experiment",{})
    st.caption(f"Experiment: {exp.get('kind','none')} · value {exp.get('value',0)}")
    if st.button("Reset lab run"):
        st.session_state.game = new_state(); st.rerun()

play, market, gm, beta, review_tab, lab = st.tabs(["🎮 Play", "🛍️ Marketplace", "🌙 AI Game Master", "🤖 Beta Testers", "✅ Development Review", "🧪 Dev Lab"])
with play:
    if not state.get("route"):
        st.subheader("Crossroads")
        cols=st.columns(3)
        for i,(rid,info) in enumerate(ROUTES.items()):
            with cols[i%3]:
                badge=" ⭐ Featured" if rid==world.get("featured_route") else ""
                st.markdown(f"### {info['name']}{badge}")
                st.write(info['theme'].title())
                st.write("Difficulty:", "◆"*info['difficulty'])
                st.write("Collectibles:", ", ".join(info['collectibles']))
                with st.expander("Route details"):
                    st.write("Hazards:", ", ".join(info['hazards']))
                if st.button("Start Adventure", key=f"route-{rid}"):
                    choose_route(state,rid); st.rerun()
    else:
        info=ROUTES[state['route']]
        st.subheader(info['name'])
        st.progress(min(1.0,state['step']/state['distance']), text=f"Trail {state['step']} / {state['distance']}")
        st.info(state['message'])
        if state.get('encounter'):
            enc=state['encounter']; st.warning(f"Encounter: {enc['name']}")
            if enc['kind']=='enemy' and st.button("Fight"):
                resolve_enemy(state); st.rerun()
            elif enc['kind']=='obstacle':
                st.caption("Walk is blocked. Jump clears the obstacle tile.")
        a,b,c,d=st.columns(4)
        if a.button("← Walk Left"):
            move(state,"walk",world=world); st.rerun()
        if b.button("↑ Walk"):
            move(state,"walk",world=world); st.rerun()
        if c.button("Walk Right →"):
            move(state,"walk",world=world); st.rerun()
        if d.button("⤒ JUMP"):
            move(state,"jump",world=world); st.rerun()
with market:
    st.subheader("Marketplace / Wardrobe")
    exp=world.get("experiment",{})
    if exp.get("kind")=="market_discount" and int(exp.get("value",0))>0:
        st.success(f"Beta-driven experiment: {int(exp['value'])}% marketplace discount this AI cycle.")
    for item in COSMETICS:
        owned=item['id'] in state['owned_cosmetics']
        price=cosmetic_price(item,world)
        label="Equip" if owned else f"Buy · {price} coins"
        c1,c2,c3=st.columns([3,1,1])
        c1.write(f"**{item['name']}** · {item['slot'].title()}")
        c2.write("Owned" if owned else (f"{item['price']} → {price}" if price != item['price'] else ""))
        if c3.button(label,key=f"buy-{item['id']}"):
            ok,msg=buy_cosmetic(state,item['id'],world); state['message']=msg; st.rerun()
with gm:
    st.subheader("Night Watch")
    focus=world.get("development_focus",{})
    if focus: st.info(f"Development focus: {focus.get('title','')} — {focus.get('reason','')}")
    adopted=world.get("adopted_feedback_ids",[])
    if adopted:
        st.write("**Adopted beta feedback:**")
        for item in adopted: st.code(item)
    st.json(world)
    st.caption("Gemini-generated world state is validated before the development build reads it.")
with beta:
    st.subheader("Gemini 3.5 Flash-Lite Beta Tester Council")
    if not council:
        st.info("No beta tester council has run yet. The GitHub workflow or offline tester can create the first council.")
    else:
        scores=council.get("scores",{})
        x,y,z=st.columns(3)
        x.metric("Fun",f"{scores.get('fun_average','—')} / 5")
        y.metric("Clarity",f"{scores.get('clarity_average','—')} / 5")
        z.metric("Friction",f"{scores.get('friction_average','—')} / 5")
        st.write("**Category signal**", council.get("category_signal",{}))
        st.write("### Safe content requests")
        safe=council.get("safe_content_feature_requests",[])
        if not safe: st.caption("None in latest council.")
        for item in safe:
            st.markdown(f"**{item.get('title')}** · `{item.get('id')}`")
            st.write(item.get("desired_outcome",""))
        st.write("### Agent reports")
        for report in council.get("reports",[]):
            with st.expander(f"{report.get('tester_name')} · {report.get('focus','')}"):
                st.write(report.get("session_summary",""))
                st.write("Feature requests:")
                for item in report.get("feature_requests",[]):
                    st.write(f"- {item.get('title')} — {item.get('desired_outcome')}")
        st.caption("These are synthetic AI tester reports based on executable play traces and data snapshots, not human playtest results.")
with review_tab:
    st.subheader("Prepared Development Update")
    st.caption("Accept selected beta-driven features for staged implementation/validation, or Hold the entire prepared bundle. Auto-merge remains disabled.")
    review = fetch_remote_json("runtime/development_review.json", {})
    gate = fetch_remote_json("runtime/development_gate.json", {})
    if not review:
        st.info("No prepared development bundle is available yet.")
    else:
        bundle_id = str(review.get("bundle_id", ""))
        same_gate = isinstance(gate, dict) and str(gate.get("bundle_id", "")) == bundle_id
        if same_gate:
            status = str(gate.get("decision", "pending")).upper()
            (st.success if status == "ACCEPTED" else st.warning)(f"Current bundle status: {status}")
            previous = set(gate.get("selected_feature_ids", []))
        else:
            st.info("Current bundle status: PREPARED — owner decision required.")
            previous = set()
        selected_ids = []
        features = [x for x in review.get("features", []) if isinstance(x, dict)]
        for item in features:
            locked = bool(item.get("locked", False))
            impl = str(item.get("implementation_class", "review_required")).replace("_", " ").title()
            checked = st.checkbox(
                f"{item.get('priority','P3')} · {item.get('title','Untitled')} · {impl}",
                value=(str(item.get("id", "")) in previous) if same_gate else not locked,
                disabled=locked,
                key=f"review-{bundle_id}-{item.get('id','')}",
            )
            if checked and not locked:
                selected_ids.append(str(item.get("id", "")))
            with st.expander(f"Details — {item.get('title','Untitled')}"):
                st.write(item.get("desired_outcome") or item.get("reason") or "No detail.")
                if locked:
                    st.warning("Milestone locked.")
        review_pin = st.text_input("Owner approval passphrase", type="password", key=f"pin-{bundle_id}")
        try:
            expected_pin = str(st.secrets.get("WAYPOINT_REVIEW_PIN", ""))
            github_token = str(st.secrets.get("WAYPOINT_REVIEW_GITHUB_TOKEN", ""))
        except Exception:
            expected_pin = ""; github_token = ""
        ready = bool(expected_pin and github_token)
        if not ready:
            st.warning("Configure WAYPOINT_REVIEW_PIN and WAYPOINT_REVIEW_GITHUB_TOKEN in Streamlit secrets to enable decisions.")
        a,b=st.columns(2)
        if a.button("ACCEPT selected update", type="primary", use_container_width=True, disabled=not ready):
            if not pin_matches(review_pin, expected_pin):
                st.error("Owner passphrase is incorrect.")
            else:
                try:
                    persist_decision(token=github_token, review=review, decision="accepted", selected_ids=selected_ids)
                    st.success("Accepted for staged implementation and validation. Auto-merge remains disabled.")
                    st.rerun()
                except ReviewGateError as exc:
                    st.error(str(exc))
        if b.button("HOLD prepared update", use_container_width=True, disabled=not ready):
            if not pin_matches(review_pin, expected_pin):
                st.error("Owner passphrase is incorrect.")
            else:
                try:
                    persist_decision(token=github_token, review=review, decision="hold", selected_ids=[])
                    st.warning("Held. Source implementation is not authorized for this bundle.")
                    st.rerun()
                except ReviewGateError as exc:
                    st.error(str(exc))


with lab:
    st.subheader("Development telemetry")
    st.write(f"Events this browser session: {len(state['telemetry'])}")
    st.json(state['telemetry'][-25:])
    st.download_button("Download telemetry JSON", json.dumps(state['telemetry'],indent=2), "waypoint_telemetry.json", "application/json")
    st.caption("Community Cloud session state is not treated as permanent storage. Export telemetry or connect an authenticated backend before multi-user persistence.")
