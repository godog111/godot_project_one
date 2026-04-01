extends Control
class_name CardSlot

## 事件面板卡槽
## 通过加入 cardDropable 组，与 card.gd 的拖放系统对接
## 释放鼠标时 card.gd 会调用 add_card(self)

signal card_placed(slot_index: int, placed_card: card)
signal card_removed(slot_index: int)

@export var slot_index: int = 0
## 允许放入的卡牌类型，格式 "item_2"（与 eventInfo.card_x 一致），空表示接受任意
@export var required_card_type: String = ""

var current_card: card = null
var is_occupied: bool = false

## 高亮颜色（悬停时提示可放入）
const COLOR_NORMAL   = Color(0.2, 0.2, 0.2, 0.8)
const COLOR_HOVER    = Color(0.4, 0.8, 0.4, 0.9)
const COLOR_OCCUPIED = Color(0.15, 0.15, 0.15, 0.95)
const COLOR_WRONG    = Color(0.8, 0.2, 0.2, 0.8)

@onready var bg_rect: ColorRect = $BgRect

func _ready() -> void:
	add_to_group("cardDropable")
	_update_visual()

## card.gd 松手时调用此方法
func add_card(new_card: card) -> void:
	print("[CardSlot %d] add_card | is_occupied=%s | required='%s' | card=%s" % [
		slot_index, is_occupied, required_card_type, new_card.cardName])

	if is_occupied:
		print("[CardSlot %d] → 拒绝：已占用，退回" % slot_index)
		if new_card.preDeck != null and new_card.preDeck != self and new_card.preDeck.has_method("add_card"):
			new_card.preDeck.add_card(new_card)
		else:
			new_card.cardCurrentState = card.cardState.following
		return

	if required_card_type != "" and not _is_card_match(new_card):
		print("[CardSlot %d] → 拒绝：类型不匹配 class=%s index=%s 需要=%s" % [
			slot_index,
			new_card.cardInfo.get("cardClass","?"),
			new_card.cardInfo.get("index","?"),
			required_card_type])
		_flash_wrong()
		if new_card.preDeck != null and new_card.preDeck != self and new_card.preDeck.has_method("add_card"):
			new_card.preDeck.add_card(new_card)
		else:
			new_card.cardCurrentState = card.cardState.following
		return

	print("[CardSlot %d] → 通过，开始放入" % slot_index)
	_place_card(new_card)

## 检查卡牌是否符合槽位要求
func _is_card_match(c: card) -> bool:
	if required_card_type == "":
		return true
	var parts = required_card_type.split("_")
	if parts.size() < 2:
		return true
	var required_class = parts[0]
	var required_index = int(parts[1])
	var c_class = c.cardInfo.get("cardClass", "")
	var c_index = int(c.cardInfo.get("index", -1))
	return c_class == required_class and c_index == required_index

## 放入卡牌
func _place_card(new_card: card) -> void:
	is_occupied = true
	current_card = new_card
	new_card.follow_target = null
	new_card.preDeck = self
	# 立即设 hanging，阻止 card.gd _on_button_button_up 末尾的 following 覆盖
	new_card.cardCurrentState = card.cardState.hanging

	# reparent 推迟到下一帧，避免在 _on_button_button_up 调用栈内修改场景树
	call_deferred("_do_reparent_card", new_card)

	_update_visual()
	card_placed.emit(slot_index, new_card)
	print("[CardSlot %d] ✓ _place_card 完成：%s  is_occupied=%s  state=%s" % [
		slot_index, new_card.cardName, is_occupied, new_card.cardCurrentState])

## 下一帧执行 reparent + 锚点填满
func _do_reparent_card(new_card: card) -> void:
	if not is_instance_valid(new_card):
		print("[CardSlot %d] _do_reparent_card：卡牌已无效，跳过" % slot_index)
		return

	# 如果卡牌已经被拖走（preDeck 不再指向自己，或状态是 dragging），跳过
	if new_card.preDeck != self or new_card.cardCurrentState == card.cardState.dragging:
		print("[CardSlot %d] _do_reparent_card：卡牌已离开（preDeck=%s state=%s），跳过" % [
			slot_index,
			new_card.preDeck.name if new_card.preDeck != null else "null",
			new_card.cardCurrentState])
		return

	print("[CardSlot %d] _do_reparent_card 执行，当前 state=%s  parent=%s" % [
		slot_index, new_card.cardCurrentState,
		new_card.get_parent().name if new_card.get_parent() else "null"])

	var old_parent = new_card.get_parent()
	if old_parent != null and old_parent != self:
		old_parent.remove_child(new_card)
	if new_card.get_parent() != self:
		add_child(new_card)

	# 全屏锚点填满卡槽
	new_card.layout_mode = 1
	new_card.anchor_left   = 0.0
	new_card.anchor_top    = 0.0
	new_card.anchor_right  = 1.0
	new_card.anchor_bottom = 1.0
	new_card.offset_left   = 0.0
	new_card.offset_top    = 0.0
	new_card.offset_right  = 0.0
	new_card.offset_bottom = 0.0
	new_card.follow_target = null
	# 再次确保 hanging（防止中间某处被改回 following）
	new_card.cardCurrentState = card.cardState.hanging

	print("[CardSlot %d] ✓ reparent 完成：%s  parent=%s  state=%s" % [
		slot_index, new_card.cardName,
		new_card.get_parent().name if new_card.get_parent() else "null",
		new_card.cardCurrentState])

## 移除卡牌（由 event.gd 或 card.gd 拖出时调用）
## silent=true 时不发 card_removed 信号（玩家主动拖出时使用，避免触发 reset）
func remove_card(silent: bool = false) -> card:
	print("[CardSlot %d] remove_card 调用 | is_occupied=%s | current_card=%s | silent=%s" % [
		slot_index, is_occupied, current_card.cardName if is_instance_valid(current_card) else "null", silent])
	if not is_occupied:
		print("[CardSlot %d] remove_card → 已为空，直接返回 null" % slot_index)
		return null
	var removed = current_card
	current_card = null
	is_occupied = false

	if is_instance_valid(removed):
		var p = removed.get_parent()
		print("[CardSlot %d] remove_card → removed.parent=%s | self=%s" % [
			slot_index, p.name if p else "null", name])
		if p != null:
			p.remove_child(removed)
			print("[CardSlot %d] remove_card → remove_child 完成，现在 parent=%s" % [
				slot_index, removed.get_parent().name if removed.get_parent() else "null"])
		removed.layout_mode = 0
		removed.anchor_left   = 0.0
		removed.anchor_top    = 0.0
		removed.anchor_right  = 0.0
		removed.anchor_bottom = 0.0
		removed.size = Vector2(136, 191)
		removed.preDeck = null
		removed.follow_target = null
	else:
		print("[CardSlot %d] remove_card → current_card 已无效" % slot_index)

	_update_visual()
	if not silent:
		card_removed.emit(slot_index)
	print("[CardSlot %d] remove_card → 完成，返回 %s" % [slot_index, removed.cardName if is_instance_valid(removed) else "null"])
	return removed

## 刷新槽位外观
func _update_visual() -> void:
	if bg_rect == null:
		return
	if is_occupied:
		bg_rect.color = COLOR_OCCUPIED
	else:
		bg_rect.color = COLOR_NORMAL

func _on_mouse_entered() -> void:
	if not is_occupied and bg_rect:
		bg_rect.color = COLOR_HOVER

func _on_mouse_exited() -> void:
	_update_visual()

## 放入失败时闪红
func _flash_wrong() -> void:
	if bg_rect == null:
		return
	bg_rect.color = COLOR_WRONG
	var tween = create_tween()
	tween.tween_interval(0.3)
	tween.tween_callback(_update_visual)
