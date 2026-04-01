extends card
class_name shopCard
var priceRatio
@export var items:PackedStringArray
var diaPath

func drawCard():
	pickButton =$Button
	$nameLabel.text = cardInfo["base_displayName"]
	$Button/Panel/Label.text =cardInfo["base_desc"]
	priceRatio = cardInfo["base_card"]
	items = cardInfo["base_desc"].split("!")

var deckP
func _on_butto_down() -> void:
	NpcManager.currentNpc =self
	$Button.visible=false
	cardCurrentState=cardState.hanging
	
	deckP = get_parent()
	var poi =global_position
	get_parent().remove_child(self)
	VfSlayer.add_child(self)
	global_position =poi
	
	follow_target.visible=false
	var tween1=create_tween()
	tween1.tween_property($TextureRect,"size",Vector2(1545,317),0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	
	$Button2.visible=true
	$nameLabel.visible=true
	var tween5=create_tween()
	tween5.tween_property($TextureRect/npcImg,"modulate",Color(1,1,1,1),0.5)
	var tween3 =create_tween()
	await tween3.tween_property(self,"global_position",Vector2(355,0),0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT).finished
	$shopCardDeck.visible=true
	var tween4 =create_tween()
	await tween4.tween_property($shopCardDeck,"size",Vector2(1565,360),0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	
	shop_add_card()

var dioScene:Node
func show_dia(diaName:String):
	if dioScene!=null:
		dioScene.queue_free()


func shop_add_card():
	for i in items:
		var cardToAdd =preload("res://cards/shopItemCard.tscn").instantiate()as shopItemCard
		cardToAdd.priceRatio = float(priceRatio)
		cardToAdd.connect("showDia",show_dia)
		cardToAdd.initCard(i)
		cardToAdd.global_position=$shopCardDeck.global_position+Vector2($shopCardDeck.size.x,0)
		
		#自定义牌桌添加部分
		var cardBackground = preload("res://cards/card_background.tscn").instantiate()
		$shopCardDeck.cardPoiDeck.add_child(cardBackground)
		var global_poi =cardToAdd.global_position #获取节点全局位置
		if cardToAdd.get_parent():
			cardToAdd.get_parent().remove_child(cardToAdd)
		$shopCardDeck.cardDeck.add_child(cardToAdd)
		cardToAdd.global_position = global_poi
		
		cardToAdd.follow_target=cardBackground
		cardToAdd.cardCurrentState=cardToAdd.cardState.following
		
		await  get_tree().create_timer(0.1).timeout
		
func leave():
	await get_tree().create_timer(0.5).timeout
	var t=create_tween()
	t.tween_property(self,"modulate",Color(1,1,1,0),0.3)
	visible = false
	follow_target.visible=false
	
	pass
