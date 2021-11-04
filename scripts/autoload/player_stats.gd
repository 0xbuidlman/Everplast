extends Node

signal stat_updated()
signal level_up(upgrade)

const KEY: String = \
		"^0Y]rm)'fT1Ki<YH&rlp3gy1-2:~.IF8`OKgL&nkBXmE(!48^AgvmiQc$@H?^t"

const FILE: String = \
		"user://save.json"

var ranks: Array = ["none", "silver", "gold", "emerald", "diamond", "glitch", "volcano"]
var equipable_items: Array = ["none", "water gun", "nail gun", "laser gun"]

var default_data: Dictionary = {
	"health_max": 10.0,
	"health": 10.0,
	"coins": 0.0,
	"orbs" : 0.0,
	"level": 1.0,
	"adrenaline": 10.0,
	"adrenaline_max": 10.0,
	"adrenaline_speed": 5.0,
	"world_last": 1.0,
	"level_last": 1.0,
	"world_max": 1.0,
	"level_max": 1.0,
	"quick_items" : [],
	"equipables" : [],
	"equiped_item": "none",
	"collectables" : [],
	"rank": float(Ranks.NONE),
}


enum Ranks {
	NONE,
	SILVER,
	GOLD,
	EMERALD,
	DIAMOND,
	GLITCH,
	VOLCANO,
}


# Keep these the same
var data = [{}, {}, {}, {}, {}]
var no_data_hash = data.hash()
var current_save_profile: int = 0

var adrenaline_timer := Timer.new()


func _ready() -> void:
	UI.connect("changed", self, "_ui_changed")
	Signals.connect("new_save_file", self, "_new_save_file")
	Signals.connect("player_death", self, "_player_death")
	Signals.connect("coin_collected", self, "_coin_collected")
	Signals.connect("orb_collected", self, "_orb_collected")
	Signals.connect("player_dashed", self, "_player_dashed")
	Signals.connect("player_hurt_from_enemy", self, "_player_hurt_from_enemy")
	Signals.connect("save", self, "save_stats")
	Signals.connect("profile_deleted", self, "_profile_deleted")
	Signals.connect("profile_updated", self, "_profile_updated")
	Signals.connect("level_changed", self, "_level_changed")
	#Signals.connect("level_completed", self, "_level_completed")
	Signals.connect("quick_item_used", self, "_quick_item_used")
	Signals.connect("equipped", self, "_equipped")
	connect("level_up", self, "_level_up")
	add_child(adrenaline_timer)
	adrenaline_timer.connect("timeout", self, "_timer_timeout")
	load_stats()


func _physics_process(delta):
	if not Globals.game_state == Globals.GameStates.LEVEL: return
	if get_stat("adrenaline") >= get_stat("adrenaline_max"):
		adrenaline_timer.stop()
	else:
		if adrenaline_timer.is_stopped():
			adrenaline_timer.start(get_stat("adrenaline_speed"))


func _ui_changed(menu: int) -> void:
	match menu:
		UI.PROFILE_SELECTOR:
			current_save_profile = UI.profile_index
			if UI.last_menu == UI.MAIN_MENU:
				load_stats()
		UI.PROFILE_SELECTOR_UPDATE_PROMPT:
			current_save_profile = UI.profile_index


func save_stats(on_reset: bool = false) -> void:
	if Globals.game_state == Globals.GameStates.LEVEL:
		set_stat("world_last", LevelController.current_world)
		set_stat("level_last", LevelController.current_level)
#		update_max_levels(LevelController.current_world, LevelController.current_level)
	var file: File = File.new()
	#file.open_encrypted_with_pass(FILE, File.WRITE, KEY)
	file.open(FILE, File.WRITE)
	file.store_string(to_json(data))
	file.close()
	load_stats()


func set_health(new_value):
	if new_value > get_stat("health_max"):
		new_value = get_stat("health_max")
	elif new_value < 0:
		new_value = 0
	set_stat("health", new_value)
	#set_stat("health", clamp(get_stat("health"), 0, get_stat("health_max")))
	emit_signal("stat_updated")


func set_adrenaline(new_value):
	if new_value > get_stat("adrenaline_max"):
		new_value = get_stat("adrenaline_max")
	elif new_value < 0:
		new_value = 0
	set_stat("adrenaline", new_value)
	#set_stat("health", clamp(get_stat("health"), 0, get_stat("health_max")))
	emit_signal("stat_updated")



func profile_delete(profile: int):
	if QuickPlay.data.last_profile == profile:
		QuickPlay.reset()
	data[profile] = {}
	save_stats(true)
	load_stats()


func _profile_deleted() -> void:
	profile_delete(UI.profile_index)


func _profile_updated() -> void:
	var profile: int = UI.profile_index
	var old_profile: Dictionary = data[profile]
	data[profile] = default_data
	for element in old_profile:
		if default_data.has(element) and typeof(old_profile.get(element)) == typeof(default_data.get(element)):
			data[profile][element] = old_profile[element]
	save_stats(true)


func load_stats() -> void:
	var file: File = File.new()
	if file.file_exists(FILE):
		#file.open_encrypted_with_pass(FILE, File.READ, KEY)
		file.open(FILE, File.READ)
		var loaded_data
		var test = parse_json(file.get_as_text())
		if test is Array:
			loaded_data = parse_json(file.get_as_text())
		else:
			reset_all()
			return

		if not typeof(loaded_data) == TYPE_ARRAY:
			reset_all()
			return
		file.close()

		var index: int = 0
		for dict in loaded_data:
			if typeof(dict) == TYPE_DICTIONARY:
				data[index] = dict
				index += 1
			else:
				#print("Profile %s Reset: Game Stats: %s" % [index, data])
				profile_delete(index)
		#print("Game Stats: %s" % str(data))
	else:
		reset_all()


func verify(index: int) -> bool:
	for i in PlayerStats.data[index]:
		if not PlayerStats.default_data.has(i):
			return false
		elif not typeof(PlayerStats.data[index][i]) == typeof(PlayerStats.default_data[i]):
			return false
	return PlayerStats.data[index].size() == PlayerStats.default_data.size()


func get_stat(value: String): #-> Variant not supported
	if data[current_save_profile].has(value):
		return data[current_save_profile][value]
	else:
		printerr("Could not get value %s on base %s" % [value, current_save_profile])


func set_stat(value, value2): #-> Variant
	if data[current_save_profile].has(value):
		data[current_save_profile][value] = value2
	else:
		printerr("Could not get value %s on base %s" % [value, current_save_profile])
	emit_signal("stat_updated")


func reset_all() -> void:
	data = [{}, {}, {}, {}, {}]
	save_stats(true)
	#print("Game Stats Reset Completely: Game Stats: %s" % str(data))


func get_level_up_cost() -> int:
	var cost: int = 500
	var level = get_stat("level")
	cost *= level * 2
	return int(cost)


func _new_save_file(index: int) -> void:
	data[index] = default_data
	save_stats(true)
	load_stats()


func _timer_timeout() -> void:
	if Globals.game_state == Globals.GameStates.LEVEL:
		set_adrenaline(get_stat("adrenaline") + 1)
		emit_signal("stat_updated")


func _coin_collected(amount: int) -> void:
	set_stat("coins", get_stat("coins") + amount)
	emit_signal("stat_updated")


func _orb_collected(amount: int) -> void:
	set_stat("orbs", get_stat("orbs") + amount)
	emit_signal("stat_updated")


func _player_dashed() -> void:
	if not get_stat("adrenaline") <= 0:
		set_stat("adrenaline", get_stat("adrenaline") - 1)
		Signals.emit_signal("adrenaline_updated")
		emit_signal("stat_updated")


func _player_hurt_from_enemy(hurt_type: int, knockback, damage) -> void:
	if not Globals.player_invincible:
		var health: int = get_stat("health")
		set_health(health - damage)
		emit_signal("stat_updated")


func _player_death() -> void:
	var prev_quick_items = get_stat("quick_items")
	var prev_collectables = get_stat("collectables")
	var prev_equipables = get_stat("equipables")
	load_stats()
	set_stat("quick_items", prev_quick_items)
	set_stat("collectables", prev_collectables)
	set_stat("equipables", prev_equipables)
	set_stat("health", get_stat("health_max"))
	emit_signal("stat_updated")


func _level_changed(world: int, level:int) -> void:
	set_stat("adrenaline", PlayerStats.get_stat("adrenaline_max"))
	set_stat("world_last", world)
	set_stat("level_last", level)


func _quick_item_used(item_name: String) -> void:
	match item_name:
		"carrot":
			set_health(get_stat("health") + 2)
		"cherry":
			set_adrenaline(get_stat("adrenaline") + 2)
	emit_signal("stat_updated")


func _level_up(upgrade: String) -> void:
	match upgrade:
		"health":
			set_stat("health_max", PlayerStats.get_stat("health_max") + 10)
		"adrenaline":
			set_stat("adrenaline_max", PlayerStats.get_stat("adrenaline_max") + 10)
	set_stat("orbs", PlayerStats.get_stat("orbs") - get_level_up_cost())
	set_stat("level", PlayerStats.get_stat("level") + 1)
	set_stat("adrenaline_speed", PlayerStats.get_stat("adrenaline_speed") / 1.3)


func _equipped(equipable: String) -> void:
	set_stat("equiped_item", equipable)
