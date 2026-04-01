# Card 模块文档

> 生成时间：2026-03-26  
> 项目：Godot 卡牌游戏  
> 覆盖范围：`cards/`、`deck/`、`event/`、`data/`、`assets/` 中所有与卡牌相关的脚本

---

## 目录

1. [架构总览](#架构总览)
2. [cards/ — 卡牌本体](#cards--卡牌本体)
   - [card.gd — 卡牌基类](#cardgd--卡牌基类)
   - [card_fixed.gd — 卡牌重构版本](#card_fixedgd--卡牌重构版本)
   - [npc_card.gd — NPC卡](#npc_cardgd--npc卡)
   - [shop_card.gd — 商店卡](#shop_cardgd--商店卡)
   - [shop_item_card.gd — 商店商品卡](#shop_item_cardgd--商店商品卡)
   - [site_card.gd — 地点卡](#site_cardgd--地点卡)
   - [grid_snap_table.gd — 网格吸附牌桌基类](#grid_snap_tablegd--网格吸附牌桌基类)
   - [card_table_main.gd — 主牌桌](#card_table_maingd--主牌桌)
   - [card_transform_ui.gd — 卡牌变换UI](#card_transform_uigd--卡牌变换ui)
   - [get_in_button.gd — 地点进入按钮](#get_in_buttongd--地点进入按钮)
3. [deck/ — 牌桌](#deck--牌桌)
   - [deck.gd — 传统牌桌基类](#deckgd--传统牌桌基类)
   - [changeable_deck.gd — 可操作牌桌](#changeable_deckgd--可操作牌桌)
   - [hand_deck.gd — 手牌区](#hand_deckgd--手牌区)
   - [shop_card_deck.gd — 商店收购牌桌](#shop_card_deckgd--商店收购牌桌)
   - [delete.gd — 删除按钮](#deletegd--删除按钮)
4. [event/ — 事件系统](#event--事件系统)
   - [event.gd — 事件面板](#eventgd--事件面板)
   - [card_slot.gd — 卡槽](#card_slotgd--卡槽)
5. [全局辅助](#全局辅助)
   - [infos.gd — 全局单例](#infosgd--全局单例)
   - [assets/cardInfo.gd — 卡牌数据加载器（主版）](#assetscardinfogd--卡牌数据加载器主版)
   - [assets/cardDataJSON.gd — 卡牌数据加载器（旧版）](#assetscardDataJSONgd--卡牌数据加载器旧版)
   - [data/playerinfo.gd — 玩家存档数据](#dataplayerinfogd--玩家存档数据)
   - [data/deckSavedCards.gd — 牌桌存档数据](#datadecksavedcardsgd--牌桌存档数据)
   - [npc_manager.gd — NPC管理器](#npc_managergd--npc管理器)
6. [场景文件速查](#场景文件速查)
7. [核心流程图](#核心流程图)
8. [关键设计说明](#关键设计说明)

---

## 架构总览

```
card（基类）
├── npcCard          → NPC 展开/对话
├── shopCard         → 商店展开/购物
│   └── shopItemCard → 单个商品购买项
└── siteCard         → 跳转地图场景

GridSnapTable（网格牌桌基类，继承 Control）
└── CardTableMain    → 主牌桌，生成初始卡牌、管理事件面板

deck.gd（传统牌桌基类，继承 Panel）
├── changeable_deck.gd  → 全拿/紧凑/删除功能牌桌
├── hand_deck.gd        → 手牌区（继承 deck，仅覆盖 _ready）
└── shop_card_deck.gd   → 商店收购区（add_card 改为卖出逻辑）

EventPanel（事件面板）
└── CardSlot         → 单个卡槽（触发槽/条件槽）

Infos（CanvasLayer 全局自动加载单例）
└── add_new_card()   → 统一入口，按 cardClass 分发实例化

CardInfo（Node 全局自动加载单例）
└── 读取 assets/cardData.json → 提供 get_item/get_event/get_table 等接口
```

### 全局节点
| 单例名 | 说明 |
|---|---|
| `Infos` | 存档系统 + 统一创卡入口 |
| `CardInfo` | 卡牌/事件/数据表 JSON 读取 |
| `NpcManager` | NPC 对话管理 |
| `VfSlayer` | 拖拽期间卡牌浮层容器 |

---

## cards/ — 卡牌本体

---

### card.gd — 卡牌基类

**路径：** `res://cards/card.gd`  
**类名：** `card`  
**继承：** `Control`  
**场景：** `res://cards/card.tscn`（根节点 240×340，子节点 Panel/ColorRect/itemImg+name，Button，AllButton）

#### 属性

| 属性 | 类型 | 说明 |
|---|---|---|
| `velocity` | Vector2 | 弹簧运动速度 |
| `damping` | float = 0.35 | 弹簧阻尼 |
| `stiffness` | float = 500 | 弹簧刚度 |
| `preDeck` | Node | 当前所属牌桌（放置后记录） |
| `cardClass` | String | 卡牌类型（site/shop/npc/普通） |
| `cardName` | String | 卡牌 ID（与 JSON key 一致） |
| `maxStackNum` | int | 最大堆叠数量 |
| `cardWeight` | float | 单张重量 |
| `cardInfo` | Dictionary | 从 CardInfo 读取的完整数据 |
| `pickButton` | Node | 当前活动的拖拽按钮 |
| `dup` | Node | 拖拽期间的幽灵副本 |
| `num` | int = 1 | 当前堆叠数量 |
| `cardCurrentState` | cardState | 当前状态（枚举） |
| `follow_target` | Node | 弹簧跟随目标（传统 deck 模式用） |
| `whichDeckMouseIn` | Node | 每帧检测到的鼠标所在牌桌 |
| `del` | bool | 标记为待删除 |

#### 状态枚举 `cardState`

| 状态 | 说明 |
|---|---|
| `following` | 正常跟随目标位置（在牌桌内静止） |
| `dragging` | 被玩家拖拽中 |
| `vfs` | 幽灵副本（拖拽时的占位影子，不响应点击） |
| `fake` | 飞入堆叠动画副本（播放完销毁） |
| `hanging` | 已放入 CardSlot 卡槽中（锁定） |

#### 方法

##### `_process(delta)`
每帧主状态机：
- `dragging`：调用 `follow(鼠标位置)` 跟随鼠标；同时轮询 `cardDropable` 组，更新 `whichDeckMouseIn`
- `following`：调用 `follow(follow_target.global_position)`
- `vfs`：调用 `follow(鼠标位置)`（幽灵副本跟随）

##### `_input(event)`
补刀鼠标松手：  
- 仅在 `dragging` 状态下监听鼠标左键释放
- 用静态变量 `_current_dragger` 防止多张卡同时响应
- 触发 `_do_release()`

##### `follow(target_position, delta)`
弹簧跟随算法：
```
force = (target - position) * stiffness
velocity += force * delta
velocity *= (1 - damping)
position += velocity * delta
```

##### `_on_button_button_down()`
按下主逻辑，分三路：

1. **vfs 状态** → 直接忽略
2. **hanging 状态（从卡槽拖出）**：
   - 调用 `slot.remove_card(silent=true)` 脱离卡槽
   - 挂到 VfSlayer
   - 生成幽灵副本（`dup`）
   - 切换 `dragging`，注册 `_current_dragger`
3. **following 状态**：
   - **GridSnapTable 模式**（preDeck 有 `release_card`）：通知牌桌释放锚点，整体拖动，生成 dup
   - **旧 deck 模式**：拆分堆叠（num=1，剩余创新卡），生成 dup

##### `_on_button_button_up()`
松手信号处理：
- vfs/hanging 状态直接忽略
- 检查 `_current_dragger`，防止多张卡抢占
- 调用 `_do_release()`

##### `_do_release()`
**松手核心逻辑**（`_input` 和 `button_up` 共用）：
1. 清理 dup 幽灵副本
2. 若标记 `del=true`，销毁自己
3. 优先放入 `whichDeckMouseIn`（鼠标当前所在牌桌）
4. 否则放回 `preDeck`（上一个牌桌）
5. 兜底：从 `cardDropable` 组找 GridSnapTable 放入
6. 若全失败，state → `following`
7. 最后清空 `whichDeckMouseIn`

##### `initCard(Nm: String)`
初始化卡牌：
1. 从 `CardInfo.get_item(Nm)` 取数据
2. 赋值 `cardClass`、`cardName`、`maxStackNum`
3. state → `following`
4. 调用 `drawCard()`

##### `drawCard()`
绘制卡牌外观：
1. 获取图片节点（调 `_get_item_image_node()`）
2. 尝试加载 `cardImg/{cardName}.png` 或 `.svg`，找不到则用 `icon.svg`
3. 获取名称节点（调 `_get_name_label_node()`），设置 `displayName`
4. 获取堆叠按钮（调 `_get_all_button_node()`），设置 `X{num}`

##### `_get_item_image_node()` / `_get_name_label_node()` / `_get_all_button_node()`
兼容多场景结构的节点查找，依次尝试多条路径，找不到返回 null。

##### `_on_all_button_button_down()`
点击堆叠数字按钮（旧 deck 模式）：
- GridSnapTable 模式下禁用（直接 return）
- 旧 deck 模式：复制 dup 到 VfSlayer，切换 `dragging`（即从堆叠中拆出单张）

##### `canStackWith(other: card) -> bool`
判断能否与另一张卡牌堆叠：
- 必须同名（`cardName` 相同）
- 合并后不超过 `maxStackNum`
- 不与自身比较

##### `doStack(other: card) -> bool`
执行堆叠（合并）：
- 调 `canStackWith` 校验
- `num += other.num`
- 调 `drawCard()` 刷新显示
- 返回成功/失败

##### `splitStack(splitNum: int) -> card`
拆分堆叠：
- 校验 `0 < splitNum < num`
- `num -= splitNum`，调 `drawCard()`
- `duplicate()` 生成新卡，新卡 `num = splitNum`
- 返回新卡节点

##### `getDisplayName() -> String`
返回 `cardInfo["displayName"]`，找不到则返回 `cardName`。

##### `moveToPosition(targetPos, duration)`
Tween 动画移动到指定位置（TRANS_QUAD EASE_OUT）。

---

### card_fixed.gd — 卡牌重构版本

**路径：** `res://cards/card_fixed.gd`  
**类名：** `card_fixed`  
**继承：** `Control`  
**状态：** 独立实验版，尚未替换主流程

> 与 card.gd 逻辑相似，但结构更清晰：`@onready` 直接绑定节点引用，不依赖字符串路径查找。

#### 额外属性
- `cardDesc`：描述
- `cardPrice`：价格
- `numc`：堆叠总数（区别于 `num`）
- `cardDisplayName`：显示名称

#### 关键方法差异

| 方法 | 与 card.gd 差异 |
|---|---|
| `_ready()` | 自行获取 VfSlayer/Infos 引用，连接按钮信号 |
| `_safe_update_weight()` | 安全调用父父节点的 update_weight，静默失败 |
| `set_display_name(name)` | 直接更新 cardDisplay.text |
| `set_card_image_color(color)` | 设置 ColorRect 颜色 |
| `cardStack(cardToStack)` | 简化堆叠逻辑，合并 numc |

---

### npc_card.gd — NPC卡

**路径：** `res://cards/npc_card.gd`  
**类名：** `npcCard`  
**继承：** `card`  
**场景：** `res://cards/npc_card.tscn`（Panel+siteImg+npcImg+Button+nameLabel）

#### 方法

##### `drawCard()`
- 设置 `$nameLabel.text = cardInfo["base_displayName"]`
- 设置 `pickButton = $Button`

##### `_on_cardnpc_button_down()`
点击展开 NPC 卡：
1. `hanging` 状态直接 return（防重入）
2. `NpcManager.currentNpc = self`
3. state → `hanging`，z_index = 1000，移到同级末尾
4. Tween：TextureRect 横向展开至 1545×317（0.5s EXPO_OUT）
5. Tween：siteImg 淡入
6. Tween：卡牌飞到父节点位置
7. 隐藏 Button，显示 nameLabel
8. 启动 DialogueManager 对话气泡

##### `_on_esc()`
收起 NPC 卡（由 NpcManager 或对话系统回调）：
1. `follow_target.visible = true`
2. state → `following`
3. Tween：TextureRect 缩回 220×317（0.3s EXPO_OUT）
4. Tween：siteImg 淡出
5. 显示 Button，隐藏 nameLabel

---

### shop_card.gd — 商店卡

**路径：** `res://cards/shop_card.gd`  
**类名：** `shopCard`  
**继承：** `card`  
**场景：** `res://cards/shop_card.tscn`（含 shopCardDeck 实例）

#### 属性
- `priceRatio`：价格倍率（从 `cardInfo["base_card"]` 读取）
- `items: PackedStringArray`：商品列表（由 `cardInfo["base_desc"]` 按 `!` 分割）
- `diaPath`：对话路径（预留）
- `deckP`：展开前的父节点
- `dioScene`：当前对话场景实例

#### 方法

##### `drawCard()`
- 设置名称标签、描述
- 解析 `priceRatio` 和 `items` 列表

##### `_on_butto_down()`
点击展开商店：
1. `NpcManager.currentNpc = self`
2. state → `hanging`，从父节点脱出，挂到 VfSlayer
3. `follow_target.visible = false`
4. Tween：横向展开至 1545×317
5. 显示 Button2 和 nameLabel，npcImg 淡入
6. Tween：飞到屏幕左侧 (355, 0)
7. 显示 shopCardDeck，Tween 展开至 1565×360
8. 调用 `shop_add_card()` 填充商品

##### `show_dia(diaName: String)`
切换对话场景（若已有则先 queue_free）。

##### `shop_add_card()`
遍历 `items` 列表，每项：
1. 实例化 `shopItemCard.tscn`
2. 设置 `priceRatio`，连接 `showDia` 信号
3. `initCard(item_name)`
4. 添加 card_background 到 `shopCardDeck.cardPoiDeck`
5. 将卡牌移入 `shopCardDeck.cardDeck`
6. 设置 `follow_target = cardBackground`，state → `following`
7. 每张卡间隔 0.1s（逐一飞入动画效果）

##### `leave()`
商店关闭动画：等 0.5s，淡出，隐藏自身和 follow_target。

---

### shop_item_card.gd — 商店商品卡

**路径：** `res://cards/shop_item_card.gd`  
**类名：** `shopItemCard`  
**继承：** `card`  
**场景：** `res://cards/shopItemCard.tscn`

#### 属性
- `price`：计算后价格 = `round(priceRatio * cardInfo["base_price"])`
- `itemName`：商品的卡牌 ID（`cardInfo["base_cardName"]`）
- `priceRatio: float`：由父级 shopCard 传入
- `signal showDia(diaName: String)`：金币不足时触发

#### 方法

##### `drawCard()`
- 读取 `price` 并显示在 `$price`

##### `_on_button_button_down()`
购买逻辑：
1. 若 `Infos.save.money >= price`：
   - `Infos.add_new_card(itemName, Infos.hand_deck, self)` 加入手牌
   - `Infos.save.money -= price`
   - `Infos.playerUpdate()` 刷新金币UI
2. 否则：发出 `showDia("lackOfMoney")` 信号，`NpcManager.customCounter += 1`

---

### site_card.gd — 地点卡

**路径：** `res://cards/site_card.gd`  
**类名：** `siteCard`  
**继承：** `card`（字符串引用 `"res://cards/card.gd"`）  
**场景：** `res://cards/siteCard.tscn`（TextureRect+VBoxContainer+siteImg+Label+getInButton）

#### 方法

##### `drawCard()`
- `pickButton = $getInButton`
- 设置描述 Label 和名称 Label
- `$getInButton.visible = true`

##### `_on_get_in_button_button_down()`
进入地图场景：
1. 保存所有 `saveableDecks` 组的牌桌（`d.storCard()`）
2. 路径：`res://site/{cardName}.tscn`
3. 若文件存在则 `change_scene_to_file`；否则打印错误

---

### grid_snap_table.gd — 网格吸附牌桌基类

**路径：** `res://cards/grid_snap_table.gd`  
**类名：** `GridSnapTable`  
**继承：** `Control`

#### 属性

| 属性 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `snap_step_x` | float | 70.0 | X 轴网格间距 |
| `snap_step_y` | float | 90.0 | Y 轴网格间距 |
| `debug_draw_anchors` | bool | false | 调试绘制锚点 |
| `anchor_buffer` | int | 3 | 视口外扩展缓冲格数 |
| `table_offset` | Vector2 | ZERO | 桌面拖动累积偏移 |
| `_anchor_map` | Dictionary | {} | Vector2i → card 节点 |
| `cards_container` | Control | $Cards | 卡牌容器 |

#### 公开 API

##### `place_card(card_node: card)`
卡牌放置总入口：
1. 检测是否在删除区 → 调 `remove_card`
2. `_world_to_nearest_grid` 算最近格
3. BFS 找可用锚点：`_find_available_anchor`
4. 若找不到 → 原位回退（`_place_at_position`）
5. 同名 → `_merge_cards`；空格 → `_place_at_anchor`

##### `release_card(card_node: card)`
卡牌被拖起时调用：
- 清除 `_anchor_map` 中该卡的占用
- 保存当前位置到 meta `_last_valid_position`（用于回退）

##### `add_card(card_node: card)`
兼容旧 deck 接口，转发到 `place_card`。

##### `update_weight()`
兼容接口，空实现（GridSnapTable 无重量系统）。

##### `remove_card(card_node: card)`
从牌桌移除：释放锚点、从容器移除、`queue_free`。

##### `refresh_card_positions()`
强制刷新所有卡牌世界坐标（桌面拖动后调用）。

##### `world_to_grid(world_pos) / grid_to_world(grid_pos)`
坐标转换公开接口，转发到私有方法。

#### 私有方法

##### `_world_to_nearest_grid(world_pos) -> Vector2i`
```
local = world_pos - table_offset
gx = round(local.x / snap_step_x)
gy = round(local.y / snap_step_y)
```

##### `_grid_to_world(grid_pos) -> Vector2`
```
return Vector2(gx * snap_step_x, gy * snap_step_y) + table_offset
```

##### `_find_available_anchor(start, card_node) -> Vector2i`
BFS 搜索可用锚点（最大半径 20 格）：
- 按 Chebyshev 环形逐层扩展（`_ring_cells`）
- 在牌桌范围内（min_grid ~ max_grid）
- 空格 ✓ 或同名可合并 ✓
- 找不到返回 `(-99999, -99999)`

##### `_ring_cells(center, r) -> Array[Vector2i]`
生成 Chebyshev 半径 r 的环上所有格坐标（r=0 时只返回 center）。

##### `_merge_cards(target, source)`
同名合并：
- 调 `target.doStack(source)` 
- 成功 → `_play_merge_animation`（飞入后 queue_free）
- 失败（超堆叠上限）→ `_find_next_empty_anchor` + `_place_at_anchor`

##### `_find_next_empty_anchor(start) -> Vector2i`
找严格空锚点（不接受同名合并，供堆叠上限时使用）。

##### `_place_at_anchor(card_node, grid_pos)`
放置到锚点：
- 注册 `_anchor_map[grid_pos] = card_node`
- 确保在 cards_container 下
- Tween：TRANS_BACK EASE_OUT 吸附动画（0.18s）
- state → `following`，`follow_target = null`，`preDeck = self`

##### `_place_at_position(card_node, world_pos)`
移动到指定位置（不绑定锚点，用于回退原位）。

##### `_play_merge_animation(target, source)`
合并飞入动画：0.15s 飞向 target，结束后 `source.queue_free()`。

##### `_input(event)`
中键桌面拖动：
- 按下中键：记录起始位置和偏移
- 拖动中：`table_offset = 起始偏移 + delta`，调 `_on_table_moved`

##### `_on_table_moved()`
更新所有 `following` 状态卡牌的位置（直接赋值，不用 tween，保持流畅感）。

##### `_draw()`
调试绘制：绿点=空锚点，橙点=已占用。

---

### card_table_main.gd — 主牌桌

**路径：** `res://cards/card_table_main.gd`  
**类名：** `CardTableMain`  
**继承：** `GridSnapTable`  
**场景：** `res://cards/card_table_main.tscn`

#### 配置属性
- `initial_cards: Array[String]`：初始卡牌列表（Inspector 可改）
- `card_scene: PackedScene`：卡牌场景（默认 card.tscn）
- `event_panel_scene: PackedScene`：事件面板场景

#### 方法

##### `_ready()`
1. `super._ready()`（GridSnapTable 初始化）
2. `_set_fullscreen()` 全屏锚点
3. `_ensure_card_info_loaded()` 确保数据加载
4. 等一帧后 `_spawn_initial_cards()`
5. `_setup_delete_zone()` 删除区交互

##### `_set_fullscreen()`
设置自身和背景 anchor = (0,0,1,1)，offset = 0。

##### `_setup_delete_zone()`
删除区（右下角 ColorRect）鼠标进出高亮效果，设 `mouse_filter = PASS`。

##### `_is_in_delete_zone(card_node) -> bool`
检测卡牌中心是否在 DeleteZone 内。

##### `_ensure_card_info_loaded()`
检查 CardInfo 单例，若未加载则手动实例化 `cardInfo.gd` 并调 `load_json_data()`。

##### `_spawn_initial_cards()`
按 `initial_cards` 列表生成初始卡牌：
- 计算牌桌网格范围
- 同名卡分配同一起始格，交由 `place_card` 自动合并
- 不同名各占一格（BFS 自动找空格）

##### `_input(event)`
键盘快捷键（先交给 super 处理桌面拖动）：
- `ESC`：退出游戏
- `F1`：`_print_debug_info()`
- `F2`：`_print_slot_debug()` 诊断 cardDropable 组
- `F4`：`_respawn_cards()` 重新生成

##### `_print_debug_info()`
打印锚点占用数、卡牌总数、所有锚点信息。

##### `_respawn_cards()`
清空 `_anchor_map` 和 cards_container，重新生成。

##### `_print_slot_debug()`
F2 诊断：打印所有 `cardDropable` 组节点的 global_rect。

##### `add_new_card_by_name(card_key: String)`
供 EventPanel 的 result 执行器调用，内部转发 `_add_single_card`。

##### `open_event_panel_by_id(event_id: int)`
通过 eventId 打开事件面板（`_get_or_create_event_panel` + `open_event_by_id`）。

##### `open_event_panel_for_card(trigger_card: card)`
通过触发卡打开事件面板。

##### `_get_or_create_event_panel() -> EventPanel`
事件面板单例管理：已存在则复用，否则实例化并添加到根节点（visible=false）。

##### `_add_single_card(card_key: String)`
添加单张卡牌：实例化 → initCard → 位置设为牌桌中心 → `place_card`。

---

### card_transform_ui.gd — 卡牌变换UI

**路径：** `res://cards/card_transform_ui.gd`  
**类名：** `CardTransformUI`  
**继承：** `Control`

> 可附加到任意卡牌的旋转/缩放调整 UI，hover 时淡入淡出。

#### 方法

| 方法 | 说明 |
|---|---|
| `setup_for_card(card)` | 公开接口：为指定卡设置 UI 位置和滑块初始值 |
| `show_ui()` | Tween 淡入（modulate WHITE） |
| `hide_ui()` | Tween 淡出（modulate TRANSPARENT），完成后 visible=false |
| `_on_rotation_changed(value)` | 调用卡牌 `rotate_card(value)` |
| `_on_scale_changed(value)` | 调用卡牌 `scale_card(value)` |
| `_on_reset_pressed()` | 调用卡牌 `reset_transform()`，重置滑块 |
| `_on_close_pressed()` | hide_ui() |
| `_input(event)` | 点击 UI 外部时自动关闭 |

---

### get_in_button.gd — 地点进入按钮

**路径：** `res://cards/get_in_button.gd`  
**继承：** `Button`

#### 方法

| 方法 | 说明 |
|---|---|
| `_on_mouse_entered()` | 显示 $Panel，Tween 淡入（modulate 透明→不透明，0.2s） |
| `_on_mouse_exited()` | Tween 淡出（modulate→透明，0.2s），完成后隐藏 Panel |

---

## deck/ — 牌桌

---

### deck.gd — 传统牌桌基类

**路径：** `res://deck/deck.gd`  
**继承：** `Panel`  
**场景：** `res://deck/deck.tscn`（groups: cardDeck, cardDropable, saveableDecks）

#### 属性
- `cardDeck: Control`：卡牌实际父节点
- `cardPoiDeck: HBoxContainer`：卡牌背景占位节点（ScrollContainer 内）
- `currentWeight: int`：当前重量
- `maxWeight: int = 180`：最大重量
- `cardsSaved: Array[PackedScene]`：存档用的打包场景列表
- `defultCards: Array[String]`：默认卡牌列表

#### 方法

##### `_ready()`
- 若在 `saveableDecks` 组 → `loadCards()`
- 否则按 `defultCards` 生成卡牌
- 设置 ProgressBar max_value

##### `_process(delta)`
每帧：按 x 坐标对 cardDeck 子节点排序（`sort_nodes_by_position`）。

##### `sort_nodes_by_position(children)` / `sort_by_position(a, b)`
按 `position.x` 升序排列，同时更新 `z_index` 和 move_child。  
（`hanging` 状态的卡牌跳过 z_index 更新）

##### `add_card(cardToAdd)`
添加卡牌到传统 deck：
1. 若重量允许，尝试同名堆叠（`_try_stack_same_name`）
2. 检测附近（100px）是否有不同名卡牌（1/4偏移）
3. 创建 cardBackground 并加入 cardPoiDeck
4. 将卡牌移入 cardDeck
5. 有不同名邻居 → 计算偏移（`_calculate_stack_offset`）并偏移放置
6. 设置 `follow_target = cardBackground`，`preDeck = self`，state → `following`
7. `update_weight()`

##### `update_weight()`
重算重量（仅 `following` 状态的卡牌计入），更新 weight Label 和 ProgressBar。

##### `_try_stack_same_name(cardToStack: card) -> bool`
遍历 cardDeck 子节点，找到同名 following 状态的卡 → `doStack` → `_play_stack_animation` → `queue_free`。

##### `_get_nearby_cards(pos, radius) -> Array[card]`
返回 cardDeck 中距离 pos 在 radius 内的所有 following 卡。

##### `_calculate_stack_offset(baseCard, newCard) -> Vector2`
基于 `newCard.cardName.hash()` 决定偏移方向（上/右/下/左，±30px）。

##### `_play_stack_animation(targetCard, sourceCard)`
堆叠飞入动画：
- 复制 sourceCard 为 fakeCard（z_index=1000，state=fake）
- 加入 VfSlayer，从鼠标位置飞向 targetCard（0.2s TRANS_BACK）
- 结束后 queue_free

##### `card_is_stacked(cardToStack) -> bool`（旧接口，保留兼容）
转发到 `_try_stack_same_name`。

##### `fake_card_move(cardTofake)`（旧动画接口，保留兼容）
与 `_play_stack_animation` 类似。

##### `storCard()`
保存卡牌到存档：
1. 将 cardDeck 子节点逐一 `PackedScene.pack(c)`
2. 存入 `deckSavedCards` Resource
3. `Infos.save.decks[节点路径] = saver`

##### `loadCards()`
从存档加载：
1. 若 `Infos.save.decks` 有本牌桌路径 → 实例化各 PackedScene，调 `add_card`
2. 否则按 `defultCards` 生成默认卡牌

##### `clear_children(node)`
清空节点的所有子节点并 `queue_free`。

---

### changeable_deck.gd — 可操作牌桌

**路径：** `res://deck/changeable_deck.gd`  
**继承：** `deck.gd`  
**场景：** `res://deck/changeableDeck.tscn`

#### 额外属性
- `compressed: bool = false`：是否紧凑模式
- `compressedSize: Vector2 = (130, 360)`
- `normalSize: Vector2 = (240, 360)`

#### 方法

| 方法 | 说明 |
|---|---|
| `_on_get_all_button_down()` | 全拿：对 cardDeck 所有子节点调 `_on_all_button_button_down()` |
| `_on_get_all_button_up()` | 全拿松手：对所有子节点调 `_on_button_button_up()` |
| `_on_delete_button_down()` | 预留删除功能（空实现） |
| `_on_compressed_toggled(toggled_on)` | 切换紧凑/正常尺寸，更新所有 cardPoiDeck 子节点的 minimum_size |
| `_on_card_poi_deck_child_entered_tree(node)` | 新卡入树时，若紧凑模式则应用紧凑尺寸 |
| `_on_delete_mouse_entered()` | 鼠标进入删除按钮：对所有 dragging 状态卡设 `del=true` |
| `_on_delete_mouse_exited()` | 鼠标离开删除按钮：取消 `del` 标记 |

---

### hand_deck.gd — 手牌区

**路径：** `res://deck/hand_deck.gd`  
**继承：** `deck.gd`  
**场景：** `res://deck/handDeck.tscn`（groups: cardDeck, cardDropable，不含 saveableDecks）

#### 方法

##### `_ready()`
- 设置 ProgressBar.max_value = maxWeight
- 调用 `update_weight()`

---

### shop_card_deck.gd — 商店收购牌桌

**路径：** `res://deck/shop_card_deck.gd`  
**继承：** `deck.gd`  
**场景：** `res://deck/shopCardDeck.tscn`（ProgressBar 隐藏）

#### 属性
- `priceRatio: float`：价格倍率
- `signal showDia(diaName: String)`

#### 方法

##### `add_card(cardToAdd: Node)` 【完全重写】
卖出逻辑（替代父类 add_card）：
1. `price = cardToAdd.price`
2. 若 `price <= 0` → emit `showDia("worthless")`，return
3. `Infos.save.money += price * num`，`playerUpdate()`
4. `cardToAdd.queue_free()`
5. emit `showDia("deal")`

---

### delete.gd — 删除按钮

**路径：** `res://deck/delete.gd`  
**继承：** `Button`

> 自定义鼠标进出检测，轮询替代信号，解决 Button `mouse_entered/exited` 信号在某些场景丢失的问题。

#### 方法

##### `_process(delta)`
每帧：用 `get_global_rect().has_point(mouse_pos)` 检测鼠标是否在矩形内，状态改变时手动 emit `mouse_entered` / `mouse_exited`。

---

## event/ — 事件系统

---

### event.gd — 事件面板

**路径：** `res://event/event.gd`  
**类名：** `EventPanel`  
**继承：** `Control`

#### 流程
```
open_panel() → 等待玩家拖卡到触发槽
→ _on_trigger_card_placed → _load_event(eventId)
→ 玩家填满条件槽 → _check_condition → confirm_button 激活
→ _on_confirm_pressed → _execute_result → _consume_slot_cards
→ 0.8s 后 close_panel()
```

#### 状态枚举 `EventState`

| 状态 | 说明 |
|---|---|
| `IDLE` | 初始/重置，等待触发卡 |
| `WAITING` | 事件已加载，等待条件满足 |
| `CONDITION_MET` | 所有条件槽已填满 |
| `COMPLETED` | 已执行 result |

#### 关键方法

##### `_ready()`
收集条件卡槽（`_collect_slots`），连接信号，`_reset_to_idle`。

##### `_collect_slots()`
遍历 slot_container 子节点，收集 `slot_index >= 0` 的 CardSlot 并按 index 排序；触发槽（index=-1）单独连接。

##### `open_panel()` / `open_event_by_id(id)` / `open_event(trigger_card)`
三种打开方式，最终都调 `_load_event`。

##### `_load_event(event_id)`
从 `CardInfo.get_event(event_id)` 加载数据，更新标题/描述/卡槽配置。

##### `_setup_slots(data)`
根据 event_data 中的 `card_1`~`card_6` 字段配置各槽的 `required_card_type`，多余槽隐藏。

##### `_check_condition() -> bool`
检查是否所有必填槽都已占用；是则 state → `CONDITION_MET`，激活确定按钮。

##### `_on_confirm_pressed()`
执行 result → 消耗卡槽卡牌 → 0.8s 后关闭。

##### `_execute_result(result_string)`
解析 result 格式（目前支持类型 1：`1_{index}_{amount}` 给卡）。

##### `_give_card_by_index(target_index, amount)`
从 CardInfo 中找对应 index 的卡牌，调 `CardTableMain.add_new_card_by_name` 若干次。

##### `_consume_slot_cards()`
销毁所有条件槽和触发槽中的卡。

##### `_return_card_to_table(c)`
将卡牌退回主牌桌（`add_card`）或手动恢复 `following` 状态。

##### `close_panel()`
未完成则退回所有槽中卡，隐藏面板。

---

### card_slot.gd — 卡槽

**路径：** `res://event/card_slot.gd`  
**类名：** `CardSlot`  
**继承：** `Control`

#### 属性
- `slot_index: int`：槽编号（-1=触发槽，0~5=条件槽）
- `required_card_type: String`：接受的卡牌类型格式 `"class_index"`，空=任意
- `current_card: card`：当前放入的卡
- `is_occupied: bool`：是否已被占用

#### 信号
- `card_placed(slot_index, placed_card)`
- `card_removed(slot_index)`

#### 方法

##### `_ready()`
加入 `cardDropable` 组（使 card.gd 的拖放系统可识别），刷新外观。

##### `add_card(new_card: card)`
card.gd 松手时调用：
1. 已占用 → 退回原牌桌（preDeck）或 following
2. 类型不匹配 → 闪红（`_flash_wrong`），退回
3. 通过 → `_place_card(new_card)`

##### `_is_card_match(c: card) -> bool`
按 `required_card_type` 格式（`class_index`）检查 cardClass 和 index 是否匹配。

##### `_place_card(new_card: card)`
放入卡牌：
- `is_occupied = true`，`current_card = new_card`
- state → `hanging`（立即锁定，防止 button_up 覆盖）
- `call_deferred("_do_reparent_card", new_card)`

##### `_do_reparent_card(new_card: card)`
下一帧执行：
- 检查卡牌是否已被拖走（preDeck ≠ self 或 state = dragging）→ 跳过
- remove_child from 旧父节点，add_child to self
- 设置全屏锚点（layout_mode=1, anchor 全 0~1，offset 全 0）

##### `remove_card(silent: bool = false) -> card`
移除卡牌：
- 重置 `is_occupied`、`current_card`
- remove_child，重置 layout_mode 和 anchor
- 若非 silent，emit `card_removed`

##### `_update_visual()`
根据 `is_occupied` 更新背景颜色（正常/占用）。

##### `_flash_wrong()`
闪红：设置 `COLOR_WRONG`，0.3s 后恢复正常颜色。

---

## 全局辅助

---

### infos.gd — 全局单例

**路径：** `res://infos.gd`  
**继承：** `CanvasLayer`  
**全局名：** `Infos`

#### 属性
- `saves: Dictionary`：所有存档
- `save: player`：当前存档
- `playerInfoPath: String`：存档路径
- `hand_deck: Control`：手牌区节点引用

#### 方法

##### `add_new_card(cardName, cardDeck, caller?) -> Node`
**统一创卡入口**：
1. `CardInfo.get_item(cardName)` 取数据
2. 按 `cardClass` 实例化对应场景：
   - `site` → `siteCard.tscn`
   - `shop` → `shop_card.tscn`
   - `npc` → `npc_card.tscn`
   - 其他 → `card.tscn`
3. `initCard(cardName)`
4. 位置设为 caller.global_position，z_index=100
5. `cardDeck.add_card(cardToAdd)`
6. 返回卡牌节点

##### `loadPlayerInfo(savePath)`
- 加载 `user://save/{savePath}.tres` 存档
- 更新 hand_deck.maxWeight
- 跳转到存档中的场景
- `hand_deck.loadCards()`，刷新 UI

##### `playerUpdate()`
更新金币显示：`$moneyLabel.text = "$" + str(save.money)`

##### `savePlayerInfo(newSavePath)`
- 遍历 `saveableDecks` 组全部保存（`storCard`）
- `ResourceSaver.save(save, path)`

---

### assets/cardInfo.gd — 卡牌数据加载器（主版）

**路径：** `res://assets/cardInfo.gd`  
**类名：** `cardInfo`（全局自动加载为 `CardInfo`）  
**数据源：** `res://assets/cardData.json`

#### JSON 结构
```json
{
  "_metadata": { ... },
  "cardInfo": { "ice": { ... }, "Stone": { ... } },
  "eventInfo": { "1": { ... }, "2": { ... } },
  "自定义表": { ... }
}
```

#### 方法

| 方法 | 说明 |
|---|---|
| `load_json_data() -> bool` | 读取/解析 JSON，分离 cardInfo/eventInfo/_metadata |
| `get_item(card_id) -> Dictionary` | 获取单张卡牌数据，找不到返回 `{}` |
| `get_all_cards() -> Dictionary` | 返回全部 cardInfo |
| `get_cards_by_class(class) -> Array` | 按 cardClass 过滤 |
| `has_card(card_id) -> bool` | 是否存在 |
| `get_card_count() -> int` | 卡牌总数 |
| `get_event(event_id: int) -> Dictionary` | 获取事件数据（key 为 str(id)） |
| `get_all_events() -> Dictionary` | 全部事件 |
| `has_event(event_id: int) -> bool` | 事件是否存在 |
| `get_metadata() -> Dictionary` | 元数据 |
| `get_table(table_name) -> Dictionary` | 获取任意数据表 |
| `get_table_item(table, item_id) -> Dictionary` | 获取表中单项 |
| `has_table(table_name) -> bool` | 表是否存在 |
| `has_table_item(table, item_id) -> bool` | 项是否存在 |
| `get_table_names() -> Array` | 所有数据表名称 |

---

### assets/cardDataJSON.gd — 卡牌数据加载器（旧版）

**路径：** `res://assets/cardDataJSON.gd`  
**类名：** `CardDataJSON`  
**状态：** 独立旧版本，与 cardInfo.gd 平行存在

> 数据结构不同（items 平铺在顶层），有字段类型自动转换功能（TYPE_INT 等映射）。

#### 方法（与 cardInfo.gd 对应）
- `load_data() -> bool`
- `_convert_types(raw) -> Dictionary`：递归类型转换
- `_parse_item_types(item) -> Dictionary`：按 type_map 字段转换（index/price/card/max 等 → int）
- `get_item / get_all_items / get_items_by_class / has_item / get_item_count / get_metadata`

---

### data/playerinfo.gd — 玩家存档数据

**路径：** `res://data/playerinfo.gd`  
**类名：** `player`  
**继承：** `Resource`

| 字段 | 类型 | 说明 |
|---|---|---|
| `nowTime` | float | 当前时间 |
| `money` | int | 金币 |
| `playerName` | String | 玩家名 |
| `star / planet / loacation` | String | 位置信息 |
| `handMax` | float | 手牌最大重量 |
| `HP / HPMax / HPRate` | float | 生命值 |
| `handCurrent` | int | 当前手牌数 |
| `recipes` | Array[String] | 已解锁配方 |
| `folderPath` | String | 存档文件夹路径 |
| `decks` | Dictionary | 各牌桌存档（路径→deckSavedCards） |

---

### data/deckSavedCards.gd — 牌桌存档数据

**路径：** `res://data/deckSavedCards.gd`  
**类名：** `deckSavedCards`  
**继承：** `Resource`

```gdscript
@export var cards: Array[PackedScene]
```

---

### npc_manager.gd — NPC管理器

**路径：** `res://npc_manager.gd`  
**全局名：** `NpcManager`

#### 属性
- `currentNpc: Control`：当前展开的 NPC/商店卡

#### 方法

##### `npc_give_card(cardName, num: int = 1)`
NPC 赠卡：逐一（间隔 0.1s）调用 `Infos.add_new_card` 到 `Infos.hand_deck`。

##### `esc_dialogue()`
关闭当前对话：调 `currentNpc._on_esc()`。

---

## 场景文件速查

| 场景文件 | 脚本 | 根节点尺寸 | 关键子节点 |
|---|---|---|---|
| `cards/card.tscn` | card.gd | 240×340 | Panel/ColorRect/itemImg+name；Button；AllButton |
| `cards/card_background.tscn` | 无 | 220×340 | 仅根节点（占位背景） |
| `cards/card_table.tscn` | card_table_with_stacking.gd | 全屏 | Bg；Cards；BackButton |
| `cards/card_table_main.tscn` | CardTableMain | 全屏 | Background；Cards；TitleLabel；HelpLabel；AddIceButton；TestEventButton；DeleteZone |
| `cards/npc_card.tscn` | npcCard | 220×317 | TextureRect(Panel)/siteImg+npcImg；Button；nameLabel |
| `cards/shopItemCard.tscn` | shopItemCard | 240×340 | Control/VBoxContainer/ColorRect/itemImg+name；Button；price/price2 |
| `cards/shop_card.tscn` | shopCard | 240×340 | shopCardDeck(实例)；TextureRect/siteImg+npcImg；Button+Button2；nameLabel |
| `cards/siteCard.tscn` | siteCard | 240×340 | TextureRect/VBoxContainer/siteImg+Label；getInButton |
| `deck/deck.tscn` | deck.gd | 全屏 | ScrollContainer/cardPoiDeck；cardDeck；ProgressBar；weight |
| `deck/changeableDeck.tscn` | changeable_deck.gd | 940×200 | （同 deck）+Panel/getAll+compressed+delete |
| `deck/handDeck.tscn` | hand_deck.gd | 全屏 | （同 deck）|
| `deck/shopCardDeck.tscn` | shop_card_deck.gd | 全屏 | （同 deck，ProgressBar 隐藏） |

---

## 核心流程图

### 拖拽放置流程

```
玩家按下卡牌
    ↓
_on_button_button_down()
    ├── hanging 状态 → slot.remove_card(silent) → 挂 VfSlayer → 生成 dup → dragging
    ├── following + GridSnapTable → preDeck.release_card → 生成 dup → dragging
    └── following + 旧 deck → 拆分堆叠 → 生成 dup → dragging

[每帧] _process：follow(鼠标) + 更新 whichDeckMouseIn

玩家松手
    ↓
_do_release()
    ├── queue_free(dup)
    ├── del=true → queue_free(self)
    ├── whichDeckMouseIn.add_card(self)  ← 优先
    ├── preDeck.add_card(self)
    └── 兜底：找 GridSnapTable.add_card
```

### GridSnapTable 放置流程

```
add_card(card) → place_card(card)
    ↓
_is_in_delete_zone? → remove_card + queue_free
    ↓
_world_to_nearest_grid(card.global_position) = best_grid
    ↓
_find_available_anchor(best_grid, card) [BFS]
    ├── 同名格 → _merge_cards → doStack → 飞入动画
    └── 空格   → _place_at_anchor → 吸附 Tween 0.18s
```

### 事件面板流程

```
open_panel()
    ↓
玩家拖卡到触发槽 → _on_trigger_card_placed
    ↓
_load_event(eventId) → 配置标题/描述/条件槽
    ↓
玩家填满条件槽 → _check_condition → confirm 激活
    ↓
_on_confirm_pressed
    ├── _execute_result("1_index_amount") → 给卡
    ├── _consume_slot_cards → queue_free 条件卡+触发卡
    └── 0.8s → close_panel()
```

### 存档流程

```
切场景前：site_card / goto_button
    ↓
saveableDecks 组 → d.storCard()
    ↓ deck.storCard()
PackedScene.pack 每张卡 → deckSavedCards → Infos.save.decks[path]
    ↓ Infos.savePlayerInfo()
ResourceSaver.save(save, path)

加载时：Infos.loadPlayerInfo(path)
    ↓
加载 player Resource → change_scene → hand_deck.loadCards()
    ↓ deck.loadCards()
从 Infos.save.decks[path] 取 deckSavedCards → 实例化各 PackedScene → add_card
```

---

## 关键设计说明

### 1. 两种牌桌模式

项目存在**两套并行的牌桌系统**：

| 特性 | 旧版 `deck.gd` | 新版 `GridSnapTable` |
|---|---|---|
| 布局方式 | 线性排列（ScrollContainer） | 二维网格锚点 |
| 卡牌定位 | follow_target（背景占位节点） | 直接 BFS 找锚点 |
| 合并方式 | 同名堆叠 + 1/4 偏移异名 | 同名格自动合并，异名 BFS 找空格 |
| 重量系统 | 有（ProgressBar） | 无（空实现） |
| 存读档 | 支持（`saveableDecks` 组） | 不支持（主牌桌不参与存档） |

`card.gd` 通过 `preDeck.has_method("release_card")` 判断当前属于哪种模式。

### 2. 幽灵副本（vfs）机制

拖拽时，原卡保持在原位置（`following`/`dragging`），复制出 `dup` 作为视觉占位：
- `dup.cardCurrentState = vfs` → 不响应任何点击
- 松手后 `dup.queue_free()`
- 防止拖拽时牌桌出现"空洞"

### 3. 防多卡抢占机制

静态变量 `card._current_dragger` 全局唯一，拖拽开始时注册自己，松手时清空。确保同一帧只有一张卡处理松手逻辑（解决 reparent 后 button_up 信号丢失的边缘情况）。

### 4. CardSlot hanging 状态

卡牌放入 CardSlot 时立即切换 `hanging` 状态：
- 阻止 `_on_button_button_up` 末尾的 `following` 覆盖
- reparent 推迟到 `call_deferred`（下一帧），避免在调用栈内修改场景树

### 5. 数据驱动

所有卡牌数据来自 `assets/cardData.json`，通过 `CardInfo` 全局单例读取：
- `cardInfo` 表：卡牌基础数据（class/name/max/weight/price 等）
- `eventInfo` 表：事件数据（title/description/card_1~6/result）
- 支持扩展任意自定义表（`get_table`）

### 6. 存档系统

存档使用 Godot `Resource` 系统（`.tres`）：
- `player` Resource 存玩家状态 + `decks` 字典
- 每个牌桌用节点路径作 key，值为 `deckSavedCards`（PackedScene 数组）
- 注意：GridSnapTable 的主牌桌不参与存档

---

*文档由 AI 分析生成，如有代码更新请同步维护此文档。*
