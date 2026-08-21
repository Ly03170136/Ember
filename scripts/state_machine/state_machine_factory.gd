extends Node
class_name StateMachineFactory

static func create_player_state_machine(owner_node):
	var fsm = StateMachine.new()
	fsm.owner = owner_node
	fsm.default_state_name = "idle"
	fsm.auto_start = false
	fsm.debug_mode = false
	fsm.add_state(PlayerIdleState.new())
	fsm.add_state(PlayerWalkState.new())
	fsm.add_state(PlayerAttackState.new())
	fsm.add_state(PlayerDownState.new())
	return fsm


static func create_player_state_machine_with_node(owner_node, parent_node):
	var fsm = create_player_state_machine(owner_node)
	fsm.name = "PlayerStateMachine"
	parent_node.add_child(fsm)
	return fsm


static func create_zombie_state_machine(owner_node):
	var fsm = StateMachine.new()
	fsm.owner = owner_node
	fsm.default_state_name = "idle"
	fsm.auto_start = false
	fsm.debug_mode = false
	fsm.add_state(ZombieIdleState.new())
	fsm.add_state(ZombieWanderState.new())
	fsm.add_state(ZombieChaseState.new())
	fsm.add_state(ZombieAttackState.new())
	fsm.add_state(ZombieDownState.new())
	return fsm


static func create_zombie_state_machine_with_node(owner_node, parent_node):
	var fsm = create_zombie_state_machine(owner_node)
	fsm.name = "ZombieStateMachine"
	parent_node.add_child(fsm)
	return fsm


static func create_state_machine(owner_node, state_list, default_state = ""):
	var fsm = StateMachine.new()
	fsm.owner = owner_node
	fsm.default_state_name = default_state
	fsm.auto_start = false
	for state in state_list:
		fsm.add_state(state)
	return fsm


static func create_state_machine_with_node(owner_node, parent_node, state_list, default_state = "", node_name = "StateMachine"):
	var fsm = create_state_machine(owner_node, state_list, default_state)
	fsm.name = node_name
	parent_node.add_child(fsm)
	return fsm
