from ai_lab.contracts import validate_world

def test_contract_clamps_ai_output():
    d={'featured_route':'bad','difficulty_offset':99,'reward':{'coins':999,'gems':99},'challenge':{'target':99},'content_pack':{'kind':'source_edit','route':'bad'},'development_focus':{},'adopted_feedback_ids':['valid','fake'],'experiment':{'kind':'market_discount','route':'bad','value':99},'development_backlog':[{}]*9}
    d=validate_world(d,{'valid'})
    assert d['featured_route']=='moss' and d['difficulty_offset']==1
    assert d['reward']=={'coins':25,'gems':2}
    assert d['challenge']['target']==5
    assert d['content_pack']['kind']=='world_event'
    assert d['experiment']['value']==25 and d['experiment']['route']=='moss'
    assert d['adopted_feedback_ids']==['valid']
    assert len(d['development_backlog'])==5
