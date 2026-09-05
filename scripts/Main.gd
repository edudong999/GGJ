extends Control

const EVENTS_PER_ROUND: int = 3
const ATTRS: Array = ["mood", "harmony", "immunity", "supplies"]
const SIDEBAR_EXPANDED_WIDTH: int = 260
const SIDEBAR_COLLAPSED_WIDTH: int = 40

@onready var main_scene: Panel = $MainScene
@onready var day_value_label: Label = $MainScene/Margin/VBox/TopBar/DayCell/VBox/DayValue
@onready var attr_row: HBoxContainer = $MainScene/Margin/VBox/TopBar/AttrRow

@onready var sidebar: Panel = $MainScene/Margin/VBox/Body/Sidebar
@onready var sidebar_title: Label = $MainScene/Margin/VBox/Body/Sidebar/Margin/VBox/Header/Title
@onready var sidebar_body: VBoxContainer = $MainScene/Margin/VBox/Body/Sidebar/Margin/VBox/SidebarBody
@onready var sidebar_toggle_btn: Button = $MainScene/Margin/VBox/Body/Sidebar/Margin/VBox/Header/ToggleBtn

@onready var card_list: Panel = $CardList
@onready var card_list_day_label: Label = $CardList/Margin/VBox/TopBar/DayLabel
@onready var card_list_attr_label: Label = $CardList/Margin/VBox/TopBar/AttrLabel
@onready var events_bar: HBoxContainer = $CardList/Margin/VBox/EventsBar

@onready var settlement_panel: Panel = $Settlement
@onready var settlement_title: Label = $Settlement/Margin/VBox/Title
@onready var settlement_event_info: Label = $Settlement/Margin/VBox/EventInfo
@onready var settlement_result: Label = $Settlement/Margin/VBox/Result
@onready var settlement_diffs: Label = $Settlement/Margin/VBox/Diffs
@onready var continue_button: Button = $Settlement/Margin/VBox/ContinueBtn

@onready var end_overlay: Panel = $EndOverlay
@onready var end_photo_bg: ColorRect = $EndOverlay/VBox/Photo/PhotoBg
@onready var end_photo_label: Label = $EndOverlay/VBox/Photo/PhotoLabel
@onready var end_title_label: Label = $EndOverlay/VBox/TitleLabel
@onready var end_text_label: Label = $EndOverlay/VBox/TextLabel
@onready var collapse_button: Button = $EndOverlay/VBox/ButtonRow/CollapseBtn
@onready var restart_button: Button = $EndOverlay/VBox/ButtonRow/RestartButton
@onready var end_badge: Button = $EndBadge

@onready var card_button: Button = $CardButton
@onready var menu_btn: Button = $MenuBtn
@onready var menu_popup: Panel = $MenuPopup
@onready var menu_continue_btn: Button = $MenuPopup/Margin/VBox/ContinueBtn
@onready var menu_restart_btn: Button = $MenuPopup/Margin/VBox/RestartBtn
@onready var menu_quit_btn: Button = $MenuPopup/Margin/VBox/QuitBtn

@onready var start_screen: Panel = $StartScreen
@onready var start_btn: Button = $StartScreen/VBox/StartBtn
@onready var start_quit_btn: Button = $StartScreen/VBox/StartQuitBtn

var event_panels: Array = []
var cards_open: bool = false
var sidebar_collapsed: bool = false


func _ready() -> void:
	continue_button.pressed.connect(_on_continue_settlement)
	restart_button.pressed.connect(_on_restart_pressed)
	collapse_button.pressed.connect(_on_collapse_ending)
	end_badge.pressed.connect(_on_show_ending)
	sidebar_toggle_btn.pressed.connect(_on_sidebar_toggle)
	card_button.pressed.connect(_on_card_button_pressed)
	menu_btn.pressed.connect(_on_menu_pressed)
	menu_continue_btn.pressed.connect(_on_menu_continue)
	menu_restart_btn.pressed.connect(_on_menu_restart)
	menu_quit_btn.pressed.connect(_on_menu_quit)
	start_btn.pressed.connect(_on_start_pressed)
	start_quit_btn.pressed.connect(_on_menu_quit)
	GameState.start_new_game()
	_build_event_panels()
	_show_start_screen()


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


# ─────────────── 启动 / 菜单 ───────────────

func _show_start_screen() -> void:
	main_scene.visible = false
	card_list.visible = false
	settlement_panel.visible = false
	end_overlay.visible = false
	end_badge.visible = false
	card_button.visible = false
	menu_popup.visible = false
	start_screen.visible = true


func _on_start_pressed() -> void:
	start_screen.visible = false
	main_scene.visible = true
	card_button.visible = true
	cards_open = false
	_refresh_main_scene()


func _on_menu_pressed() -> void:
	menu_popup.visible = not menu_popup.visible


func _on_menu_continue() -> void:
	menu_popup.visible = false


func _on_menu_restart() -> void:
	menu_popup.visible = false
	_restart_to_start()


func _on_menu_quit() -> void:
	get_tree().quit()


func _restart_to_start() -> void:
	end_overlay.visible = false
	end_badge.visible = false
	card_list.visible = false
	settlement_panel.visible = false
	card_button.visible = false
	cards_open = false
	GameState.start_new_game()
	_refresh_event_panels()
	_show_start_screen()


# ─────────────── 主场景渲染 ───────────────

func _refresh_main_scene() -> void:
	day_value_label.text = "Day %d / %d" % [GameState.day, GameState.MAX_DAYS]
	card_list_day_label.text = "Day %d / %d" % [GameState.day, GameState.MAX_DAYS]
	card_list_attr_label.text = "心情 %d · 和睦 %d · 免疫 %d · 物资 %d" % [
		GameState.mood, GameState.harmony, GameState.immunity, GameState.supplies,
	]
	_render_family_status()
	_render_attributes()


func _render_family_status() -> void:
	for child in sidebar_body.get_children():
		child.queue_free()
	var status: Dictionary = GameState.get_family_status()
	for member_name in ["爸爸", "妈妈", "儿子", "女儿"]:
		var member_box := VBoxContainer.new()
		member_box.add_theme_constant_override("separation", 4)

		var name_label := Label.new()
		name_label.text = member_name
		name_label.add_theme_font_size_override("font_size", 18)
		member_box.add_child(name_label)

		var items: Array = status.get(member_name, [])
		if items.is_empty():
			var placeholder := Label.new()
			placeholder.text = "  (无标记)"
			placeholder.add_theme_font_size_override("font_size", 14)
			placeholder.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6, 1))
			member_box.add_child(placeholder)
		else:
			for it in items:
				var tag := Label.new()
				tag.text = ("  ✓ " if it["on"] else "  ○ ") + it["label"]
				tag.add_theme_font_size_override("font_size", 14)
				tag.add_theme_color_override("font_color",
					Color(0.4, 0.75, 0.4, 1) if it["on"] else Color(0.55, 0.55, 0.6, 1))
				member_box.add_child(tag)
		sidebar_body.add_child(member_box)


func _render_attributes() -> void:
	for child in attr_row.get_children():
		child.queue_free()
	for key in ATTRS:
		var box := PanelContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		box.add_child(hbox)

		var value: int = GameState[key]
		var color: Color = _attr_color(value)

		var name_label := Label.new()
		name_label.text = GameState.get_attribute_label(key)
		name_label.add_theme_font_size_override("font_size", 16)
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hbox.add_child(name_label)

		var value_label := Label.new()
		value_label.text = "%d" % value
		value_label.custom_minimum_size = Vector2(40, 0)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value_label.add_theme_font_size_override("font_size", 22)
		value_label.add_theme_color_override("font_color", color)
		hbox.add_child(value_label)

		var bar := ProgressBar.new()
		bar.min_value = 0
		bar.max_value = 100
		bar.value = value
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 10)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER

		var bg_style := StyleBoxFlat.new()
		bg_style.bg_color = Color(0.18, 0.18, 0.22)
		bg_style.corner_radius_top_left = 3
		bg_style.corner_radius_top_right = 3
		bg_style.corner_radius_bottom_left = 3
		bg_style.corner_radius_bottom_right = 3
		bar.add_theme_stylebox_override("background", bg_style)

		var fill_style := StyleBoxFlat.new()
		fill_style.bg_color = color
		fill_style.corner_radius_top_left = 3
		fill_style.corner_radius_top_right = 3
		fill_style.corner_radius_bottom_left = 3
		fill_style.corner_radius_bottom_right = 3
		bar.add_theme_stylebox_override("fill", fill_style)

		hbox.add_child(bar)
		attr_row.add_child(box)


func _attr_color(value: int) -> Color:
	if value <= 20: return Color(0.85, 0.4, 0.4)
	if value <= 40: return Color(0.85, 0.7, 0.4)
	if value <= 70: return Color(0.85, 0.85, 0.85)
	return Color(0.5, 0.85, 0.55)


# ─────────────── 侧边栏 ───────────────

func _on_sidebar_toggle() -> void:
	sidebar_collapsed = not sidebar_collapsed
	if sidebar_collapsed:
		sidebar.custom_minimum_size = Vector2(SIDEBAR_COLLAPSED_WIDTH, 0)
		sidebar_body.visible = false
		sidebar_title.visible = false
		sidebar_toggle_btn.text = "▶"
	else:
		sidebar.custom_minimum_size = Vector2(SIDEBAR_EXPANDED_WIDTH, 0)
		sidebar_body.visible = true
		sidebar_title.visible = true
		sidebar_toggle_btn.text = "◀"


# ─────────────── 卡牌展开/收起 ───────────────

func _on_card_button_pressed() -> void:
	if end_overlay.visible:
		return
	if cards_open:
		_close_cards()
	else:
		_open_cards()


func _open_cards() -> void:
	cards_open = true
	main_scene.visible = false
	settlement_panel.visible = false
	card_list.visible = true
	card_button.text = "Close ▴"
	_refresh_event_panels()


func _close_cards() -> void:
	cards_open = false
	card_list.visible = false
	settlement_panel.visible = false
	main_scene.visible = true
	card_button.text = "Cards ▾"
	_refresh_main_scene()


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


# ─────────────── 选项/结算 ───────────────

func _on_choose_option(event_idx: int, option_idx: int, visible_options: Array) -> void:
	var ev: Dictionary = GameState.current_round_events[event_idx]
	var opt: Dictionary = visible_options[option_idx]
	var played_day: int = GameState.day

	var before: Dictionary = _snapshot_attributes()
	GameState.apply_option(opt)
	var diffs: Array = _compute_diffs(before)

	_show_settlement(played_day, ev["title"], opt["text"], GameState.last_result, diffs)


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


func _show_settlement(played_day: int, event_title: String, option_text: String, result_text: String, diffs: Array) -> void:
	settlement_title.text = "第 %d 天 · 结算" % played_day
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

	card_list.visible = false
	settlement_panel.visible = true
	card_button.text = "Cards ▾"


func _on_continue_settlement() -> void:
	settlement_panel.visible = false
	if GameState.is_game_over():
		_show_ending()
		return
	main_scene.visible = true
	_refresh_main_scene()


# ─────────────── 结局 ───────────────

func _show_ending() -> void:
	main_scene.visible = false
	card_list.visible = false
	settlement_panel.visible = false
	card_button.visible = false
	end_overlay.visible = true
	end_badge.visible = false
	menu_popup.visible = false
	var e: Dictionary = GameState.get_ending()
	end_title_label.text = e["title"]
	end_text_label.text = e["text"]
	_apply_ending_photo(e["title"])
	end_badge.text = "结局: %s ▴ 展开" % e["title"]


func _apply_ending_photo(title: String) -> void:
	match title:
		"在结束的那一天":
			end_photo_bg.color = Color(0.95, 0.82, 0.35, 1)
			end_photo_label.text = "圆"
		"平庸却坚定的结局":
			end_photo_bg.color = Color(0.72, 0.66, 0.5, 1)
			end_photo_label.text = "稳"
		"还好有政府":
			end_photo_bg.color = Color(0.4, 0.55, 0.72, 1)
			end_photo_label.text = "援"
		"离开":
			end_photo_bg.color = Color(0.55, 0.28, 0.28, 1)
			end_photo_label.text = "去"
		"需要医院":
			end_photo_bg.color = Color(0.45, 0.65, 0.55, 1)
			end_photo_label.text = "医"
		_:
			end_photo_bg.color = Color(0.3, 0.3, 0.4, 1)
			end_photo_label.text = "?"


func _on_collapse_ending() -> void:
	end_overlay.visible = false
	end_badge.visible = true
	main_scene.visible = true
	_refresh_main_scene()


func _on_show_ending() -> void:
	main_scene.visible = false
	end_overlay.visible = true
	end_badge.visible = false


func _on_restart_pressed() -> void:
	_restart_to_start()