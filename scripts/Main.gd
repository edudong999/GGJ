extends Control

const EVENTS_PER_ROUND: int = 3

@onready var round_label: Label = $Margin/VBox/TopBar/RoundLabel
@onready var mood_label: Label = $Margin/VBox/StatusBar/MoodLabel
@onready var harmony_label: Label = $Margin/VBox/StatusBar/HarmonyLabel
@onready var immunity_label: Label = $Margin/VBox/StatusBar/ImmunityLabel
@onready var supplies_label: Label = $Margin/VBox/StatusBar/SuppliesLabel
@onready var events_bar: HBoxContainer = $Margin/VBox/EventsBar
@onready var result_label: Label = $Margin/VBox/ResultLabel
@onready var hint_label: Label = $Margin/VBox/HintLabel
@onready var end_overlay: Panel = $EndOverlay
@onready var end_label: Label = $EndOverlay/EndVBox/EndLabel
@onready var restart_button: Button = $EndOverlay/EndVBox/RestartButton

var event_panels: Array = []  # [{panel, title, desc, select_btn}]


func _ready() -> void:
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

		var btn := Button.new()
		btn.name = "SelectBtn"
		btn.text = "选择此事件"
		btn.pressed.connect(_on_select_event.bind(i))
		vbox.add_child(btn)

		events_bar.add_child(panel)
		event_panels.append({
			"panel": panel,
			"title": title,
			"desc": desc,
			"select_btn": btn,
		})


func refresh() -> void:
	round_label.text = "第 %d / %d 轮" % [GameState.round, GameState.MAX_ROUNDS]
	mood_label.text = "心情: %d" % GameState.mood
	harmony_label.text = "和睦: %d" % GameState.harmony
	immunity_label.text = "免疫: %d" % GameState.immunity
	supplies_label.text = "物资: %d" % GameState.supplies
	result_label.text = GameState.last_result
	hint_label.text = "选择本轮发生的事件"
	_refresh_event_panels()


func _refresh_event_panels() -> void:
	for i in range(EVENTS_PER_ROUND):
		var card: Dictionary = event_panels[i]
		var panel: PanelContainer = card["panel"]
		_clear_option_container(panel)
		card["select_btn"].visible = true
		card["select_btn"].disabled = false

		if i < GameState.current_round_events.size():
			var ev: Dictionary = GameState.current_round_events[i]
			card["title"].text = ev["title"]
			card["desc"].text = ev["description"]
			panel.visible = true
		else:
			panel.visible = false


func _clear_option_container(panel: PanelContainer) -> void:
	for child in panel.get_children():
		var vbox: VBoxContainer = child
		for c in vbox.get_children():
			if c.name == "OptionsContainer":
				c.queue_free()


func _on_select_event(idx: int) -> void:
	var ev: Dictionary = GameState.current_round_events[idx]
	var card: Dictionary = event_panels[idx]
	card["select_btn"].visible = false

	var vbox: VBoxContainer = card["panel"].get_child(0)
	var opts_container := VBoxContainer.new()
	opts_container.name = "OptionsContainer"
	vbox.add_child(opts_container)

	var visible_options: Array = GameState.get_visible_options(ev)
	for i in range(visible_options.size()):
		var opt: Dictionary = visible_options[i]
		var btn := Button.new()
		btn.text = "%d. %s" % [i + 1, opt["text"]]
		btn.pressed.connect(_on_choose_option.bind(idx, i, visible_options))
		opts_container.add_child(btn)

	for j in range(EVENTS_PER_ROUND):
		if j != idx:
			event_panels[j]["select_btn"].disabled = true


func _on_choose_option(event_idx: int, option_idx: int, visible_options: Array) -> void:
	var opt: Dictionary = visible_options[option_idx]
	GameState.apply_option(opt)

	if GameState.is_game_over():
		_show_end(false)
		return
	if GameState.is_victory():
		_show_end(true)
		return

	refresh()


func _show_end(victory: bool) -> void:
	end_overlay.visible = true
	if victory:
		end_label.text = "🎉 你成功度过了疫情!\n家庭成员都健康地走过了这段日子。"
	else:
		end_label.text = "💀 这一次,你没能撑过去..."


func _on_restart_pressed() -> void:
	end_overlay.visible = false
	GameState.start_new_game()
	refresh()