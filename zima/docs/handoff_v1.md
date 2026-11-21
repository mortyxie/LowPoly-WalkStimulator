# 美术替换指引 — 喂食系统占位模型（handoff_v1）

> 版本：v2（2026-11-21，新增三轮轮回系统章节；v1 原始内容见下方）
> 本文档写给负责替换占位模型的美术同学，同时记录三轮轮回的验收要点。

---

## 0. 三轮轮回系统（v2 新增，2026-11-21 AI 独立开发）

### 0.1 玩法流程（按终版策划案实现）

| 轮回 | 目标 | 失败条件 | 失败表现 |
|---|---|---|---|
| 1 · 启蒙 | 上交任意一件凶器 + 之后按时喂 2 顿 | 喂食超时 | 【我看到你了】红字闪 0.8s → 黑屏 → 重置轮回 1 |
| 2 · 陷阱 | 破盒（时机条）得假钥匙 → 拿假钥匙开最左边大门 | 时机条按空失败 / 喂食超时 | 同上，重置轮回 2（食物重新随机、盒子复原） |
| 3 · 终局 | 撬锁（COGITO 沉浸式撬锁小游戏）→ 开最左边大门 → 结局演出 | 撬锁失败不会重置（自动换撬锁器可重试）/ 喂食超时 | 喂食超时同上，重置轮回 3 |

- 解锁轮回 2：交凶器 + 喂饱 → 黑屏过场（「看起来他满意了」）。
- 解锁轮回 3：假钥匙开门 = **声响暴露强制剧情**（钥匙消耗、房东暴怒、红字、黑屏）。
- 结局：全屏黑 → 白色细体「欢迎回家」淡入停留 4s → Staff 片尾滚动 → 停在黑屏。
- 已上交的凶器**永久消失**（跨轮回记账）；轮回 2 起右键=藏匿（藏掉的武器不再刷出）。
- 交互键统一为 **F**（interact 动作，physical F）；空格只用于时机条命中。

### 0.2 新文件一览

| 文件 | 职责 |
|---|---|
| `feed/loop_manager.gd` | **LoopManager autoload**：轮次状态、失败重置、解锁、凶器/藏匿记账、喂食压力计时、食物点位池随机刷新、剧情演出编排 |
| `feed/timing_minigame.gd` | 参数化时机条小游戏（轨道/滑块/绿区/周期/命中数/颜色全可配），**破盒用**（撬锁已改为 COGITO 沉浸式小游戏） |
| `feed/loop_ui.gd` | 黑幕、红字警示、欢迎回家、片尾滚动字幕 |
| `feed/glow_highlight.gd` | 剧情道具信标式强闪高亮（自发光脉冲 + 小灯；钥匙金/撬锁器冷青/盒子琥珀/大门幽青） |
| `feed/mystery_box.gd` | 神秘盒子（占位木盒，破盒后掀盖表现） |
| `feed/final_door.gd` | 最左边大门（门板占位 + 按 F 交互区，提示随轮回变化） |
| `feed/quest_item.gd` | 剧情道具（假钥匙=COGITO 金钥匙复刻；撬锁器=细长黑圆柱） |
| `tests/autotest.gd` | 端到端自动测试（`--headless --path . -- --autotest` 跑全流程） |

改动过的旧文件：`food_item.gd`（+model_override_path）、`landlord_npc.gd`（+reset_for_loop / accept_weapons / 通知 LoopManager）、`camera_interact.gd`（+藏匿、+input_locked 门控、+新拾取组、freed 自愈）、`scripts/interactable.gd`（+input_locked 门控、+refresh_prompt）、`zima_demo.tscn`（移除摆死的 FoodItem×3 / Weapon×2，改由 LoopManager 按轮刷新）、`project.godot`（+LoopManager autoload、+COGITO autoload×5、+minigame_hit 空格、interact 改 F 键）。

### 0.3 关键实现位置（策划数值都对得上）

- 破盒：`loop_manager.gd` `BOX_GAME`（绿区 60px / 周期 4.2s / 命中 3 / 滑块 24×12 暗红）。
- 撬锁：**COGITO 沉浸式撬锁小游戏**（`CogitoLockpickMinigame`，鼠标找甜点 + 按住 D 转锁芯 + 撬断自动续 + Esc 退出）。SubViewport 收不到 `_input`，鼠标位移由 LoopManager 从 MouseLook autoload 桥接喂给它，撬锁期间相机视角锁定。难度参数：甜点宽度 12.0 / 耐久 8.0（LoopManager 导出）。策划案的自研时机条参数（绿区 90px / 周期 3.8s / 命中 2）保留在 `LOCKPICK_GAME` 常量中未删。
- 食物点位池：`FOOD_SPOTS`（8 个）+ `FOOD_KINDS`（7 种，按 glb 路径随机换 model_override_path）。
- 喂食压力：`feed_timeout`（默认 45s，喂食阶段没喂就重置当前轮）。
- COGITO autoload 注册（CogitoGlobals / CogitoSceneManager / CogitoQuestManager / MenuTemplateManager / CogitoQuickSlots）是为了让插件脚本在本工程可编译；未启用编辑器插件、未用其玩法代码，仅钥匙造型复刻（见 CREDITS.md）。
- ⚠️ 两个 COGITO 上游小补丁（升级插件时注意被覆盖）：`Components/LootComponent.gd` 补 `return []`；`InventoryPD/CogitoQuickSlots.gd` `_ready` 加空玩家防御。

### 0.4 验收方式（无手操）

```
.tools/Godot_v4.7.2-stable_win64.exe --headless --path zima -- --autotest
```
预期输出 `AUTOTEST ALL PASS`（33 项断言：三轮闭环、失败重置、藏匿、参数校验、结局）。
食物/钥匙/盒子/门/撬锁器全部是运行时代码生成 + 占位网格，等美术按 0.5 节替换。

### 0.5 待美术替换的占位（新增）

| 物件 | 当前占位 | 替换建议 |
|---|---|---|
| 神秘盒子 `feed/mystery_box.gd` | 0.42×0.3×0.32 深色木盒 + 浅色盖缝 | 换正式可破坏盒模型，`break_open()` 换掀盖/碎裂表现 |
| 大门 `feed/final_door.gd` | 1.3×2.25×0.09 深色门板 + 暗金属锁孔块 | 对齐 DoriHome 最左侧门的美术（位置 -8.5,0,-3.0，贴 z≈-3 墙） |
| 假钥匙 / 撬锁器 `feed/quest_item.gd` | COGITO 金钥匙复刻 / 细长黑圆柱 | 钥匙正式模型用户在找；撬锁器可换 CC0 模型 |

### 0.6 整体动线（体验指引，v2.1 新增）

**引导系统**：黑暗房间内所有剧情目标都有**信标式强闪高亮**（0.5s 亮 / 0.3s 灭循环，自发光能量 8.0 + 同步小灯），颜色即导航——

| 颜色 | 目标 | 位置 |
|---|---|---|
| 琥珀色 | 神秘盒子（轮回 2） | 西侧小方桌上（-6.73, 0.5, -6.7） |
| 金色 | 假钥匙（破盒后掉出） | 盒子旁地面 |
| 冷青色 | 撬锁器（轮回 3） | 大门附近地板 |
| 幽青色 | 最终大门（灯挂在门把手高度 1.2m） | z≈-3 墙最左（-8.5, 0, -3.0）；**不是**客厅里穿模的那扇传送门（x≈-4.5） |

**快速体验**（跳过轮回 1，喂食压力放宽到 5 分钟）：

```
.tools/Godot_v4.7.2-stable_win64.exe --path zima -- --loop2   # 直接进轮回2，出生在盒子旁
.tools/Godot_v4.7.2-stable_win64.exe --path zima -- --loop3   # 直接进轮回3，出生在大门口
```

**完整动线**：

```
轮回 1「启蒙」
  出生点 → 找食物（左键拿/左键交房东，喂食阶段 45s 内要喂）
  → 拾取刀或斧 → 交给房东（凶器永久消失）
  → 再按时喂 2 顿 → 黑屏过场 → 轮回 2
  ✗ 超时没喂 → 红字【我看到你了】0.8s → 黑屏 → 只重置轮回 1

轮回 2「陷阱」
  琥珀光神秘盒子（西侧小方桌）→ 按 F 破盒
  → 空格打时机条（暗红滑块命中绿区 3 次；按空失败 = 红字黑屏重置轮回 2）
  → 金色假钥匙掉出 → 左键拾取 → 幽青大门按 F
  → 「咔哒」锁开 → 巨响暴露（强制剧情：钥匙消耗、红字、黑屏）→ 轮回 3

轮回 3「终局」
  刀斧全清空；大门附近冷青色撬锁器 → 左键拾取 → 大门按 F
  → 第一人称撬锁：鼠标左右移撬杆找「甜点」→ 按住 D 转锁芯
    （越准转得越深；不对位硬转磨撬锁耐久，撬断自动换新不扣道具；Esc 退出可再按 F 重试）
  → 解锁成功 → 黑屏 → 白色细体「欢迎回家」淡入 4s → Staff 片尾 → 通关
```

**通用操作**：F = 交互/查看/开门；鼠标左键 = 拾取/交付；右键 = 吃食物（轮回 2 起手持武器时 = 藏匿）；空格 = 时机条命中；D = 撬锁转锁芯；Esc = 退出撬锁。

---

## 1. 涉及文件

| 文件 | 用途 | 占位外观 |
|---|---|---|
| `feed/food_item.tscn` | 食物道具场景（可直接拖进任意关卡摆放） | 0.45m 金黄色方块 |
| `feed/landlord_npc.tscn` | 房东 NPC 场景（可直接拖进任意关卡摆放） | 0.8×2.05×0.5 暗红色立柱（顶部与相机视线齐平） |
| `feed/food_item.gd` | 食物逻辑脚本（拿起/吃掉） | — |
| `feed/landlord_npc.gd` | 房东逻辑脚本（靠近交付/喊话） | — |
| `feed/near_prompt.gd` | 靠近提示 UI（autoload：NearPrompt，屏幕底部持续显示） | — |
| `camera_interact.gd`（项目根） | 鼠标视角 + 交互中枢：E 交互、右键吃掉、视角捕获 | — |

## 2. 替换食物模型步骤

1. 把正式食物模型（`.glb` 推荐）拖进 Godot，放到例如 `models/food/` 目录。
2. 打开 `feed/food_item.tscn`：
   - **保留**根节点 `FoodItem`（RigidBody3D + 脚本）和 `CollisionShape3D`；
   - 把根节点下的 `MeshInstance3D`（占位方块）删掉，改为实例化/拖入你的 glb 场景作为子节点（或者直接把 glb 里的 MeshInstance3D 拖成根节点子级）；
   - 调整模型位置让底部对齐根节点原点（即模型"脚底"在 y=0）。
3. 按模型实际大小调整 `CollisionShape3D` 的 BoxShape3D 尺寸。
4. 手持姿态：`feed/food_item.gd` 里的 `HAND_OFFSET` 常量控制拿在手上时相对相机的偏移（右0.38 / 下0.38 / 前0.8），如模型尺寸差异大可按需调整。
5. 每个食物场景自带 `PickupZone`（Area3D 球形感应，半径 1.6m）：玩家靠近时底部显示「[鼠标左键] 拾取食物」。换模型后按体型调整该感应半径即可。

## 3. 替换房东 NPC 模型步骤

1. 把正式模型放进 `models/npc/`（带骨骼动画的 glb 亦可）。
2. 打开 `feed/landlord_npc.tscn`：
   - **保留**根节点 `LandlordNPC`（StaticBody3D + 脚本）和 `CollisionShape3D`；
   - 删除占位 `MeshInstance3D`，挂入你的模型节点；如果换 CharacterBody/动画树结构，**务必保留 `landlord_npc.gd` 挂在根节点上**，交互依赖它的 `shout()` / `interact()` 方法。
3. 碰撞盒按模型体型调整（当前 0.8×2.05×0.5，占位柱顶部与相机视线高度齐平）。
4. 场景里自带 `PickupZone`（Area3D 球形感应，半径 2.0m）：玩家**手持食物**靠近时底部显示「[鼠标左键] 交给房东」，左键交付。

## 4. 文案配置位置（策划也可改）

全部在 Godot 编辑器的 Inspector 里改，不用动代码：

- 食物名字：`food_item.tscn` 根节点 → `item_name`
- 吃掉后浮现文字：根节点 → `consume_text`
- 房东名字：`landlord_npc.tscn` 根节点 → `display_name`
- 房东台词池（超时威胁时随机抽一条）：根节点 → `shout_lines`

## 5.5 交互架构说明（v2 更新）

- **左键输入统一仲裁**：拾取与「交给房东」的判定全部收口在 `camera_interact.gd`，一次点击最多执行一个动作，优先级：交付 > 拾取。食物/房东脚本不做任何按键轮询，只暴露 `is_player_near()` 与动作接口，感应区重叠也不会再串。
- **可拾取白名单**：只有 `feed_food` 组的节点能被拾取（`food_item.tscn` 自动入组）；房东在 `feed_landlord` 组，永远不会被拿起。
- **颜色区分**：房东占位柱为紫色，食物为金黄色。

## 5. 交互操作（验收用）

- **鼠标移动**：控制视角（点击窗口捕获鼠标，ESC 释放，再点击重新捕获）
- **靠近食物** → 屏幕底部出现「[鼠标左键] 拾取食物」→ 左键拿起，物品挂到相机变第一人称手持
- **手持中右键** → 自己吃掉，屏幕中上方浮现金色文字
- **手持中靠近房东** → 底部出现「[鼠标左键] 交给房东」→ 左键交付，房东台词浮现
- **准星对准房东按 E** → 房东随机喊一句（红色大字浮现后淡出）

## 6. 注意事项

- 项目启动时 `main.gd` 会把 3D 世界材质统一转成 PSX 风格，新导入的模型也会被自动转换，无需特殊处理。
- 食物是 RigidBody3D（有物理会掉落），若希望食物悬空摆放不倒，可在 Inspector 把 `freeze` 勾上。
- 场景摆放只需拖动 `food_item.tscn` / `landlord_npc.tscn` 实例位置，无需其他配置。

---

## 6. 版本合并记录（2026-11-20）

本地工作与远端仓库 `mortyxie/LowPoly-WalkStimulator`（main，此前推进到 `c437829`）完成了首次合并并推送（merge commit `342aab8`）。处理方式：

| 冲突文件 | 处理 | 说明 |
|---|---|---|
| `.gitignore` | 双方保留 | 远端原有 Godot 忽略规则 + 本地新增 `.workbuddy/` |
| `zima/project.godot` | 取本地 | 本地多出 `MessageBanner`/`NearPrompt` autoload 与 `consume`/`pickup` 输入动作；远端为旧基线 |
| `zima/camera_interact.gd` | 取本地 | 远端仍是旧版（含 interact 双调用 bug、无鼠标视角）；本地为重构后的视角+交互中枢 |
| `zima/addons/.../player.gd` | 取本地 | 远端的「镜头跟随鼠标」实现在 player 内转视角，与本地相机自持视角架构冲突（会双重旋转），统一用本地架构 |
| `zima/ENV/interactable.gd` | 取本地 | 本地把提示改为屏幕横幅 |
| `zima/zima_demo.tscn` | 取本地 | 差异仅为本地喂食系统（食物×3、房东、PSX SubViewport stretch 设置），远端无独有节点 |

⚠️ 需要注意：
- 远端最后一条提交写着「增加开关门挂点【但没弄完】」，但对比发现 `zima_demo.tscn` 远端版本中**并没有**独有节点——开关门挂点可能放在其他场景或尚未提交。如果美术/关卡同学有这部分未推送的工作，需要另行同步。
- 远端的雾效/后处理调整（`552e1a3`）在主场景中与本地一致，无丢失。
