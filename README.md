# pvz_warG

**植物大战僵尸同人塔防 · Godot 4.7.1 · 2D 与 3D 合体**

2D 主线、3D 前院和公共模块已经合并成**同一个 Godot 工程**：一个仓库、一份 `project.godot`、一条主场景。按 **F5** 直接玩 2D 主线；在编辑器里打开 3D 场景按 **F6** 就能走进前院，两者共用同一套音频、事件、设置和转场。

| 主菜单 · 拼图选关 | 前院战斗 |
| :---: | :---: |
| ![](docs/maintenance/screenshots/main_menu.png) | ![](docs/maintenance/screenshots/first_level_battle.png) |
| 作者 / 查看 / 设置，三张地图以拼图卡片呈现 | 卡槽、阳光、波次进度与车道末端的装甲车 |

## 技术栈

| 项 | 值 |
| --- | --- |
| 引擎 | Godot **4.7.1**（`config_version=5`） |
| 渲染 / 物理 | Forward Plus（Windows 走 D3D12）· Jolt Physics |
| 语言 | GDScript，无 C# |
| 画面 | 1920 × 1080，`viewport` 拉伸 |
| 主场景 | `2d/scenes/levels/chose_map.tscn` |
| 仓库 | <https://github.com/lefengyao/pvz_warG> |
| 插件 | ECSmini（ECS 运行时）、Pixel Art Filter |
| 许可 | Apache-2.0 |

## 快速开始

1. 用 Godot 4.7.1 打开本目录（`project.godot` 在根目录），等首次导入完成。
2. 按 **F5** 运行主场景：主菜单 → 闯关 → 选地图 → 选关 → 选卡 → 战斗。
3. 想直接看 3D，按 **F6** 运行下表中的场景。

| 入口 | 场景 | 说明 |
| --- | --- | --- |
| 2D 主线（F5） | `2d/scenes/levels/chose_map.tscn` | 主菜单、拼图选关、选卡、战斗、结算 |
| 3D 前院 | `3d/scenes/maps/front_yard/FrontYard.tscn` | 3D 草坪、草叶着色器、方向光与阴影、车道网格 |
| ECS 前院 | `3d/scenes/maps/front_yard/EcsFrontYardDemo.tscn` | 用 ECSmini 驱动前院逻辑的实验场景 |
| 卡牌盒 | `3d/scenes/cards_box/CardsBox.tscn` | 3D 卡牌展示 |
| 沙盒 | `3d/scenes/sandbox/test.tscn` | 临时试验场 |

> Godot 不在 PATH 时用完整路径启动，例如：`& 'E:/生产项目/项目/Godot/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64.exe' --path .`

## 内容一览

### 植物（13 株）

每株一个独立场景，位于 `2d/scenes/plants/front_yard/<name>/`：

- 射手线：豌豆射手 `pean_shooter`、双发射手 `pea_repeater`、寒冰射手 `ice_shooter`、激光豆 `laser_bean`、魔炮 `magic_pea`
- 经济与肉盾：向日葵 `sun_flower`、坚果 `nut`
- 一次性与陷阱：樱桃炸弹 `cherry_bomb`、土豆雷 `potato_mine`、倭瓜 `squash`
- 近战与地面：菜问 `caiwen`、地刺 `spikeweed`、悟空 `wukong`（带武器子场景）

### 僵尸（7 种）

位于 `2d/scenes/zombies/front_yard/`，出场由 `2d/scenes/zombies/zombie_spawner.tscn` 统一调度：

- 普通僵尸 `ordinary_zombie`、路障僵尸 `conehead_zombie`、铁桶僵尸 `buckthead_zombie`
- 手枪僵尸 `pistol_zombie`、撑杆跳僵尸 `pole_vaulting_zombie`、刺客僵尸 `assassin_zombie`、魏龙 `weilong`
- 若干可掉落的部件场景（`loot_head`、`loot_pisol_zombie`、`pole`、`c4` 等）

### 关卡、地图与界面

| 类别 | 内容 |
| --- | --- |
| 关卡 | 4 关，`2d/scenes/levels/front_yard/level_logic/level_logic1..4.tscn`；关卡壳为 `level/level1.tscn` 与 `level/normal_front_yard_level.tscn` |
| 地图 | 前院 `courtyard.tres`、森林 `forest.tres`、黑夜 `deep_woods.tres`（沙滩贴图与着色器已在 `2d/assets` 中） |
| 界面 | 主菜单/选关 `chose_map`、地图卡片 `map_card`、选卡 `slot/card_selection`、全部卡牌 `slot/ui_all_cards`、波次进度 `slot/progress_bar`、暂停设置 `in_game_setting` |
| 系统 | 阳光收集、卡槽冷却、车道末端装甲车兜底、波次推进、铲子移除、黑场转场 |

## 目录结构

```text
pvz_warG/
├─ project.godot          引擎、Autoload、渲染与输入配置
├─ 2d/                    2D 主线
│  ├─ scenes/             关卡、植物、僵尸、UI、卡片
│  ├─ src/                玩法脚本：autoload、plants、zombies、projectiles、levels、special、ui
│  ├─ assets/             贴图、音频、着色器
│  └─ resources/          地图、关卡与数值资源
├─ 3d/                    3D 前院与卡牌
│  ├─ scenes/             FrontYard、ECS 演示、草坪、卡牌盒、僵尸模型
│  ├─ src/managers/       EcsFrontYardDemo.gd、PlantLogic.gd
│  └─ assets/             模型、材质、着色器
├─ shared/                跨 2D/3D 复用
│  ├─ src/                音频、事件总线、角色基类、两套状态机、场景转场
│  ├─ scenes/             设置面板、音频滑块、淡入淡出
│  └─ assets/             字体与公共音频
├─ addons/                ECSmini、Pixel Art Filter（Godot 插件必须留在根目录）
├─ specs/                 组件与实体规格
├─ docs/                  设计、执行计划、验收报告、素材清单、截图
├─ tests/                 2D 流程、3D 契约、共享组件回归
└─ tools/                 迁移与一键验证脚本
```

## 架构要点

### 单例（以 `project.godot` 为准，共 8 个）

| 名称 | 来源 | 职责 |
| --- | --- | --- |
| `Audiomanager` | `shared/src/audio/audiomanager.gd` | 音频总线（MASTER / MUSIC / SFX）与播放 |
| `Globalmanager` | `2d/src/autoload/globalmanager.gd` | 运行时容器引用（plants / zombies / bullets / suns / lawnmowers）与点击音效 |
| `GenerateCards` | `2d/src/autoload/generate_cards.gd` | 植物名 → 场景路径的映射与卡牌生成 |
| `GameProgressBus` | `2d/src/autoload/game_progress_bus.gd` | 关卡阶段信号（备战、选卡等） |
| `EventBus` | `shared/src/events/event_bus.gd` | 跨系统事件订阅与派发 |
| `Settings` | `2d/scenes/ui/settings.tscn` | 设置面板，`Settings.ingameset` 是 2D 暂停接口 |
| `ScreenFade` | `shared/scenes/ui/screen_fade.tscn` | 黑场过渡层 |
| `SceneTransition` | `shared/src/ui/scene_transition.gd` | 场景切换与镜头过渡的统一入口 |

### 两套状态机并存，不要混用

`shared/src/state_machine/` 里有两套实现：`StateBase` / `StateMachineManager` 与 `state_base` / `state_machine`。它们的 API 不通用，各自服务原来的调用方；新增代码请沿用所接入的那一套。

### 输入与职责边界

- 前院的全局输入统一从 `FrontYard/Manager/PlantLogic` 进入，地图、草坪和 UI 不重复监听同类输入。
- `Manager` 下 PlantLogic、Plant、Zombie、LevelLogic、Music 各管一摊，跨系统调用优先走方法或信号。
- 3D 新管理器放 `3d/src/managers/`，2D 专用管理器放 `2d/src/` 对应职责目录。

### 3D 草坪

草坪底板是 `Background/Grass/Board/BoardBase`；草叶由 `LawnGrid` / `LawnCell` 分块渲染（`LawnRenderChunk` 做批次），叶片形变走 `lawn_cell_grass.gdshader`。草坪、着色器、光照、阴影或 AABB 改动必须做真实图形运行验证，不能只看 headless。

### 资源与 UID

移动资源要同步更新 `project.godot`、场景引用、`preload/load`、动态拼接路径和存档迁移，并保留 `.uid` / `.import` 源元数据。资源链接与 UID 由 `tools/verify_references.py` 静态校验。

## 开发与验证

```powershell
# 1. 严格导入（无资源/脚本报错）
godot --headless --editor --path . --quit

# 2. 静态引用与项目结构
python tools/verify_references.py
python tests/integration_layout_test.py

# 3. 前院结构契约
& './tests/3d/front_yard/front_yard_background_structure_contract_test.ps1'
& './tests/3d/front_yard/front_yard_cell_bounds_contract_test.ps1'

# 4. 一键整合验证（加 -Capture 出图形截图）
./tools/verify_integration.ps1 -GodotPath '<godot.exe>' -PythonPath '<python.exe>'
```

最近一次完整验证（详见 [验收报告](docs/maintenance/integration_validation_report.md)）：

| 检查 | 结果 |
| --- | --- |
| 严格导入 + 主场景 | 通过，无资源与脚本报错 |
| 静态引用 | 795 条资源链接、531 个 UID，无错误 |
| 2D 流程 | 717 项检查，4 关全部进入战斗 |
| 2D 真实渲染 | 721 项检查（含截图） |
| 前院契约 | 14 项契约全部通过 |
| 草叶运行时 | 6 个 chunk、1756 个实例 |
| ECSmini | 11 个脚本 + 24 组配置通过 |
| 整合结论 | `PASS: integration (14 FrontYard contracts)` |

这些检查覆盖加载、场景接口、启动战斗、输入路由与视觉；**不**覆盖完整通关、数值平衡、导出构建、其它平台和长时间性能。

## 整合记录

- 2026-11-13 把 2D 与 3D 两个工程合并进单一仓库：设计见 [整合设计](docs/superpowers/specs/2026-11-13-2d-3d-project-integration-design.md)，执行见 [整合计划](docs/superpowers/plans/2026-11-13-2d-3d-integration.md)，结果见 [验收报告](docs/maintenance/integration_validation_report.md)。
- 搬迁清单与素材哈希：`docs/maintenance/integration_manifest.json`。
- 合并前的完整工程与旧目录归档在项目外：`../_project_backups/pvz_warG_before_integration_20261113_164917/`。

## 许可与致谢

- 代码以 **Apache License 2.0** 开源，全文见 [LICENSE](LICENSE)，© 2026 lefengyao。
- 游戏内「开源声明」与「创作者名单」两个入口在 `2d/src/levels/general/chose_map.gd`。
- 作者：恋梓里 <https://space.bilibili.com/1986364363>；美术：石英suartz <https://space.bilibili.com/169529553>。
- 美术、音乐与音效部分来自《植物大战僵尸》原作与网络素材（爱给网、耳聆网等），版权归各自作者所有；Apache-2.0 仅覆盖本项目代码。
