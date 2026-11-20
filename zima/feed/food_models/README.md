# 食物模型（不进仓库）

这里的 `*.glb` 是素材包原件，按授权不能随仓库分发，所以被 `zima/.gitignore` 排除了。
本机要跑起来，把下列文件放进本目录即可，名字不能改（代码里按这些路径 preload / 拖进检查器）。

| 文件 | 内容 | 来源 |
| --- | --- | --- |
| food_pizza.glb | 披萨一角 | PSX Kitchen Props Pack（Nicowlas，付费） |
| food_pizza_full.glb | 完整披萨 | 同上 |
| food_pizza_half.glb | 半块披萨 | 同上 |
| food_pizza_slice_gone.glb | 缺一角的披萨 | 同上 |
| food_pizza_quarter_eaten.glb | 吃掉四分之一的披萨 | 同上 |
| food_toast.glb | 吐司 | 同上 |
| food_toast_burnt.glb | 烤过的吐司 | 同上 |
| food_chocolate.glb | 巧克力（未拆） | 同上 |
| food_chocolate_open.glb | 巧克力（拆开） | 同上 |
| food_can_cola.glb | 可乐罐 | 同上 |
| food_can_fanta.glb | 芬达罐 | 同上 |
| food_can_beer.glb | 啤酒罐 | 同上 |
| food_chips.glb | 薯片盒 | 同上 |
| food_choco_munch.glb | 巧克力盒 A | 同上 |
| food_choco_chumps.glb | 巧克力盒 B | 同上 |
| food_can_beans.glb | 豆子罐头 | PSX Survival Items - Free Sample（Fanix Studio） |

包里的 `fbx/`、`obj/`、`glb/` 三种格式，用的是 glb（贴图内嵌，单文件即插即用）。
替换模型只要把对应的 glb 拖到 `FoodItem` 的 `model_scene` 上，碰撞盒会按包围盒自动重算。

默认模型走的是运行时 `load()`（不是 `preload`），文件名和路径就按上表。真缺文件时脚本只会打一条提示、
退回一个黄色方块占位，不会把工程拖成解析错误。
