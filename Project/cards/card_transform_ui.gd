
extends Control
# 卡牌变换UI控制

class_name CardTransformUI

@export var target_card: NodePath
@export var show_on_hover: bool = true
@export var fade_duration: float = 0.2

@onready var rotation_slider: HSlider = $Panel/RotationSlider
@onready var scale_slider: HSlider = $Panel/ScaleSlider
@onready var reset_button: Button = $Panel/ResetButton
@onready var close_button: Button = $Panel/CloseButton

var current_card: Node = null
var is_visible: bool = false

func _ready() -> void:
	# 隐藏UI初始状态
	modulate = Color.TRANSPARENT
	visible = false
	
	# 连接信号
	rotation_slider.value_changed.connect(_on_rotation_changed)
	scale_slider.value_changed.connect(_on_scale_changed)
	reset_button.pressed.connect(_on_reset_pressed)
	close_button.pressed.connect(_on_close_pressed)
	
	# 如果指定了目标卡牌
	if target_card:
		current_card = get_node(target_card)
		if current_card:
			_setup_for_card(current_card)

# 为指定卡牌设置UI
func setup_for_card(card: Node) -> void:
	current_card = card
	_setup_for_card(card)

func _setup_for_card(card: Node) -> void:
	if not card:
		return
	
	# 更新UI位置（在卡牌上方）
	var card_pos = card.global_position
	global_position = card_pos - Vector2(0, 120)
	
	# 更新滑块值
	if card.has_method("get_transform_info"):
		var info = card.get_transform_info()
		rotation_slider.value = info.get("rotation", 0)
		scale_slider.value = info.get("scale", Vector2.ONE).x

# 显示UI
func show_ui() -> void:
	if is_visible:
		return
	
	is_visible = true
	visible = true
	
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, fade_duration)

# 隐藏UI
func hide_ui() -> void:
	if not is_visible:
		return
	
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.TRANSPARENT, fade_duration)
	tween.finished.connect(func(): 
		visible = false
		is_visible = false
	)

# 旋转变化
func _on_rotation_changed(value: float) -> void:
	if current_card and current_card.has_method("rotate_card"):
		current_card.rotate_card(value)

# 缩放变化
func _on_scale_changed(value: float) -> void:
	if current_card and current_card.has_method("scale_card"):
		current_card.scale_card(value)

# 重置变换
func _on_reset_pressed() -> void:
	if current_card and current_card.has_method("reset_transform"):
		current_card.reset_transform()
		
		# 重置滑块
		rotation_slider.value = 0
		scale_slider.value = 1.0

# 关闭UI
func _on_close_pressed() -> void:
	hide_ui()

# 输入处理
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		# 点击UI外部时关闭
		if is_visible and not get_global_rect().has_point(event.position):
			hide_ui()
