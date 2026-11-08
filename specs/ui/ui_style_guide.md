---
schemaVersion: 1
id: ui_style_guide
title: UI 贴图与主题规范
type: ui
description: UI 贴图裁剪、按钮统一主题（定稿参数）、弹窗与动画平滑的实践规范与已知坑。
---

# UI 贴图与主题规范

这份资料记录本项目 UI 贴图的使用方式，以及踩过的坑。新做界面时按这里的做法走，可以少走弯路。

## 一、素材与裁剪区

| 素材 | 原本用途 | 常用裁剪区 | 说明 |
|---|---|---|---|
| `assets/textures/ui/button.png` | 按钮 / 面板底 | `Rect2(40, 118, 217, 59)` | 从原始药丸区 `Rect2(34, 112, 229, 71)` **四周各内缩 6px**，去掉最外圈深色描边 |
| `assets/textures/ui/slot/slot.png` | 卡片外框 | `Rect2(79.23, 86, 116.55, 144)` | 中间不透明深棕，只有外圈约 10px 金边 |
| `assets/textures/ui/plant_slot.png` | 面板底 | `Rect2(34, 86, 229, 144)` | 用于设置面板 / 暂停面板背景 |

**要点**

- 整张贴图带透明留白，直接当背景会又小又偏，一律先裁有效区域再做九宫格。
- 药丸图原始高只有 **71px**，四角花纹约占 35px。按钮比它矮的时候九宫格会把花纹压成缺口，所以默认裁剪用了去边版本。
- 内缩 6px 的目的是让按钮边界落在棕色填充上，看起来没有明显描边。想保留描边就用原始区 `(34, 112, 229, 71)`。

## 二、按钮统一规范（定稿）

**所有按钮统一使用 `res://resources/ui/button_theme.tres`，不要再单独写样式。**

| 项 | 值 |
|---|---|
| 类型 | `Theme`，定义 `Button` 类型 |
| 贴图 | `button.png` 的 `Rect2(40, 118, 217, 59)` |
| `texture_margin`（九宫格切分） | 左 44 / 上 20 / 右 44 / 下 20 |
| `content_margin`（内容内边距） | 左 36 / 上 **34** / 右 36 / 下 **2** |
| normal | 原色 |
| hover | `modulate_color` 1.15（提亮） |
| pressed | `modulate_color` 0.8（压暗） |
| disabled | 同 normal |
| focus | `StyleBoxEmpty`（去掉默认虚线框） |
| 字体颜色 | 纯白，按下时 0.9 灰 |

**上下内边距不对称是故意的**：`(34 - 2) / 2 = 16` 单位的下移量，用于视觉居中——贴图上方有一条浅色高光，纯几何居中会让文字看起来偏高。以 100 单位高的按钮为基准，这正好是高度的 10%（已确认观感合适）。

**使用方式**

1. 在按钮节点的检查器里把 `Theme` 设为 `button_theme.tres`
2. **不要再设 `theme_override_styles/normal|hover|pressed`**，否则会覆盖主题
3. 需要特殊尺寸时，只调 `theme_override_font_sizes/font_size` 和 `custom_minimum_size`

**当前已套用的位置**

- `scenes/levels/chose_map.tscn`：三个主菜单选项、返回、设置、音频面板返回、信息层「查看」×2 与「关闭」
- `scenes/levels/front_yard/yard_level_select.tscn`：左上「返回」
- `scenes/ui/in_game_setting.tscn`：「返回主菜单」「返回游戏」

## 三、其他九宫格位置

| 位置 | 实现 | 切分 / 内边距 |
|---|---|---|
| 主菜单信息层面板 `ConfirmLayer/Panel` | `NinePatchRect` + 同一张裁剪图 | `patch_margin` 48 / 26 |
| 暂停面板底 `setting/setting` | `NinePatchRect` + plant_slot 裁剪图 | `patch_margin` 10 / 50 |

## 四、三种九宫格实现方式

| 方式 | 用在什么场景 | 关键属性 |
|---|---|---|
| `StyleBoxTexture` | 按钮、弹窗面板（走主题/样式覆盖） | `texture` + `texture_margin_*` + `content_margin_*` |
| `NinePatchRect` | 场景里直接摆的底板 | `texture` + `patch_margin_*` |
| `AtlasTexture` | 图标、小图（不需要拉伸） | `atlas` + `region` |

两套参数含义别混：

- `texture_margin_*` / `patch_margin_*`：**九宫格切分线**，保护四角不被拉伸
- `content_margin_*`：**内容（文字）与边框的内边距**
- `StyleBoxTexture` 的 `content_margin` **不填时会退化成等于 `texture_margin`**，文字会被挤到中间一小块 —— 这个坑真实踩过

## 五、必须记住的四个坑

1. **透明来自贴图 alpha，没有「透明度属性」。**
   `StyleBoxTexture` 没有透明度开关；换成带透明边的图，面板就会透出后面的画面。想要不透明就用 `StyleBoxFlat`，或者用裁掉透明边的区域。

2. **弹出菜单 / 对话框都是 Window，会画深色外框。**
   默认绘制 `Window/styles/embedded_border`（深色边框 + 预留标题高度）。处理：主题里设 `Window/styles/embedded_border = StyleBoxEmpty` 且 `Window/constants/title_height = 0`。

3. **但系统对话框的标题栏不受上面那条控制。**
   `ConfirmationDialog` 的标题文字和右上角 ✕ 是窗口装饰，改主题也去不掉，而且它是独立窗口、不参与场景根节点的 `scale`，字号会显得偏小。结论：需要「文字/按钮都长在贴图上」的效果时，改用场景内自绘 `Control` 层（本项目是 `chose_map.tscn` 的 `ConfirmLayer`）。

4. **大面积不能用按钮图拉伸。**
   药丸图是 229×71 的长条，铺到大面板会严重变形。大面板要么换专门的底板贴图，要么用纯色 `StyleBoxFlat`。

## 六、动画平滑相关的两个全局设置

| 设置 | 当前值 | 原因 |
|---|---|---|
| `gui/common/snap_controls_to_pixels` | `false` | 开启时 Control 位置按整数像素对齐，小幅浮动会变成「停十几帧跳一格」的顿感 |
| `rendering/textures/canvas_textures/default_texture_filter` | `0`（Nearest） | 全局最近邻；对需要平滑移动的控件单独设 `texture_filter = 2`（Linear） |

## 七、标准操作步骤

**新按钮**

1. 检查器里把 `Theme` 设为 `resources/ui/button_theme.tres`
2. 设 `theme_override_font_sizes/font_size`（常用 64 / 96）
3. 需要固定尺寸就设 `custom_minimum_size`
4. 不要写 `theme_override_styles/*`

**新面板**

1. 用 `AtlasTexture` 裁出底板有效区域
2. 用 `NinePatchRect` 摆放，设 `patch_margin_*`
3. 面板内的文字节点记得设 `horizontal_alignment = 1` 与 `vertical_alignment = 1`

**弹出菜单**

1. 主题里设 `PopupMenu/styles/panel` = 九宫格 `StyleBoxTexture`
2. `PopupMenu/styles/hover` 用**纯色** `StyleBoxFlat`（贴图高亮会变形）
3. 设 `Window/styles/embedded_border` 为空，去掉深色窗口框
4. 调 `item_start_padding`、`item_end_padding`、`v_separation` 控制留白

## 八、字体

- 全局字体：`assets/fonts/Silver.ttf`（`project.godot` 的 `gui/theme/custom_font`）
- 控件上通常还要单独设 `theme_override_font_sizes/font_size`，因为默认字号（16）在这个分辨率下太小
- 场景根节点若带手写 `scale`，字号会跟着放大，换算时要注意（本项目选关界面 `scale = 1.787 / 1.334`）
- 纯文字 Label 需要显式设 `horizontal_alignment = 1` + `vertical_alignment = 1` 才会居中；Button 的水平居中由 `alignment` 控制，默认就是居中
