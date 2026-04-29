--!strict

local workspaceRef = game:GetService('Workspace')
local serverStorage = game:GetService('ServerStorage')

local existingBaseplate = workspaceRef:FindFirstChild('Baseplate')
if existingBaseplate and existingBaseplate:IsA('BasePart') then
  existingBaseplate:Destroy()
end

local existingArena = workspaceRef:FindFirstChild('Arena')
if existingArena then
  existingArena:Destroy()
end

local arenaFolder = Instance.new('Folder')
arenaFolder.Name = 'Arena'
arenaFolder.Parent = workspaceRef

local arenaFloor = Instance.new('Part')
arenaFloor.Name = 'ArenaFloor'
arenaFloor.Size = Vector3.new(75, 4, 75)
arenaFloor.Position = Vector3.new(0, -1.5, 0)
arenaFloor.Anchored = true
arenaFloor.CanCollide = true
arenaFloor.Material = Enum.Material.SmoothPlastic
arenaFloor.BrickColor = BrickColor.new('Medium stone grey')
arenaFloor.Parent = arenaFolder

local function createWall(name: string, size: Vector3, position: Vector3)
  local wall = Instance.new('Part')
  wall.Name = name
  wall.Size = size
  wall.CFrame = CFrame.new(position)
  wall.Anchored = true
  wall.CanCollide = true
  wall.Transparency = 1
  wall.Parent = arenaFolder
end

createWall('NorthWall', Vector3.new(75, 50, 1), Vector3.new(0, 25, -37.5))
createWall('SouthWall', Vector3.new(75, 50, 1), Vector3.new(0, 25, 37.5))
createWall('EastWall', Vector3.new(1, 50, 75), Vector3.new(37.5, 25, 0))
createWall('WestWall', Vector3.new(1, 50, 75), Vector3.new(-37.5, 25, 0))

local spawnLocation = Instance.new('SpawnLocation')
spawnLocation.Name = 'SpawnLocation'
spawnLocation.Size = Vector3.new(4, 1, 4)
spawnLocation.Position = Vector3.new(0, 1, 0)
spawnLocation.Anchored = true
spawnLocation.Transparency = 1
spawnLocation.CanCollide = false
spawnLocation.Neutral = true
spawnLocation.Duration = 0
spawnLocation.Parent = arenaFolder

local function isEnemyModel(model: Model): boolean
  return model:FindFirstChildOfClass('Humanoid') ~= nil
end

local function shouldDeleteRigObject(instance: Instance): boolean
  if instance:IsA('BillboardGui') then
    return true
  end

  local isTargetName = instance.Name == 'NPC' or instance.Name == 'Soldier'
  return isTargetName and (instance:IsA('Script') or instance:IsA('LocalScript'))
end

local function getOrCreateEnemyRigsFolder(): Folder
  local existingFolder = serverStorage:FindFirstChild('EnemyRigs')
  if existingFolder and existingFolder:IsA('Folder') then
    return existingFolder
  end

  if existingFolder then
    existingFolder:Destroy()
  end

  local enemyRigsFolder = Instance.new('Folder')
  enemyRigsFolder.Name = 'EnemyRigs'
  enemyRigsFolder.Parent = serverStorage
  return enemyRigsFolder
end

local function cleanupAndMoveEnemyRigs()
  local enemyRigsFolder = getOrCreateEnemyRigsFolder()
  for _, child in workspaceRef:GetChildren() do
    if child:IsA('Model') and isEnemyModel(child) then
      for _, descendant in child:GetDescendants() do
        if shouldDeleteRigObject(descendant) then
          descendant:Destroy()
        end
      end
      child.Parent = enemyRigsFolder
    end
  end
end

cleanupAndMoveEnemyRigs()

print('Arena setup complete')
