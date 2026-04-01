extends Node
class_name CardDataJSON

## 卡牌数据 JSON 加载器
## 使用方式：
##   var data = CardDataJSON.new()
##   var ice_card = data.get_item("ice")
##   print(ice_card.display_name)  # 自动类型转换，无需手动 parse

const FILE_PATH = "res://assets/cardData.json"

# 数据存储
var _items: Dictionary = {}
var _metadata: Dictionary = {}

# 初始化
func _init() -> void:
	load_data()

func load_data() -> bool:
	if not ResourceLoader.exists(FILE_PATH):
		push_error("[CardDataJSON] 错误: JSON文件不存在! 路径: %s" % FILE_PATH)
		return false
	
	var file = FileAccess.open(FILE_PATH, FileAccess.READ)
	if not file:
		push_error("[CardDataJSON] 错误: 无法打开JSON文件! 路径: %s" % FILE_PATH)
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		push_error("[CardDataJSON] JSON解析失败: %s" % json.get_error_message())
		return false
	
	var data = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		push_error("[CardDataJSON] JSON根对象必须是字典")
		return false
	
	# 解析元数据
	if data.has("_metadata"):
		_metadata = data["_metadata"]
	
	# 解析数据项
	if data.has("items"):
		_items = _convert_types(data["items"])
	
	print("[CardDataJSON] 数据加载完成，共 %d 条记录" % _items.size())
	return true

## 转换字符串值为正确的类型
func _convert_types(raw_data: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	
	for key in raw_data:
		var item = raw_data[key]
		if typeof(item) == TYPE_DICTIONARY:
			result[key] = _parse_item_types(item)
	
	return result

## 解析单个项目的类型
func _parse_item_types(item: Dictionary) -> Dictionary:
	var parsed: Dictionary = {}
	
	# 定义字段类型映射
	var type_map = {
		"index": TYPE_INT,
		"price": TYPE_INT,
		"card": TYPE_INT,
		"max": TYPE_INT,
		"siteArea": TYPE_INT,
		"npcSched": TYPE_INT,
		"foodHP": TYPE_INT,
		"eventId": TYPE_INT
	}
	
	for field in item:
		var value = item[field]
		
		if type_map.has(field):
			# 根据类型映射转换
			match type_map[field]:
				TYPE_INT:
					parsed[field] = int(value) if value != "" else 0
				TYPE_FLOAT:
					parsed[field] = float(value) if value != "" else 0.0
				TYPE_BOOL:
					parsed[field] = bool(value) if value else false
				_:
					parsed[field] = str(value)
		else:
			# 默认转为字符串
			parsed[field] = str(value)
	
	return parsed

## 获取单个物品数据
func get_item(item_id: String) -> Dictionary:
	if _items.has(item_id):
		return _items[item_id]
	return {}

## 获取所有物品
func get_all_items() -> Dictionary:
	return _items

## 根据类型获取物品列表
func get_items_by_class(card_class: String) -> Array:
	var result: Array = []
	for item in _items.values():
		if item.get("cardClass") == card_class:
			result.append(item)
	return result

## 检查物品是否存在
func has_item(item_id: String) -> bool:
	return _items.has(item_id)

## 获取物品数量
func get_item_count() -> int:
	return _items.size()

## 获取元数据
func get_metadata() -> Dictionary:
	return _metadata
