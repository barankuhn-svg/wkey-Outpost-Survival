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
