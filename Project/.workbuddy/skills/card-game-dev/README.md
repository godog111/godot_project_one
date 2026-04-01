# 卡牌游戏开发Skill

这是一个专为Godot卡牌游戏开发的WorkBuddy Skill，提供了一套完整的工具和知识库，帮助快速构建高质量的卡牌游戏。

## 安装和使用

### 1. 安装Skill
将此文件夹复制到以下位置之一：
- **用户Skill**：`~/.workbuddy/skills/card-game-dev/`（跨所有项目可用）
- **项目Skill**：`.workbuddy/skills/card-game-dev/`（项目内共享）

### 2. 激活Skill
当WorkBuddy检测到卡牌游戏开发任务时，会自动加载此Skill。你不需要手动激活。

## 包含的内容

### 📁 scripts/
- `generate_stacking_system.py` - 卡牌堆叠系统生成器
- `generate_transform_system.py` - 卡牌变换系统生成器（待添加）
- `generate_boundary_system.py` - 边界管理系统生成器（待添加）

### 📁 references/
- `card_stacking_guide.md` - 卡牌堆叠开发完整指南
- `transform_guide.md` - 卡牌变换开发指南（待添加）
- `boundary_guide.md` - 边界管理开发指南（待添加）

### 📁 assets/
- `card_stacking_example.tscn` - 堆叠系统示例场景（待添加）
- `boundary_example.gd` - 边界系统示例脚本（待添加）

## 使用案例

### 案例1：添加卡牌堆叠功能
```
用户：我想在我的卡牌游戏中添加堆叠功能
WorkBuddy：加载card-game-dev skill → 分析现有代码 → 生成堆叠系统 → 提供集成指南
```

### 案例2：实现卡牌旋转
```
用户：需要让卡牌可以旋转和缩放
WorkBuddy：加载skill → 生成变换系统代码 → 提供多设备输入处理方案
```

### 案例3：添加游戏区域限制
```
用户：需要限制卡牌只能在游戏区域内移动
WorkBuddy：加载skill → 生成边界管理系统 → 提供弹性边界实现
```

## 开发路线图

### 已完成
- [x] Skill基础结构
- [x] 卡牌堆叠系统生成器
- [x] 堆叠开发指南

### 计划中
- [ ] 卡牌变换系统
- [ ] 边界管理系统
- [ ] 状态保存系统
- [ ] 性能优化工具
- [ ] 测试框架集成

### 未来功能
- [ ] 卡牌特效系统
- [ ] 网络对战功能
- [ ] AI对手系统
- [ ] 卡牌编辑器工具

## 贡献指南

如果你想为此Skill贡献代码：

1. Fork此项目
2. 创建功能分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 打开Pull Request

## 许可证

本项目采用MIT许可证 - 查看LICENSE文件了解详情

## 支持

如果你遇到问题或有建议：
1. 查看 `references/` 目录中的指南
2. 检查现有实现示例
3. 提交Issue到项目仓库

---

**注意**：这是一个持续开发的项目，功能会不断更新和完善。建议定期更新以获取最新功能和改进。