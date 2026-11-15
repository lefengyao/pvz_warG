# ECSmini 0.3 开发交接

交接时间：2026-10-01 20:58，Asia/Shanghai。本文记录 ECSmini 0.3 更新后的实际工作区状态，供下一位开发者或智能体继续开发。

**当前状态：ECSmini 0.3 核心、主要扩展、模拟推进边界和高级实验场景已实现。批量计算采用纯 GDScript 的 serial、parallel、auto 模式。版本号为 0.3.0，工作区仍有未提交改动，不代表已经发布。**

## 1. 用户目标与授权

用户希望把自制 ECS 插件发展为能力更完整、技术架构更强的 ECS，并明确授权破坏兼容性：游戏主体尚未接入插件，可以调整旧接口，不必为了兼容牺牲新内核设计。

本轮范围是可替换存储、Archetype/Chunk、批量计算、独立线程任务、增量查询、变化追踪、依赖调度、模板、事件、关系、索引、快照、回放、纠正输入回滚和调试能力。植物、僵尸、战斗、波次规则仍属于游戏侧，插件不直接承担这些玩法。

用户要求更新 ECS 插件并继续已有交接工作。本轮完成 P1 边界修复、高级实验场景和 P2 回放副作用约定。没有暂存、提交、推送或修改发布配置。

## 2. 工作环境

| 项目 | 当前值 |
| --- | --- |
| 工作区 | `E:\生产项目\项目\GodotProject\pvz_warG\pvz_warG` |
| 引擎 | Godot 4.7.1 stable，项目约定为 Godot 4.7 |
| 分支 / 当前提交 | `main` / `bf5de34`，本轮更改均在工作区 |
| Godot Console | `E:\生产项目\项目\Godot\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe` |
| 可用 Python | `C:\Users\15610\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe` |
| 测量机器 | Intel Core i7-14650HX，24 个逻辑处理器 |

本机 PATH 中的 Python 可能只是 Microsoft Store 占位程序，验证时使用上面的实际解释器。项目未配置完整主场景，查看原 FrontYard 时打开场景并用 F6 运行。

## 3. 阅读入口与源码地图

先读 [README](/E:/生产项目/项目/GodotProject/pvz_warG/pvz_warG/addons/ecsmini/README.md)、[数据扩展说明](/E:/生产项目/项目/GodotProject/pvz_warG/pvz_warG/addons/ecsmini/EXTENSIONS.md)、[存储与计算说明](/E:/生产项目/项目/GodotProject/pvz_warG/pvz_warG/addons/ecsmini/COMPUTE.md) 和 [持久化与回放说明](/E:/生产项目/项目/GodotProject/pvz_warG/pvz_warG/addons/ecsmini/PERSISTENCE.md)。

| 职责 | 主要入口 | 已实现内容 |
| --- | --- | --- |
| 世界协调 | [ecs_world.gd](/E:/生产项目/项目/GodotProject/pvz_warG/pvz_warG/addons/ecsmini/runtime/ecs_world.gd) | 代际句柄、持久 UID、生命周期、延迟命令、验证、批量提交、恢复边界、模拟时钟及 RNG |
| 查询 | [ecs_query.gd](/E:/生产项目/项目/GodotProject/pvz_warG/pvz_warG/addons/ecsmini/runtime/ecs_query.gd) | 首次编译后只检查受影响实体；嵌套遍历保留快照；批量导出 |
| 调度 | [ecs_scheduler.gd](/E:/生产项目/项目/GodotProject/pvz_warG/pvz_warG/addons/ecsmini/runtime/ecs_scheduler.gd)、[ecs_system.gd](/E:/生产项目/项目/GodotProject/pvz_warG/pvz_warG/addons/ecsmini/runtime/ecs_system.gd) | 拓扑依赖、阶段顺序、读写冲突、执行批次、声明数组原地修改检测 |
| 变化追踪 | [ecs_change_journal.gd](/E:/生产项目/项目/GodotProject/pvz_warG/pvz_warG/addons/ecsmini/runtime/ecs_change_journal.gd)、[ecs_change_reader.gd](/E:/生产项目/项目/GodotProject/pvz_warG/pvz_warG/addons/ecsmini/runtime/ecs_change_reader.gd) | 有界环形历史、独立游标、丢失与重置报告、责任系统记录 |
| 存储接口 | [ecs_storage.gd](/E:/生产项目/项目/GodotProject/pvz_warG/pvz_warG/addons/ecsmini/runtime/storage/ecs_storage.gd) | 统一存储契约、批次隔离、键枚举、内部批量提交 |
| 稀疏存储 | [ecs_sparse_storage.gd](/E:/生产项目/项目/GodotProject/pvz_warG/pvz_warG/addons/ecsmini/runtime/storage/ecs_sparse_storage.gd) | 每种组件的密集实体/值数组与稀疏行索引，交换删除 |
| Archetype 存储 | [ecs_archetype_storage.gd](/E:/生产项目/项目/GodotProject/pvz_warG/pvz_warG/addons/ecsmini/runtime/storage/ecs_archetype_storage.gd) | 精确组件签名、有限容量 Chunk、结构迁移与行压缩 |
| 批量计算 | [ecs_batch_compute.gd](/E:/生产项目/项目/GodotProject/pvz_warG/pvz_warG/addons/ecsmini/runtime/compute/ecs_batch_compute.gd) | Vector2/3 serial、parallel、auto 模式；非法数值和溢出拒绝 |
| 模板、事件、关系、索引 | [EXTENSIONS.md](/E:/生产项目/项目/GodotProject/pvz_warG/pvz_warG/addons/ecsmini/EXTENSIONS.md) | Inspector Resource 模板、分阶段事件、反向关系、删除策略、分组与 Vector2/3 空间查询 |
| 快照与磁盘格式 | [ecs_snapshot.gd](/E:/生产项目/项目/GodotProject/pvz_warG/pvz_warG/addons/ecsmini/runtime/persistence/ecs_snapshot.gd)、[ecs_snapshot_store.gd](/E:/生产项目/项目/GodotProject/pvz_warG/pvz_warG/addons/ecsmini/runtime/persistence/ecs_snapshot_store.gd) | 完整预校验、UID/引用重映射、版本化 JSON、安全类型编码、迁移回调 |
| 回放与回滚 | [ecs_replay.gd](/E:/生产项目/项目/GodotProject/pvz_warG/pvz_warG/addons/ecsmini/runtime/persistence/ecs_replay.gd) | 固定步长输入、检查点、重放、纠正输入、失败后的数据与历史恢复 |
| 驱动和调试 | [ecs_runner.gd](/E:/生产项目/项目/GodotProject/pvz_warG/pvz_warG/addons/ecsmini/runtime/ecs_runner.gd)、[ecs_debug_controls.gd](/E:/生产项目/项目/GodotProject/pvz_warG/pvz_warG/addons/ecsmini/debug/ecs_debug_controls.gd)、[ecs_debug_panel.gd](/E:/生产项目/项目/GodotProject/pvz_warG/pvz_warG/addons/ecsmini/debug/ecs_debug_panel.gd) | 两阶段驱动、暂停、单步、可选性能记录、有界变更轨迹 |

设计稿和执行计划分别保存在本机：

- [设计稿](/E:/生产项目/项目/GodotProject/pvz_warG/pvz_warG/docs/superpowers/specs/2026-10-01-ecsmini-next-design.md)。
- [执行计划](/E:/生产项目/项目/GodotProject/pvz_warG/pvz_warG/docs/superpowers/plans/2026-10-01-ecsmini-next-plan.md)。

根目录 `docs/` 被 Git 忽略，两个文件没有纳入版本管理；计划中的复选框尚未同步完成情况。交接进度以本文及实际测试结果为准。

## 4. 接手时必须保留的设计约束

1. **World 管生命周期和变更，Storage 管数据。** 默认使用稀疏存储，`set_storage_backend()` 只允许空世界切换，并拒绝共享后端。不要通过直接写 Storage 绕开验证、查询通知和索引。
2. **运行时句柄与持久 UID 分开。** 句柄含槽位与代数，只在所属 World 中使用；存档恢复生成新句柄。稳定 UID 用于持久引用和输入命令。
3. **读取已提交状态，结构变更按 FIFO 延迟。** 系统 Tick、受保护查询遍历期间，添加/移除组件和销毁实体通过命令队列提交；创建实体立即得到句柄。等待销毁的实体拒绝后续写入并从查询结果中排除。
4. **变化读取器独立且有界。** 创建读取器后才启用记录；容量修改会重置历史，消费者必须处理 overflow/reset。直接修改可变组件后调用 `mark_component_changed()`。
5. **模拟与呈现分阶段。** 仅模拟推进 Tick、模拟时间和事件阶段；呈现负责同步节点。`before/after/reads/writes` 影响顺序与安全批次，普通系统回调仍串行执行。
6. **线程任务只处理独立数学数据。** World、索引和节点由所属线程操作；内置计算由主线程调度，工作线程只写自己的 PackedArray，所有任务完成后才提交。
7. **快照预校验后再恢复。** 安全编码拒绝 Object/Resource/Callable、循环容器和非法数值。只对明确注册的句柄组件重映射整数；其他整数保持原值。
8. **恢复统一发 restored。** 不发普通 cleared 或逐实体 destroyed，避免监听器在恢复中重建游戏。查询失效、变化读取器重置、索引重新构建；2D/3D 节点绑定按 UID 重新对应。
9. **回放由一个驱动独占模拟时钟。** 可变模拟状态放在组件/World 元数据中，随机数使用 `world.rng`；系统私有可变状态、外部时间和全局 RNG 不会自动回放。只保证受控场景中的可复现性，没有跨平台锁步保证。
10. **计算使用纯 GDScript。** 小批次由 serial 模式在主线程处理；parallel 模式把独立 PackedArray 切片交给 WorkerThreadPool；auto 根据批次大小选择模式。World 与场景节点始终由所属线程访问。

## 5. 验证状态与命令

本轮在纯 GDScript 迁移后重新运行完整测试入口、编辑器导入和 FrontYard 契约；详细结果见第 7 节。后续改动后再按以下命令复测：

### 可直接使用的命令

在项目根目录执行。这里的变量名仅用于此次验证，不修改环境配置。

```powershell
$ecsGodot = 'E:\生产项目\项目\Godot\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe'
$ecsPython = 'C:\Users\15610\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'

git status --short
& $ecsGodot --headless --editor --path . --quit

# ECSmini 全套 GDScript 合约与示例检查。
& $ecsPython addons/ecsmini/tests/run_tests.py --godot $ecsGodot

# 需要单独验证已经完成的模块时：
& $ecsGodot --headless --path . --script addons/ecsmini/tests/core_review_test.gd
& $ecsGodot --headless --path . --script addons/ecsmini/tests/extensions_test.gd
& $ecsGodot --headless --path . --script addons/ecsmini/tests/persistence_test.gd
& $ecsGodot --headless --path . --script addons/ecsmini/tests/diagnostics_test.gd
& $ecsGodot --headless --path . --script addons/ecsmini/tests/storage_compute_test.gd
& $ecsGodot --headless --path . --script addons/ecsmini/examples/example_smoke_test.gd

# 独占空闲环境再测性能，不要和其他测试同时运行。
& $ecsGodot --headless --path . --script addons/ecsmini/benchmarks/advanced_benchmark.gd -- --counts=100,1000,10000 --samples=3 --iterations=10 --output=user://ecsmini-final-benchmark.json

& '.\Map\FrontYard\front_yard_background_structure_contract_test.ps1'
& '.\Map\FrontYard\front_yard_cell_bounds_contract_test.ps1'
```

总入口会检查脚本错误、ERROR、ObjectDB 泄漏和退出码；性能报告记录实际模式，不以易波动的墙钟阈值判断性能合格。

## 6. 本轮完成项

### P1：World 和 Runner 的模拟推进安全边界（已完成）

`World._tick()` 现在检查 `_iteration_depth` 和 `_is_flushing`；`Runner.step()` 要求 `world.is_at_safe_boundary()`。`tests/simulation_boundary_test.gd` 覆盖查询遍历、Runner 单步、销毁 Flush 回调和正常自动启动。

### P1：高级实验场景（已完成）

场景和模块已实现，项目资源路径为：

```text
res://addons/ecsmini/examples/advanced/AdvancedEcsLab.tscn
res://addons/ecsmini/examples/advanced/lab_controller.gd
res://addons/ecsmini/examples/advanced/lab_simulation.gd
res://addons/ecsmini/examples/advanced/lab_presentation.gd
res://addons/ecsmini/examples/advanced/lab_controls.gd
res://addons/ecsmini/examples/advanced/lab_observations.gd
```

已有测试明确了接手接口和行为：

- `SimulationModule/LabController` 独占 EcsReplay 时钟，默认暂停，初始化 32 个模板实体；支持 64 个实体、稀疏/Archetype 和 serial、parallel、auto 三种计算模式。
- `LabUI/WindowLayout/LabLayout/ContentModule/SimulationStage/PresentationModule` 管视觉和 UID 绑定；空间最近搜索用于高亮。
- 行分组、跟随关系、事件和观察展示各自管理职责；32 个实体时预期四组与 28 条跟随关系。
- 控制器公开 `reset_lab`、`step_lab`、`queue_velocity`、`rewind_to`、`replay_to`、`correct_input`、`save_lab`、`load_lab`、`run_lab`、`pause_lab`。
- 磁盘 Load 后创建新的回放基线，不能把旧历史直接接到加载状态上；绑定按稳定 UID 重建。
- UI 按钮驱动，不监听全局玩法输入；不要同时让 Runner 和 Replay 推进同一个 World，也不要让通用调试面板单步绕过 Replay。
- 交互、状态摘要、保存/恢复、serial/parallel/auto 模式及释放验证后，再验证 1920×1080 的真实渲染与布局。

保留 `tests/advanced_lab_test.gd` 作为场景接口和生命周期契约；更改计算模式后重新运行此测试。

### P2：回放外部副作用约定（已完成）

恢复会回退事件读者游标。重模拟期间跳过 Presentation，但最后一次 Presentation 可能重新读取历史音效、网络或成就事件；这时 `is_replaying` 已恢复为 false，单靠该标志不能保证副作用不重复。

`PERSISTENCE.md` 已说明专用 reader discard、稳定事件 ID 去重和纠正载荷的 upsert/补偿要求；`tests/replay_side_effects_test.gd` 检查相关时序和去重行为。数据事务仍只恢复 ECS 数据。

### P2：性能与最终交付验证

`COMPUTE.md` 说明 `keys_for()` / `set_values_unchecked()` 边界和纯 GDScript serial、parallel、auto 模式。完成计算路径更新后，按第 5 节命令重新验证 ECSmini 套件、性能报告和 FrontYard 契约。

## 7. 验证结果与性能记录

本轮迁移至纯 GDScript 后，Godot 4.7.1 headless 全量测试入口退出码 0：adapter 54、advanced_core 67、advanced_lab 33、core_review 15、core 74、extensions 76、persistence 51、replay side-effect 19、simulation boundary 7、storage/compute 16,344 项，均为 0 failures。示例 smoke 为 0 失败；基础 benchmark 正确性通过，高级 benchmark 24 组配置（两个存储、2D/3D、serial/parallel/auto、17/257 实体）全部正确。最新复跑命令为 `python addons/ecsmini/tests/run_tests.py --godot <Godot 4.7.1 console executable>`，运行于 2026-10-01 21:14:08–21:14:20 +08:00，退出码 0；完整输出记录在忽略文件 `.codex/ecsmini-pure-gd-verify-20261001-2112.log`，SHA-256 为 `EE656C2B031D8C1C2509A579CB5AE2908BF3B86BF62F86B8D82E437073E204B3`。随后 Godot 无头编辑器导入、FrontYard background/grass structure 与 cell bounds 契约均退出码 0；记录在 `.codex/ecsmini-pure-gd-integration-20261001-2118.log`，SHA-256 为 `CBFAB7C2FD4824D3C19A5F0F04F5C8855586FE526295CC14B141D900D9EECAE9`。高级实验场景 headless 启动退出码 0。

`addons/ecsmini/native/` 下的 C++ 源码、构建脚本和 GDExtension 描述已从插件移除，空目录也已清理。插件运行时使用纯 GDScript；parallel 模式调用 Godot 内置 `WorkerThreadPool`。忽略目录 `.codex/ecsmini-native/` 中仍保留本机 DLL、旧 `.gdextension` 与第三方 godot-cpp 构建缓存；本地 benchmark JSON 中也有历史 native 路径。这些是项目本地缓存，不属于 `addons/ecsmini` 插件源码，本轮保留未清理。项目目前没有 `export_presets.cfg`，没有执行 Linux/macOS 导出包测试；该平台包验证保持 UNRESOLVED。对本次纯 GDScript 改动，常规 headless 合约测试是主要回归项；准备发布或承诺目标平台支持时，再按目标平台补导出并启动 smoke test。未来性能记录应包含模式、实体规模、引擎版本、样本次数和完整 capture/compute/commit 时间，不构成普遍速度保证。

## 8. 游戏内容与 Git 注意事项

开始本轮前就存在以下用户改动，必须保留：

- `E:\生产项目\项目\GodotProject\pvz_warG\pvz_warG\Map\FrontYard\FrontYard.tscn`：已有资源 ID 调整。
- `E:\生产项目\项目\GodotProject\pvz_warG\pvz_warG\Plants\Dave1.png`：用户删除。
- `E:\生产项目\项目\GodotProject\pvz_warG\pvz_warG\Zombies\`：用户新增内容。

本任务新增的游戏侧示例为 [EcsFrontYardDemo.gd](/E:/生产项目/项目/GodotProject/pvz_warG/pvz_warG/Manager/EcsFrontYardDemo.gd) 与 [EcsFrontYardDemo.tscn](/E:/生产项目/项目/GodotProject/pvz_warG/pvz_warG/Map/FrontYard/EcsFrontYardDemo.tscn)。原场景保持原职责；所有全局玩法输入仍从 FrontYard/Manager/PlantLogic 进入。不要把实验脚本散落到原地图/UI，新的游戏管理器放根目录 Manager。

插件新增源码多数仍是未跟踪文件。仅看 `git diff --stat` 会漏掉这些文件；接手时同时检查 `git status --short` 和文件实际内容。保留 `.gd.uid`，不要把 `.godot/`、`.codex/` 或第三方构建缓存当源码。

按项目约定使用 apply_patch 手工修改，不使用破坏性清理命令。未经用户明确要求，不提交、推送、合并、清理历史或改发布配置。需要提交时先报告具体文件，只暂存本任务范围。

## 10. 后续建议

1. 若继续扩展，先读取本文与四份使用文档，检查 Git 状态和引擎路径。
2. 为新的游戏玩法在 `Manager/` 建立应用侧系统，保持植物、僵尸、战斗和波次规则在插件外。
3. 若纯 GDScript 计算或存储发生变化，重新运行 ECSmini 合约、示例 smoke 和性能测量，再记录当次验证结果。
4. 需要提交时先审查工作区中的用户改动和未跟踪 ECSmini 文件，再单独取得提交授权。

## 11. 生产前审查与源码交付

2026-10-01 完成纯 GDScript 源码审查。修复快照 validator 的实体/生命周期重入、reference schema 注册顺序影响 digest、动态注册跳过依赖启动，以及插件测试依赖宿主场景四类问题。补充启动中断/取消、动态优先级、configure 自移除的回归，适配器补充 2D/3D 重复 restore 后 UID 绑定和非均匀缩放/剪切父节点下的 3D 全局变换检查。

最终 Godot 4.7.1 Windows 全套入口在宿主项目和实际 ZIP 解压后的独立项目均退出码 0。adapter 为 86/84 项（宿主专用场景多两项），core review 35、persistence 55、storage/compute 16,344 项；其他合约、示例 smoke、基础基准以及高级基准 24 组配置均通过。FrontYard 两项结构合约及 git diff --check 通过。日志位于 `.codex/ecsmini-production-source-tests.log` 和 `.codex/ecsmini-production-package-tests.log`。

桌面包 `C:/Users/15610/Desktop/ECSmini-pure-gd-source-0.3.0.zip` 包含 124 个文件、55 个 GDScript 与对应 UID、3 个文本场景和 MIT 许可证；无 C++、GDExtension、二进制、缓存、HANDOFF 或宿主玩法文件。大小 152,809 字节；SHA-256 为 `1BD9E729AFF6E48150D40D0380787D4742F997D780C972E92F641C5B7693BB5B`。逐文件解压校验与工作区源码一致。桌面另有 `ECSmini生产前审查报告.md` 和 `ECSmini_GDScript插件技术详解.md`。

动态注册的新系统若必须排在已启动系统前，应先 stop World，再注册并 restart；失败注册调用 on_detach 清理 configure 的工作。实际玩法尚未迁入 ECS；Linux/macOS 导出、真实负载帧预算和完整玩法仍待验收。没有暂存、提交、推送或修改发布配置。
