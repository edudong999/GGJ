extends Control

const EVENTS_PER_ROUND: int = 3
const ATTRS: Array = ["mood", "harmony", "immunity", "supplies"]

@onready var round_label: Label = $Margin/VBox/TopBar/RoundLabel
@onready var mood_label: Label = $Margin/VBox/StatusBar/MoodLabel
@onready var harmony_label: Label = $Margin/VBox/StatusBar/HarmonyLabel
@onready var immunity_label: Label = $Margin/VBox/StatusBar/ImmunityLabel
@onready var supplies_label: Label = $Margin/VBox/StatusBar/SuppliesLabel
@onready var events_bar: HBoxContainer = $Margin/VBox/EventsBar
@onready var settlement_panel: PanelContainer = $Margin/VBox/SettlementPanel
@onready var settlement_title: Label = $Margin/VBox/SettlementPanel/SettlementVBox/Title
@onready var settlement_event_info: Label = $Margin/VBox/SettlementPanel/SettlementVBox/EventInfo
@onready var settlement_result: Label = $Margin/VBox/SettlementPanel/SettlementVBox/Result
@onready var settlement_diffs: Label = $Margin/VBox/SettlementPanel/SettlementVBox/Diffs
@onready var continue_button: Button = $Margin/VBox/SettlementPanel/SettlementVBox/ContinueBtn
@onready var end_overlay: Panel = $EndOverlay
@onready var end_label: Label = $EndOverlay/EndVBox/EndLabel
@onready var restart_button: Button = $EndOverlay/EndVBox/RestartButton

var event_panels: Array = []  # [{panel, title, desc, options_container}]


func _ready() -> void:
	continue_button.pressed.connect(_on_continue_settlement)
	restart_button.pressed.connect(_on_restart_pressed)
	GameState.start_new_game()
	_build_event_panels()
	refresh()


func _build_event_panels() -> void:
	for i in range(EVENTS_PER_ROUND):
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var vbox := VBoxContainer.new()
		panel.add_child(vbox)

		var title := Label.new()
		title.name = "Title"
		title.add_theme_font_size_override("font_size", 22)
		vbox.add_child(title)

		var desc := Label.new()
		desc.name = "Desc"
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(desc)

		var opts := VBoxContainer.new()
		opts.name = "OptionsContainer"
		vbox.add_child(opts)

		events_bar.add_child(panel)
		event_panels.append({
			"panel": panel,
			"title": title,
			"desc": desc,
			"options_container": opts,
		})


func refresh() -> void:
	round_label.text = "第 %d / %d 轮" % [GameState.round, GameState.MAX_ROUNDS]
	mood_label.text = "心情: %d" % GameState.mood
	harmony_label.text = "和睦: %d" % GameState.harmony
	immunity_label.text = "免疫: %d" % GameState.immunity
	supplies_label.text = "物资: %d" % GameState.supplies
	_refresh_event_panels()


func _refresh_event_panels() -> void:
	for i in range(EVENTS_PER_ROUND):
		var card: Dictionary = event_panels[i]
		var panel: PanelContainer = card["panel"]
		var opts_container: VBoxContainer = card["options_container"]
		for c in opts_container.get_children():
			c.queue_free()

		if i < GameState.current_round_events.size():
			var ev: Dictionary = GameState.current_round_events[i]
			card["title"].text = ev["title"]
			card["desc"].text = ev["description"]
			panel.visible = true

			var visible_options: Array = GameState.get_visible_options(ev)
			for j in range(visible_options.size()):
				var opt: Dictionary = visible_options[j]
				var btn := Button.new()
				btn.text = "%d. %s" % [j + 1, opt["text"]]
				btn.pressed.connect(_on_choose_option.bind(i, j, visible_options))
				opts_container.add_child(btn)
		else:
			panel.visible = false


func _on_choose_option(event_idx: int, option_idx: int, visible_options: Array) -> void:
	var ev: Dictionary = GameState.current_round_events[event_idx]
	var opt: Dictionary = visible_options[option_idx]
	var played_round: int = GameState.round

	var before: Dictionary = _snapshot_attributes()
	GameState.apply_option(opt)
	var diffs: Array = _compute_diffs(before)

	if GameState.is_game_over():
		_show_end(false)
		return
	if GameState.is_victory():
		_show_end(true)
		return

	_show_settlement(played_round, ev["title"], opt["text"], GameState.last_result, diffs)


func _snapshot_attributes() -> Dictionary:
	return {
		"mood": GameState.mood,
		"harmony": GameState.harmony,
		"immunity": GameState.immunity,
		"supplies": GameState.supplies,
	}


func _compute_diffs(before: Dictionary) -> Array:
	var diffs: Array = []
	for key in ATTRS:
		var delta: int = GameState[key] - int(before[key])
		if delta != 0:
			diffs.append({
				"name": GameState.get_attribute_label(key),
				"old": int(before[key]),
				"new": GameState[key],
				"delta": delta,
			})
	return diffs


func _show_settlement(played_round: int, event_title: String, option_text: String, result_text: String, diffs: Array) -> void:
	settlement_title.text = "第 %d 轮 · 结算" % played_round
	settlement_event_info.text = "事件: %s\n你的选择: %s" % [event_title, option_text]
	settlement_result.text = result_text if result_text != "" else "(无特别描述)"

	if diffs.is_empty():
		settlement_diffs.text = "(无变化)"
	else:
		var lines: Array = []
		for d in diffs:
			var sign := "+" if int(d["delta"]) > 0 else ""
			lines.append("  %s: %d → %d (%s%d)" % [d["name"], d["old"], d["new"], sign, int(d["delta"])])
		settlement_diffs.text = "\n".join(lines)

	events_bar.visible = false
	settlement_panel.visible = true


func _on_continue_settlement() -> void:
	settlement_panel.visible = false
	events_bar.visible = true
	refresh()


func _show_end(victory: bool) -> void:
	settlement_panel.visible = false
	events_bar.visible = false
	end_overlay.visible = true
	if victory:
		end_label.text = "🎉 你成功度过了疫情!\n家庭成员都健康地走过了这段日子。"
	else:
		end_label.text = "💀 这一次,你没能撑过去..."


func _on_restart_pressed() -> void:
	end_overlay.visible = false
	GameState.start_new_game()
	refresh()