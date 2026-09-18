from __future__ import annotations
import json
import streamlit as st
from streamlit_lab.core import new_state, ROUTES, COSMETICS, choose_route, move, resolve_enemy, buy_cosmetic, cosmetic_price
from streamlit_lab.world_state import load_world_state, load_beta_council
from streamlit_lab.review_gate import ReviewGateError, fetch_remote_json, persist_decision, pin_matches, request_implementation, request_rollback

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

play, market, gm, beta, review_tab, accepted_tab, lab = st.tabs(["🎮 Play", "🛍️ Marketplace", "🌙 AI Game Master", "🤖 Beta Testers", "✅ Development Review", "📦 Accepted Updates", "🧪 Dev Lab"])
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
    st.caption("Only pending features stay here. Accepted features move to Accepted Updates. Rolled-back features return here for a fresh decision.")

    review = fetch_remote_json("runtime/development_review.json", {})
    gate = fetch_remote_json("runtime/development_gate.json", {})
    flagged = fetch_remote_json("runtime/flagged_features.json", {"features": []})

    if not review:
        st.info("No prepared development bundle is available yet.")
    else:
        bundle_id = str(review.get("bundle_id", ""))
        same_gate = isinstance(gate, dict) and str(gate.get("bundle_id", "")) == bundle_id
        accepted_ids = set(gate.get("selected_feature_ids", [])) if same_gate and str(gate.get("decision", "")) == "accepted" else set()
        flagged_ids = {
            str(item.get("id", ""))
            for item in flagged.get("features", [])
            if isinstance(item, dict) and bool(item.get("manual_clear_required", False))
        }

        all_features = [x for x in review.get("features", []) if isinstance(x, dict)]
        pending = [x for x in all_features if str(x.get("id", "")) not in accepted_ids]

        if not pending:
            st.success("All features in this prepared bundle are already accepted. Manage them in Accepted Updates.")
        else:
            selected_ids = []
            for item in pending:
                fid = str(item.get("id", ""))
                rolled_back = fid in flagged_ids or bool(item.get("rollback_flagged", False))
                locked = bool(item.get("locked", False)) and not rolled_back
                impl = str(item.get("implementation_class", "review_required")).replace("_", " ").title()
                prefix = "ROLLED BACK · " if rolled_back else ""
                checked = st.checkbox(
                    f"{prefix}{item.get('priority','P3')} · {item.get('title','Untitled')} · {impl}",
                    value=False,
                    disabled=locked,
                    key=f"pending-{bundle_id}-{fid}",
                )
                if checked and not locked:
                    selected_ids.append(fid)
                with st.expander(f"Details — {item.get('title','Untitled')}"):
                    st.write("**Beta tester:**", item.get("tester") or "Development analysis")
                    st.write("**Category:**", item.get("category", "—"))
                    st.write("**Desired outcome:**", item.get("desired_outcome") or "—")
                    st.write("**Reason:**", item.get("reason") or "—")
                    if rolled_back:
                        st.warning("This feature was rolled back. Selecting and accepting it again is an explicit owner decision to reconsider it.")
                    elif locked:
                        st.warning("This category is milestone-locked and cannot be accepted for ordinary optimization.")

            st.divider()
            st.caption(f"Pending: {len(pending)} · Selected: {len(selected_ids)}")
            review_pin = st.text_input("Owner approval passphrase", type="password", key=f"review-pin-{bundle_id}")
            try:
                expected_pin = str(st.secrets.get("WAYPOINT_REVIEW_PIN", ""))
                github_token = str(st.secrets.get("WAYPOINT_REVIEW_GITHUB_TOKEN", ""))
            except Exception:
                expected_pin = ""
                github_token = ""
            controls_ready = bool(expected_pin and github_token)
            if not controls_ready:
                st.warning("Review controls are read-only until the Streamlit review secrets are configured.")

            a, b = st.columns(2)
            if a.button(
                "ACCEPT selected",
                type="primary",
                use_container_width=True,
                disabled=(not controls_ready or not selected_ids),
                key=f"accept-pending-{bundle_id}",
            ):
                if not pin_matches(review_pin, expected_pin):
                    st.error("Owner passphrase is incorrect.")
                else:
                    try:
                        persist_decision(token=github_token, review=review, decision="accepted", selected_ids=selected_ids)
                    except ReviewGateError as exc:
                        st.error(str(exc))
                    else:
                        st.success("Accepted features moved to Accepted Updates.")
                        st.rerun()

            if b.button(
                "HOLD pending",
                use_container_width=True,
                disabled=not controls_ready,
                key=f"hold-pending-{bundle_id}",
            ):
                if not pin_matches(review_pin, expected_pin):
                    st.error("Owner passphrase is incorrect.")
                else:
                    try:
                        persist_decision(token=github_token, review=review, decision="hold", selected_ids=[])
                    except ReviewGateError as exc:
                        st.error(str(exc))
                    else:
                        st.info("Pending features remain in Development Review.")
                        st.rerun()


with accepted_tab:
    st.subheader("Accepted Development Updates")
    st.caption("Select accepted features, then IMPLEMENT. Implemented features stay green. The latest implemented batch can be rolled back as one safe unit.")

    gate = fetch_remote_json("runtime/development_gate.json", {})
    implementation_request = fetch_remote_json("runtime/implementation_request.json", {})
    rollback_request = fetch_remote_json("runtime/rollback_request.json", {})

    try:
        expected_pin = str(st.secrets.get("WAYPOINT_REVIEW_PIN", ""))
        github_token = str(st.secrets.get("WAYPOINT_REVIEW_GITHUB_TOKEN", ""))
    except Exception:
        expected_pin = ""
        github_token = ""
    controls_ready = bool(expected_pin and github_token)

    accepted_features = [
        x for x in gate.get("selected_features", [])
        if isinstance(x, dict)
    ] if isinstance(gate, dict) and str(gate.get("decision", "")) == "accepted" else []
    implemented_ids = set(str(x) for x in gate.get("implemented_feature_ids", [])) if isinstance(gate, dict) else set()

    if not accepted_features:
        st.info("No accepted development features are waiting here.")
    else:
        bundle_id = str(gate.get("bundle_id", ""))
        impl_matches = isinstance(implementation_request, dict) and str(implementation_request.get("bundle_id", "")) == bundle_id
        impl_status = str(implementation_request.get("status", "")) if impl_matches else ""
        active_batch_ids = set(str(x) for x in implementation_request.get("selected_feature_ids", [])) if impl_matches else set()
        rollback_matches = isinstance(rollback_request, dict) and str(rollback_request.get("bundle_id", "")) == bundle_id
        rollback_status = str(rollback_request.get("status", "")) if rollback_matches else ""

        implementation_active = impl_status in {"requested", "in_progress"}
        latest_batch_implemented = impl_status == "completed" and bool(active_batch_ids)
        rollback_active = rollback_status == "requested"

        selected_for_implement = []
        selected_for_rollback = []
        for item in accepted_features:
            fid = str(item.get("id", ""))
            is_implemented = fid in implemented_ids
            in_latest_batch = fid in active_batch_ids and latest_batch_implemented

            if is_implemented:
                checked = st.checkbox(
                    f"🟢 IMPLEMENTED · {item.get('title','Untitled')}",
                    value=in_latest_batch,
                    disabled=not in_latest_batch or rollback_active,
                    key=f"implemented-{bundle_id}-{fid}",
                )
                if checked and in_latest_batch:
                    selected_for_rollback.append(fid)
                st.success(f"✓ {item.get('title','Untitled')} — implemented")
            else:
                checked = st.checkbox(
                    f"🟢 ACCEPTED · {item.get('title','Untitled')}",
                    value=False,
                    disabled=implementation_active or latest_batch_implemented or rollback_active,
                    key=f"accepted-{bundle_id}-{fid}",
                )
                if checked:
                    selected_for_implement.append(fid)

        st.divider()
        owner_pin = st.text_input("Owner approval passphrase", type="password", key=f"accepted-pin-{bundle_id}")
        if not controls_ready:
            st.warning("Actions are read-only until the Streamlit review secrets are configured.")

        if latest_batch_implemented:
            st.caption("Rollback applies to the latest implemented batch as one unit. Keep all its checked boxes selected to roll it back safely.")
            rollback_reason = st.text_input(
                "Rollback reason",
                placeholder="Example: update breaks route loading",
                key=f"rollback-reason-{bundle_id}",
            )
            if st.button(
                "ROLL BACK selected implemented batch",
                use_container_width=True,
                disabled=(
                    not controls_ready
                    or rollback_active
                    or set(selected_for_rollback) != active_batch_ids
                ),
                key=f"rollback-batch-{bundle_id}",
            ):
                if not pin_matches(owner_pin, expected_pin):
                    st.error("Owner passphrase is incorrect.")
                else:
                    try:
                        request_rollback(
                            token=github_token,
                            gate=gate,
                            selected_ids=selected_for_rollback,
                            reason=rollback_reason,
                        )
                    except ReviewGateError as exc:
                        st.error(str(exc))
                    else:
                        st.warning("Rollback requested. Rolled-back features will return to Development Review.")
                        st.rerun()
        elif implementation_active:
            st.info("Implementation requested for the checked batch. Wait for the implementation worker to finish before starting another batch.")
        else:
            if st.button(
                "IMPLEMENT selected accepted features",
                type="primary",
                use_container_width=True,
                disabled=(not controls_ready or not selected_for_implement),
                key=f"implement-selected-{bundle_id}",
            ):
                if not pin_matches(owner_pin, expected_pin):
                    st.error("Owner passphrase is incorrect.")
                else:
                    try:
                        request_implementation(
                            token=github_token,
                            gate=gate,
                            selected_ids=selected_for_implement,
                        )
                    except ReviewGateError as exc:
                        st.error(str(exc))
                    else:
                        st.success("Selected accepted features queued for implementation.")
                        st.rerun()

with lab:
    st.subheader("Development telemetry")
    st.write(f"Events this browser session: {len(state['telemetry'])}")
    st.json(state['telemetry'][-25:])
    st.download_button("Download telemetry JSON", json.dumps(state['telemetry'],indent=2), "waypoint_telemetry.json", "application/json")
    st.caption("Community Cloud session state is not treated as permanent storage. Export telemetry or connect an authenticated backend before multi-user persistence.")
