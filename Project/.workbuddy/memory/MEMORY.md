# 项目长期记忆

## 项目概述
- **项目类型**：Godot 4 卡牌游戏
- **工作区**：`h:/Users/Administrator/Documents/Project`

## Card 模块文档
- 完整文档路径：`h:/Users/Administrator/Documents/Project/CARD_MODULE_DOC.md`
- 生成时间：2026-03-26
- 覆盖范围：cards/、deck/、event/、data/、assets/ 全部卡牌相关脚本

## 架构摘要

### 卡牌继承体系
- `card`（基类）→ npcCard / shopCard（→shopItemCard）/ siteCard
- `GridSnapTable`（新版网格牌桌）→ CardTableMain（主牌桌）
- `deck.gd`（旧版传统牌桌）→ changeable_deck / hand_deck / shop_card_deck

### 全局单例
| 名称 | 文件 | 职责 |
|---|---|---|
| Infos | infos.gd | 存档系统 + 统一创卡入口 add_new_card |
| CardInfo | assets/cardInfo.gd | JSON 卡牌数据加载 |
| NpcManager | npc_manager.gd | NPC 对话管理 |
| VfSlayer | （节点） | 拖拽浮层容器 |

### 关键设计
1. **两种牌桌模式并行**：card.gd 通过 `preDeck.has_method("release_card")` 区分
2. **幽灵副本机制**：拖拽时复制 dup (vfs 状态) 作视觉占位
3. **防多卡抢占**：静态变量 `_current_dragger` 全局唯一
4. **CardSlot hanging 状态**：放入即锁，reparent deferred 执行
5. **数据驱动**：全部卡牌数据来自 `assets/cardData.json`
