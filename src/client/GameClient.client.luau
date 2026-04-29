--!strict
local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')

local player = Players.LocalPlayer
local playerGui = player.PlayerGui

-- Wait for Remotes
local Remotes = ReplicatedStorage:WaitForChild('Remotes')
local GetDataRemote = Remotes:WaitForChild('GetData') :: RemoteFunction
local UpgradeStatRemote = Remotes:WaitForChild('UpgradeStat') :: RemoteEvent
local StartRoundRemote = Remotes:WaitForChild('StartRound') :: RemoteEvent

local Config = require(ReplicatedStorage.Shared.Config)

-- Fetch data
local function fetchData()
  return GetDataRemote:InvokeServer()
end

-- Build Menu UI
local function buildMenuUI()
  local data = fetchData()

  local screenGui = Instance.new('ScreenGui')
  screenGui.Name = 'MenuGui'
  screenGui.ResetOnSpawn = false
  screenGui.IgnoreGuiInset = true
  screenGui.Parent = playerGui

  -- Background
  local bg = Instance.new('Frame')
  bg.Name = 'Background'
  bg.Size = UDim2.fromScale(1, 1)
  bg.Position = UDim2.fromScale(0, 0)
  bg.BackgroundColor3 = Color3.fromRGB(15, 20, 35)
  bg.BorderSizePixel = 0
  bg.Parent = screenGui

  -- Coins display top
  local coinsLabel = Instance.new('TextLabel')
  coinsLabel.Name = 'CoinsLabel'
  coinsLabel.Size = UDim2.fromScale(0.3, 0.06)
  coinsLabel.Position = UDim2.fromScale(0.35, 0.02)
  coinsLabel.BackgroundTransparency = 1
  coinsLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
  coinsLabel.TextScaled = true
  coinsLabel.Font = Enum.Font.GothamBold
  coinsLabel.Text = '🪙 ' .. tostring(data.coins)
  coinsLabel.Parent = bg

  -- Stats container
  local statsFrame = Instance.new('Frame')
  statsFrame.Name = 'StatsFrame'
  statsFrame.Size = UDim2.fromScale(0.5, 0.4)
  statsFrame.Position = UDim2.fromScale(0.25, 0.3)
  statsFrame.BackgroundColor3 = Color3.fromRGB(25, 30, 50)
  statsFrame.BorderSizePixel = 0
  statsFrame.Parent = bg

  local corner = Instance.new('UICorner')
  corner.CornerRadius = UDim.new(0, 12)
  corner.Parent = statsFrame

  local layout = Instance.new('UIListLayout')
  layout.Padding = UDim.new(0, 8)
  layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
  layout.Parent = statsFrame

  local padding = Instance.new('UIPadding')
  padding.PaddingTop = UDim.new(0, 12)
  padding.PaddingBottom = UDim.new(0, 12)
  padding.PaddingLeft = UDim.new(0, 16)
  padding.PaddingRight = UDim.new(0, 16)
  padding.Parent = statsFrame

  local stats = {
    {
      key = 'hp',
      label = '❤️  HP',
      value = Config.DEFAULT_HP + (data.hpUpgrades * Config.HP_PER_UPGRADE),
    },
    {
      key = 'damage',
      label = '⚔️  Damage',
      value = Config.DEFAULT_DAMAGE + (data.damageUpgrades * Config.DAMAGE_PER_UPGRADE),
    },
    {
      key = 'regen',
      label = '💚  Regen',
      value = Config.DEFAULT_REGEN + (data.regenUpgrades * Config.REGEN_PER_UPGRADE),
    },
  }

  for _, stat in stats do
    local row = Instance.new('Frame')
    row.Name = stat.key .. 'Row'
    row.Size = UDim2.new(1, 0, 0, 44)
    row.BackgroundTransparency = 1
    row.Parent = statsFrame

    local rowLayout = Instance.new('UIListLayout')
    rowLayout.FillDirection = Enum.FillDirection.Horizontal
    rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    rowLayout.Padding = UDim.new(0, 8)
    rowLayout.Parent = row

    local nameLabel = Instance.new('TextLabel')
    nameLabel.Size = UDim2.new(0.5, 0, 1, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    nameLabel.TextScaled = true
    nameLabel.Font = Enum.Font.Gotham
    nameLabel.Text = stat.label
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Parent = row

    local valueLabel = Instance.new('TextLabel')
    valueLabel.Name = 'Value'
    valueLabel.Size = UDim2.new(0.25, 0, 1, 0)
    valueLabel.BackgroundTransparency = 1
    valueLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    valueLabel.TextScaled = true
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.Text = tostring(stat.value)
    valueLabel.Parent = row

    local upgradeCount = 0
    if stat.key == 'hp' then
      upgradeCount = data.hpUpgrades
    elseif stat.key == 'damage' then
      upgradeCount = data.damageUpgrades
    elseif stat.key == 'regen' then
      upgradeCount = data.regenUpgrades
    end
    local cost = Config.UPGRADE_BASE_COST + (upgradeCount * Config.UPGRADE_COST_MULTIPLIER)

    local plusBtn = Instance.new('TextButton')
    plusBtn.Name = 'PlusBtn'
    plusBtn.Size = UDim2.new(0.2, 0, 0.8, 0)
    plusBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 100)
    plusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    plusBtn.TextScaled = true
    plusBtn.Font = Enum.Font.GothamBold
    plusBtn.Text = '+' .. tostring(cost) .. '🪙'
    plusBtn.Parent = row

    local btnCorner = Instance.new('UICorner')
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent = plusBtn

    plusBtn.MouseButton1Click:Connect(function()
      UpgradeStatRemote:FireServer(stat.key)
      task.wait(0.1)
      screenGui:Destroy()
      buildMenuUI()
    end)
  end

  -- START button
  local startBtn = Instance.new('TextButton')
  startBtn.Name = 'StartButton'
  startBtn.Size = UDim2.fromScale(0.3, 0.08)
  startBtn.Position = UDim2.fromScale(0.35, 0.78)
  startBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
  startBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
  startBtn.TextScaled = true
  startBtn.Font = Enum.Font.GothamBold
  startBtn.Text = 'START'
  startBtn.Parent = bg

  local startCorner = Instance.new('UICorner')
  startCorner.CornerRadius = UDim.new(0, 12)
  startCorner.Parent = startBtn

  startBtn.MouseButton1Click:Connect(function()
    StartRoundRemote:FireServer()
    screenGui:Destroy()
  end)
end

local EnemyReplicateRemote = Remotes:WaitForChild('EnemyReplicate') :: RemoteEvent
local EnemyDiedRemote = Remotes:WaitForChild('EnemyDied') :: RemoteEvent
local CoinUpdateRemote = Remotes:WaitForChild('CoinUpdate') :: RemoteEvent
local FloatingCoinRemote = Remotes:WaitForChild('FloatingCoin') :: RemoteEvent

local localEnemyParts: { [string]: { root: Part, hpBar: Frame?, hpFill: Frame? } } = {}

local function createLocalEnemy(id: string)
  local root = Instance.new('Part')
  root.Name = 'EnemyVisual_' .. id
  root.Size = Vector3.new(2, 5, 2)
  root.Anchored = true
  root.CanCollide = false
  root.Transparency = 1
  root.Parent = workspace

  -- HP Bar BillboardGui
  local billboard = Instance.new('BillboardGui')
  billboard.Size = UDim2.new(4, 0, 0.5, 0)
  billboard.StudsOffset = Vector3.new(0, 4, 0)
  billboard.AlwaysOnTop = false
  billboard.Parent = root

  local bg = Instance.new('Frame')
  bg.Size = UDim2.fromScale(1, 1)
  bg.BackgroundColor3 = Color3.fromRGB(50, 0, 0)
  bg.BorderSizePixel = 0
  bg.Parent = billboard

  local fill = Instance.new('Frame')
  fill.Name = 'Fill'
  fill.Size = UDim2.fromScale(1, 1)
  fill.BackgroundColor3 = Color3.fromRGB(220, 0, 0)
  fill.BorderSizePixel = 0
  fill.Parent = bg

  localEnemyParts[id] = { root = root, hpBar = bg, hpFill = fill }
end

EnemyReplicateRemote.OnClientEvent:Connect(
  function(data: { [string]: { px: number, py: number, pz: number, hp: number, maxHp: number } })
    for id, state in data do
      if not localEnemyParts[id] then
        createLocalEnemy(id)
      end
      local parts = localEnemyParts[id]
      parts.root.Position = Vector3.new(state.px, state.py, state.pz)
      if parts.hpFill then
        local ratio = math.clamp(state.hp / state.maxHp, 0, 1)
        parts.hpFill.Size = UDim2.fromScale(ratio, 1)
      end
    end
  end
)

EnemyDiedRemote.OnClientEvent:Connect(function(id: string)
  local parts = localEnemyParts[id]
  if parts then
    parts.root:Destroy()
    localEnemyParts[id] = nil
  end
end)

CoinUpdateRemote.OnClientEvent:Connect(function(newCoins: number)
  local gui = playerGui:FindFirstChild('MenuGui')
  if gui then
    local coins = gui:FindFirstChild('CoinsLabel', true)
    if coins then
      coins.Text = '🪙 ' .. tostring(newCoins)
    end
  end
end)

FloatingCoinRemote.OnClientEvent:Connect(function(pos: Vector3, amount: number)
  local billboard = Instance.new('BillboardGui')
  billboard.Size = UDim2.new(3, 0, 1, 0)
  billboard.StudsOffset = Vector3.new(0, 3, 0)
  billboard.AlwaysOnTop = true
  billboard.Adornee = workspace.Terrain
  billboard.Parent = workspace

  local label = Instance.new('TextLabel')
  label.Size = UDim2.fromScale(1, 1)
  label.BackgroundTransparency = 1
  label.TextColor3 = Color3.fromRGB(255, 215, 0)
  label.TextScaled = true
  label.Font = Enum.Font.GothamBold
  label.Text = '+' .. tostring(amount) .. ' 🪙'
  label.Parent = billboard

  -- Position at world pos
  local part = Instance.new('Part')
  part.Anchored = true
  part.CanCollide = false
  part.Transparency = 1
  part.Size = Vector3.one
  part.Position = pos
  part.Parent = workspace
  billboard.Adornee = part

  task.delay(1.5, function()
    billboard:Destroy()
    part:Destroy()
  end)
end)

buildMenuUI()
