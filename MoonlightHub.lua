--[[
    MoonlightHub | Your Bizarre Adventure
    Tabs: Farming, Visuals, Player, Settings
    RightShift: minimize / restore
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local env = (type(getgenv) == "function" and getgenv()) or _G
if type(env.MoonlightHub) == "table" and type(env.MoonlightHub.Destroy) == "function" then
    pcall(env.MoonlightHub.Destroy)
end

local LocalPlayer = Players.LocalPlayer

--------------------------------------------------------------------------------
-- Settings (saved to a file when the executor supports it)
--------------------------------------------------------------------------------

local HUB_NAME = "MoonlightHub"
local SETTINGS_FILE = "MoonlightHub_Settings.json"
local ITEMS_PATH = { "Item_Spawns", "Items" }
local TITLE_HEIGHT = 38
local SIDEBAR_WIDTH = 120
local PICKUP_HOVER_OFFSET = Vector3.new(0, 3, 0)
local WHITE = Color3.fromRGB(255, 255, 255)

local Settings = { Theme = "Dark", IconSize = 56, ShowFps = false, Places = {} }

local function loadSettings()
    if type(isfile) ~= "function" or type(readfile) ~= "function" then
        return
    end
    pcall(function()
        if not isfile(SETTINGS_FILE) then
            return
        end
        local data = HttpService:JSONDecode(readfile(SETTINGS_FILE))
        if type(data) ~= "table" then
            return
        end
        if data.Theme == "Dark" or data.Theme == "Light" then
            Settings.Theme = data.Theme
        end
        if type(data.IconSize) == "number" then
            Settings.IconSize = math.clamp(data.IconSize, 40, 96)
        end
        if type(data.ShowFps) == "boolean" then
            Settings.ShowFps = data.ShowFps
        end
        if type(data.Places) == "table" then
            for _, place in ipairs(data.Places) do
                if type(place) == "table" and type(place.name) == "string" and type(place.x) == "number"
                    and type(place.y) == "number" and type(place.z) == "number" then
                    table.insert(Settings.Places, place)
                end
            end
        end
    end)
end
loadSettings()

local saveQueued = false
local function saveSettings()
    if saveQueued then
        return
    end
    saveQueued = true
    task.delay(1, function()
        saveQueued = false
        if type(writefile) ~= "function" then
            return
        end
        pcall(function()
            writefile(SETTINGS_FILE, HttpService:JSONEncode(Settings))
        end)
    end)
end

--------------------------------------------------------------------------------
-- Themes: Dark = anthracite + dark purple, Light = milk white + dark purple
--------------------------------------------------------------------------------

local PALETTES = {
    Dark = {
        Background = Color3.fromRGB(34, 36, 40),
        Panel = Color3.fromRGB(46, 48, 54),
        Raised = Color3.fromRGB(60, 62, 70),
        Border = Color3.fromRGB(22, 23, 26),
        Text = Color3.fromRGB(236, 234, 242),
        SubText = Color3.fromRGB(150, 148, 164),
        Accent = Color3.fromRGB(104, 52, 168),
        AccentPressed = Color3.fromRGB(78, 36, 128),
        OnAccent = Color3.fromRGB(255, 255, 255),
        Off = Color3.fromRGB(78, 78, 88),
        TabSelected = Color3.fromRGB(64, 50, 90),
        ScrollBar = Color3.fromRGB(100, 100, 112),
        Moon = Color3.fromRGB(232, 222, 250),
        IconStroke = Color3.fromRGB(104, 52, 168),
    },
    Light = {
        Background = Color3.fromRGB(248, 245, 238),
        Panel = Color3.fromRGB(237, 232, 224),
        Raised = Color3.fromRGB(226, 220, 211),
        Border = Color3.fromRGB(203, 196, 186),
        Text = Color3.fromRGB(38, 26, 58),
        SubText = Color3.fromRGB(118, 104, 136),
        Accent = Color3.fromRGB(88, 40, 142),
        AccentPressed = Color3.fromRGB(66, 28, 110),
        OnAccent = Color3.fromRGB(255, 255, 255),
        Off = Color3.fromRGB(198, 190, 180),
        TabSelected = Color3.fromRGB(224, 214, 236),
        ScrollBar = Color3.fromRGB(160, 150, 172),
        Moon = Color3.fromRGB(88, 40, 142),
        IconStroke = Color3.fromRGB(88, 40, 142),
    },
}

local Theme = PALETTES[Settings.Theme] or PALETTES.Dark
local ThemeBinds = setmetatable({}, { __mode = "k" })
local ThemeCallbacks = {}

local function T(key)
    return { __theme = key }
end

--------------------------------------------------------------------------------
-- Catalog and state
--------------------------------------------------------------------------------

-- Value scale is a relative ranking for the "Value" priority, not game data.
local ITEM_CATALOG = {
    { key = "lucky arrow", label = "Lucky Arrow", value = 100 },
    { key = "lucky stone mask", label = "Lucky Stone Mask", value = 95 },
    { key = "pure rokakaka", label = "Pure Rokakaka", value = 85 },
    { key = "mysterious arrow", label = "Mysterious Arrow", value = 75 },
    { key = "rib cage", label = "Rib Cage", value = 70 },
    { key = "steel ball", label = "Steel Ball", value = 60 },
    { key = "stone mask", label = "Stone Mask", value = 55 },
    { key = "zeppeli", label = "Zeppeli's Hat", value = 45 },
    { key = "quinton", label = "Quinton's Glove", value = 45 },
    { key = "rokakaka", label = "Rokakaka", value = 40 },
    { key = "diary", label = "Diary", value = 35 },
    { key = "arrow", label = "Arrow", value = 30 },
    { key = "gold coin", label = "Gold Coin", value = 20 },
}
local RARE_ITEMS = { ["Lucky Arrow"] = true, ["Lucky Stone Mask"] = true }
local STAT_NAMES = {
    Stand = { "Stand" },
    Spec = { "Spec", "Specialization" },
    Level = { "Level", "Lvl" },
    Money = { "Money", "Cash" },
}

local CATALOG_BY_LENGTH = {}
local ITEM_LABELS = {}
for _, entry in ipairs(ITEM_CATALOG) do
    table.insert(CATALOG_BY_LENGTH, entry)
    table.insert(ITEM_LABELS, entry.label)
end
table.sort(CATALOG_BY_LENGTH, function(a, b)
    return #a.key > #b.key
end)
local FILTER_OPTIONS = table.clone(ITEM_LABELS)
table.insert(FILTER_OPTIONS, "Other")

local State = {
    ItemESP = { Enabled = false, Range = 1500, Color = Color3.fromRGB(255, 214, 10) },
    PlayerESP = {
        Enabled = false,
        Range = 2000,
        Tracers = false,
        Color = Color3.fromRGB(255, 69, 58),
        Fields = { Name = true, Distance = true, Health = true, Stand = true, Spec = true, Level = true },
    },
    Farm = { Enabled = false, Speed = 800, Priority = "Distance", Selected = {} },
    Sell = { Enabled = false, Interval = 15, ProtectRare = true, Selected = {} },
    Buy = { Enabled = false, Target = 5, Price = 75000 },
    Utils = { AntiAfk = true, AutoPlay = true, FarmScreen = false },
    Walk = { Enabled = false, Speed = 32 },
    Fly = { Enabled = false, Speed = 60 },
    Teleport = { Speed = 1500 },
    World = { Fullbright = false, NoFog = false, Time = false, TimeValue = 14, Fov = false, FovValue = 90 },
}
for _, option in ipairs(FILTER_OPTIONS) do
    State.Farm.Selected[option] = true
end
for _, option in ipairs(ITEM_LABELS) do
    State.Sell.Selected[option] = true
end

local Stats = { Picked = 0, Sold = 0, Bought = 0, StartedAt = os.clock() }

--------------------------------------------------------------------------------
-- Utilities
--------------------------------------------------------------------------------

local alive = true
local Connections = {}

local function track(connection)
    table.insert(Connections, connection)
    return connection
end

local function safeCall(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
        warn("[" .. HUB_NAME .. "] " .. tostring(err))
    end
    return ok
end

local function applyTheme(name)
    Theme = PALETTES[name] or PALETTES.Dark
    for inst, props in pairs(ThemeBinds) do
        for prop, key in pairs(props) do
            pcall(function()
                inst[prop] = Theme[key]
            end)
        end
    end
    for _, callback in ipairs(ThemeCallbacks) do
        safeCall(callback)
    end
end

local function create(className, props, children)
    local inst = Instance.new(className)
    local parent = nil
    if props then
        for key, value in pairs(props) do
            if key == "Parent" then
                parent = value
            elseif type(value) == "table" and value.__theme then
                ThemeBinds[inst] = ThemeBinds[inst] or {}
                ThemeBinds[inst][key] = value.__theme
                inst[key] = Theme[value.__theme]
            else
                inst[key] = value
            end
        end
    end
    if children then
        for _, child in ipairs(children) do
            child.Parent = inst
        end
    end
    if parent then
        inst.Parent = parent
    end
    return inst
end

local function corner(radius)
    return create("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function pill()
    return create("UICorner", { CornerRadius = UDim.new(1, 0) })
end

local function stroke(color, thickness)
    return create("UIStroke", {
        Color = color,
        Thickness = thickness,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })
end

local function newLabel(props)
    props.BackgroundTransparency = 1
    props.BorderSizePixel = 0
    props.Font = props.Font or Enum.Font.GothamMedium
    props.TextColor3 = props.TextColor3 or T("Text")
    props.TextSize = props.TextSize or 13
    props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
    return create("TextLabel", props)
end

local function getRoot()
    local char = LocalPlayer.Character
    if not char then
        return nil
    end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        return nil
    end
    return char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function getScreenSize()
    local camera = Workspace.CurrentCamera
    if camera and camera.ViewportSize.X > 0 then
        return camera.ViewportSize
    end
    return Vector2.new(800, 450)
end

local function clampPosition(x, y, width, height)
    local screen = getScreenSize()
    return math.clamp(x, 0, math.max(screen.X - width, 0)), math.clamp(y, 0, math.max(screen.Y - height, 0))
end

local function formatNumber(value)
    local number = tonumber(value)
    if not number then
        return tostring(value)
    end
    local digits = tostring(math.floor(number))
    local formatted = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (formatted:gsub("^,", ""))
end

local function getItemInfo(name)
    if type(name) ~= "string" or name == "" then
        return nil
    end
    local lowered = string.lower(name)
    for _, entry in ipairs(CATALOG_BY_LENGTH) do
        if string.find(lowered, entry.key, 1, true) then
            return entry
        end
    end
    return nil
end

local function readStat(player, names)
    local containers = {}
    for _, containerName in ipairs({ "PlayerStats", "leaderstats", "Stats", "Data" }) do
        local container = player:FindFirstChild(containerName)
        if container then
            table.insert(containers, container)
        end
    end
    for _, name in ipairs(names) do
        for _, container in ipairs(containers) do
            local object = container:FindFirstChild(name)
            if object and object:IsA("ValueBase") then
                return object.Value
            end
        end
        local direct = player:FindFirstChild(name)
        if direct and direct:IsA("ValueBase") then
            return direct.Value
        end
        local attribute = player:GetAttribute(name)
        if attribute ~= nil then
            return attribute
        end
    end
    return nil
end

--------------------------------------------------------------------------------
-- UI containers
--------------------------------------------------------------------------------

local function mount(instance)
    local candidates = {}
    if type(gethui) == "function" then
        table.insert(candidates, function()
            return gethui()
        end)
    end
    table.insert(candidates, function()
        return CoreGui
    end)
    table.insert(candidates, function()
        return LocalPlayer:WaitForChild("PlayerGui")
    end)
    for _, getParent in ipairs(candidates) do
        local ok, parent = pcall(getParent)
        if ok and parent then
            local parented = pcall(function()
                instance.Parent = parent
            end)
            if parented and instance.Parent == parent then
                return true
            end
        end
    end
    return false
end

local function newScreenGui(name, order, enabled)
    return create("ScreenGui", {
        Name = name,
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = order,
        Enabled = enabled,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
end

local screenGui = newScreenGui(HUB_NAME, 50, true)
local farmGui = newScreenGui(HUB_NAME .. "_FarmScreen", 40, false)
local tracerGui = newScreenGui(HUB_NAME .. "_Tracers", 10, true)
local espFolder = create("Folder", { Name = HUB_NAME .. "_ESP" })

if not (mount(screenGui) and mount(farmGui) and mount(tracerGui) and mount(espFolder)) then
    error("[" .. HUB_NAME .. "] no writable UI container found")
end

local function isOwnGui(instance)
    return instance:IsDescendantOf(screenGui) or instance:IsDescendantOf(farmGui) or instance:IsDescendantOf(tracerGui)
end

--------------------------------------------------------------------------------
-- Tracers
--------------------------------------------------------------------------------

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
                line.From = from
                line.To = to
                line.Color = color
                line.Visible = true
            end,
            hide = function()
                line.Visible = false
            end,
            destroy = function()
                pcall(function()
                    line:Remove()
                end)
            end,
        }
    end

    local frame = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BorderSizePixel = 0,
        Visible = false,
        Parent = tracerGui,
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
        hide = function()
            frame.Visible = false
        end,
        destroy = function()
            frame:Destroy()
        end,
    }
end

--------------------------------------------------------------------------------
-- Item registry and Items ESP
--------------------------------------------------------------------------------

local Items = {}

local function getItemPart(inst)
    if inst:IsA("BasePart") then
        return inst
    end
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
    for _, candidate in ipairs(candidates) do
        local info = getItemInfo(candidate)
        if info then
            return info.label, info
        end
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
    if rec.highlight then
        rec.highlight:Destroy()
        rec.highlight = nil
    end
    if rec.gui then
        rec.gui:Destroy()
        rec.gui = nil
    end
    rec.tag = nil
end

local function clearItemESP()
    for _, rec in pairs(Items) do
        destroyItemVisual(rec)
    end
end

local function removeItem(inst)
    local rec = Items[inst]
    if rec then
        destroyItemVisual(rec)
        Items[inst] = nil
    end
end

local function addItem(inst)
    local part = getItemPart(inst)
    if not part then
        return
    end
    local prompt = inst:FindFirstChildWhichIsA("ProximityPrompt", true)
    local label, info = resolveItem(inst, prompt)
    Items[inst] = {
        inst = inst,
        part = part,
        prompt = prompt,
        label = label,
        value = info and info.value or 0,
        known = info ~= nil,
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
            if child:IsA("Model") or child:IsA("BasePart") then
                found[child] = true
            end
        end
        return found
    end
    -- Fallback: the items folder was not found, scan prompts of known item names.
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
        if not Items[inst] then
            addItem(inst)
        end
    end
    for inst in pairs(Items) do
        if not found[inst] or not inst.Parent then
            removeItem(inst)
        end
    end
end

local function ensureItemVisual(rec)
    if rec.gui and rec.gui.Parent and rec.highlight and rec.highlight.Parent then
        return
    end
    destroyItemVisual(rec)
    rec.highlight = create("Highlight", {
        Name = "ItemHighlight",
        Adornee = rec.inst,
        FillTransparency = 0.65,
        OutlineTransparency = 0,
        DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
        Parent = espFolder,
    })
    rec.gui = create("BillboardGui", {
        Name = "ItemTag",
        Adornee = rec.part,
        AlwaysOnTop = true,
        Size = UDim2.fromOffset(170, 36),
        StudsOffset = Vector3.new(0, 2.5, 0),
        Parent = espFolder,
    })
    rec.tag = newLabel({
        Size = UDim2.fromScale(1, 1),
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextStrokeTransparency = 0.4,
        Parent = rec.gui,
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

--------------------------------------------------------------------------------
-- Players ESP (configurable fields)
--------------------------------------------------------------------------------

local PlayerRecords = {}

local function removePlayerRecord(player)
    local rec = PlayerRecords[player]
    if not rec then
        return
    end
    if rec.highlight then
        rec.highlight:Destroy()
    end
    if rec.gui then
        rec.gui:Destroy()
    end
    if rec.tracer then
        rec.tracer.destroy()
    end
    PlayerRecords[player] = nil
end

local function clearPlayerESP()
    for player in pairs(PlayerRecords) do
        removePlayerRecord(player)
    end
end

local function clearTracers()
    for _, rec in pairs(PlayerRecords) do
        if rec.tracer then
            rec.tracer.destroy()
            rec.tracer = nil
        end
    end
end

local function statText(prefix, value)
    if value == nil or value == "" then
        return prefix .. "?"
    end
    return prefix .. tostring(value)
end

local function buildPlayerText(player, humanoid, dist)
    local fields = State.PlayerESP.Fields
    local first, second, third = {}, {}, {}
    if fields.Name then
        table.insert(first, player.DisplayName)
    end
    if fields.Level then
        table.insert(first, statText("Lv ", readStat(player, STAT_NAMES.Level)))
    end
    if fields.Stand then
        table.insert(second, statText("Stand: ", readStat(player, STAT_NAMES.Stand)))
    end
    if fields.Spec then
        table.insert(second, statText("Spec: ", readStat(player, STAT_NAMES.Spec)))
    end
    if fields.Health then
        table.insert(third, string.format("HP %d/%d", math.floor(humanoid.Health), math.floor(humanoid.MaxHealth)))
    end
    if fields.Distance then
        table.insert(third, string.format("%d studs", math.floor(dist)))
    end
    local lines = {}
    if #first > 0 then
        table.insert(lines, table.concat(first, "  "))
    end
    if #second > 0 then
        table.insert(lines, table.concat(second, " | "))
    end
    if #third > 0 then
        table.insert(lines, table.concat(third, " | "))
    end
    return table.concat(lines, "\n"), #lines
end

local function ensurePlayerVisual(rec, char)
    if rec.char == char and rec.highlight and rec.highlight.Parent and rec.gui and rec.gui.Parent then
        return
    end
    if rec.highlight then
        rec.highlight:Destroy()
    end
    if rec.gui then
        rec.gui:Destroy()
    end
    rec.char = char
    rec.highlight = create("Highlight", {
        Name = "PlayerHighlight",
        Adornee = char,
        FillTransparency = 0.7,
        OutlineTransparency = 0,
        DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
        Parent = espFolder,
    })
    rec.gui = create("BillboardGui", {
        Name = "PlayerTag",
        Adornee = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"),
        AlwaysOnTop = true,
        Size = UDim2.fromOffset(220, 50),
        StudsOffset = Vector3.new(0, 3, 0),
        Parent = espFolder,
    })
    rec.label = newLabel({
        Size = UDim2.fromScale(1, 1),
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextStrokeTransparency = 0.4,
        Parent = rec.gui,
    })
end

local function updatePlayerESP(originPos, camera, slow)
    local range = State.PlayerESP.Range
    local color = State.PlayerESP.Color
    local viewport = camera.ViewportSize
    local screenCenter = Vector2.new(viewport.X / 2, viewport.Y / 2)

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            local targetRoot = char and char:FindFirstChild("HumanoidRootPart")
            local humanoid = char and char:FindFirstChildOfClass("Humanoid")
            local dist = 0
            local inRange = false
            if targetRoot and humanoid and humanoid.Health > 0 then
                dist = (targetRoot.Position - originPos).Magnitude
                inRange = dist <= range
            end

            if inRange then
                local rec = PlayerRecords[player]
                if not rec then
                    rec = {}
                    PlayerRecords[player] = rec
                end
                if slow or not rec.highlight then
                    ensurePlayerVisual(rec, char)
                    rec.highlight.FillColor = color
                    rec.highlight.OutlineColor = color
                    local text, lineCount = buildPlayerText(player, humanoid, dist)
                    rec.label.TextColor3 = color
                    rec.label.Text = text
                    rec.gui.Size = UDim2.fromOffset(220, math.max(lineCount, 1) * 15 + 4)
                end
                if State.PlayerESP.Tracers then
                    local point, onScreen = camera:WorldToViewportPoint(targetRoot.Position)
                    if onScreen then
                        if not rec.tracer then
                            rec.tracer = createTracer()
                        end
                        rec.tracer.update(screenCenter, Vector2.new(point.X, point.Y), color)
                    elseif rec.tracer then
                        rec.tracer.hide()
                    end
                elseif rec.tracer then
                    rec.tracer.destroy()
                    rec.tracer = nil
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
    local itemOn = State.ItemESP.Enabled
    local playerOn = State.PlayerESP.Enabled
    if not (itemOn or playerOn) then
        return
    end
    local camera = Workspace.CurrentCamera
    if not camera then
        return
    end
    local root = getRoot()
    local originPos = root and root.Position or camera.CFrame.Position
    espClock += dt
    local slow = espClock >= 0.1
    if slow then
        espClock = 0
    end
    if itemOn and slow then
        safeCall(updateItemESP, originPos)
    end
    if playerOn then
        safeCall(updatePlayerESP, originPos, camera, slow)
    end
end))

task.spawn(function()
    while alive do
        if State.ItemESP.Enabled or State.Farm.Enabled then
            local ok, err = pcall(refreshItems)
            if not ok then
                warn("[" .. HUB_NAME .. "] items scan: " .. tostring(err))
            end
        end
        task.wait(1)
    end
end)

--------------------------------------------------------------------------------
-- Noclip and hover (refcounted)
--------------------------------------------------------------------------------

local noclipUsers = 0
local noclipConn = nil
local noclipChar = nil
local noclipParts = {}
local noclipChanged = {}

local function acquireNoclip()
    noclipUsers += 1
    if noclipConn then
        return
    end
    noclipConn = RunService.Stepped:Connect(function()
        local char = LocalPlayer.Character
        if not char then
            return
        end
        if char ~= noclipChar then
            noclipChar = char
            noclipParts = {}
            noclipChanged = {}
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    table.insert(noclipParts, part)
                end
            end
        end
        for _, part in ipairs(noclipParts) do
            if part.Parent and part.CanCollide then
                noclipChanged[part] = true
                part.CanCollide = false
            end
        end
    end)
end

local function releaseNoclip()
    noclipUsers = math.max(noclipUsers - 1, 0)
    if noclipUsers == 0 and noclipConn then
        noclipConn:Disconnect()
        noclipConn = nil
        for part in pairs(noclipChanged) do
            if part.Parent then
                part.CanCollide = true
            end
        end
        noclipChanged = {}
        noclipParts = {}
        noclipChar = nil
    end
end

local hoverUsers = 0
local hoverConn = nil

local function acquireHover()
    hoverUsers += 1
    acquireNoclip()
    if hoverConn then
        return
    end
    hoverConn = RunService.Stepped:Connect(function(_, dt)
        local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if root then
            root.AssemblyLinearVelocity = Vector3.new(0, 0.5 * Workspace.Gravity * dt, 0)
            root.AssemblyAngularVelocity = Vector3.zero
        end
    end)
end

local function releaseHover()
    hoverUsers = math.max(hoverUsers - 1, 0)
    releaseNoclip()
    if hoverUsers == 0 and hoverConn then
        hoverConn:Disconnect()
        hoverConn = nil
    end
end

--------------------------------------------------------------------------------
-- Flight (TweenService only), item farm, teleports
--------------------------------------------------------------------------------

local statusLabel = nil
local tpStatusLabel = nil
local activeTween = nil
local flightId = 0
local farmToken = 0
local flightBusy = false

local function setStatus(text)
    if statusLabel then
        statusLabel.Text = "Status: " .. text
    end
end

local function setTpStatus(text)
    if tpStatusLabel then
        tpStatusLabel.Text = "Status: " .. text
    end
end

local fireProximity = nil
if type(fireproximityprompt) == "function" then
    fireProximity = fireproximityprompt
end

local function pickTarget(originPos, failures, priority)
    local best = nil
    local bestDist = math.huge
    local bestValue = -1
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
                    best = rec
                    bestDist = dist
                    bestValue = rec.value
                end
            end
        end
    end
    return best, bestDist
end

-- Movement is strictly TweenService, duration = distance / speed.
local function flyTo(position, rec, speed)
    local root = getRoot()
    if not root then
        return "nochar"
    end
    flightId += 1
    local myId = flightId
    local distance = (root.Position - position).Magnitude
    local duration = math.max(distance / (speed or State.Farm.Speed), 0.05)
    local goal = CFrame.new(position) * root.CFrame.Rotation
    local tween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), { CFrame = goal })
    activeTween = tween
    tween:Play()

    local startedAt = os.clock()
    local result = "arrived"
    while tween.PlaybackState ~= Enum.PlaybackState.Completed and tween.PlaybackState ~= Enum.PlaybackState.Cancelled do
        if myId ~= flightId then
            result = "cancelled"
            break
        end
        if rec and not itemAlive(rec) then
            result = "gone"
            break
        end
        if not getRoot() then
            result = "nochar"
            break
        end
        if os.clock() - startedAt > duration + 2 then
            result = "timeout"
            break
        end
        RunService.Heartbeat:Wait()
    end
    if result == "arrived" and tween.PlaybackState ~= Enum.PlaybackState.Completed then
        result = "cancelled"
    end
    if tween.PlaybackState ~= Enum.PlaybackState.Completed then
        tween:Cancel()
    end
    if activeTween == tween then
        activeTween = nil
    end
    return result
end

local function pickUp(rec)
    local prompt = rec.prompt
    if prompt and prompt.Parent and fireProximity then
        pcall(fireProximity, prompt)
        return
    end
    local keyCode = Enum.KeyCode.E
    local hold = 0.3
    if prompt and prompt.Parent then
        if prompt.KeyboardKeyCode ~= Enum.KeyCode.Unknown then
            keyCode = prompt.KeyboardKeyCode
        end
        hold = math.max(prompt.HoldDuration, 0) + 0.15
    end
    VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
    task.wait(hold)
    VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
end

local function farmStep(failures)
    local root = getRoot()
    if not root then
        setStatus("waiting for character")
        task.wait(0.5)
        return
    end
    refreshItems()
    local target, dist = pickTarget(root.Position, failures, State.Farm.Priority)
    if not target then
        setStatus("no items match the filter")
        task.wait(0.5)
        return
    end
    setStatus(string.format("flying to %s (%d studs)", target.label, math.floor(dist)))
    local result = flyTo(target.part.Position + PICKUP_HOVER_OFFSET, target, State.Farm.Speed)
    if result == "gone" then
        setStatus("item disappeared, retargeting")
        return
    end
    if result ~= "arrived" or not itemAlive(target) then
        return
    end
    setStatus("picking up " .. target.label)
    pickUp(target)
    task.wait(0.6)
    if itemAlive(target) then
        local failure = failures[target.inst]
        if not failure then
            failure = { count = 0, untilTime = 0 }
            failures[target.inst] = failure
        end
        failure.count += 1
        if failure.count >= 3 then
            failure.count = 0
            failure.untilTime = os.clock() + 30
        end
    else
        Stats.Picked += 1
        failures[target.inst] = nil
    end
end

local function farmLoop(token)
    acquireHover()
    local failures = {}
    while alive and farmToken == token and State.Farm.Enabled do
        local ok, err = pcall(farmStep, failures)
        if not ok then
            warn("[" .. HUB_NAME .. "] farm: " .. tostring(err))
            task.wait(0.5)
        end
        RunService.Heartbeat:Wait()
    end
    releaseHover()
    if farmToken == token then
        setStatus("idle")
    end
end

local function stopFarm()
    State.Farm.Enabled = false
    farmToken += 1
    flightId += 1
    if activeTween then
        pcall(function()
            activeTween:Cancel()
        end)
        activeTween = nil
    end
    setStatus("idle")
end

local function startFarm()
    State.Farm.Enabled = true
    farmToken += 1
    task.spawn(farmLoop, farmToken)
end

local function flyToNearest()
    if flightBusy then
        return
    end
    if State.Farm.Enabled then
        setStatus("stop auto farm first")
        return
    end
    flightBusy = true
    task.spawn(function()
        local ok, err = pcall(function()
            refreshItems()
            local root = getRoot()
            if not root then
                setStatus("waiting for character")
                return
            end
            local target, dist = pickTarget(root.Position, {}, "Distance")
            if not target then
                setStatus("no items match the filter")
                return
            end
            setStatus(string.format("flying to %s (%d studs)", target.label, math.floor(dist)))
            acquireHover()
            local result = flyTo(target.part.Position + PICKUP_HOVER_OFFSET, target, State.Farm.Speed)
            releaseHover()
            if result == "arrived" then
                setStatus("arrived at " .. target.label)
            else
                setStatus("flight " .. result)
            end
        end)
        if not ok then
            warn("[" .. HUB_NAME .. "] nearest: " .. tostring(err))
        end
        flightBusy = false
    end)
end

local function teleportTo(position, label)
    if flightBusy then
        setTpStatus("busy, wait for the current flight")
        return
    end
    if State.Farm.Enabled then
        setTpStatus("stop auto farm first")
        return
    end
    if not getRoot() then
        setTpStatus("waiting for character")
        return
    end
    flightBusy = true
    task.spawn(function()
        local ok, err = pcall(function()
            setTpStatus("flying to " .. label)
            acquireHover()
            local result = flyTo(position, nil, State.Teleport.Speed)
            releaseHover()
            setTpStatus(result == "arrived" and ("arrived at " .. label) or ("flight " .. result))
        end)
        if not ok then
            warn("[" .. HUB_NAME .. "] teleport: " .. tostring(err))
        end
        flightBusy = false
    end)
end

--------------------------------------------------------------------------------
-- GUI button activation (used by auto buy and auto play)
--------------------------------------------------------------------------------

local function activateGuiButton(button)
    if type(firesignal) == "function" then
        local fired = false
        for _, signalName in ipairs({ "MouseButton1Down", "MouseButton1Click", "MouseButton1Up", "Activated" }) do
            local ok = pcall(function()
                firesignal(button[signalName])
            end)
            fired = fired or ok
        end
        if fired then
            return true
        end
    end
    if type(getconnections) == "function" then
        local ok = pcall(function()
            for _, connection in ipairs(getconnections(button.MouseButton1Click)) do
                connection:Fire()
            end
            for _, connection in ipairs(getconnections(button.Activated)) do
                connection:Fire()
            end
        end)
        if ok then
            return true
        end
    end
    local position = button.AbsolutePosition + button.AbsoluteSize / 2
    local parentGui = button:FindFirstAncestorOfClass("ScreenGui")
    if parentGui and not parentGui.IgnoreGuiInset then
        position += GuiService:GetGuiInset()
    end
    VirtualInputManager:SendMouseButtonEvent(position.X, position.Y, 0, true, game, 0)
    task.wait(0.05)
    VirtualInputManager:SendMouseButtonEvent(position.X, position.Y, 0, false, game, 0)
    return true
end

local function guiVisible(gui)
    local node = gui
    while node do
        if node:IsA("GuiObject") and not node.Visible then
            return false
        end
        if node:IsA("ScreenGui") then
            return node.Enabled
        end
        node = node.Parent
    end
    return true
end

--------------------------------------------------------------------------------
-- Auto sell
--------------------------------------------------------------------------------

local sellStatusLabel = nil
local sellBusy = false

local function setSellStatus(text)
    if sellStatusLabel then
        sellStatusLabel.Text = "Status: " .. text
    end
end

local function getBackpackTools()
    local list = {}
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") then
                table.insert(list, tool)
            end
        end
    end
    local char = LocalPlayer.Character
    if char then
        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") then
                table.insert(list, tool)
            end
        end
    end
    return list
end

local function countItem(label)
    local total = 0
    for _, tool in ipairs(getBackpackTools()) do
        local info = getItemInfo(tool.Name)
        if info and info.label == label then
            total += 1
        end
    end
    return total
end

local function isSellable(tool)
    local info = getItemInfo(tool.Name)
    if not info or not State.Sell.Selected[info.label] then
        return false
    end
    if State.Sell.ProtectRare and RARE_ITEMS[info.label] then
        return false
    end
    return true
end

local function sellTool(tool)
    local char = LocalPlayer.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    local remote = char and char:FindFirstChild("RemoteEvent")
    if not (humanoid and remote and humanoid.Health > 0) then
        return false
    end
    humanoid:EquipTool(tool)
    task.wait(0.2)
    remote:FireServer("EndDialogue", { NPC = "Merchant", Dialogue = "Dialogue5", Option = "Option1" })
    task.wait(0.4)
    return tool.Parent == nil
end

local function runSellCycle()
    if sellBusy then
        return
    end
    sellBusy = true
    local ok, err = pcall(function()
        local sold = 0
        local queue = {}
        for _, tool in ipairs(getBackpackTools()) do
            if isSellable(tool) then
                table.insert(queue, tool)
            end
        end
        if #queue == 0 then
            setSellStatus("nothing to sell")
            return
        end
        for _, tool in ipairs(queue) do
            if not alive then
                break
            end
            if tool.Parent and isSellable(tool) then
                setSellStatus("selling " .. tool.Name)
                if sellTool(tool) then
                    sold += 1
                    Stats.Sold += 1
                end
            end
        end
        setSellStatus(string.format("sold %d item(s), total %d", sold, Stats.Sold))
    end)
    if not ok then
        warn("[" .. HUB_NAME .. "] sell: " .. tostring(err))
    end
    sellBusy = false
end

task.spawn(function()
    while alive do
        if State.Sell.Enabled then
            runSellCycle()
            local waited = 0
            while alive and State.Sell.Enabled and waited < State.Sell.Interval do
                task.wait(0.5)
                waited += 0.5
            end
        else
            task.wait(0.5)
        end
    end
end)

--------------------------------------------------------------------------------
-- Auto buy Lucky Arrows (finds the shop button in the UI)
--------------------------------------------------------------------------------

local buyStatusLabel = nil

local function setBuyStatus(text)
    if buyStatusLabel then
        buyStatusLabel.Text = "Status: " .. text
    end
end

local function findLuckyArrowButton()
    local gui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not gui then
        return nil
    end
    local fallback = nil
    for _, desc in ipairs(gui:GetDescendants()) do
        if not isOwnGui(desc) then
            local lname = string.lower(desc.Name)
            local text = ""
            if desc:IsA("TextLabel") or desc:IsA("TextButton") then
                text = string.lower(desc.Text)
            end
            local hit = string.find(lname, "lucky arrow", 1, true) or string.find(lname, "luckyarrow", 1, true)
                or string.find(text, "lucky arrow", 1, true)
            if hit then
                if desc:IsA("GuiButton") then
                    return desc
                end
                local node = desc
                for _ = 1, 4 do
                    node = node.Parent
                    if not node or node == gui then
                        break
                    end
                    local button = node:FindFirstChildWhichIsA("GuiButton", true)
                    if button and not isOwnGui(button) then
                        fallback = fallback or button
                        break
                    end
                end
            end
        end
    end
    return fallback
end

local function buyStep()
    local held = countItem("Lucky Arrow")
    if held >= State.Buy.Target then
        setBuyStatus(string.format("holding %d, target reached", held))
        return 5
    end
    local money = tonumber(readStat(LocalPlayer, STAT_NAMES.Money))
    if money and money < State.Buy.Price then
        setBuyStatus(string.format("need $%s, have $%s", formatNumber(State.Buy.Price), formatNumber(money)))
        return 4
    end
    local button = findLuckyArrowButton()
    if not button then
        setBuyStatus("shop button not found (open Menu > Shop once)")
        return 6
    end
    setBuyStatus("buying Lucky Arrow")
    activateGuiButton(button)
    task.wait(1.5)
    if countItem("Lucky Arrow") > held then
        Stats.Bought += 1
        setBuyStatus(string.format("bought, total %d", Stats.Bought))
        return 1
    end
    setBuyStatus("purchase not confirmed, retrying later")
    return 8
end

task.spawn(function()
    while alive do
        if State.Buy.Enabled then
            local ok, result = pcall(buyStep)
            local delay = ok and result or 5
            if not ok then
                warn("[" .. HUB_NAME .. "] buy: " .. tostring(result))
            end
            local waited = 0
            while alive and State.Buy.Enabled and waited < delay do
                task.wait(0.5)
                waited += 0.5
            end
        else
            task.wait(0.5)
        end
    end
end)

--------------------------------------------------------------------------------
-- Anti AFK and auto Play
--------------------------------------------------------------------------------

track(LocalPlayer.Idled:Connect(function()
    if not State.Utils.AntiAfk then
        return
    end
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new(0, 0))
    end)
end))

local function findPlayButton()
    local gui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not gui then
        return nil
    end
    for _, desc in ipairs(gui:GetDescendants()) do
        if desc:IsA("GuiButton") and not isOwnGui(desc) and guiVisible(desc) then
            local name = string.lower(desc.Name)
            local text = desc:IsA("TextButton") and string.lower(desc.Text) or ""
            local childLabel = desc:FindFirstChildWhichIsA("TextLabel", true)
            local childText = childLabel and string.lower(childLabel.Text) or ""
            local function isPlay(value)
                return string.match(value, "^%s*play%s*$") ~= nil
            end
            if isPlay(name) or isPlay(text) or isPlay(childText) or name == "playbutton" then
                return desc
            end
        end
    end
    return nil
end

task.spawn(function()
    local startedAt = os.clock()
    local pressed = false
    while alive and not pressed and os.clock() - startedAt < 180 do
        if State.Utils.AutoPlay then
            local ok, button = pcall(findPlayButton)
            if ok and button then
                pcall(activateGuiButton, button)
                task.wait(3)
                local stillThere = select(2, pcall(findPlayButton))
                pressed = not stillThere
            end
        end
        task.wait(2)
    end
end)

--------------------------------------------------------------------------------
-- Farm screen, FPS
--------------------------------------------------------------------------------

local farmScreenToggle = nil
local currentFps = 0
local farmValues = {}

local function setFarmScreen(on)
    State.Utils.FarmScreen = on
    farmGui.Enabled = on
    pcall(function()
        RunService:Set3dRenderingEnabled(not on)
    end)
end

local farmCard = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(340, 320),
    BackgroundColor3 = T("Panel"),
    BorderSizePixel = 0,
}, {
    corner(14),
    stroke(T("Border"), 2),
    create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }),
    create("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18) }),
})
create("Frame", {
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = T("Background"),
    BorderSizePixel = 0,
    Active = true,
    Parent = farmGui,
}, { farmCard })

newLabel({
    LayoutOrder = 1,
    Size = UDim2.new(1, 0, 0, 30),
    Text = HUB_NAME,
    Font = Enum.Font.GothamBold,
    TextSize = 20,
    TextXAlignment = Enum.TextXAlignment.Center,
    Parent = farmCard,
})
local farmRowOrder = 1
local function farmRow(key, title)
    farmRowOrder += 1
    local row = create("Frame", {
        LayoutOrder = farmRowOrder,
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundTransparency = 1,
        Parent = farmCard,
    })
    newLabel({ Size = UDim2.new(0.5, 0, 1, 0), Text = title, TextColor3 = T("SubText"), TextSize = 14, Parent = row })
    farmValues[key] = newLabel({
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.fromScale(1, 0),
        Size = UDim2.new(0.5, 0, 1, 0),
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = row,
    })
end
farmRow("Money", "Money")
farmRow("Level", "Level")
farmRow("Session", "Session")
farmRow("Picked", "Items picked")
farmRow("Sold", "Items sold")
farmRow("Bought", "Lucky Arrows bought")
farmRow("Fps", "FPS")

local closeFarmButton = create("TextButton", {
    LayoutOrder = 20,
    Size = UDim2.new(1, 0, 0, 32),
    BackgroundColor3 = T("Accent"),
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Text = "Close farm screen",
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    TextColor3 = T("OnAccent"),
    Parent = farmCard,
}, { corner(8) })
closeFarmButton.MouseButton1Click:Connect(function()
    setFarmScreen(false)
    if farmScreenToggle then
        farmScreenToggle.Set(false, false)
    end
end)

local function updateFarmScreen()
    local money = readStat(LocalPlayer, STAT_NAMES.Money)
    local level = readStat(LocalPlayer, STAT_NAMES.Level)
    local elapsed = math.floor(os.clock() - Stats.StartedAt)
    farmValues.Money.Text = money ~= nil and ("$" .. formatNumber(money)) or "?"
    farmValues.Level.Text = level ~= nil and tostring(level) or "?"
    farmValues.Session.Text = string.format(
        "%02d:%02d:%02d",
        math.floor(elapsed / 3600),
        math.floor((elapsed % 3600) / 60),
        elapsed % 60
    )
    farmValues.Picked.Text = tostring(Stats.Picked)
    farmValues.Sold.Text = tostring(Stats.Sold)
    farmValues.Bought.Text = tostring(Stats.Bought)
    farmValues.Fps.Text = tostring(currentFps)
end

local fpsPill = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 8),
    Size = UDim2.fromOffset(76, 24),
    BackgroundColor3 = T("Panel"),
    BorderSizePixel = 0,
    Visible = Settings.ShowFps,
    Parent = screenGui,
}, { pill(), stroke(T("Border"), 1.5) })
local fpsLabel = newLabel({
    Size = UDim2.fromScale(1, 1),
    Text = "FPS 0",
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Center,
    Parent = fpsPill,
})

local fpsAccum, fpsFrames, farmClock = 0, 0, 0
track(RunService.RenderStepped:Connect(function(dt)
    fpsAccum += dt
    fpsFrames += 1
    if fpsAccum >= 0.5 then
        currentFps = math.floor(fpsFrames / fpsAccum + 0.5)
        fpsAccum, fpsFrames = 0, 0
        if fpsPill.Visible then
            fpsLabel.Text = "FPS " .. currentFps
        end
    end
    if State.Utils.FarmScreen then
        farmClock += dt
        if farmClock >= 0.5 then
            farmClock = 0
            safeCall(updateFarmScreen)
        end
    end
end))

--------------------------------------------------------------------------------
-- Player: walk speed, fly, noclip
--------------------------------------------------------------------------------

local walkOriginal = 16
local walkApplied = false
local flyActive = false
local noclipByUser = false

local function setWalk(on)
    State.Walk.Enabled = on
    local humanoid = getHumanoid()
    if on then
        if humanoid and not walkApplied then
            walkOriginal = humanoid.WalkSpeed
        end
        walkApplied = true
    elseif walkApplied then
        walkApplied = false
        if humanoid then
            humanoid.WalkSpeed = walkOriginal
        end
    end
end

local function setFly(on)
    State.Fly.Enabled = on
    if not on then
        flyActive = false
        local humanoid = getHumanoid()
        if humanoid then
            humanoid.PlatformStand = false
        end
    end
end

local function setNoclip(on)
    if on and not noclipByUser then
        noclipByUser = true
        acquireNoclip()
    elseif not on and noclipByUser then
        noclipByUser = false
        releaseNoclip()
    end
end

local function stepFly(humanoid, dt)
    local root = humanoid.Parent and humanoid.Parent:FindFirstChild("HumanoidRootPart")
    local camera = Workspace.CurrentCamera
    if not root or not camera then
        return
    end
    flyActive = true
    humanoid.PlatformStand = true
    local speed = State.Fly.Speed
    local move = humanoid.MoveDirection
    local look = camera.CFrame.LookVector
    local velocity = Vector3.zero
    if move.Magnitude > 0.05 then
        local flatLook = Vector3.new(look.X, 0, look.Z)
        local forward = 0
        if flatLook.Magnitude > 0.01 then
            forward = move:Dot(flatLook.Unit)
        end
        velocity = move * speed + Vector3.new(0, look.Y * forward * speed, 0)
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
        velocity += Vector3.new(0, speed, 0)
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        velocity -= Vector3.new(0, speed, 0)
    end
    root.AssemblyLinearVelocity = velocity + Vector3.new(0, 0.5 * Workspace.Gravity * dt, 0)
    root.AssemblyAngularVelocity = Vector3.zero
end

track(RunService.Heartbeat:Connect(function(dt)
    local humanoid = getHumanoid()
    if not humanoid or humanoid.Health <= 0 then
        return
    end
    if State.Walk.Enabled and humanoid.WalkSpeed ~= State.Walk.Speed then
        humanoid.WalkSpeed = State.Walk.Speed
    end
    local locked = State.Farm.Enabled or flightBusy
    if State.Fly.Enabled and not locked then
        stepFly(humanoid, dt)
    elseif flyActive then
        flyActive = false
        humanoid.PlatformStand = false
    end
end))

--------------------------------------------------------------------------------
-- Teleport targets: NPCs, players, places
--------------------------------------------------------------------------------

local npcLookup = {}
local placeLookup = {}

local function modelFrontPosition(model)
    local part = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
    if not part then
        return nil
    end
    return part.Position + part.CFrame.LookVector * 4 + Vector3.new(0, 2, 0)
end

local function listNpcs()
    npcLookup = {}
    local names = {}
    for _, desc in ipairs(Workspace:GetDescendants()) do
        if desc:IsA("Humanoid") then
            local model = desc.Parent
            if model and model:IsA("Model") and not Players:GetPlayerFromCharacter(model) and not npcLookup[model.Name] then
                npcLookup[model.Name] = model
                table.insert(names, model.Name)
            end
        end
    end
    table.sort(names)
    return names
end

local function listPlayers()
    local names = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(names, player.Name)
        end
    end
    table.sort(names)
    return names
end

local function listPlaces()
    placeLookup = {}
    local names = {}
    for _, place in ipairs(Settings.Places) do
        placeLookup[place.name] = Vector3.new(place.x, place.y, place.z)
        table.insert(names, place.name)
    end
    local spawnIndex = 0
    for _, desc in ipairs(Workspace:GetDescendants()) do
        if desc:IsA("SpawnLocation") then
            spawnIndex += 1
            local name = "Spawn " .. spawnIndex
            placeLookup[name] = desc.Position + Vector3.new(0, 4, 0)
            table.insert(names, name)
        end
    end
    return names
end

--------------------------------------------------------------------------------
-- World: fullbright, no fog, time of day, FOV
--------------------------------------------------------------------------------

local worldSaved = { Fullbright = nil, NoFog = nil, Time = nil, Atmosphere = {}, Fov = nil }

local function setProp(inst, prop, value)
    if inst[prop] ~= value then
        inst[prop] = value
    end
end

local function restoreProps(saved)
    if saved then
        for prop, value in pairs(saved) do
            pcall(function()
                Lighting[prop] = value
            end)
        end
    end
end

local function setFullbright(on)
    State.World.Fullbright = on
    if on then
        worldSaved.Fullbright = worldSaved.Fullbright or {
            Brightness = Lighting.Brightness,
            Ambient = Lighting.Ambient,
            OutdoorAmbient = Lighting.OutdoorAmbient,
            GlobalShadows = Lighting.GlobalShadows,
        }
    else
        restoreProps(worldSaved.Fullbright)
        worldSaved.Fullbright = nil
    end
end

local function restoreAtmosphere()
    for atmosphere, saved in pairs(worldSaved.Atmosphere) do
        if atmosphere.Parent then
            pcall(function()
                atmosphere.Density = saved.Density
                atmosphere.Haze = saved.Haze
            end)
        end
    end
    worldSaved.Atmosphere = {}
end

local function setNoFog(on)
    State.World.NoFog = on
    if on then
        worldSaved.NoFog = worldSaved.NoFog or { FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart }
    else
        restoreProps(worldSaved.NoFog)
        worldSaved.NoFog = nil
        restoreAtmosphere()
    end
end

local function setTimeOverride(on)
    State.World.Time = on
    if on then
        worldSaved.Time = worldSaved.Time or { ClockTime = Lighting.ClockTime }
    else
        restoreProps(worldSaved.Time)
        worldSaved.Time = nil
    end
end

local function setFovOverride(on)
    State.World.Fov = on
    local camera = Workspace.CurrentCamera
    if on then
        if camera and not worldSaved.Fov then
            worldSaved.Fov = camera.FieldOfView
        end
    else
        if camera and worldSaved.Fov then
            camera.FieldOfView = worldSaved.Fov
        end
        worldSaved.Fov = nil
    end
end

track(RunService.RenderStepped:Connect(function()
    local world = State.World
    if world.Fullbright then
        setProp(Lighting, "Brightness", 2)
        setProp(Lighting, "Ambient", Color3.fromRGB(178, 178, 178))
        setProp(Lighting, "OutdoorAmbient", Color3.fromRGB(178, 178, 178))
        setProp(Lighting, "GlobalShadows", false)
    end
    if world.NoFog then
        setProp(Lighting, "FogEnd", 1000000)
        setProp(Lighting, "FogStart", 0)
        for _, child in ipairs(Lighting:GetChildren()) do
            if child:IsA("Atmosphere") then
                if not worldSaved.Atmosphere[child] then
                    worldSaved.Atmosphere[child] = { Density = child.Density, Haze = child.Haze }
                end
                setProp(child, "Density", 0)
                setProp(child, "Haze", 0)
            end
        end
    end
    if world.Time then
        setProp(Lighting, "ClockTime", world.TimeValue)
    end
    if world.Fov then
        local camera = Workspace.CurrentCamera
        if camera then
            setProp(camera, "FieldOfView", world.FovValue)
        end
    end
end))

--------------------------------------------------------------------------------
-- UI helpers: drag, controls
--------------------------------------------------------------------------------

local function isPointerDown(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

-- Drag a target by a handle. A press without movement fires onTap.
local function makeDraggable(handle, target, onTap)
    local active = nil
    local startPointer = Vector2.zero
    local startPos = Vector2.zero
    local moved = false

    handle.InputBegan:Connect(function(input)
        if not isPointerDown(input) then
            return
        end
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
                    if not moved and onTap then
                        onTap()
                    end
                end
            end
        end)
    end)

    track(UserInputService.InputChanged:Connect(function(input)
        if not active then
            return
        end
        if input ~= active and input.UserInputType ~= Enum.UserInputType.MouseMovement then
            return
        end
        local delta = Vector2.new(input.Position.X, input.Position.Y) - startPointer
        if not moved and delta.Magnitude < 6 then
            return
        end
        moved = true
        local size = target.AbsoluteSize
        local x, y = clampPosition(startPos.X + delta.X, startPos.Y + delta.Y, size.X, size.Y)
        target.Position = UDim2.fromOffset(x, y)
    end))
end

-- Pointer tracking for sliders and pickers. Scrolling is locked during a drag.
local function trackDrag(hit, scroller, onDrag)
    local active = nil
    hit.InputBegan:Connect(function(input)
        if not isPointerDown(input) then
            return
        end
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

local layoutCounters = {}
local function nextOrder(page)
    layoutCounters[page] = (layoutCounters[page] or 0) + 1
    return layoutCounters[page]
end

local function addSection(page, text)
    return newLabel({
        Size = UDim2.new(1, 0, 0, 22),
        Text = string.upper(text),
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextColor3 = T("SubText"),
        LayoutOrder = nextOrder(page),
        Parent = page,
    })
end

local function addLabel(page, text)
    return newLabel({
        Size = UDim2.new(1, 0, 0, 24),
        Text = text,
        TextColor3 = T("SubText"),
        TextSize = 12,
        TextWrapped = true,
        LayoutOrder = nextOrder(page),
        Parent = page,
    })
end

local function newRow(page, height)
    return create("Frame", {
        Size = UDim2.new(1, 0, 0, height),
        BackgroundColor3 = T("Panel"),
        BorderSizePixel = 0,
        LayoutOrder = nextOrder(page),
        Parent = page,
    }, { corner(8) })
end

local function addToggle(page, text, default, callback)
    local row = newRow(page, 40)
    newLabel({ Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -70, 1, 0), Text = text, Parent = row })
    local trackFrame = create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(40, 22),
        BorderSizePixel = 0,
        Parent = row,
    }, { pill() })
    local knob = create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Size = UDim2.fromOffset(18, 18),
        BackgroundColor3 = WHITE,
        BorderSizePixel = 0,
        Parent = trackFrame,
    }, { pill() })
    local hit = create("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Text = "",
        AutoButtonColor = false,
        Parent = row,
    })

    local value = default
    local info = TweenInfo.new(0.15, Enum.EasingStyle.Quad)
    local function render(animate)
        local trackColor = value and Theme.Accent or Theme.Off
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
    table.insert(ThemeCallbacks, function()
        render(false)
    end)

    hit.MouseButton1Click:Connect(function()
        value = not value
        render(true)
        safeCall(callback, value)
    end)
    return {
        Set = function(newValue, fire)
            value = newValue
            render(true)
            if fire then
                safeCall(callback, value)
            end
        end,
    }
end

local function addSlider(page, text, min, max, default, step, suffix, callback)
    local row = newRow(page, 58)
    newLabel({ Position = UDim2.fromOffset(12, 6), Size = UDim2.new(0.6, 0, 0, 20), Text = text, Parent = row })
    local valueLabel = newLabel({
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -12, 0, 6),
        Size = UDim2.new(0.4, 0, 0, 20),
        TextColor3 = T("SubText"),
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = row,
    })
    local rail = create("Frame", {
        Position = UDim2.new(0, 12, 0, 38),
        Size = UDim2.new(1, -24, 0, 6),
        BackgroundColor3 = T("Off"),
        BorderSizePixel = 0,
        Parent = row,
    }, { pill() })
    local fill = create("Frame", {
        Size = UDim2.fromScale(0, 1),
        BackgroundColor3 = T("Accent"),
        BorderSizePixel = 0,
        Parent = rail,
    }, { pill() })
    local knob = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.fromOffset(16, 16),
        BackgroundColor3 = WHITE,
        BorderSizePixel = 0,
        ZIndex = 2,
        Parent = rail,
    }, { pill(), stroke(T("Accent"), 1.5) })
    local hit = create("TextButton", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 26),
        Size = UDim2.new(1, 0, 0, 32),
        Text = "",
        AutoButtonColor = false,
        Parent = row,
    })

    local function setValue(raw, fire)
        local value = math.clamp(math.floor((raw - min) / step + 0.5) * step + min, min, max)
        local alpha = (value - min) / (max - min)
        fill.Size = UDim2.fromScale(alpha, 1)
        knob.Position = UDim2.fromScale(alpha, 0.5)
        valueLabel.Text = tostring(value) .. suffix
        if fire then
            safeCall(callback, value)
        end
    end
    trackDrag(hit, page, function(pos)
        local alpha = math.clamp((pos.X - rail.AbsolutePosition.X) / math.max(rail.AbsoluteSize.X, 1), 0, 1)
        setValue(min + alpha * (max - min), true)
    end)
    setValue(default, false)
end

local function addColorPicker(page, text, default, callback)
    local h, s, v = Color3.toHSV(default)
    local container = newRow(page, 40)
    container.ClipsDescendants = true
    newLabel({ Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -70, 0, 40), Text = text, Parent = container })
    local swatch = create("Frame", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -12, 0, 10),
        Size = UDim2.fromOffset(34, 20),
        BackgroundColor3 = default,
        BorderSizePixel = 0,
        Parent = container,
    }, { corner(6), stroke(T("Border"), 1) })
    local headerHit = create("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 40),
        Text = "",
        AutoButtonColor = false,
        Parent = container,
    })

    local svBox = create("Frame", {
        Position = UDim2.fromOffset(12, 48),
        Size = UDim2.new(1, -56, 0, 100),
        BackgroundColor3 = Color3.fromHSV(h, 1, 1),
        BorderSizePixel = 0,
        Parent = container,
    }, { corner(6) })
    create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        Parent = svBox,
    }, {
        corner(6),
        create("UIGradient", {
            Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
        }),
    })
    create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BorderSizePixel = 0,
        Parent = svBox,
    }, {
        corner(6),
        create("UIGradient", {
            Rotation = 90,
            Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }),
        }),
    })
    local svKnob = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(12, 12),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = svBox,
    }, { pill(), stroke(Color3.new(0, 0, 0), 1.5) })

    local hueBar = create("Frame", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -12, 0, 48),
        Size = UDim2.fromOffset(24, 100),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        Parent = container,
    }, {
        corner(6),
        create("UIGradient", {
            Rotation = 90,
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
                ColorSequenceKeypoint.new(1 / 6, Color3.fromRGB(255, 255, 0)),
                ColorSequenceKeypoint.new(2 / 6, Color3.fromRGB(0, 255, 0)),
                ColorSequenceKeypoint.new(3 / 6, Color3.fromRGB(0, 255, 255)),
                ColorSequenceKeypoint.new(4 / 6, Color3.fromRGB(0, 0, 255)),
                ColorSequenceKeypoint.new(5 / 6, Color3.fromRGB(255, 0, 255)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
            }),
        }),
    })
    local hueKnob = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.new(1, 4, 0, 6),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = hueBar,
    }, { corner(3), stroke(Color3.new(0, 0, 0), 1.5) })

    local function apply(fire)
        local color = Color3.fromHSV(h, s, v)
        swatch.BackgroundColor3 = color
        svBox.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
        svKnob.Position = UDim2.fromScale(s, 1 - v)
        hueKnob.Position = UDim2.fromScale(0.5, h)
        if fire then
            safeCall(callback, color)
        end
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

-- Header shared by all dropdown variants. Returns container, valueLabel, arrow, hit.
local function dropdownHeader(page, text, valueText)
    local container = newRow(page, 40)
    container.ClipsDescendants = true
    newLabel({ Position = UDim2.fromOffset(12, 0), Size = UDim2.new(0.45, 0, 0, 40), Text = text, Parent = container })
    local valueLabel = newLabel({
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -30, 0, 0),
        Size = UDim2.new(0.55, -30, 0, 40),
        TextColor3 = T("SubText"),
        TextXAlignment = Enum.TextXAlignment.Right,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Text = valueText,
        Parent = container,
    })
    local arrow = newLabel({
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -10, 0, 0),
        Size = UDim2.fromOffset(16, 40),
        Text = ">",
        Font = Enum.Font.GothamBold,
        TextColor3 = T("SubText"),
        TextXAlignment = Enum.TextXAlignment.Center,
        Parent = container,
    })
    local hit = create("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 40),
        Text = "",
        AutoButtonColor = false,
        Parent = container,
    })
    return container, valueLabel, arrow, hit
end

local function expandTo(container, arrow, expanded, height)
    TweenService:Create(container, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
        Size = UDim2.new(1, 0, 0, expanded and height or 40),
    }):Play()
    TweenService:Create(arrow, TweenInfo.new(0.18), { Rotation = expanded and 90 or 0 }):Play()
end

local function addDropdown(page, text, options, default, callback)
    local rowHeight = 30
    local container, valueLabel, arrow, hit = dropdownHeader(page, text, default)
    local selected = default
    local buttons = {}
    local function render()
        valueLabel.Text = selected
        for option, button in pairs(buttons) do
            local isSelected = option == selected
            button.BackgroundColor3 = isSelected and Theme.Accent or Theme.Raised
            button.TextColor3 = isSelected and Theme.OnAccent or Theme.Text
        end
    end
    for index, option in ipairs(options) do
        buttons[option] = create("TextButton", {
            Position = UDim2.fromOffset(8, 40 + (index - 1) * rowHeight),
            Size = UDim2.new(1, -16, 0, rowHeight - 4),
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = option,
            Font = Enum.Font.GothamMedium,
            TextSize = 13,
            Parent = container,
        }, { corner(6) })
        buttons[option].MouseButton1Click:Connect(function()
            selected = option
            render()
            safeCall(callback, option)
        end)
    end
    render()
    table.insert(ThemeCallbacks, render)

    local expanded = false
    hit.MouseButton1Click:Connect(function()
        expanded = not expanded
        expandTo(container, arrow, expanded, 40 + #options * rowHeight + 6)
    end)
end

-- Dropdown whose options are rebuilt every time it opens (teleport targets).
local function addDynamicDropdown(page, text, getOptions)
    local maxList = 150
    local container, valueLabel, arrow, hit = dropdownHeader(page, text, "Select")
    local list = create("ScrollingFrame", {
        Position = UDim2.fromOffset(8, 44),
        Size = UDim2.new(1, -16, 0, 30),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = T("ScrollBar"),
        Parent = container,
    }, { create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })

    local selected = nil
    local expanded = false

    local function rebuild()
        for _, child in ipairs(list:GetChildren()) do
            if child:IsA("TextButton") or child:IsA("TextLabel") then
                child:Destroy()
            end
        end
        local options = getOptions()
        if #options == 0 then
            newLabel({
                Size = UDim2.new(1, -6, 0, 26),
                Text = "nothing found",
                TextColor3 = T("SubText"),
                Parent = list,
            })
        end
        for index, name in ipairs(options) do
            local isSelected = name == selected
            local button = create("TextButton", {
                LayoutOrder = index,
                Size = UDim2.new(1, -6, 0, 26),
                BackgroundColor3 = isSelected and T("Accent") or T("Raised"),
                BorderSizePixel = 0,
                AutoButtonColor = false,
                Text = name,
                Font = Enum.Font.GothamMedium,
                TextSize = 12,
                TextColor3 = isSelected and T("OnAccent") or T("Text"),
                TextTruncate = Enum.TextTruncate.AtEnd,
                Parent = list,
            }, { corner(6) })
            button.MouseButton1Click:Connect(function()
                selected = name
                valueLabel.Text = name
                expanded = false
                expandTo(container, arrow, false, 0)
            end)
        end
        local listHeight = math.min(math.max(#options, 1) * 30, maxList)
        list.Size = UDim2.new(1, -16, 0, listHeight)
        return 44 + listHeight + 8
    end

    hit.MouseButton1Click:Connect(function()
        expanded = not expanded
        if expanded then
            local height = rebuild()
            expandTo(container, arrow, true, height)
        else
            expandTo(container, arrow, false, 0)
        end
    end)
    return {
        GetSelected = function()
            return selected
        end,
        Clear = function()
            selected = nil
            valueLabel.Text = "Select"
        end,
    }
end

local function addMultiDropdown(page, text, options, selectedMap, callback)
    local rowHeight = 30
    local listTop = 78
    local container, valueLabel, arrow, hit = dropdownHeader(page, text, "")
    local boxes = {}
    local function render()
        local count = 0
        for option, box in pairs(boxes) do
            local isOn = selectedMap[option] == true
            box.BackgroundColor3 = isOn and Theme.Accent or Theme.Off
            if isOn then
                count += 1
            end
        end
        valueLabel.Text = count .. "/" .. #options
    end

    local function quickButton(label, xScale, xOffset, setAll)
        local button = create("TextButton", {
            Position = UDim2.new(xScale, xOffset, 0, 44),
            Size = UDim2.new(0.5, -12, 0, 28),
            BackgroundColor3 = T("Raised"),
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = label,
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextColor3 = T("Text"),
            Parent = container,
        }, { corner(6) })
        button.MouseButton1Click:Connect(function()
            for _, option in ipairs(options) do
                selectedMap[option] = setAll
            end
            render()
            safeCall(callback, selectedMap)
        end)
    end
    quickButton("Select all", 0, 8, true)
    quickButton("Clear", 0.5, 4, false)

    for index, option in ipairs(options) do
        local row = create("TextButton", {
            Position = UDim2.fromOffset(8, listTop + (index - 1) * rowHeight),
            Size = UDim2.new(1, -16, 0, rowHeight - 4),
            BackgroundColor3 = T("Raised"),
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = "",
            Parent = container,
        }, { corner(6) })
        boxes[option] = create("Frame", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 8, 0.5, 0),
            Size = UDim2.fromOffset(14, 14),
            BorderSizePixel = 0,
            Parent = row,
        }, { corner(4) })
        newLabel({ Position = UDim2.fromOffset(30, 0), Size = UDim2.new(1, -36, 1, 0), Text = option, Parent = row })
        row.MouseButton1Click:Connect(function()
            selectedMap[option] = not selectedMap[option]
            render()
            safeCall(callback, selectedMap)
        end)
    end
    render()
    table.insert(ThemeCallbacks, render)

    local expanded = false
    hit.MouseButton1Click:Connect(function()
        expanded = not expanded
        expandTo(container, arrow, expanded, listTop + #options * rowHeight + 6)
    end)
end

local function addButton(page, text, callback, secondary)
    local base = secondary and "Raised" or "Accent"
    local button = create("TextButton", {
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundColor3 = T(base),
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = text,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextColor3 = secondary and T("Text") or T("OnAccent"),
        LayoutOrder = nextOrder(page),
        Parent = page,
    }, { corner(8) })
    button.MouseButton1Click:Connect(function()
        button.BackgroundColor3 = Theme.AccentPressed
        TweenService:Create(button, TweenInfo.new(0.25), { BackgroundColor3 = Theme[base] }):Play()
        safeCall(callback)
    end)
end

local function addTextBox(page, placeholder)
    local row = newRow(page, 40)
    local box = create("TextBox", {
        Position = UDim2.fromOffset(8, 6),
        Size = UDim2.new(1, -16, 0, 28),
        BackgroundColor3 = T("Raised"),
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        PlaceholderText = placeholder,
        PlaceholderColor3 = T("SubText"),
        Text = "",
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        TextColor3 = T("Text"),
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = row,
    }, { corner(6), create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }) })
    return box
end

--------------------------------------------------------------------------------
-- Window
--------------------------------------------------------------------------------

local function computeWindowSize()
    local screen = getScreenSize()
    return math.clamp(screen.X - 40, 320, 560), math.clamp(screen.Y - 40, 240, 360)
end

local normalW, normalH = computeWindowSize()
local winW, winH = normalW, normalH
local startScreen = getScreenSize()
local iconSize = Settings.IconSize

local window = create("CanvasGroup", {
    Name = "Window",
    Active = true,
    BackgroundColor3 = T("Background"),
    BorderSizePixel = 0,
    Position = UDim2.fromOffset(math.floor((startScreen.X - winW) / 2), math.floor((startScreen.Y - winH) / 2)),
    Size = UDim2.fromOffset(winW, winH),
    Parent = screenGui,
}, { corner(12), stroke(T("Border"), 2) })

local titleBar = create("Frame", {
    Name = "TitleBar",
    Active = true,
    BackgroundColor3 = T("Panel"),
    BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 0, TITLE_HEIGHT),
    Parent = window,
})
create("Frame", {
    Position = UDim2.new(0, 0, 1, -1),
    Size = UDim2.new(1, 0, 0, 1),
    BackgroundColor3 = T("Border"),
    BorderSizePixel = 0,
    Parent = titleBar,
})
newLabel({
    Name = "Title",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(160, 20),
    Text = HUB_NAME,
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    TextXAlignment = Enum.TextXAlignment.Center,
    Parent = titleBar,
})

local function makeLight(color, xOffset)
    return create("TextButton", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, xOffset, 0.5, 0),
        Size = UDim2.fromOffset(18, 18),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextColor3 = Color3.fromRGB(45, 45, 45),
        Parent = titleBar,
    }, { pill() })
end

local closeLight = makeLight(Color3.fromRGB(255, 95, 87), 12)
local minimizeLight = makeLight(Color3.fromRGB(254, 188, 46), 38)
local zoomLight = makeLight(Color3.fromRGB(40, 200, 64), 64)

local lightGlyphs = { [closeLight] = "x", [minimizeLight] = "-", [zoomLight] = "+" }
for light in pairs(lightGlyphs) do
    light.MouseEnter:Connect(function()
        for other, glyph in pairs(lightGlyphs) do
            other.Text = glyph
        end
    end)
    light.MouseLeave:Connect(function()
        for other in pairs(lightGlyphs) do
            other.Text = ""
        end
    end)
end

local sidebar = create("Frame", {
    Name = "Sidebar",
    Active = true,
    BackgroundColor3 = T("Panel"),
    BorderSizePixel = 0,
    Position = UDim2.fromOffset(0, TITLE_HEIGHT),
    Size = UDim2.new(0, SIDEBAR_WIDTH, 1, -TITLE_HEIGHT),
    Parent = window,
})
create("Frame", {
    Position = UDim2.new(1, -1, 0, 0),
    Size = UDim2.new(0, 1, 1, 0),
    BackgroundColor3 = T("Border"),
    BorderSizePixel = 0,
    Parent = sidebar,
})
local tabList = create("Frame", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 1, -30),
    Parent = sidebar,
}, {
    create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
    create("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 9) }),
})
newLabel({
    AnchorPoint = Vector2.new(0.5, 1),
    Position = UDim2.new(0.5, 0, 1, -8),
    Size = UDim2.new(1, -16, 0, 16),
    Text = "YBA",
    TextSize = 11,
    TextColor3 = T("SubText"),
    TextXAlignment = Enum.TextXAlignment.Center,
    Parent = sidebar,
})

local content = create("Frame", {
    Name = "Content",
    BackgroundTransparency = 1,
    ClipsDescendants = true,
    Position = UDim2.fromOffset(SIDEBAR_WIDTH, TITLE_HEIGHT),
    Size = UDim2.new(1, -SIDEBAR_WIDTH, 1, -TITLE_HEIGHT),
    Parent = window,
})

local Tabs = {}
local activeTab = nil
local function paintTabs()
    for tabName, tab in pairs(Tabs) do
        local isSelected = tabName == activeTab
        tab.page.Visible = isSelected
        TweenService:Create(tab.button, TweenInfo.new(0.15), {
            BackgroundTransparency = isSelected and 0 or 1,
            BackgroundColor3 = Theme.TabSelected,
            TextColor3 = isSelected and Theme.Text or Theme.SubText,
        }):Play()
    end
end
table.insert(ThemeCallbacks, paintTabs)

local function selectTab(name)
    activeTab = name
    paintTabs()
end

local function addTab(name, order)
    local button = create("TextButton", {
        Name = name,
        LayoutOrder = order,
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = name,
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        Parent = tabList,
    }, { corner(8) })
    local page = create("ScrollingFrame", {
        Name = name .. "Page",
        Visible = false,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = T("ScrollBar"),
        Parent = content,
    }, {
        create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
        create("UIPadding", {
            PaddingTop = UDim.new(0, 10),
            PaddingBottom = UDim.new(0, 10),
            PaddingLeft = UDim.new(0, 10),
            PaddingRight = UDim.new(0, 12),
        }),
    })
    Tabs[name] = { page = page, button = button }
    button.MouseButton1Click:Connect(function()
        selectTab(name)
    end)
    return page
end

--------------------------------------------------------------------------------
-- Tab: Farming
--------------------------------------------------------------------------------

local farmingPage = addTab("Farming", 1)

addSection(farmingPage, "Auto farm items")
addToggle(farmingPage, "Auto farm items", false, function(value)
    if value then
        startFarm()
    else
        stopFarm()
    end
end)
addSlider(farmingPage, "Tween speed", 500, 3000, State.Farm.Speed, 50, " studs/s", function(value)
    State.Farm.Speed = value
end)
addDropdown(farmingPage, "Target priority", { "Distance", "Value" }, State.Farm.Priority, function(option)
    State.Farm.Priority = option
end)
addMultiDropdown(farmingPage, "Items filter", FILTER_OPTIONS, State.Farm.Selected, function(selectedMap)
    State.Farm.Selected = selectedMap
end)
addButton(farmingPage, "Teleport to Nearest", flyToNearest)
statusLabel = addLabel(farmingPage, "Status: idle")

addSection(farmingPage, "Auto sell")
addToggle(farmingPage, "Auto sell", false, function(value)
    State.Sell.Enabled = value
    if not value then
        setSellStatus("idle")
    end
end)
addMultiDropdown(farmingPage, "Items to sell", ITEM_LABELS, State.Sell.Selected, function(selectedMap)
    State.Sell.Selected = selectedMap
end)
addToggle(farmingPage, "Don't sell rare items", State.Sell.ProtectRare, function(value)
    State.Sell.ProtectRare = value
end)
addSlider(farmingPage, "Sell every", 5, 120, State.Sell.Interval, 5, " s", function(value)
    State.Sell.Interval = value
end)
addButton(farmingPage, "Sell now", function()
    task.spawn(runSellCycle)
end, true)
sellStatusLabel = addLabel(farmingPage, "Status: idle")
addLabel(farmingPage, "Rare items kept: Lucky Arrow, Lucky Stone Mask")

addSection(farmingPage, "Auto buy")
addToggle(farmingPage, "Auto buy Lucky Arrows", false, function(value)
    State.Buy.Enabled = value
    if not value then
        setBuyStatus("idle")
    end
end)
addSlider(farmingPage, "Hold up to", 1, 25, State.Buy.Target, 1, " arrows", function(value)
    State.Buy.Target = value
end)
buyStatusLabel = addLabel(farmingPage, "Status: idle")
addLabel(farmingPage, "Price: $75,000 each")

addSection(farmingPage, "Utilities")
addToggle(farmingPage, "Anti AFK", State.Utils.AntiAfk, function(value)
    State.Utils.AntiAfk = value
end)
addToggle(farmingPage, "Auto press Play after rejoin", State.Utils.AutoPlay, function(value)
    State.Utils.AutoPlay = value
end)
farmScreenToggle = addToggle(farmingPage, "Farm screen", false, function(value)
    setFarmScreen(value)
    if value then
        safeCall(updateFarmScreen)
    end
end)

--------------------------------------------------------------------------------
-- Tab: Visuals
--------------------------------------------------------------------------------

local visualsPage = addTab("Visuals", 2)

addSection(visualsPage, "Items ESP")
addToggle(visualsPage, "Show items", false, function(value)
    State.ItemESP.Enabled = value
    if value then
        task.spawn(safeCall, refreshItems)
    else
        clearItemESP()
    end
end)
addSlider(visualsPage, "Range", 500, 5000, State.ItemESP.Range, 50, " studs", function(value)
    State.ItemESP.Range = value
end)
addColorPicker(visualsPage, "Items color", State.ItemESP.Color, function(color)
    State.ItemESP.Color = color
end)

addSection(visualsPage, "Players ESP")
addToggle(visualsPage, "Show players", false, function(value)
    State.PlayerESP.Enabled = value
    if not value then
        clearPlayerESP()
    end
end)
addMultiDropdown(
    visualsPage,
    "Display",
    { "Name", "Distance", "Health", "Stand", "Spec", "Level" },
    State.PlayerESP.Fields,
    function(selectedMap)
        State.PlayerESP.Fields = selectedMap
    end
)
addSlider(visualsPage, "Range", 500, 5000, State.PlayerESP.Range, 50, " studs", function(value)
    State.PlayerESP.Range = value
end)
addToggle(visualsPage, "Tracers", false, function(value)
    State.PlayerESP.Tracers = value
    if not value then
        clearTracers()
    end
end)
addColorPicker(visualsPage, "Players color", State.PlayerESP.Color, function(color)
    State.PlayerESP.Color = color
end)

addSection(visualsPage, "World")
addToggle(visualsPage, "Fullbright", false, setFullbright)
addToggle(visualsPage, "No fog", false, setNoFog)
addToggle(visualsPage, "Override time of day", false, setTimeOverride)
addSlider(visualsPage, "Time of day", 0, 24, State.World.TimeValue, 0.5, " h", function(value)
    State.World.TimeValue = value
end)
addToggle(visualsPage, "Override FOV", false, setFovOverride)
addSlider(visualsPage, "FOV", 40, 120, State.World.FovValue, 1, "", function(value)
    State.World.FovValue = value
end)

--------------------------------------------------------------------------------
-- Tab: Player
--------------------------------------------------------------------------------

local playerPage = addTab("Player", 3)

addSection(playerPage, "Movement")
addToggle(playerPage, "Walk speed", false, setWalk)
addSlider(playerPage, "Speed", 16, 150, State.Walk.Speed, 1, "", function(value)
    State.Walk.Speed = value
end)
addToggle(playerPage, "Fly", false, setFly)
addSlider(playerPage, "Fly speed", 10, 300, State.Fly.Speed, 5, " studs/s", function(value)
    State.Fly.Speed = value
end)
addToggle(playerPage, "Noclip", false, setNoclip)
addLabel(playerPage, "Fly: move stick or WASD, look up/down to climb, Space/Ctrl on PC")

addSection(playerPage, "Teleports")
addSlider(playerPage, "Teleport speed", 500, 5000, State.Teleport.Speed, 50, " studs/s", function(value)
    State.Teleport.Speed = value
end)

local npcPicker = addDynamicDropdown(playerPage, "NPC", listNpcs)
addButton(playerPage, "Teleport to NPC", function()
    local name = npcPicker.GetSelected()
    local model = name and npcLookup[name]
    local position = model and model.Parent and modelFrontPosition(model)
    if position then
        teleportTo(position, name)
    else
        setTpStatus("pick an NPC first")
    end
end)

local playerPicker = addDynamicDropdown(playerPage, "Player", listPlayers)
addButton(playerPage, "Teleport to player", function()
    local name = playerPicker.GetSelected()
    local target = name and Players:FindFirstChild(name)
    local char = target and target.Character
    local position = char and modelFrontPosition(char)
    if position then
        teleportTo(position, name)
    else
        setTpStatus("pick a player first")
    end
end)

local placePicker = addDynamicDropdown(playerPage, "Place", listPlaces)
addButton(playerPage, "Teleport to place", function()
    local name = placePicker.GetSelected()
    local position = name and placeLookup[name]
    if position then
        teleportTo(position, name)
    else
        setTpStatus("pick a place first")
    end
end)
local placeNameBox = addTextBox(playerPage, "New place name")
addButton(playerPage, "Save current position", function()
    local root = getRoot()
    if not root then
        setTpStatus("waiting for character")
        return
    end
    local name = placeNameBox.Text
    if name == "" then
        name = "Place " .. (#Settings.Places + 1)
    end
    for index = #Settings.Places, 1, -1 do
        if Settings.Places[index].name == name then
            table.remove(Settings.Places, index)
        end
    end
    local position = root.Position
    table.insert(Settings.Places, { name = name, x = position.X, y = position.Y, z = position.Z })
    saveSettings()
    placeNameBox.Text = ""
    setTpStatus("saved place " .. name)
end, true)
addButton(playerPage, "Delete selected place", function()
    local name = placePicker.GetSelected()
    for index = #Settings.Places, 1, -1 do
        if Settings.Places[index].name == name then
            table.remove(Settings.Places, index)
            saveSettings()
            placePicker.Clear()
            setTpStatus("deleted " .. name)
            return
        end
    end
    setTpStatus("only saved places can be deleted")
end, true)
tpStatusLabel = addLabel(playerPage, "Status: idle")

--------------------------------------------------------------------------------
-- Minimized icon (follows the theme)
--------------------------------------------------------------------------------

local minimized = false
local animating = false

local iconScale = create("UIScale", { Scale = 1 })
local icon = create("Frame", {
    Name = "MinimizedIcon",
    Active = true,
    Visible = false,
    BackgroundColor3 = T("Background"),
    BorderSizePixel = 0,
    Position = UDim2.fromOffset(20, 20),
    Size = UDim2.fromOffset(iconSize, iconSize),
    Parent = screenGui,
}, { corner(14), stroke(T("IconStroke"), 2), iconScale })

-- Crescent: a disc with a background-colored disc cut out of it (scale based, so it follows the icon size).
create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.446, 0.5),
    Size = UDim2.fromScale(0.536, 0.536),
    BackgroundColor3 = T("Moon"),
    BorderSizePixel = 0,
    ZIndex = 1,
    Parent = icon,
}, { pill() })
create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.607, 0.411),
    Size = UDim2.fromScale(0.464, 0.464),
    BackgroundColor3 = T("Background"),
    BorderSizePixel = 0,
    ZIndex = 2,
    Parent = icon,
}, { pill() })

local function minimizeWindow()
    if animating or minimized then
        return
    end
    animating = true
    local winPos = window.AbsolutePosition
    local ix, iy = clampPosition(winPos.X + 6, winPos.Y + 6, iconSize, iconSize)
    local collapse = TweenService:Create(window, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut), {
        Size = UDim2.fromOffset(iconSize, iconSize),
        Position = UDim2.fromOffset(ix, iy),
        GroupTransparency = 1,
    })
    collapse:Play()
    collapse.Completed:Wait()
    window.Visible = false
    icon.Position = UDim2.fromOffset(ix, iy)
    icon.Size = UDim2.fromOffset(iconSize, iconSize)
    iconScale.Scale = 0.6
    icon.Visible = true
    TweenService:Create(iconScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Scale = 1,
    }):Play()
    minimized = true
    animating = false
end

local function restoreWindow()
    if animating or not minimized then
        return
    end
    animating = true
    local ix = icon.Position.X.Offset
    local iy = icon.Position.Y.Offset
    local x, y = clampPosition(ix, iy, winW, winH)
    icon.Visible = false
    window.Size = UDim2.fromOffset(iconSize, iconSize)
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

local maximized = false
local function toggleZoom()
    if animating or minimized then
        return
    end
    maximized = not maximized
    local screen = getScreenSize()
    local pos = window.AbsolutePosition
    local x, y
    if maximized then
        winW, winH = math.max(screen.X - 40, normalW), math.max(screen.Y - 40, normalH)
        x, y = (screen.X - winW) / 2, (screen.Y - winH) / 2
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
    if processed then
        return
    end
    if input.KeyCode == Enum.KeyCode.RightShift then
        if minimized then
            task.spawn(restoreWindow)
        else
            task.spawn(minimizeWindow)
        end
    end
end))

--------------------------------------------------------------------------------
-- Tab: Settings
--------------------------------------------------------------------------------

local settingsPage = addTab("Settings", 4)

addSection(settingsPage, "Appearance")
addDropdown(settingsPage, "Script theme", { "Dark", "Light" }, Settings.Theme, function(option)
    Settings.Theme = option
    applyTheme(option)
    saveSettings()
end)
addSlider(settingsPage, "Mini icon size", 40, 96, iconSize, 2, " px", function(value)
    iconSize = value
    Settings.IconSize = value
    if icon.Visible then
        local x, y = clampPosition(icon.Position.X.Offset, icon.Position.Y.Offset, value, value)
        icon.Position = UDim2.fromOffset(x, y)
        icon.Size = UDim2.fromOffset(value, value)
    end
    saveSettings()
end)
addToggle(settingsPage, "Show FPS", Settings.ShowFps, function(value)
    Settings.ShowFps = value
    fpsPill.Visible = value
    saveSettings()
end)
addSection(settingsPage, "Info")
addLabel(settingsPage, "RightShift or the yellow dot minimizes the window")

selectTab("Farming")

--------------------------------------------------------------------------------
-- Cleanup
--------------------------------------------------------------------------------

local function destroyHub()
    if not alive then
        return
    end
    alive = false
    State.Farm.Enabled = false
    State.ItemESP.Enabled = false
    State.PlayerESP.Enabled = false
    State.Sell.Enabled = false
    State.Buy.Enabled = false
    farmToken += 1
    flightId += 1
    if activeTween then
        pcall(function()
            activeTween:Cancel()
        end)
        activeTween = nil
    end
    setFly(false)
    setWalk(false)
    setNoclip(false)
    setFullbright(false)
    setNoFog(false)
    setTimeOverride(false)
    setFovOverride(false)
    setFarmScreen(false)
    if hoverConn then
        hoverConn:Disconnect()
        hoverConn = nil
    end
    if noclipConn then
        noclipUsers = 1
        releaseNoclip()
    end
    clearItemESP()
    clearPlayerESP()
    for _, connection in ipairs(Connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    table.clear(Connections)
    screenGui:Destroy()
    farmGui:Destroy()
    tracerGui:Destroy()
    espFolder:Destroy()
    if env.MoonlightHub and env.MoonlightHub.Destroy == destroyHub then
        env.MoonlightHub = nil
    end
end

closeLight.MouseButton1Click:Connect(function()
    TweenService:Create(window, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { GroupTransparency = 1 }):Play()
    task.delay(0.2, destroyHub)
end)

env.MoonlightHub = { Destroy = destroyHub }