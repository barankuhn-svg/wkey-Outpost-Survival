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

local function getDefaultData(): PlayerData
  return {
    coins = 0,
    hpUpgrades = 0,
    damageUpgrades = 0,
    regenUpgrades = 0,
  }
end

local function loadData(player: Player)
  local success, data = pcall(function()
    return PlayerDataStore:GetAsync('player_' .. player.UserId)
  end)
  if success and data then
    playerData[player.UserId] = data :: PlayerData
  else
    playerData[player.UserId] = getDefaultData()
  end
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

Players.PlayerAdded:Connect(function(player: Player)
  loadData(player)
end)

Players.PlayerRemoving:Connect(function(player: Player)
  saveData(player)
  playerData[player.UserId] = nil
end)

-- RemoteEvents Setup
local ReplicatedStorage = game:GetService('ReplicatedStorage')

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
}

local activeEnemies: { [string]: EnemyState } = {}
local replicationData: { [string]: { px: number, py: number, pz: number, hp: number, maxHp: number } } =
  {}

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
  if #activeEnemies >= maxEnemies then
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

  -- Random spawn position on arena edge
  local angle = math.random() * math.pi * 2
  local radius = 30
  local spawnPos = Vector3.new(math.cos(angle) * radius, 2, math.sin(angle) * radius)
  model:PivotTo(CFrame.new(spawnPos))
  model.Parent = workspace

  humanoid.MaxHealth = hp
  humanoid.Health = hp

  -- Animations
  local animator = humanoid:FindFirstChildOfClass('Animator') or Instance.new('Animator')
  animator.Parent = humanoid

  local walkTrack = animator:LoadAnimation(getRandomWalkAnim())
  walkTrack:Play()

  local punchTrack = animator:LoadAnimation(getRandomPunchAnim())

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
  }

  activeEnemies[id] = enemyState

  -- Death handling
  humanoid.Died:Connect(function()
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
          if nearestDist < 5 then
            local playerHumanoid = char:FindFirstChildOfClass('Humanoid')
            if playerHumanoid then
              playerHumanoid:TakeDamage(enemy.damage * (1 / 20))
            end
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

-- StartRound handler
StartRoundRemote.OnServerEvent:Connect(function(player: Player)
  roundActive = true
  roundStartTime = tick()
end)

-- Player death handling
Players.PlayerAdded:Connect(function(player: Player)
  player.CharacterAdded:Connect(function(character: Model)
    local humanoid = character:WaitForChild('Humanoid') :: Humanoid
    local pdata = playerData[player.UserId]
    if pdata then
      humanoid.MaxHealth = Config.DEFAULT_HP + (pdata.hpUpgrades * Config.HP_PER_UPGRADE)
      humanoid.Health = humanoid.MaxHealth
    end
    humanoid.Died:Connect(function()
      roundActive = false
      for id, enemy in activeEnemies do
        if enemy.model.Parent then
          enemy.model:Destroy()
        end
        activeEnemies[id] = nil
        replicationData[id] = nil
      end
    end)
  end)
end)
