extends CanvasLayer

var saves:Dictionary
var save:player
var playerInfoPath:String

@onready var hand_deck:Control =$handDeck

func add_new_card(cardName,cardDeck,caller=get_tree().get_first_node_in_group("cardDeck"))->Node:
		
	print("开始创建卡牌"+str(cardName))
	var card_data = CardInfo.get_item(cardName)
	if card_data.is_empty():
		push_error("无法找到卡牌数据: " + cardName)
		return null
	var cardClass = card_data.get("cardClass", "")
	print("添加卡牌的类型为%s"%cardClass)
	var cardToAdd
	if cardClass =="site":
		cardToAdd =preload("res://cards/siteCard.tscn").instantiate()as card
	elif cardClass =="shop":
		cardToAdd =preload("res://cards/shop_card.tscn").instantiate()as card
	elif cardClass =="npc":
		cardToAdd =preload("res://cards/npc_card.tscn").instantiate()as card
	else:
		cardToAdd =preload("res://cards/card.tscn").instantiate()as card
	cardToAdd.initCard(cardName)
	cardToAdd.global_position=caller.global_position
	
	cardToAdd.z_index =100
	cardDeck.add_card(cardToAdd)
	return cardToAdd

func loadPlayerInfo(savePath:String="autoSave"):
	var path ="user://save/"+savePath+".tres"
	playerInfoPath=path
	save = load(playerInfoPath)as player
	
	hand_deck.maxWeight=save.handMax
	
	get_tree().change_scene_to_file(save.loacation)
	hand_deck.loadCards()
	visible =true
	playerUpdate()

func playerUpdate():
	$moneyLabel.text ="$"+str(save.money)


func savePlayerInfo(newSavePath:String):
	for d in get_tree().get_nodes_in_group("saveableDecks"):
		d.storCard()
	var path = save.folderPath+newSavePath+".tres"
	ResourceSaver.save(save,path)
	print("存档保存至"+path)

	
#func savePlayerInfo(newSavePath:String):
	#for d in get_tree().get_nodes_in_group("saveableDecks"):
		#d.storCard()
	#var path =save.folderPath*newSavePath+".tres"
	#ResourceSaver.save(save,path)
	#print("存档保存至"+path)
