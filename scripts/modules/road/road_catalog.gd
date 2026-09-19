extends RefCounted
## Route definitions, waypoint presentation metadata, and route graph.

const ROUTES = {
	"moss":{"name":"Moss Trail", "tag":"GENTLE / HEALING", "text":"Slimes, coin trails, and calmer hazards.", "color":"70bf99", "difficulty":0, "difficulty_label":"EASY", "encounters":"Slimes • light thorns • roadside campfire", "collectibles":"Coins • healing potions • fishing rewards • possible gear cache"},
	"forge":{"name":"Bramble Forge", "tag":"DANGEROUS / MORE LOOT", "text":"Kobolds, goblins, thorns, and two end-of-route gear rolls.", "color":"eaa06e", "difficulty":1, "difficulty_label":"MODERATE", "encounters":"Goblins • kobolds • ogres • more elites • thorns", "collectibles":"Two finish gear rolls • elite gem chance • relic charge • possible gear cache"},
	"shrine":{"name":"Moonlit Steps", "tag":"PRECISION / SHRINE", "text":"Rune paths and a blessing after the trail.", "color":"b9a1e4", "difficulty":1, "difficulty_label":"MODERATE", "encounters":"Slimes • kobolds • thorns • shrine event", "collectibles":"Coins • gear • shrine blessing • fishing rewards • possible gear cache"},
	"treasure":{"name":"Lantern Crossing", "tag":"COINS / TRAVELER", "text":"A rich detour with a traveler encounter.", "color":"ebcd7e", "difficulty":1, "difficulty_label":"MODERATE", "encounters":"Slimes • goblins • traveler event • thorns", "collectibles":"Extra coin pickups • traveler gift/trade • fishing rewards • possible gear cache"},
	"frost":{"name":"Frostfang Pass", "tag":"HARD / ELITES / GEMS", "text":"Winter hazards, ogres, elites, and improved gem rewards.", "color":"9fc7d8", "difficulty":2, "difficulty_label":"HARD", "encounters":"Ogres • kobolds • high elite chance • stronger thorns", "collectibles":"Gem tiles • guaranteed finish gem • possible bonus gear • frequent gear cache"},
	"fen":{"name":"Whispering Fen", "tag":"HARD / FISHING / RELICS", "text":"Wet paths, fishing pools, gear caches, and aggressive monsters.", "color":"86ad9c", "difficulty":2, "difficulty_label":"HARD", "encounters":"Goblins • ogres • high elite chance • stronger thorns", "collectibles":"Extra fishing pool • gem tiles • +18 finish relic charge • frequent gear cache"},
	"gloomwood":{"name":"Gloomwood Hollow", "tag":"TWILIGHT / ROOTS / GLOOMCAPS", "text":"A twilight forest woven around the Whispering Hollow Root.", "color":"8f86b8", "difficulty":1, "difficulty_label":"MODERATE", "encounters":"Slimes • goblins • kobolds • ensnaring briars • Elite ambushes", "collectibles":"Gloomcaps • every 3rd Gloomcap grants 1 gem • gear cache • Resolve"},
	"sunken_grotto":{"name":"Sunken Grotto", "tag":"CAVERNS / WATER / PEARLS", "text":"Descend through glowing crystal pools beneath the western roads.", "color":"68b8b5", "difficulty":1, "difficulty_label":"MODERATE", "encounters":"Slimes • kobolds • slick algae slopes • flooded caches", "collectibles":"Prismatic Pearls • fishing pools • gems • crystal caches"},
	"cinder_caldera":{"name":"Cinder Caldera", "tag":"EXTREME / MAGMA / ELITES", "text":"Cross a volcanic rift where magma vents split the old forge road.", "color":"d86f4f", "difficulty":3, "difficulty_label":"EXTREME", "encounters":"Ogres • goblins • magma vents • guaranteed Elite threat", "collectibles":"Magma Ember Shards • gems • high-tier gear caches • relic charge"},
	"galecrest_spire":{"name":"Galecrest Spire", "tag":"EXTREME / WIND / RUINS", "text":"Climb an alpine ruin above the eastern pass through relentless crosswinds.", "color":"91b7ce", "difficulty":3, "difficulty_label":"EXTREME", "encounters":"Ogres • kobolds • gale-force gusts • guaranteed Elite threat", "collectibles":"Skyfeather Relics • gems • summit caches • relic charge"}
}
# Road-end waypoints share one navigation grammar but inherit a visual
# identity from the location just completed. This keeps every junction readable
# while making each biome feel authored rather than copy-pasted.
const WAYPOINT_STYLES = {
	"moss":{
		"label":"MOSSWOOD", "post":"765f49", "trim":"8eb77f", "accent":"d6e5a5", "motif":"leaf"
	},
	"forge":{
		"label":"BRAMBLE FORGE", "post":"6f5143", "trim":"c87957", "accent":"f2b36f", "motif":"ember"
	},
	"shrine":{
		"label":"MOONLIT STEPS", "post":"625a70", "trim":"9b89ba", "accent":"dfd1f0", "motif":"moon"
	},
	"treasure":{
		"label":"LANTERN CROSSING", "post":"7b6242", "trim":"c59a58", "accent":"f0d787", "motif":"lantern"
	},
	"frost":{
		"label":"FROSTFANG PASS", "post":"665f5c", "trim":"8eabb8", "accent":"dbe9ef", "motif":"frost"
	},
	"fen":{
		"label":"WHISPERING FEN", "post":"53675f", "trim":"719987", "accent":"c5ded2", "motif":"reed"
	},
	"gloomwood":{
		"label":"GLOOMWOOD HOLLOW", "post":"5c4d52", "trim":"75678e", "accent":"d4c1e8", "motif":"root"
	},
	"sunken_grotto":{
		"label":"SUNKEN GROTTO", "post":"4e6667", "trim":"5fa39f", "accent":"b5e5df", "motif":"crystal"
	},
	"cinder_caldera":{
		"label":"CINDER CALDERA", "post":"62483f", "trim":"b95f45", "accent":"f1a269", "motif":"ember"
	},
	"galecrest_spire":{
		"label":"GALECREST SPIRE", "post":"59656e", "trim":"7fa6bb", "accent":"d3e8f0", "motif":"spire"
	}
}

static func waypoint_style(route_id: String) -> Dictionary:
	if WAYPOINT_STYLES.has(route_id):
		return WAYPOINT_STYLES[route_id]
	return {
		"label":"WAYPOINT", "post":"765f49", "trim":"879574", "accent":"eee1b8", "motif":"leaf"
	}

const ROUTE_CONNECTIONS = {
	"moss":["forge", "gloomwood", "camp"],
	"forge":["moss", "fen", "cinder_caldera", "camp"],
	"fen":["forge", "frost", "cinder_caldera", "galecrest_spire", "camp"],
	"treasure":["shrine", "gloomwood", "sunken_grotto", "camp"],
	"shrine":["treasure", "frost", "camp"],
	"frost":["shrine", "fen", "galecrest_spire", "camp"],
	"gloomwood":["moss", "treasure", "sunken_grotto", "camp"],
	"sunken_grotto":["gloomwood", "treasure", "camp"],
	"cinder_caldera":["forge", "fen", "camp"],
	"galecrest_spire":["frost", "fen", "camp"]
}

