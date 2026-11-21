# ZIMA 素材署名 / Credits

## 怪物模型

- **PSX Sea Horror Monsters - Free Sampler**（Giant Crab / Drowned Fisherman）
  by bitkiln — https://bitkiln.itch.io/psx-sea-horror-monsters-free-sampler
  授权：免费用于个人与商业项目，可修改；不可转售或作为素材包再分发。
  署名非强制，此处标注：Art by bitkiln。
- 使用文件：`monsters/drowned/`（drowned.tscn、drowned_oilskin.glb、drowned_deckhand.glb 及贴图）、
  `scripts/monster_brain.gd`、`shaders/psx_lit*.gdshader`、`shaders/apply_psx.gd`

## 食物模型

- **PSX Kitchen Props Pack**（披萨一角、吐司）by Nicowlas — 付费素材包
  授权：可用于个人与商业项目、可修改；不可转售、不可再分发原始文件（含修改后的版本）。
  以 `glb/` 里两个模型内嵌贴图的版本接入：`feed/food_models/food_pizza.glb`、`food_toast.glb`
- **PSX Survival Items - Free Sample**（豆子罐头）by Fanix Studio —
  https://fanixstudio.itch.io （免费用于个人与商业项目，可修改；不可转售或再分发素材本身）
  使用文件：`feed/food_models/food_can_beans.glb`

## 钥匙与工具

- **COGITO — Immersive Sim Template for Godot 4** by Phazorknight —
  https://github.com/Phazorknight/Cogito
  授权：MIT。假钥匙的金色造型（BoxMesh 钥匙身 + PrismMesh 齿 + CylinderMesh 柄）
  1:1 复刻自其 `pickup_key.tscn`（几何与材质参数一致），见 `feed/quest_item.gd`。
  插件完整拷贝在 `addons/cogito/`（未启用，按需取用素材）。

## 插件

- **PS1 RPG Menu Kit Free** — PS1 风渐变窗口、菜单列表、对话框（`addons/ps1_rpg_menu`），
  对话气球 `feed/psx_balloon.tscn` 用的就是它的 `dialogue_box` 与 `menu_list`。
  PS1 RPG Menu Kit Free by heyheythere - https://heyheythere.itch.io/ps1-rpg-menu-kit-free - CC BY 4.0
  授权全文见 `addons/ps1_rpg_menu/LICENSE.txt`
- **Footstepper** — 脚步音效节点（`addons/footstepper`）
- **Godot Retro** — CRT 后期 / 抖动（`addons/godot_retro`）
- **Weather FX** — 天气效果（`addons/weather_fx`）
- Button Prompts / Input Helper / Quick Audio（`addons/` 下其余插件）

各插件具体授权见各自目录内的 LICENSE。
