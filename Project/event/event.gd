extends Control
class_name EventPanel

## 事件面板
## 流程：
##   1. open_panel() 打开空白面板，只显示触发槽
##   2. 玩家拖任意卡到触发槽 → 根据卡的 eventId 加载事件
##   3. 玩家填满所有条件卡槽 → 点确定 → 执行 result

# ── 节点引用 ──────────────────────────────────────
@onready var title_label: Label             = $title
@onready var desc_panel: Panel              = $descriptionText
@onready var desc_label: Label              = $descriptionText/descriptionText
@onready var slot_container: Panel          = $slot
@onready var confirm_button: Button         = $Button
@onready var close_button: Button           = $CloseButton
@onready var trigger_slot: CardSlot         = $slot/TriggerSlot

# 条件卡槽列表（Slot1~Slot6，按 slot_index 排序）
var slots: Array[CardSlot] = []

# ── 事件状态 ──────────────────────────────────────
enum EventState { IDLE, WAITING, CONDITION_MET, COMPLETED }
var event_state: EventState = EventState.IDLE

var current_event_data: Dictionary = {}
var required_slot_count: int = 0

# ── 初始化 ────────────────────────────────────────
func _ready() -> void:
	_collect_slots()
	_reset_to_idle()

func _collect_slots() -> void:
	slots.clear()
	for child in slot_container.get_children():
		# slot_index == -1 是触发槽，跳过
		if child is CardSlot and child.slot_index >= 0:
			slots.append(child)
			child.card_placed.connect(_on_condition_card_placed)
			child.card_removed.connect(_on_condition_card_removed)
	slots.sort_custom(func(a, b): return a.slot_index < b.slot_index)
	print("[EventPanel] 条件卡槽数量: %d" % slots.size())

	# 触发槽单独连接
	if trigger_slot:
		trigger_slot.required_card_type = ""  # 接受任意卡
		trigger_slot.card_placed.connect(_on_trigger_card_placed)
		trigger_slot.card_removed.connect(_on_trigger_card_removed)

# ── 公开接口 ──────────────────────────────────────

## 打开面板（空白状态，等待玩家放入触发卡）
func open_panel() -> void:
	_reset_to_idle()
	visible = true
	print("[EventPanel] 面板已打开，等待触发卡")

## 兼容旧接口：直接通过 eventId 打开（跳过触发槽）
func open_event_by_id(event_id: int) -> void:
	_reset_to_idle()
	visible = true
	_load_event(event_id)

## 兼容旧接口：通过触发卡打开
func open_event(trigger_card: card) -> void:
	_reset_to_idle()
	visible = true
	var event_id = trigger_card.cardInfo.get("eventId", 0)
	if event_id == 0:
		push_warning("[EventPanel] 该卡牌没有 eventId")
		return
	_load_event(event_id)

# ── 触发槽回调 ──────────────────────────────────

func _on_trigger_card_placed(_slot_index: int, placed_card: card) -> void:
	var event_id = placed_card.cardInfo.get("eventId", 0)
	print("[EventPanel] 触发卡放入：%s  eventId=%s" % [placed_card.cardName, event_id])
	if event_id == 0:
		push_warning("[EventPanel] 该卡牌没有 eventId，无法加载事件")
		title_label.text = "该卡牌无对应事件"
		desc_label.text = ""
		_set_all_slots_visible(false)
		return
	_load_event(int(event_id))

func _on_trigger_card_removed(_slot_index: int) -> void:
	print("[EventPanel] 触发卡移除，重置为 IDLE")
	_reset_to_idle()

# ── 事件加载 ──────────────────────────────────────

func _load_event(event_id: int) -> void:
	var event_data = CardInfo.get_event(event_id)
	if event_data.is_empty():
		push_warning("[EventPanel] 找不到 eventId=%d 的事件" % event_id)
		title_label.text = "未知事件 (%d)" % event_id
		desc_label.text = ""
		_set_all_slots_visible(false)
		return

	current_event_data = event_data
	event_state = EventState.WAITING
	required_slot_count = _count_required_slots(event_data)
	print("[EventPanel] 加载事件 %d，需要 %d 个条件卡槽" % [event_id, required_slot_count])

	_update_title(event_data)
	_update_description(false)
	_setup_slots(event_data)
	_set_confirm_enabled(false)

# ── 内部：UI 更新 ──────────────────────────────────

func _reset_to_idle() -> void:
	event_state = EventState.IDLE
	current_event_data = {}
	required_slot_count = 0
	title_label.text = "拖入卡牌以查看事件"
	desc_label.text = ""
	_set_all_slots_visible(false)
	_set_confirm_enabled(false)
	# 触发槽始终可见
	if trigger_slot:
		trigger_slot.visible = true
	# 清空条件卡槽中的卡
	for s in slots:
		if s.is_occupied:
			var c = s.remove_card()
			if c != null:
				_return_card_to_table(c)

func _update_title(data: Dictionary) -> void:
	title_label.text = data.get("title", "未知事件")

func _update_description(completed: bool) -> void:
	if completed:
		desc_label.text = current_event_data.get("description_result", "")
	else:
		desc_label.text = current_event_data.get("description_begain", "")

func _setup_slots(data: Dictionary) -> void:
	for i in range(slots.size()):
		var slot_node = slots[i]
		var key = "card_%d" % (i + 1)
		var card_type = data.get(key, "")
		if card_type != "" and i < required_slot_count:
			slot_node.required_card_type = card_type
			slot_node.visible = true
		else:
			slot_node.required_card_type = ""
			slot_node.visible = false
			if slot_node.is_occupied:
				var c = slot_node.remove_card()
				if c != null:
					_return_card_to_table(c)

func _count_required_slots(data: Dictionary) -> int:
	var count = 0
	for i in range(1, 7):
		var key = "card_%d" % i
		if data.get(key, "") != "":
			count = i
		else:
			break
	return max(count, 1)

func _set_all_slots_visible(v: bool) -> void:
	for s in slots:
		s.visible = v

func _set_confirm_enabled(enabled: bool) -> void:
	confirm_button.disabled = not enabled
	confirm_button.modulate = Color.WHITE if enabled else Color(0.5, 0.5, 0.5, 1.0)

# ── 条件卡槽回调 ──────────────────────────────────

func _on_condition_card_placed(_slot_index: int, _placed_card: card) -> void:
	if event_state == EventState.WAITING:
		_check_condition()

func _on_condition_card_removed(_slot_index: int) -> void:
	if event_state != EventState.IDLE:
		_check_condition()

func _check_condition() -> bool:
	if event_state == EventState.IDLE or required_slot_count == 0:
		_set_confirm_enabled(false)
		return false
	for i in range(required_slot_count):
		if i >= slots.size() or not slots[i].is_occupied:
			event_state = EventState.WAITING
			_set_confirm_enabled(false)
			return false
	event_state = EventState.CONDITION_MET
	_set_confirm_enabled(true)
	print("[EventPanel] 条件满足，确定按钮激活")
	return true

# ── 确定按钮 ──────────────────────────────────────

func _on_confirm_pressed() -> void:
	if event_state != EventState.CONDITION_MET:
		return
	print("[EventPanel] 执行 result")
	event_state = EventState.COMPLETED
	_update_description(true)
	_set_confirm_enabled(false)

	var result_str = current_event_data.get("result", "")
	if result_str != "":
		_execute_result(result_str)

	_consume_slot_cards()

	# 显示结果描述 0.8 秒后自动关闭
	await get_tree().create_timer(0.8).timeout
	close_panel()

## 右上角关闭按钮
func _on_close_pressed() -> void:
	close_panel()

# ── Result 执行器 ─────────────────────────────────

func _execute_result(result_string: String) -> void:
	print("[EventPanel] 执行 result: %s" % result_string)
	var parts = result_string.split("_")
	if parts.size() < 1:
		return
	var event_type = int(parts[0])
	match event_type:
		1:
			if parts.size() < 3:
				return
			_give_card_by_index(int(parts[1]), int(parts[2]))
		_:
			push_warning("[EventPanel] 未知 result 类型: %d" % event_type)

func _give_card_by_index(target_index: int, amount: int) -> void:
	var all_cards = CardInfo.get_all_cards()
	var target_card_id = ""
	for card_id in all_cards.keys():
		var c = all_cards[card_id]
		if int(c.get("index", -1)) == target_index:
			target_card_id = card_id
			break
	if target_card_id == "":
		push_warning("[EventPanel] 找不到 index=%d 的卡牌" % target_index)
		return
	print("[EventPanel] 给予卡牌: %s x%d" % [target_card_id, amount])
	var table = _find_card_table()
	if table != null and table.has_method("add_new_card_by_name"):
		for i in range(amount):
			table.add_new_card_by_name(target_card_id)
	else:
		push_warning("[EventPanel] 找不到牌桌")

func _find_card_table() -> Node:
	var tables = get_tree().get_nodes_in_group("cardTable")
	if tables.size() > 0:
		return tables[0]
	return _find_node_by_name(get_tree().get_root(), "card_table_main")

func _find_node_by_name(parent: Node, target_name: String) -> Node:
	for child in parent.get_children():
		if child.name == target_name:
			return child
		var found = _find_node_by_name(child, target_name)
		if found:
			return found
	return null

func _consume_slot_cards() -> void:
	# 消耗条件槽的卡
	for i in range(required_slot_count):
		if i < slots.size() and slots[i].is_occupied:
			var c = slots[i].remove_card()
			if c != null:
				c.queue_free()
	# 消耗触发槽的卡
	if trigger_slot and trigger_slot.is_occupied:
		var tc = trigger_slot.remove_card()
		if tc != null:
			tc.queue_free()

# ── 退回卡牌到牌桌 ────────────────────────────────

func _return_card_to_table(c: card) -> void:
	if not is_instance_valid(c):
		return
	var table = _find_card_table()
	if table != null and table.has_method("add_card"):
		table.add_card(c)
	else:
		c.cardCurrentState = card.cardState.following

# ── 关闭面板 ──────────────────────────────────────

func close_panel() -> void:
	if event_state != EventState.COMPLETED:
		# 退回条件槽内的卡
		for slot_node in slots:
			if slot_node.is_occupied:
				var c = slot_node.remove_card()
				if c != null:
					_return_card_to_table(c)
		# 退回触发槽内的卡
		if trigger_slot and trigger_slot.is_occupied:
			var tc = trigger_slot.remove_card()
			if tc != null:
				_return_card_to_table(tc)
	visible = false
	print("[EventPanel] 面板关闭")
