--[[
    MoonlightHub v2 | Your Bizarre Adventure
    Tabs: Farming, Visuals, Player, Settings
    Theme: Dark (anthracite + deep purple) / Light (milk white + deep purple)
    RightShift toggles window; drag by title/sidebar; yellow=minimize, green=zoom, red=close
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local VirtualInputManager = game:GetService("VirtualInputManager")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local env = (type(getgenv) == "function" and getgenv()) or _G
if type(env.MoonlightHub) == "table" and type(env.MoonlightHub.Destroy) == "function" then
    pcall(env.MoonlightHub.Destroy)
end

local LocalPlayer = Players.LocalPlayer

-- ============================================================
-- Palettes and theme registry
-- ============================================================

local Palettes = {
    Dark = {
        Background = Color3.fromRGB(30, 30, 36),
        Panel      = Color3.fromRGB(44, 44, 54),
        Border     = Color3.fromRGB(18, 18, 24),
        Raised     = Color3.fromRGB(56, 56, 68),
        Text       = Color3.fromRGB(232, 232, 240),
        SubText    = Color3.fromRGB(150, 148, 160),
        Accent     = Color3.fromRGB(96, 52, 156),
        AccentHi   = Color3.fromRGB(122, 68, 192),
        Red        = Color3.fromRGB(255, 95, 87),
        Yellow     = Color3.fromRGB(254, 188, 46),
        Green      = Color3.fromRGB(40, 200, 64),
        On         = Color3.fromRGB(96, 52, 156),
        Off        = Color3.fromRGB(70, 70, 80),
        White      = Color3.fromRGB(255, 255, 255),
    },
    Light = {
        Background = Color3.fromRGB(248, 245, 240),
        Panel      = Color3.fromRGB(236, 232, 226),
        Border     = Color3.fromRGB(180, 172, 164),
        Raised     = Color3.fromRGB(222, 217, 210),
        Text       = Color3.fromRGB(38, 28, 52),
        SubText    = Color3.fromRGB(118, 108, 124),
        Accent     = Color3.fromRGB(96, 52, 156),
        AccentHi   = Color3.fromRGB(122, 68, 192),
        Red        = Color3.fromRGB(220, 70, 65),
        Yellow     = Color3.fromRGB(215, 155, 30),
        Green      = Color3.fromRGB(38, 175, 60),
        On         = Color3.fromRGB(96, 52, 156),
        Off        = Color3.fromRGB(180, 174, 168),
        White      = Color3.fromRGB(255, 255, 255),
    },
}
local Theme = Palettes.Dark
local CurrentThemeName = "Dark"

local Themed = {}
local ThemeHooks = {}

local function themed(inst, role)
    table.insert(Themed, { inst = inst, role = role })
    local c = Theme[role]
    if c then
        if inst:IsA("UIStroke") then
            inst.Color = c
        elseif inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
            inst.TextColor3 = c
        else
            inst.BackgroundColor3 = c
        end
    end
    return inst
end

local function onThemeChange(fn)
    table.insert(ThemeHooks, fn)
end

local function applyTheme(name)
    CurrentThemeName = name
    Theme = Palettes[name] or Palettes.Dark
    for _, entry in ipairs(Themed) do
        local inst = entry.inst
        if inst and inst.Parent ~= nil then
            local c = Theme[entry.role]
            if c then
                pcall(function()
                    if inst:IsA("UIStroke") then
                        inst.Color = c
                    elseif inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
                        inst.TextColor3 = c
                    else
                        inst.BackgroundColor3 = c
                    end
                end)
            end
        end
    end
    for _, fn in ipairs(ThemeHooks) do
        pcall(fn)
    end
end

-- ============================================================
-- Constants and catalog
-- ============================================================

local HUB_NAME = "MoonlightHub"
local ITEMS_PATH = { "Item_Spawns", "Items" }
local BASE_ICON_SIZE = 56
local TITLE_HEIGHT = 38
local SIDEBAR_WIDTH = 120
local PICKUP_HOVER_OFFSET = Vector3.new(0, 3, 0)
local LUCKY_ARROW_PRICE = 75000
local RARE_KEYS = { "lucky arrow", "lucky stone mask" }

local ITEM_CATALOG = {
    { key = "lucky arrow",       label = "Lucky Arrow",       value = 100, rare = true },
    { key = "lucky stone mask",  label = "Lucky Stone Mask",  value = 95,  rare = true },
    { key = "pure rokakaka",     label = "Pure Rokakaka",     value = 85,  rare = false },
    { key = "mysterious arrow",  label = "Mysterious Arrow",  value = 75,  rare = false },
    { key = "rib cage",          label = "Rib Cage",          value = 70,  rare = false },
    { key = "steel ball",        label = "Steel Ball",        value = 60,  rare = false },
    { key = "stone mask",        label = "Stone Mask",        value = 55,  rare = false },
    { key = "zeppeli",           label = "Zeppeli's Hat",     value = 45,  rare = false },
    { key = "quinton",           label = "Quinton's Glove",   value = 45,  rare = false },
    { key = "rokakaka",          label = "Rokakaka",          value = 40,  rare = false },
    { key = "diary",             label = "Diary",             value = 35,  rare = false },
    { key = "arrow",             label = "Arrow",             value = 30,  rare = false },
    { key = "gold coin",         label = "Gold Coin",         value = 20,  rare = false },
}

local CATALOG_BY_LENGTH = {}
local FILTER_OPTIONS = {}
for _, entry in ipairs(ITEM_CATALOG) do
    table.insert(CATALOG_BY_LENGTH, entry)
    table.insert(FILTER_OPTIONS, entry.label)
end
table.insert(FILTER_OPTIONS, "Other")
table.sort(CATALOG_BY_LENGTH, function(a, b) return #a.key > #b.key end)

local function isRareLabel(label)
    local low = string.lower(label or "")
    for _, k in ipairs(RARE_KEYS) do
        if string.find(low, k, 1, true) then return true end
    end
    return false
end

-- ============================================================
-- State
-- ============================================================

local State = {
    ItemESP   = { Enabled = false, Range = 1500, Color = Color3.fromRGB(255, 214, 10) },
    PlayerESP = {
        Enabled = false, Range = 2000, Tracers = false,
        Color = Color3.fromRGB(255, 69, 58),
        Fields = { Name = true, Distance = true, Health = true, Stand = false, Spec = false, Level = false },
    },
    Farm  = { Enabled = false, Speed = 800, Priority = "Distance", Selected = {} },
    Sell  = { Enabled = false, DontSellRare = true, Selected = {}, Interval = 1.5 },
    Buy   = { Enabled = false, Interval = 2.0 },
    World = { Fullbright = false, NoFog = false, TimeOfDay = 14, FOV = 70 },
    Player = { WalkSpeed = 16, Fly = false, FlySpeed = 60, Noclip = false, AntiAFK = false },
    Settings = { ShowFPS = false, AutoPlay = false, IconSize = BASE_ICON_SIZE },
    FarmScreen = false,
}
for _, option in ipairs(FILTER_OPTIONS) do
    State.Farm.Selected[option] = true
    State.Sell.Selected[option] = false
end

-- ============================================================
-- Utilities
-- ============================================================

local alive = true
local Connections = {}
local function track(conn)
    table.insert(Connections, conn)
    return conn
end

local function safeCall(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
        warn("[" .. HUB_NAME .. "] " .. tostring(err))
    end
    return ok
end

local function create(class, props, children)
    local inst = Instance.new(class)
    local parent = nil
    if props then
        for k, v in pairs(props) do
            if k == "Parent" then parent = v else inst[k] = v end
        end
    end
    if children then
        for _, c in ipairs(children) do c.Parent = inst end
    end
    if parent then inst.Parent = parent end
    return inst
end

local function corner(radius) return create("UICorner", { CornerRadius = UDim.new(0, radius) }) end
local function pill() return create("UICorner", { CornerRadius = UDim.new(1, 0) }) end
local function stroke(color, thickness)
    return create("UIStroke", {
        Color = color, Thickness = thickness,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })
end

local function newLabel(props)
    props.BackgroundTransparency = 1
    props.BorderSizePixel = 0
    props.Font = props.Font or Enum.Font.GothamMedium
    props.TextSize = props.TextSize or 13
    props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
    return create("TextLabel", props)
end

local function getRoot()
    local char = LocalPlayer.Character
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

local function getScreenSize()
    local cam = Workspace.CurrentCamera
    if cam and cam.ViewportSize.X > 0 then return cam.ViewportSize end
    return Vector2.new(800, 450)
end

local function clampPosition(x, y, w, h)
    local s = getScreenSize()
    return math.clamp(x, 0, math.max(s.X - w, 0)), math.clamp(y, 0, math.max(s.Y - h, 0))
end

local function getItemInfo(name)
    if type(name) ~= "string" or name == "" then return nil end
    local low = string.lower(name)
    for _, entry in ipairs(CATALOG_BY_LENGTH) do
        if string.find(low, entry.key, 1, true) then return entry end
    end
    return nil
end

local function findPromptByKeywords(keywords)
    for _, desc in ipairs(Workspace:GetDescendants()) do
        if desc:IsA("ProximityPrompt") then
            local holder = desc:FindFirstAncestorOfClass("Model") or desc.Parent
            local name = holder and holder.Name or ""
            local lower = string.lower(name)
            for _, kw in ipairs(keywords) do
                if string.find(lower, kw, 1, true) then return desc end
            end
        end
    end
    return nil
end

local function findRemoteByName(keywords)
    local containers = { ReplicatedStorage, ReplicatedStorage:FindFirstChild("Remotes"), ReplicatedStorage:FindFirstChild("RemoteEvents"), ReplicatedStorage:FindFirstChild("Events") }
    for _, container in ipairs(containers) do
        if container then
            for _, desc in ipairs(container:GetDescendants()) do
                if desc:IsA("RemoteEvent") or desc:IsA("RemoteFunction") or desc:IsA("UnreliableRemoteEvent") then
                    local lower = string.lower(desc.Name)
                    for _, kw in ipairs(keywords) do
                        if string.find(lower, kw, 1, true) then return desc end
                    end
                end
            end
        end
    end
    return nil
end

local function getPlayerMoney()
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    if ls then
        for _, n in ipairs({ "Money", "Cash", "Yen", "Coins", "Currency" }) do
            local v = ls:FindFirstChild(n)
            if v and v:IsA("ValueBase") then return v.Value end
        end
    end
    for _, n in ipairs({ "Money", "Cash", "Yen", "Coins" }) do
        local v = LocalPlayer:FindFirstChild(n)
        if v and v:IsA("ValueBase") then return v.Value end
        local a = LocalPlayer:GetAttribute(n)
        if a then return a end
    end
    return nil
end

-- YBA-specific field readers (best-effort, multiple paths)
local function getPlayerStand(player)
    local attr = player:GetAttribute("StandName") or player:GetAttribute("Stand")
    if attr then return tostring(attr) end
    local v = player:FindFirstChild("StandName") or player:FindFirstChild("Stand")
    if v and v:IsA("ValueBase") then return tostring(v.Value) end
    local char = player.Character
    if char then
        local s = char:FindFirstChild("Stand")
        if s then return s.Name end
    end
    return "—"
end

local function getPlayerSpec(player)
    local attr = player:GetAttribute("Specialization") or player:GetAttribute("Spec")
    if attr then return tostring(attr) end
    local v = player:FindFirstChild("Specialization") or player:FindFirstChild("Spec")
    if v and v:IsA("ValueBase") then return tostring(v.Value) end
    return "—"
end

local function getPlayerLevel(player)
    local ls = player:FindFirstChild("leaderstats")
    if ls then
        local lvl = ls:FindFirstChild("Level") or ls:FindFirstChild("Lvl")
        if lvl and lvl:IsA("ValueBase") then return tostring(lvl.Value) end
    end
    local attr = player:GetAttribute("Level")
    if attr then return tostring(attr) end
    local v = player:FindFirstChild("Level")
    if v and v:IsA("ValueBase") then return tostring(v.Value) end
    return "—"
end

-- ============================================================
-- Mount ScreenGuis
-- ============================================================

local function mount(instance)
    local candidates = {}
    if type(gethui) == "function" then
        table.insert(candidates, function() return gethui() end)
    end
    table.insert(candidates, function() return CoreGui end)
    table.insert(candidates, function() return LocalPlayer:WaitForChild("PlayerGui") end)
    for _, get in ipairs(candidates) do
        local ok, parent = pcall(get)
        if ok and parent then
            local ok2 = pcall(function() instance.Parent = parent end)
            if ok2 and instance.Parent == parent then return true end
        end
    end
    return false
end

local screenGui = create("ScreenGui", {
    Name = HUB_NAME, ResetOnSpawn = false, IgnoreGuiInset = true,
    DisplayOrder = 50, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
local tracerGui = create("ScreenGui", {
    Name = HUB_NAME .. "_Tracers", ResetOnSpawn = false,
    IgnoreGuiInset = true, DisplayOrder = 10, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
local espFolder = create("Folder", { Name = HUB_NAME .. "_ESP" })

if not (mount(screenGui) and mount(tracerGui) and mount(espFolder)) then
    error("[" .. HUB_NAME .. "] no writable UI container")
end

-- ============================================================
-- Tracers
-- ============================================================

local drawingSupported = pcall(function()
    local probe = Drawing.new("Line")
    probe:Remove()
end)

local function createTracer()
    if drawingSupported then
        local line = Drawing.new("Line")
        line.Thickness = 1.5
        line.Transparency = 1
        line.Visible = false
        return {
            update = function(from, to, color)
                line.From = from; line.To = to; line.Color = color; line.Visible = true
            end,
            hide = function() line.Visible = false end,
            destroy = function() pcall(function() line:Remove() end) end,
        }
    end
    local frame = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0,
        Visible = false, Parent = tracerGui,
    })
    return {
        update = function(from, to, color)
            local delta = to - from
            frame.Size = UDim2.fromOffset(delta.Magnitude, 1.5)
            frame.Position = UDim2.fromOffset((from.X + to.X) / 2, (from.Y + to.Y) / 2)
            frame.Rotation = math.deg(math.atan2(delta.Y, delta.X))
            frame.BackgroundColor3 = color
            frame.Visible = true
        end,
        hide = function() frame.Visible = false end,
        destroy = function() frame:Destroy() end,
    }
end

-- ============================================================
-- Item registry (for ESP and farm)
-- ============================================================

local Items = {}

local function getItemPart(inst)
    if inst:IsA("BasePart") then return inst end
    if inst:IsA("Model") then
        return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
    end
    return nil
end

local function resolveItem(inst, prompt)
    local candidates = { inst.Name }
    if prompt then
        table.insert(candidates, prompt.ObjectText)
        table.insert(candidates, prompt.ActionText)
    end
    for _, c in ipairs(candidates) do
        local info = getItemInfo(c)
        if info then return info.label, info end
    end
    return inst.Name, nil
end

local function itemAlive(rec)
    return rec.inst.Parent ~= nil
        and rec.part.Parent ~= nil
        and rec.inst:IsDescendantOf(Workspace)
        and (rec.prompt == nil or rec.prompt.Parent ~= nil)
end

local function destroyItemVisual(rec)
    if rec.highlight then rec.highlight:Destroy(); rec.highlight = nil end
    if rec.gui then rec.gui:Destroy(); rec.gui = nil end
    rec.tag = nil
end

local function clearItemESP()
    for _, rec in pairs(Items) do destroyItemVisual(rec) end
end

local function removeItem(inst)
    local rec = Items[inst]
    if rec then destroyItemVisual(rec); Items[inst] = nil end
end

local function addItem(inst)
    local part = getItemPart(inst)
    if not part then return end
    local prompt = inst:FindFirstChildWhichIsA("ProximityPrompt", true)
    local label, info = resolveItem(inst, prompt)
    Items[inst] = {
        inst = inst, part = part, prompt = prompt,
        label = label, value = info and info.value or 0,
        known = info ~= nil, rare = info and info.rare or isRareLabel(label),
    }
end

local function findItemsContainer()
    local node = Workspace
    for _, name in ipairs(ITEMS_PATH) do
        node = node and node:FindFirstChild(name)
    end
    return node
end

local function collectCandidates()
    local found = {}
    local container = findItemsContainer()
    if container then
        for _, child in ipairs(container:GetChildren()) do
            if child:IsA("Model") or child:IsA("BasePart") then found[child] = true end
        end
        return found
    end
    for _, desc in ipairs(Workspace:GetDescendants()) do
        if desc:IsA("ProximityPrompt") then
            local holder = desc:FindFirstAncestorOfClass("Model") or desc.Parent
            if holder and not Players:GetPlayerFromCharacter(holder) and getItemInfo(holder.Name) then
                found[holder] = true
            end
        end
    end
    return found
end

local function refreshItems()
    local found = collectCandidates()
    for inst in pairs(found) do
        if not Items[inst] then addItem(inst) end
    end
    for inst in pairs(Items) do
        if not found[inst] or not inst.Parent then removeItem(inst) end
    end
end

local function ensureItemVisual(rec)
    if rec.gui and rec.gui.Parent and rec.highlight and rec.highlight.Parent then return end
    destroyItemVisual(rec)
    rec.highlight = create("Highlight", {
        Name = "ItemHighlight", Adornee = rec.inst,
        FillTransparency = 0.65, OutlineTransparency = 0,
        DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Parent = espFolder,
    })
    rec.gui = create("BillboardGui", {
        Name = "ItemTag", Adornee = rec.part, AlwaysOnTop = true,
        Size = UDim2.fromOffset(180, 36), StudsOffset = Vector3.new(0, 2.5, 0),
        Parent = espFolder,
    })
    rec.tag = newLabel({
        Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextStrokeTransparency = 0.4, Parent = rec.gui,
    })
end

local function updateItemESP(originPos)
    local range = State.ItemESP.Range
    local color = State.ItemESP.Color
    for _, rec in pairs(Items) do
        if itemAlive(rec) then
            local dist = (rec.part.Position - originPos).Magnitude
            if dist <= range then
                ensureItemVisual(rec)
                rec.highlight.Enabled = true
                rec.highlight.FillColor = color
                rec.highlight.OutlineColor = color
                rec.gui.Enabled = true
                rec.tag.TextColor3 = color
                rec.tag.Text = string.format("%s\n%d studs", rec.label, math.floor(dist))
            elseif rec.gui then
                rec.highlight.Enabled = false
                rec.gui.Enabled = false
            end
        elseif rec.gui then
            destroyItemVisual(rec)
        end
    end
end

-- ============================================================
-- Player ESP
-- ============================================================

local PlayerRecords = {}

local function removePlayerRecord(player)
    local rec = PlayerRecords[player]
    if not rec then return end
    if rec.highlight then rec.highlight:Destroy() end
    if rec.gui then rec.gui:Destroy() end
    if rec.tracer then rec.tracer.destroy() end
    PlayerRecords[player] = nil
end

local function clearPlayerESP()
    for player in pairs(PlayerRecords) do removePlayerRecord(player) end
end

local function clearTracers()
    for _, rec in pairs(PlayerRecords) do
        if rec.tracer then rec.tracer.destroy(); rec.tracer = nil end
    end
end

local function buildPlayerText(player, humanoid, dist)
    local fields = State.PlayerESP.Fields
    local lines = {}
    if fields.Name then table.insert(lines, player.DisplayName) end
    if fields.Distance then table.insert(lines, math.floor(dist) .. " studs") end
    if fields.Health and humanoid then
        table.insert(lines, string.format("HP %d/%d", math.floor(humanoid.Health), math.floor(humanoid.MaxHealth)))
    end
    if fields.Stand then table.insert(lines, "Stand: " .. getPlayerStand(player)) end
    if fields.Spec then table.insert(lines, "Spec: " .. getPlayerSpec(player)) end
    if fields.Level then table.insert(lines, "Lvl " .. getPlayerLevel(player)) end
    if #lines == 0 then return player.DisplayName end
    return table.concat(lines, "\n")
end

local function ensurePlayerVisual(rec, char)
    if rec.char == char and rec.highlight and rec.highlight.Parent and rec.gui and rec.gui.Parent then
        return
    end
    if rec.highlight then rec.highlight:Destroy() end
    if rec.gui then rec.gui:Destroy() end
    rec.char = char
    rec.highlight = create("Highlight", {
        Name = "PlayerHighlight", Adornee = char,
        FillTransparency = 0.7, OutlineTransparency = 0,
        DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Parent = espFolder,
    })
    local adorn = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
    rec.gui = create("BillboardGui", {
        Name = "PlayerTag", Adornee = adorn, AlwaysOnTop = true,
        Size = UDim2.fromOffset(200, 80), StudsOffset = Vector3.new(0, 2.5, 0),
        Parent = espFolder,
    })
    rec.label = newLabel({
        Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextStrokeTransparency = 0.4, TextWrapped = true, Parent = rec.gui,
    })
end

local function updatePlayerESP(originPos, camera, slow)
    local range = State.PlayerESP.Range
    local color = State.PlayerESP.Color
    local viewport = camera.ViewportSize
    local center = Vector2.new(viewport.X / 2, viewport.Y / 2)

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            local targetRoot = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local dist = 0
            local inRange = false
            if targetRoot and hum and hum.Health > 0 then
                dist = (targetRoot.Position - originPos).Magnitude
                inRange = dist <= range
            end

            if inRange then
                local rec = PlayerRecords[player]
                if not rec then rec = {}; PlayerRecords[player] = rec end
                if slow or not rec.highlight then
                    ensurePlayerVisual(rec, char)
                    rec.highlight.FillColor = color
                    rec.highlight.OutlineColor = color
                    rec.label.TextColor3 = color
                    rec.label.Text = buildPlayerText(player, hum, dist)
                end
                if State.PlayerESP.Tracers then
                    local point, onScreen = camera:WorldToViewportPoint(targetRoot.Position)
                    if onScreen then
                        if not rec.tracer then rec.tracer = createTracer() end
                        rec.tracer.update(center, Vector2.new(point.X, point.Y), color)
                    elseif rec.tracer then
                        rec.tracer.hide()
                    end
                elseif rec.tracer then
                    rec.tracer.destroy(); rec.tracer = nil
                end
            else
                removePlayerRecord(player)
            end
        end
    end
end

track(Players.PlayerRemoving:Connect(removePlayerRecord))

local espClock = 0
track(RunService.RenderStepped:Connect(function(dt)
    if not (State.ItemESP.Enabled or State.PlayerESP.Enabled) then return end
    local camera = Workspace.CurrentCamera
    if not camera then return end
    local root = getRoot()
    local origin = root and root.Position or camera.CFrame.Position
    espClock += dt
    local slow = espClock >= 0.1
    if slow then espClock = 0 end
    if State.ItemESP.Enabled and slow then safeCall(updateItemESP, origin) end
    if State.PlayerESP.Enabled then safeCall(updatePlayerESP, origin, camera, slow) end
end))

task.spawn(function()
    while alive do
        if State.ItemESP.Enabled or State.Farm.Enabled or State.Sell.Enabled then
            pcall(refreshItems)
        end
        task.wait(1)
    end
end)

-- ============================================================
-- Farm / Fly / Stabilizer
-- ============================================================

local activeTween = nil
local flightId = 0
local farmToken = 0
local manualFlight = false
local farmStats = { picked = 0, failed = 0, startedAt = 0 }

local stabilizerUsers = 0
local stabilizerConn = nil
local stabilizerChar = nil
local stabilizerParts = {}

local function rebuildStabilizerParts(char)
    stabilizerChar = char
    stabilizerParts = {}
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then table.insert(stabilizerParts, part) end
    end
end

local function acquireStabilizer()
    stabilizerUsers += 1
    if stabilizerConn then return end
    stabilizerConn = RunService.Stepped:Connect(function()
        local char = LocalPlayer.Character
        if not char then return end
        if char ~= stabilizerChar then rebuildStabilizerParts(char) end
        for _, part in ipairs(stabilizerParts) do
            if part.Parent then part.CanCollide = false end
        end
        local root = char:FindFirstChild("HumanoidRootPart")
        if root then
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
    end)
end

local function releaseStabilizer()
    stabilizerUsers = math.max(stabilizerUsers - 1, 0)
    if stabilizerUsers == 0 and stabilizerConn then
        stabilizerConn:Disconnect()
        stabilizerConn = nil
        stabilizerChar = nil
        stabilizerParts = {}
    end
end

local function pickTarget(originPos, failures, priority)
    local best, bestDist, bestValue = nil, math.huge, -1
    local now = os.clock()
    for _, rec in pairs(Items) do
        if itemAlive(rec) and (rec.prompt == nil or rec.prompt.Enabled) then
            local key = rec.known and rec.label or "Other"
            local failure = failures[rec.inst]
            local blocked = failure ~= nil and failure.untilTime > now
            if State.Farm.Selected[key] and not blocked then
                local dist = (rec.part.Position - originPos).Magnitude
                local better
                if priority == "Value" then
                    better = rec.value > bestValue or (rec.value == bestValue and dist < bestDist)
                else
                    better = dist < bestDist
                end
                if better then
                    best, bestDist, bestValue = rec, dist, rec.value
                end
            end
        end
    end
    return best, bestDist
end

local function flyTo(position, rec)
    local root = getRoot()
    if not root then return "nochar" end
    flightId += 1
    local myId = flightId
    local distance = (root.Position - position).Magnitude
    local duration = math.max(distance / State.Farm.Speed, 0.05)
    local goal = CFrame.new(position) * root.CFrame.Rotation
    local tween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), { CFrame = goal })
    activeTween = tween
    tween:Play()

    local start = os.clock()
    local result = "arrived"
    while tween.PlaybackState ~= Enum.PlaybackState.Completed and tween.PlaybackState ~= Enum.PlaybackState.Cancelled do
        if myId ~= flightId then result = "cancelled"; break end
        if rec and not itemAlive(rec) then result = "gone"; break end
        if not getRoot() then result = "nochar"; break end
        if os.clock() - start > duration + 2 then result = "timeout"; break end
        RunService.Heartbeat:Wait()
    end
    if result == "arrived" and tween.PlaybackState ~= Enum.PlaybackState.Completed then
        result = "cancelled"
    end
    if tween.PlaybackState ~= Enum.PlaybackState.Completed then tween:Cancel() end
    if activeTween == tween then activeTween = nil end
    return result
end

local function pickUp(rec)
    local prompt = rec.prompt
    local fireProx = fireproximityprompt
    if prompt and prompt.Parent and type(fireProx) == "function" then
        pcall(fireProx, prompt); return
    end
    local key = Enum.KeyCode.E
    local hold = 0.3
    if prompt and prompt.Parent then
        if prompt.KeyboardKeyCode ~= Enum.KeyCode.Unknown then key = prompt.KeyboardKeyCode end
        hold = math.max(prompt.HoldDuration, 0) + 0.15
    end
    VirtualInputManager:SendKeyEvent(true, key, false, game)
    task.wait(hold)
    VirtualInputManager:SendKeyEvent(false, key, false, game)
end

local function farmStep(failures)
    local root = getRoot()
    if not root then task.wait(0.5); return end
    refreshItems()
    local target, dist = pickTarget(root.Position, failures, State.Farm.Priority)
    if not target then task.wait(0.5); return end
    local result = flyTo(target.part.Position + PICKUP_HOVER_OFFSET, target)
    if result == "gone" then farmStats.failed += 1; return end
    if result ~= "arrived" or not itemAlive(target) then return end
    pickUp(target)
    task.wait(0.6)
    if itemAlive(target) then
        farmStats.failed += 1
        local f = failures[target.inst]
        if not f then f = { count = 0, untilTime = 0 }; failures[target.inst] = f end
        f.count += 1
        if f.count >= 3 then f.count = 0; f.untilTime = os.clock() + 30 end
    else
        farmStats.picked += 1
        failures[target.inst] = nil
    end
end

local function farmLoop(token)
    acquireStabilizer()
    local failures = {}
    farmStats.startedAt = os.clock()
    while alive and farmToken == token and State.Farm.Enabled do
        local ok = safeCall(farmStep, failures)
        if not ok then task.wait(0.5) end
        RunService.Heartbeat:Wait()
    end
    releaseStabilizer()
end

local function stopFarm()
    State.Farm.Enabled = false
    farmToken += 1
    flightId += 1
    if activeTween then pcall(function() activeTween:Cancel() end); activeTween = nil end
end

local function startFarm()
    State.Farm.Enabled = true
    farmToken += 1
    task.spawn(farmLoop, farmToken)
end

local function flyToNearest()
    if manualFlight then return end
    if State.Farm.Enabled then return end
    manualFlight = true
    task.spawn(function()
        pcall(function()
            refreshItems()
            local root = getRoot()
            if not root then return end
            local target = pickTarget(root.Position, {}, "Distance")
            if not target then return end
            acquireStabilizer()
            flyTo(target.part.Position + PICKUP_HOVER_OFFSET, target)
            releaseStabilizer()
        end)
        manualFlight = false
    end)
end

-- ============================================================
-- Auto Sell / Auto Buy
-- ============================================================

local function clickButton(button)
    pcall(function() button.MouseButton1Click:Fire() end)
end

local function waitForGuiWithKeywords(keywords, timeout)
    local start = os.clock()
    while os.clock() - start < (timeout or 3) do
        for _, gui in ipairs(LocalPlayer.PlayerGui:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Enabled then
                local lower = string.lower(gui.Name)
                for _, kw in ipairs(keywords) do
                    if string.find(lower, kw, 1, true) then return gui end
                end
            end
        end
        task.wait(0.15)
    end
    return nil
end

local function openShop()
    local prompt = findPromptByKeywords({ "shop", "merchant", "store", "sell", "vendor" })
    if prompt then
        local fireProx = fireproximityprompt
        if type(fireProx) == "function" then
            pcall(fireProx, prompt)
        else
            pcall(function() prompt:InputHoldBegin() end)
            task.wait(math.max(prompt.HoldDuration, 0.1) + 0.1)
            pcall(function() prompt:InputHoldEnd() end)
        end
        task.wait(0.5)
        return waitForGuiWithKeywords({ "shop", "store", "sell", "merchant" }, 3)
    end
    return nil
end

local function fireSellRemote(itemName)
    local remote = findRemoteByName({ "sellitem", "sell", "sold" })
    if remote then
        pcall(function()
            if remote:IsA("RemoteFunction") then
                remote:InvokeServer(itemName)
            else
                remote:FireServer(itemName)
            end
        end)
        return true
    end
    return false
end

local function sellOnce()
    local gui = openShop()
    if not gui then return false end
    local sold = 0
    for _, desc in ipairs(gui:GetDescendants()) do
        if desc:IsA("TextButton") then
            local text = string.lower(desc.Text or "")
            if string.find(text, "sell", 1, true) and not string.find(text, "sell all", 1, true) then
                local parent = desc.Parent
                local itemLabel = parent and parent:FindFirstChildWhichIsA("TextLabel", true)
                local itemText = itemLabel and itemLabel.Text or ""
                local info = getItemInfo(itemText)
                local label = info and info.label or "Other"
                if State.Sell.Selected[label] and not (State.Sell.DontSellRare and isRareLabel(itemText)) then
                    clickButton(desc)
                    sold += 1
                    task.wait(0.1)
                end
            end
        end
    end
    if sold > 0 then return true end
    -- remote fallback
    for label, on in pairs(State.Sell.Selected) do
        if on and not (State.Sell.DontSellRare and isRareLabel(label)) then
            if fireSellRemote(label) then sold += 1 end
        end
    end
    return sold > 0
end

local function buyLuckyArrowOnce()
    local money = getPlayerMoney()
    if money and money < LUCKY_ARROW_PRICE then return false end
    local gui = openShop()
    if not gui then
        local remote = findRemoteByName({ "buyitem", "buy", "purchase" })
        if remote then
            pcall(function()
                if remote:IsA("RemoteFunction") then
                    remote:InvokeServer("Lucky Arrow")
                else
                    remote:FireServer("Lucky Arrow")
                end
            end)
            return true
        end
        return false
    end
    for _, desc in ipairs(gui:GetDescendants()) do
        if desc:IsA("TextButton") or desc:IsA("ImageButton") then
            local n = string.lower(desc.Name)
            local t = string.lower(desc.Text or "")
            if string.find(n, "lucky", 1, true) or string.find(t, "lucky", 1, true) then
                clickButton(desc)
                return true
            end
        end
    end
    return false
end

task.spawn(function()
    local sellClock = 0
    local buyClock = 0
    while alive do
        local dt = task.wait(0.25)
        if State.Sell.Enabled then
            sellClock += dt
            if sellClock >= State.Sell.Interval then
                sellClock = 0
                safeCall(sellOnce)
            end
        end
        if State.Buy.Enabled then
            buyClock += dt
            if buyClock >= State.Buy.Interval then
                buyClock = 0
                safeCall(buyLuckyArrowOnce)
            end
        end
    end
end)

-- ============================================================
-- World visuals: fullbright, no fog, time, FOV
-- ============================================================

local originalLighting = {
    Brightness = Lighting.Brightness,
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    FogEnd = Lighting.FogEnd,
    FogStart = Lighting.FogStart,
    TimeOfDay = Lighting.TimeOfDay,
    ClockTime = Lighting.ClockTime,
    FieldOfView = 70,
}

local function applyWorld()
    local w = State.World
    if w.Fullbright then
        Lighting.Brightness = 3
        Lighting.Ambient = Color3.fromRGB(178, 178, 178)
        Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
    else
        Lighting.Brightness = originalLighting.Brightness
        Lighting.Ambient = originalLighting.Ambient
        Lighting.OutdoorAmbient = originalLighting.OutdoorAmbient
    end
    if w.NoFog then
        Lighting.FogEnd = 1e6
        Lighting.FogStart = 1e6
    else
        Lighting.FogEnd = originalLighting.FogEnd
        Lighting.FogStart = originalLighting.FogStart
    end
    Lighting.ClockTime = w.TimeOfDay
    local cam = Workspace.CurrentCamera
    if cam then cam.FieldOfView = w.FOV end
end

-- ============================================================
-- Player: walkspeed, fly, noclip
-- ============================================================

local flyConn = nil
local flyBV, flyBG = nil, nil

local function stopFly()
    if flyConn then flyConn:Disconnect(); flyConn = nil end
    if flyBV then flyBV:Destroy(); flyBV = nil end
    if flyBG then flyBG:Destroy(); flyBG = nil end
end

local function startFly()
    stopFly()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    flyBV = create("BodyVelocity", {
        MaxForce = Vector3.new(1e9, 1e9, 1e9), Velocity = Vector3.zero, Parent = root,
    })
    flyBG = create("BodyGyro", {
        MaxTorque = Vector3.new(1e9, 1e9, 1e9), P = 10000, D = 500,
        CFrame = root.CFrame, Parent = root,
    })
    local cam = Workspace.CurrentCamera
    flyConn = RunService.RenderStepped:Connect(function()
        local c = LocalPlayer.Character
        local r = c and c:FindFirstChild("HumanoidRootPart")
        if not r then stopFly(); return end
        if flyBV.Parent ~= r then
            flyBV.Parent = r; flyBG.Parent = r
        end
        local dir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.new(0, 1, 0) end
        if dir.Magnitude > 0 then dir = dir.Unit end
        flyBV.Velocity = dir * State.Player.FlySpeed
        flyBG.CFrame = cam.CFrame
    end)
end

local function updateWalkspeed()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = State.Player.WalkSpeed end
end

track(LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    if State.Player.Fly then startFly() end
    updateWalkspeed()
end))

-- Noclip loop
task.spawn(function()
    while alive do
        if State.Player.Noclip then
            local char = LocalPlayer.Character
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = false end
                end
            end
        end
        task.wait(0.15)
    end
end)

-- ============================================================
-- Anti AFK + Auto Play
-- ============================================================

track(LocalPlayer.Idled:Connect(function()
    if not State.Player.AntiAFK then return end
    local vu = game:GetService("VirtualUser")
    pcall(function() vu:CaptureController() end)
    pcall(function() vu:ClickButton2(Vector2.new()) end)
end))

task.spawn(function()
    while alive do
        if State.Settings.AutoPlay then
            pcall(function()
                for _, gui in ipairs(LocalPlayer.PlayerGui:GetChildren()) do
                    if gui:IsA("ScreenGui") and gui.Enabled then
                        for _, desc in ipairs(gui:GetDescendants()) do
                            if desc:IsA("TextButton") or desc:IsA("ImageButton") then
                                local n = string.lower(desc.Name)
                                local t = string.lower(desc.Text or "")
                                if n == "play" or n == "playbutton" or string.find(n, "play", 1, true)
                                    or t == "play" or string.find(t, "play", 1, true) then
                                    pcall(function() desc.MouseButton1Click:Fire() end)
                                    return
                                end
                            end
                        end
                    end
                end
            end)
        end
        task.wait(1)
    end
end)

-- ============================================================
-- UI helpers: drag, tabs, controls
-- ============================================================

local function isPointerDown(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch
end

local function makeDraggable(handle, target, onTap)
    local active, startPointer, startPos, moved = nil, Vector2.zero, Vector2.zero, false
    handle.InputBegan:Connect(function(input)
        if not isPointerDown(input) then return end
        active = input
        moved = false
        startPointer = Vector2.new(input.Position.X, input.Position.Y)
        startPos = target.AbsolutePosition
        local conn
        conn = input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                conn:Disconnect()
                if active == input then
                    active = nil
                    if not moved and onTap then onTap() end
                end
            end
        end)
    end)
    track(UserInputService.InputChanged:Connect(function(input)
        if not active then return end
        if input ~= active and input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        local delta = Vector2.new(input.Position.X, input.Position.Y) - startPointer
        if not moved and delta.Magnitude < 6 then return end
        moved = true
        local size = target.AbsoluteSize
        local x, y = clampPosition(startPos.X + delta.X, startPos.Y + delta.Y, size.X, size.Y)
        target.Position = UDim2.fromOffset(x, y)
    end))
end

local function trackDrag(hit, scroller, onDrag)
    local active = nil
    hit.InputBegan:Connect(function(input)
        if not isPointerDown(input) then return end
        active = input
        scroller.ScrollingEnabled = false
        onDrag(input.Position)
        local conn
        conn = input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                conn:Disconnect()
                if active == input then
                    active = nil
                    scroller.ScrollingEnabled = true
                end
            end
        end)
    end)
    track(UserInputService.InputChanged:Connect(function(input)
        if active and (input == active or input.UserInputType == Enum.UserInputType.MouseMovement) then
            onDrag(input.Position)
        end
    end))
end

local orderCounters = {}
local function nextOrder(page)
    orderCounters[page] = (orderCounters[page] or 0) + 1
    return orderCounters[page]
end

local function addSection(page, text)
    return themed(newLabel({
        Size = UDim2.new(1, 0, 0, 22), Text = string.upper(text),
        Font = Enum.Font.GothamBold, TextSize = 11,
        LayoutOrder = nextOrder(page), Parent = page,
    }), "SubText")
end

local function addLabel(page, text)
    return themed(newLabel({
        Size = UDim2.new(1, 0, 0, 24), Text = text, TextSize = 12,
        TextWrapped = true, LayoutOrder = nextOrder(page), Parent = page,
    }), "SubText")
end

local function addToggle(page, text, default, callback)
    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, 40), BorderSizePixel = 0,
        LayoutOrder = nextOrder(page), Parent = page,
    }, { corner(8) })
    themed(row, "Panel")
    themed(newLabel({ Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -70, 1, 0), Text = text, Parent = row }), "Text")
    local trackFrame = create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(40, 22), BorderSizePixel = 0, Parent = row,
    }, { pill() })
    local knob = create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, 0),
        Size = UDim2.fromOffset(18, 18), BorderSizePixel = 0, Parent = trackFrame,
    }, { pill() })
    themed(knob, "White")
    local hit = create("TextButton", {
        BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "", AutoButtonColor = false, Parent = row,
    })

    local value = default
    local info = TweenInfo.new(0.15, Enum.EasingStyle.Quad)
    local function render(animate)
        local trackColor = value and Theme.On or Theme.Off
        local knobPos = value and UDim2.new(1, -20, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)
        if animate then
            TweenService:Create(trackFrame, info, { BackgroundColor3 = trackColor }):Play()
            TweenService:Create(knob, info, { Position = knobPos }):Play()
        else
            trackFrame.BackgroundColor3 = trackColor
            knob.Position = knobPos
        end
    end
    render(false)
    onThemeChange(function() render(false) end)

    hit.MouseButton1Click:Connect(function()
        value = not value
        render(true)
        safeCall(callback, value)
    end)
end

local function addSlider(page, text, min, max, default, step, suffix, callback)
    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, 58), BorderSizePixel = 0,
        LayoutOrder = nextOrder(page), Parent = page,
    }, { corner(8) })
    themed(row, "Panel")
    themed(newLabel({ Position = UDim2.fromOffset(12, 6), Size = UDim2.new(0.6, 0, 0, 20), Text = text, Parent = row }), "Text")
    local valueLabel = themed(newLabel({
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 6),
        Size = UDim2.new(0.4, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Right, Parent = row,
    }), "SubText")
    local rail = create("Frame", {
        Position = UDim2.new(0, 12, 0, 38), Size = UDim2.new(1, -24, 0, 6),
        BorderSizePixel = 0, Parent = row,
    }, { pill() })
    themed(rail, "Off")
    local fill = create("Frame", {
        Size = UDim2.fromScale(0, 1), BorderSizePixel = 0, Parent = rail,
    }, { pill() })
    themed(fill, "Accent")
    local knob = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.fromOffset(16, 16), BorderSizePixel = 0, ZIndex = 2, Parent = rail,
    }, { pill() })
    themed(knob, "White")
    local hit = create("TextButton", {
        BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 26),
        Size = UDim2.new(1, 0, 0, 32), Text = "", AutoButtonColor = false, Parent = row,
    })

    local function setValue(raw, fire)
        local value = math.clamp(math.floor((raw - min) / step + 0.5) * step + min, min, max)
        local alpha = (value - min) / (max - min)
        fill.Size = UDim2.fromScale(alpha, 1)
        knob.Position = UDim2.fromScale(alpha, 0.5)
        valueLabel.Text = tostring(value) .. suffix
        if fire then safeCall(callback, value) end
    end
    trackDrag(hit, page, function(pos)
        local alpha = math.clamp((pos.X - rail.AbsolutePosition.X) / math.max(rail.AbsoluteSize.X, 1), 0, 1)
        setValue(min + alpha * (max - min), true)
    end)
    setValue(default, false)
end

local function addColorPicker(page, text, default, callback)
    local h, s, v = Color3.toHSV(default)
    local container = create("Frame", {
        Size = UDim2.new(1, 0, 0, 40), BorderSizePixel = 0, ClipsDescendants = true,
        LayoutOrder = nextOrder(page), Parent = page,
    }, { corner(8) })
    themed(container, "Panel")
    themed(newLabel({
        Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -70, 0, 40), Text = text, Parent = container,
    }), "Text")
    local swatch = create("Frame", {
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 10),
        Size = UDim2.fromOffset(34, 20), BackgroundColor3 = default, BorderSizePixel = 0, Parent = container,
    }, { corner(6), stroke(Color3.fromRGB(80, 80, 80), 1) })
    local headerHit = create("TextButton", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), Text = "", AutoButtonColor = false, Parent = container,
    })

    local svBox = create("Frame", {
        Position = UDim2.fromOffset(12, 48), Size = UDim2.new(1, -56, 0, 100),
        BackgroundColor3 = Color3.fromHSV(h, 1, 1), BorderSizePixel = 0, Parent = container,
    }, { corner(6) })
    create("Frame", {
        Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = svBox,
    }, { corner(6), create("UIGradient", {
        Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
    }) })
    create("Frame", {
        Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Parent = svBox,
    }, { corner(6), create("UIGradient", {
        Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }),
    }) })
    local svKnob = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(12, 12),
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 3, Parent = svBox,
    }, { pill(), stroke(Color3.new(0, 0, 0), 1.5) })

    local hueBar = create("Frame", {
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 48),
        Size = UDim2.fromOffset(24, 100), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = container,
    }, { corner(6), create("UIGradient", {
        Rotation = 90, Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
            ColorSequenceKeypoint.new(1/6, Color3.fromRGB(255, 255, 0)),
            ColorSequenceKeypoint.new(2/6, Color3.fromRGB(0, 255, 0)),
            ColorSequenceKeypoint.new(3/6, Color3.fromRGB(0, 255, 255)),
            ColorSequenceKeypoint.new(4/6, Color3.fromRGB(0, 0, 255)),
            ColorSequenceKeypoint.new(5/6, Color3.fromRGB(255, 0, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
        }),
    }) })
    local hueKnob = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(1, 4, 0, 6),
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 3, Parent = hueBar,
    }, { corner(3), stroke(Color3.new(0, 0, 0), 1.5) })

    local function apply(fire)
        local color = Color3.fromHSV(h, s, v)
        swatch.BackgroundColor3 = color
        svBox.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
        svKnob.Position = UDim2.fromScale(s, 1 - v)
        hueKnob.Position = UDim2.fromScale(0.5, h)
        if fire then safeCall(callback, color) end
    end
    apply(false)

    trackDrag(svBox, page, function(pos)
        s = math.clamp((pos.X - svBox.AbsolutePosition.X) / math.max(svBox.AbsoluteSize.X, 1), 0, 1)
        v = 1 - math.clamp((pos.Y - svBox.AbsolutePosition.Y) / math.max(svBox.AbsoluteSize.Y, 1), 0, 1)
        apply(true)
    end)
    trackDrag(hueBar, page, function(pos)
        h = math.clamp((pos.Y - hueBar.AbsolutePosition.Y) / math.max(hueBar.AbsoluteSize.Y, 1), 0, 0.999)
        apply(true)
    end)

    local expanded = false
    headerHit.MouseButton1Click:Connect(function()
        expanded = not expanded
        TweenService:Create(container, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
            Size = UDim2.new(1, 0, 0, expanded and 160 or 40),
        }):Play()
    end)
end

local function addDropdown(page, text, options, default, callback)
    local rowHeight = 30
    local container = create("Frame", {
        Size = UDim2.new(1, 0, 0, 40), BorderSizePixel = 0, ClipsDescendants = true,
        LayoutOrder = nextOrder(page), Parent = page,
    }, { corner(8) })
    themed(container, "Panel")
    themed(newLabel({ Position = UDim2.fromOffset(12, 0), Size = UDim2.new(0.5, 0, 0, 40), Text = text, Parent = container }), "Text")
    local valueLabel = themed(newLabel({
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -30, 0, 0),
        Size = UDim2.new(0.5, -30, 0, 40), TextXAlignment = Enum.TextXAlignment.Right,
        Text = default, Parent = container,
    }), "SubText")
    local arrow = themed(newLabel({
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 0),
        Size = UDim2.fromOffset(16, 40), Text = ">", Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center, Parent = container,
    }), "SubText")
    local headerHit = create("TextButton", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), Text = "", AutoButtonColor = false, Parent = container,
    })

    local selected = default
    local buttons = {}
    local buttonHooks = {}

    local function render()
        valueLabel.Text = selected
        for option, button in pairs(buttons) do
            local isSel = option == selected
            button.BackgroundColor3 = isSel and Theme.Accent or Theme.Raised
            button.TextColor3 = isSel and Theme.White or Theme.Text
        end
    end

    for index, option in ipairs(options) do
        local b = create("TextButton", {
            Position = UDim2.fromOffset(8, 40 + (index - 1) * rowHeight),
            Size = UDim2.new(1, -16, 0, rowHeight - 4),
            BorderSizePixel = 0, AutoButtonColor = false, Text = option,
            Font = Enum.Font.GothamMedium, TextSize = 13, Parent = container,
        }, { corner(6) })
        buttons[option] = b
        b.MouseButton1Click:Connect(function()
            selected = option
            render()
            safeCall(callback, option)
        end)
    end
    render()
    onThemeChange(render)

    local expanded = false
    headerHit.MouseButton1Click:Connect(function()
        expanded = not expanded
        TweenService:Create(container, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
            Size = UDim2.new(1, 0, 0, expanded and (40 + #options * rowHeight + 6) or 40),
        }):Play()
        TweenService:Create(arrow, TweenInfo.new(0.18), { Rotation = expanded and 90 or 0 }):Play()
    end)
end

local function addMultiDropdown(page, text, options, selectedMap, callback)
    local rowHeight = 30
    local listTop = 78
    local container = create("Frame", {
        Size = UDim2.new(1, 0, 0, 40), BorderSizePixel = 0, ClipsDescendants = true,
        LayoutOrder = nextOrder(page), Parent = page,
    }, { corner(8) })
    themed(container, "Panel")
    themed(newLabel({ Position = UDim2.fromOffset(12, 0), Size = UDim2.new(0.5, 0, 0, 40), Text = text, Parent = container }), "Text")
    local valueLabel = themed(newLabel({
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -30, 0, 0),
        Size = UDim2.new(0.5, -30, 0, 40), TextXAlignment = Enum.TextXAlignment.Right, Parent = container,
    }), "SubText")
    local arrow = themed(newLabel({
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 0),
        Size = UDim2.fromOffset(16, 40), Text = ">", Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center, Parent = container,
    }), "SubText")
    local headerHit = create("TextButton", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), Text = "", AutoButtonColor = false, Parent = container,
    })

    local boxes = {}
    local rows = {}
    local function render()
        local count = 0
        for option, box in pairs(boxes) do
            local on = selectedMap[option] == true
            box.BackgroundColor3 = on and Theme.On or Theme.Off
            local rowBtn = rows[option]
            if rowBtn then rowBtn.BackgroundColor3 = Theme.Raised end
            if on then count += 1 end
        end
        valueLabel.Text = count .. "/" .. #options
    end

    local function quickButton(label, xScale, xOff, setAll)
        local b = create("TextButton", {
            Position = UDim2.new(xScale, xOff, 0, 44),
            Size = UDim2.new(0.5, -12, 0, 28), BorderSizePixel = 0, AutoButtonColor = false,
            Text = label, Font = Enum.Font.GothamBold, TextSize = 12, Parent = container,
        }, { corner(6) })
        themed(b, "Raised")
        themed(b, "Text") -- text color; will re-apply background too but ok
        b.MouseButton1Click:Connect(function()
            for _, o in ipairs(options) do selectedMap[o] = setAll end
            render()
            safeCall(callback, selectedMap)
        end)
    end
    quickButton("Select all", 0, 8, true)
    quickButton("Clear", 0.5, 4, false)

    for i, option in ipairs(options) do
        local row = create("TextButton", {
            Position = UDim2.fromOffset(8, listTop + (i - 1) * rowHeight),
            Size = UDim2.new(1, -16, 0, rowHeight - 4), BorderSizePixel = 0,
            AutoButtonColor = false, Text = "", Parent = container,
        }, { corner(6) })
        rows[option] = row
        themed(row, "Raised")
        boxes[option] = create("Frame", {
            AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0),
            Size = UDim2.fromOffset(14, 14), BorderSizePixel = 0, Parent = row,
        }, { corner(4) })
        themed(newLabel({
            Position = UDim2.fromOffset(30, 0), Size = UDim2.new(1, -36, 1, 0), Text = option, Parent = row,
        }), "Text")
        row.MouseButton1Click:Connect(function()
            selectedMap[option] = not selectedMap[option]
            render()
            safeCall(callback, selectedMap)
        end)
    end
    render()
    onThemeChange(render)

    local expanded = false
    headerHit.MouseButton1Click:Connect(function()
        expanded = not expanded
        TweenService:Create(container, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
            Size = UDim2.new(1, 0, 0, expanded and (listTop + #options * rowHeight + 6) or 40),
        }):Play()
        TweenService:Create(arrow, TweenInfo.new(0.18), { Rotation = expanded and 90 or 0 }):Play()
    end)
end

local function addButton(page, text, callback)
    local b = create("TextButton", {
        Size = UDim2.new(1, 0, 0, 38), BorderSizePixel = 0,
        AutoButtonColor = false, Text = text, Font = Enum.Font.GothamBold,
        TextSize = 13, LayoutOrder = nextOrder(page), Parent = page,
    }, { corner(8) })
    themed(b, "Accent")
    themed(b, "White")
    b.MouseButton1Click:Connect(function()
        b.BackgroundColor3 = Theme.AccentHi
        TweenService:Create(b, TweenInfo.new(0.25), { BackgroundColor3 = Theme.Accent }):Play()
        safeCall(callback)
    end)
end

-- ============================================================
-- Window
-- ============================================================

local function computeWindowSize()
    local s = getScreenSize()
    return math.clamp(s.X - 40, 340, 580), math.clamp(s.Y - 40, 260, 400)
end

local normalW, normalH = computeWindowSize()
local winW, winH = normalW, normalH
local startScreen = getScreenSize()

local window = create("CanvasGroup", {
    Name = "Window", Active = true, BorderSizePixel = 0,
    Position = UDim2.fromOffset(math.floor((startScreen.X - winW) / 2), math.floor((startScreen.Y - winH) / 2)),
    Size = UDim2.fromOffset(winW, winH), Parent = screenGui,
}, { corner(12), stroke(Color3.fromRGB(20, 20, 25), 2) })
themed(window, "Background")

local titleBar = create("Frame", {
    Name = "TitleBar", Active = true, BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 0, TITLE_HEIGHT), Parent = window,
})
themed(titleBar, "Panel")
create("Frame", {
    Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1), BorderSizePixel = 0, Parent = titleBar,
}, {}).BackgroundColor3 = Theme.Border

local titleLabel = themed(newLabel({
    Name = "Title", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(180, 20), Text = HUB_NAME, Font = Enum.Font.GothamBold,
    TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center, Parent = titleBar,
}), "Text")

local fpsLabel = themed(newLabel({
    AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
    Size = UDim2.fromOffset(80, 20), Text = "", TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Right, Parent = titleBar,
}), "SubText")

local function makeLight(color, xOff)
    return create("TextButton", {
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, xOff, 0.5, 0),
        Size = UDim2.fromOffset(18, 18), BackgroundColor3 = color, BorderSizePixel = 0,
        AutoButtonColor = false, Text = "", Font = Enum.Font.GothamBold,
        TextSize = 13, TextColor3 = Color3.fromRGB(45, 45, 45), Parent = titleBar,
    }, { pill() })
end

local closeLight = makeLight(Color3.fromRGB(255, 95, 87), 12)
local minimizeLight = makeLight(Color3.fromRGB(254, 188, 46), 38)
local zoomLight = makeLight(Color3.fromRGB(40, 200, 64), 64)

local lightGlyphs = { [closeLight] = "x", [minimizeLight] = "-", [zoomLight] = "+" }
for light in pairs(lightGlyphs) do
    light.MouseEnter:Connect(function()
        for other, g in pairs(lightGlyphs) do other.Text = g end
    end)
    light.MouseLeave:Connect(function()
        for other in pairs(lightGlyphs) do other.Text = "" end
    end)
end

local sidebar = create("Frame", {
    Name = "Sidebar", Active = true, BorderSizePixel = 0,
    Position = UDim2.fromOffset(0, TITLE_HEIGHT),
    Size = UDim2.new(0, SIDEBAR_WIDTH, 1, -TITLE_HEIGHT), Parent = window,
})
themed(sidebar, "Panel")
create("Frame", {
    Position = UDim2.new(1, -1, 0, 0), Size = UDim2.new(0, 1, 1, 0), BorderSizePixel = 0, Parent = sidebar,
}, {}).BackgroundColor3 = Theme.Border

local tabList = create("Frame", {
    BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -30), Parent = sidebar,
}, {
    create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
    create("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 9) }),
})
themed(newLabel({
    AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8),
    Size = UDim2.new(1, -16, 0, 16), Text = "YBA", TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Center, Parent = sidebar,
}), "SubText")

local content = create("Frame", {
    Name = "Content", BackgroundTransparency = 1, ClipsDescendants = true,
    Position = UDim2.fromOffset(SIDEBAR_WIDTH, TITLE_HEIGHT),
    Size = UDim2.new(1, -SIDEBAR_WIDTH, 1, -TITLE_HEIGHT), Parent = window,
})

local Tabs = {}
local function selectTab(name)
    for tabName, tab in pairs(Tabs) do
        local sel = tabName == name
        tab.page.Visible = sel
        TweenService:Create(tab.button, TweenInfo.new(0.15), {
            BackgroundTransparency = sel and 0 or 1,
            TextColor3 = sel and Theme.Text or Theme.SubText,
            BackgroundColor3 = sel and Theme.Raised or Theme.Panel,
        }):Play()
    end
end
onThemeChange(function()
    for name, tab in pairs(Tabs) do
        if tab.page.Visible then
            tab.button.BackgroundTransparency = 0
            tab.button.TextColor3 = Theme.Text
            tab.button.BackgroundColor3 = Theme.Raised
        else
            tab.button.TextColor3 = Theme.SubText
        end
    end
end)

local function addTab(name, order)
    local button = create("TextButton", {
        Name = name, LayoutOrder = order, Size = UDim2.new(1, 0, 0, 32),
        BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false,
        Text = name, Font = Enum.Font.GothamMedium, TextSize = 13,
        Parent = tabList,
    }, { corner(8) })
    themed(button, "SubText")
    local page = create("ScrollingFrame", {
        Name = name .. "Page", Visible = false, BackgroundTransparency = 1, BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1), CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ScrollBarThickness = 3, ScrollBarImageColor3 = Color3.fromRGB(90, 90, 90),
        Parent = content,
    }, {
        create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
        create("UIPadding", {
            PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
            PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 12),
        }),
    })
    Tabs[name] = { page = page, button = button }
    button.MouseButton1Click:Connect(function() selectTab(name) end)
    return page
end

-- ============================================================
-- Tab: Farming
-- ============================================================

local farmPage = addTab("Farming", 1)

addSection(farmPage, "Auto Farm Items")
addToggle(farmPage, "Auto farm items", false, function(v)
    if v then startFarm() else stopFarm() end
end)
addSlider(farmPage, "Tween speed", 500, 3000, State.Farm.Speed, 50, " studs/s", function(v)
    State.Farm.Speed = v
end)
addDropdown(farmPage, "Target priority", { "Distance", "Value" }, State.Farm.Priority, function(v)
    State.Farm.Priority = v
end)
addMultiDropdown(farmPage, "Farm filter", FILTER_OPTIONS, State.Farm.Selected, function(m)
    State.Farm.Selected = m
end)
addButton(farmPage, "Teleport to Nearest", flyToNearest)
addToggle(farmPage, "Farm screen (hide world)", false, function(v)
    State.FarmScreen = v
end)

addSection(farmPage, "Auto Sell")
addToggle(farmPage, "Auto sell", false, function(v) State.Sell.Enabled = v end)
addToggle(farmPage, "Don't sell rare items", true, function(v) State.Sell.DontSellRare = v end)
addSlider(farmPage, "Sell interval", 0.5, 5, State.Sell.Interval, 0.5, " s", function(v)
    State.Sell.Interval = v
end)
addMultiDropdown(farmPage, "Sell filter", FILTER_OPTIONS, State.Sell.Selected, function(m)
    State.Sell.Selected = m
end)

addSection(farmPage, "Auto Buy Lucky Arrows")
addToggle(farmPage, "Auto buy Lucky Arrows", false, function(v) State.Buy.Enabled = v end)
addSlider(farmPage, "Buy interval", 1, 10, State.Buy.Interval, 0.5, " s", function(v)
    State.Buy.Interval = v
end)

-- ============================================================
-- Tab: Visuals
-- ============================================================

local visualsPage = addTab("Visuals", 2)

addSection(visualsPage, "Item ESP")
addToggle(visualsPage, "Show items", false, function(v)
    State.ItemESP.Enabled = v
    if v then task.spawn(safeCall, refreshItems) else clearItemESP() end
end)
addSlider(visualsPage, "Item range", 500, 5000, State.ItemESP.Range, 50, " studs", function(v)
    State.ItemESP.Range = v
end)
addColorPicker(visualsPage, "Item color", State.ItemESP.Color, function(c)
    State.ItemESP.Color = c
end)

addSection(visualsPage, "Player ESP")
addToggle(visualsPage, "Show players", false, function(v)
    State.PlayerESP.Enabled = v
    if not v then clearPlayerESP() end
end)
addSlider(visualsPage, "Player range", 500, 5000, State.PlayerESP.Range, 50, " studs", function(v)
    State.PlayerESP.Range = v
end)
addToggle(visualsPage, "Tracers", false, function(v)
    State.PlayerESP.Tracers = v
    if not v then clearTracers() end
end)
addColorPicker(visualsPage, "Players color", State.PlayerESP.Color, function(c)
    State.PlayerESP.Color = c
end)
addSection(visualsPage, "Player ESP fields")
addToggle(visualsPage, "Show name", true, function(v) State.PlayerESP.Fields.Name = v end)
addToggle(visualsPage, "Show distance", true, function(v) State.PlayerESP.Fields.Distance = v end)
addToggle(visualsPage, "Show health", true, function(v) State.PlayerESP.Fields.Health = v end)
addToggle(visualsPage, "Show stand", false, function(v) State.PlayerESP.Fields.Stand = v end)
addToggle(visualsPage, "Show spec", false, function(v) State.PlayerESP.Fields.Spec = v end)
addToggle(visualsPage, "Show level", false, function(v) State.PlayerESP.Fields.Level = v end)

addSection(visualsPage, "World")
addToggle(visualsPage, "Fullbright", false, function(v) State.World.Fullbright = v; applyWorld() end)
addToggle(visualsPage, "No fog", false, function(v) State.World.NoFog = v; applyWorld() end)
addSlider(visualsPage, "Time of day", 0, 24, State.World.TimeOfDay, 1, "h", function(v)
    State.World.TimeOfDay = v; applyWorld()
end)
addSlider(visualsPage, "FOV", 40, 120, State.World.FOV, 1, "", function(v)
    State.World.FOV = v; applyWorld()
end)

-- ============================================================
-- Tab: Player
-- ============================================================

local playerPage = addTab("Player", 3)

addSection(playerPage, "Movement")
addSlider(playerPage, "WalkSpeed", 8, 200, State.Player.WalkSpeed, 1, "", function(v)
    State.Player.WalkSpeed = v
    updateWalkspeed()
end)
addToggle(playerPage, "Fly", false, function(v)
    State.Player.Fly = v
    if v then startFly() else stopFly() end
end)
addSlider(playerPage, "Fly speed", 10, 500, State.Player.FlySpeed, 5, "", function(v)
    State.Player.FlySpeed = v
end)
addToggle(playerPage, "Noclip", false, function(v) State.Player.Noclip = v end)
addToggle(playerPage, "Anti AFK", false, function(v) State.Player.AntiAFK = v end)

addSection(playerPage, "Teleports")
local npcNames = {}
local playerNames = {}
local placeNames = { "Spawn", "SpawnLocation", "Shop", "Yba Shop", "Mysterious Merchant", "Arrow Shop" }

local function scanTargets()
    table.clear(npcNames)
    for _, desc in ipairs(Workspace:GetDescendants()) do
        if desc:IsA("Humanoid") then
            local model = desc:FindFirstAncestorOfClass("Model")
            if model and not Players:GetPlayerFromCharacter(model) then
                table.insert(npcNames, model.Name)
            end
        end
    end
    table.sort(npcNames)
    table.clear(playerNames)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then table.insert(playerNames, p.DisplayName) end
    end
    table.sort(playerNames)
end

local function teleportToPosition(pos)
    local root = getRoot()
    if not root then return end
    acquireStabilizer()
    local from = root.Position
    local dist = (pos - from).Magnitude
    local duration = math.max(dist / 1000, 0.05)
    local tw = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
        CFrame = CFrame.new(pos) * root.CFrame.Rotation,
    })
    tw:Play()
    tw.Completed:Wait()
    releaseStabilizer()
end

local selectedNpc, selectedPlayer, selectedPlace = "", "", ""

addButton(playerPage, "Refresh teleport lists", scanTargets)
addDropdown(playerPage, "NPC", { "(none)" }, "(none)", function(v) selectedNpc = v end)
addButton(playerPage, "Teleport to NPC", function()
    for _, desc in ipairs(Workspace:GetDescendants()) do
        if desc:IsA("Humanoid") then
            local model = desc:FindFirstAncestorOfClass("Model")
            if model and model.Name == selectedNpc and not Players:GetPlayerFromCharacter(model) then
                local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart", true)
                if root then teleportToPosition(root.Position + Vector3.new(3, 0, 0)) end
                return
            end
        end
    end
end)

addDropdown(playerPage, "Player", { "(none)" }, "(none)", function(v) selectedPlayer = v end)
addButton(playerPage, "Teleport to Player", function()
    for _, p in ipairs(Players:GetPlayers()) do
        if p.DisplayName == selectedPlayer and p.Character then
            local r = p.Character:FindFirstChild("HumanoidRootPart")
            if r then teleportToPosition(r.Position + Vector3.new(3, 0, 0)) end
            return
        end
    end
end)

addDropdown(playerPage, "Place", placeNames, placeNames[1], function(v) selectedPlace = v end)
addButton(playerPage, "Teleport to Place", function()
    for _, desc in ipairs(Workspace:GetDescendants()) do
        if desc:IsA("BasePart") and desc.Name == selectedPlace then
            teleportToPosition(desc.Position + Vector3.new(0, 5, 0))
            return
        end
        if desc:IsA("Model") and desc.Name == selectedPlace then
            local root = desc:FindFirstChild("HumanoidRootPart") or desc:FindFirstChildWhichIsA("BasePart", true)
            if root then teleportToPosition(root.Position + Vector3.new(3, 0, 0)) end
            return
        end
    end
end)

-- ============================================================
-- Tab: Settings
-- ============================================================

local settingsPage = addTab("Settings", 4)

addSection(settingsPage, "Appearance")
addDropdown(settingsPage, "Script theme", { "Dark", "Light" }, CurrentThemeName, function(v)
    applyTheme(v)
end)
addSlider(settingsPage, "Mini icon size", 40, 96, State.Settings.IconSize, 2, " px", function(v)
    State.Settings.IconSize = v
    if iconScale then iconScale.Scale = v / BASE_ICON_SIZE end
end)

addSection(settingsPage, "Diagnostics")
addToggle(settingsPage, "Show FPS", false, function(v)
    State.Settings.ShowFPS = v
    fpsLabel.Text = ""
end)

addSection(settingsPage, "Session")
addToggle(settingsPage, "Auto press Play after rejoin", false, function(v)
    State.Settings.AutoPlay = v
end)

-- ============================================================
-- Minimize / restore / zoom / mini icon
-- ============================================================

local minimized, animating, maximized = false, false, false

local icon = create("Frame", {
    Name = "MinimizedIcon", Active = true, Visible = false,
    BorderSizePixel = 0, Position = UDim2.fromOffset(20, 20),
    Size = UDim2.fromOffset(BASE_ICON_SIZE, BASE_ICON_SIZE), Parent = screenGui,
}, { corner(14), stroke(Color3.fromRGB(64, 64, 64), 1.5) })
themed(icon, "Background")

local iconScale = create("UIScale", { Scale = 1, Parent = icon })
iconScale.Scale = State.Settings.IconSize / BASE_ICON_SIZE

-- Crescent moon
create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, -3, 0.5, 0),
    Size = UDim2.fromOffset(30, 30), BackgroundColor3 = Color3.fromRGB(250, 232, 170),
    BorderSizePixel = 0, ZIndex = 1, Parent = icon,
}, { pill() })
local cutout = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 6, 0.5, -5),
    Size = UDim2.fromOffset(26, 26), BorderSizePixel = 0, ZIndex = 2, Parent = icon,
}, { pill() })
themed(cutout, "Background")

local function minimizeWindow()
    if animating or minimized then return end
    animating = true
    local wp = window.AbsolutePosition
    local scale = State.Settings.IconSize / BASE_ICON_SIZE
    local ix, iy = clampPosition(wp.X + 6, wp.Y + 6, State.Settings.IconSize, State.Settings.IconSize)
    local collapse = TweenService:Create(window, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut), {
        Size = UDim2.fromOffset(State.Settings.IconSize, State.Settings.IconSize),
        Position = UDim2.fromOffset(ix, iy),
        GroupTransparency = 1,
    })
    collapse:Play()
    collapse.Completed:Wait()
    window.Visible = false
    icon.Position = UDim2.fromOffset(ix, iy)
    iconScale.Scale = 0.6 * scale
    icon.Visible = true
    TweenService:Create(iconScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Scale = scale,
    }):Play()
    minimized = true
    animating = false
end

local function restoreWindow()
    if animating or not minimized then return end
    animating = true
    local ix = icon.Position.X.Offset
    local iy = icon.Position.Y.Offset
    local x, y = clampPosition(ix, iy, winW, winH)
    icon.Visible = false
    window.Size = UDim2.fromOffset(State.Settings.IconSize, State.Settings.IconSize)
    window.Position = UDim2.fromOffset(ix, iy)
    window.GroupTransparency = 1
    window.Visible = true
    local expand = TweenService:Create(window, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
        Size = UDim2.fromOffset(winW, winH),
        Position = UDim2.fromOffset(x, y),
        GroupTransparency = 0,
    })
    expand:Play()
    expand.Completed:Wait()
    minimized = false
    animating = false
end

local function toggleZoom()
    if animating or minimized then return end
    maximized = not maximized
    local s = getScreenSize()
    local pos = window.AbsolutePosition
    local x, y
    if maximized then
        winW, winH = math.max(s.X - 40, normalW), math.max(s.Y - 40, normalH)
        x, y = (s.X - winW) / 2, (s.Y - winH) / 2
    else
        winW, winH = normalW, normalH
        x, y = clampPosition(pos.X, pos.Y, winW, winH)
    end
    TweenService:Create(window, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.fromOffset(winW, winH),
        Position = UDim2.fromOffset(x, y),
    }):Play()
end

makeDraggable(titleBar, window)
makeDraggable(sidebar, window)
makeDraggable(icon, icon, restoreWindow)

minimizeLight.MouseButton1Click:Connect(minimizeWindow)
zoomLight.MouseButton1Click:Connect(toggleZoom)

track(UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        if minimized then task.spawn(restoreWindow) else task.spawn(minimizeWindow) end
    end
end))

-- ============================================================
-- Farm screen (fullscreen overlay with stats)
-- ============================================================

local farmOverlay = create("Frame", {
    Name = "FarmScreen", Visible = false, BorderSizePixel = 0,
    Size = UDim2.fromScale(1, 1), ZIndex = 9999, Parent = screenGui,
})
themed(farmOverlay, "Background")
local farmTitle = themed(newLabel({
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.35),
    Size = UDim2.fromOffset(400, 40), Text = "FARMING", Font = Enum.Font.GothamBold,
    TextSize = 32, TextXAlignment = Enum.TextXAlignment.Center, Parent = farmOverlay,
}), "Text")
local farmStatsLabel = themed(newLabel({
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(500, 200), Text = "", Font = Enum.Font.GothamMedium,
    TextSize = 18, TextXAlignment = Enum.TextXAlignment.Center, Parent = farmOverlay,
}), "SubText")
farmStatsLabel.TextWrapped = true

task.spawn(function()
    while alive do
        local show = State.FarmScreen and State.Farm.Enabled
        farmOverlay.Visible = show
        if show then
            local elapsed = os.clock() - farmStats.startedAt
            local mins = math.floor(elapsed / 60)
            local secs = math.floor(elapsed % 60)
            farmStatsLabel.Text = string.format(
                "Picked: %d\nFailed: %d\nTime: %02d:%02d\nSpeed: %d studs/s\nPriority: %s",
                farmStats.picked, farmStats.failed, mins, secs, State.Farm.Speed, State.Farm.Priority
            )
        end
        task.wait(0.5)
    end
end)

-- ============================================================
-- FPS counter
-- ============================================================

local fpsFrames, fpsTime = 0, 0
track(RunService.RenderStepped:Connect(function(dt)
    if not State.Settings.ShowFPS then
        if fpsLabel.Text ~= "" then fpsLabel.Text = "" end
        return
    end
    fpsFrames += 1
    fpsTime += dt
    if fpsTime >= 0.5 then
        fpsLabel.Text = math.floor(fpsFrames / fpsTime) .. " FPS"
        fpsFrames, fpsTime = 0, 0
    end
end))

-- ============================================================
-- Init
-- ============================================================

selectTab("Farming")
scanTargets()
applyWorld()

-- ============================================================
-- Cleanup
-- ============================================================

local function destroyHub()
    if not alive then return end
    alive = false
    State.Farm.Enabled = false
    State.ItemESP.Enabled = false
    State.PlayerESP.Enabled = false
    State.Sell.Enabled = false
    State.Buy.Enabled = false
    farmToken += 1
    flightId += 1
    if activeTween then pcall(function() activeTween:Cancel() end); activeTween = nil end
    if stabilizerConn then stabilizerConn:Disconnect(); stabilizerConn = nil end
    stopFly()
    clearItemESP()
    clearPlayerESP()
    for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
    table.clear(Connections)
    pcall(function() screenGui:Destroy() end)
    pcall(function() tracerGui:Destroy() end)
    pcall(function() espFolder:Destroy() end)
    if env.MoonlightHub and env.MoonlightHub.Destroy == destroyHub then
        env.MoonlightHub = nil
    end
end

closeLight.MouseButton1Click:Connect(function()
    TweenService:Create(window, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { GroupTransparency = 1 }):Play()
    task.delay(0.2, destroyHub)
end)

env.MoonlightHub = { Destroy = destroyHub }