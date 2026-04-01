#!/usr/bin/env python3
"""
卡牌堆叠系统生成器
自动生成Godot卡牌堆叠功能的GDScript代码
"""

import os
import sys

def generate_card_stack_manager():
    """生成卡牌堆叠管理器脚本"""
    code = '''extends Node
class_name CardStackManager

# 信号定义
signal card_added_to_stack(card, stack)
signal card_removed_from_stack(card, stack)
signal stack_formed(stack_cards)
signal stack_disbanded(stack_id)

# 堆叠相关参数
@export var max_stack_height: float = 10.0  # 最大堆叠高度
@export var stack_spacing: float = 2.0      # 卡牌间间距
@export var max_cards_per_stack: int = 15   # 每堆最大卡牌数

# 堆叠数据结构
var active_stacks = {}  # stack_id -> Array[card_nodes]
var card_to_stack = {}  # card -> stack_id

func _ready():
    print("卡牌堆叠管理器已就绪")

# 检查卡牌是否可以堆叠
func can_stack(card_a, card_b: float) -> bool:
    # 简单的距离检测
    var distance = card_a.global_position.distance_to(card_b.global_position)
    return distance < 50.0

# 添加卡牌到堆叠
func add_to_stack(card, stack_id = null):
    # 如果没有指定堆叠ID，创建新堆叠
    if stack_id == null or not active_stacks.has(stack_id):
        stack_id = generate_stack_id()
        active_stacks[stack_id] = []
    
    # 添加卡牌到堆叠
    active_stacks[stack_id].append(card)
    card_to_stack[card] = stack_id
    
    # 更新堆叠布局
    update_stack_layout(stack_id)
    
    # 发送信号
    emit_signal("card_added_to_stack", card, stack_id)
    return stack_id

# 从堆叠移除卡牌
func remove_from_stack(card):
    if not card_to_stack.has(card):
        return null
    
    var stack_id = card_to_stack[card]
    active_stacks[stack_id].erase(card)
    card_to_stack.erase(card)
    
    # 如果堆叠为空，移除它
    if active_stacks[stack_id].size() == 0:
        active_stacks.erase(stack_id)
        emit_signal("stack_disbanded", stack_id)
    else:
        update_stack_layout(stack_id)
    
    emit_signal("card_removed_from_stack", card, stack_id)
    return stack_id

# 更新堆叠布局
func update_stack_layout(stack_id):
    if not active_stacks.has(stack_id):
        return
    
    var cards = active_stacks[stack_id]
    var base_position = cards[0].global_position
    
    for i in range(cards.size()):
        var card = cards[i]
        var target_y = base_position.y - (i * stack_spacing)
        var target_position = Vector3(base_position.x, target_y, base_position.z)
        
        # 平滑移动到目标位置
        var tween = create_tween()
        tween.tween_property(card, "global_position", target_position, 0.2)
        tween.tween_property(card, "rotation", Vector3.ZERO, 0.2)

# 生成唯一堆叠ID
func generate_stack_id() -> String:
    return "stack_%s" % str(Time.get_ticks_msec())

# 获取卡牌所在的堆叠
func get_card_stack(card):
    return card_to_stack.get(card, null)

# 获取堆叠中的所有卡牌
func get_stack_cards(stack_id):
    return active_stacks.get(stack_id, [])

# 堆叠统计
func get_stack_count() -> int:
    return active_stacks.size()

func get_total_stacked_cards() -> int:
    var total = 0
    for stack_id in active_stacks:
        total += active_stacks[stack_id].size()
    return total
'''
    return code

def generate_stacking_card_extension():
    """生成支持堆叠的卡牌扩展脚本"""
    code = '''extends DraggableCard
class_name StackingCard

# 堆叠相关属性
var stack_id = null
var is_in_stack = false

func _ready():
    super._ready()
    print("堆叠卡牌已初始化")

# 覆盖拖动开始函数
func _on_gui_input(event: InputEvent):
    super._on_gui_input(event)
    
    # 如果被拖动且当前在堆叠中，通知堆叠管理器
    if event is InputEventMouseButton and event.pressed and is_dragging and stack_id:
        var stack_manager = get_node("/root/CardTable/CardStackManager")
        if stack_manager:
            stack_manager.remove_from_stack(self)
            stack_id = null
            is_in_stack = false

# 处理堆叠事件
func on_added_to_stack(new_stack_id):
    stack_id = new_stack_id
    is_in_stack = true
    # 禁用拖动当卡牌在堆叠中时
    set_draggable(false)

func on_removed_from_stack():
    stack_id = null
    is_in_stack = false
    # 重新启用拖动
    set_draggable(true)

# 检查是否与其他卡牌重叠（用于自动堆叠）
func check_for_overlap(other_card, threshold: float = 50.0) -> bool:
    var distance = global_position.distance_to(other_card.global_position)
    return distance < threshold
'''
    return code

def main():
    print("正在生成卡牌堆叠系统...")
    
    # 生成堆叠管理器
    manager_code = generate_card_stack_manager()
    
    # 生成卡牌扩展
    card_code = generate_stacking_card_extension()
    
    print("✓ 卡牌堆叠管理器已生成")
    print("✓ 支持堆叠的卡牌扩展已生成")
    print("")
    print("使用方法：")
    print("1. 将堆叠管理器节点添加到你的场景中")
    print("2. 更新卡牌脚本使用StackingCard类")
    print("3. 在card_table.gd中集成堆叠管理器")
    print("4. 测试堆叠功能")
    
    return manager_code, card_code

if __name__ == "__main__":
    manager, card = main()
    # 这里你可以选择将代码保存到文件
    # with open("card_stack_manager.gd", "w") as f:
    #     f.write(manager)
    # with open("stacking_card_extension.gd", "w") as f:
    #     f.write(card)