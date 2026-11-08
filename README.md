# pvz_warG

Godot 4.7.1 游戏项目。用 Godot 打开根目录的 `project.godot`，按 F6 运行当前场景，按 F5 从主菜单启动项目。

## 文件分类

| 目录 | 放置内容 | 维护规则 |
|---|---|---|
| `assets/textures/` | 图片、角色帧、地图图片、UI 贴图、图标 | 按 `plants`、`zombies`、`levels`、`ui`、`objects`、`projectiles` 分功能 |
| `assets/audio/` | 音乐、角色音效、环境音、UI 音效 | 角色和关卡专用声音放对应功能目录；公共音效在 `general_music` 等历史素材分组 |
| `assets/fonts/` | 游戏运行时字体 | 保留字体授权信息，导入配置随字体维护 |
| `assets/shaders/` | `.gdshader` 着色器 | 按使用场景分组，`.uid` 随文件保留 |
| `src/autoload/` | 六个实际注册的全局脚本 | 在 Project Settings → Autoload 注册，保持现有单例名称 |
| `src/core/` | 状态机、角色和属性等基础代码 | 被多个功能共用的基础类 |
| `src/resources/` | 自定义 Resource 脚本 | 例如 `level_resource.gd` 定义关卡数据结构 |
| `src/levels/` | 关卡、波次、选关与关卡音乐代码 | 子目录对应场景所在功能目录 |
| `src/plants/`、`src/zombies/` | 角色逻辑和状态代码 | 按区域、角色、行为细分 |
| `src/projectiles/`、`src/objects/` | 子弹、近战判定、道具、掉落等代码 | 与对应场景保持相同的功能分类 |
| `src/ui/` | 界面交互逻辑 | 菜单、选卡、设置、血条等 |
| `src/special/` | 阳光集合、僵尸环境音等辅助行为 | 新功能优先放所属功能目录 |
| `scenes/` | `.tscn` 场景 | 分类为 `levels`、`plants`、`zombies`、`projectiles`、`objects`、`ui` 和 `components` |
| `resources/` | 可复用 `.tres` 配置 | `audio/default_bus_layout.tres` 是运行时音频总线 |
| `docs/` | 计划、维护规范、报告与历史记录 | 不放运行时依赖的文件 |
| `tests/` | 流程和资源回归测试 | 从命令行显式运行，不混入游戏场景列表 |
| `tools/` | 检查工具、辅助脚本 | `logs/` 是自动生成的本机测试输出 |

项目根目录只保留项目配置、README、忽略规则和这些分类目录。`.godot/` 是引擎生成的缓存，可重建，不应作为源文件管理。

## 命名与新增文件

- 新建文件和目录使用英文 `snake_case`，例如 `src/plants/front_yard/new_plant/attack.gd`。
- 同一功能在 `assets/`、`src/`、`scenes/` 中采用相同的分类路径，避免出现 `plant/plants` 或 `UI/UI` 这样的分叉。
- 角色场景放 `scenes/plants/...`，行为脚本放 `src/plants/...`，图片放 `assets/textures/plants/...`，声音放 `assets/audio/plants/...`。
- 图片、音频的现有原文件名（含中文和素材来源标识）本次保留，新增素材采用有含义的英文名称。
- 实际注册的单例脚本放 `src/autoload/`；普通基础类放 `src/core/`，避免将所有共享脚本称为 Autoload。
- PSD、音频工程、Blender 工程等制作源文件建议放项目外独立素材目录或仓库；导出的运行素材进入本项目 `assets/`。
- 构建产物放 `build/` 或 `exports/`，不要把导出的游戏程序与源项目混放。

## 移动资源的规则

优先在 Godot 的 FileSystem 面板中移动资源，让编辑器更新依赖。移动脚本或着色器时保留 `.uid` 文件，移动图片、字体和音频时保留 `.import` 文件。

Godot 不一定会更新代码中的字符串、运行时拼接的路径或 `user://` 存档中的路径。移动后必须执行引用检查及引擎流程测试。入口场景、字体、图标、音频总线和 Autoload 在 `project.godot` 中使用明确路径；场景内部仍保留原 UID。

将来若再移动 `src/ui/music/music_setting.gd`，需要同时维护 `src/autoload/settings.gd` 中的存档兼容迁移，因为旧版 `.tres` 音量存档记录了这个脚本的位置。本次已备份旧存档并保留音量。

## 启动与测试

在项目根目录执行，按本机实际位置指定 Godot 和 Python：

```powershell
# 正常启动游戏
& '../Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe' --path .

# 检查迁移文件、资源路径、UID、原素材完整性
python tools/verify_references.py

# 编辑器导入、静态检查、主菜单启动、四关完整启动流程
./tools/verify_project.ps1 -GodotPath '../Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe' -PythonPath 'python'

# 使用真实图形设备复测，并保存主菜单、第一关战斗截图
& '../Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe' --path . --resolution 960x540 --scene res://tests/project_smoke.tscn -- --capture
```

验证工具遇到资源错误、脚本错误、警告或非零退出码会判为失败。测试输出在 `tools/logs/`，不进入版本管理。测试用例以 8 倍游戏时间缩短等待，通过实际界面处理函数执行选关、选卡、取消重选、战斗、暂停和返回菜单；不替代完整通关或游戏平衡性测试。

`verify_references.py` 中对原始文件的哈希检查用于确保本次迁移没有改变素材；将来有意修改原素材或删除旧文件时，应在评审中更新这份迁移验收基线。

## 本次迁移记录

- 计划：`docs/superpowers/plans/2026-10-30-project-layout.md`
- 逐文件清单、原始哈希与 UID：`docs/maintenance/migration_manifest.json`
- 验证结果：`docs/maintenance/validation_report.md`
- 原始备份：项目外 `../_project_backups/pvz_warG_20261030/before_restructure.zip`
- 回退时解压到新目录，不要覆盖混合两套目录结构。

项目目前没有 Git 仓库。已提供 `.gitignore`；建立版本管理后，应提交源码、场景、原素材、`.uid`、`.import` 和文档，忽略缓存、测试日志与导出包。

## 许可

本项目采用 **Apache License 2.0**，完整条款见根目录的 `LICENSE`。

- 允许商业使用、修改、再分发
- 分发时需保留版权与许可声明，修改过的文件需注明改动
- 附带专利授权条款；同时不提供任何担保

版权声明：`Copyright 2026 lefengyao`

游戏内「开源声明」弹层同步写明了许可证与源码仓库地址，位置在 `src/levels/general/chose_map.gd` 的 `_on_license_pressed()`。
