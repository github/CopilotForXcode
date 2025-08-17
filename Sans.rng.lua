local OrionLib = loadstring(game:HttpGet(('https://raw.githubusercontent.com/jensonhirst/Orion/main/source')))()

local Window = OrionLib:MakeWindow({
    Name = "Sans-rng | v1.6",
    HidePremium = false,
    IntroText =  ":^Killer boy^:",
    SaveConfig = true,
    ConfigFolder = "OrionTest"
})

local ClickSansRng = Window:MakeTab({
    Name = "AutoClickSans",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

local ClickAll = Window:MakeTab({
    Name = "AutoClickAll",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

local RunService = game:GetService("RunService")
local sansConnection

ClickSansRng:AddToggle({
    Name = "AutoClick-Sans.rng",
    Default = false,
    Callback = function(Value)
        print("Auto Click NPCs:", Value)
        if sansConnection then
            sansConnection:Disconnect()
            sansConnection = nil
        end
        if Value then
            sansConnection = RunService.RenderStepped:Connect(function()
                local enemiesFolder = workspace:FindFirstChild("NPCs")
                if enemiesFolder then
                    for _, npc in pairs(enemiesFolder:GetChildren()) do
                        local hitbox = npc:FindFirstChild("ClickablePart")
                        if hitbox and hitbox:IsA("Part") then
                            local clickDetector = hitbox:FindFirstChildOfClass("ClickDetector")
                            if clickDetector then
                                fireclickdetector(clickDetector)
                            end
                        end
                    end
                end
            end)
        end
    end
})

ClickAll:AddLabel("Just.rng")

local autoRunning = false

ClickAll:AddToggle({
    Name = "AutoClick-just.rng",
    Default = false,
    Callback = function(Value)
        print(Value)
        autoRunning = Value
        if Value then
            for _, descendant in ipairs(game:GetDescendants()) do
                if descendant:IsA("TextLabel") or descendant:IsA("TextButton") or descendant:IsA("TextBox") then
                    descendant.Font = Enum.Font.SciFi
                end
            end
            task.spawn(function()
                while autoRunning do
                    local npcFolder = workspace:FindFirstChild("Sans")
                    if npcFolder then
                        for _, npc in ipairs(npcFolder:GetChildren()) do
                            if npc:IsA("Model") then
                                local main = npc:FindFirstChild("Main")
                                if main then
                                    local clickDetector = main:FindFirstChildOfClass("ClickDetector")
                                    if clickDetector then
                                        fireclickdetector(clickDetector)
                                    end
                                end
                                local part = npc:FindFirstChild("Part")
                                if part then
                                    local clickDetectorPart = part:FindFirstChildOfClass("ClickDetector")
                                    if clickDetectorPart then
                                        fireclickdetector(clickDetectorPart)
                                    end
                                end
                            end
                        end
                    end
                    task.wait(0.01)
                end
            end)
        end
    end    
})

local godModeEnabled = false
local godConnection

ClickAll:AddToggle({
    Name = "GodMode",
    Default = false,
    Callback = function(Value)
        print("GodMode:", Value)
        godModeEnabled = Value
        local attacksFolder = workspace:FindFirstChild("Attacks")
        if not attacksFolder then return end

        local function disableAttackObject(obj)
            if obj:IsA("BasePart") or obj:IsA("MeshPart") or obj:IsA("UnionOperation") then
                obj.Transparency = 1
                obj.CanCollide = false
                obj.CanTouch = false
            elseif obj:IsA("Decal") or obj:IsA("SurfaceGui") then
                obj.Enabled = false
            elseif obj:IsA("Script") or obj:IsA("LocalScript") then
                obj.Disabled = true
            end
        end

        if Value then
            for _, obj in ipairs(attacksFolder:GetDescendants()) do
                disableAttackObject(obj)
            end
            godConnection = attacksFolder.DescendantAdded:Connect(function(obj)
                disableAttackObject(obj)
            end)
        else
            for _, obj in ipairs(attacksFolder:GetDescendants()) do
                if obj:IsA("BasePart") or obj:IsA("MeshPart") or obj:IsA("UnionOperation") then
                    obj.Transparency = 0
                    obj.CanCollide = true
                    obj.CanTouch = true
                elseif obj:IsA("Decal") or obj:IsA("SurfaceGui") then
                    obj.Enabled = true
                elseif obj:IsA("Script") or obj:IsA("LocalScript") then
                    obj.Disabled = false
                end
            end
            if godConnection then
                godConnection:Disconnect()
                godConnection = nil
            end
        end
    end
})

ClickAll:AddLabel("Unnamed sans.rng")

local unnamedConnection

ClickAll:AddToggle({
    Name = "AutoClick-Unnamed sans.rng",
    Default = false,
    Callback = function(Value)
        print("Auto Click NPCs:", Value)
        if unnamedConnection then
            unnamedConnection:Disconnect()
            unnamedConnection = nil
        end
        if Value then
            unnamedConnection = RunService.RenderStepped:Connect(function()
                local enemiesFolder = workspace:FindFirstChild("Enemies")
                if enemiesFolder then
                    for _, npc in pairs(enemiesFolder:GetChildren()) do
                        local hitbox = npc:FindFirstChild("ClickHitbox")
                        if hitbox and hitbox:IsA("Part") then
                            local clickDetector = hitbox:FindFirstChildOfClass("ClickDetector")
                            if clickDetector then
                                fireclickdetector(clickDetector)
                            end
                        end
                    end
                end
            end)
        end
    end
})

ClickAll:AddLabel("YUKKIY’S SANS RNG")

local yukkiyConnection

ClickAll:AddToggle({
    Name = "AutoClick-YUKKIY’S SANS RNG",
    Default = false,
    Callback = function(Value)
        print("Auto Click NPCs:", Value)
        if yukkiyConnection then
            yukkiyConnection:Disconnect()
            yukkiyConnection = nil
        end
        if Value then
            yukkiyConnection = RunService.RenderStepped:Connect(function()
                local enemiesFolder = workspace:FindFirstChild("Sanses")
                if enemiesFolder then
                    for _, npc in pairs(enemiesFolder:GetChildren()) do
                        local union = npc:FindFirstChild("BasePart")
                        if union and union:IsA("UnionOperation") then
                            local clickDetector = union:FindFirstChildOfClass("ClickDetector")
                            if clickDetector then
                                fireclickdetector(clickDetector)
                            end
                        end
                    end
                end
            end)
        end
    end
})
