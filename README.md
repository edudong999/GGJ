# Pandemic Survival — 疫情家庭生存

一款基于 Godot 4 的卡牌 demo。每轮出现 3 个事件,从 3 个选项中做出选择,影响家庭的 4 个核心属性。撑过 20 轮则全家安全度过疫情。

## 玩法

- **属性**：心情 / 和睦 / 免疫 / 物资,初始均为 50,范围 0–100
- **回合**：共 20 轮,每轮从 3 个池子各抽 1 个事件:
  - **家庭池** (`family`):谈心、蛋糕、网课
  - **物资池** (`supplies`):封城、物资配送
  - **社区池** (`community`):社区求助
- **胜负**：走完 20 轮且属性 > 0 → 胜利;任一属性 ≤ 0 → 失败
- **特殊标记**：`小儿子学业危机` 跟踪儿子学业状态;`是否与儿子谈心` 跨轮持续,影响后续蛋糕事件的可选项

## 运行

需要 Godot 4.2+。在 Godot 中打开本目录,按 F5 运行主场景 `scenes/Main.tscn`。

## 项目结构

```
project.godot         # Godot 项目配置
scenes/Main.tscn      # 主场景(唯一场景)
scripts/
  GameState.gd        # autoload 单例:状态、事件加载与过滤
  Main.gd             # 主场景脚本:UI 构建与交互
data/events.json      # 事件数据(可独立编辑)
```

## 扩展事件

在 `data/events.json` 中按以下结构添加新事件:

```json
{
  "id": "your_event_id",
  "pool": "family",
  "title": "事件标题",
  "description": "事件描述",
  "trigger": {"attribute": "mood", "min": 60},
  "options": [
    {
      "text": "选项文字",
      "effects": {"mood": 10, "supplies": -5},
      "result": "选择后显示的结果文本"
    }
  ]
}
```

`pool` 必填,值必须是 `family` / `supplies` / `community` 之一。

支持的 effects: `mood` / `harmony` / `immunity` / `supplies` / `son_crisis` / `talked_with_son`
trigger 和 requires 支持: `min` / `max` / `equals`