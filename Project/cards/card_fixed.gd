extends Control
class_name card_fixed

var velocity = Vector2.ZERO
var damping = 0.35
var stiffness = 500

var preDeck

@export var cardClass: String
@export var cardName: String
@export var cardDesc: String
@export var cardPrice: int
@export var cardWeight: int = 1
@export var num: int = 1
@export var numc: int = 1
@export var cardCurrentState: int = 0
@export var follow_target: Node
@export var cardDisplayName: String

enum cardState {
	normal,
	following,
	dragging,
	vfs,
	fake,
	stacked
}

@onready var cardDisplay: Label = $CardDisplay
@onready var cardImage: ColorRect = $CardImage
@onready var cardButton: Button = $CardButton

var VfSlayer: Node
var Infos: Node

func _ready():
	VfSlayer = get_node("/root/VfSlayer")
	Infos = get_node("/root/Infos")
	
	if cardDisplay:
		cardDisplay.text = cardDisplayName if cardDisplayName else cardName
	
	# 设置按钮信号
	if cardButton:
		cardButton.button_down.connect(_on_button_button_down)
		cardButton.button_up.connect(_on_button_button_up)

func _on_button_button_down():
	print("卡牌按钮按下: %s" % cardName)
	
	# 创建副本
	var dup = duplicate()
	if dup != null:
		# 重置可能指向已释放对象的引用
		dup.follow_target = null
		VfSlayer.add_child(dup)
		dup.global_position = global_position
		dup.cardCurrentState = cardState.vfs
		cardCurrentState = cardState.dragging
		
		# 安全调用update_weight - 检查父节点是否存在且方法可用
		_safe_update_weight()
		
		if numc != 1 and numc != null:
			var c = Infos.add_new_card(cardName, get_parent().get_parent(), self) as Control
			# 在修改c的follow_target之前，先检查当前的follow_target是否有效
			if follow_target != null and is_instance_valid(follow_target):
				# c.follow_target.queue_free()
				c.follow_target = follow_target

func _on_button_button_up():
	print("卡牌按钮释放: %s" % cardName)
	
	# 安全调用update_weight - 检查父节点是否存在且方法可用
	_safe_update_weight()
	
	if follow_target != null and is_instance_valid(follow_target):
		# 检查follow_target是否仍然有效
		if follow_target is Node and is_instance_valid(follow_target):
			global_position = follow_target.global_position
			cardCurrentState = cardState.following
		else:
			# follow_target已无效，重置状态
			follow_target = null
			cardCurrentState = cardState.normal
	else:
		cardCurrentState = cardState.normal

# 安全调用update_weight方法
func _safe_update_weight() -> void:
	# 检查父节点的父节点是否存在
	var parent_parent = get_parent().get_parent() if get_parent() else null
	if parent_parent and parent_parent.has_method("update_weight"):
		parent_parent.update_weight()
	else:
		# 如果不存在或没有方法，静默失败
		pass

# 设置卡牌显示名称
func set_display_name(name: String) -> void:
	cardDisplayName = name
	if cardDisplay:
		cardDisplay.text = name

# 设置卡牌图片
func set_card_image(texture: Texture2D) -> void:
	# 这个方法需要根据实际UI结构调整
	# 如果cardImage是TextureRect，可以这样设置：
	# if cardImage and cardImage is TextureRect:
	#     cardImage.texture = texture
	pass

# 设置卡牌图片颜色（当图片不存在时使用）
func set_card_image_color(color: Color) -> void:
	if cardImage and cardImage is ColorRect:
		cardImage.color = color

# 设置牌桌引用
func set_table(table_node: Node) -> void:
	# 这个方法用于设置牌桌引用，以便update_weight可以正确调用
	# 实际上，我们只需要确保父节点的父节点有update_weight方法
	# 或者我们可以直接存储牌桌引用
	pass

# 卡牌堆叠功能
func cardStack(cardToStack) -> bool:
	# 简单的堆叠实现
	if cardToStack.cardName == cardName and cardCurrentState == cardState.following:
		numc += cardToStack.numc
		if cardDisplay:
			cardDisplay.text = "%s x%d" % [cardDisplayName if cardDisplayName else cardName, numc]
		return true
	return false
