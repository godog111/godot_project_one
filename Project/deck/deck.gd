extends Panel

@onready var cardDeck:Control = $cardDeck
@onready var cardPoiDeck:HBoxContainer =$ScrollContainer/cardPoiDeck

var currentWeight =0
@export var maxWeight=180


func _ready() ->void:
	if is_in_group("saveableDecks"):
		loadCards()
	else:
		for i in defultCards:
			Infos.nowScene.add_new_card(i,self) 
	$ProgressBar.max_value = maxWeight

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if cardDeck.get_child_count()!=0:
		var children = cardDeck.get_children()
		sort_nodes_by_position(children)

func sort_nodes_by_position(children):
	children.sort_custom(sort_by_position)
	for i in range(children.size()):
		if children[i].cardCurrentState!=children[i].cardState.hanging:
			children[i].z_index =i
			cardDeck.move_child(children[i],i)

func sort_by_position(a,b):
	return a.position.x<b.position.x

func add_card(cardToAdd)->void:
	print("add_card 被调用")
	
	# 1. 先检查是否可以与同名卡牌堆叠（完全重合）
	if currentWeight + cardToAdd.cardWeight <= maxWeight:
		if _try_stack_same_name(cardToAdd):
			return
	
	# 2. 检查是否与不同名卡牌形成堆叠组（1/4偏移）
	var nearbyCards = _get_nearby_cards(cardToAdd.global_position, 100.0)
	var differentNameCard = null
	for other in nearbyCards:
		if other != cardToAdd and other.cardName != cardToAdd.cardName:
			differentNameCard = other
			break
	
	# 3. 创建背景项
	var index = cardToAdd.z_index
	var cardBackground = preload("res://cards/card_background.tscn").instantiate()
	cardPoiDeck.add_child(cardBackground)
	
	if index <= cardPoiDeck.get_child_count():
		cardPoiDeck.move_child(cardBackground, index)
	else:
		cardPoiDeck.move_child(cardBackground, -1)
	
	var global_poi = cardToAdd.global_position
	
	if cardToAdd.get_parent():
		cardToAdd.get_parent().remove_child(cardToAdd)
	cardDeck.add_child(cardToAdd)
	
	# 4. 如果有不同名卡牌在附近，1/4偏移放置
	if differentNameCard != null:
		var offset = _calculate_stack_offset(differentNameCard, cardToAdd)
		cardToAdd.global_position = differentNameCard.global_position + offset
		cardToAdd.z_index = differentNameCard.z_index + 1
	else:
		cardToAdd.global_position = global_poi
	
	cardToAdd.follow_target = cardBackground
	cardToAdd.preDeck = self
	cardToAdd.cardCurrentState = cardToAdd.cardState.following
	
	update_weight()

func update_weight()->void:
	var nowWeight=0
	for i in cardDeck.get_children():
		if i.cardCurrentState == i.cardState.following:
			nowWeight+=i.cardWeight*i.num
	currentWeight = nowWeight
	var weightText = str(currentWeight)+"/"+str(maxWeight)
	$weight.text = weightText
	$ProgressBar.value=currentWeight
	print(str(self.name)+"现在重量为"+weightText)

# ========== 堆叠系统 ==========

## 尝试与同名卡牌堆叠（完全重合）
func _try_stack_same_name(cardToStack: card) -> bool:
	for existing in cardDeck.get_children():
		if existing.cardName == cardToStack.cardName \
		   and existing.cardCurrentState == card.cardState.following:
			if existing.doStack(cardToStack):
				_play_stack_animation(existing, cardToStack)
				cardToStack.queue_free()
				update_weight()
				return true
	return false

## 获取指定位置附近的卡牌
func _get_nearby_cards(pos: Vector2, radius: float) -> Array[card]:
	var result: Array[card] = []
	for c in cardDeck.get_children():
		if c is card and c.cardCurrentState == card.cardState.following:
			if c.global_position.distance_to(pos) < radius:
				result.append(c)
	return result

## 计算堆叠偏移（1/4遮挡效果）
func _calculate_stack_offset(baseCard: card, newCard: card) -> Vector2:
	# 基于卡牌名称的哈希值确定偏移方向，确保同一组卡牌有稳定的排列
	var nameHash = newCard.cardName.hash()
	var directions = [
		Vector2(0, -30),    # 向上
		Vector2(30, 0),     # 向右
		Vector2(0, 30),     # 向下
		Vector2(-30, 0),    # 向左
	]
	var dirIndex = abs(nameHash) % directions.size()
	return directions[dirIndex]

## 播放堆叠动画
func _play_stack_animation(targetCard: card, sourceCard: card) -> void:
	var fakeCard = sourceCard.duplicate()
	fakeCard.z_index = 1000
	fakeCard.cardCurrentState = card.cardState.fake
	VfSlayer.add_child(fakeCard)
	fakeCard.global_position = get_global_mouse_position() - Vector2(125, 100)
	
	var tween = create_tween()
	tween.tween_property(fakeCard, "global_position", targetCard.global_position, 0.2) \
		.set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)
	
	await tween.finished
	fakeCard.queue_free()

## 旧的堆叠检测（保留兼容）
func card_is_stacked(cardToStack)->bool:
	return _try_stack_same_name(cardToStack)

func fake_card_move(cardTofake):
	var fakeCard = cardTofake.duplicate()
	#fakeCard.initCard(cardTofake.cardName)
	fakeCard.z_index=1000
	fakeCard.cardCurrentState = fakeCard.cardState.fake
	VfSlayer.add_child(fakeCard)
	fakeCard.global_position =get_global_mouse_position()-Vector2(125,100)
	var tween = create_tween()
	await tween.tween_property(fakeCard,"global_position",cardTofake.global_position,0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).finished
	fakeCard.queue_free()

@export var cardsSaved:Array[PackedScene]
@export var defultCards:Array[String]
func storCard():
	# 检查存档系统是否初始化
	if Infos.save == null:
		print("警告: 存档系统未初始化，无法保存")
		return
	
	if Infos.save.decks == null:
		Infos.save.decks = {}
	
	cardsSaved = []
	if cardDeck.get_children().size() > 0:
		for c in cardDeck.get_children():
			var p = PackedScene.new()
			var r = p.pack(c)
			print("保存了名为" + c.cardName + "卡片", "保存结果为", r)
			cardsSaved.append(p)
	var saver = deckSavedCards.new()
	saver.cards = cardsSaved
	var path = str(get_path())
	var savePath = path
	Infos.save.decks[savePath] = saver
			
func loadCards():
	clear_children($ScrollContainer/cardPoiDeck)
	clear_children($cardDeck)
	
	# 检查存档系统是否初始化
	if Infos.save == null or Infos.save.decks == null:
		print("存档系统未初始化，生成默认卡牌")
		for i in defultCards:
			Infos.nowScene.add_new_card(i, self)
		return
	
	var path = str(get_path())
	var savePath = path
	if Infos.save.decks.has(savePath):
		var save = Infos.save.decks[savePath]
		if save.cards.size() > 0:
			for c in save.cards:
				var p = c.instantiate()
				add_card(p)
	else:
		for i in defultCards:
			Infos.nowScene.add_new_card(i, self)
				



func clear_children(node:Node):
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
