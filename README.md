# Pandemic Survival — 疫情家庭生存

一款基于 Godot 4 的卡牌 demo。每轮出现 3 个事件(各池 1 个),从选项中做出选择后进入独立结算页。撑过 20 轮则全家安全度过疫情。

## 玩法

- **属性**:心情 / 和睦 / 免疫 / 物资,初始均为 50,范围 0–100
- **游戏流程**:
  1. **主场景**:屏幕显示 Day、家庭成员生长状态、4 项属性。右下角 `Cards ▾` 按钮控制卡牌展开/收起
  2. **卡牌阶段**:点按钮 → 3 个事件卡(各池 1 个)展开,直接显示选项按钮,选一个
  3. **结算阶段**:独立结算页显示本次选择(事件/选项/结果文本/属性前后变化)。继续 → 回主场景
  4. 重复 1-3,直到 Day 20 或任一属性 ≤ 0
- **天数**:共 20 天(`MAX_DAYS`)
- **3 个池子**(每池按权重 2/3/5 加权抽取):
  - **家庭池** (`family`):谈心、蛋糕、人之常情、线上测试、线上测试2、网恋、你是我的好爸爸
  - **社区池** (`community`):社区求助、也是社区志愿者、困难
  - **事件池** (`events`):封城、接龙时间、党员突击队、例行值守、漏网之鱼
- **结局**(5 种):
  - **在结束的那一天** (完美):值守度=1 AND 儿子完美结局=1 AND 你是我的好爸爸=1
  - **平庸却坚定的结局** (普通):上述条件未满足且属性 > 0
  - **还好有政府**:物资 ≤ 0
  - **离开**:心情 ≤ 0(分 3 个变体)
  - **需要医院**:免疫 ≤ 0
- **生长主题**:每位家庭成员有 0/1 标志,在主场景里展示
  - 爸:党员值守、社区志愿者
  - 妈:家庭支柱、心力交瘁
  - 儿:学业危机、完美结局
  - 女:账号未处理、好爸爸达成

## 运行

需要 Godot 4.7+。在 Godot 中打开本目录,按 F5 运行主场景 `scenes/Main.tscn`。

## 项目结构

```
project.godot         # Godot 项目配置
scenes/Main.tscn      # 主场景(主场景 + 卡牌层 + 结算层 + 结局层 + 卡牌按钮)
scripts/
  GameState.gd        # autoload 单例:状态、事件加载、池子加权抽取、结局判定
  Main.gd             # 主场景脚本:UI 渲染、按钮交互
data/events.json      # 15 个事件数据
```

## 扩展事件

在 `data/events.json` 中按以下结构添加新事件:

```json
{
  "id": "your_event_id",
  "pool": "family",
  "title": "事件标题",
  "description": "事件描述",
  "weight": 3,
  "trigger": {"attribute": "mood", "min": 60},
  "force_day": [5, 10],
  "force_position": [1, 2],
  "unique": false,
  "force_not": [{"attribute": "duty", "equals": 1}],
  "force_requires": [{"attribute": "eggs", "equals": 1}],
  "options": [
    {
      "text": "选项文字",
      "effects": {"mood": 10, "supplies": -5},
      "result": "选择后显示的结果文本"
    }
  ]
}
```

- `pool`: 必填,值必须是 `family` / `community` / `events`
- `weight`: 2=低概率 / 3=中概率(默认) / 5=高概率
- `trigger`: 满足条件才进入候选池
- `force_day`: 强制出现的日期(数组),配合 `force_position`(同长度数组)指定位置
- `unique`: 只出现一次
- `force_not`: 满足任一即排除(如「值守度=0 才出现」用 `force_not: [{duty, equals:1}]`)
- `force_requires`: 全部满足才进入候选

支持的 effects: `mood` / `harmony` / `immunity` / `supplies` / `son_crisis` / `talked_with_son` / `son_perfect` / `test_good_ending` / `good_dad` / `account` / `online_love_pending` / `duty` / `is_volunteer` / `eggs` / `hot_noodles`