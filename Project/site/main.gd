extends Node2D

@export var scene_1:Node
@export var scene_2:Node
@export var scene_3:Node

@export var maxRandomItemNum:int
@export var minRandomItemNum:int
@export var siteItems:Dictionary


	
	
	
func get_some_card():
	print("点击抽卡")
	var num_cards = randi()%(maxRandomItemNum - minRandomItemNum +1)+minRandomItemNum
	print(num_cards)
	var total_weight = get_total_weight(siteItems)
	print(total_weight)
	var selected_cards =[]
	
	for i in range(num_cards):
		print("抽卡随机")
		var random_num = randi()%total_weight
		var cumulative_weight =0
		for c in siteItems.keys():
			cumulative_weight+= siteItems[c]
			if random_num<cumulative_weight:
				selected_cards.append(c)
				break
	for c in selected_cards:
		print("开始分牌")
		var randomDeck = get_tree().get_nodes_in_group("cardDeck")[randi_range(0,2)]
		var all_decks = get_tree().get_nodes_in_group("cardDeck")
		for i in range(all_decks.size()):
			print("索引 ", i, ": ", all_decks[i], " 路径: ", all_decks[i].get_path())
		print("现在的牌桌号是："+str(randomDeck))
		await get_tree().create_timer(0.1).timeout
		Infos.add_new_card(c,randomDeck,$Button)
func get_total_weight(card_dict):
	var total_weight =0
	for weight in card_dict.values():
		total_weight+=weight
	return total_weight
