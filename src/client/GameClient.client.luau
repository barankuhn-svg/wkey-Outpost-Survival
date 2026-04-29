--!strict
local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local UserInputService = game:GetService('UserInputService')

local player = Players.LocalPlayer
local playerGui = player.PlayerGui

-- Wait for Remotes
local Remotes = ReplicatedStorage:WaitForChild('Remotes')
local GetDataRemote = Remotes:WaitForChild('GetData') :: RemoteFunction
local UpgradeStatRemote = Remotes:WaitForChild('UpgradeStat') :: RemoteEvent
local StartRoundRemote = Remotes:WaitForChild('StartRound') :: RemoteEvent

local Config = require(ReplicatedStorage.Shared.Config)
local Localization = require(ReplicatedStorage.Shared.Localization)

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
  coinsLabel.Size = UDim2.fromScale(0.2, 0.06)
  coinsLabel.Position = UDim2.fromScale(0.01, 0.12)
  coinsLabel.BackgroundTransparency = 1
  coinsLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
  coinsLabel.TextScaled = true
  coinsLabel.Font = Enum.Font.GothamBold
  coinsLabel.Text = '🪙 ' .. tostring(data.coins)
  coinsLabel.Parent = bg

  local avatarViewport = Instance.new('ViewportFrame')
  avatarViewport.Name = 'AvatarViewport'
  avatarViewport.Size = UDim2.fromScale(0.15, 0.3)
  avatarViewport.Position = UDim2.fromScale(0.425, 0.02)
  avatarViewport.BackgroundColor3 = Color3.fromRGB(20, 25, 45)
  avatarViewport.BackgroundTransparency = 0
  avatarViewport.BorderSizePixel = 0
  avatarViewport.ZIndex = 10
  avatarViewport.Parent = bg

  local avatarCorner = Instance.new('UICorner')
  avatarCorner.CornerRadius = UDim.new(0, 12)
  avatarCorner.Parent = avatarViewport

  task.defer(function()
    local success, result = pcall(function()
      local humanoidDescription = Players:GetHumanoidDescriptionFromUserId(player.UserId)
      local avatarModel =
        Players:CreateHumanoidModelFromDescription(humanoidDescription, Enum.HumanoidRigType.R15)

      local worldModel = Instance.new('WorldModel')
      worldModel.Parent = avatarViewport

      avatarModel:PivotTo(CFrame.new(0, 0, 0) * CFrame.Angles(0, math.pi, 0))
      avatarModel.Parent = worldModel

      local cam = Instance.new('Camera')
      cam.CFrame = CFrame.new(Vector3.new(0, 3, 7), Vector3.new(0, 2, 0))
      cam.Parent = avatarViewport
      avatarViewport.CurrentCamera = cam
    end)
    if not success then
      warn('Avatar viewport failed:', result)
    end
  end)

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
    nameLabel.Size = UDim2.fromScale(0.5, 1)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    nameLabel.TextScaled = true
    nameLabel.Font = Enum.Font.Gotham
    nameLabel.Text = stat.label
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Parent = row

    local valueLabel = Instance.new('TextLabel')
    valueLabel.Name = 'Value'
    valueLabel.Size = UDim2.fromScale(0.25, 1)
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
    local benefitText = '(+10 HP)'
    if stat.key == 'damage' then
      benefitText = '(+5 DMG)'
    elseif stat.key == 'regen' then
      benefitText = '(+0.5 Regen)'
    end

    local plusBtn = Instance.new('TextButton')
    plusBtn.Name = 'PlusBtn'
    plusBtn.Size = UDim2.fromScale(0.2, 0.8)
    plusBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 100)
    plusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    plusBtn.TextScaled = true
    plusBtn.Font = Enum.Font.GothamBold
    plusBtn.Text = '+ ' .. tostring(cost) .. '🪙  ' .. benefitText
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
  startBtn.Text = Localization.get('ui.start_button')
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
  billboard.Size = UDim2.fromScale(4, 0.5)
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
  billboard.Size = UDim2.fromScale(3, 1)
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

local BeamUpdateRemote2 = Remotes:WaitForChild('BeamUpdate') :: RemoteEvent

-- Beam visuals
local beamOriginPart = Instance.new('Part')
beamOriginPart.Name = 'BeamOrigin'
beamOriginPart.Size = Vector3.one * 0.1
beamOriginPart.Anchored = true
beamOriginPart.CanCollide = false
beamOriginPart.Transparency = 1
beamOriginPart.Parent = workspace

local beamTargetPart = Instance.new('Part')
beamTargetPart.Name = 'BeamTarget'
beamTargetPart.Size = Vector3.one * 0.1
beamTargetPart.Anchored = true
beamTargetPart.CanCollide = false
beamTargetPart.Transparency = 1
beamTargetPart.Parent = workspace

local beamAttachment0 = Instance.new('Attachment')
beamAttachment0.Parent = beamOriginPart

local beamAttachment1 = Instance.new('Attachment')
beamAttachment1.Parent = beamTargetPart

local waterBeam = Instance.new('Beam')
waterBeam.Attachment0 = beamAttachment0
waterBeam.Attachment1 = beamAttachment1
waterBeam.Color = ColorSequence.new(Color3.fromRGB(0, 200, 255))
waterBeam.Transparency = NumberSequence.new(0.2)
waterBeam.Width0 = 0.3
waterBeam.Width1 = 0.3
waterBeam.FaceCamera = true
waterBeam.Enabled = false
waterBeam.Parent = workspace

local beamHideTimer = 0
local BEAM_SHOW_DURATION = 0.15

game:GetService('RunService').Heartbeat:Connect(function(dt: number)
  if waterBeam.Enabled then
    beamHideTimer -= dt
    if beamHideTimer <= 0 then
      waterBeam.Enabled = false
    end
  end
end)

BeamUpdateRemote2.OnClientEvent:Connect(function(originPos: Vector3?, targetPos: Vector3?)
  if originPos and targetPos then
    beamOriginPart.Position = originPos
    beamTargetPart.Position = targetPos
    waterBeam.Enabled = true
    beamHideTimer = BEAM_SHOW_DURATION
  else
    waterBeam.Enabled = false
  end
end)

-- IN-GAME UI
local roundTimerLabel: TextLabel? = nil
local difficultyLabel: TextLabel? = nil
local difficultyProgressFill: Frame? = nil
local hpBarFill: Frame? = nil
local inGameCoinsLabel: TextLabel? = nil
local inGameGui: ScreenGui? = nil

local function buildInGameUI(playerHumanoid: Humanoid)
  local screenGui = Instance.new('ScreenGui')
  screenGui.Name = 'InGameGui'
  screenGui.ResetOnSpawn = false
  screenGui.IgnoreGuiInset = true
  screenGui.Parent = playerGui
  inGameGui = screenGui

  -- Top center: Timer + Difficulty + Progress
  local topCenter = Instance.new('Frame')
  topCenter.Name = 'TopCenter'
  topCenter.Size = UDim2.fromScale(0.35, 0.1)
  topCenter.Position = UDim2.fromScale(0.325, 0.02)
  topCenter.BackgroundColor3 = Color3.fromRGB(20, 20, 40)
  topCenter.BorderSizePixel = 0
  topCenter.Parent = screenGui

  local topCorner = Instance.new('UICorner')
  topCorner.CornerRadius = UDim.new(0, 10)
  topCorner.Parent = topCenter

  local timerLabel = Instance.new('TextLabel')
  timerLabel.Name = 'TimerLabel'
  timerLabel.Size = UDim2.fromScale(1, 0.35)
  timerLabel.Position = UDim2.fromScale(0, 0)
  timerLabel.BackgroundTransparency = 1
  timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
  timerLabel.TextScaled = true
  timerLabel.Font = Enum.Font.GothamBold
  timerLabel.Text = '00:00'
  timerLabel.Parent = topCenter
  roundTimerLabel = timerLabel

  local progressBarBg = Instance.new('Frame')
  progressBarBg.Name = 'DifficultyProgressBg'
  progressBarBg.Size = UDim2.fromScale(0.9, 0.18)
  progressBarBg.Position = UDim2.fromScale(0.05, 0.42)
  progressBarBg.BackgroundColor3 = Color3.fromRGB(35, 35, 55)
  progressBarBg.BorderSizePixel = 0
  progressBarBg.Parent = topCenter

  local progressBarCorner = Instance.new('UICorner')
  progressBarCorner.CornerRadius = UDim.new(0, 6)
  progressBarCorner.Parent = progressBarBg

  local progressFill = Instance.new('Frame')
  progressFill.Name = 'DifficultyProgressFill'
  progressFill.Size = UDim2.fromScale(0, 1)
  progressFill.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
  progressFill.BorderSizePixel = 0
  progressFill.Parent = progressBarBg
  difficultyProgressFill = progressFill

  local progressFillCorner = Instance.new('UICorner')
  progressFillCorner.CornerRadius = UDim.new(0, 6)
  progressFillCorner.Parent = progressFill

  local diffLabel = Instance.new('TextLabel')
  diffLabel.Name = 'DifficultyLabel'
  diffLabel.Size = UDim2.fromScale(1, 0.32)
  diffLabel.Position = UDim2.fromScale(0, 0.64)
  diffLabel.BackgroundTransparency = 1
  diffLabel.TextColor3 = Color3.fromRGB(0, 200, 0)
  diffLabel.TextScaled = true
  diffLabel.Font = Enum.Font.GothamBold
  diffLabel.Text = Localization.get('ui.difficulty_easy')
  diffLabel.Parent = topCenter
  difficultyLabel = diffLabel

  -- Top left: Coins + HP
  local topLeft = Instance.new('Frame')
  topLeft.Name = 'TopLeft'
  topLeft.Size = UDim2.fromScale(0.2, 0.12)
  topLeft.Position = UDim2.fromScale(0.01, 0.15)
  topLeft.BackgroundColor3 = Color3.fromRGB(20, 20, 40)
  topLeft.BorderSizePixel = 0
  topLeft.Parent = screenGui

  local tlCorner = Instance.new('UICorner')
  tlCorner.CornerRadius = UDim.new(0, 10)
  tlCorner.Parent = topLeft

  local coinsLabel = Instance.new('TextLabel')
  coinsLabel.Name = 'CoinsLabel'
  coinsLabel.Size = UDim2.fromScale(1, 0.4)
  coinsLabel.Position = UDim2.fromScale(0, 0.05)
  coinsLabel.BackgroundTransparency = 1
  coinsLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
  coinsLabel.TextScaled = true
  coinsLabel.Font = Enum.Font.GothamBold
  coinsLabel.Text = '🪙 0'
  coinsLabel.Parent = topLeft
  inGameCoinsLabel = coinsLabel

  local hpLabel = Instance.new('TextLabel')
  hpLabel.Size = UDim2.fromScale(1, 0.2)
  hpLabel.Position = UDim2.fromScale(0, 0.48)
  hpLabel.BackgroundTransparency = 1
  hpLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
  hpLabel.TextScaled = true
  hpLabel.Font = Enum.Font.Gotham
  hpLabel.Text = '❤️ ' .. Localization.get('ui.hp')
  hpLabel.Parent = topLeft

  local hpBarBg = Instance.new('Frame')
  hpBarBg.Size = UDim2.fromScale(0.9, 0.2)
  hpBarBg.Position = UDim2.fromScale(0.05, 0.72)
  hpBarBg.BackgroundColor3 = Color3.fromRGB(60, 0, 0)
  hpBarBg.BorderSizePixel = 0
  hpBarBg.Parent = topLeft

  local hpCorner = Instance.new('UICorner')
  hpCorner.CornerRadius = UDim.new(0, 6)
  hpCorner.Parent = hpBarBg

  local hpFill = Instance.new('Frame')
  hpFill.Name = 'HpFill'
  hpFill.Size = UDim2.fromScale(1, 1)
  hpFill.BackgroundColor3 = Color3.fromRGB(220, 0, 0)
  hpFill.BorderSizePixel = 0
  hpFill.Parent = hpBarBg
  hpBarFill = hpFill

  local hpFillCorner = Instance.new('UICorner')
  hpFillCorner.CornerRadius = UDim.new(0, 6)
  hpFillCorner.Parent = hpFill

  -- Right side: Spawn controls
  local rightPanel = Instance.new('Frame')
  rightPanel.Name = 'RightPanel'
  rightPanel.Size = UDim2.fromScale(0.21, 0.45)
  rightPanel.Position = UDim2.fromScale(0.78, 0.25)
  rightPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 40)
  rightPanel.BorderSizePixel = 0
  rightPanel.Parent = screenGui

  local rpCorner = Instance.new('UICorner')
  rpCorner.CornerRadius = UDim.new(0, 12)
  rpCorner.Parent = rightPanel

  local rpLayout = Instance.new('UIListLayout')
  rpLayout.Padding = UDim.new(0, 10)
  rpLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
  rpLayout.Parent = rightPanel

  local rpPadding = Instance.new('UIPadding')
  rpPadding.PaddingTop = UDim.new(0, 10)
  rpPadding.PaddingLeft = UDim.new(0, 8)
  rpPadding.PaddingRight = UDim.new(0, 8)
  rpPadding.PaddingBottom = UDim.new(0, 10)
  rpPadding.Parent = rightPanel

  local spawnRateLabel = Instance.new('TextLabel')
  spawnRateLabel.Size = UDim2.new(1, 0, 0, 26)
  spawnRateLabel.BackgroundTransparency = 1
  spawnRateLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
  spawnRateLabel.TextScaled = true
  spawnRateLabel.Font = Enum.Font.GothamBold
  spawnRateLabel.Text = Localization.get('ui.spawn_rate') .. ' (/s)'
  spawnRateLabel.Name = 'SpawnRateLabel'
  spawnRateLabel.Parent = rightPanel

  local spawnRateSlider = Instance.new('Frame')
  spawnRateSlider.Name = 'SpawnRateSlider'
  spawnRateSlider.Size = UDim2.new(1, 0, 0, 24)
  spawnRateSlider.BackgroundColor3 = Color3.fromRGB(40, 40, 80)
  spawnRateSlider.BorderSizePixel = 0
  spawnRateSlider.Parent = rightPanel

  local spawnRateFill = Instance.new('Frame')
  spawnRateFill.Name = 'Fill'
  spawnRateFill.Size = UDim2.fromScale(0, 1)
  spawnRateFill.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
  spawnRateFill.BorderSizePixel = 0
  spawnRateFill.Parent = spawnRateSlider

  local spawnRateInput = Instance.new('TextButton')
  spawnRateInput.Size = UDim2.fromScale(1, 1)
  spawnRateInput.BackgroundTransparency = 1
  spawnRateInput.Text = ''
  spawnRateInput.Parent = spawnRateSlider

  local spawnRateValueLabel = Instance.new('TextLabel')
  spawnRateValueLabel.Size = UDim2.new(1, 0, 0, 20)
  spawnRateValueLabel.BackgroundTransparency = 1
  spawnRateValueLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
  spawnRateValueLabel.TextScaled = true
  spawnRateValueLabel.Font = Enum.Font.Gotham
  spawnRateValueLabel.Text = '1.0'
  spawnRateValueLabel.Parent = rightPanel

  local maxEnemiesLabel = Instance.new('TextLabel')
  maxEnemiesLabel.Size = UDim2.new(1, 0, 0, 26)
  maxEnemiesLabel.BackgroundTransparency = 1
  maxEnemiesLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
  maxEnemiesLabel.TextScaled = true
  maxEnemiesLabel.Font = Enum.Font.GothamBold
  maxEnemiesLabel.Text = Localization.get('ui.max_enemies')
  maxEnemiesLabel.Name = 'MaxEnemiesLabel'
  maxEnemiesLabel.Parent = rightPanel

  local maxEnemiesSlider = Instance.new('Frame')
  maxEnemiesSlider.Name = 'MaxEnemiesSlider'
  maxEnemiesSlider.Size = UDim2.new(1, 0, 0, 24)
  maxEnemiesSlider.BackgroundColor3 = Color3.fromRGB(40, 40, 80)
  maxEnemiesSlider.BorderSizePixel = 0
  maxEnemiesSlider.Parent = rightPanel

  local maxEnemiesFill = Instance.new('Frame')
  maxEnemiesFill.Name = 'Fill'
  maxEnemiesFill.Size = UDim2.fromScale(0, 1)
  maxEnemiesFill.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
  maxEnemiesFill.BorderSizePixel = 0
  maxEnemiesFill.Parent = maxEnemiesSlider

  local maxEnemiesInput = Instance.new('TextButton')
  maxEnemiesInput.Size = UDim2.fromScale(1, 1)
  maxEnemiesInput.BackgroundTransparency = 1
  maxEnemiesInput.Text = ''
  maxEnemiesInput.Parent = maxEnemiesSlider

  local maxEnemiesValueLabel = Instance.new('TextLabel')
  maxEnemiesValueLabel.Size = UDim2.new(1, 0, 0, 20)
  maxEnemiesValueLabel.BackgroundTransparency = 1
  maxEnemiesValueLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
  maxEnemiesValueLabel.TextScaled = true
  maxEnemiesValueLabel.Font = Enum.Font.Gotham
  maxEnemiesValueLabel.Text = '20'
  maxEnemiesValueLabel.Parent = rightPanel

  local SetSpawnRateRemote = Remotes:WaitForChild('SetSpawnRate') :: RemoteEvent
  local applyBtn = Instance.new('TextButton')
  applyBtn.Size = UDim2.new(1, 0, 0, 34)
  applyBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 110)
  applyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
  applyBtn.TextScaled = true
  applyBtn.Font = Enum.Font.GothamBold
  applyBtn.Text = 'Apply'
  applyBtn.Parent = rightPanel

  local killAllBtn = Instance.new('TextButton')
  killAllBtn.Size = UDim2.new(1, 0, 0, 34)
  killAllBtn.BackgroundColor3 = Color3.fromRGB(180, 0, 0)
  killAllBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
  killAllBtn.TextScaled = true
  killAllBtn.Font = Enum.Font.GothamBold
  killAllBtn.Text = Localization.get('ui.kill_all')
  killAllBtn.Parent = rightPanel

  local kaCorner = Instance.new('UICorner')
  kaCorner.CornerRadius = UDim.new(0, 8)
  kaCorner.Parent = killAllBtn

  local applyCorner = Instance.new('UICorner')
  applyCorner.CornerRadius = UDim.new(0, 8)
  applyCorner.Parent = applyBtn

  -- Wire up Kill All
  local KillAllRemote = Remotes:WaitForChild('KillAll') :: RemoteEvent
  local spawnRateValue = 1
  local maxEnemiesValue = 20
  local draggingSpawn = false
  local draggingMax = false

  local function updateSpawnFromAlpha(alpha: number)
    local clamped = math.clamp(alpha, 0, 1)
    spawnRateValue = math.floor((1 + (9 * clamped)) * 10 + 0.5) / 10
    spawnRateFill.Size = UDim2.fromScale((spawnRateValue - 1) / 9, 1)
    spawnRateValueLabel.Text = string.format('%.1f', spawnRateValue)
  end

  local function updateMaxFromAlpha(alpha: number)
    local clamped = math.clamp(alpha, 0, 1)
    maxEnemiesValue = math.floor(1 + (49 * clamped) + 0.5)
    maxEnemiesFill.Size = UDim2.fromScale((maxEnemiesValue - 1) / 49, 1)
    maxEnemiesValueLabel.Text = tostring(maxEnemiesValue)
  end

  updateSpawnFromAlpha(0)
  updateMaxFromAlpha((20 - 1) / 49)

  local function sliderAlphaFromMouse(sliderFrame: Frame): number
    local mouseX = UserInputService:GetMouseLocation().X
    return (mouseX - sliderFrame.AbsolutePosition.X) / sliderFrame.AbsoluteSize.X
  end

  spawnRateInput.MouseButton1Down:Connect(function()
    draggingSpawn = true
    updateSpawnFromAlpha(sliderAlphaFromMouse(spawnRateSlider))
  end)

  maxEnemiesInput.MouseButton1Down:Connect(function()
    draggingMax = true
    updateMaxFromAlpha(sliderAlphaFromMouse(maxEnemiesSlider))
  end)

  UserInputService.InputEnded:Connect(function(input: InputObject)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
      draggingSpawn = false
      draggingMax = false
    end
  end)

  UserInputService.InputChanged:Connect(function(input: InputObject)
    if input.UserInputType ~= Enum.UserInputType.MouseMovement then
      return
    end
    if draggingSpawn then
      updateSpawnFromAlpha(sliderAlphaFromMouse(spawnRateSlider))
    end
    if draggingMax then
      updateMaxFromAlpha(sliderAlphaFromMouse(maxEnemiesSlider))
    end
  end)

  applyBtn.MouseButton1Click:Connect(function()
    SetSpawnRateRemote:FireServer(spawnRateValue, maxEnemiesValue)
  end)

  killAllBtn.MouseButton1Click:Connect(function()
    KillAllRemote:FireServer()
  end)

  -- HP bar update loop
  game:GetService('RunService').Heartbeat:Connect(function()
    if playerHumanoid and hpBarFill then
      local ratio = math.clamp(playerHumanoid.Health / playerHumanoid.MaxHealth, 0, 1)
      hpBarFill.Size = UDim2.fromScale(ratio, 1)
    end
  end)
end

-- Timer + Difficulty update loop
local roundStartClientTime = 0
local inRound = false

local RoundStartedRemote = Remotes:WaitForChild('RoundStarted') :: RemoteEvent
RoundStartedRemote.OnClientEvent:Connect(function()
  inRound = true
  roundStartClientTime = tick()
  local char = player.Character or player.CharacterAdded:Wait()
  local humanoid = char:WaitForChild('Humanoid') :: Humanoid
  buildInGameUI(humanoid)
end)

game:GetService('RunService').Heartbeat:Connect(function()
  if not inRound then
    return
  end
  if not roundTimerLabel then
    return
  end

  local elapsed = tick() - roundStartClientTime
  local minutes = math.floor(elapsed / 60)
  local seconds = math.floor(elapsed % 60)
  roundTimerLabel.Text = string.format('%02d:%02d', minutes, seconds)

  local currentDiff = Config.DIFFICULTY[1]
  local diffKeyMap = {
    Easy = 'ui.difficulty_easy',
    Medium = 'ui.difficulty_medium',
    Hard = 'ui.difficulty_hard',
    Extreme = 'ui.difficulty_extreme',
    ULTRA = 'ui.difficulty_ultra',
  }
  for _, diff in Config.DIFFICULTY do
    if elapsed >= diff.time then
      currentDiff = diff
    end
  end
  if difficultyLabel then
    difficultyLabel.Text = Localization.get(diffKeyMap[currentDiff.label] or 'ui.difficulty_easy')
    difficultyLabel.TextColor3 = currentDiff.color
  end
  if difficultyProgressFill then
    difficultyProgressFill.Size = UDim2.fromScale(math.clamp(elapsed / 240, 0, 1), 1)
    difficultyProgressFill.BackgroundColor3 = currentDiff.color
  end
end)

CoinUpdateRemote.OnClientEvent:Connect(function(newCoins: number)
  if inGameCoinsLabel then
    inGameCoinsLabel.Text = '🪙 ' .. tostring(newCoins)
  end
end)

-- DEATH SCREEN
local PlayerDiedRemote = Remotes:WaitForChild('PlayerDied') :: RemoteEvent

local function buildDeathScreen(elapsed: number, coins: number, kills: number, difficulty: string)
  if inGameGui then
    inGameGui:Destroy()
    inGameGui = nil
  end
  inRound = false

  local screenGui = Instance.new('ScreenGui')
  screenGui.Name = 'DeathGui'
  screenGui.ResetOnSpawn = false
  screenGui.IgnoreGuiInset = true
  screenGui.Parent = playerGui

  local bg = Instance.new('Frame')
  bg.Size = UDim2.fromScale(1, 1)
  bg.BackgroundColor3 = Color3.fromRGB(10, 10, 20)
  bg.BackgroundTransparency = 0.3
  bg.BorderSizePixel = 0
  bg.Parent = screenGui

  local panel = Instance.new('Frame')
  panel.Size = UDim2.fromScale(0.4, 0.55)
  panel.Position = UDim2.fromScale(0.3, 0.2)
  panel.BackgroundColor3 = Color3.fromRGB(20, 20, 40)
  panel.BorderSizePixel = 0
  panel.Parent = bg

  local panelCorner = Instance.new('UICorner')
  panelCorner.CornerRadius = UDim.new(0, 16)
  panelCorner.Parent = panel

  local layout = Instance.new('UIListLayout')
  layout.Padding = UDim.new(0, 10)
  layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
  layout.Parent = panel

  local padding = Instance.new('UIPadding')
  padding.PaddingTop = UDim.new(0, 20)
  padding.PaddingBottom = UDim.new(0, 20)
  padding.PaddingLeft = UDim.new(0, 16)
  padding.PaddingRight = UDim.new(0, 16)
  padding.Parent = panel

  local titleLabel = Instance.new('TextLabel')
  titleLabel.Size = UDim2.new(1, 0, 0, 50)
  titleLabel.BackgroundTransparency = 1
  titleLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
  titleLabel.TextScaled = true
  titleLabel.Font = Enum.Font.GothamBold
  titleLabel.Text = '💀 ' .. Localization.get('ui.you_died')
  titleLabel.Parent = panel

  local minutes = math.floor(elapsed / 60)
  local seconds = math.floor(elapsed % 60)
  local timeStr = string.format('%02d:%02d', minutes, seconds)

  local stats = {
    { label = '⏱️  ' .. Localization.get('ui.survived'), value = timeStr },
    { label = '🪙  ' .. Localization.get('ui.coins'), value = tostring(coins) },
    { label = '💀  ' .. Localization.get('ui.kills'), value = tostring(kills) },
    { label = '📈  Difficulty', value = difficulty },
  }

  for _, stat in stats do
    local row = Instance.new('TextLabel')
    row.Size = UDim2.new(1, 0, 0, 36)
    row.BackgroundTransparency = 1
    row.TextColor3 = Color3.fromRGB(200, 200, 200)
    row.TextScaled = true
    row.Font = Enum.Font.Gotham
    row.Text = stat.label .. ':  ' .. stat.value
    row.Parent = panel
  end

  local backBtn = Instance.new('TextButton')
  backBtn.Size = UDim2.new(0.8, 0, 0, 44)
  backBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
  backBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
  backBtn.TextScaled = true
  backBtn.Font = Enum.Font.GothamBold
  backBtn.Text = Localization.get('ui.back_to_menu')
  backBtn.Parent = panel

  local btnCorner = Instance.new('UICorner')
  btnCorner.CornerRadius = UDim.new(0, 10)
  btnCorner.Parent = backBtn

  backBtn.MouseButton1Click:Connect(function()
    screenGui:Destroy()
    buildMenuUI()
  end)
end

PlayerDiedRemote.OnClientEvent:Connect(
  function(elapsed: number, coins: number, kills: number, difficulty: string)
    buildDeathScreen(elapsed, coins, kills, difficulty)
  end
)

buildMenuUI()
