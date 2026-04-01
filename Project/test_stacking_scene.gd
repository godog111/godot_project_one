extends Control
class_name TestStackingScene

## 堆叠系统测试场景
## 测试内容：
## 1. 同名卡牌堆叠（完全重合 + 数量相加）
## 2. 不同名卡牌堆叠（1/4偏移）

@onready var deck: Panel = $TestDeck

# 测试用卡牌数据
var test_cards: Array[String] = [
	"ice", "ice", "ice",       # 3张同名，应完全重合
	"Stone", "Stone",          # 2张同名，应完全重合
	"Glod",                    # 1张单独
	"npc_1",                   # 1张NPC
	"site_1",                  # 1张地点
]

func _ready() -> void:
	print("=== 堆叠系统测试场景 ===")
	print("测试卡牌列表: ", test_cards)
	
	# 确保 Infos 和存档系统已初始化
	_ensure_save_system()
	
	# 等待一帧确保场景初始化完成
	await get_tree().process_frame
	
	# 生成测试卡牌
	_spawn_test_cards()
	
	print("\n操作说明：")
	print("- 拖动卡牌到同名卡牌上：应完全重合，数量相加")
	print("- 拖动卡牌到不同名卡牌附近：应1/4偏移排列")
	print("- F5: 重新生成测试卡牌")

func _ensure_save_system() -> void:
	# 确保 Infos.save 存在
	if Infos.save == null:
		print("初始化存档系统...")
		var player_script = load("res://data/playerinfo.gd")
		if player_script:
			Infos.save = player_script.new()
			Infos.save.decks = {}
			print("存档系统初始化完成")
		else:
			push_error("无法加载 playerinfo.gd")

func _spawn_test_cards() -> void:
	print("\n生成测试卡牌...")
	
	# 清除现有卡牌
	_clear_existing_cards()
	
	# 生成测试卡牌，按组排列
	var start_pos = Vector2(200, 200)
	var group_spacing = Vector2(150, 0)
	
	var current_group = 0
	var last_name = ""
	
	for i in range(test_cards.size()):
		var card_name = test_cards[i]
		
		# 如果是新组，增加间距
		if card_name != last_name:
			current_group += 1
			last_name = card_name
		
		var spawn_pos = start_pos + Vector2(current_group * 180, 100 + (i % 3) * 50)
		
		# 创建卡牌
		var card = Infos.add_new_card(card_name, deck)
		if card:
			card.global_position = spawn_pos
			print("  生成: %s 位置: %s" % [card_name, spawn_pos])
	
	print("测试卡牌生成完成！")

func _clear_existing_cards() -> void:
	var card_deck = deck.get_node("cardDeck")
	for child in card_deck.get_children():
		child.queue_free()
	
	var poi_deck = deck.get_node("ScrollContainer/cardPoiDeck")
	for child in poi_deck.get_children():
		child.queue_free()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F5:
				print("\n重新生成测试卡牌...")
				_spawn_test_cards()
			KEY_ESCAPE:
				get_tree().quit()
