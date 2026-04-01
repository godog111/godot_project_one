extends "res://cards/card.gd"
class_name siteCard



func drawCard():
	#设置另外可拾取的按钮
	pickButton=$getInButton
	
	$getInButton/Panel/Label.text = cardInfo["base_desc"]
	$TextureRect/VBoxContainer/Label.text = cardInfo["base_displayName"]
	$getInButton.visible=true

func _on_get_in_button_button_down() -> void:
	var path="res://site/"+cardName+".tscn"
	#path="res://site/site2.tscn"
	for d in get_tree().get_nodes_in_group("saveableDecks"):
		d.storCard()
	print("跳转场景"+path)
	if ResourceLoader.exists(path):
			get_tree().change_scene_to_file(path)
	else:	print("场景文件不存在：", path)
	pass # Replace with function body.
