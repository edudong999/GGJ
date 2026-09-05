extends Node

# 游戏核心状态,作为 autoload 单例运行

const MAX_DAYS: int = 20
const POOLS: Array = ["family", "community", "events"]

# 共享属性
var day: int = 1
var mood: int = 50        # 心情值
var harmony: int = 50     # 和睦值
var immunity: int = 50    # 免疫力
var supplies: int = 50    # 物资

# 家庭成员成长标志 (0/1)
var son_crisis: int = 0          # 小儿子学业危机
var talked_with_son: int = 0     # 本轮是否与儿子谈心(为 0 时,蛋糕 / 线上测试的某些选项不可见)
var son_perfect: int = 0         # 儿子完美结局(线上测试2 完成)
var test_good_ending: int = 0    # 线上测试好结局(触发线上测试2 的前置)
var good_dad: int = 0            # 你是我的好爸爸(女儿网恋处理得当)
var account: int = 1             # 网恋诈骗账号存在(默认 1)
var online_love_pending: int = 0 # 网恋事件已发生但未告知父亲

# 父亲个人标志
var duty: int = 0                # 值守度(党员突击队任务)
var is_volunteer: int = 0        # 也是社区志愿者

# 物资计数
var eggs: int = 0                # 鸡蛋数量
var hot_noodles: int = 0         # 热干面数量

# 已触发的事件(用于 unique 标记)
var fired_event_ids: Array = []

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
	day = 1
	mood = 50
	harmony = 50
	immunity = 50
	supplies = 50
	son_crisis = 0
	talked_with_son = 0
	son_perfect = 0
	test_good_ending = 0
	good_dad = 0
	account = 1
	online_love_pending = 0
	duty = 0
	is_volunteer = 0
	eggs = 0
	hot_noodles = 0
	fired_event_ids = []
	last_result = ""
	pick_day_events()


# ─────────────── 事件抽取 ───────────────

func pick_day_events() -> void:
	current_round_events = []
	var used_ids: Dictionary = {}  # 已选中的事件 id

	# 1) 强制事件(按 force_day 匹配今天)
	var forced: Array = _collect_forced_events()
	forced.sort_custom(func(a, b): return int(a["position"]) < int(b["position"]))
	for entry in forced:
		if current_round_events.size() >= 3:
			break
		var ev: Dictionary = entry["event"]
		if ev["id"] not in used_ids:
			current_round_events.append(ev)
			used_ids[ev["id"]] = true
			if ev.get("unique", false):
				fired_event_ids.append(ev["id"])

	# 2) 用加权随机填充剩余槽位
	while current_round_events.size() < 3:
		var pick = _pick_weighted_for_remaining(used_ids)
		if pick == null:
			break
		current_round_events.append(pick)
		used_ids[pick["id"]] = true
		if pick.get("unique", false):
			fired_event_ids.append(pick["id"])


func _collect_forced_events() -> Array:
	var result: Array = []
	for ev in events:
		var force_days: Array = ev.get("force_day", [])
		if force_days.is_empty():
			continue
		var positions: Array = ev.get("force_position", [])
		for i in range(force_days.size()):
			if int(force_days[i]) == day:
				var pos: int = 1
				if i < positions.size():
					pos = int(positions[i])
				result.append({"event": ev, "position": pos})
				break
	return result


func _pick_weighted_for_remaining(used_ids: Dictionary) -> Variant:
	# 先按池子收集可用事件,每个池子按权重抽 1 个,然后在 3 个里按权重再抽 1
	# 这样既保留池子结构,又允许强制事件占满某个池子时其他池子补位
	var pool_picks: Array = []
	for pool_name in POOLS:
		var candidates: Array = []
		var total_weight: int = 0
		for ev in events:
			if ev.get("pool", "") != pool_name:
				continue
			if ev["id"] in used_ids:
				continue
			if ev["id"] in fired_event_ids:
				continue
			if not _check_trigger(ev):
				continue
			candidates.append(ev)
			total_weight += int(ev.get("weight", 3))
		if candidates.is_empty():
			continue
		var pick: Dictionary = candidates[_weighted_index(candidates, total_weight)]
		pool_picks.append(pick)

	if pool_picks.is_empty():
		return null

	# 在 pool_picks 中按权重再抽 1
	var total: int = 0
	for p in pool_picks:
		total += int(p.get("weight", 3))
	return pool_picks[_weighted_index(pool_picks, total)]


func _weighted_index(candidates: Array, total_weight: int) -> int:
	if total_weight <= 0 or candidates.is_empty():
		return 0
	var roll: int = randi() % total_weight
	var acc: int = 0
	for i in range(candidates.size()):
		acc += int(candidates[i].get("weight", 3))
		if roll < acc:
			return i
	return candidates.size() - 1


func _check_trigger(ev: Dictionary) -> bool:
	if ev.has("trigger") and not _match_condition(ev["trigger"]):
		return false
	if ev.has("force_not"):
		for cond in ev["force_not"]:
			if _match_condition(cond):
				return false
	if ev.has("force_requires"):
		for cond in ev["force_requires"]:
			if not _match_condition(cond):
				return false
	return true


func _match_condition(cond: Dictionary) -> bool:
	var attr_name: String = cond.get("attribute", "")
	var value = _get_attribute(attr_name)
	if value == null:
		return true
	if cond.has("min") and int(value) < int(cond["min"]):
		return false
	if cond.has("max") and int(value) > int(cond["max"]):
		return false
	if cond.has("equals") and int(value) != int(cond["equals"]):
		return false
	return true


func get_visible_options(event: Dictionary) -> Array:
	var visible: Array = []
	for opt in event["options"]:
		if not opt.has("requires"):
			visible.append(opt)
			continue
		if _match_condition(opt["requires"]):
			visible.append(opt)
	return visible


# ─────────────── 选项应用 ───────────────

func apply_option(option: Dictionary) -> void:
	if option.has("branches"):
		var branches: Array = option["branches"]
		for branch in branches:
			if _match_condition(branch.get("requires", {})):
				_apply_effects(branch.get("effects", {}))
				last_result = branch.get("result", "")
				break
		_advance_day()
		return

	_apply_effects(option.get("effects", {}))
	last_result = option.get("result", "")
	_advance_day()


func _apply_effects(effects: Dictionary) -> void:
	for key in effects.keys():
		_apply_single_effect(key, int(effects[key]))


func _apply_single_effect(key: String, value: int) -> void:
	match key:
		"mood": mood = clamp(mood + value, 0, 100)
		"harmony": harmony = clamp(harmony + value, 0, 100)
		"immunity": immunity = clamp(immunity + value, 0, 100)
		"supplies": supplies = clamp(supplies + value, 0, 100)
		"son_crisis": son_crisis = value
		"talked_with_son": talked_with_son = value
		"son_perfect": son_perfect = value
		"test_good_ending": test_good_ending = value
		"good_dad": good_dad = value
		"account": account = value
		"online_love_pending": online_love_pending = value
		"duty": duty = value
		"is_volunteer": is_volunteer = value
		"eggs": eggs = max(0, eggs + value)
		"hot_noodles": hot_noodles = max(0, hot_noodles + value)


func _advance_day() -> void:
	if day < MAX_DAYS:
		day += 1
		pick_day_events()
	# 最后一天不再抽事件,等下次 apply_option 后 day=MAX_DAYS+1,is_game_over 会触发


# ─────────────── 结局判定 ───────────────

func is_game_over() -> bool:
	return day > MAX_DAYS or mood <= 0 or harmony <= 0 or immunity <= 0 or supplies <= 0


func is_victory() -> bool:
	if not is_game_over():
		return false
	var e: Dictionary = get_ending()
	return e["type"] == "perfect" or e["type"] == "normal"


func get_ending() -> Dictionary:
	if supplies <= 0:
		return _ending("bad", "还好有政府", "勉强度日。我们被当做了困难家庭,获得了街道网格员和其他下沉党员的免费援助。大家顿顿都有吃的了,但也没心思再去想任何事。")
	if mood <= 0:
		return _mood_zero_ending()
	if immunity <= 0:
		return _ending("bad", "需要医院", "刚开始儿子病倒了,然后是妻子和女儿。我烧到 40 度。我们在社区志愿者的帮助下进入了方舱医院,被拆分到不同地方。我要赶紧好起来,然后见他们。")
	if duty == 1 and son_perfect == 1 and good_dad == 1:
		return _ending("perfect", "在结束的那一天", "平平安安。当病毒的雾霾散去,你在短暂的喜悦后,更感到的是如释重负。妻子在给所有认识的朋友报平安,孩子们则更忧心即将到来的回堂测试。这个家庭没有被天灾打倒。想起沉重的防护服,你很惊讶自己扛下来了,湖北扛下来了,中国扛下来了。每当你回想起这段岁月,你也是抗疫一线基层防线一个英勇的标点——你就感到,热泪盈眶。")
	return _ending("normal", "平庸却坚定的结局", "这就够了。疫情见证了我们家庭的努力,谁都没有被打倒。我们对未来充满期望。")


func _mood_zero_ending() -> Dictionary:
	var text: String
	if son_perfect == 0:
		text = "他在哪?一个夜里,儿子打开了门,然后再也没回来。没人知道他是怎么做到的,那么多监控和卡口管理人员。妻子每天都在哭。我们想他。"
	elif good_dad == 0:
		text = "她在那?我们以为女儿是最省心的,但是疫情后,她离开了,连句道别都没留。妻子每天都在哭。我们想她。"
	else:
		text = "我可能不是一个称职的父亲。前妻在女儿高考后跟我离婚,我带走没成年的儿子,而她们一起离开了。儿子还在上高中,我需要支撑下去。"
	return _ending("bad", "离开", text)


func _ending(type: String, title: String, text: String) -> Dictionary:
	return {"type": type, "title": title, "text": text}


# ─────────────── 属性查询 ───────────────

func _get_attribute(name: String):
	match name:
		"mood":      return mood
		"harmony":   return harmony
		"immunity":  return immunity
		"supplies":  return supplies
		"day":       return day
		"son_crisis": return son_crisis
		"talked_with_son": return talked_with_son
		"son_perfect": return son_perfect
		"test_good_ending": return test_good_ending
		"good_dad":  return good_dad
		"account":   return account
		"online_love_pending": return online_love_pending
		"duty":      return duty
		"is_volunteer": return is_volunteer
		"eggs":      return eggs
		"hot_noodles": return hot_noodles
	return null


func get_attribute_label(name: String) -> String:
	match name:
		"mood":     return "心情"
		"harmony":  return "和睦"
		"immunity": return "免疫"
		"supplies": return "物资"
	return name


# 家庭成员成长状态,用于主场景展示
func get_family_status() -> Dictionary:
	return {
		"爸爸": _format_status([
			{"label": "党员值守", "value": duty == 1},
			{"label": "社区志愿者", "value": is_volunteer == 1},
		]),
		"妈妈": _format_status([
			{"label": "家庭支柱", "value": harmony >= 60},
			{"label": "心力交瘁", "value": harmony < 30},
		]),
		"儿子": _format_status([
			{"label": "学业危机", "value": son_crisis == 1},
			{"label": "完美结局", "value": son_perfect == 1},
		]),
		"女儿": _format_status([
			{"label": "账号未处理", "value": account == 1 and good_dad == 0},
			{"label": "好爸爸达成", "value": good_dad == 1},
		]),
	}


func _format_status(items: Array) -> Array:
	var out: Array = []
	for it in items:
		out.append({"label": it["label"], "on": bool(it["value"])})
	return out