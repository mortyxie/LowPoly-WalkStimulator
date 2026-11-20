# 美术替换指引 — 喂食系统占位模型（handoff_v1）

> 版本：v1（2026-11-20）
> 本文档写给负责替换占位模型的美术同学。当前所有「喂食系统」相关物件都是**长方体占位**，功能逻辑已就绪，只需替换视觉模型。

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
