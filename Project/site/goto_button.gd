extends Button

@export var site:String

func _on_button_down() ->void:
	var all_decks = get_tree().get_nodes_in_group("saveableDecks")
	for i in range(all_decks.size()):
		print("索引 ", i, ": ", all_decks[i], " 路径: ", all_decks[i].get_path())
	
	for d in get_tree().get_nodes_in_group("saveableDecks"):
		d.storCard()
	get_tree().change_scene_to_file(site)
	pass
