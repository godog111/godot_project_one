extends Control

@onready var nameBox =$LineEdit
# Called when the node enters the scene tree for the first time.

func _on_new_game_button_down()->void:
	var newPlayerInfo =player.new()
	playerInit(newPlayerInfo)
	
func playerInit(newPlayer:player):
	newPlayer.playerName=nameBox.text
	newPlayer.loacation="res://site/site1.tscn"
	newPlayer.money =100000
	newPlayer.handMax =100
	var folderPath = "user://save/"
	var savePath = folderPath+"autoSave.tres"
	create_folder(folderPath)
	newPlayer.folderPath=folderPath
	ResourceSaver.save(newPlayer,savePath)
	Infos.loadPlayerInfo()

func create_folder(folder_path:String):
	var dir =DirAccess.open(folder_path)
	if dir!=null:
		print("Directory already exists:"+folder_path)
	else:
		var result = DirAccess.make_dir_absolute(folder_path)
		if result ==OK:
			print("Directory created:"+folder_path)
		else:
			print("Failed to create directory:"+folder_path)
