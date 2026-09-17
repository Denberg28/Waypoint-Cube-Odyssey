from streamlit_lab.core import new_state, choose_route, move, buy_cosmetic, cosmetic_price, COSMETICS

def test_route_and_movement():
    s=new_state(); choose_route(s,'moss'); move(s,'walk',seed=9); assert s['step']>=1

def test_jump_clears_obstacle_two_rows():
    s=new_state(); choose_route(s,'moss'); s['encounter']={'kind':'obstacle','name':'Thorns'}; before=s['step']; move(s,'jump',seed=5); assert s['step']==before+2

def test_market_never_overdraws():
    s=new_state(); s['coins']=0; ok,_=buy_cosmetic(s,'trail_cap'); assert not ok and s['coins']==0

def test_market_discount_experiment_is_bounded_and_applied():
    item=COSMETICS[0]
    world={'experiment':{'kind':'market_discount','route':'moss','value':20}}
    assert cosmetic_price(item,world) <= item['price']
    s=new_state(); before=s['coins']; ok,_=buy_cosmetic(s,item['id'],world); assert ok
    assert before-s['coins']==cosmetic_price(item,world)

def test_route_coin_bonus_experiment():
    s=new_state(); choose_route(s,'moss'); s['step']=11; s['encounter']=None; before=s['coins']
    move(s,'walk',seed=999,world={'experiment':{'kind':'route_coin_bonus','route':'moss','value':10}})
    assert s['route'] is None and s['coins']-before==35
