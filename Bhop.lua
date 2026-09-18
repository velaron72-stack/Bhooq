-- ratman4080: BHOP MASTER v4
-- Стена больше не сбрасывает скорость. Только стоп 300мс -> 16.
-- Air control сохранён. Кнопка 50x50.

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

-- ========== КОНФИГ ==========
local SPEED_PER_JUMP   = 8
local MAX_SPEED        = 500
local STOP_TIMEOUT     = 0.3
local BASE_WALKSPEED   = 16
local AIR_CONTROL_MIX  = 0.35

-- ========== СОСТОЯНИЕ ==========
local bhopEnabled  = false
local bhopSpeed    = BASE_WALKSPEED
local lastMoveTime = tick()
local character, humanoid, rootPart

-- ========== GUI ==========
local oldGui = player:WaitForChild("PlayerGui"):FindFirstChild("BhopMasterGui")
if oldGui then oldGui:Destroy() end

local BhopMasterGui = Instance.new("ScreenGui")
BhopMasterGui.Name = "BhopMasterGui"
BhopMasterGui.ResetOnSpawn = false
BhopMasterGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
BhopMasterGui.Parent = player:WaitForChild("PlayerGui")

local BhopMasterButton = Instance.new("TextButton")
BhopMasterButton.Name = "BhopMasterToggle"
BhopMasterButton.Size = UDim2.new(0, 50, 0, 50)
BhopMasterButton.Position = UDim2.new(0.1, 0, 0.35, 0)
BhopMasterButton.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
BhopMasterButton.TextColor3 = Color3.fromRGB(255, 255, 255)
BhopMasterButton.Font = Enum.Font.SourceSansBold
BhopMasterButton.TextSize = 10
BhopMasterButton.Text = "BHOP\nOFF"
BhopMasterButton.AutoButtonColor = false
BhopMasterButton.Parent = BhopMasterGui

local Corner = Instance.new("UICorner")
Corner.CornerRadius = UDim.new(1, 0)
Corner.Parent = BhopMasterButton

-- ========== ДРАГ + ТАП ==========
local touchInput, touchStartPos, buttonStartPos, moved, touchStartTime

BhopMasterButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
    or input.UserInputType == Enum.UserInputType.MouseButton1 then
        touchInput = input
        touchStartPos = input.Position
        buttonStartPos = BhopMasterButton.Position
        moved = false
        touchStartTime = tick()
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == touchInput and input.UserInputType == Enum.UserInputType.Touch then
        local delta = input.Position - touchStartPos
        if delta.Magnitude > 10 then moved = true end
        BhopMasterButton.Position = UDim2.new(
            buttonStartPos.X.Scale, buttonStartPos.X.Offset + delta.X,
            buttonStartPos.Y.Scale, buttonStartPos.Y.Offset + delta.Y
        )
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input ~= touchInput then return end
    if not moved and (tick() - touchStartTime) < 0.3 then
        bhopEnabled = not bhopEnabled
        if bhopEnabled then
            BhopMasterButton.BackgroundColor3 = Color3.fromRGB(40, 200, 60)
            BhopMasterButton.Text = "BHOP\nON"
            bhopSpeed = BASE_WALKSPEED
            lastMoveTime = tick()
        else
            BhopMasterButton.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
            BhopMasterButton.Text = "BHOP\nOFF"
            bhopSpeed = BASE_WALKSPEED
            if humanoid then humanoid.WalkSpeed = BASE_WALKSPEED end
        end
    end
    touchInput = nil
end)

-- ========== ПРИВЯЗКА К ПЕРСОНАЖУ ==========
local function onCharacter(char)
    character = char
    humanoid  = char:WaitForChild("Humanoid")
    rootPart  = char:WaitForChild("HumanoidRootPart")

    bhopSpeed = BASE_WALKSPEED
    humanoid.WalkSpeed = BASE_WALKSPEED
    lastMoveTime = tick()

    humanoid.Jumping:Connect(function(active)
        if not active then return end
        if not bhopEnabled then return end
        if humanoid.Health <= 0 then return end

        bhopSpeed = math.min(bhopSpeed + SPEED_PER_JUMP, MAX_SPEED)
        humanoid.WalkSpeed = bhopSpeed
    end)
end

if player.Character then onCharacter(player.Character) end
player.CharacterAdded:Connect(onCharacter)

-- ========== AIR CONTROL + СТОП-ДЕТЕКТ ==========
RunService.Heartbeat:Connect(function()
    if not bhopEnabled then return end
    if not humanoid or not rootPart or humanoid.Health <= 0 then return end

    local state = humanoid:GetState()
    local inAir = (state == Enum.HumanoidStateType.Freefall
                or state == Enum.HumanoidStateType.Jumping)

    -- ===== AIR CONTROL =====
    if inAir then
        local md = humanoid.MoveDirection
        if md.Magnitude > 0.05 then
            local vel = rootPart.AssemblyLinearVelocity
            local horiz = Vector3.new(vel.X, 0, vel.Z)
            local speed = horiz.Magnitude

            if speed > 1 then
                local currentDir = horiz.Unit
                local targetDir = Vector3.new(md.X, 0, md.Z).Unit
                local newDir = currentDir:Lerp(targetDir, AIR_CONTROL_MIX).Unit

                rootPart.AssemblyLinearVelocity = Vector3.new(
                    newDir.X * speed,
                    vel.Y,
                    newDir.Z * speed
                )
            end
        end
    end

    -- ===== ДЕТЕКТ ОСТАНОВКИ =====
    local md = humanoid.MoveDirection
    local horizVel = Vector3.new(
        rootPart.AssemblyLinearVelocity.X, 0,
        rootPart.AssemblyLinearVelocity.Z
    ).Magnitude

    local isMoving = md.Magnitude > 0.05 or horizVel > 1

    if isMoving then
        lastMoveTime = tick()
    elseif tick() - lastMoveTime >= STOP_TIMEOUT then
        bhopSpeed = BASE_WALKSPEED
        humanoid.WalkSpeed = BASE_WALKSPEED
    end
end)

-- ========== ЖИВОЙ СЧЁТЧИК ==========
RunService.Heartbeat:Connect(function()
    if bhopEnabled and humanoid and humanoid.Health > 0 then
        BhopMasterButton.Text = string.format("BHOP\n%d", math.floor(humanoid.WalkSpeed))
    end
end)
