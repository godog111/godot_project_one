extends GridSnapTable
class_name CardTableMain

## 卡牌桌主场景
## 继承自 GridSnapTable，获得：
##   - 二维锚点网格吸附
##   - 桌面中键拖动
##   - 同名合并 / 异名找空锚点
## 本脚本负责：初始卡牌生成、键盘快捷键、CardInfo 加载

# ─────────────────── 配置 ───────────────────

## 初始卡牌列表（可在 Inspector 修改）
@export var initial_cards: Array[String] = [
	"ice", "ice", "ice",
	"Stone", "Stone",
	"Glod",
	"npc_1", "npc_2",
	"site_1", "site_2",
	"shop"
]

## 卡牌场景（使用基础 card 场景）
@export var card_scene: PackedScene = preload("res://cards/card.tscn")
## 事件面板场景
@export var event_panel_scene: PackedScene = preload("res://event/event.tscn")

# ─────────────────── 节点引用 ───────────────────

@onready var background: ColorRect = $Background
@onready var title_label: Label = $TitleLabel
@onready var help_label: Label = $HelpLabel
@onready var delete_zone: ColorRect = $DeleteZone

# 事件面板实例（单例，复用）
var _event_panel: EventPanel = null

# ─────────────────── 初始化 ───────────────────

func _ready() -> void:
	super._ready()  # 确保 GridSnapTable._ready 执行（add_to_group 等初始化）
	print("=== 卡牌桌主场景初始化（GridSnapTable）===")
	_set_fullscreen()
	_ensure_card_info_loaded()
	# 等一帧确保视口尺寸就绪
	await get_tree().process_frame
	_spawn_initial_cards()
	print("=== 初始化完成 ===")
	print("操作：鼠标拖动卡牌 | 中键拖动桌面 | F1调试 | F4重生成 | ESC退出 | 拖到右下角删除")
	if help_label:
		help_label.text = "拖动卡牌自动吸附锚点 | 中键拖动桌面 | F1调试 | F4重生成 | ESC退出 | 拖到右下角删除"
	
	# 设置删除区域交互
	_setup_delete_zone()

func _set_fullscreen() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_right = 0
	offset_bottom = 0
	if background:
		background.anchor_right = 1.0
		background.anchor_bottom = 1.0
		background.offset_right = 0
		background.offset_bottom = 0

func _setup_delete_zone() -> void:
	if not delete_zone:
		return
	# 让删除区域接收鼠标事件
	delete_zone.mouse_filter = Control.MOUSE_FILTER_PASS
	# 高亮效果
	delete_zone.mouse_entered.connect(func(): delete_zone.color = Color(0.9, 0.3, 0.3, 0.5))
	delete_zone.mouse_exited.connect(func(): delete_zone.color = Color(0.8, 0.2, 0.2, 0.3))

## 重写：检测卡牌是否在删除区域内
func _is_in_delete_zone(card_node: card) -> bool:
	if not delete_zone:
		return false
	var card_rect = card_node.get_global_rect()
	var zone_rect = delete_zone.get_global_rect()
	# 检测卡牌中心是否在删除区域内
	var card_center = card_rect.get_center()
	return zone_rect.has_point(card_center)

func _ensure_card_info_loaded() -> void:
	# 检查是否已有 CardInfo 单例
	if Engine.has_singleton("CardInfo"):
		var ci = Engine.get_singleton("CardInfo")
		if ci and ci.get_card_count() > 0:
			print("CardInfo 已加载: %d 条卡牌记录" % ci.get_card_count())
			return
	
	print("警告: CardInfo 未加载，尝试手动加载...")
	var script = preload("res://assets/cardInfo.gd")
	if script:
		var inst = script.new()
		inst.load_json_data()
		print("CardInfo 手动加载: %d 条卡牌记录" % inst.get_card_count())

# ─────────────────── 卡牌生成 ───────────────────

func _spawn_initial_cards() -> void:
	if not card_scene:
		push_error("card_scene 未设置")
		return

	print("生成 %d 张初始卡牌..." % initial_cards.size())

	# 计算牌桌可容纳的网格范围（使用节点的全局位置）
	var min_grid := world_to_grid(global_position)
	var max_grid := world_to_grid(global_position + size)
	var grid_cols = max_grid.x - min_grid.x + 1
	var grid_rows = max_grid.y - min_grid.y + 1
	print("牌桌网格范围: (%d,%d) 到 (%d,%d), 共 %d 列 %d 行" % [min_grid.x, min_grid.y, max_grid.x, max_grid.y, grid_cols, grid_rows])

	# 按名称分组，同名叠在同一起始格，依靠 place_card 自动合并
	var group_index := 0
	var name_to_grid: Dictionary = {}  # cardName -> 分配到的初始格

	for card_key in initial_cards:
		var card_inst = card_scene.instantiate() as card
		if not card_inst:
			push_error("卡牌实例化失败: %s" % card_key)
			continue

		# 先加入容器，再初始化（initCard 需要节点在树中）
		cards_container.add_child(card_inst)
		card_inst.add_to_group("card")

		if card_inst.has_method("initCard"):
			card_inst.initCard(card_key)

		# 为每种名称分配一个起始网格格子（确保在牌桌范围内）
		if not name_to_grid.has(card_key):
			var col = group_index % grid_cols
			var row = group_index / grid_cols
			# 限制在牌桌范围内
			if row >= grid_rows:
				push_warning("卡牌 %s 超出牌桌范围，跳过生成" % card_key)
				card_inst.queue_free()
				continue
			name_to_grid[card_key] = Vector2i(min_grid.x + col, min_grid.y + row)
			group_index += 1

		# 先把卡牌移到起始格的世界位置，再调用 place_card
		var start_grid: Vector2i = name_to_grid[card_key]
		card_inst.global_position = grid_to_world(start_grid)
		card_inst.cardCurrentState = card.cardState.following

		# 通过 GridSnapTable 的放置逻辑处理合并/吸附
		place_card(card_inst)

	print("卡牌生成完成")

# ─────────────────── 键盘快捷键 ───────────────────

func _input(event: InputEvent) -> void:
	# 先交给父类处理桌面拖动
	super._input(event)

	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				get_tree().quit()
			KEY_F1:
				_print_debug_info()
			KEY_F2:
				_print_slot_debug()
			KEY_F4:
				_respawn_cards()

func _print_debug_info() -> void:
	print("\n=== GridSnapTable 调试信息 ===")
	print("table_offset: %s" % table_offset)
	print("锚点占用数: %d" % _anchor_map.size())
	print("卡牌总数: %d" % cards_container.get_child_count())
	for grid_pos in _anchor_map.keys():
		var c = _anchor_map[grid_pos]
		var name_str = c.cardName if c and is_instance_valid(c) else "（已销毁）"
		print("  格 %s -> %s" % [grid_pos, name_str])

func _respawn_cards() -> void:
	print("重新生成卡牌...")
	_anchor_map.clear()
	for child in cards_container.get_children():
		child.queue_free()
	await get_tree().process_frame
	_spawn_initial_cards()
	print("卡牌重新生成完成")

## F2 诊断：打印所有 cardDropable 节点的 global_rect，用于排查卡槽检测问题
func _print_slot_debug() -> void:
	print("\n=== cardDropable 节点诊断 ===")
	var nodes = get_tree().get_nodes_in_group("cardDropable")
	print("共 %d 个节点" % nodes.size())
	for node in nodes:
		if node is Control:
			var r = node.get_global_rect()
			print("  [%s] visible=%s  global_pos=%s  size=%s  rect=%s" % [
				node.name, node.visible, node.global_position, node.size, r
			])
		else:
			print("  [%s] (非Control节点)" % node.name)
	print("=== 诊断结束 ===\n")

## 添加一张 ice 卡牌（测试用）
func _on_add_ice_button_pressed() -> void:
	print("添加 ice 卡牌...")
	_add_single_card("ice")

## 通过卡牌名称添加新卡（供 EventPanel 的 result 执行器调用）
func add_new_card_by_name(card_key: String) -> void:
	_add_single_card(card_key)

## 打开事件面板（测试入口）
func _on_test_event_button_pressed() -> void:
	var panel = _get_or_create_event_panel()
	if panel:
		panel.open_panel()

## 打开事件面板（通过 eventId）
func open_event_panel_by_id(event_id: int) -> void:
	var panel = _get_or_create_event_panel()
	panel.open_event_by_id(event_id)

## 打开事件面板（通过触发卡牌）
func open_event_panel_for_card(trigger_card: card) -> void:
	var panel = _get_or_create_event_panel()
	panel.open_event(trigger_card)

## 获取或创建事件面板实例（单例复用）
func _get_or_create_event_panel() -> EventPanel:
	if _event_panel != null and is_instance_valid(_event_panel):
		return _event_panel
	if event_panel_scene == null:
		push_error("[CardTableMain] event_panel_scene 未设置")
		return null
	_event_panel = event_panel_scene.instantiate() as EventPanel
	# 放在界面最顶层
	get_tree().get_root().add_child(_event_panel)
	_event_panel.visible = false
	print("[CardTableMain] 事件面板已创建")
	return _event_panel

## 添加单张卡牌到牌桌
func _add_single_card(card_key: String) -> void:
	if not card_scene:
		push_error("card_scene 未设置")
		return
	
	var card_inst = card_scene.instantiate() as card
	if not card_inst:
		push_error("卡牌实例化失败: %s" % card_key)
		return
	
	cards_container.add_child(card_inst)
	card_inst.add_to_group("card")
	
	if card_inst.has_method("initCard"):
		card_inst.initCard(card_key)
	
	# 放在牌桌可见区域内（靠近中心的网格对齐位置），不依赖鼠标坐标
	var table_rect = get_global_rect()
	var spawn_pos = table_rect.get_center()
	card_inst.global_position = spawn_pos
	card_inst.cardCurrentState = card.cardState.following
	
	# 使用 GridSnapTable 的放置逻辑处理合并/吸附
	place_card(card_inst)
	
	print("已添加卡牌: %s" % card_key)
