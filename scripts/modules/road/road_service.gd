extends RefCounted

static func roll_environment(host, route: String) -> String:
	var roll: float = host.rng.randf()
	if route == "frost": return "winter" if roll < 0.76 else "cloudy"
	if route == "fen":
		if roll < 0.58: return "rainy"
		elif roll < 0.88: return "cloudy"
		return "sunny"
	if route == "gloomwood": return "cloudy" if roll < 0.72 else "rainy"
	if route == "sunken_grotto": return "rainy" if roll < 0.62 else "cloudy"
	if route == "cinder_caldera":
		if roll < 0.56: return "sand"
		elif roll < 0.84: return "sunny"
		return "cloudy"
	if route == "galecrest_spire": return "winter" if roll < 0.68 else "cloudy"
	if route == "moss":
		if roll < 0.34: return "sunny"
		elif roll < 0.58: return "cloudy"
		elif roll < 0.76: return "rainy"
		elif roll < 0.90: return "winter"
		return "sand"
	if route == "forge":
		if roll < 0.38: return "sand"
		elif roll < 0.62: return "sunny"
		elif roll < 0.82: return "cloudy"
		elif roll < 0.92: return "rainy"
		return "winter"
	if route == "shrine":
		if roll < 0.26: return "winter"
		elif roll < 0.50: return "cloudy"
		elif roll < 0.72: return "rainy"
		elif roll < 0.90: return "sunny"
		return "sand"
	if roll < 0.24: return "sunny"
	elif roll < 0.44: return "cloudy"
	elif roll < 0.64: return "rainy"
	elif roll < 0.82: return "sand"
	return "winter"

static func route_options_for_stage_index(stage_index: int) -> Array:
	var sets: Array = [
		["moss", "forge", "gloomwood"],
		["treasure", "shrine", "sunken_grotto"],
		["moss", "fen", "cinder_caldera"],
		["forge", "frost", "galecrest_spire"],
		["shrine", "sunken_grotto", "fen"],
		["frost", "cinder_caldera", "galecrest_spire"]
	]
	return sets[stage_index % sets.size()].duplicate()
