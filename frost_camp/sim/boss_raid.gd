class_name BossRaid
extends RefCounted
## 보스 레이드(선택 콘텐츠). 기지의 빙하 동굴 입구에 잠시 서 있으면 플레이어와 용병이 레이드 영역으로 옮겨진다.
## 빙하 곰왕은 플레이어를 쫓아오며 붙으면 할퀴고, 일정 간격으로 바닥을 내려찍고(빨간 원으로 미리 알림), 작은 곰을 부른다.
## 플레이어는 클릭한 쪽으로 쏘고(shoot), 용병은 알아서 쏜다. 곰왕을 쓰러뜨리면 큰 돈과 보석을 받고,
## 플레이어가 쓰러지면 빈손으로 돌아온다. 이길 때마다 곰왕이 강해지고 보상도 커진다.

signal started
signal ended(won: bool, reward: int)
## 쏜 자리와 닿은 자리(화면이 작살·포탄을 날린다)
signal shot(from: Vector2, to: Vector2, weapon: String)
signal boss_hit(damage: int)
signal slam_warned(index: int)
signal slammed(index: int)
signal minion_spawned(index: int)
signal minion_killed(index: int)
## 곰왕이나 작은 곰이 사람을 쳤다(맞은 자리)
signal agent_hit(pos: Vector2)

const WEAPONS := ["harpoon", "spread", "cannon"]
const MINION_RADIUS := 0.8

var sim: FrostSim
var config: Dictionary
var weapons: Dictionary
var merc_config: Dictionary
var active := false
## 이긴 횟수. 곰왕 체력과 보상이 이만큼 커진다.
var wins := 0
var portal_pos: Vector2
var arena_center: Vector2
var arena_radius: float
var player_start: Vector2
var boss_start: Vector2
## 곰왕: {"pos", "hp", "max_hp", "contact"}
var boss := {}
## 작은 곰: [{"pos", "hp", "timer", "alive"}]
var minions: Array = []
## 내려찍기: [{"pos", "left", "done"}]
var slams: Array = []
## 지금 고른 무기와 다음 사격까지 남은 시간
var weapon := "harpoon"
var cooldown := 0.0
## 레이드가 끝난 뒤(이기든 지든) 입구가 다시 열리기까지 남은 초
var reopen_left := 0.0
var _portal_wait := 0.0
var _slam_timer := 0.0
var _summon_timer := 0.0
var _merc_timers := {}


func _init(frost_sim: FrostSim, balance: Dictionary, layout: Dictionary) -> void:
	sim = frost_sim
	config = balance.get("boss", {})
	weapons = balance.get("weapons", {})
	merc_config = balance.get("mercs", {})
	var arena: Dictionary = layout.get("raid_arena", {})
	if arena.is_empty():
		return
	portal_pos = FrostSim._vec(arena.portal)
	arena_center = FrostSim._vec(arena.center)
	arena_radius = float(arena.radius)
	player_start = FrostSim._vec(arena.player_start)
	boss_start = FrostSim._vec(arena.boss_start)


func is_available() -> bool:
	return not config.is_empty() and portal_pos != Vector2.ZERO


## 출발 조건: 작살총이 있고, 기지에 습격이 오는 중이 아니며, 이미 레이드 중이 아니고, 지난 레이드 뒤 입구가 다시 열렸다.
func can_start() -> bool:
	return is_available() and not active and reopen_left <= 0.0 and sim.gun_level > 0 and sim.raid.state != Raid.State.ATTACKING


## 가진 무기인가(작살총은 작살총 존, 나머지는 각 무기 존을 사야 한다).
func has_weapon(name: String) -> bool:
	match name:
		"harpoon":
			return sim.gun_level > 0
		"spread":
			var zone := sim.find_zone("weapon_spread")
			return zone != null and zone.level > 0
		"cannon":
			var zone := sim.find_zone("weapon_cannon")
			return zone != null and zone.level > 0
	return false


func select_weapon(name: String) -> void:
	if has_weapon(name):
		weapon = name


## 레이드에 데려갈 수 있는 용병 번호들(sim.workers)
func mercs() -> Array[int]:
	var result: Array[int] = []
	for i in sim.workers.size():
		var w := sim.workers[i]
		if w.role == "merc" and not w.retired:
			result.append(i)
	return result


## 입구 위에 portal_delay초 서 있으면 출발한다.
func tick_portal(delta: float) -> void:
	reopen_left = maxf(reopen_left - delta, 0.0)
	if not can_start() or sim.player.pos.distance_to(portal_pos) > float(sim.balance.purchase.zone_radius):
		_portal_wait = 0.0
		return
	_portal_wait += delta
	if _portal_wait >= float(config.portal_delay):
		_portal_wait = 0.0
		start()


func portal_progress() -> float:
	return clampf(_portal_wait / float(config.portal_delay), 0.0, 1.0) if is_available() else 0.0


func start() -> void:
	active = true
	var max_hp := int(float(config.hp) * (1.0 + float(config.hp_growth) * wins))
	boss = {"pos": boss_start, "hp": max_hp, "max_hp": max_hp, "contact": 0.0}
	minions.clear()
	slams.clear()
	_slam_timer = 0.0
	_summon_timer = 0.0
	cooldown = 0.0
	sim.player.pos = player_start
	sim.player.hp = sim.player.max_hp
	sim.player.dazed_left = 0.0
	var ids := mercs()
	for k in ids.size():
		var angle := TAU * k / maxf(ids.size(), 1.0)
		sim.workers[ids[k]].pos = player_start + Vector2.from_angle(angle) * 1.5
		sim.workers[ids[k]].hp = sim.workers[ids[k]].max_hp
	if not WEAPONS.has(weapon) or not has_weapon(weapon):
		weapon = "harpoon"
	started.emit()


func tick(delta: float) -> void:
	if not active:
		return
	cooldown = maxf(cooldown - delta, 0.0)
	_tick_boss(delta)
	_tick_slams(delta)
	_tick_minions(delta)
	_tick_mercs(delta)
	if boss.hp <= 0:
		_finish(true)
	elif sim.player.hp <= 0.0:
		_finish(false)


## 클릭한 자리 쪽으로 고른 무기를 쏜다. 쿨다운 중이면 false.
func shoot(target: Vector2) -> bool:
	if not active or cooldown > 0.0 or not has_weapon(weapon):
		return false
	var spec: Dictionary = weapons[weapon]
	cooldown = float(spec.cooldown)
	var from := sim.player.pos
	var dir := (target - from).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.UP
	var damage := _weapon_damage(weapon)
	var shots := int(spec.get("shots", 1))
	var spread := float(spec.get("angle", 0.0))
	for k in shots:
		var angle := (k - (shots - 1) / 2.0) * spread
		var d := dir.rotated(angle)
		var end := from + d * float(spec.range)
		var hit := _first_hit(from, end)
		var stop: Vector2 = hit.pos if hit.has("pos") else end
		if spec.has("splash"):
			_splash(stop, float(spec.splash), damage)
		elif hit.has("target"):
			_damage_target(hit.target, damage)
		shot.emit(from, stop, weapon)
	return true


func _weapon_damage(name: String) -> int:
	var spec: Dictionary = weapons[name]
	if spec.damage is Array:
		return int(spec.damage[clampi(sim.gun_level, 1, spec.damage.size()) - 1])
	return int(spec.damage)


## from→to 선분에 처음 닿는 적(곰왕 또는 작은 곰). {"target": "boss" 또는 작은 곰 번호, "pos": 닿은 자리}
func _first_hit(from: Vector2, to: Vector2) -> Dictionary:
	var best := {}
	var best_t := INF
	var candidates: Array = [["boss", boss.pos, float(config.radius)]] if boss.hp > 0 else []
	for i in minions.size():
		if minions[i].alive:
			candidates.append([i, minions[i].pos, MINION_RADIUS])
	var seg := to - from
	var length_sq := seg.length_squared()
	for c in candidates:
		var t := clampf((c[1] - from).dot(seg) / length_sq, 0.0, 1.0) if length_sq > 0.0 else 0.0
		var closest: Vector2 = from + seg * t
		if closest.distance_to(c[1]) <= c[2] and t < best_t:
			best_t = t
			best = {"target": c[0], "pos": closest}
	return best


func _splash(at: Vector2, radius: float, damage: int) -> void:
	if boss.hp > 0 and at.distance_to(boss.pos) <= radius + float(config.radius):
		_damage_target("boss", damage)
	for i in minions.size():
		if minions[i].alive and at.distance_to(minions[i].pos) <= radius:
			_damage_target(i, damage)


func _damage_target(target, damage: int) -> void:
	if typeof(target) == TYPE_STRING:
		boss.hp = maxi(boss.hp - damage, 0)
		boss_hit.emit(damage)
		return
	var m: Dictionary = minions[target]
	m.hp -= damage
	if m.hp <= 0 and m.alive:
		m.alive = false
		minion_killed.emit(target)


## 곰왕은 플레이어를 천천히 쫓고, 붙으면 할퀸다. 일정 간격으로 내려찍기와 작은 곰 부르기를 한다.
func _tick_boss(delta: float) -> void:
	var to_player: Vector2 = sim.player.pos - boss.pos
	if to_player.length() > float(config.contact_radius) * 0.8:
		boss.pos = _clamp_arena(boss.pos + to_player.limit_length(float(config.speed) * delta))
	if to_player.length() <= float(config.contact_radius):
		boss.contact += delta
		if boss.contact >= float(config.contact_interval):
			boss.contact = 0.0
			_hurt_player(float(config.contact_damage))
	else:
		boss.contact = 0.0
	_slam_timer += delta
	if _slam_timer >= float(config.slam_interval):
		_slam_timer = 0.0
		_warn_slams()
	_summon_timer += delta
	if _summon_timer >= float(config.summon_interval):
		_summon_timer = 0.0
		for k in int(config.summon_count):
			var spot: Vector2 = boss.pos + Vector2.from_angle(sim.rng.randf() * TAU) * 2.5
			minions.append({"pos": _clamp_arena(spot), "hp": int(config.minion_hp), "timer": 0.0, "alive": true})
			minion_spawned.emit(minions.size() - 1)


## 플레이어 자리 하나와 그 둘레 무작위 자리에 빨간 원을 띄운다(warning초 뒤 내려찍는다).
func _warn_slams() -> void:
	for k in int(config.slam_count):
		var spot := sim.player.pos
		if k > 0:
			spot += Vector2.from_angle(sim.rng.randf() * TAU) * sim.rng.randf_range(2.0, 5.0)
		slams.append({"pos": _clamp_arena(spot), "left": float(config.slam_warning), "done": false})
		slam_warned.emit(slams.size() - 1)


func _tick_slams(delta: float) -> void:
	for i in slams.size():
		var s: Dictionary = slams[i]
		if s.done:
			continue
		s.left -= delta
		if s.left > 0.0:
			continue
		s.done = true
		slammed.emit(i)
		var radius := float(config.slam_radius)
		if sim.player.pos.distance_to(s.pos) <= radius:
			_hurt_player(float(config.slam_damage))
		for id in mercs():
			if sim.workers[id].pos.distance_to(s.pos) <= radius:
				_hurt_merc(id, float(config.slam_damage))


## 작은 곰은 가장 가까운 사람(플레이어나 용병)에게 달려들어 문다.
func _tick_minions(delta: float) -> void:
	for m in minions:
		if not m.alive:
			continue
		var target_pos: Vector2 = sim.player.pos
		var target_merc := -1
		for id in mercs():
			if m.pos.distance_to(sim.workers[id].pos) < m.pos.distance_to(target_pos):
				target_pos = sim.workers[id].pos
				target_merc = id
		if m.pos.distance_to(target_pos) > 1.0:
			m.pos = m.pos.move_toward(target_pos, float(config.minion_speed) * delta)
			m.timer = 0.0
			continue
		m.timer += delta
		if m.timer >= 1.0:
			m.timer = 0.0
			if target_merc == -1:
				_hurt_player(float(config.minion_damage))
			else:
				_hurt_merc(target_merc, float(config.minion_damage))


## 용병은 곰왕 둘레 자기 자리로 가서, 사거리 안의 가장 가까운 적을 쏜다.
func _tick_mercs(delta: float) -> void:
	var ids := mercs()
	for k in ids.size():
		var w := sim.workers[ids[k]]
		var angle := TAU * k / maxf(ids.size(), 1.0)
		var post: Vector2 = boss.pos + Vector2.from_angle(angle) * float(merc_config.keep_distance)
		w.pos = _clamp_arena(w.pos.move_toward(post, float(merc_config.speed) * delta))
		_merc_timers[ids[k]] = _merc_timers.get(ids[k], 0.0) + delta
		if _merc_timers[ids[k]] < float(merc_config.interval):
			continue
		var target = null
		var target_pos := Vector2.ZERO
		var best := float(merc_config.range)
		for i in minions.size():
			if minions[i].alive and w.pos.distance_to(minions[i].pos) < best:
				best = w.pos.distance_to(minions[i].pos)
				target = i
				target_pos = minions[i].pos
		if target == null and w.pos.distance_to(boss.pos) <= float(merc_config.range):
			target = "boss"
			target_pos = boss.pos
		if target == null:
			continue
		_merc_timers[ids[k]] = 0.0
		_damage_target(target, int(merc_config.damage))
		shot.emit(w.pos, target_pos, "merc")


func _hurt_player(damage: float) -> void:
	sim.player.hp = maxf(sim.player.hp - damage, 0.0)
	agent_hit.emit(sim.player.pos)


func _hurt_merc(index: int, damage: float) -> void:
	agent_hit.emit(sim.workers[index].pos)
	sim._hurt_worker(index, damage)


func _clamp_arena(p: Vector2) -> Vector2:
	var offset := p - arena_center
	return arena_center + offset.limit_length(arena_radius)


## 레이드를 끝내고 기지 입구 옆으로 돌아온다. 이기면 돈과 보석을 받고 곰왕이 다음엔 더 강해진다.
func _finish(won: bool) -> void:
	active = false
	reopen_left = float(config.get("reopen_delay", 0.0))
	var reward := 0
	if won:
		reward = int(float(config.reward) * (1.0 + float(config.reward_growth) * wins))
		wins += 1
		sim.money += reward
		sim.total_earned += reward
		for k in int(config.gems):
			if not sim.player.stack.push("gem"):
				sim.money += int(sim.balance.items.gem.price)
	minions.clear()
	slams.clear()
	var back := portal_pos + Vector2(2.0, -0.6)  # 입구 옆, 남쪽 방벽 안쪽
	sim.player.pos = back
	sim.player.hp = sim.player.max_hp
	sim.player.dazed_left = 0.0
	for id in mercs():
		sim.workers[id].pos = back
	ended.emit(won, reward)
