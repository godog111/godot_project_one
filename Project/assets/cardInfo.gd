extends Node
class_name cardInfo

## 卡牌数据加载器 - JSON 版本
## 数据来源: assets/cardData.json
## 使用方式:
##   var data = cardInfo.get_item("ice")
##   print(data.displayName)  # 自动类型转换

const JSON_FILE_PATH = "res://assets/cardData.json"

# 数据存储
var _card_data: Dictionary = {}
var _event_data: Dictionary = {}
var _metadata: Dictionary = {}
var _all_data: Dictionary = {}  # 所有数据的副本

func _init() -> void:
	print("[cardInfo] 单例初始化开始...")
	load_json_data()

## 加载 JSON 数据
func load_json_data() -> bool:
	if not ResourceLoader.exists(JSON_FILE_PATH):
		push_error("[cardInfo] 错误: JSON文件不存在! 路径: %s" % JSON_FILE_PATH)
		return false
	
	var file = FileAccess.open(JSON_FILE_PATH, FileAccess.READ)
	if not file:
		push_error("[cardInfo] 错误: 无法打开JSON文件! 路径: %s" % JSON_FILE_PATH)
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		push_error("[cardInfo] JSON解析失败: %s" % json.get_error_message())
		return false
	
	var data = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		push_error("[cardInfo] JSON根对象必须是字典")
		return false
	
	# 解析数据
	_all_data = data.duplicate(true)  # 复制所有数据
	
	if data.has("_metadata"):
		_metadata = data["_metadata"]
		_all_data.erase("_metadata")
	
	if data.has("cardInfo"):
		_card_data = data["cardInfo"]
	
	if data.has("eventInfo"):
		_event_data = data["eventInfo"]
	
	print("[cardInfo] cardInfo: %d 条记录" % _card_data.size())
	print("[cardInfo] eventInfo: %d 条记录" % _event_data.size())
	
	# 打印所有可用的数据表
	for key in _all_data.keys():
		if typeof(_all_data[key]) == TYPE_DICTIONARY:
			print("[cardInfo] 可用数据表: %s (%d 条)" % [key, _all_data[key].size()])
	
	return true

## 获取卡牌数据
func get_item(card_id: String) -> Dictionary:
	if _card_data.has(card_id):
		return _card_data[card_id]
	return {}

## 获取所有卡牌
func get_all_cards() -> Dictionary:
	return _card_data

## 根据类型获取卡牌列表
func get_cards_by_class(card_class: String) -> Array:
	var result: Array = []
	for card in _card_data.values():
		if card.get("cardClass") == card_class:
			result.append(card)
	return result

## 检查卡牌是否存在
func has_card(card_id: String) -> bool:
	return _card_data.has(card_id)

## 获取卡牌数量
func get_card_count() -> int:
	return _card_data.size()

## ======== eventInfo 相关方法 ========

## 获取事件数据
func get_event(event_id: int) -> Dictionary:
	var key = str(event_id)
	if _event_data.has(key):
		return _event_data[key]
	return {}

## 获取所有事件
func get_all_events() -> Dictionary:
	return _event_data

## 检查事件是否存在
func has_event(event_id: int) -> bool:
	return _event_data.has(str(event_id))

## 获取元数据
func get_metadata() -> Dictionary:
	return _metadata

## ======== 通用数据访问方法（支持新增表格） ========

## 获取任意数据表
func get_table(table_name: String) -> Dictionary:
	if _all_data.has(table_name) and typeof(_all_data[table_name]) == TYPE_DICTIONARY:
		return _all_data[table_name]
	return {}

## 获取数据表中的一项
func get_table_item(table_name: String, item_id: String) -> Dictionary:
	var table = get_table(table_name)
	if table.has(item_id):
		return table[item_id]
	return {}

## 检查数据表是否存在
func has_table(table_name: String) -> bool:
	return _all_data.has(table_name)

## 检查数据表中是否存在某项
func has_table_item(table_name: String, item_id: String) -> bool:
	var table = get_table(table_name)
	return table.has(item_id)

## 获取所有数据表名称
func get_table_names() -> Array:
	var names: Array = []
	for key in _all_data.keys():
		if typeof(_all_data[key]) == TYPE_DICTIONARY:
			names.append(key)
	return names
