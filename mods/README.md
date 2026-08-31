# 《余烬 EMBER》MOD 开发指南

> 本文档基于游戏实际代码编写，所有格式和字段均与代码一致。
> 最后更新：游戏开发初期阶段，内容会随版本迭代更新。

## 一、MOD 能力边界

### 1.1 MOD 可以做什么

| 能力 | 说明 | 覆盖已有内容 |
|------|------|-------------|
| 新增物品 | 武器、工具、食物、药品、资源、弹药等 | ✅ 相同 ID 可覆盖 |
| 新增建筑 | 防御、生产、存储、电力、医疗等 | ✅ 相同 ID 可覆盖 |
| 新增配方 | 制作配方，指定材料和工作站 | ✅ 相同 ID 可覆盖 |
| 新增科技 | 公共科技、职业专属科技、书籍 | ✅ 相同 ID 可覆盖 |
| 新增 NPC 类型 | 市民、商人、猎人、士兵等 | ✅ 相同 ID 可覆盖 |
| 注册行为模板 | 为 NPC 注册自定义行为名称 | ⚠️ 仅注册名称，逻辑需脚本 |

### 1.2 MOD 不能做什么（当前版本硬编码）

以下内容目前没有 MOD 接口，修改需要改游戏源码：

| 内容 | 所在文件 | 说明 |
|------|---------|------|
| 丧尸类型 | `scripts/world/zombie.gd` | 6 种丧尸的速度/伤害/血量/特殊能力 |
| 职业定义 | `scripts/ui/main_menu.gd` | 8 职业的名称、描述、选择界面 |
| 玩家属性曲线 | `scripts/player/player.gd` | 生命/饥饿/口渴/体力基础值、成长 |
| 建筑升级配置 | `scripts/globals/building_db.gd` | `UPGRADES` 常量，各建筑的升级路线 |
| 昼夜循环参数 | `scripts/world/main.gd` | 一天时长、起始时间 |
| 世界生成参数 | `scripts/world/world_generator.gd` | 地图大小、资源密度、种子 |
| 物理层定义 | `scripts/globals/physics_layers.gd` + `project.godot` | 12 个物理层 |
| 输入映射 | `project.godot` | 按键绑定 |
| 核心游戏规则 | 各核心脚本 | 胜利条件、病毒传播、倒地救援等 |
| 自定义脚本逻辑 | - | MOD 目前不支持加载 `.gd` 脚本 |

### 1.3 覆盖机制

- MOD 数据通过 `register_*()` 方法写入各数据库的 `_custom_*` 字典
- 查询时**优先返回 MOD 数据**，其次是游戏内置数据
- 如果 MOD 使用与内置内容相同的 ID，会**完全覆盖**内置内容
- 示例：MOD 中定义 `"wood": {"name": "修改后的木材"}` 会替换游戏原有的木材

---

## 二、MOD 目录结构

```
mods/
  your_mod_name/           # 文件夹名即 MOD ID
    mod.json               # 必需：MOD 元数据
    items.json             # 可选：物品
    buildings.json         # 可选：建筑
    recipes.json           # 可选：配方
    tech_tree.json         # 可选：科技树
    npcs.json              # 可选：NPC 类型
    behaviors.json         # 可选：行为模板
```

- 以 `_` 开头的键（如 `_comment`、`_version`）会被自动忽略，可用于写注释
- 缺少某个 JSON 文件不影响加载，只会跳过对应类型
- 缺少 `mod.json` 的文件夹会被跳过

---

## 三、数据格式规范

### 3.1 mod.json（MOD 元数据）

```json
{
  "name": "我的MOD",
  "id": "my_mod",
  "version": "1.0.0",
  "author": "作者名",
  "description": "MOD描述",
  "enabled": true,
  "website": "",
  "dependencies": []
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| name | string | ✅ | MOD 显示名称 |
| id | string | ✅ | MOD 唯一标识（建议英文小写+下划线） |
| version | string | - | 版本号，默认 "1.0.0" |
| author | string | - | 作者，默认 "未知" |
| description | string | - | 描述 |
| enabled | bool | - | 设为 false 可禁用此 MOD |
| website | string | - | 官网/下载页 |
| dependencies | array | - | 依赖的其他 MOD ID 列表（当前版本仅记录，未做强制检查） |

### 3.2 items.json（物品）

```json
{
  "my_sword": {
    "name": "我的剑",
    "desc": "一把来自MOD的剑",
    "type": 2,
    "max_stack": 1,
    "weight": 2.0,
    "color": [0.8, 0.2, 0.2, 1.0],
    "damage": 15,
    "durability": 100,
    "attack_range": 50,
    "attack_speed": 1.2
  }
}
```

**通用字段：**

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| name | string | ✅ | 物品名称 |
| desc | string | - | 物品描述 |
| type | int/string | ✅ | 物品类型，见下方枚举 |
| max_stack | int | ✅ | 最大堆叠数 |
| weight | float | ✅ | 单格重量（影响负重系统） |
| color | array | ✅ | `[R, G, B, A]`，范围 0.0~1.0 |

**物品类型（type）：**

| 数字 | 字符串（自动转换） | 说明 |
|------|-------------------|------|
| 0 | resource | 资源材料 |
| 1 | tool | 工具 |
| 2 | weapon | 武器 |
| 3 | food | 食物 |
| 4 | medicine | 药品 |
| 5 | building | 建筑物品 |
| 6 | ammo | 弹药 |
| 7 | misc | 杂项 |

> `type` 字段可以写数字也可以写字符串（如 `"weapon"`），加载时会自动转换。

**按类型的额外字段：**

| 类型 | 字段 | 说明 |
|------|------|------|
| weapon | damage | 伤害值 |
| weapon | durability | 耐久度 |
| weapon | attack_range | 攻击距离（像素） |
| weapon | attack_speed | 攻击速度（次/秒） |
| weapon | knockback | 击退力 |
| weapon | weapon_type | "melee" 或 "ranged" |
| weapon | ammo_type | 远程武器所需弹药 ID |
| food | hunger_restore | 恢复饥饿值 |
| food | thirst_restore | 恢复口渴值 |
| food | health_restore | 恢复生命值 |
| medicine | health_restore | 恢复生命值 |
| 书籍类 | book_type | 学习后解锁的技能类型 |

### 3.3 buildings.json（建筑）

```json
{
  "my_tower": {
    "name": "瞭望塔",
    "desc": "MOD添加的防御建筑",
    "category": "defense",
    "size": [96, 96],
    "max_health": 500,
    "build_time": 30.0,
    "cost": {"wood": 50, "stone": 30},
    "color": [0.6, 0.4, 0.2, 1.0]
  }
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| name | string | ✅ | 建筑名称 |
| desc | string | - | 建筑描述 |
| category | string | ✅ | 分类，见下方 |
| size | array | ✅ | `[宽, 高]`，单位像素（不是格子数） |
| max_health | float | ✅ | 最大生命值 |
| build_time | float | ✅ | 建造时间（秒） |
| cost | object | ✅ | 建造材料 `{"物品ID": 数量}` |
| color | array | ✅ | `[R, G, B, A]` |

**建筑分类（category）：**
`basic` / `production` / `defense` / `power` / `storage` / `farming` / `medical` / `vehicle` / `decoration` / `comfort` / `special`

**可选功能字段：**

| 字段 | 说明 |
|------|------|
| station | 作为制作工作站，值为工作站 ID（如 "workbench"、"campfire"、"kitchen"） |
| slots | 储物格子数（存储类建筑） |
| light_radius | 照明半径（光源建筑） |
| damage | 造成伤害（陷阱、电网等） |
| power_type | 电力设备类型（"solar"/"wind"/"fence"/"fridge" 等） |
| power_consumption | 电力消耗（W） |
| water_source | 是否为水源（true/false） |

> ⚠️ 注意：建筑的 `size` 单位是**像素**，不是格子。常用值：1格=48px，2格=96px。

### 3.4 recipes.json（配方）

```json
{
  "my_sword_recipe": {
    "result": "my_sword",
    "count": 1,
    "ingredients": {"wood": 3, "metal": 5, "fiber": 1},
    "station": "workbench",
    "name": "制作我的剑"
  }
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| result | string | ✅ | 产出物品 ID |
| count | int | ✅ | 产出数量 |
| ingredients | object | ✅ | 所需材料 `{"物品ID": 数量}` |
| station | string | ✅ | 所需工作站，空字符串 `""` 表示随时随地可做 |
| name | string | ✅ | 配方显示名称 |

**工作站（station）有效值：**

| 值 | 对应建筑 |
|----|---------|
| `""` | 不需要工作站（徒手制作） |
| `workbench` | 工作台 |
| `campfire` | 篝火 |
| `kitchen` | 厨房（厨师专用） |
| `furnace` | 熔炉 |
| `blacksmith` | 铁匠铺 |
| `med_station` | 医疗站（医生专用） |
| `research` | 研究台 |
| `sawmill` | 锯木厂 |
| `greenhouse` | 大棚 |
| `garage` | 车库（汽修工专用） |

### 3.5 tech_tree.json（科技树）

```json
{
  "public_techs": {
    "my_tech": {
      "name": "我的科技",
      "desc": "解锁MOD内容",
      "cost": 2,
      "tier": 2,
      "requires": ["common_t1_fire"],
      "category": "crafting"
    }
  },
  "class_techs": {
    "warrior": {
      "my_war_tech": {
        "name": "战士专属科技",
        "desc": "描述",
        "cost": 1,
        "tier": 1,
        "requires": []
      }
    }
  },
  "books": {
    "my_book": {
      "name": "我的书",
      "desc": "学习后获得科技点",
      "class_unlock": "",
      "points": 3,
      "study_time": 3600.0,
      "locations": "获取地点描述"
    }
  }
}
```

**公共科技（public_techs）字段：**

| 字段 | 类型 | 说明 |
|------|------|------|
| name | string | 科技名称 |
| desc | string | 科技描述 |
| cost | int | 消耗科技点 |
| tier | int | 科技层级（1~4） |
| requires | array | 前置科技 ID 列表 |
| category | string | 分类：crafting/tools/survival/cooking/medical/defense/combat/electric |

**职业科技（class_techs）：**
- 外层 key 是职业 ID，内层是该职业的科技
- 职业 ID 有效值：`warrior` / `craftsman` / `doctor` / `farmer` / `mechanic` / `chef` / `lumberjack` / `engineer`

**书籍（books）字段：**

| 字段 | 类型 | 说明 |
|------|------|------|
| name | string | 书籍名称 |
| desc | string | 描述 |
| class_unlock | string | 解锁的职业 ID，空字符串表示通用 |
| points | int | 学习后获得的科技点 |
| study_time | float | 学习所需时间（秒） |
| locations | string | 获取地点描述 |

### 3.6 npcs.json（NPC 类型）

```json
{
  "my_merchant": {
    "name": "流浪商人",
    "speed": 40.0,
    "max_health": 80.0,
    "color": [0.8, 0.6, 0.3, 1.0],
    "scale": 1.0,
    "is_police": false,
    "behavior": "civilian",
    "can_trade": true,
    "trade_items": ["wood", "stone", "metal"],
    "dialogue_tree": "",
    "spawn_weight": 5,
    "faction": "civilian"
  }
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| name | string | NPC 名称 |
| speed | float | 移动速度 |
| max_health | float | 最大生命值 |
| color | array | `[R, G, B, A]` |
| scale | float | 体型缩放 |
| is_police | bool | 是否为警察/敌对 |
| behavior | string | 行为模板名称（内置：civilian / police） |
| can_trade | bool | 是否可交易 |
| trade_items | array | 可交易物品 ID 列表 |
| dialogue_tree | string | 对话树 ID |
| spawn_weight | int | 生成权重 |
| faction | string | 阵营：civilian / police / military |

> 战斗型 NPC 额外字段：`damage`、`attack_range`、`attack_cooldown`

### 3.7 behaviors.json（行为模板）

```json
{
  "my_behavior": {
    "description": "自定义行为描述",
    "author": "我的MOD"
  }
}
```

> ⚠️ 当前版本行为模板仅注册名称，实际 AI 逻辑需要通过游戏脚本实现。
> 纯 JSON MOD 无法添加新的 AI 行为逻辑。

---

## 四、调试与验证

### 4.1 查看加载日志

启动游戏后，控制台会输出 MOD 加载日志：

```
[ModLoader] 正在加载MOD: 我的MOD v1.0.0 (作者: xxx)
[ModLoader]   加载物品: 3 个
[ModLoader]   加载建筑: 2 个
[ModLoader]   加载配方: 2 个
[ModLoader] MOD加载完成: 我的MOD
```

如果某个 JSON 格式错误，该文件会被静默跳过（返回空字典），请检查 JSON 语法。

### 4.2 常见错误

| 现象 | 可能原因 |
|------|---------|
| MOD 物品显示"未知物品" | 旧版本 bug，已修复；确保使用最新代码 |
| 建筑无法建造 | `cost` 字段格式错误，应为 `{"物品ID": 数量}` |
| 建筑尺寸不对 | `size` 单位是像素不是格子，1格=48px |
| 配方不显示 | `station` 值不在有效值列表中，或材料物品 ID 不存在 |
| 物品重量为0 | 旧版本 bug，已修复 |
| 颜色显示白色 | `color` 数组格式错误，应为 `[R,G,B,A]` 且值在 0~1 |

---

## 五、后期扩展 MOD 边界的指南

> 本节面向游戏开发者，说明如何在后续版本中安全地扩展 MOD 能力。

### 5.1 扩展新的 MOD 可修改内容（标准流程）

以"让 MOD 可以添加新丧尸类型"为例：

1. **在对应 DB 中添加 `_custom_*` 字典和 `register_*()` 方法**
   ```gdscript
   var _custom_zombie_types := {}

   func register_zombie_type(type_id: String, data: Dictionary) -> void:
       var converted := data.duplicate()
       if converted.has("color") and converted.color is Array:
           converted.color = Color(converted.color[0], converted.color[1], converted.color[2])
       _custom_zombie_types[type_id] = converted
   ```

2. **添加统一查询入口**
   ```gdscript
   func get_zombie_type(type_id: String) -> Dictionary:
       if _custom_zombie_types.has(type_id):
           return _custom_zombie_types[type_id]
       if ZOMBIE_TYPES.has(type_id):
           return ZOMBIE_TYPES[type_id]
       return {}
   ```

3. **把所有直接访问 `ZOMBIE_TYPES[type_id]` 的地方改为 `get_zombie_type(type_id)`**
   - 这是最关键的一步，也是工作量最大的一步
   - 如果有很多地方直接访问常量，需要逐一替换

4. **在 mod_loader.gd 中添加加载逻辑**
   ```gdscript
   var zombies_path := mod_path + "zombies.json"
   if FileAccess.file_exists(zombies_path):
       _load_mod_zombies(zombies_path)
   ```

5. **更新本文档**，添加新的数据格式说明

### 5.2 扩展难度评估

| 扩展内容 | 难度 | 原因 |
|---------|------|------|
| 新数据类型（如丧尸、职业、天气） | 中 | 需要加 register + 改所有直接访问常量的地方 |
| 让 MOD 修改数值参数（如昼夜时长） | 低 | 加个全局配置表，MOD 覆盖即可 |
| MOD 脚本支持（加载 .gd） | 高 | 需要安全沙箱、API 边界、性能控制 |
| MOD 自定义美术资源 | 中 | 需要资源路径重定向和加载钩子 |
| 修改核心战斗公式 | 高 | 涉及多处硬编码逻辑，需要设计回调钩子 |

### 5.3 降低后期扩展难度的当前做法

现在游戏初期，建议养成以下习惯，后期扩展 MOD 边界会轻松很多：

1. **所有数据查询走方法，不直接访问常量**
   - ✅ `ItemDB.get_item("wood")`
   - ❌ `ItemDB.ITEMS["wood"]`

2. **新系统设计时就预留 `_custom_*` 字典**
   - 写新的 DB 时，默认加上 register/unregister 接口

3. **核心逻辑与数据分离**
   - 战斗公式读配置表，不把数值写死在逻辑里

4. **用 EventBus 做钩子点**
   - 在关键流程（如玩家受伤、丧尸生成、物品使用）发信号
   - MOD 脚本（未来支持）可以挂这些信号

### 5.4 版本兼容性策略

- MOD 格式版本号写在每个 JSON 的 `_version` 字段
- 游戏主版本升级时，如果数据格式变了，写迁移逻辑或在文档中标注不兼容
- 初期阶段（当前）不保证向后兼容，MOD 作者需关注更新日志

---

## 六、与 data/ 目录的关系

游戏 `data/` 目录下也有 JSON 文件，但**当前版本这些文件未接入游戏逻辑**，属于预留的数据驱动框架。

- `data/` JSON：游戏官方数据包（预留，未来可能接入）
- `mods/` JSON：玩家/第三方 MOD（当前已生效）

两者格式不同，不要混用。MOD 作者只需要关注 `mods/` 目录。
