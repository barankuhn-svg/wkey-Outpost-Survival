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
