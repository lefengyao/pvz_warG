# AGENTS.md

本文件适用于整合后的项目根目录。引擎为 Godot 4.7.1，配置为根目录的 `project.godot`。

## 项目结构与运行

- `2d/`：2D 玩法、场景、素材和专用配置；F5 启动 `2d/scenes/levels/chose_map.tscn`。
- `3d/`：前院、模型、卡牌预览和专用管理器；F6 运行 `3d/scenes/maps/front_yard/FrontYard.tscn` 或 `EcsFrontYardDemo.tscn`。
- `shared/`：公共音频、字体、状态机、角色基础属性、事件、设置和转场。
- `addons/` 保留根目录；`tests/`、`tools/`、`docs/`、`specs/` 按职责独立维护。
- 两种状态机保留各自类型和 API；共享目录不意味着可以互相替换。

## 工作流程

1. 先执行 `git status --short`，保留已有改动。用 `rg` 定位脚本、场景、资源和调用方。
2. 优先局部修改，保留节点、公开变量、信号、UID 和资源接口。用 `apply_patch` 手工编辑。
3. 场景与 UI 按布局、导航、内容、窗口控制、数据展示职责模块化；关键模块名使用 PascalCase 语义名称。
4. 修改层级或命名时同步检查脚本路径、场景连接、公开变量和外部调用方。
5. 查看差异后运行对应验证；汇报修改文件、验证结果和未验证部分。

## Godot 约定与职责

- 使用 Godot 4 GDScript 和现有类型标注；`@tool` 同时考虑编辑器与运行时。
- 不用局部变量遮蔽基类属性，不随意添加 `@warning_ignore`；整数索引除法显式表达意图。
- 前院全局输入统一由 `FrontYard/Manager/PlantLogic` 处理，地图、草坪和 UI 不重复监听同类输入。
- 3D 新管理器放 `3d/src/managers/`；2D 专用管理器放 `2d/src/` 对应职责目录。
- 前院 `Manager` 下 PlantLogic、Plant、Zombie、LevelLogic、Music 保留职责边界；跨系统调用优先使用方法或信号。
- 草坪底板是 `Background/Grass/Board/BoardBase`；草叶由 LawnGrid/LawnCell 和 `lawn_cell_grass.gdshader` 负责。
- 草坪、着色器、光照、阴影和 AABB 改动必须做真实图形运行验证。
- 单例注册以 `project.godot` 为准。只有一个 Audiomanager；`Settings.ingameset` 是 2D 暂停接口，3D 设置使用共享场景实例。
- 移动资源须同步更新 `project.godot`、场景、preload/load、动态拼接路径及存档迁移。保留 `.uid` 和 `.import` 源元数据。

## 验证

```powershell
godot --headless --editor --path . --quit
python tools/verify_references.py
python tests/integration_layout_test.py
& './tests/3d/front_yard/front_yard_background_structure_contract_test.ps1'
& './tests/3d/front_yard/front_yard_cell_bounds_contract_test.ps1'
./tools/verify_integration.ps1 -GodotPath '<Godot executable>' -PythonPath '<Python executable>'
```

图形验证在完整验证命令后添加 `-Capture`。Godot 不在 PATH 时使用本机 4.7.1 可执行文件；安装位置见 README 的示例。

## 文件与 Git

- 不覆盖、重置或清理用户已有改动，不使用 `git reset --hard`、`git checkout --`。
- 不主动提交、推送、改发布配置或重写历史；提交前报告具体文件，仅暂存任务相关路径。
- `.godot/`、测试日志及本机 MCP 桥接不作为源码提交；ECSmini 和像素过滤插件属于项目源码。
- `.gitignore` 仅作用于未跟踪文件，用 `git check-ignore -v` 核实范围；已跟踪文件需单独检查。
- 若用户明确要求停止跟踪 PowerShell 脚本，先用 `git ls-files -- '*.ps1'` 检查，再用 `git rm --cached -- '*.ps1'` 并确认本地文件保留。清理远程历史需单独明确授权。
- 整合清单和素材哈希在 `docs/maintenance/`；有意改素材时需更新验收基线。原项目及重复内容已归档到项目外备份，详情见 README。
