# pvz_warG

一个正在成长中的 Godot 植物大战僵尸风格游戏项目。

这是一个从零开始的早期原型。现在的内容还很少，甚至还没有完整的游戏流程，但项目会随着新的想法、系统和内容逐步扩大。

> 现在什么都没有，并不代表未来什么都不会有。

## 项目状态

目前项目处于早期开发阶段，已有部分场景、草坪、植物、UI、音频和工具代码，但整体仍在持续搭建中。现阶段的重点是验证结构、表现和玩法方向，而不是提供完整成品。

## 本地运行

### 环境要求

- Godot 4.7 或兼容的 Godot 4.x 版本

### 启动方式

1. 使用 Godot Project Manager 导入本项目目录。
2. 打开项目。
3. 在文件系统面板中打开 `Map/FrontYard/FrontYard.tscn`。
4. 使用 **Run Current Scene**（F6）运行当前场景。

项目当前没有配置完整的主场景，直接运行整个项目可能不会进入最终游戏流程。

## 目录概览

| 目录 | 内容 |
| --- | --- |
| `Map` | 地图和 FrontYard 场景 |
| `Plants` | 植物资源和植物场景 |
| `UI` | 界面、进度条、音乐等 UI 组件 |
| `Assets` | 模型、纹理、音频和其他素材 |
| `AutoLoads` | 全局管理器和自动加载脚本 |
| `Tool` | 状态机、角色等通用工具 |
| `addons` | Godot 插件 |
| `docs` | 开发记录、设计文档和计划 |

## 未来方向

项目会逐步向更完整的游戏体验发展，计划方向包括：

- 更多植物、僵尸和可交互单位
- 完整的种植、防守和战斗循环
- 多种关卡、场景和难度变化
- 更完善的动画、特效、音效和音乐
- 更稳定的存档、配置和游戏状态管理
- 性能优化、编辑器工具和更清晰的开发流程

路线会随着开发过程调整。每一个可以运行的小功能，都会成为下一阶段的基础。

## 参与开发

项目仍处于个人早期开发阶段，目录结构和实现方式可能会持续变化。欢迎提出建议、发现问题，或为未来的功能留下想法。

## 许可证

项目许可证尚未确定。未经许可，请不要将项目素材或代码用于商业发布。

---

# pvz_warG

A growing Godot project inspired by the Plants vs. Zombies style of gameplay.

This is an early prototype built from scratch. There is very little content right now, and the project does not yet have a complete game loop. It will grow over time as new ideas, systems, and content are added.

> Having almost nothing today does not mean there will be nothing tomorrow.

## Project Status

The project is currently in early development. It already contains parts of the map, lawn, plant, UI, audio, and tooling systems, but the overall experience is still being built. The current focus is on exploring structure, presentation, and gameplay direction rather than shipping a finished game.

## Run Locally

### Requirements

- Godot 4.7 or a compatible Godot 4.x version

### Start the Project

1. Import this project directory through the Godot Project Manager.
2. Open the project.
3. Open `Map/FrontYard/FrontYard.tscn` from the FileSystem dock.
4. Run the current scene with **Run Current Scene** (F6).

The project does not have a complete main scene configured yet, so running the entire project may not enter the final gameplay flow.

## Directory Overview

| Directory | Contents |
| --- | --- |
| `Map` | Maps and FrontYard scenes |
| `Plants` | Plant assets and plant scenes |
| `UI` | UI components such as progress bars and music controls |
| `Assets` | Models, textures, audio, and other resources |
| `AutoLoads` | Global managers and autoload scripts |
| `Tool` | Shared tools such as state machines and character code |
| `addons` | Godot plugins |
| `docs` | Development notes, design documents, and plans |

## Future Direction

The project will gradually move toward a more complete game experience. Possible directions include:

- More plants, zombies, and interactive units
- A complete planting, defense, and combat loop
- Multiple levels, environments, and difficulty changes
- More polished animation, effects, sound, and music
- Reliable save data, configuration, and game-state management
- Performance improvements, editor tools, and a clearer development workflow

The roadmap may change as development continues. Every small feature that works becomes a foundation for the next stage.

## Contributing

This project is still in early personal development, so its structure and implementation may change frequently. Suggestions, issue reports, and ideas for future features are welcome.

## License

The project license has not been decided yet. Please do not use the project assets or source code in a commercial release without permission.
