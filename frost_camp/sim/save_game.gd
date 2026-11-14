class_name SaveGame
extends RefCounted
## 이어하기(8차 QA 다음 개발). sim을 평소처럼 layout으로 만든 뒤, 바뀌는 값만 덮어써서 되살린다.
## 시설·판매대·컨베이어를 잇는 참조는 생성 때 만들어지니 저장하지 않는다.
## 곰왕 레이드 중, 기지 습격이 쳐들어온 중, 엔딩 뒤에는 저장하지 않는다(그 상태의 화면을 되살리기 어렵다).

const PATH := "user://frost_save.dat"
## 저장 형식이 바뀌면 올린다. 다른 버전의 저장은 버린다.
const VERSION := 1

const SIM_FIELDS := [
	"money", "bears_killed", "time", "total_earned", "woodpile", "meat_pile", "holes_open",
	"gun_level", "gun_timer", "glow_timer", "wall_level", "unlocked", "stats", "haul_levels",
]
const AGENT_FIELDS := [
	"pos", "chop_timer", "unload_timer", "pickup_timer", "fish_timer", "zone_wait", "zone_wait_id",
	"attack_timer", "max_hp", "hp", "dazed_left", "max_warmth", "warmth",
]
const WORKER_FIELDS := ["speed", "damage", "target", "delivering", "stall", "carry_item", "line", "retired", "dead", "zone_id"]
const ZONE_FIELDS := ["level", "paid", "_carry"]
const STALL_FIELDS := ["stock", "cash", "queue", "served", "_spawn_timer", "_sell_timer"]
const TREE_FIELDS := ["hits", "respawn_left", "glowing"]
const BEAR_FIELDS := ["pos", "hp", "respawn_left", "attack_timer", "_wander_target"]
const CONVEYOR_FIELDS := ["level", "items", "_take_timer"]
const RAID_FIELDS := ["state", "time_left", "wave", "spawn_pos", "spawn_index"]
const BLIZZARD_FIELDS := ["state", "time_left"]
const BOSS_FIELDS := ["wins", "weapon", "reopen_left"]
const HEAT_FIELDS := ["level", "radius", "fuel", "feed_timer"]
const TOWER_FIELDS := ["level", "timer"]


static func can_save(sim: FrostSim) -> bool:
	return not sim.won and not sim.boss_raid.active and sim.raid.state != Raid.State.ATTACKING


static func capture(sim: FrostSim) -> Dictionary:
	var data := {"version": VERSION, "rng": sim.rng.state}
	data.sim = _pick(sim, SIM_FIELDS)
	data.player = _agent(sim.player)
	data.workers = sim.workers.map(func(w: Worker) -> Dictionary:
		var d := _agent(w)
		d.role = w.role
		d.merge(_pick(w, WORKER_FIELDS))
		return d)
	data.zones = sim.zones.map(func(z: PurchaseZone) -> Dictionary: return _pick(z, ZONE_FIELDS))
	data.structures = sim.structures.map(func(s: Structure) -> Dictionary:
		return {"hp": s.hp, "max_hp": s.max_hp, "repair": _pick(s.repair, ZONE_FIELDS)})
	data.stalls = sim.stalls.map(func(s: Stall) -> Dictionary: return _pick(s, STALL_FIELDS))
	data.trees = sim.trees.map(func(t: HarvestTree) -> Dictionary: return _pick(t, TREE_FIELDS))
	data.bears = sim.bears.map(func(b: HarvestBear) -> Dictionary: return _pick(b, BEAR_FIELDS))
	data.conveyors = {}
	for item in sim.conveyors:
		data.conveyors[item] = _pick(sim.conveyors[item], CONVEYOR_FIELDS)
	data.piles = {}
	for item in sim.extra_piles:
		data.piles[item] = sim.extra_piles[item].count
	data.heat = sim.heat_sources.map(func(h: Dictionary) -> Dictionary: return _pick_dict(h, HEAT_FIELDS))
	data.towers = sim.towers.map(func(t: Dictionary) -> Dictionary: return _pick_dict(t, TOWER_FIELDS))
	data.raid = _pick(sim.raid, RAID_FIELDS)
	data.blizzard = _pick(sim.blizzard, BLIZZARD_FIELDS)
	data.boss = _pick(sim.boss_raid, BOSS_FIELDS)
	return data


## 방금 만든 sim(아무것도 진행하지 않은 상태)에 저장된 값을 덮어쓴다. 화면을 만들기 전에 부른다.
static func restore(sim: FrostSim, data: Dictionary) -> void:
	sim.rng.state = data.rng
	_put(sim, data.sim)
	_put_agent(sim.player, data.player)
	for d: Dictionary in data.workers:
		var worker := Worker.new(d.role, sim.worker_spawn, sim.balance.workers[d.role])
		_put_agent(worker, d)
		_put(worker, d, WORKER_FIELDS)
		sim.workers.append(worker)
	for i in sim.zones.size():
		_put(sim.zones[i], data.zones[i])
	for i in sim.structures.size():
		var s: Dictionary = data.structures[i]
		sim.structures[i].hp = s.hp
		sim.structures[i].max_hp = s.max_hp
		_put(sim.structures[i].repair, s.repair)
	for i in sim.stalls.size():
		_put(sim.stalls[i], data.stalls[i])
	for i in sim.trees.size():
		_put(sim.trees[i], data.trees[i])
	# 서식지를 늘려 더해진 곰은 같은 순서로 다시 더한다(신호는 아직 아무도 듣지 않는다).
	sim._add_bears(data.bears.size() - sim.bears.size())
	for i in sim.bears.size():
		_put(sim.bears[i], data.bears[i])
	for item in data.conveyors:
		_put(sim.conveyors[item], data.conveyors[item])
	for item in data.piles:
		sim.extra_piles[item].count = data.piles[item]
	for i in sim.heat_sources.size():
		sim.heat_sources[i].merge(data.heat[i], true)
	for i in sim.towers.size():
		sim.towers[i].merge(data.towers[i], true)
	_put(sim.raid, data.raid)
	sim.raid.bears.clear()
	_put(sim.blizzard, data.blizzard)
	_put(sim.boss_raid, data.boss)
	sim.hole_users.fill(null)


static func has_save() -> bool:
	return not read().is_empty()


## 저장이 없거나 버전이 다르면 빈 Dictionary
static func read() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return {}
	var data: Variant = file.get_var()
	if not data is Dictionary or data.get("version", -1) != VERSION:
		return {}
	return data


static func write(sim: FrostSim) -> bool:
	if not can_save(sim):
		return false
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_var(capture(sim))
	return true


static func delete() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)


static func _agent(agent: SimAgent) -> Dictionary:
	var d := _pick(agent, AGENT_FIELDS)
	d.stack = agent.stack.items.duplicate()
	d.capacity = agent.stack.capacity
	return d


static func _put_agent(agent: SimAgent, d: Dictionary) -> void:
	_put(agent, d, AGENT_FIELDS)
	agent.stack.items.assign(d.stack)
	agent.stack.capacity = d.capacity


static func _pick(object: Object, fields: Array) -> Dictionary:
	var d := {}
	for field: String in fields:
		var value: Variant = object.get(field)
		d[field] = value.duplicate(true) if value is Array or value is Dictionary else value
	return d


static func _pick_dict(source: Dictionary, fields: Array) -> Dictionary:
	var d := {}
	for field: String in fields:
		if source.has(field):
			d[field] = source[field]
	return d


## 타입이 정해진 배열(Array[float] 등)은 assign으로 채운다.
static func _put(object: Object, d: Dictionary, fields: Array = []) -> void:
	for field: String in (fields if not fields.is_empty() else d.keys()):
		var value: Variant = d[field]
		var current: Variant = object.get(field)
		if current is Array:
			current.assign(value)
		elif value is Dictionary:
			object.set(field, value.duplicate(true))
		else:
			object.set(field, value)
