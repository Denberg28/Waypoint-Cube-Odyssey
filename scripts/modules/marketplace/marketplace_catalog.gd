extends RefCounted
## Marketplace-only cosmetic catalog.

const COSMETICS = [
	# Body skins
	{"id":"skin_sage", "name":"Forest Sage", "slot":"skin", "price":120, "color":"7fb694", "text":"A calm moss-green body tint."},
	{"id":"skin_twilight", "name":"Twilight Plum", "slot":"skin", "price":160, "color":"9c87bd", "text":"A muted violet evening tint."},
	{"id":"skin_frost", "name":"Frost Pearl", "slot":"skin", "price":190, "color":"c5d7dc", "text":"A soft winter pearl finish."},
	{"id":"skin_ember", "name":"Ember Rose", "slot":"skin", "price":240, "color":"d48779", "text":"A warm ember-red finish."},
	# Head pieces
	{"id":"head_trail_cap", "name":"Trail Cap", "slot":"head", "price":90, "style":"trail_cap", "color":"69866c", "text":"A practical little trail cap."},
	{"id":"head_moon_hood", "name":"Moon Hood", "slot":"head", "price":150, "style":"moon_hood", "color":"70658e", "text":"A soft hood for night roads."},
	{"id":"head_waypoint_crown", "name":"Waypoint Crown", "slot":"head", "price":260, "style":"crown", "color":"d5b76f", "text":"A tiny crown for veteran wanderers."},
	# Back pieces
	{"id":"back_traveler_pack", "name":"Traveler Pack", "slot":"back", "price":110, "style":"pack", "color":"8b6d50", "text":"A compact expedition backpack."},
	{"id":"back_lantern", "name":"Lantern Pack", "slot":"back", "price":180, "style":"lantern", "color":"d4a864", "text":"Carries a warm waypoint lantern."},
	{"id":"back_cape", "name":"Road Cape", "slot":"back", "price":230, "style":"cape", "color":"587f77", "text":"A short cape for long roads."},
	# Face pieces
	{"id":"face_scarf", "name":"Wanderer Scarf", "slot":"face", "price":80, "style":"scarf", "color":"b56f66", "text":"A simple road scarf."},
	{"id":"face_goggles", "name":"Scout Goggles", "slot":"face", "price":140, "style":"goggles", "color":"cfb276", "text":"Small brass-colored goggles."},
	{"id":"face_star_mark", "name":"Star Mark", "slot":"face", "price":210, "style":"star_mark", "color":"ead98c", "text":"A glowing cheek-side star mark."}
]

# Persistent camp companion. The market rolls one procedural cat appearance at a
# time; the adopted design is stored in the save so the companion never changes

static func cosmetic(id: String) -> Dictionary:
	for item in COSMETICS:
		if item.id == id:
			return item
	return {}

static func cosmetics_for_slot(slot: String) -> Array:
	var result: Array = []
	for item in COSMETICS:
		if str(item.slot) == slot:
			result.append(item)
	return result

