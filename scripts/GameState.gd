extends Node

# 游戏核心状态,作为 autoload 单例运行

const MAX_ROUNDS: int = 20
const POOLS: Array = ["family", "supplies", "community"]

var round: int = 1
var mood: int = 50        # 心情值
var harmony: int = 50     # 和睦值
var immunity: int = 50    # 免疫力
var supplies: int = 50    # 物资

var son_crisis: int = 0       # 小儿子学业危机: 0=正常 1=危机
var talked_with_son: int = 0  # 本轮是否已与儿子谈心

var events: Array = []
var current_round_events: Array = []
var last_result: String = ""


func _ready() -> void:
	load_events()


func load_events() -> void:
	var path := "res://data/events.json"
	if not FileAccess.file_exists(path):
		push_error("找不到事件文件: %s" % path)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("无法读取事件文件")
		return
	var content := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(content)
	if parsed is Array:
		events = parsed
	else:
		push_error("events.json 格式错误,应为数组")


func start_new_game() -> void:
	round = 1
	mood = 50
	harmony = 50
	immunity = 50
	supplies = 50
	son_crisis = 0
	talked_with_son = 0
	last_result = ""
	pick_round_events()


func pick_round_events() -> void:
	current_round_events = []
	for pool_name in POOLS:
		var available: Array = []
		for ev in events:
			if ev.get("pool", "") == pool_name and _check_trigger(ev):
				available.append(ev)
		if available.size() > 0:
			available.shuffle()
			current_round_events.append(available[0])


func _check_trigger(ev: Dictionary) -> bool:
	if not ev.has("trigger"):
		return true
	var t: Dictionary = ev["trigger"]
	var attr_name: String = t.get("attribute", "")
	var value = _get_attribute(attr_name)
	if value == null:
		return true
	if t.has("min") and int(value) < int(t["min"]):
		return false
	if t.has("max") and int(value) > int(t["max"]):
		return false
	if t.has("equals") and int(value) != int(t["equals"]):
		return false
	return true


func get_visible_options(event: Dictionary) -> Array:
	var visible: Array = []
	for opt in event["options"]:
		if _check_requires(opt):
			visible.append(opt)
	return visible


func _check_requires(node: Dictionary) -> bool:
	if not node.has("requires"):
		return true
	var r: Dictionary = node["requires"]
	var attr_name: String = r.get("attribute", "")
	var value = _get_attribute(attr_name)
	if value == null:
		return true
	if r.has("min") and int(value) < int(r["min"]):
		return false
	if r.has("max") and int(value) > int(r["max"]):
		return false
	if r.has("equals") and int(value) != int(r["equals"]):
		return false
	return true


func apply_option(option: Dictionary) -> void:
	# 处理 branches(用于"在群里求助"这种基于状态产生不同后果的选项)
	if option.has("branches"):
		var branches: Array = option["branches"]
		for branch in branches:
			if _check_requires(branch):
				_apply_effects(branch.get("effects", {}))
				last_result = branch.get("result", "")
				break
		_advance_round()
		return

	_apply_effects(option.get("effects", {}))
	last_result = option.get("result", "")
	_advance_round()


func _apply_effects(effects: Dictionary) -> void:
	for key in effects.keys():
		_apply_single_effect(key, int(effects[key]))


func _apply_single_effect(key: String, value: int) -> void:
	match key:
		"mood":
			mood = clamp(mood + value, 0, 100)
		"harmony":
			harmony = clamp(harmony + value, 0, 100)
		"immunity":
			immunity = clamp(immunity + value, 0, 100)
		"supplies":
			supplies = clamp(supplies + value, 0, 100)
		"son_crisis":
			son_crisis = value
		"talked_with_son":
			talked_with_son = value


func _advance_round() -> void:
	if round < MAX_ROUNDS:
		round += 1
		pick_round_events()


func is_game_over() -> bool:
	return mood <= 0 or harmony <= 0 or immunity <= 0 or supplies <= 0


func is_victory() -> bool:
	return round > MAX_ROUNDS and not is_game_over()


func _get_attribute(name: String):
	match name:
		"mood": return mood
		"harmony": return harmony
		"immunity": return immunity
		"supplies": return supplies
		"son_crisis": return son_crisis
		"talked_with_son": return talked_with_son
	return null


func get_attribute_label(name: String) -> String:
	match name:
		"mood": return "心情"
		"harmony": return "和睦"
		"immunity": return "免疫"
		"supplies": return "物资"
	return name