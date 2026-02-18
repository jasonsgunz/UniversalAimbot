local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Teams = game:GetService("Teams")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- // Variables & State
local Active = false
local Keybind = Enum.KeyCode.E
local TargetPartName = "HumanoidRootPart"
local Mode = "Hold"
local Prediction = 0 
local SettingKey = false
local LockedPlayer = nil 
local Checks = { Alive = false, Team = false, Wall = false }

local selfOptions = {
    speed = {value = 16, enabled = false, key = Enum.KeyCode.T, setting = false},
    jump = {value = 50, enabled = false, key = Enum.KeyCode.Y, setting = false},
    fly = {value = 1, enabled = false, key = Enum.KeyCode.U, setting = false}
}
local espOptions = { tracers = false, names = false, dot = false }

local antiFlingEnabled = false
local lastSafeCF = CFrame.new()
local teleportThreshold = 25 

local tpwalking = false
local ctrl = {f=0,b=0,l=0,r=0}

local hitboxEnabled = false
local hitboxSize = 8
local hitboxVisual = false
local hitboxData = {}
local collisionEnabled = false

local espCache = {} 
local _Connections = {}

-- // Utility Functions
local function isVisible(targetPart)
    local origin = Camera.CFrame.Position
    local direction = targetPart.Position - origin
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {LocalPlayer.Character, targetPart.Parent}
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    local result = workspace:Raycast(origin, direction, rayParams)
    return result == nil
end

local function findBestHitboxPart(character)
    if not character then return nil end
    local priority = {"HumanoidRootPart","UpperTorso","LowerTorso","Torso","Head"}
    for _,name in ipairs(priority) do
        local part = character:FindFirstChild(name)
        if part and part:IsA("BasePart") then return part end
    end
    return character:FindFirstChildOfClass("BasePart")
end

-- // GUI SETUP
local ScreenGui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
ScreenGui.Name = "Titan_V21_Universal"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true

local Main = Instance.new("Frame", ScreenGui)
Main.Size = UDim2.new(0, 380, 0, 300); Main.Position = UDim2.new(0.5, -190, 0.5, -150)
Main.BackgroundColor3 = Color3.fromRGB(20, 20, 25); Main.Active = true; Main.BorderSizePixel = 0
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 8)

local TracerContainer = Instance.new("Frame", ScreenGui)
TracerContainer.Size = UDim2.new(1,0,1,0); TracerContainer.BackgroundTransparency = 1

local Title = Instance.new("TextLabel", Main)
Title.Size = UDim2.new(1, -60, 0, 35); Title.Position = UDim2.new(0, 15, 0, 0); Title.BackgroundTransparency = 1
Title.Text = "TITAN V21 | PHYSICS GUARD"; Title.TextColor3 = Color3.new(1, 1, 1); Title.Font = "GothamBold"; Title.TextSize = 14; Title.TextXAlignment = "Left"

local Close = Instance.new("TextButton", Main)
Close.Size = UDim2.new(0, 25, 0, 25); Close.Position = UDim2.new(1, -30, 0, 5); Close.BackgroundColor3 = Color3.fromRGB(200, 50, 50); Close.Text = "X"; Close.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", Close).CornerRadius = UDim.new(0, 4)

-- // Tab System
local TabHolder = Instance.new("Frame", Main)
TabHolder.Size = UDim2.new(1, -20, 0, 30); TabHolder.Position = UDim2.new(0, 10, 0, 35); TabHolder.BackgroundTransparency = 1

local function createTab(name, pos)
    local btn = Instance.new("TextButton", TabHolder)
    btn.Size = UDim2.new(0, 80, 1, 0); btn.Position = UDim2.new(0, pos, 0, 0); btn.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    btn.Text = name; btn.TextColor3 = Color3.new(1, 1, 1); btn.Font = "GothamBold"; Instance.new("UICorner", btn)
    return btn
end

local MainTab = createTab("MAIN", 0)
local SelfTab = createTab("SELF", 85)
local HitTab = createTab("HITBOX", 170)
local EspTab = createTab("ESP", 255)

local function createPage()
    local p = Instance.new("ScrollingFrame", Main)
    p.Size = UDim2.new(1, 0, 1, -75); p.Position = UDim2.new(0, 0, 0, 75); p.BackgroundTransparency = 1
    p.BorderSizePixel = 0; p.CanvasSize = UDim2.new(0, 0, 0, 350); p.ScrollBarThickness = 0; p.Visible = false
    Instance.new("UIListLayout", p).HorizontalAlignment = "Center"; p.UIListLayout.Padding = UDim.new(0, 8)
    return p
end

local MainPage = createPage(); MainPage.Visible = true; MainTab.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
local SelfPage = createPage()
local HitPage = createPage()
local EspPage = createPage()

-- // MAIN PAGE CONTROLS
local DropdownFrame = Instance.new("Frame", ScreenGui)
DropdownFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35); DropdownFrame.Visible = false; DropdownFrame.ZIndex = 100
Instance.new("UICorner", DropdownFrame)
Instance.new("UIListLayout", DropdownFrame).HorizontalAlignment = "Center"

local function createButton(txt, parent)
    local b = Instance.new("TextButton", parent)
    b.Size = UDim2.new(0, 340, 0, 35); b.BackgroundColor3 = Color3.fromRGB(45, 45, 50); b.Text = txt; b.TextColor3 = Color3.new(1,1,1); Instance.new("UICorner", b)
    return b
end

-- Prediction Slider
local Sliding = false
local PredRow = Instance.new("Frame", MainPage); PredRow.Size = UDim2.new(0, 340, 0, 45); PredRow.BackgroundTransparency = 1
local PredTxt = Instance.new("TextLabel", PredRow); PredTxt.Size = UDim2.new(1, 0, 0, 20); PredTxt.BackgroundTransparency = 1; PredTxt.Text = "Prediction: 0%"; PredTxt.TextColor3 = Color3.new(1,1,1); PredTxt.Font = "Gotham"
local SliderBack = Instance.new("Frame", PredRow); SliderBack.Size = UDim2.new(1, -20, 0, 10); SliderBack.Position = UDim2.new(0, 10, 0, 25); SliderBack.BackgroundColor3 = Color3.fromRGB(40, 40, 45); Instance.new("UICorner", SliderBack)
local SliderFill = Instance.new("Frame", SliderBack); SliderFill.Size = UDim2.new(0, 0, 1, 0); SliderFill.BackgroundColor3 = Color3.fromRGB(60, 160, 60); Instance.new("UICorner", SliderFill)

SliderBack.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then Sliding = true end end)
UIS.InputChanged:Connect(function(input) 
    if Sliding and input.UserInputType == Enum.UserInputType.MouseMovement then 
        local pos = math.clamp((input.Position.X - SliderBack.AbsolutePosition.X) / SliderBack.AbsoluteSize.X, 0, 1)
        SliderFill.Size = UDim2.new(pos, 0, 1, 0); Prediction = math.floor(pos * 100); PredTxt.Text = "Prediction: " .. Prediction .. "%"
    end 
end)
UIS.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then Sliding = false end end)

local BindBtn = createButton("KEYBIND: [E]", MainPage)
BindBtn.MouseButton1Click:Connect(function() SettingKey = true; BindBtn.Text = "[...]" end)

local ModeBtn = createButton("MODE: HOLD", MainPage)
ModeBtn.MouseButton1Click:Connect(function() Mode = (Mode == "Hold" and "Toggle" or "Hold"); ModeBtn.Text = "MODE: "..Mode:upper() end)

-- // SELF PAGE CONTROLS
local advancedGuardBtn = createButton("ADVANCED GUARD: OFF", SelfPage)
advancedGuardBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
advancedGuardBtn.MouseButton1Click:Connect(function()
    antiFlingEnabled = not antiFlingEnabled
    advancedGuardBtn.Text = "ADVANCED GUARD: "..(antiFlingEnabled and "ON" or "OFF")
    advancedGuardBtn.BackgroundColor3 = antiFlingEnabled and Color3.fromRGB(60, 160, 60) or Color3.fromRGB(200, 50, 50)
end)

table.insert(_Connections, RunService.PostSimulation:Connect(function()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    
    if hrp and hum and antiFlingEnabled then
        local currentCF = hrp.CFrame
        local distanceMoved = (currentCF.Position - lastSafeCF.Position).Magnitude
        
        -- Anti-Teleport & Fling Snapback
        if distanceMoved > teleportThreshold and not selfOptions.fly.enabled then
            hrp.CFrame = lastSafeCF
            hrp.AssemblyLinearVelocity = Vector3.zero
        else
            lastSafeCF = currentCF
        end
        
        -- Physical Resistance
        hrp.AssemblyAngularVelocity = Vector3.zero 
        local vel = hrp.AssemblyLinearVelocity
        if vel.Magnitude > 80 then
            hrp.AssemblyLinearVelocity = Vector3.new(math.clamp(vel.X, -40, 40), vel.Y, math.clamp(vel.Z, -40, 40))
        end
        
        -- Anti-Fling Touch Disable
        for _, v in pairs(char:GetDescendants()) do
            if v:IsA("BasePart") then v.CanTouch = false end
        end
        hum.Sit = false
    end
end))

-- // TRACER & AIMBOT LOGIC
table.insert(_Connections, RunService.RenderStepped:Connect(function()
    local char = LocalPlayer.Character
    local myRoot = char and char:FindFirstChild("HumanoidRootPart")
    
    -- ESP Loop
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local root = p.Character:FindFirstChild("HumanoidRootPart")
            if not espCache[p] then espCache[p] = {} end
            local cache = espCache[p]

            if root and espOptions.tracers and myRoot then
                local pos, onScreen = Camera:WorldToViewportPoint(root.Position)
                local myPos, myOnScreen = Camera:WorldToViewportPoint(myRoot.Position)
                
                if onScreen and myOnScreen then
                    if not cache.line then 
                        cache.line = Instance.new("Frame", TracerContainer)
                        cache.line.AnchorPoint = Vector2.new(0.5, 0.5); cache.line.BorderSizePixel = 0
                        cache.line.BackgroundColor3 = Color3.new(1,1,1)
                    end
                    local p1, p2 = Vector2.new(myPos.X, myPos.Y), Vector2.new(pos.X, pos.Y)
                    cache.line.Size = UDim2.new(0, (p2 - p1).Magnitude, 0, 1.5)
                    cache.line.Position = UDim2.new(0, (p1.X + p2.X) / 2, 0, (p1.Y + p2.Y) / 2)
                    cache.line.Rotation = math.deg(math.atan2(p2.Y - p1.Y, p2.X - p1.X))
                    cache.line.Visible = true
                elseif cache.line then cache.line.Visible = false end
            end
        end
    end

    -- Aimbot Loop
    if Active then
        if not LockedPlayer or not LockedPlayer.Character or not LockedPlayer.Character:FindFirstChild(TargetPartName) then
            local target, dist = nil, math.huge
            for _, p in pairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild(TargetPartName) then
                    local pos, onScreen = Camera:WorldToViewportPoint(p.Character[TargetPartName].Position)
                    if onScreen then
                        local mag = (Vector2.new(pos.X, pos.Y) - Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)).Magnitude
                        if mag < dist then dist = mag; target = p end
                    end
                end
            end
            LockedPlayer = target
        end
        
        if LockedPlayer then
            local p = LockedPlayer.Character[TargetPartName]
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, p.Position + (p.Velocity * (Prediction / 100)))
        end
    end
end))

-- // Tab Switcher Function
local function switch(btn, page)
    MainPage.Visible = false; SelfPage.Visible = false; HitPage.Visible = false; EspPage.Visible = false
    MainTab.BackgroundColor3 = Color3.fromRGB(35, 35, 40); SelfTab.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    HitTab.BackgroundColor3 = Color3.fromRGB(35, 35, 40); EspTab.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    page.Visible = true; btn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
end

MainTab.MouseButton1Click:Connect(function() switch(MainTab, MainPage) end)
SelfTab.MouseButton1Click:Connect(function() switch(SelfTab, SelfPage) end)
HitTab.MouseButton1Click:Connect(function() switch(HitTab, HitPage) end)
EspTab.MouseButton1Click:Connect(function() switch(EspTab, EspPage) end)

-- // Dragging Logic
local dragging, dragStart, startPos
Main.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 and not Sliding then dragging = true; dragStart = input.Position; startPos = Main.Position end end)
UIS.InputChanged:Connect(function(input) if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then local delta = input.Position - dragStart; Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y) end end)
UIS.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)

-- // Keybind Input Handler
UIS.InputBegan:Connect(function(input, gp)
    if SettingKey then Keybind = input.KeyCode; BindBtn.Text = "KEYBIND: ["..input.KeyCode.Name.."]"; SettingKey = false; return end
    if not gp and input.KeyCode == Keybind then 
        if Mode == "Hold" then Active = true else Active = not Active end
    end
end)
UIS.InputEnded:Connect(function(input)
    if input.KeyCode == Keybind and Mode == "Hold" then Active = false; LockedPlayer = nil end
end)

Close.MouseButton1Click:Connect(function() ScreenGui:Destroy(); for _, c in pairs(_Connections) do c:Disconnect() end end)

pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "VERSION V.3.1 (BETA)",
        Text = "This Script was made by jasonsgunz on Github.",
        Icon = "rbxassetid://6031094670",
        Duration = 6
    })
end)
