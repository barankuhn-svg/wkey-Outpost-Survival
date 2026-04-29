--!strict
local Players = game:GetService('Players')
local DataStoreService = game:GetService('DataStoreService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')

local Config = require(ReplicatedStorage.Shared.Config)

local PlayerDataStore = DataStoreService:GetDataStore('PlayerData_v1')

type PlayerData = {
  coins: number,
  hpUpgrades: number,
  damageUpgrades: number,
  regenUpgrades: number,
}

local playerData: { [number]: PlayerData } = {}
local playerDataLoaded: { [number]: boolean } = {}

local function getDefaultData(): PlayerData
  return {
    coins = 0,
    hpUpgrades = 0,
    damageUpgrades = 0,
    regenUpgrades = 0,
  }
end

local function loadData(player: Player)
  playerDataLoaded[player.UserId] = false
  local success, data = pcall(function()
    return PlayerDataStore:GetAsync('player_' .. player.UserId)
  end)
  if success and data then
    playerData[player.UserId] = data :: PlayerData
  else
    playerData[player.UserId] = getDefaultData()
  end
  playerDataLoaded[player.UserId] = true
end

local function saveData(player: Player)
  local data = playerData[player.UserId]
  if not data then
    return
  end
  pcall(function()
    PlayerDataStore:SetAsync('player_' .. player.UserId, data)
  end)
end

Players.PlayerRemoving:Connect(function(player: Player)
  saveData(player)
  playerData[player.UserId] = nil
  playerDataLoaded[player.UserId] = nil
end)

-- RemoteEvents Setup
local Remotes = Instance.new('Folder')
Remotes.Name = 'Remotes'
Remotes.Parent = ReplicatedStorage

local GetDataRemote = Instance.new('RemoteFunction')
GetDataRemote.Name = 'GetData'
GetDataRemote.Parent = Remotes

local UpgradeStatRemote = Instance.new('RemoteEvent')
UpgradeStatRemote.Name = 'UpgradeStat'
UpgradeStatRemote.Parent = Remotes

local StartRoundRemote = Instance.new('RemoteEvent')
StartRoundRemote.Name = 'StartRound'
StartRoundRemote.Parent = Remotes

-- GetData: returns player data to client
GetDataRemote.OnServerInvoke = function(player: Player)
  if not playerDataLoaded[player.UserId] then
    loadData(player)
  end
  return playerData[player.UserId] or getDefaultData()
end

-- UpgradeStat: handles stat upgrade requests
UpgradeStatRemote.OnServerEvent:Connect(function(player: Player, stat: string)
  local data = playerData[player.UserId]
  if not data then
    return
  end

  local upgradeCount = 0
  if stat == 'hp' then
    upgradeCount = data.hpUpgrades
  elseif stat == 'damage' then
    upgradeCount = data.damageUpgrades
  elseif stat == 'regen' then
    upgradeCount = data.regenUpgrades
  end

  local cost = Config.UPGRADE_BASE_COST + (upgradeCount * Config.UPGRADE_COST_MULTIPLIER)

  if data.coins < cost then
    return
  end

  data.coins -= cost

  if stat == 'hp' then
    data.hpUpgrades += 1
  elseif stat == 'damage' then
    data.damageUpgrades += 1
  elseif stat == 'regen' then
    data.regenUpgrades += 1
  end

  saveData(player)
end)

-- ENEMY SYSTEM
local ServerStorage = game:GetService('ServerStorage')
local RunService = game:GetService('RunService')
local HttpService = game:GetService('HttpService')

local waterGunTemplate = workspace:FindFirstChild('Water Gun')
if waterGunTemplate then
  waterGunTemplate.Parent = game:GetService('ServerStorage')
end

local EnemyRigsFolder = ServerStorage:WaitForChild('EnemyRigs')
local enemyRigTemplates: { Model } = {}
for _, rig in EnemyRigsFolder:GetChildren() do
  if rig:IsA('Model') then
    table.insert(enemyRigTemplates, rig)
  end
end

type EnemyTier = 'Weak' | 'Medium' | 'Strong' | 'Boss'

type EnemyState = {
  id: string,
  model: Model,
  humanoid: Humanoid,
  rootPart: BasePart,
  hp: number,
  maxHp: number,
  damage: number,
  tier: EnemyTier,
  walkAnimTrack: AnimationTrack?,
  punchAnimTrack: AnimationTrack?,
  lastAttackTime: number,
}

local activeEnemies: { [string]: EnemyState } = {}
local replicationData: { [string]: { px: number, py: number, pz: number, hp: number, maxHp: number } } =
  {}
local enemyLastHitBy: { [string]: number } = {}
local playerKills: { [number]: number } = {}

local spawnRate = 1
local maxEnemies = 20
local roundActive = false
local roundStartTime = 0

-- Replication RemoteEvent
local EnemyReplicateRemote = Instance.new('RemoteEvent')
EnemyReplicateRemote.Name = 'EnemyReplicate'
EnemyReplicateRemote.Parent = Remotes

local EnemyDiedRemote = Instance.new('RemoteEvent')
EnemyDiedRemote.Name = 'EnemyDied'
EnemyDiedRemote.Parent = Remotes

local CoinUpdateRemote = Instance.new('RemoteEvent')
CoinUpdateRemote.Name = 'CoinUpdate'
CoinUpdateRemote.Parent = Remotes

local FloatingCoinRemote = Instance.new('RemoteEvent')
FloatingCoinRemote.Name = 'FloatingCoin'
FloatingCoinRemote.Parent = Remotes

local function getScaleFactor(): number
  local elapsed = tick() - roundStartTime
  return 1 + (elapsed / Config.ENEMY_SCALE_INTERVAL)
end

local function getTierForTime(): EnemyTier
  local elapsed = tick() - roundStartTime
  if elapsed < 60 then
    return 'Weak'
  elseif elapsed < 120 then
    return 'Medium'
  elseif elapsed < 180 then
    return 'Strong'
  else
    return 'Boss'
  end
end

local function getRandomRig(): Model
  local idx = math.random(1, #enemyRigTemplates)
  return enemyRigTemplates[idx]:Clone()
end

local function getRandomWalkAnim(): Animation
  local anim = Instance.new('Animation')
  anim.AnimationId = 'rbxassetid://'
    .. tostring(Config.ANIM_WALK[math.random(1, #Config.ANIM_WALK)])
  return anim
end

local function getRandomPunchAnim(): Animation
  local anim = Instance.new('Animation')
  anim.AnimationId = 'rbxassetid://'
    .. tostring(Config.ANIM_PUNCH[math.random(1, #Config.ANIM_PUNCH)])
  return anim
end

local function spawnEnemy()
  if not roundActive then
    return
  end
  local enemyCount = 0
  for _ in activeEnemies do
    enemyCount += 1
  end
  if enemyCount >= maxEnemies then
    return
  end

  local tier = getTierForTime()
  local factor = getScaleFactor()
  local baseStats = Config.ENEMY_STATS[tier]
  local hp = math.floor(baseStats.HP * factor)
  local damage = math.floor(baseStats.Damage * factor)

  local model = getRandomRig()
  local humanoid = model:FindFirstChildOfClass('Humanoid')
  if not humanoid then
    model:Destroy()
    return
  end

  local rootPart = model:FindFirstChild('HumanoidRootPart') :: BasePart
  if not rootPart then
    model:Destroy()
    return
  end

  -- Random spawn position anywhere on arena
  local spawnX = math.random(-35, 35)
  local spawnZ = math.random(-35, 35)
  model.Parent = workspace

  for _, descendant in model:GetDescendants() do
    if descendant:IsA('BillboardGui') then
      descendant:Destroy()
      continue
    end
    if descendant:IsA('BasePart') then
      descendant.Anchored = false
      descendant.CanCollide = false
      descendant.Massless = false
      continue
    end
    if
      descendant:IsA('BodyMover')
      or descendant:IsA('AlignPosition')
      or descendant:IsA('AlignOrientation')
      or descendant:IsA('LinearVelocity')
      or descendant:IsA('AngularVelocity')
      or descendant:IsA('VectorForce')
    then
      descendant:Destroy()
    end
  end

  local arenaFloor: BasePart? = nil
  local arenaFolder = workspace:FindFirstChild('Arena')
  if arenaFolder then
    local floorCandidate = arenaFolder:FindFirstChild('ArenaFloor')
    if floorCandidate and floorCandidate:IsA('BasePart') then
      arenaFloor = floorCandidate
    end
  end
  local floorTopY = 0
  if arenaFloor then
    floorTopY = arenaFloor.Position.Y + (arenaFloor.Size.Y * 0.5)
  end
  local _, modelSize = model:GetBoundingBox()
  local spawnY = floorTopY + (modelSize.Y * 0.5) + 0.05
  model:PivotTo(CFrame.new(spawnX, spawnY, spawnZ))

  humanoid.MaxHealth = hp
  humanoid.Health = hp

  -- Animations
  local animator = humanoid:FindFirstChildOfClass('Animator') or Instance.new('Animator')
  animator.Parent = humanoid

  local walkTrack: AnimationTrack? = nil
  local walkSuccess, walkResult = pcall(function()
    return animator:LoadAnimation(getRandomWalkAnim())
  end)
  if walkSuccess and walkResult then
    walkTrack = walkResult :: AnimationTrack
    walkTrack.Looped = true
    walkTrack:Play()
  end

  local punchTrack: AnimationTrack? = nil
  local punchSuccess, punchResult = pcall(function()
    return animator:LoadAnimation(getRandomPunchAnim())
  end)
  if punchSuccess and punchResult then
    punchTrack = punchResult :: AnimationTrack
  end

  local id = HttpService:GenerateGUID(false)

  local enemyState: EnemyState = {
    id = id,
    model = model,
    humanoid = humanoid,
    rootPart = rootPart,
    hp = hp,
    maxHp = hp,
    damage = damage,
    tier = tier,
    walkAnimTrack = walkTrack,
    punchAnimTrack = punchTrack,
    lastAttackTime = 0,
  }

  activeEnemies[id] = enemyState

  -- Death handling
  humanoid.Died:Connect(function()
    if enemyState.walkAnimTrack then
      enemyState.walkAnimTrack:Stop()
    end
    if enemyState.punchAnimTrack then
      enemyState.punchAnimTrack:Stop()
    end

    local killerUserId = enemyLastHitBy[id]
    if killerUserId then
      playerKills[killerUserId] = (playerKills[killerUserId] or 0) + 1
    end

    local reward = Config.COIN_REWARD[tier]
    for _, p in Players:GetPlayers() do
      local pdata = playerData[p.UserId]
      if pdata then
        pdata.coins += reward
        CoinUpdateRemote:FireClient(p, pdata.coins)
        FloatingCoinRemote:FireAllClients(rootPart.Position, reward)
      end
    end
    EnemyDiedRemote:FireAllClients(id)
    activeEnemies[id] = nil
    replicationData[id] = nil
    enemyLastHitBy[id] = nil
    model:Destroy()
  end)
end

-- Enemy AI loop
local function updateEnemyAI()
  for id, enemy in activeEnemies do
    if not enemy.model.Parent then
      activeEnemies[id] = nil
      continue
    end

    -- Find nearest player
    local nearestPlayer: Player? = nil
    local nearestDist = math.huge
    for _, p in Players:GetPlayers() do
      local char = p.Character
      if not char then
        continue
      end
      local root = char:FindFirstChild('HumanoidRootPart') :: BasePart
      if not root then
        continue
      end
      local dist = (root.Position - enemy.rootPart.Position).Magnitude
      if dist < nearestDist then
        nearestDist = dist
        nearestPlayer = p
      end
    end

    if nearestPlayer then
      local char = nearestPlayer.Character
      if char then
        local targetRoot = char:FindFirstChild('HumanoidRootPart') :: BasePart
        if targetRoot then
          enemy.humanoid:MoveTo(targetRoot.Position)
          -- Attack if close
          if nearestDist < 6 then
            local playerHumanoid = char:FindFirstChildOfClass('Humanoid')
            local now = tick()
            if playerHumanoid and (now - enemy.lastAttackTime) >= 0.9 then
              enemy.lastAttackTime = now
              if enemy.walkAnimTrack and enemy.walkAnimTrack.IsPlaying then
                enemy.walkAnimTrack:Stop()
              end
              if enemy.punchAnimTrack then
                enemy.punchAnimTrack:Stop()
                enemy.punchAnimTrack:Play(0.05, 1, 1)
              end
              playerHumanoid:TakeDamage(enemy.damage)
            end
          elseif enemy.walkAnimTrack and not enemy.walkAnimTrack.IsPlaying then
            enemy.walkAnimTrack:Play()
          end
        end
      end
    end

    -- Update replication data
    replicationData[id] = {
      px = enemy.rootPart.Position.X,
      py = enemy.rootPart.Position.Y,
      pz = enemy.rootPart.Position.Z,
      hp = enemy.humanoid.Health,
      maxHp = enemy.humanoid.MaxHealth,
    }
  end
end

-- 20Hz Replication
local replicationAccum = 0
RunService.Heartbeat:Connect(function(dt: number)
  if not roundActive then
    return
  end

  replicationAccum += dt
  updateEnemyAI()

  if replicationAccum >= (1 / Config.REPLICATION_RATE) then
    replicationAccum = 0
    if next(replicationData) then
      EnemyReplicateRemote:FireAllClients(replicationData)
    end
  end
end)

-- Spawn loop
local spawnAccum = 0
RunService.Heartbeat:Connect(function(dt: number)
  if not roundActive then
    return
  end
  spawnAccum += dt
  if spawnAccum >= (1 / spawnRate) then
    spawnAccum = 0
    spawnEnemy()
  end
end)

-- Passive coin loop
local coinAccum = 0
RunService.Heartbeat:Connect(function(dt: number)
  if not roundActive then
    return
  end
  coinAccum += dt
  if coinAccum >= 1 then
    coinAccum = 0
    for _, p in Players:GetPlayers() do
      local pdata = playerData[p.UserId]
      if pdata then
        pdata.coins += Config.PASSIVE_COINS_PER_SECOND
        CoinUpdateRemote:FireClient(p, pdata.coins)
      end
    end
  end
end)

-- WATER GUN SYSTEM
local BeamUpdateRemote = Instance.new('RemoteEvent')
BeamUpdateRemote.Name = 'BeamUpdate'
BeamUpdateRemote.Parent = Remotes

local function getPlayerDamage(player: Player): number
  local pdata = playerData[player.UserId]
  if not pdata then
    return Config.DEFAULT_DAMAGE
  end
  return Config.DEFAULT_DAMAGE + (pdata.damageUpgrades * Config.DAMAGE_PER_UPGRADE)
end

local function getNearestEnemy(origin: Vector3): (string?, EnemyState?)
  local nearestId: string? = nil
  local nearestEnemy: EnemyState? = nil
  local nearestDist = math.huge
  for id, enemy in activeEnemies do
    if not enemy.model.Parent then
      continue
    end
    local dist = (enemy.rootPart.Position - origin).Magnitude
    if dist < nearestDist and dist <= Config.WATER_GUN_RANGE then
      nearestDist = dist
      nearestId = id
      nearestEnemy = enemy
    end
  end
  return nearestId, nearestEnemy
end

-- Water gun fire loop per player
local playerGunTimers: { [number]: number } = {}

RunService.Heartbeat:Connect(function(dt: number)
  if not roundActive then
    return
  end
  for _, player in Players:GetPlayers() do
    local char = player.Character
    if not char then
      continue
    end
    local root = char:FindFirstChild('HumanoidRootPart') :: BasePart
    if not root then
      continue
    end

    local uid = player.UserId
    playerGunTimers[uid] = (playerGunTimers[uid] or 0) + dt

    if playerGunTimers[uid] >= (1 / Config.WATER_GUN_FIRE_RATE) then
      playerGunTimers[uid] = 0

      local beamOrigin = root.Position
      local waterGun = char:FindFirstChild('Water Gun')
      if waterGun and waterGun:IsA('Model') then
        local gunPrimaryPart = waterGun.PrimaryPart or waterGun:FindFirstChildWhichIsA('BasePart')
        if gunPrimaryPart then
          beamOrigin = gunPrimaryPart.Position
        end
      end

      local id, enemy = getNearestEnemy(beamOrigin)
      local humanoidRootPart = root
      local waterGun = char:FindFirstChild('Water Gun')
      if waterGun and enemy then
        local gunPart = waterGun.PrimaryPart
        if gunPart then
          local weld = humanoidRootPart:FindFirstChildOfClass('Weld')
          if weld then
            local targetPos = enemy.rootPart.Position
            local gunWorldPos = humanoidRootPart.CFrame * CFrame.new(0, 4, 0.5)
            local lookDir = (targetPos - gunWorldPos.Position)
            lookDir = Vector3.new(lookDir.X, 0, lookDir.Z).Unit
            local angle = math.atan2(-lookDir.X, -lookDir.Z) + math.pi * 0.5
            weld.C0 = CFrame.new(0, 4, 0.5) * CFrame.Angles(0, angle, 0)
          end
        end
      end

      if id and enemy then
        local dmg = getPlayerDamage(player)
        enemyLastHitBy[id] = uid
        enemy.humanoid:TakeDamage(dmg)
        BeamUpdateRemote:FireAllClients(beamOrigin, enemy.rootPart.Position)
      else
        BeamUpdateRemote:FireAllClients(nil, nil)
      end
    end
  end
end)

Players.PlayerRemoving:Connect(function(player: Player)
  playerGunTimers[player.UserId] = nil
end)

-- KillAll + SpawnControls + RoundStarted Remote
local KillAllRemote = Instance.new('RemoteEvent')
KillAllRemote.Name = 'KillAll'
KillAllRemote.Parent = Remotes

local SetSpawnRateRemote = Instance.new('RemoteEvent')
SetSpawnRateRemote.Name = 'SetSpawnRate'
SetSpawnRateRemote.Parent = Remotes

local RoundStartedRemote = Instance.new('RemoteEvent')
RoundStartedRemote.Name = 'RoundStarted'
RoundStartedRemote.Parent = Remotes

KillAllRemote.OnServerEvent:Connect(function(_player: Player)
  for _, enemy in activeEnemies do
    if enemy.model.Parent then
      enemy.humanoid.Health = 0
    end
  end
end)

SetSpawnRateRemote.OnServerEvent:Connect(
  function(_player: Player, newSpawnRate: number, newMaxEnemies: number)
    spawnRate = newSpawnRate
    maxEnemies = newMaxEnemies
  end
)

-- Fire RoundStarted to all clients when round begins
StartRoundRemote.OnServerEvent:Connect(function(_player: Player)
  roundActive = true
  roundStartTime = tick()
  for _, p in Players:GetPlayers() do
    local pdata = playerData[p.UserId]
    if pdata then
      CoinUpdateRemote:FireClient(p, pdata.coins)
    end
    local char = p.Character
    if char then
      local humanoid = char:FindFirstChildOfClass('Humanoid')
      if humanoid then
        local upgrades = pdata and pdata.hpUpgrades or 0
        humanoid.MaxHealth = Config.DEFAULT_HP + (upgrades * Config.HP_PER_UPGRADE)
        humanoid.Health = humanoid.MaxHealth
      end
    end
  end
  RoundStartedRemote:FireAllClients()
end)

-- DEATH SCREEN
local PlayerDiedRemote = Instance.new('RemoteEvent')
PlayerDiedRemote.Name = 'PlayerDied'
PlayerDiedRemote.Parent = Remotes

local function onPlayerDied(
  player: Player,
  elapsed: number,
  coins: number,
  kills: number,
  difficulty: string
)
  PlayerDiedRemote:FireClient(player, elapsed, coins, kills, difficulty)
end

-- Track kills per player

Players.PlayerAdded:Connect(function(player: Player)
  loadData(player)
  playerKills[player.UserId] = 0
  player.CharacterAdded:Connect(function(character: Model)
    local humanoid = character:WaitForChild('Humanoid') :: Humanoid
    local humanoidRootPart = character:WaitForChild('HumanoidRootPart') :: BasePart
    local pdata = playerData[player.UserId]
    if pdata then
      humanoid.MaxHealth = Config.DEFAULT_HP + (pdata.hpUpgrades * Config.HP_PER_UPGRADE)
      humanoid.Health = humanoid.MaxHealth
    end

    local waterGunModelTemplate = ServerStorage:FindFirstChild('Water Gun')
    if waterGunModelTemplate and waterGunModelTemplate:IsA('Model') then
      local clonedGun = waterGunModelTemplate:Clone()
      local gunPrimaryPart: BasePart? = nil
      local largestVolume = 0
      for _, descendant in clonedGun:GetDescendants() do
        if descendant:IsA('BasePart') then
          local volume = descendant.Size.X * descendant.Size.Y * descendant.Size.Z
          if volume > largestVolume then
            largestVolume = volume
            gunPrimaryPart = descendant
          end
        end
      end
      if gunPrimaryPart then
        clonedGun.PrimaryPart = gunPrimaryPart
      end
      if gunPrimaryPart then
        for _, descendant in clonedGun:GetDescendants() do
          if descendant:IsA('BasePart') and descendant ~= gunPrimaryPart then
            local wc = Instance.new('WeldConstraint')
            wc.Part0 = gunPrimaryPart
            wc.Part1 = descendant
            wc.Parent = gunPrimaryPart
          end
        end

        for _, descendant in clonedGun:GetDescendants() do
          if descendant:IsA('BasePart') then
            descendant.Anchored = false
            descendant.CanCollide = false
            descendant.Massless = true
          end
        end

        clonedGun.Parent = character
        clonedGun:PivotTo(humanoidRootPart.CFrame * CFrame.new(0, 4, 0.5))

        local gunWeld = Instance.new('Weld')
        gunWeld.Part0 = humanoidRootPart
        gunWeld.Part1 = gunPrimaryPart
        gunWeld.C0 = CFrame.new(0, 4, 0.5)
        gunWeld.Parent = humanoidRootPart
      end
    end

    humanoid.Died:Connect(function()
      if not roundActive then
        return
      end
      roundActive = false
      local elapsed = tick() - roundStartTime
      local pdata2 = playerData[player.UserId]
      local coins = pdata2 and pdata2.coins or 0
      local kills = playerKills[player.UserId] or 0
      local currentDiff = Config.DIFFICULTY[1]
      for _, diff in Config.DIFFICULTY do
        if elapsed >= diff.time then
          currentDiff = diff
        end
      end
      for id, enemy in activeEnemies do
        if enemy.model.Parent then
          enemy.model:Destroy()
        end
        activeEnemies[id] = nil
        replicationData[id] = nil
        enemyLastHitBy[id] = nil
      end
      onPlayerDied(player, elapsed, coins, kills, currentDiff.label)
    end)
  end)
end)

Players.PlayerRemoving:Connect(function(player: Player)
  playerKills[player.UserId] = nil
end)

-- REGEN SYSTEM
local regenAccum: { [number]: number } = {}

RunService.Heartbeat:Connect(function(dt: number)
  if not roundActive then
    return
  end
  for _, player in Players:GetPlayers() do
    local char = player.Character
    if not char then
      continue
    end
    local humanoid = char:FindFirstChildOfClass('Humanoid')
    if not humanoid then
      continue
    end
    if humanoid.Health <= 0 then
      continue
    end

    local uid = player.UserId
    regenAccum[uid] = (regenAccum[uid] or 0) + dt

    if regenAccum[uid] >= 1 then
      regenAccum[uid] = 0
      local pdata = playerData[uid]
      if pdata then
        local regenAmount = Config.DEFAULT_REGEN + (pdata.regenUpgrades * Config.REGEN_PER_UPGRADE)
        local newHp = math.min(humanoid.Health + regenAmount, humanoid.MaxHealth)
        humanoid.Health = newHp
      end
    end
  end
end)

Players.PlayerRemoving:Connect(function(player: Player)
  regenAccum[player.UserId] = nil
end)
