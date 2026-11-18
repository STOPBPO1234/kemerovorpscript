local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

-- Состояния и настройки
local accelMultiplier = 0.01
local brakePower = 0.05
local speedLimit = 200
local flightSpeed = 1
local flightEnabled = false
local driftMode = false
local leftBrakeActive = false
local rightBrakeActive = false
local keyAccel = Enum.KeyCode.W
local keyBrake = Enum.KeyCode.S
local keyStop = Enum.KeyCode.P
local keyFlip = Enum.KeyCode.F
local keyAlign = Enum.KeyCode.R
local activeFlyConnection, activeBrakeConnection = nil, nil
local originalCharacterParent = LocalPlayer.Character and LocalPlayer.Character.Parent
local isUnloaded = false
local driftStrength = 5
local driftConnection = nil

-- Drift V2: отдельный режим, классический дрифт остаётся без изменений.
local driftV2Mode = false
local driftV2Connection = nil
local driftV2Angle = 17       -- целевой угол бокового скольжения, градусы
local driftV2Control = 6      -- отзывчивость и помощь стабилизации, 1..10

local isCarFlipRunning = false
local antiStuckConnection = nil

local clickTpEnabled = false
local noclipEnabled = false
local playerFlyEnabled = false
local playerFlySpeed = 50
local targetPlayerName = ""

-- Переменные для спидхака игрока
local playerSpeedEnabled = false
local playerWalkSpeed = 16

-- Переменная для силы прыжка
local jumpPowerEnabled = false
local jumpPowerValue = 50
local jumpPowerConn = nil

-- Переменная для расширения зума камеры
local maxZoomEnabled = false

-- Переменная для защиты от падения
local noFallDamageEnabled = false
local noFallConn = nil

-- Визуальные переменные (Фуллбрайт, FOV, ESP)
local fullbrightEnabled = false
local fovEnabled = false
local fovValue = 70
local espEnabled = false

local clickTpConn, noclipConn, playerFlyConn, playerSpeedConn, fullbrightConn, fovConn, espConn
local optimizationConnection = nil
local inputBeganConnection, inputEndedConnection = nil, nil

-- ==========================================
-- ЛОГИКА ФУНКЦИЙ ЧИТА
-- ==========================================

local function getCarModel(instance)
    return instance:FindFirstAncestor(LocalPlayer.Name .. "'s Car")
        or (instance:FindFirstAncestor("Body") and instance:FindFirstAncestor("Body").Parent)
        or (instance:FindFirstAncestor("Misc") and instance:FindFirstAncestor("Misc").Parent)
        or instance:FindFirstAncestorWhichIsA("Model")
end

local function getVehicleSeat()
    local char = LocalPlayer.Character
    if not char then return nil end
    local hum = char:FindFirstChildWhichIsA("Humanoid")
    if not hum then return nil end
    local seat = hum.SeatPart
    return (seat and seat:IsA("VehicleSeat")) and seat or nil
end

local function alignCarToCamera()
    local seat = getVehicleSeat()
    if not seat then return end
    local car = getCarModel(seat)
    local cam = workspace.CurrentCamera
    if not car or not car:IsA("Model") then return end
    if not car.PrimaryPart then
        car.PrimaryPart = (seat.Parent == car and seat) or car:FindFirstChildWhichIsA("BasePart")
    end
    
    local cf = car:GetPrimaryPartCFrame()
    local pos = cf.Position
    local camLook = cam.CFrame.LookVector
    local flatLook = Vector3.new(camLook.X, 0, camLook.Z)
    if flatLook.Magnitude < 0.01 then 
        flatLook = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
        if flatLook.Magnitude < 0.01 then flatLook = Vector3.new(1, 0, 0) else flatLook = flatLook.Unit end
    else
        flatLook = flatLook.Unit
    end
    
    car:SetPrimaryPartCFrame(CFrame.new(pos + Vector3.new(0, 1.5, 0), pos + Vector3.new(0, 1.5, 0) + flatLook))
    seat.AssemblyLinearVelocity = seat.AssemblyLinearVelocity * Vector3.new(0.2, 1, 0.2)
    seat.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
end

fullbrightConn = RunService.Heartbeat:Connect(function()
    if fullbrightEnabled then
        Lighting.Brightness = 2
        Lighting.ClockTime = 12
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 100000
    end
end)

fovConn = RunService.RenderStepped:Connect(function()
    if fovEnabled then
        workspace.CurrentCamera.FieldOfView = fovValue
    end
end)

local function toggleEsp(state)
    espEnabled = state
    if state then
        espConn = RunService.Heartbeat:Connect(function()
            for _, p in pairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p.Character then
                    local char = p.Character
                    local hl = char:FindFirstChild("v0xtESP")
                    
                    local teamColor = Color3.fromRGB(255, 255, 255)
                    if p.Team and p.Team.TeamColor then
                        teamColor = p.Team.TeamColor.Color
                    end

                    if not hl then
                        hl = Instance.new("Highlight")
                        hl.Name = "v0xtESP"
                        hl.Adornee = char
                        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                        hl.FillTransparency = 0.5
                        hl.Parent = char
                    end
                    
                    hl.FillColor = teamColor
                end
            end
        end)
    else
        if espConn then espConn:Disconnect(); espConn = nil end
        for _, p in pairs(Players:GetPlayers()) do
            if p.Character then
                local hl = p.Character:FindFirstChild("v0xtESP")
                if hl then hl:Destroy() end
            end
        end
    end
end

local function toggleNoFallDamage(state)
    noFallDamageEnabled = state
    if state then
        noFallConn = RunService.Heartbeat:Connect(function()
            local char = LocalPlayer.Character
            if char then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hrp and hum then
                    if hum:GetState() == Enum.HumanoidStateType.Freefall and hrp.AssemblyLinearVelocity.Y < -40 then
                        hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, -40, hrp.AssemblyLinearVelocity.Z)
                    end
                end
            end
        end)
    else
        if noFallConn then noFallConn:Disconnect(); noFallConn = nil end
    end
end

local function toggleJumpPower(state)
    jumpPowerEnabled = state
    if state then
        jumpPowerConn = RunService.Heartbeat:Connect(function()
            local char = LocalPlayer.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then
                    hum.UseJumpPower = true
                    hum.JumpPower = jumpPowerValue
                end
            end
        end)
    else
        if jumpPowerConn then jumpPowerConn:Disconnect(); jumpPowerConn = nil end
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.JumpPower = 50
            end
        end
    end
end

local function toggleMaxZoom(state)
    maxZoomEnabled = state
    if state then
        LocalPlayer.CameraMaxZoomDistance = 1000
    else
        LocalPlayer.CameraMaxZoomDistance = 400
    end
end

-- Безопасная оптимизация (не трогает персонажей игроков)
local function runOptimization()
    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 999999
        Lighting.Brightness = 2
        Lighting.ShadowSoftness = 0
        Lighting.Technology = Enum.Technology.Compatibility

        for _, child in pairs(Lighting:GetChildren()) do
            if child:IsA("PostEffect") or child:IsA("Sky") or child:IsA("Atmosphere") or child:IsA("Clouds") then
                child:Destroy()
            end
        end

        if workspace:FindFirstChildOfClass("Terrain") then
            local terrain = workspace.Terrain
            terrain.WaterWaveSize = 0
            terrain.WaterWaveTransparency = 1
            terrain.WaterTransparency = 0
            terrain.WaterReflectance = 0
            pcall(function() terrain.Decoration = false end)
        end

        for _, obj in pairs(workspace:GetDescendants()) do
            local isCharacterPart = false
            for _, p in pairs(Players:GetPlayers()) do
                if p.Character and obj:IsDescendantOf(p.Character) then
                    isCharacterPart = true
                    break
                end
            end

            if not isCharacterPart then
                if obj:IsA("BasePart") then
                    obj.CastShadow = false
                    obj.Material = Enum.Material.SmoothPlastic
                    obj.Reflectance = 0
                elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
                    obj.Enabled = false
                    obj:Destroy()
                elseif obj:IsA("Decal") or obj:IsA("Texture") then
                    obj.Transparency = 1
                elseif obj:IsA("SpecialMesh") or obj:IsA("MeshPart") then
                    obj.TextureID = ""
                end
            end
        end

        if optimizationConnection then
            optimizationConnection:Disconnect()
            optimizationConnection = nil
        end
        optimizationConnection = workspace.DescendantAdded:Connect(function(obj)
            pcall(function()
                local isCharacterPart = false
                for _, p in pairs(Players:GetPlayers()) do
                    if p.Character and obj:IsDescendantOf(p.Character) then
                        isCharacterPart = true
                        break
                    end
                end

                if not isCharacterPart then
                    if obj:IsA("BasePart") then
                        obj.CastShadow = false
                        obj.Material = Enum.Material.SmoothPlastic
                    elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") then
                        obj.Enabled = false
                    elseif obj:IsA("Decal") or obj:IsA("Texture") then
                        obj.Transparency = 1
                    end
                end
            end)
        end)

        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        local userGameSettings = UserSettings():GetService("UserGameSettings")
        userGameSettings.SavedQualityLevel = Enum.SavedQualityLevel.Level1
    end)
end

local mouse = LocalPlayer:GetMouse()
clickTpConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if clickTpEnabled and not gameProcessed and input.UserInputType == Enum.UserInputType.MouseButton1 then
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt) then
            local seat = getVehicleSeat()
            local hit = mouse.Hit
            if hit then
                if seat then
                    local carModel = getCarModel(seat)
                    if carModel and carModel.PrimaryPart then
                        carModel:SetPrimaryPartCFrame(hit + Vector3.new(0, 3, 0))
                    else
                        seat.CFrame = hit + Vector3.new(0, 3, 0)
                    end
                else
                    local char = LocalPlayer.Character
                    if char and char:FindFirstChild("HumanoidRootPart") then
                        char:MoveTo(hit.Position + Vector3.new(0, 3, 0))
                    end
                end
            end
        end
    end
end)

playerSpeedConn = RunService.Heartbeat:Connect(function()
    if playerSpeedEnabled and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = playerWalkSpeed
        end
    end
end)

noclipConn = RunService.Stepped:Connect(function()
    if noclipEnabled and LocalPlayer.Character then
        for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end
end)

local function updatePlayerFly()
    if not playerFlyEnabled then 
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum.PlatformStand = false end
        end
        return 
    end
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end
    
    hum.PlatformStand = true
    local cam = workspace.CurrentCamera
    local camCFrame = cam.CFrame
    local moveDir = Vector3.new()
    
    if not UserInputService:GetFocusedTextBox() then
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + camCFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - camCFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - camCFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + camCFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.E) then moveDir = moveDir + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.Q) then moveDir = moveDir - Vector3.new(0, 1, 0) end
    end
    
    if moveDir.Magnitude > 0 then hrp.AssemblyLinearVelocity = moveDir.Unit * playerFlySpeed
    else hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0) end
    hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
end

local function togglePlayerFly(state)
    playerFlyEnabled = state
    if state then
        if not playerFlyConn then playerFlyConn = RunService.Heartbeat:Connect(updatePlayerFly) end
    else
        if playerFlyConn then playerFlyConn:Disconnect(); playerFlyConn = nil end
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum.PlatformStand = false end
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then hrp.AssemblyLinearVelocity = Vector3.new() end
        end
    end
end

local function applySpeedLimit(part)
     if speedLimit == math.huge then return end
     local vel = part.AssemblyLinearVelocity
     local horiz = Vector3.new(vel.X, 0, vel.Z)
     if horiz.Magnitude > speedLimit then
         local limited = horiz.Unit * speedLimit
         part.AssemblyLinearVelocity = Vector3.new(limited.X, vel.Y, limited.Z)
     end
end

local function stopCarInternal()
     local seat = getVehicleSeat()
     if not seat then return end
     local car = getCarModel(seat)
     if not car or not car:IsA("Model") then return end
     if not car.PrimaryPart then
         car.PrimaryPart = (seat.Parent == car and seat) or car:FindFirstChildWhichIsA("BasePart")
     end
     local cf = car:GetPrimaryPartCFrame()
     local pos = cf.Position
     local look = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
     if look.Magnitude < 0.01 then look = Vector3.new(1, 0, 0) else look = look.Unit end
     car:SetPrimaryPartCFrame(CFrame.new(pos + Vector3.new(0, 0.5, 0), pos + Vector3.new(0, 0.5, 0) + look))
     seat.AssemblyLinearVelocity  = Vector3.new()
     seat.AssemblyAngularVelocity = Vector3.new()
end

local function vehicleFlyStep()
    if isUnloaded then return end
    local seat = getVehicleSeat()
    if not seat then
        if activeFlyConnection then activeFlyConnection:Disconnect(); activeFlyConnection = nil end
        return
    end
    if isCarFlipRunning or seat.Anchored then return end

    local currentVel = seat.AssemblyLinearVelocity
    local currentCf = seat.CFrame
    local lookVec = currentCf.LookVector
    local horizVel = Vector3.new(currentVel.X, 0, currentVel.Z)
    local forwardSpeed = horizVel:Dot(lookVec)

    if rightBrakeActive then
        if forwardSpeed > 2 then
            seat.AssemblyLinearVelocity = currentVel * Vector3.new(1 - brakePower, 1, 1 - brakePower)
        else
            seat.AssemblyLinearVelocity = Vector3.new(currentVel.X, currentVel.Y, currentVel.Z) - lookVec * (accelMultiplier * 25)
        end
    elseif leftBrakeActive then
        if forwardSpeed < -2 then
            seat.AssemblyLinearVelocity = currentVel * Vector3.new(1 - brakePower, 1, 1 - brakePower)
        else
            seat.AssemblyLinearVelocity = Vector3.new(currentVel.X, currentVel.Y, currentVel.Z) + lookVec * (accelMultiplier * 25)
        end
    else
        seat.AssemblyLinearVelocity = currentVel * Vector3.new(1 - brakePower * 0.1, 1, 1 - brakePower * 0.1)
    end
    applySpeedLimit(seat)
end

local function updateFlyConnection()
    if leftBrakeActive or rightBrakeActive then
        if not activeFlyConnection then activeFlyConnection = RunService.Heartbeat:Connect(vehicleFlyStep) end
    else
        if activeFlyConnection then activeFlyConnection:Disconnect(); activeFlyConnection = nil end
    end
end

antiStuckConnection = RunService.Heartbeat:Connect(function()
    if isUnloaded then return end
    local seat = getVehicleSeat()
    if seat then applySpeedLimit(seat) end
end)

local function vehicleFlightStep()
    if isUnloaded or not flightEnabled then return end
    local char = LocalPlayer.Character
    if not char then return end
    local seat = getVehicleSeat()
    if not seat then
        if activeBrakeConnection then activeBrakeConnection:Disconnect(); activeBrakeConnection = nil end
        return
    end
    local car = getCarModel(seat)
    if not car or not car:IsA("Model") then return end
    char.Parent = car
    if not car.PrimaryPart then
        car.PrimaryPart = (seat.Parent == car and seat) or car:FindFirstChildWhichIsA("BasePart")
    end
    local camCf = workspace.CurrentCamera.CFrame
    local carCf = car:GetPrimaryPartCFrame()
    local moveDelta = Vector3.new(0, 0, 0)
    if not UserInputService:GetFocusedTextBox() then
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDelta = moveDelta + camCf.RightVector * flightSpeed end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDelta = moveDelta - camCf.RightVector * flightSpeed end
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDelta = moveDelta + camCf.LookVector * flightSpeed end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDelta = moveDelta - camCf.LookVector * flightSpeed end
        if UserInputService:IsKeyDown(Enum.KeyCode.E) then moveDelta = moveDelta + Vector3.new(0, 1, 0) * flightSpeed / 2 end
        if UserInputService:IsKeyDown(Enum.KeyCode.Q) then moveDelta = moveDelta - Vector3.new(0, 1, 0) * flightSpeed / 2 end
    end
    car:SetPrimaryPartCFrame(CFrame.new(carCf.Position + moveDelta) * (carCf - carCf.Position))
    seat.AssemblyLinearVelocity  = Vector3.new()
    seat.AssemblyAngularVelocity = Vector3.new()
end

local function updateFlightToggle()
    if flightEnabled then
        if not activeBrakeConnection then activeBrakeConnection = RunService.Heartbeat:Connect(vehicleFlightStep) end
    else
        if activeBrakeConnection then activeBrakeConnection:Disconnect(); activeBrakeConnection = nil end
        local char = LocalPlayer.Character
        if char then char.Parent = originalCharacterParent or char.Parent end
    end
end

local function vehicleDriftStep()
    if isUnloaded or not driftMode then return end
    local seat = getVehicleSeat()
    if not seat then return end
    local vel = seat.AssemblyLinearVelocity
    local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
    if speed < 2 then return end
    local look = seat.CFrame.LookVector
    local angVel = seat.AssemblyAngularVelocity
    local smoothedVel = Vector3.new(vel.X, 0, vel.Z):Lerp(look * speed, math.clamp(0.003 / driftStrength, 0.0003, 0.003))
    seat.AssemblyLinearVelocity = Vector3.new(smoothedVel.X, vel.Y, smoothedVel.Z)
    local angY = angVel.Y
    local st = math.clamp(driftStrength * 0.06, 0.1, 0.5)
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then angY = math.clamp(angY + st, -4.0, 4.0)
    elseif UserInputService:IsKeyDown(Enum.KeyCode.D) then angY = math.clamp(angY - st, -4.0, 4.0)
    else angY = angY * 0.80 end
    seat.AssemblyAngularVelocity = Vector3.new(angVel.X * 0.85, angY, angVel.Z * 0.85)
end

local function updateDriftToggle()
    if driftMode then
        if not driftConnection then
            driftConnection = RunService.Heartbeat:Connect(vehicleDriftStep)
        end
    else
        if driftConnection then
            driftConnection:Disconnect()
            driftConnection = nil
        end
    end
end

-- Drift V2: управляемый занос с плавной реакцией на руль.
-- A/D задают направление поворота; при отпускании руля скольжение постепенно гасится.
local function vehicleDriftV2Step(dt)
    if isUnloaded or not driftV2Mode then return end

    dt = math.clamp(dt or (1 / 60), 1 / 240, 1 / 20)

    local seat = getVehicleSeat()
    if not seat or seat.Anchored then return end

    local velocity = seat.AssemblyLinearVelocity
    local flatVelocity = Vector3.new(velocity.X, 0, velocity.Z)
    local speed = flatVelocity.Magnitude
    local angularVelocity = seat.AssemblyAngularVelocity

    -- На небольшой скорости не создаём искусственный занос и плавно гасим вращение.
    if speed < 7 then
        local angularDamping = math.exp(-4.5 * dt)
        seat.AssemblyAngularVelocity = Vector3.new(
            angularVelocity.X * angularDamping,
            angularVelocity.Y * angularDamping,
            angularVelocity.Z * angularDamping
        )
        return
    end

    local steer = 0
    if not UserInputService:GetFocusedTextBox() then
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then steer = steer + 1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then steer = steer - 1 end
    end

    local cf = seat.CFrame
    local forward = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
    local right = Vector3.new(cf.RightVector.X, 0, cf.RightVector.Z)
    if forward.Magnitude < 0.001 or right.Magnitude < 0.001 then return end
    forward = forward.Unit
    right = right.Unit

    local forwardSpeed = flatVelocity:Dot(forward)
    local lateralSpeed = flatVelocity:Dot(right)
    local control = math.clamp(driftV2Control, 1, 10) / 10
    local speedFactor = math.clamp((speed - 7) / 28, 0, 1)

    -- Целевое боковое скольжение. Угол ограничивает занос, а плавный отклик
    -- не позволяет скорости резко перескакивать вбок при нажатии A/D.
    local angle = math.rad(math.clamp(driftV2Angle, 5, 35))
    local targetLateralSpeed = steer * speed * math.sin(angle) * speedFactor
    local lateralResponse = (steer == 0) and (1.4 + control * 3.2) or (2.0 + control * 4.8)
    local lateralAlpha = 1 - math.exp(-lateralResponse * dt)
    local newLateralSpeed = lateralSpeed + (targetLateralSpeed - lateralSpeed) * lateralAlpha

    -- Не даём боковой составляющей превысить выбранный угол заноса.
    local maxLateralSpeed = speed * math.sin(math.rad(math.clamp(driftV2Angle + 8, 8, 43)))
    newLateralSpeed = math.clamp(newLateralSpeed, -maxLateralSpeed, maxLateralSpeed)

    -- Сохраняем общую горизонтальную скорость, меняя её направление, а не добавляя разгон.
    local forwardSign = (forwardSpeed >= 0) and 1 or -1
    local newForwardSpeed = forwardSign * math.sqrt(math.max(speed * speed - newLateralSpeed * newLateralSpeed, 0))
    local newFlatVelocity = forward * newForwardSpeed + right * newLateralSpeed
    seat.AssemblyLinearVelocity = Vector3.new(newFlatVelocity.X, velocity.Y, newFlatVelocity.Z)

    -- Поворот кузова следует за рулём с ограничением угловой скорости.
    -- Контрруление (нажатие противоположной A/D) помогает быстро поймать машину.
    local maxYawRate = 0.35 + 1.75 * speedFactor
    local targetYawRate = steer * maxYawRate
    local yawResponse = 2.0 + control * 5.5
    local yawAlpha = 1 - math.exp(-yawResponse * dt)
    local newYawRate = angularVelocity.Y + (targetYawRate - angularVelocity.Y) * yawAlpha
    newYawRate = math.clamp(newYawRate, -maxYawRate * 1.15, maxYawRate * 1.15)

    local bodyDamping = math.exp(-4.0 * dt)
    seat.AssemblyAngularVelocity = Vector3.new(
        angularVelocity.X * bodyDamping,
        newYawRate,
        angularVelocity.Z * bodyDamping
    )
end

local function updateDriftV2Toggle()
    if driftV2Mode then
        if not driftV2Connection then
            driftV2Connection = RunService.Heartbeat:Connect(vehicleDriftV2Step)
        end
    else
        if driftV2Connection then
            driftV2Connection:Disconnect()
            driftV2Connection = nil
        end
    end
end

-- ==========================================
-- ПОСТРОЕНИЕ ИНТЕРФЕЙСА
-- ==========================================
local window = Rayfield:CreateWindow({
    Name = "Kemerovo RP",
    LoadingTitle = "Kemerovo RP Menu",
    LoadingSubtitle = "by v0xt",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false,
})

local speedTab = window:CreateTab("Скорость", "gauge")
local flightTab = window:CreateTab("Полет", "plane")
local miscTab = window:CreateTab("Разное", "wrench")
local playerTab = window:CreateTab("Игрок", "user")
local tpTab = window:CreateTab("Телепорт", "map-pin")
local visTab = window:CreateTab("Визуал", "eye")

speedTab:CreateSection("Управление скоростью")
speedTab:CreateSlider({ Name = "Ускорение", Range = {0, 50}, Increment = 1, CurrentValue = accelMultiplier * 1000, Flag = "Sl1", Callback = function(v) accelMultiplier = v / 1000 end })
speedTab:CreateSlider({ Name = "Сила тормоза", Range = {0, 300}, Increment = 1, CurrentValue = brakePower * 1000, Flag = "Sl2", Callback = function(v) brakePower = v / 1000 end })
speedTab:CreateSlider({ Name = "Лимит скорости (0 = без лимита)", Range = {0, 1000}, Increment = 1, CurrentValue = (speedLimit == math.huge) and 0 or speedLimit, Flag = "Sl3", Callback = function(v) speedLimit = (v == 0) and math.huge or v end })

speedTab:CreateSection("Кнопки управления")
speedTab:CreateKeybind({ Name = "Газ (удерживать)", CurrentKeybind = keyAccel.Name, HoldToInteract = false, Flag = "Kb1", Callback = function(v) if typeof(v) == "string" then keyAccel = Enum.KeyCode[v] or keyAccel end end })
speedTab:CreateKeybind({ Name = "Тормоз (удерживать)", CurrentKeybind = keyBrake.Name, HoldToInteract = false, Flag = "Kb2", Callback = function(v) if typeof(v) == "string" then keyBrake = Enum.KeyCode[v] or keyBrake end end })
speedTab:CreateKeybind({ Name = "Остановить авто", CurrentKeybind = keyStop.Name, HoldToInteract = false, Flag = "Kb3", Callback = function(v) if typeof(v) == "string" then keyStop = Enum.KeyCode[v] or keyStop end end })
speedTab:CreateKeybind({ Name = "Перевернуть авто", CurrentKeybind = keyFlip.Name, HoldToInteract = false, Flag = "Kb4", Callback = function(v) if typeof(v) == "string" then keyFlip = Enum.KeyCode[v] or keyFlip end end })
speedTab:CreateKeybind({ Name = "Выровнять авто по камере", CurrentKeybind = keyAlign.Name, HoldToInteract = false, Flag = "Kb5", Callback = function(v) if typeof(v) == "string" then keyAlign = Enum.KeyCode[v] or keyAlign end end })
speedTab:CreateButton({ Name = "Развернуть/Выровнять авто", Callback = function() alignCarToCamera() end })

flightTab:CreateSection("Управление полетом")
flightTab:CreateToggle({ Name = "Включить полет", CurrentValue = flightEnabled, Flag = "Tg1", Callback = function(v) flightEnabled = v; updateFlightToggle() end })
flightTab:CreateSlider({ Name = "Скорость полета", Range = {0, 800}, Increment = 1, CurrentValue = flightSpeed * 100, Flag = "Sl4", Callback = function(v) flightSpeed = v / 100 end })
flightTab:CreateLabel("| Q = вниз | E = вверх |")

miscTab:CreateSection("Дрифт и Мир")
local classicDriftToggleControl
local driftV2ToggleControl

classicDriftToggleControl = miscTab:CreateToggle({
    Name = "Режим Дрифта",
    CurrentValue = driftMode,
    Flag = "Tg2",
    Callback = function(v)
        if v and driftV2Mode and driftV2ToggleControl then
            driftV2ToggleControl:Set(false)
        end
        driftMode = v
        updateDriftToggle()
    end
})
miscTab:CreateSlider({ Name = "Сила Дрифта", Range = {1, 10}, Increment = 1, CurrentValue = driftStrength, Flag = "Sl5", Callback = function(v) driftStrength = v end })

driftV2ToggleControl = miscTab:CreateToggle({
    Name = "Дрифт V2 (управляемый занос)",
    CurrentValue = driftV2Mode,
    Flag = "TgDriftV2",
    Callback = function(v)
        if v and driftMode and classicDriftToggleControl then
            classicDriftToggleControl:Set(false)
        end
        driftV2Mode = v
        updateDriftV2Toggle()
    end
})
miscTab:CreateSlider({ Name = "V2: Угол заноса", Range = {5, 35}, Increment = 1, CurrentValue = driftV2Angle, Flag = "SlDriftV2Angle", Callback = function(v) driftV2Angle = v end })
miscTab:CreateSlider({ Name = "V2: Помощь управления", Range = {1, 10}, Increment = 1, CurrentValue = driftV2Control, Flag = "SlDriftV2Control", Callback = function(v) driftV2Control = v end })
miscTab:CreateLabel("V2: A/D — руль | противоположное нажатие — контрруление")

miscTab:CreateSection("Выгрузка чита")
miscTab:CreateButton({ Name = "Выгрузить чит", Callback = function()
    isUnloaded = true
    flightEnabled = false; driftMode = false; driftV2Mode = false; playerFlyEnabled = false; noclipEnabled = false; clickTpEnabled = false; playerSpeedEnabled = false; fullbrightEnabled = false; fovEnabled = false; espEnabled = false; noFallDamageEnabled = false; jumpPowerEnabled = false; maxZoomEnabled = false
    if antiStuckConnection then antiStuckConnection:Disconnect(); antiStuckConnection = nil end
    if activeFlyConnection then activeFlyConnection:Disconnect(); activeFlyConnection = nil end
    if activeBrakeConnection then activeBrakeConnection:Disconnect(); activeBrakeConnection = nil end
    if driftConnection then driftConnection:Disconnect(); driftConnection = nil end
    if driftV2Connection then driftV2Connection:Disconnect(); driftV2Connection = nil end
    if clickTpConn then clickTpConn:Disconnect(); clickTpConn = nil end
    if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
    if playerFlyConn then playerFlyConn:Disconnect(); playerFlyConn = nil end
    if playerSpeedConn then playerSpeedConn:Disconnect(); playerSpeedConn = nil end
    if fullbrightConn then fullbrightConn:Disconnect(); fullbrightConn = nil end
    if fovConn then fovConn:Disconnect(); fovConn = nil end
    if espConn then espConn:Disconnect(); espConn = nil end
    if noFallConn then noFallConn:Disconnect(); noFallConn = nil end
    if jumpPowerConn then jumpPowerConn:Disconnect(); jumpPowerConn = nil end
    if optimizationConnection then optimizationConnection:Disconnect(); optimizationConnection = nil end
    if inputBeganConnection then inputBeganConnection:Disconnect(); inputBeganConnection = nil end
    if inputEndedConnection then inputEndedConnection:Disconnect(); inputEndedConnection = nil end
    workspace.CurrentCamera.FieldOfView = 70

    for _, p in pairs(Players:GetPlayers()) do
        if p.Character then
            local hl = p.Character:FindFirstChild("v0xtESP")
            if hl then hl:Destroy() end
        end
    end

    local char = LocalPlayer.Character
    if char then 
        char.Parent = originalCharacterParent or char.Parent 
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.PlatformStand = false; hum.WalkSpeed = 16; hum.JumpPower = 50 end
    end
    Rayfield:Destroy()
end})

playerTab:CreateSection("Спидхак и Прыжок")
playerTab:CreateToggle({ Name = "Включить Спидхак", CurrentValue = playerSpeedEnabled, Flag = "TgSpeed", Callback = function(v) playerSpeedEnabled = v end })
playerTab:CreateSlider({ Name = "Скорость игрока", Range = {16, 300}, Increment = 1, CurrentValue = playerWalkSpeed, Flag = "SlPlayerSpeed", Callback = function(v) playerWalkSpeed = v end })
playerTab:CreateToggle({ Name = "Кастомная сила прыжка", CurrentValue = jumpPowerEnabled, Flag = "TgJumpPower", Callback = function(v) toggleJumpPower(v) end })
playerTab:CreateSlider({ Name = "Высота прыжка", Range = {50, 300}, Increment = 5, CurrentValue = jumpPowerValue, Flag = "SlJumpPower", Callback = function(v) jumpPowerValue = v end })

playerTab:CreateSection("Полет Игрока")
playerTab:CreateToggle({ Name = "Полет игрока включен", CurrentValue = playerFlyEnabled, Flag = "Tg3", Callback = function(v) togglePlayerFly(v) end })
playerTab:CreateSlider({ Name = "Скорость полета игрока", Range = {10, 300}, Increment = 5, CurrentValue = playerFlySpeed, Flag = "Sl6", Callback = function(v) playerFlySpeed = v end })

playerTab:CreateSection("РП Функции и Защита")
playerTab:CreateToggle({ Name = "Защита от падения (No Fall Damage)", CurrentValue = noFallDamageEnabled, Flag = "TgNoFall", Callback = function(v) toggleNoFallDamage(v) end })
playerTab:CreateToggle({ Name = "Ноуклип (Игрок)", CurrentValue = noclipEnabled, Flag = "Tg4", Callback = function(v) noclipEnabled = v end })
playerTab:CreateToggle({ Name = "Клик ТП (Alt + ЛКМ)", CurrentValue = clickTpEnabled, Flag = "Tg6", Callback = function(v) clickTpEnabled = v end })
playerTab:CreateToggle({ Name = "Разблокировать дальний зум камеры", CurrentValue = maxZoomEnabled, Flag = "TgZoom", Callback = function(v) toggleMaxZoom(v) end })

tpTab:CreateSection("Телепорт к игроку (Вся Карта / В Авто)")
local playerList = {}
for _, p in pairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then table.insert(playerList, p.Name) end
end
if #playerList == 0 then table.insert(playerList, "None") end

local playerDropdown = tpTab:CreateDropdown({ Name = "Выберите игрока", Options = playerList, CurrentOption = playerList[1], Flag = "Dd1", Callback = function(opt) targetPlayerName = opt end })
tpTab:CreateButton({ Name = "Обновить список", Callback = function()
    local newList = {}
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then table.insert(newList, p.Name) end
    end
    if #newList == 0 then table.insert(newList, "None") end
    playerDropdown:Refresh(newList)
end})
tpTab:CreateButton({ Name = "Телепортироваться", Callback = function()
    local targetPlayer = Players:FindFirstChild(targetPlayerName)
    if targetPlayer and targetPlayer.Character then
        local targetHRP = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
        if targetHRP then
            pcall(function() LocalPlayer:RequestStreamAroundAsync(targetHRP.Position) end)
            task.wait(0.2)
            local seat = getVehicleSeat()
            if seat then
                local carModel = getCarModel(seat)
                if carModel and carModel.PrimaryPart then
                    carModel:SetPrimaryPartCFrame(targetHRP.CFrame + Vector3.new(0, 5, 0))
                else
                    seat.CFrame = targetHRP.CFrame + Vector3.new(0, 5, 0)
                end
            else
                local char = LocalPlayer.Character
                if char and char:FindFirstChild("HumanoidRootPart") then
                    char:SetPrimaryPartCFrame(targetHRP.CFrame + Vector3.new(0, 3, 0))
                end
            end
        end
    end
end})


-- ==========================================
-- TELEPORT V3
-- ==========================================

tpTab:CreateSection("TELEPORT V3")

local playerList = getTeleportTarget and {} or {}

local function refreshTeleportPlayers()
    local list = {}

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(list, player.Name)
        end
    end

    table.sort(list)
    return list
end

playerList = refreshTeleportPlayers()
targetPlayerName = playerList[1] or ""

local playerDropdown = tpTab:CreateDropdown({
    Name = "Выберите игрока",
    Options = playerList,
    CurrentOption = targetPlayerName,
    Flag = "Dd1",
    Callback = function(option)
        if typeof(option) == "table" then
            targetPlayerName = option[1] or ""
        else
            targetPlayerName = option or ""
        end
    end
})

-- Получение выбранного игрока
local function getV3Target()
    local target = Players:FindFirstChild(targetPlayerName)

    if not target or target == LocalPlayer then
        warn("[TP V3] Выберите игрока!")
        return nil
    end

    local character = target.Character
    if not character then
        warn("[TP V3] Персонаж не загружен!")
        return nil
    end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    local hum = character:FindFirstChildOfClass("Humanoid")

    if not hrp or not hum then
        warn("[TP V3] Не удалось найти персонажа!")
        return nil
    end

    return target, character, hrp, hum
end

-- Поиск автомобиля по сиденью
local function getV3CarFromSeat(seat)
    if not seat then return nil end

    local model = seat:FindFirstAncestorWhichIsA("Model")

    while model do
        if model:FindFirstChildWhichIsA("VehicleSeat", true) then
            return model
        end

        model = model.Parent
        if model and not model:IsA("Model") then
            return nil
        end
    end

    return nil
end

-- Обновление списка
tpTab:CreateButton({
    Name = "Обновить игроков",
    Callback = function()
        playerList = refreshTeleportPlayers()
        targetPlayerName = playerList[1] or ""

        playerDropdown:Refresh(playerList)

        print("[TP V3] Список обновлён")
    end
})

-- ==========================================
-- MODE 1: TELEPORT ON FOOT
-- ==========================================

tpTab:CreateButton({
    Name = "1. ТП пешком к игроку",
    Callback = function()
        local target, character, targetHRP = getV3Target()
        if not targetHRP then return end

        local myChar = LocalPlayer.Character
        if not myChar then return end

        local myHRP = myChar:FindFirstChild("HumanoidRootPart")
        if not myHRP then return end

        pcall(function()
            LocalPlayer:RequestStreamAroundAsync(targetHRP.Position)
        end)

        task.wait(0.3)

        myChar:PivotTo(
            targetHRP.CFrame * CFrame.new(0, 0, -5)
        )

        myHRP.AssemblyLinearVelocity = Vector3.zero
        myHRP.AssemblyAngularVelocity = Vector3.zero

        print("[TP V3] ТП пешком")
    end
})

-- ==========================================
-- MODE 2: TELEPORT WITH OWN CAR
-- ==========================================

tpTab:CreateButton({
    Name = "2. ТП своей машиной",
    Callback = function()
        local target, character, targetHRP = getV3Target()
        if not targetHRP then return end

        local seat = getVehicleSeat()

        if not seat then
            warn("[TP V3] Сначала сядь в свою машину!")
            return
        end

        local car = getCarModel(seat)

        if not car or not car:IsA("Model") then
            warn("[TP V3] Машина не найдена!")
            return
        end

        pcall(function()
            LocalPlayer:RequestStreamAroundAsync(targetHRP.Position)
        end)

        task.wait(0.3)

        car:PivotTo(
            targetHRP.CFrame * CFrame.new(0, 0, -10)
        )

        for _, part in ipairs(car:GetDescendants()) do
            if part:IsA("BasePart") then
                part.AssemblyLinearVelocity = Vector3.zero
                part.AssemblyAngularVelocity = Vector3.zero
            end
        end

        print("[TP V3] Машина перемещена")
    end
})

-- ==========================================
-- MODE 3: PASSENGER TELEPORT
-- ==========================================

tpTab:CreateButton({
    Name = "3. ТП на пассажирское место",
    Callback = function()
        local target, character, targetHRP, targetHum =
            getV3Target()

        if not targetHum then return end

        local targetSeat = targetHum.SeatPart

        if not targetSeat then
            warn("[TP V3] Игрок не сидит в машине!")
            return
        end

        local targetCar = getV3CarFromSeat(targetSeat)

        if not targetCar then
            warn("[TP V3] Машина игрока не найдена!")
            return
        end

        -- Ищем свободное пассажирское место
        local freeSeat = nil

        for _, obj in ipairs(targetCar:GetDescendants()) do
            if obj:IsA("Seat") or obj:IsA("VehicleSeat") then
                if obj.Occupant == nil and obj ~= targetSeat then
                    if obj:IsA("Seat") then
                        freeSeat = obj
                        break
                    elseif not freeSeat then
                        freeSeat = obj
                    end
                end
            end
        end

        if not freeSeat then
            warn("[TP V3] Нет свободных мест!")
            return
        end

        local myChar = LocalPlayer.Character
        if not myChar then return end

        local myHum = myChar:FindFirstChildOfClass("Humanoid")
        local myHRP = myChar:FindFirstChild("HumanoidRootPart")

        if not myHum or not myHRP then return end

        pcall(function()
            LocalPlayer:RequestStreamAroundAsync(
                freeSeat.Position
            )
        end)

        task.wait(0.3)

        myChar:PivotTo(
            freeSeat.CFrame * CFrame.new(0, 2, 0)
        )

        task.wait(0.2)

        freeSeat:Sit(myHum)

        print("[TP V3] Попытка посадки в машину игрока")
    end
})

tpTab:CreateSection("TELEPORT V3 INFO")

tpTab:CreateLabel("1 — Телепорт пешком")
tpTab:CreateLabel("2 — Телепорт своей машиной")
tpTab:CreateLabel("3 — Посадка в машину игрока")
tpTab:CreateLabel("Для режима 3 игрок должен быть в машине")


visTab:CreateSection("Подсветка игроков (ESP)")
visTab:CreateToggle({ Name = "ESP (Подсветка по цветам команд)", CurrentValue = espEnabled, Flag = "TgESP", Callback = function(v) toggleEsp(v) end })

visTab:CreateSection("Освещение и Очистка")
visTab:CreateToggle({ Name = "Фуллбрайт (Всегда светло)", CurrentValue = fullbrightEnabled, Flag = "TgFullbright", Callback = function(v) fullbrightEnabled = v end })
visTab:CreateToggle({ Name = "Кастомный FOV (Угол обзора)", CurrentValue = fovEnabled, Flag = "TgFOV", Callback = function(v) 
    fovEnabled = v 
    if not v then workspace.CurrentCamera.FieldOfView = 70 end
end })
visTab:CreateSlider({ Name = "Значение FOV", Range = {50, 120}, Increment = 1, CurrentValue = 70, Flag = "SlFOV", Callback = function(v) fovValue = v end })

visTab:CreateSection("Оптимизация (FPS Boost)")
visTab:CreateButton({ Name = "Включить Оптимизацию (FPS Boost)", Callback = function() runOptimization() end })

inputBeganConnection = UserInputService.InputBegan:Connect(function(input, gp)
    if isUnloaded or gp then return end
    if input.KeyCode == keyAccel then leftBrakeActive = true; updateFlyConnection() end
    if input.KeyCode == keyBrake then rightBrakeActive = true; updateFlyConnection() end
    if input.KeyCode == keyStop then stopCarInternal() end
    if input.KeyCode == keyAlign then alignCarToCamera() end
    if input.KeyCode == keyFlip then
        local seat = getVehicleSeat()
        if seat and not isCarFlipRunning then
            isCarFlipRunning = true
            local car = getCarModel(seat)
            if car and car:IsA("Model") then
                if not car.PrimaryPart then car.PrimaryPart = seat end
                local cf = car:GetPrimaryPartCFrame()
                car:SetPrimaryPartCFrame(CFrame.new(cf.Position + Vector3.new(0, 4, 0)) * CFrame.Angles(0, math.rad(cf.Rotation.Y), 0))
            else
                seat.CFrame = seat.CFrame + Vector3.new(0, 4, 0)
            end
            task.wait(0.3)
            isCarFlipRunning = false
        end
    end
end)

inputEndedConnection = UserInputService.InputEnded:Connect(function(input)
    if isUnloaded then return end
    if input.KeyCode == keyAccel then leftBrakeActive = false; updateFlyConnection() end
    if input.KeyCode == keyBrake then rightBrakeActive = false; updateFlyConnection() end
end)
