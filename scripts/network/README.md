# 联机同步框架使用指南

## 概述

本框架提供统一的联机同步能力，采用**组件模式**，不破坏现有继承结构。

```
scripts/network/
├── network_entity.gd    # 同步组件（附加到实体上）
├── network_manager.gd   # 实体管理器（autoload 单例）
└── README.md            # 本文档
```

### 核心设计

- **服务器权威**：只有服务器能修改属性和位置，客户端只接收同步
- **组件模式**：`NetworkEntity` 作为子节点附加到任何实体，不影响继承链
- **Dirty Flag**：属性只在变化时同步，节省带宽
- **位置插值**：客户端位置平滑插值，避免抖动
- **统一生成/销毁**：通过 `NetworkManager` 广播实体的创建和销毁

---

## 快速开始

### 1. 给实体添加同步组件

在场景编辑器中，给需要同步的实体添加一个 `Node` 子节点，命名为 `NetworkEntity`，挂上 `network_entity.gd` 脚本。

或者在代码中动态添加：

```gdscript
# 在实体的 _ready() 中
var net_comp = Node.new()
net_comp.name = "NetworkEntity"
net_comp.set_script(load("res://scripts/network/network_entity.gd"))
add_child(net_comp)
```

### 2. 在实体脚本中获取引用

```gdscript
@onready var network_entity = $NetworkEntity

func _ready() -> void:
    # 声明需要同步的属性
    network_entity.declare_property("hp", 100.0)
    network_entity.declare_property("zombie_type", "normal")
    network_entity.declare_property("is_dead", false)
```

### 3. 服务器修改属性

```gdscript
func take_damage(amount: float) -> void:
    if not NetworkManager.is_server():
        return
    var new_hp = network_entity.get_property("hp") - amount
    network_entity.set_property("hp", new_hp)
    if new_hp <= 0:
        network_entity.set_property("is_dead", true)
        _die()
```

### 4. 客户端读取属性

```gdscript
func _process(delta: float) -> void:
    if not NetworkManager.is_server():
        # 客户端从同步组件读取属性
        health_bar.value = network_entity.get_property("hp", 100.0)
```

### 5. 监听属性变化

```gdscript
func _ready() -> void:
    network_entity.state_changed.connect(_on_state_changed)

func _on_state_changed(changes: Dictionary) -> void:
    if changes.has("hp"):
        print("HP 变为: ", changes.hp)
    if changes.has("is_dead") and changes.is_dead:
        _play_death_animation()
```

---

## 实体生成与销毁

### 服务器生成实体

```gdscript
# 生成丧尸并广播给所有客户端
var zombie = NetworkManager.spawn_entity(
    "res://scenes/entities/zombie.tscn",
    Vector2(100, 200),
    {"zombie_type": "fast", "hp": 30.0}
)
```

### 服务器销毁实体

```gdscript
NetworkManager.destroy_entity(zombie)
```

### 新玩家加入时全量同步

在 `GameManager._client_ready()` 中，服务器为新玩家同步所有现有实体：

```gdscript
NetworkManager.sync_all_entities_to_client(new_peer_id)
```

---

## API 参考

### NetworkEntity（同步组件）

| 方法 | 说明 | 调用端 |
|------|------|--------|
| `declare_property(name, default)` | 声明需要同步的属性 | 所有端（_ready中） |
| `set_property(name, value)` | 设置属性值，自动标记为待同步 | 仅服务器 |
| `set_properties(data)` | 批量设置属性 | 仅服务器 |
| `get_property(name, default)` | 获取属性值 | 所有端 |
| `has_property(name)` | 检查属性是否存在 | 所有端 |
| `get_all_properties()` | 获取所有属性的副本 | 所有端 |
| `force_sync()` | 强制立即同步所有属性 | 仅服务器 |
| `teleport(pos)` | 瞬移并立即同步（不插值） | 仅服务器 |
| `is_server()` | 是否是服务器 | 所有端 |
| `is_local_client()` | 父实体是否是本地玩家 | 所有端 |

| 信号 | 说明 |
|------|------|
| `state_changed(changes: Dictionary)` | 属性变化时触发（客户端） |

| 导出变量 | 默认值 | 说明 |
|---------|--------|------|
| `sync_position` | true | 是否同步位置 |
| `position_sync_interval` | 0.1 | 位置同步间隔（秒），10Hz |
| `state_sync_interval` | 0.2 | 属性同步间隔（秒），5Hz |
| `interpolation_speed` | 10.0 | 位置插值速度 |
| `interpolation_enabled` | true | 是否启用位置插值 |

### NetworkManager（实体管理器）

| 方法 | 说明 | 调用端 |
|------|------|--------|
| `spawn_entity(scene_path, pos, data, parent)` | 生成实体并广播 | 仅服务器 |
| `destroy_entity(entity)` | 销毁实体并广播 | 仅服务器 |
| `get_entity(network_id)` | 获取 NetworkEntity 组件 | 所有端 |
| `get_entity_node(network_id)` | 获取实体节点 | 所有端 |
| `sync_all_entities_to_client(peer_id)` | 全量同步给新玩家 | 仅服务器 |
| `is_active()` | 联机是否激活 | 所有端 |
| `is_server()` | 是否是服务器 | 所有端 |
| `local_peer_id()` | 本地玩家 peer_id | 所有端 |

| 信号 | 说明 |
|------|------|
| `entity_spawned(entity)` | 实体生成时触发 |
| `entity_destroyed(network_id)` | 实体销毁时触发 |

---

## 迁移示例：丧尸同步

以下是将 `zombie.gd` 迁移到新框架的步骤。

### 步骤1：在丧尸场景中添加 NetworkEntity 子节点

在 `zombie.tscn` 中添加一个 Node 子节点，命名为 `NetworkEntity`，挂 `network_entity.gd`。

### 步骤2：修改 zombie.gd

```gdscript
extends CharacterBody2D

@onready var network_entity = $NetworkEntity

var _type_config: Dictionary = {}

func _ready() -> void:
    # 声明同步属性
    network_entity.declare_property("hp", 50.0)
    network_entity.declare_property("zombie_type", "normal")
    network_entity.declare_property("is_dead", false)
    network_entity.declare_property("anim_state", 0)

    # 客户端不运行 AI
    if not NetworkManager.is_server():
        set_physics_process(false)
        # 监听属性变化更新表现
        network_entity.state_changed.connect(_on_state_changed)
        return

    # 服务器：初始化类型配置
    _init_zombie_type()

func _init_zombie_type() -> void:
    var type = network_entity.get_property("zombie_type", "normal")
    _type_config = ZOMBIE_TYPES.get(type, ZOMBIE_TYPES.normal)
    network_entity.set_property("hp", _type_config.max_health)
    # 设置精灵颜色、缩放等
    sprite.modulate = _type_config.color

func take_damage(amount: float, attacker: Node2D = null) -> void:
    if not NetworkManager.is_server():
        return
    var hp = network_entity.get_property("hp") - amount
    network_entity.set_property("hp", hp)
    if hp <= 0 and not network_entity.get_property("is_dead"):
        network_entity.set_property("is_dead", true)
        _die()

func _die() -> void:
    # 掉落物品、给经验等（服务器逻辑）
    _drop_loot()
    # 销毁并广播
    NetworkManager.destroy_entity(self)

func _on_state_changed(changes: Dictionary) -> void:
    # 客户端：根据属性变化更新表现
    if changes.has("hp"):
        health_bar.value = changes.hp
    if changes.has("is_dead") and changes.is_dead:
        _play_death_animation()
```

### 步骤3：修改生成逻辑

在 `main.gd` 中，将丧尸生成改为通过 NetworkManager：

```gdscript
# 旧代码
var zombie = ObjectPool.acquire("zombie")
zombie.position = spawn_pos
world_layer.add_child(zombie)

# 新代码
var zombie = NetworkManager.spawn_entity(
    "res://scenes/entities/zombie.tscn",
    spawn_pos,
    {"zombie_type": "fast"}
)
```

> 注意：使用 NetworkManager.spawn_entity 后，对象池需要调整。
> 建议初期先不用对象池，等同步稳定后再优化性能。

---

## 与现有系统的关系

### 玩家（player.gd）

玩家已有完整的位置预测+校正同步，**不需要迁移**到 NetworkEntity。
玩家的属性同步（生命、饥饿等）可以单独加 NetworkEntity 组件，只同步属性不同步位置。

### NPC（npc.gd）

NPC 已有位置同步，可以逐步迁移：
- 位置同步可以继续用现有逻辑，或改用 NetworkEntity
- 属性（血量、感染状态）用 NetworkEntity 同步

### 建筑（building.gd）

建筑完全没有联机代码，是迁移的首选目标：
- 建筑不移动，关闭位置同步（`sync_position = false`）
- 同步属性：血量、建造进度、等级
- 生成/销毁通过 NetworkManager

---

## 最佳实践

### 1. 属性命名

用小写+下划线，和现有代码风格一致：
```gdscript
network_entity.declare_property("max_health", 100.0)  # ✅
network_entity.declare_property("MaxHealth", 100.0)   # ❌
```

### 2. 同步频率

| 实体类型 | 位置频率 | 属性频率 | 说明 |
|---------|---------|---------|------|
| 玩家 | 20Hz | 5Hz | 高频，需要流畅 |
| 丧尸 | 10Hz | 2Hz | 中频 |
| NPC | 5Hz | 1Hz | 低频 |
| 建筑 | 关闭 | 事件驱动 | 不动，只在受伤时同步 |
| 掉落物 | 关闭 | 事件驱动 | 只在创建/拾取时同步 |

在场景编辑器中调整 `position_sync_interval` 和 `state_sync_interval`。

### 3. 不要在客户端修改属性

```gdscript
# ❌ 错误：客户端修改属性不会同步，且会被服务器覆盖
network_entity.set_property("hp", 50)

# ✅ 正确：客户端发请求给服务器
rpc_id(1, "_request_heal", amount)

# 服务器端
@rpc("any_peer")
func _request_heal(amount: float) -> void:
    if not NetworkManager.is_server(): return
    network_entity.set_property("hp", network_entity.get_property("hp") + amount)
```

### 4. 大数值用整数同步

位置可以用 `Vector2i`（像素整数）减少带宽：
```gdscript
# NetworkEntity 内部已用 float，如需优化可修改 _sync_position 的参数
```

### 5. 新玩家加入时的全量同步

确保在 `GameManager._client_ready()` 中调用：
```gdscript
NetworkManager.sync_all_entities_to_client(pid)
```
否则新玩家看不到已存在的丧尸、建筑等。

---

## 常见问题

### Q: 实体的 NetworkEntity 组件找不到？
A: 确保场景中子节点命名为 `NetworkEntity`，且挂了正确的脚本。组件会在 `_ready()` 时自动注册到 NetworkManager。

### Q: 客户端属性不更新？
A: 检查：1) 是否是服务器调用 `set_property`；2) 属性是否已 `declare_property`；3) `NetworkManager.is_active()` 是否返回 true。

### Q: 位置不同步？
A: 检查 `sync_position` 是否为 true，服务器是否运行了 `_process`（NetworkEntity 的 `_process`）。

### Q: 生成的实体客户端看不到？
A: 确保用 `NetworkManager.spawn_entity()` 生成，而不是直接 `add_child()`。直接 add_child 的实体不会广播给客户端。

### Q: 和现有 GameManager 冲突吗？
A: 不冲突。GameManager 负责玩家管理、聊天、断线重连；NetworkManager 负责网络实体同步。两者互补。

---

## 后续优化方向

1. **兴趣管理**：只同步玩家周围的实体，减少带宽
2. **带宽压缩**：位置用整数、属性用位掩码
3. **延迟补偿**：攻击判定回滚
4. **对象池集成**：NetworkManager 与 ObjectPool 配合
5. **断线重连完善**：重连时发送世界快照
