extends Control
class_name card

var velocity = Vector2.ZERO
var damping = 0.35
var stiffness = 500

var preDeck

@export var cardClass: String
@export var cardName: String
@export var maxStackNum: int
@export var cardWeight: float
@export var cardInfo: Dictionary

var pickButton: Node
var dup
var num = 1

enum cardState { following, dragging, vfs, fake, hanging }
@export var cardCurrentState = cardState.following

@export var follow_target: Node
var whichDeckMouseIn

func _process(delta: float) -> void:
	match cardCurrentState:
		cardState.dragging:
			follow(get_global_mouse_position() - size / 2, delta)
			var mouse_position = get_global_mouse_position()
			var nodes = get_tree().get_nodes_in_group("cardDropable")
			
			# 每帧重置，避免鼠标离开后仍残留上一帧的目标
			whichDeckMouseIn = null
			for node in nodes:
				if not node.visible:
					continue
				var rect = node.get_global_rect()
				if rect.has_point(mouse_position):
					whichDeckMouseIn = node
					break
			
		cardState.following:
			if follow_target != null:
				follow(follow_target.global_position, delta)
		cardState.vfs:
			follow(get_global_mouse_position() - size / 2, delta)

## reparent 后 Button.button_up 信号会丢失，用 _input 补刀
## 只在 dragging 状态下监听鼠标左键释放
## 用静态变量确保同一帧只有一张卡处理松手（防止多张 dragging 卡重复响应）
static var _current_dragger: card = null  # 当前正在被拖动的卡（全局唯一）

func _input(event: InputEvent) -> void:
	if cardCurrentState != cardState.dragging:
		return
	if event is InputEventMouseButton \
	   and event.button_index == MOUSE_BUTTON_LEFT \
	   and not event.pressed:
		# 只有"当前拖动者"才处理松手；若无人注册则抢占
		if _current_dragger != null and _current_dragger != self:
			return
		print("[card _input] dragging 松手 | card=%s | parent=%s" % [
			cardName, get_parent().name if get_parent() else "null"])
		_do_release()

func follow(target_position: Vector2, delta: float):
	var displacement = target_position - global_position
	var force = displacement * stiffness
	velocity += force * delta
	velocity *= (1.0 - damping)
	global_position += velocity * delta

func cardStack(cardToStack) -> bool:
	var stackNum = cardToStack.num
	if num + stackNum > maxStackNum:
		return false
	else:
		num = num + stackNum
		print(stackNum, ",", num)
		drawCard()
		print("卡牌被堆叠")
		return true

func _on_button_button_down() -> void:
	# ── vfs 幽灵副本：不处理任何点击，直接忽略 ──
	if cardCurrentState == cardState.vfs:
		return
	print("[card button_down] card=%s | state=%s | parent=%s" % [
		cardName, cardCurrentState, get_parent().name if get_parent() else "null"])
	# ── hanging 状态：从卡槽拖出 ──
	if cardCurrentState == cardState.hanging:
		print("[card drag-from-slot] 开始 | card=%s | parent=%s | global_pos=%s | preDeck=%s" % [
			cardName,
			get_parent().name if get_parent() else "null",
			global_position,
			preDeck.name if preDeck != null else "null"
		])
		var slot = preDeck
		var cur_global = global_position
		# 先让卡槽负责把自己从场景树摘出来，重置锚点
		# silent=true：不触发 card_removed 信号，避免事件面板误 reset
		if slot != null and slot.has_method("remove_card"):
			print("[card drag-from-slot] 调用 slot.remove_card(silent=true)，slot=%s" % slot.name)
			slot.remove_card(true)
			print("[card drag-from-slot] remove_card 完成 | parent 现在=%s" % (get_parent().name if get_parent() else "null"))
		else:
			print("[card drag-from-slot] 警告：preDeck=%s，无 remove_card 方法，直接强制摘出" % (slot.name if slot else "null"))
			var p = get_parent()
			if p != null:
				p.remove_child(self)
			layout_mode = 0
			anchor_left = 0.0; anchor_top = 0.0; anchor_right = 0.0; anchor_bottom = 0.0
		# 此时 self 已经不在任何父节点下，挂到 VfSlayer
		print("[card drag-from-slot] add_child to VfSlayer | parent before=%s" % (get_parent().name if get_parent() else "null"))
		VfSlayer.add_child(self)
		global_position = cur_global
		print("[card drag-from-slot] VfSlayer 挂载完成 | parent=%s | global_pos=%s" % [
			get_parent().name if get_parent() else "null", global_position])
		# 生成幽灵副本（拖动期间显示占位）
		dup = self.duplicate()
		if dup != null:
			dup.follow_target = null
		VfSlayer.add_child(dup)
		dup.global_position = global_position
		dup.cardCurrentState = cardState.vfs
		preDeck = null
		cardCurrentState = cardState.dragging
		_current_dragger = self  # 注册为当前拖动者，防止其他 dragging 卡响应松手
		print("[card drag-from-slot] 完成 | state=dragging | dup=%s" % (dup.name if dup else "null"))
		return

	if cardCurrentState == cardState.following:
		# ── GridSnapTable 模式：不拆分堆叠，整体拖动 ──
		if preDeck != null and preDeck.has_method("release_card"):
			# 通知牌桌释放锚点
			preDeck.release_card(self)
			# 整体拖动，不修改 num
			dup = self.duplicate()
			if dup != null:
				dup.follow_target = null
			VfSlayer.add_child(dup)
			dup.global_position = global_position
			dup.cardCurrentState = cardState.vfs
			cardCurrentState = cardState.dragging
			_current_dragger = self  # 注册为当前拖动者
			if follow_target != null:
				follow_target.queue_free()
				follow_target = null
			return
		
		# ── 旧 deck 模式：拆分堆叠 ──
		var numc = num
		num = 1
		drawCard()
		dup = self.duplicate()
		# ==== 关键修复：在添加到场景前，清理副本中的无效引用 ====
		if dup != null:
			# 重置可能指向已释放对象的引用
			dup.follow_target = null
		VfSlayer.add_child(dup)
		dup.global_position = global_position
		dup.cardCurrentState = cardState.vfs
		cardCurrentState = cardState.dragging
		_current_dragger = self  # 注册为当前拖动者
		
		var _deck_parent = get_parent().get_parent() if get_parent() and get_parent().get_parent() else null
		if _deck_parent and _deck_parent.has_method("update_weight"):
			_deck_parent.update_weight() # 检查牌桌是否满了
		if numc != 1 and numc != null:
			var c = Infos.add_new_card(cardName, get_parent().get_parent() if get_parent() else null, self) as Control
			# 在修改c的follow_target之前，先检查当前的follow_target是否有效
			if follow_target != null and is_instance_valid(follow_target):
				# c.follow_target.queue_free()
				c.follow_target = follow_target
			else:
				c.follow_target = null
			c.global_position = global_position
			c.num = numc - 1
			if c.has_method("drawCard"):
				c.drawCard()
		
		if follow_target != null:
			follow_target.queue_free()
			follow_target = null # 清理自身的引用
		get_parent().get_parent().update_weight()

var del
func _on_button_button_up() -> void:
	# ── vfs 幽灵副本：不处理松手，直接忽略 ──
	if cardCurrentState == cardState.vfs:
		return
	# hanging 状态下 button_up 无意义（卡牌已放入槽中）
	if cardCurrentState == cardState.hanging:
		return
	# _input 已经处理过了（dragging 状态下 _current_dragger 会被清空）
	# 若此时 _current_dragger 不是 self 且不为 null，说明另一张卡在拖，忽略
	if _current_dragger != null and _current_dragger != self:
		return
	print("[card button_up signal] card=%s | state=%s" % [cardName, cardCurrentState])
	_do_release()

## 松手时的实际处理逻辑（_input 和 button_up 信号共用）
func _do_release() -> void:
	# 防止同一帧多次触发
	if _current_dragger == self:
		_current_dragger = null  # 占位已清，后续重入直接忽略
	elif _current_dragger != null:
		return  # 另一张卡正在处理，不抢
	
	if dup != null:
		dup.queue_free()
		dup = null
	if del:
		self.queue_free()
		print("deleted")
		return
	# 优先使用 whichDeckMouseIn，但需检查是否有 add_card 方法
	var handled = false
	if whichDeckMouseIn != null and whichDeckMouseIn.has_method("add_card"):
		# 如果目标是 GridSnapTable 类型的牌桌，先把位置移到其可见范围中心
		# 避免卡牌在事件面板上方时 place_card 找不到合法锚点
		if whichDeckMouseIn is GridSnapTable and whichDeckMouseIn is Control:
			var deck_rect = (whichDeckMouseIn as Control).get_global_rect()
			if not deck_rect.has_point(get_global_rect().get_center()):
				global_position = deck_rect.get_center()
		whichDeckMouseIn.add_card(self)
		handled = true
	elif preDeck != null and preDeck.has_method("add_card"):
		# 恢复到拖起时记录的位置，确保 place_card 能找到原来那个锚点格子
		if has_meta("_last_valid_position"):
			global_position = get_meta("_last_valid_position")
		elif preDeck is Control:
			global_position = (preDeck as Control).get_global_rect().get_center()
		preDeck.add_card(self)
		handled = true
	else:
		print("有一张卡牌没有preDeck,也没有whichDeckMouseIn,一般由于点击太快导致")
	
	# CardSlot 的 _place_card 会立即把状态改为 hanging
	if cardCurrentState != cardState.hanging:
		# 如果 preDeck 为空（从卡槽拖出后），找牌桌兜底
		if not handled:
			# 从 cardDropable 组里找 GridSnapTable 类型的牌桌
			var fallback_table: GridSnapTable = null
			for node in get_tree().get_nodes_in_group("cardDropable"):
				if node is GridSnapTable:
					fallback_table = node as GridSnapTable
					break
			if fallback_table != null:
				var fb_rect = fallback_table.get_global_rect()
				print("[card _do_release] 兜底放回牌桌: %s | rect=%s | 卡当前pos=%s" % [
					fallback_table.name, fb_rect, global_position])
				global_position = fb_rect.get_center()
				print("[card _do_release] 修正后pos=%s，调 add_card" % global_position)
				fallback_table.add_card(self)
				print("[card _do_release] add_card 完成 | parent=%s | state=%s" % [
					get_parent().name if get_parent() else "null", cardCurrentState])
				handled = true
			else:
				print("[card _do_release] 兜底失败：cardDropable 组里找不到 GridSnapTable！")
		if not handled:
			print("[card _do_release] handled=false，state→following | state=%s" % cardCurrentState)
			cardCurrentState = cardState.following
	# 用完立即清空，避免下次拖拽残留
	whichDeckMouseIn = null

func initCard(Nm: String) -> void:
	print("[initCard] 正在初始化卡牌: " + Nm)
	
	# 使用新的 CardInfo JSON 加载器
	if CardInfo:
		print("[initCard] CardInfo 卡牌数量: " + str(CardInfo.get_card_count()))
		cardInfo = CardInfo.get_item(Nm)
	else:
		push_error("CardInfo 全局类未找到")
		cardInfo = {}
	
	print("[initCard] 获取的cardInfo: " + str(cardInfo))
	
	if cardInfo.is_empty():
		push_error("无法找到卡牌数据: " + Nm)
		return
	
	cardClass = cardInfo.get("cardClass", "")
	cardName = cardInfo.get("id", Nm)
	maxStackNum = int(cardInfo.get("max", 1))
	cardCurrentState = cardState.following
	
	print("[initCard] 卡牌信息:")
	print("  - cardName: " + cardName)
	print("  - cardClass: " + cardClass)
	print("  - maxStackNum: " + str(maxStackNum))
	
	drawCard()

func drawCard():
	print("[drawCard] 开始绘制卡牌...")
	print("[drawCard] cardName: " + str(cardName))
	print("[drawCard] cardInfo: " + str(cardInfo))
	
	pickButton = $Button
	
	# 检查卡牌名称
	if cardName == "":
		push_warning("[drawCard] 警告: cardName为空!")
		cardName = "unknown"
	
	# 获取图片节点（兼容不同场景结构）
	var itemImgNode = _get_item_image_node()
	
	# 尝试加载图片（支持 .png 和 .svg）
	var texture = null
	var extensions = [".png", ".svg"]
	for ext in extensions:
		var imgPath = "res://cardImg/" + str(cardName) + ext
		if ResourceLoader.exists(imgPath):
			texture = load(imgPath)
			if texture:
				print("[drawCard] 图片加载成功: " + imgPath)
				break
	
	# 如果找不到图片，使用默认icon
	if texture == null:
		push_warning("[drawCard] 找不到卡牌图片: " + str(cardName) + "（尝试 .png 和 .svg）")
		if ResourceLoader.exists("res://icon.svg"):
			texture = load("res://icon.svg")
			print("[drawCard] 使用默认icon.svg")
	
	# 设置纹理
	if itemImgNode != null:
		itemImgNode.texture = texture
	else:
		push_warning("[drawCard] 警告: 找不到图片显示节点")
	
	# 设置显示名称
	var display_name = cardInfo.get("displayName", "未知卡牌")
	print("[drawCard] display_name: " + display_name)
	
	var nameNode = _get_name_label_node()
	if nameNode != null:
		nameNode.text = display_name
	
	# 设置堆叠数量
	var allButtonNode = _get_all_button_node()
	if allButtonNode != null:
		allButtonNode.text = "X" + str(num)
	
	print("[drawCard] 绘制完成")

# 兼容不同场景结构，获取图片节点
func _get_item_image_node():
	# 尝试原始路径
	if has_node("Control/ColorRect/itemImg"):
		return $Control/ColorRect/itemImg
	# 尝试新场景路径
	if has_node("CardPanel/CardBackground/ItemImage"):
		return $CardPanel/CardBackground/ItemImage
	# 尝试直接子节点
	if has_node("ItemImage"):
		return $ItemImage
	if has_node("itemImg"):
		return $itemImg
	return null

# 兼容不同场景结构，获取名称标签节点
func _get_name_label_node():
	# 尝试原始路径
	if has_node("Control/ColorRect/name"):
		return $Control/ColorRect/name
	# 尝试新场景路径
	if has_node("CardPanel/CardBackground/NameLabel"):
		return $CardPanel/CardBackground/NameLabel
	# 尝试直接子节点
	if has_node("NameLabel"):
		return $NameLabel
	if has_node("name"):
		return $name
	return null

# 兼容不同场景结构，获取堆叠按钮节点
func _get_all_button_node():
	# 尝试原始路径
	if has_node("AllButton"):
		return $AllButton
	# 尝试其他可能名称
	if has_node("StackLabel"):
		return $StackLabel
	return null

func _on_all_button_button_down() -> void:
	# ── GridSnapTable 模式：禁用数字标签的拆分功能 ──
	if preDeck != null and preDeck.has_method("release_card"):
		return
	
	# ── 旧 deck 模式：点击数字拆分堆叠 ──
	dup = self.duplicate()
	VfSlayer.add_child(dup)
	dup.global_position = global_position
	dup.cardCurrentState = cardState.vfs
	cardCurrentState = cardState.dragging
	if follow_target != null:
		follow_target.queue_free()

# ========== 堆叠系统相关 ==========

## 判断能否与另一张卡牌堆叠（同名）
func canStackWith(other: card) -> bool:
	if other == self:
		return false
	if other.cardName != cardName:
		return false
	if num + other.num > maxStackNum:
		return false
	return true

## 执行堆叠（将另一张卡牌合并到当前卡牌）
func doStack(other: card) -> bool:
	if not canStackWith(other):
		return false
	
	num += other.num
	drawCard()
	return true

## 拆分堆叠（返回拆分出的数量，剩余留在原卡）
func splitStack(splitNum: int) -> card:
	if splitNum >= num or splitNum <= 0:
		return null
	
	num -= splitNum
	drawCard()
	
	# 创建新卡牌
	var newCard = duplicate()
	newCard.num = splitNum
	newCard.drawCard()
	return newCard

## 获取卡牌显示名称
func getDisplayName() -> String:
	return cardInfo.get("displayName", cardName)

## 移动到指定位置（带动画）
func moveToPosition(targetPos: Vector2, duration: float = 0.2) -> void:
	var tween = create_tween()
	tween.tween_property(self, "global_position", targetPos, duration) \
		.set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_OUT)
