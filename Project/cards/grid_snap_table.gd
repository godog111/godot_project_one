extends Control
class_name GridSnapTable

## 网格吸附牌桌基类
## 功能：
##   1. 固定间距的二维锚点网格（间距可配置）
##   2. 卡牌松手时，卡牌左上角吸附到最近空锚点；同名合并；异名找下一个空锚点
##   3. 桌面可拖动（中键/右键），动态扩展可见范围内的锚点
##   4. 可继承后手动调整尺寸与配置

# ─────────────────── 导出配置 ───────────────────

## 锚点在 X 轴的间距（建议为卡牌宽度的 1/2）
@export var snap_step_x: float = 70.0
## 锚点在 Y 轴的间距（建议为卡牌高度的 1/2）
@export var snap_step_y: float = 90.0
## 锚点可视调试：是否在编辑器/运行时绘制锚点小点
@export var debug_draw_anchors: bool = false
## 视口外额外扩展的锚点缓冲格数（防止边缘抖动）
@export var anchor_buffer: int = 3

# ─────────────────── 内部状态 ───────────────────

## 桌面世界坐标偏移（桌面拖动时累积）
var table_offset: Vector2 = Vector2.ZERO

## 锚点字典：键为 Vector2i（网格坐标），值为占用该锚点的卡牌节点（null = 空）
## 注意：只有「曾经放置过卡牌」的锚点才会出现在字典里，
##       查询时「不存在 = 空」等价于 null
var _anchor_map: Dictionary = {}   # Vector2i -> card node or null

## 桌面拖动状态
var _table_dragging: bool = false
var _table_drag_start_mouse: Vector2 = Vector2.ZERO
var _table_drag_start_offset: Vector2 = Vector2.ZERO

## 卡牌容器（子类可重定向到别的节点）
@onready var cards_container: Control = $Cards

# ─────────────────── 生命周期 ───────────────────

func _ready() -> void:
	set_process_input(true)
	# 加入 cardDropable group，让卡牌可以识别到这个牌桌
	add_to_group("cardDropable")
	# 连接鼠标进出信号，用于设置卡牌的 whichDeckMouseIn
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered() -> void:
	# whichDeckMouseIn 已由 card.gd _process 每帧实时检测，此处无需处理
	pass

func _on_mouse_exited() -> void:
	# whichDeckMouseIn 已由 card.gd _process 每帧实时检测，此处无需处理
	# 注意：不能在此清空 whichDeckMouseIn，否则拖到卡槽时会被误清除
	pass

func _process(_delta: float) -> void:
	if debug_draw_anchors:
		queue_redraw()

# ─────────────────── 公开 API ───────────────────

## 将一张卡牌放置到桌面
## 卡牌松手时调用：card_node 必须已有 cardName 属性
func place_card(card_node: card) -> void:
	if not card_node:
		return
	
	# ── 检测是否拖到删除区域 ──
	if _is_in_delete_zone(card_node):
		remove_card(card_node)
		return

	var card_world_pos: Vector2 = card_node.global_position
	var best_grid: Vector2i = _world_to_nearest_grid(card_world_pos)
	var min_grid_dbg := _world_to_nearest_grid(global_position)
	var max_grid_dbg := _world_to_nearest_grid(global_position + size)
	print("[place_card] card=%s | card_pos=%s | best_grid=%s | table_range=(%s~%s) | table_offset=%s | table_size=%s" % [
		card_node.cardName, card_world_pos, best_grid, min_grid_dbg, max_grid_dbg, table_offset, size])

	# BFS 找最近的可用锚点（空 or 同名合并）
	var target_grid: Vector2i = _find_available_anchor(best_grid, card_node)
	print("[place_card] _find_available_anchor 返回: %s" % target_grid)

	if target_grid == Vector2i(-99999, -99999):
		# 牌桌内找不到可用位置，回到原位
		var last_pos = card_node.get_meta("_last_valid_position", card_node.global_position)
		print("牌桌内无可用位置，卡牌回到原位")
		_place_at_position(card_node, last_pos)
		return

	var existing = _anchor_map.get(target_grid, null)

	if existing != null and is_instance_valid(existing) \
	   and existing.cardName == card_node.cardName:
		# ── 同名合并 ──
		_merge_cards(existing, card_node)
	else:
		# ── 放置到空锚点 ──
		_place_at_anchor(card_node, target_grid)

## 检测卡牌是否在删除区域内（子类可重写）
func _is_in_delete_zone(card_node: card) -> bool:
	return false

## 强制刷新所有卡牌位置（桌面拖动后调用）
func refresh_card_positions() -> void:
	for grid_pos in _anchor_map.keys():
		var c = _anchor_map[grid_pos]
		if c != null and is_instance_valid(c):
			var world_pos = _grid_to_world(grid_pos)
			c.follow_target = null  # 断开旧 follow_target，直接弹簧到新位置
			c.global_position = world_pos

## 移除卡牌的锚点记录（卡牌被拖起时调用）
func release_card(card_node: card) -> void:
	for grid_pos in _anchor_map.keys():
		if _anchor_map[grid_pos] == card_node:
			_anchor_map[grid_pos] = null
			break
	# 记录卡牌被拖起时的位置（用于找不到位置时回退）
	card_node.set_meta("_last_valid_position", card_node.global_position)

## 获取世界坐标对应的网格坐标
func world_to_grid(world_pos: Vector2) -> Vector2i:
	return _world_to_nearest_grid(world_pos)

## 获取网格坐标对应的世界坐标
func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return _grid_to_world(grid_pos)

## 兼容旧 deck.gd 接口：外部调用 add_card 时转发到 place_card
func add_card(card_node: card) -> void:
	place_card(card_node)

## 兼容旧 deck.gd 接口：update_weight（GridSnapTable 无重量系统，空实现）
func update_weight() -> void:
	pass

## 从牌桌移除卡牌（释放锚点并从容器移除）
func remove_card(card_node: card) -> void:
	if not card_node:
		return
	
	# 释放锚点占用
	release_card(card_node)
	
	# 从容器移除
	if card_node.get_parent() == cards_container:
		cards_container.remove_child(card_node)
	
	# 清理引用
	card_node.preDeck = null
	card_node.whichDeckMouseIn = null
	
	# 延迟删除，避免当前帧操作冲突
	card_node.queue_free()
	print("卡牌已从牌桌移除: %s" % card_node.cardName)

# ─────────────────── 核心逻辑 ───────────────────

## 世界坐标 → 最近的网格坐标（四舍五入到网格）
func _world_to_nearest_grid(world_pos: Vector2) -> Vector2i:
	var local = world_pos - table_offset
	var gx = int(round(local.x / snap_step_x))
	var gy = int(round(local.y / snap_step_y))
	return Vector2i(gx, gy)

## 网格坐标 → 世界坐标（锚点左上角在世界空间的位置）
func _grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(grid_pos.x * snap_step_x, grid_pos.y * snap_step_y) + table_offset

## BFS 搜索最近的可用锚点（只在牌桌范围内搜索）
## 返回可用格坐标；若找不到则返回 (-99999,-99999)
func _find_available_anchor(start: Vector2i, card_node: card) -> Vector2i:
	const MAX_RADIUS = 20  # 最大搜索半径（格数）
	
	# 计算牌桌的网格范围（使用节点的全局位置和尺寸）
	var min_grid := _world_to_nearest_grid(global_position)
	var max_grid := _world_to_nearest_grid(global_position + size)
	
	# 按 Chebyshev 距离（环形）逐层扩展
	for r in range(0, MAX_RADIUS + 1):
		var candidates: Array[Vector2i] = _ring_cells(start, r)
		
		# 按到 start 的欧氏距离排序，保证优先选最近的
		candidates.sort_custom(func(a, b):
			return a.distance_squared_to(start) < b.distance_squared_to(start)
		)
		
		for cell in candidates:
			# 检查是否在牌桌范围内
			if cell.x < min_grid.x or cell.x > max_grid.x or cell.y < min_grid.y or cell.y > max_grid.y:
				continue
			
			var existing = _anchor_map.get(cell, null)
			if existing == null or not is_instance_valid(existing):
				# 空锚点 ✓
				return cell
			if existing.cardName == card_node.cardName:
				# 同名可合并 ✓
				return cell
			# 异名占用，继续搜索
	
	return Vector2i(-99999, -99999)

## 生成以 center 为中心、半径为 r 的 Chebyshev 环上的所有格坐标
func _ring_cells(center: Vector2i, r: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if r == 0:
		result.append(center)
		return result
	for dx in range(-r, r + 1):
		for dy in range(-r, r + 1):
			if abs(dx) == r or abs(dy) == r:
				result.append(Vector2i(center.x + dx, center.y + dy))
	return result

## 同名合并
func _merge_cards(target: card, source: card) -> void:
	if target.doStack(source):
		# 播放飞入动画再删除 source
		_play_merge_animation(target, source)
	else:
		# 合并失败（超出堆叠上限），改为找下一个空锚点放置
		var start = _world_to_nearest_grid(source.global_position)
		var target_grid = _find_next_empty_anchor(start)
		_place_at_anchor(source, target_grid)

## 找下一个严格空锚点（不接受同名合并，供超出堆叠上限时使用）
func _find_next_empty_anchor(start: Vector2i) -> Vector2i:
	const MAX_RADIUS = 20
	for r in range(0, MAX_RADIUS + 1):
		var candidates = _ring_cells(start, r)
		candidates.sort_custom(func(a, b):
			return a.distance_squared_to(start) < b.distance_squared_to(start)
		)
		for cell in candidates:
			var existing = _anchor_map.get(cell, null)
			if existing == null or not is_instance_valid(existing):
				return cell
	return start

## 将卡牌放置到指定网格锚点
func _place_at_anchor(card_node: card, grid_pos: Vector2i) -> void:
	var world_pos = _grid_to_world(grid_pos)
	
	# 注册到锚点字典
	_anchor_map[grid_pos] = card_node
	
	# 确保卡牌在容器里
	if card_node.get_parent() != cards_container:
		if card_node.get_parent():
			card_node.get_parent().remove_child(card_node)
		cards_container.add_child(card_node)
	
	# 弹簧动画吸附到锚点
	var tween = create_tween()
	tween.tween_property(card_node, "global_position", world_pos, 0.18) \
		.set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)
	
	card_node.cardCurrentState = card.cardState.following
	card_node.follow_target = null  # GridSnapTable 自己管理位置，不用 follow_target
	card_node.preDeck = self

## 将卡牌移动到指定位置（不绑定锚点，用于回退到原位）
func _place_at_position(card_node: card, world_pos: Vector2) -> void:
	# 确保卡牌在容器里
	if card_node.get_parent() != cards_container:
		if card_node.get_parent():
			card_node.get_parent().remove_child(card_node)
		cards_container.add_child(card_node)
	
	# 弹簧动画移动到指定位置
	var tween = create_tween()
	tween.tween_property(card_node, "global_position", world_pos, 0.18) \
		.set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)
	
	card_node.cardCurrentState = card.cardState.following
	card_node.follow_target = null
	card_node.preDeck = self

## 合并飞入动画
func _play_merge_animation(target: card, source: card) -> void:
	var tween = create_tween()
	tween.tween_property(source, "global_position", target.global_position, 0.15) \
		.set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)
	await tween.finished
	source.queue_free()

# ─────────────────── 桌面拖动 ───────────────────

func _input(event: InputEvent) -> void:
	# 中键拖动桌面
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				_table_dragging = true
				_table_drag_start_mouse = event.global_position
				_table_drag_start_offset = table_offset
			else:
				_table_dragging = false
	
	if event is InputEventMouseMotion and _table_dragging:
		var delta = event.global_position - _table_drag_start_mouse
		table_offset = _table_drag_start_offset + delta
		_on_table_moved()

## 桌面移动后的回调（子类可重写）
func _on_table_moved() -> void:
	# 刷新所有卡牌的世界坐标
	for grid_pos in _anchor_map.keys():
		var c = _anchor_map[grid_pos]
		if c != null and is_instance_valid(c) \
		   and c.cardCurrentState == card.cardState.following:
			c.global_position = _grid_to_world(grid_pos)

# ─────────────────── 调试绘制 ───────────────────

func _draw() -> void:
	if not debug_draw_anchors:
		return
	
	var vp_rect = get_viewport_rect()
	var min_gx = int(floor((-table_offset.x - anchor_buffer * snap_step_x) / snap_step_x))
	var max_gx = int(ceil((vp_rect.size.x - table_offset.x + anchor_buffer * snap_step_x) / snap_step_x))
	var min_gy = int(floor((-table_offset.y - anchor_buffer * snap_step_y) / snap_step_y))
	var max_gy = int(ceil((vp_rect.size.y - table_offset.y + anchor_buffer * snap_step_y) / snap_step_y))
	
	for gx in range(min_gx, max_gx + 1):
		for gy in range(min_gy, max_gy + 1):
			var world = _grid_to_world(Vector2i(gx, gy))
			var local = world  # Control 坐标即世界坐标（无相机）
			var occupied = _anchor_map.get(Vector2i(gx, gy), null)
			var color = Color(0, 1, 0, 0.4) if occupied == null else Color(1, 0.3, 0, 0.6)
			draw_circle(local, 3.0, color)
