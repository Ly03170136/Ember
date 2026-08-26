# 《余烬 EMBER》MOD开发指南

## 概述

本游戏采用**混合架构**：基础内容硬编码在游戏中，MOD通过JSON文件动态加载扩展内容。你不需要修改游戏源码，只需要在 `mods/` 目录下创建文件夹和JSON文件即可添加新内容。

## 快速开始

1. 复制 `mods/example_mod/` 目录，重命名为你的MOD名称
2. 修改 `mod.json` 中的MOD信息
3. 编辑对应的JSON文件添加你的内容
4. 启动游戏，MOD会自动加载

## MOD目录结构

```
mods/
  your_mod_name/
    mod.json          # 必需：MOD元数据
    items.json        # 可选：新物品
    buildings.json    # 可选：新建筑
    recipes.json      # 可选：新配方
    tech_tree.json    # 可选：新科技
    assets/           # 可选：MOD资源（图片、音效等）
```

## 文件格式说明

### 1. mod.json（MOD元数据）

```json
{
  "name": "你的MOD名称",
  "id": "your_mod_id",
  "version": "1.0.0",
  "author": "作者名",
  "description": "MOD描述",
  "enabled": true,
  "website": "",
  "dependencies": []
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| name | string | MOD显示名称 |
| id | string | MOD唯一标识（建议用英文） |
| version | string | 版本号 |
| author | string | 作者 |
| description | string | 描述 |
| enabled | bool | 是否启用，设为false可禁用MOD |
| website | string | 官网/下载页（可选） |
| dependencies | array | 依赖的其他MOD ID列表（可选） |

### 2. items.json（物品）

```json
{
  "item_id": {
    "name": "物品名称",
    "type": 0,
    "max_stack": 99,
    "weight": 0.5,
    "color": [1.0, 1.0, 1.0, 1.0],
    "description": "物品描述"
  }
}
```

**物品类型（type）枚举：**
- 0 = RESOURCE（资源）
- 1 = TOOL（工具）
- 2 = WEAPON（武器）
- 3 = FOOD（食物）
- 4 = MEDICINE（药品）
- 5 = BUILDING（建筑物品）
- 6 = AMMO（弹药）
- 7 = MISC（杂项）

**颜色格式：** `[红, 绿, 蓝, 透明度]`，数值范围 0.0 ~ 1.0

**常用额外字段：**
- 武器：`damage`（伤害）、`durability`（耐久）、`attack_speed`（攻速）
- 食物：`heal_amount`（恢复量）、`hunger`（饱食度）
- 工具：`durability`（耐久）、`efficiency`（效率）

### 3. buildings.json（建筑）

```json
{
  "building_id": {
    "name": "建筑名称",
    "desc": "建筑描述",
    "category": "defense",
    "size": [1, 1],
    "max_health": 100,
    "build_time": 1,
    "cost": {"wood": 10, "stone": 5},
    "color": [0.6, 0.4, 0.2, 1.0],
    "functions": ["defense"]
  }
}
```

**建筑分类（category）：**
- basic（基础）
- production（生产）
- defense（防御）
- power（电力）
- storage（存储）
- agriculture（农业）
- medical（医疗）
- decoration（装饰）

**size格式：** `[宽度, 高度]`，单位为格子

**cost格式：** `{"物品ID": 数量, ...}`

### 4. recipes.json（配方）

```json
{
  "recipe_id": {
    "result": "结果物品ID",
    "count": 1,
    "ingredients": {"wood": 3, "stone": 2},
    "station": "workbench",
    "name": "配方名称"
  }
}
```

**工作站（station）：**
- `""`（空字符串）= 随时随地可制作
- `workbench` = 工作台
- `campfire` = 篝火
- `furnace` = 熔炉
- `research_table` = 研究台

### 5. tech_tree.json（科技树）

```json
{
  "public_techs": {
    "tech_id": {
      "name": "科技名称",
      "desc": "科技描述",
      "cost": 1,
      "tier": 1,
      "requires": [],
      "category": "crafting"
    }
  },
  "class_techs": {
    "warrior": {
      "tech_id": {
        "name": "职业科技名称",
        "desc": "描述",
        "cost": 2,
        "tier": 2,
        "requires": ["前置科技ID"]
      }
    }
  },
  "books": {
    "book_id": {
      "name": "书籍名称",
      "desc": "描述",
      "class_unlock": "",
      "points": 3,
      "study_time": 3600.0,
      "locations": "获取地点"
    }
  }
}
```

**职业ID（class_techs的key）：**
- warrior（战士）
- builder（工匠）
- doctor（医生）
- farmer（农民）
- mechanic（汽修工）
- cook（厨师）
- lumberjack（伐木工）
- engineer（工程师）

**科技分类（category）：**
- crafting（制作）
- tools（工具）
- survival（生存）
- cooking（烹饪）
- medical（医疗）
- defense（防御）
- combat（战斗）
- electric（电力）

## 注意事项

1. **ID唯一性**：如果你的MOD使用了与基础游戏相同的ID，会**覆盖**基础游戏的内容。这是故意设计的，允许MOD修改基础内容。

2. **JSON格式**：确保JSON格式正确，最后一个字段后不要加逗号。

3. **颜色格式**：使用 `[R, G, B, A]` 数组格式，数值范围 0.0 ~ 1.0，不要用十六进制颜色码。

4. **Vector2格式**：建筑的size使用 `[x, y]` 数组格式。

5. **热重载**：目前MOD在游戏启动时加载，修改后需要重启游戏生效。

6. **MOD资源**：如果你的MOD需要自定义图片/音效等资源，可以放在 `assets/` 子目录中，在JSON中引用路径。

## 调试

启动游戏后，查看控制台输出，可以看到MOD加载日志：
```
[ModLoader] 正在加载MOD: 示例MOD v1.0.0 (作者: 游戏开发者)
[ModLoader]   加载物品: 3 个
[ModLoader]   加载建筑: 2 个
[ModLoader]   加载配方: 2 个
[ModLoader]   加载公共科技: 2 个
[ModLoader] MOD加载完成: 示例MOD
```

如果某个JSON文件格式错误，会显示具体的错误行号和原因。

## 示例

完整的示例MOD请参考 `mods/example_mod/` 目录，包含了所有类型的内容示例。
