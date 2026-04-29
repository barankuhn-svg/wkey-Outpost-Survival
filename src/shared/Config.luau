--!strict
local Config = {}

Config.ARENA_SIZE = 75

Config.DEFAULT_HP = 50
Config.DEFAULT_DAMAGE = 20
Config.DEFAULT_REGEN = 0.5

Config.HP_PER_UPGRADE = 10
Config.DAMAGE_PER_UPGRADE = 5
Config.REGEN_PER_UPGRADE = 0.5

Config.UPGRADE_BASE_COST = 1
Config.UPGRADE_COST_MULTIPLIER = 2

Config.PASSIVE_COINS_PER_SECOND = 1

Config.COIN_REWARD = {
  Weak = 2,
  Medium = 5,
  Strong = 15,
  Boss = 50,
}

Config.ENEMY_STATS = {
  Weak = { HP = 10, Damage = 1 },
  Medium = { HP = 100, Damage = 15 },
  Strong = { HP = 500, Damage = 50 },
  Boss = { HP = 1000, Damage = 300 },
}

Config.ENEMY_SCALE_INTERVAL = 60

Config.WATER_GUN_FIRE_RATE = 1
Config.WATER_GUN_RANGE = 200

Config.REPLICATION_RATE = 20

Config.DIFFICULTY = {
  { time = 0, label = 'Easy', color = Color3.fromRGB(0, 200, 0) },
  { time = 60, label = 'Medium', color = Color3.fromRGB(255, 200, 0) },
  { time = 120, label = 'Hard', color = Color3.fromRGB(255, 120, 0) },
  { time = 180, label = 'Extreme', color = Color3.fromRGB(200, 0, 0) },
  { time = 240, label = 'ULTRA', color = Color3.fromRGB(180, 0, 255) },
}

Config.ANIM_WALK = {
  83941379162040,
  72394126997051,
  109712313387922,
  93718630674138,
}

Config.ANIM_PUNCH = {
  84288441055806,
  123279309008951,
  126415435650868,
}

return Config
