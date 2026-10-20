--[[
    MoonlightHub | Your Bizarre Adventure
    Tabs: Farming, Visuals, Player, Settings
    RightShift: minimize / restore

    Structure note: every feature lives in its own Build.* function, so the main
    chunk stays far below Luau's limit of 200 local variables per function.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local env = (type(getgenv) == "function" and getgenv()) or _G
if type(env.MoonlightHub) == "table" and type(env.MoonlightHub.Destroy) == "function" then
    pcall(env.MoonlightHub.Destroy)
end

local LocalPlayer = Players.LocalPlayer

local HUB_NAME = "MoonlightHub"
local TITLE_HEIGHT = 38
local SIDEBAR_WIDTH = 120
local PICKUP_HOVER_OFFSET = Vector3.new(0, 3, 0)
local WHITE = Color3.fromRGB(255, 255, 255)

--------------------------------------------------------------------------------
-- Settings (saved to a file when the executor supports it)
--------------------------------------------------------------------------------

local Settings = { IconSize = 56, ShowFps = false, Places = {} }
local saveSettings

do
    local HttpService = game:GetService("HttpService")
    local SETTINGS_FILE = "MoonlightHub_Settings.json"
    local saveQueued = false

    if type(isfile) == "function" and type(readfile) == "function" then
        pcall(function()
            if not isfile(SETTINGS_FILE) then
                return
            end
            local data = HttpService:JSONDecode(readfile(SETTINGS_FILE))
            if type(data) ~= "table" then
                return
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

    function saveSettings()
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
end

--------------------------------------------------------------------------------
-- Basics: connections, safe calls
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

--------------------------------------------------------------------------------
-- Palette (dark only: anthracite + dark purple)
--------------------------------------------------------------------------------

local Theme = {
    Background = Color3.fromRGB(26, 27, 33),
    Panel = Color3.fromRGB(46, 43, 60),
    Raised = Color3.fromRGB(64, 60, 84),
    Border = Color3.fromRGB(14, 14, 18),
    Text = Color3.fromRGB(238, 236, 246),
    SubText = Color3.fromRGB(152, 148, 170),
    Accent = Color3.fromRGB(104, 52, 168),
    Accent2 = Color3.fromRGB(156, 104, 232),
    AccentPressed = Color3.fromRGB(78, 36, 128),
    OnAccent = Color3.fromRGB(255, 255, 255),
    Off = Color3.fromRGB(84, 82, 102),
    Moon = Color3.fromRGB(232, 222, 250),
}

local function T(key)
    return Theme[key]
end

--------------------------------------------------------------------------------
-- Catalog and state
--------------------------------------------------------------------------------

local RARE_ITEMS = { ["Lucky Arrow"] = true, ["Lucky Stone Mask"] = true }
local STAT_NAMES = {
    Stand = { "Stand" },
    Spec = { "Spec", "Specialization" },
    Level = { "Level", "Lvl" },
    Money = { "Money", "Cash" },
}
local ITEM_LABELS = {}
local FILTER_OPTIONS = {}
local getItemInfo

do
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
    local byLength = {}
    for _, entry in ipairs(ITEM_CATALOG) do
        table.insert(byLength, entry)
        table.insert(ITEM_LABELS, entry.label)
        table.insert(FILTER_OPTIONS, entry.label)
    end
    table.insert(FILTER_OPTIONS, "Other")
    table.sort(byLength, function(a, b)
        return #a.key > #b.key
    end)

    function getItemInfo(name)
        if type(name) ~= "string" or name == "" then
            return nil
        end
        local lowered = string.lower(name)
        for _, entry in ipairs(byLength) do
            if string.find(lowered, entry.key, 1, true) then
                return entry
            end
        end
        return nil
    end
end

local State = {
    ItemESP = { Enabled = false, Range = 1500, Color = Color3.fromRGB(255, 214, 10) },
    PlayerESP = {
        Enabled = false,
        Range = 2000,
        Tracers = false,
        Color = Color3.fromRGB(255, 69, 58),
        Fields = { Name = true, Distance = true, Health = true, Stand = true, Spec = true, Level = true },
    },
    Farm = { Enabled = false, Speed = 150, Priority = "Distance", Humanize = true, Selected = {} },
    Sell = { Enabled = false, Interval = 15, ProtectRare = true, Selected = {} },
    Buy = { Enabled = false, Target = 5, Price = 75000 },
    Utils = { AntiAfk = true, AutoPlay = true, FarmScreen = false },
    Walk = { Enabled = false, Speed = 32 },
    Fly = { Enabled = false, Speed = 60 },
    World = { Fullbright = false, NoFog = false, Time = false, TimeValue = 14, Fov = false, FovValue = 90 },
    FlightBusy = false,
}
for _, option in ipairs(FILTER_OPTIONS) do
    State.Farm.Selected[option] = true
end
for _, option in ipairs(ITEM_LABELS) do
    State.Sell.Selected[option] = true
end

local Stats = { Picked = 0, Sold = 0, Bought = 0, StartedAt = os.clock() }

--------------------------------------------------------------------------------
-- Instance helpers
--------------------------------------------------------------------------------

local function create(className, props, children)
    local inst = Instance.new(className)
    local parent = nil
    if props then
        for key, value in pairs(props) do
            if key == "Parent" then
                parent = value
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

local function stroke(color, thickness, transparency)
    return create("UIStroke", {
        Color = color,
        Thickness = thickness,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })
end

-- Soft purple outline whose gradient slowly rotates (cheap, one looping tween).
local function gradientStroke(thickness)
    local line = stroke(WHITE, thickness, 0)
    local gradient = create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Theme.Accent2),
            ColorSequenceKeypoint.new(0.5, Theme.Accent),
            ColorSequenceKeypoint.new(1, Theme.Accent2),
        }),
        Rotation = 0,
        Parent = line,
    })
    TweenService:Create(
        gradient,
        TweenInfo.new(7, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1),
        { Rotation = 360 }
    ):Play()
    return line
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

local function mount(instance)
    local candidates = {}
    if type(gethui) == "function" then
        table.insert(candidates, function()
            return gethui()
        end)
    end
    table.insert(candidates, function()
        return game:GetService("CoreGui")
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

local screenGui, farmGui, tracerGui, espFolder

local function isOwnGui(instance)
    return instance:IsDescendantOf(screenGui) or instance:IsDescendantOf(farmGui) or instance:IsDescendantOf(tracerGui)
end

--------------------------------------------------------------------------------
-- Loading screen (built first, so a startup failure is visible on screen)
--------------------------------------------------------------------------------

local Loader = (function()
    local gui = newScreenGui(HUB_NAME .. "_Loader", 100, true)
    if not mount(gui) then
        error("[" .. HUB_NAME .. "] no writable UI container found")
    end

    local api = {}
    local scale = create("UIScale", { Scale = 0.9 })
    local card = create("CanvasGroup", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(300, 180),
        BackgroundColor3 = T("Background"),
        BorderSizePixel = 0,
        GroupTransparency = 1,
        Parent = gui,
    }, { corner(20), gradientStroke(2), scale })

    local moonBox = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 18),
        Size = UDim2.fromOffset(60, 60),
        BackgroundTransparency = 1,
        Parent = card,
    })
    local pulse = create("UIScale", { Scale = 1, Parent = moonBox })
    create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.446, 0.5),
        Size = UDim2.fromScale(0.536, 0.536),
        BackgroundColor3 = T("Moon"),
        BorderSizePixel = 0,
        Parent = moonBox,
    }, { pill() })
    create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.607, 0.411),
        Size = UDim2.fromScale(0.464, 0.464),
        BackgroundColor3 = T("Background"),
        BorderSizePixel = 0,
        ZIndex = 2,
        Parent = moonBox,
    }, { pill() })

    newLabel({
        Position = UDim2.fromOffset(0, 86),
        Size = UDim2.new(1, 0, 0, 24),
        Text = HUB_NAME,
        Font = Enum.Font.GothamBold,
        TextSize = 18,
        TextXAlignment = Enum.TextXAlignment.Center,
        Parent = card,
    })
    local status = newLabel({
        Position = UDim2.fromOffset(0, 112),
        Size = UDim2.new(1, 0, 0, 18),
        Text = "Starting",
        TextSize = 12,
        TextColor3 = T("SubText"),
        TextXAlignment = Enum.TextXAlignment.Center,
        Parent = card,
    })
    local rail = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 146),
        Size = UDim2.new(1, -64, 0, 6),
        BackgroundColor3 = T("Off"),
        BackgroundTransparency = 0.4,
        BorderSizePixel = 0,
        Parent = card,
    }, { pill() })
    create("Frame", {
        Name = "Fill",
        Size = UDim2.fromScale(0, 1),
        BackgroundColor3 = WHITE,
        BorderSizePixel = 0,
        Parent = rail,
    }, {
        pill(),
        create("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, T("Accent")),
                ColorSequenceKeypoint.new(1, T("Accent2")),
            }),
        }),
    })
    local fill = rail.Fill

    local errorLabel = newLabel({
        Position = UDim2.fromOffset(16, 134),
        Size = UDim2.new(1, -32, 0, 100),
        TextSize = 11,
        TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top,
        Visible = false,
        Parent = card,
    })
    local closeButton = create("TextButton", {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 240),
        Size = UDim2.new(1, -64, 0, 30),
        BackgroundColor3 = T("Accent"),
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "Close",
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextColor3 = T("OnAccent"),
        Visible = false,
        Parent = card,
    }, { corner(10) })

    local pulseTween = TweenService:Create(
        pulse,
        TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { Scale = 1.1 }
    )
    pulseTween:Play()
    TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { GroupTransparency = 0 }):Play()
    TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

    function api.Step(fraction, text)
        status.Text = text
        TweenService:Create(fill, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1),
        }):Play()
    end

    function api.Finish()
        api.Step(1, "Ready")
        task.wait(0.6)
        pulseTween:Cancel()
        TweenService:Create(card, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { GroupTransparency = 1 }):Play()
        TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { Scale = 0.95 }):Play()
        task.wait(0.27)
        gui:Destroy()
    end

    function api.Fail(message)
        pulseTween:Cancel()
        status.Text = "Failed to start"
        status.TextColor3 = Color3.fromRGB(255, 95, 87)
        rail.Visible = false
        errorLabel.Text = string.sub(tostring(message), 1, 700)
        errorLabel.Visible = true
        closeButton.Visible = true
        TweenService:Create(card, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
            Size = UDim2.fromOffset(330, 290),
        }):Play()
        closeButton.MouseButton1Click:Connect(function()
            gui:Destroy()
        end)
    end

    return api
end)()

local Build = {}
local Mod = {}

--------------------------------------------------------------------------------
-- Module: ESP (items and players)
--------------------------------------------------------------------------------

function Build.esp()
    local ITEMS_PATH = { "Item_Spawns", "Items" }
    local Items = {}
    local PlayerRecords = {}
    local api = { Items = Items }

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

    -- Items ---------------------------------------------------------------

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

    -- Players -------------------------------------------------------------

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

    api.itemAlive = itemAlive
    api.refreshItems = refreshItems
    api.clearItems = clearItemESP
    api.clearPlayers = clearPlayerESP
    api.clearTracers = clearTracers
    return api
end

--------------------------------------------------------------------------------
-- Module: movement (noclip, hover, walk speed, fly)
--------------------------------------------------------------------------------

function Build.move()
    local api = {}

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

    local walkOriginal = 16
    local walkApplied = false
    local flyActive = false
    local noclipByUser = false

    function api.setWalk(on)
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

    function api.setFly(on)
        State.Fly.Enabled = on
        if not on then
            flyActive = false
            local humanoid = getHumanoid()
            if humanoid then
                humanoid.PlatformStand = false
            end
        end
    end

    function api.setNoclip(on)
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
        local locked = State.Farm.Enabled or State.FlightBusy
        if State.Fly.Enabled and not locked then
            stepFly(humanoid, dt)
        elseif flyActive then
            flyActive = false
            humanoid.PlatformStand = false
        end
    end))

    api.acquireHover = acquireHover
    api.releaseHover = releaseHover

    function api.reset()
        api.setFly(false)
        api.setWalk(false)
        api.setNoclip(false)
        if hoverConn then
            hoverConn:Disconnect()
            hoverConn = nil
        end
        hoverUsers = 0
        if noclipConn then
            noclipUsers = 1
            releaseNoclip()
        end
    end

    return api
end

--------------------------------------------------------------------------------
-- Module: flight (item farm via TweenService, instant teleports)
--------------------------------------------------------------------------------

function Build.flight()
    local Esp, Move = Mod.esp, Mod.move
    local Items = Esp.Items
    local itemAlive, refreshItems = Esp.itemAlive, Esp.refreshItems
    local rng = Random.new()

    local api = { statusLabel = nil, tpLabel = nil }
    local activeTween = nil
    local flightId = 0
    local farmToken = 0

    local function setStatus(text)
        if api.statusLabel then
            api.statusLabel.Text = "Status: " .. text
        end
    end

    function api.setTpStatus(text)
        if api.tpLabel then
            api.tpLabel.Text = "Status: " .. text
        end
    end

    local fireProximity = nil
    if type(fireproximityprompt) == "function" then
        fireProximity = fireproximityprompt
    end

    -- With "safe mode" on, waits are randomized so the timing is not machine-perfect.
    local function pause(minSeconds, maxSeconds)
        if State.Farm.Humanize then
            task.wait(rng:NextNumber(minSeconds, maxSeconds))
        else
            task.wait(minSeconds)
        end
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

    -- One tween segment, duration = distance / speed. Returns how it ended.
    local function tweenSegment(position, rec, speed, myId)
        local root = getRoot()
        if not root then
            return "nochar"
        end
        local distance = (root.Position - position).Magnitude
        local duration = math.max(distance / speed, 0.05)
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

    -- Farm movement is strictly TweenService. In safe mode a long path is split into
    -- several short segments with small offsets and slightly different speeds.
    local function flyTo(position, rec, speed)
        local root = getRoot()
        if not root then
            return "nochar"
        end
        flightId += 1
        local myId = flightId
        local baseSpeed = math.max(speed or State.Farm.Speed, 50)
        local startPos = root.Position
        local total = (position - startPos).Magnitude
        local segments = 1
        if State.Farm.Humanize and total > 70 then
            segments = math.clamp(math.floor(total / 80), 2, 6)
        end
        for index = 1, segments do
            local target = startPos:Lerp(position, index / segments)
            local segmentSpeed = baseSpeed
            if State.Farm.Humanize then
                if index < segments then
                    target += Vector3.new(rng:NextNumber(-3, 3), rng:NextNumber(-1, 1), rng:NextNumber(-3, 3))
                end
                segmentSpeed = baseSpeed * rng:NextNumber(0.88, 1.12)
            end
            local result = tweenSegment(target, rec, segmentSpeed, myId)
            if result ~= "arrived" then
                return result
            end
            if State.Farm.Humanize and index < segments then
                task.wait(rng:NextNumber(0.03, 0.12))
            end
        end
        return "arrived"
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

    local function approachPoint(rec)
        local point = rec.part.Position + PICKUP_HOVER_OFFSET
        if State.Farm.Humanize then
            point += Vector3.new(rng:NextNumber(-1.2, 1.2), 0, rng:NextNumber(-1.2, 1.2))
        end
        return point
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
        local result = flyTo(approachPoint(target), target, State.Farm.Speed)
        if result == "gone" then
            setStatus("item disappeared, retargeting")
            return
        end
        if result ~= "arrived" or not itemAlive(target) then
            return
        end
        setStatus("picking up " .. target.label)
        pause(0.15, 0.45)
        pickUp(target)
        pause(0.6, 1.1)
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
            pause(0.1, 0.7)
        end
    end

    local function farmLoop(token)
        Move.acquireHover()
        local failures = {}
        while alive and farmToken == token and State.Farm.Enabled do
            local ok, err = pcall(farmStep, failures)
            if not ok then
                warn("[" .. HUB_NAME .. "] farm: " .. tostring(err))
                task.wait(0.5)
            end
            RunService.Heartbeat:Wait()
        end
        Move.releaseHover()
        if farmToken == token then
            setStatus("idle")
        end
    end

    function api.cancelAll()
        farmToken += 1
        flightId += 1
        if activeTween then
            pcall(function()
                activeTween:Cancel()
            end)
            activeTween = nil
        end
    end

    function api.stopFarm()
        State.Farm.Enabled = false
        api.cancelAll()
        setStatus("idle")
    end

    function api.startFarm()
        State.Farm.Enabled = true
        farmToken += 1
        task.spawn(farmLoop, farmToken)
    end

    function api.flyToNearest()
        if State.FlightBusy then
            return
        end
        if State.Farm.Enabled then
            setStatus("stop auto farm first")
            return
        end
        State.FlightBusy = true
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
                Move.acquireHover()
                local result = flyTo(approachPoint(target), target, State.Farm.Speed)
                Move.releaseHover()
                if result == "arrived" then
                    setStatus("arrived at " .. target.label)
                else
                    setStatus("flight " .. result)
                end
            end)
            if not ok then
                warn("[" .. HUB_NAME .. "] nearest: " .. tostring(err))
            end
            State.FlightBusy = false
        end)
    end

    -- Instant teleport (no tween). The game may rubber-band it back; we report that.
    function api.teleportInstant(position, label)
        if State.Farm.Enabled then
            api.setTpStatus("stop auto farm first")
            return
        end
        local char = LocalPlayer.Character
        local root = getRoot()
        if not (char and root) then
            api.setTpStatus("waiting for character")
            return
        end
        root.AssemblyLinearVelocity = Vector3.zero
        char:PivotTo(CFrame.new(position) * root.CFrame.Rotation)
        api.setTpStatus("teleported to " .. label)
        task.delay(0.6, function()
            local now = getRoot()
            if alive and now and (now.Position - position).Magnitude > 25 then
                api.setTpStatus("rubber-banded back, the anticheat rejected the teleport")
            end
        end)
    end

    return api
end

--------------------------------------------------------------------------------
-- Module: automation (auto sell, auto buy, anti AFK, auto Play)
--------------------------------------------------------------------------------

function Build.econ()
    local GuiService = game:GetService("GuiService")
    local VirtualUser = game:GetService("VirtualUser")
    local api = { sellLabel = nil, buyLabel = nil }

    function api.setSellStatus(text)
        if api.sellLabel then
            api.sellLabel.Text = "Status: " .. text
        end
    end

    function api.setBuyStatus(text)
        if api.buyLabel then
            api.buyLabel.Text = "Status: " .. text
        end
    end

    local setSellStatus, setBuyStatus = api.setSellStatus, api.setBuyStatus

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

    -- Auto sell -----------------------------------------------------------

    local sellBusy = false

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

    function api.runSellCycle()
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
                api.runSellCycle()
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

    -- Auto buy Lucky Arrows (finds the shop button in the UI) -------------

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

    -- Anti AFK and auto Play ---------------------------------------------

    track(LocalPlayer.Idled:Connect(function()
        if not State.Utils.AntiAfk then
            return
        end
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new(0, 0))
        end)
    end))

    local function isPlayText(value)
        return string.match(value, "^%s*play%s*$") ~= nil
    end

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
                if isPlayText(name) or isPlayText(text) or isPlayText(childText) or name == "playbutton" then
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

    return api
end

--------------------------------------------------------------------------------
-- Module: farm screen and FPS counter
--------------------------------------------------------------------------------

function Build.screen()
    local api = { toggle = nil }
    local farmValues = {}
    local currentFps = 0

    function api.set(on)
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
        create("UIListLayout", {
            Padding = UDim.new(0, 4),
            SortOrder = Enum.SortOrder.LayoutOrder,
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
        }),
        create("UIPadding", {
            PaddingTop = UDim.new(0, 12),
            PaddingBottom = UDim.new(0, 12),
            PaddingLeft = UDim.new(0, 18),
            PaddingRight = UDim.new(0, 18),
        }),
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
    local rowOrder = 1
    local function farmRow(key, title)
        rowOrder += 1
        local row = create("Frame", {
            LayoutOrder = rowOrder,
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

    local closeButton = create("TextButton", {
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
    closeButton.MouseButton1Click:Connect(function()
        api.set(false)
        if api.toggle then
            api.toggle.Set(false, false)
        end
    end)

    function api.update()
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

    function api.setFpsVisible(on)
        fpsPill.Visible = on
    end

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
                safeCall(api.update)
            end
        end
    end))

    return api
end

--------------------------------------------------------------------------------
-- Module: teleport targets (NPCs, players, places)
--------------------------------------------------------------------------------

function Build.targets()
    local api = {}
    local npcLookup = {}
    local placeLookup = {}

    function api.frontPosition(model)
        local part = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
        if not part then
            return nil
        end
        return part.Position + part.CFrame.LookVector * 4 + Vector3.new(0, 2, 0)
    end

    function api.listNpcs()
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

    function api.listPlayers()
        local names = {}
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                table.insert(names, player.Name)
            end
        end
        table.sort(names)
        return names
    end

    function api.listPlaces()
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

    function api.npcModel(name)
        return npcLookup[name]
    end

    function api.placePosition(name)
        return placeLookup[name]
    end

    return api
end

--------------------------------------------------------------------------------
-- Module: world (fullbright, no fog, time of day, FOV)
--------------------------------------------------------------------------------

function Build.world()
    local Lighting = game:GetService("Lighting")
    local api = {}
    local saved = { Fullbright = nil, NoFog = nil, Time = nil, Atmosphere = {}, Fov = nil }

    local function setProp(inst, prop, value)
        if inst[prop] ~= value then
            inst[prop] = value
        end
    end

    local function restoreProps(values)
        if values then
            for prop, value in pairs(values) do
                pcall(function()
                    Lighting[prop] = value
                end)
            end
        end
    end

    function api.setFullbright(on)
        State.World.Fullbright = on
        if on then
            saved.Fullbright = saved.Fullbright or {
                Brightness = Lighting.Brightness,
                Ambient = Lighting.Ambient,
                OutdoorAmbient = Lighting.OutdoorAmbient,
                GlobalShadows = Lighting.GlobalShadows,
            }
        else
            restoreProps(saved.Fullbright)
            saved.Fullbright = nil
        end
    end

    local function restoreAtmosphere()
        for atmosphere, values in pairs(saved.Atmosphere) do
            if atmosphere.Parent then
                pcall(function()
                    atmosphere.Density = values.Density
                    atmosphere.Haze = values.Haze
                end)
            end
        end
        saved.Atmosphere = {}
    end

    function api.setNoFog(on)
        State.World.NoFog = on
        if on then
            saved.NoFog = saved.NoFog or { FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart }
        else
            restoreProps(saved.NoFog)
            saved.NoFog = nil
            restoreAtmosphere()
        end
    end

    function api.setTimeOverride(on)
        State.World.Time = on
        if on then
            saved.Time = saved.Time or { ClockTime = Lighting.ClockTime }
        else
            restoreProps(saved.Time)
            saved.Time = nil
        end
    end

    function api.setFovOverride(on)
        State.World.Fov = on
        local camera = Workspace.CurrentCamera
        if on then
            if camera and not saved.Fov then
                saved.Fov = camera.FieldOfView
            end
        else
            if camera and saved.Fov then
                camera.FieldOfView = saved.Fov
            end
            saved.Fov = nil
        end
    end

    function api.restoreAll()
        api.setFullbright(false)
        api.setNoFog(false)
        api.setTimeOverride(false)
        api.setFovOverride(false)
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
                    if not saved.Atmosphere[child] then
                        saved.Atmosphere[child] = { Density = child.Density, Haze = child.Haze }
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

    return api
end

--------------------------------------------------------------------------------
-- Module: UI kit (drag helpers, cards and controls)
--------------------------------------------------------------------------------

function Build.kit()
    local kit = {}
    local layoutCounters = {}

    local function isPointerDown(input)
        return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
    end

    -- Drag a target by a handle. A press without movement fires onTap.
    function kit.makeDraggable(handle, target, onTap)
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

    local function nextOrder(parent)
        layoutCounters[parent] = (layoutCounters[parent] or 0) + 1
        return layoutCounters[parent]
    end
    kit.nextOrder = nextOrder

    local function scrollerOf(parent)
        if parent:IsA("ScrollingFrame") then
            return parent
        end
        return parent:FindFirstAncestorOfClass("ScrollingFrame") or { ScrollingEnabled = true }
    end

    local function accentGradient(inst, rotation)
        create("UIGradient", {
            Rotation = rotation or 0,
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, T("Accent")),
                ColorSequenceKeypoint.new(1, T("Accent2")),
            }),
            Parent = inst,
        })
    end

    local function newRow(parent, height)
        return create("Frame", {
            Size = UDim2.new(1, 0, 0, height),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            LayoutOrder = nextOrder(parent),
            Parent = parent,
        })
    end

    -- Card: a soft glass panel that groups related controls.
    function kit.addCard(page, title)
        local card = create("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = T("Panel"),
            BackgroundTransparency = 0.38,
            BorderSizePixel = 0,
            LayoutOrder = nextOrder(page),
            Parent = page,
        }, {
            corner(14),
            stroke(WHITE, 1, 0.9),
            create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
            create("UIPadding", {
                PaddingTop = UDim.new(0, 10),
                PaddingBottom = UDim.new(0, 10),
                PaddingLeft = UDim.new(0, 12),
                PaddingRight = UDim.new(0, 12),
            }),
        })
        if title then
            local header = newRow(card, 20)
            local bar = create("Frame", {
                Position = UDim2.fromOffset(0, 4),
                Size = UDim2.fromOffset(4, 12),
                BackgroundColor3 = WHITE,
                BorderSizePixel = 0,
                Parent = header,
            }, { pill() })
            accentGradient(bar, 90)
            newLabel({
                Position = UDim2.fromOffset(12, 0),
                Size = UDim2.new(1, -12, 1, 0),
                Text = string.upper(title),
                Font = Enum.Font.GothamBold,
                TextSize = 11,
                TextColor3 = T("Accent2"),
                Parent = header,
            })
        end
        return card
    end

    function kit.addLabel(parent, text)
        return newLabel({
            Size = UDim2.new(1, 0, 0, 18),
            AutomaticSize = Enum.AutomaticSize.Y,
            Text = text,
            TextColor3 = T("SubText"),
            TextSize = 12,
            TextWrapped = true,
            LayoutOrder = nextOrder(parent),
            Parent = parent,
        })
    end

    function kit.addToggle(parent, text, default, callback)
        local row = newRow(parent, 34)
        newLabel({ Size = UDim2.new(1, -56, 1, 0), Text = text, Parent = row })
        local trackFrame = create("Frame", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
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
        local info = TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        local function render(animate)
            local trackColor = value and T("Accent") or T("Off")
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

    function kit.addSlider(parent, text, min, max, default, step, suffix, callback)
        local row = newRow(parent, 46)
        newLabel({ Size = UDim2.new(0.6, 0, 0, 20), Text = text, Parent = row })
        local valueLabel = newLabel({
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, 0, 0, 0),
            Size = UDim2.new(0.4, 0, 0, 20),
            Font = Enum.Font.GothamBold,
            TextColor3 = T("Accent2"),
            TextXAlignment = Enum.TextXAlignment.Right,
            Parent = row,
        })
        local rail = create("Frame", {
            Position = UDim2.new(0, 0, 0, 30),
            Size = UDim2.new(1, 0, 0, 5),
            BackgroundColor3 = T("Off"),
            BackgroundTransparency = 0.35,
            BorderSizePixel = 0,
            Parent = row,
        }, { pill() })
        local fill = create("Frame", {
            Size = UDim2.fromScale(0, 1),
            BackgroundColor3 = WHITE,
            BorderSizePixel = 0,
            Parent = rail,
        }, { pill() })
        accentGradient(fill, 0)
        local knob = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0, 0.5),
            Size = UDim2.fromOffset(14, 14),
            BackgroundColor3 = WHITE,
            BorderSizePixel = 0,
            ZIndex = 2,
            Parent = rail,
        }, { pill(), stroke(T("Accent2"), 2, 0) })
        local hit = create("TextButton", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(0, 18),
            Size = UDim2.new(1, 0, 0, 28),
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
        trackDrag(hit, scrollerOf(parent), function(pos)
            local alpha = math.clamp((pos.X - rail.AbsolutePosition.X) / math.max(rail.AbsoluteSize.X, 1), 0, 1)
            setValue(min + alpha * (max - min), true)
        end)
        setValue(default, false)
    end

    function kit.addColorPicker(parent, text, default, callback)
        local h, s, v = Color3.toHSV(default)
        local container = newRow(parent, 34)
        container.ClipsDescendants = true
        newLabel({ Size = UDim2.new(1, -50, 0, 34), Text = text, Parent = container })
        local swatch = create("Frame", {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, 0, 0, 7),
            Size = UDim2.fromOffset(34, 20),
            BackgroundColor3 = default,
            BorderSizePixel = 0,
            Parent = container,
        }, { corner(8), stroke(WHITE, 1, 0.75) })
        local headerHit = create("TextButton", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 34),
            Text = "",
            AutoButtonColor = false,
            Parent = container,
        })

        local svBox = create("Frame", {
            Position = UDim2.fromOffset(0, 40),
            Size = UDim2.new(1, -34, 0, 100),
            BackgroundColor3 = Color3.fromHSV(h, 1, 1),
            BorderSizePixel = 0,
            Parent = container,
        }, { corner(8) })
        create("Frame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
            Parent = svBox,
        }, {
            corner(8),
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
            corner(8),
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
        }, { pill(), stroke(Color3.new(0, 0, 0), 1.5, 0) })

        local hueBar = create("Frame", {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, 0, 0, 40),
            Size = UDim2.fromOffset(22, 100),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
            Parent = container,
        }, {
            corner(8),
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
        }, { corner(3), stroke(Color3.new(0, 0, 0), 1.5, 0) })

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

        local scroller = scrollerOf(parent)
        trackDrag(svBox, scroller, function(pos)
            s = math.clamp((pos.X - svBox.AbsolutePosition.X) / math.max(svBox.AbsoluteSize.X, 1), 0, 1)
            v = 1 - math.clamp((pos.Y - svBox.AbsolutePosition.Y) / math.max(svBox.AbsoluteSize.Y, 1), 0, 1)
            apply(true)
        end)
        trackDrag(hueBar, scroller, function(pos)
            h = math.clamp((pos.Y - hueBar.AbsolutePosition.Y) / math.max(hueBar.AbsoluteSize.Y, 1), 0, 0.999)
            apply(true)
        end)

        local expanded = false
        headerHit.MouseButton1Click:Connect(function()
            expanded = not expanded
            TweenService:Create(container, TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                Size = UDim2.new(1, 0, 0, expanded and 148 or 34),
            }):Play()
        end)
    end

    -- Header shared by all dropdown variants. Returns container, valueLabel, arrow, hit.
    local function dropdownHeader(parent, text, valueText)
        local container = newRow(parent, 34)
        container.ClipsDescendants = true
        newLabel({ Size = UDim2.new(0.5, 0, 0, 34), Text = text, Parent = container })
        local valueLabel = newLabel({
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -18, 0, 0),
            Size = UDim2.new(0.5, -18, 0, 34),
            TextColor3 = T("Accent2"),
            TextXAlignment = Enum.TextXAlignment.Right,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Text = valueText,
            Parent = container,
        })
        local arrow = newLabel({
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, 0, 0, 0),
            Size = UDim2.fromOffset(14, 34),
            Text = ">",
            Font = Enum.Font.GothamBold,
            TextColor3 = T("SubText"),
            TextXAlignment = Enum.TextXAlignment.Center,
            Parent = container,
        })
        local hit = create("TextButton", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 34),
            Text = "",
            AutoButtonColor = false,
            Parent = container,
        })
        return container, valueLabel, arrow, hit
    end

    local function expandTo(container, arrow, expanded, height)
        TweenService:Create(container, TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
            Size = UDim2.new(1, 0, 0, expanded and height or 34),
        }):Play()
        TweenService:Create(arrow, TweenInfo.new(0.2), { Rotation = expanded and 90 or 0 }):Play()
    end

    function kit.addDropdown(parent, text, options, default, callback)
        local rowHeight = 30
        local container, valueLabel, arrow, hit = dropdownHeader(parent, text, default)
        local selected = default
        local buttons = {}
        local function render()
            valueLabel.Text = selected
            for option, button in pairs(buttons) do
                local isSelected = option == selected
                button.BackgroundColor3 = isSelected and T("Accent") or T("Raised")
                button.BackgroundTransparency = isSelected and 0 or 0.5
            end
        end
        for index, option in ipairs(options) do
            buttons[option] = create("TextButton", {
                Position = UDim2.fromOffset(0, 38 + (index - 1) * rowHeight),
                Size = UDim2.new(1, 0, 0, rowHeight - 4),
                BorderSizePixel = 0,
                AutoButtonColor = false,
                Text = option,
                Font = Enum.Font.GothamMedium,
                TextSize = 13,
                TextColor3 = T("Text"),
                Parent = container,
            }, { corner(8) })
            buttons[option].MouseButton1Click:Connect(function()
                selected = option
                render()
                safeCall(callback, option)
            end)
        end
        render()

        local expanded = false
        hit.MouseButton1Click:Connect(function()
            expanded = not expanded
            expandTo(container, arrow, expanded, 38 + #options * rowHeight + 4)
        end)
    end

    function kit.addMultiDropdown(parent, text, options, selectedMap, callback)
        local rowHeight = 30
        local listTop = 72
        local container, valueLabel, arrow, hit = dropdownHeader(parent, text, "")
        local boxes = {}
        local function render()
            local count = 0
            for option, box in pairs(boxes) do
                local isOn = selectedMap[option] == true
                box.BackgroundColor3 = isOn and T("Accent") or T("Off")
                if isOn then
                    count += 1
                end
            end
            valueLabel.Text = count .. "/" .. #options
        end

        local function quickButton(label, xScale, xOffset, setAll)
            local button = create("TextButton", {
                Position = UDim2.new(xScale, xOffset, 0, 38),
                Size = UDim2.new(0.5, -4, 0, 28),
                BackgroundColor3 = T("Raised"),
                BackgroundTransparency = 0.4,
                BorderSizePixel = 0,
                AutoButtonColor = false,
                Text = label,
                Font = Enum.Font.GothamBold,
                TextSize = 12,
                TextColor3 = T("Text"),
                Parent = container,
            }, { corner(8) })
            button.MouseButton1Click:Connect(function()
                for _, option in ipairs(options) do
                    selectedMap[option] = setAll
                end
                render()
                safeCall(callback, selectedMap)
            end)
        end
        quickButton("Select all", 0, 0, true)
        quickButton("Clear", 0.5, 4, false)

        for index, option in ipairs(options) do
            local row = create("TextButton", {
                Position = UDim2.fromOffset(0, listTop + (index - 1) * rowHeight),
                Size = UDim2.new(1, 0, 0, rowHeight - 4),
                BackgroundColor3 = T("Raised"),
                BackgroundTransparency = 0.6,
                BorderSizePixel = 0,
                AutoButtonColor = false,
                Text = "",
                Parent = container,
            }, { corner(8) })
            boxes[option] = create("Frame", {
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 8, 0.5, 0),
                Size = UDim2.fromOffset(14, 14),
                BorderSizePixel = 0,
                Parent = row,
            }, { corner(5) })
            newLabel({ Position = UDim2.fromOffset(30, 0), Size = UDim2.new(1, -36, 1, 0), Text = option, Parent = row })
            row.MouseButton1Click:Connect(function()
                selectedMap[option] = not selectedMap[option]
                render()
                safeCall(callback, selectedMap)
            end)
        end
        render()

        local expanded = false
        hit.MouseButton1Click:Connect(function()
            expanded = not expanded
            expandTo(container, arrow, expanded, listTop + #options * rowHeight + 4)
        end)
    end

    local function pressEffect(button)
        local press = create("UIScale", { Scale = 1, Parent = button })
        button.MouseButton1Down:Connect(function()
            TweenService:Create(press, TweenInfo.new(0.08, Enum.EasingStyle.Quad), { Scale = 0.96 }):Play()
        end)
        local function release()
            TweenService:Create(press, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
        end
        button.MouseButton1Up:Connect(release)
        button.MouseLeave:Connect(release)
    end

    function kit.addButton(parent, text, callback, secondary)
        local button = create("TextButton", {
            Size = UDim2.new(1, 0, 0, 34),
            BackgroundColor3 = secondary and T("Raised") or WHITE,
            BackgroundTransparency = secondary and 0.4 or 0,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = text,
            Font = Enum.Font.GothamBold,
            TextSize = 13,
            TextColor3 = secondary and T("Text") or T("OnAccent"),
            LayoutOrder = nextOrder(parent),
            Parent = parent,
        }, { corner(10) })
        if not secondary then
            accentGradient(button, 0)
        end
        pressEffect(button)
        button.MouseButton1Click:Connect(function()
            safeCall(callback)
        end)
    end

    function kit.addTextBox(parent, placeholder)
        local row = newRow(parent, 36)
        return create("TextBox", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundColor3 = T("Raised"),
            BackgroundTransparency = 0.45,
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
        }, {
            corner(10),
            stroke(WHITE, 1, 0.88),
            create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
        })
    end

    -- List of teleport targets with a Refresh button. Rows are plain frames in the page,
    -- so there is no nested scrolling (that is what broke taps on phones before).
    function kit.addTargetList(parent, title, getEntries, onTeleport, onDelete, hint)
        local header = newRow(parent, 30)
        newLabel({ Size = UDim2.new(1, -92, 1, 0), Text = title, Font = Enum.Font.GothamBold, Parent = header })
        local refresh = create("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.fromOffset(84, 26),
            BackgroundColor3 = T("Raised"),
            BackgroundTransparency = 0.35,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = "Refresh",
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextColor3 = T("Text"),
            Parent = header,
        }, { corner(8) })
        pressEffect(refresh)

        local listFrame = create("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            LayoutOrder = nextOrder(parent),
            Parent = parent,
        }, { create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })

        local function clearRows()
            for _, child in ipairs(listFrame:GetChildren()) do
                if child:IsA("GuiObject") then
                    child:Destroy()
                end
            end
        end

        local function smallButton(row, text, rightOffset, width, primary)
            local button = create("TextButton", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, rightOffset, 0.5, 0),
                Size = UDim2.fromOffset(width, 24),
                BackgroundColor3 = primary and WHITE or T("Off"),
                BackgroundTransparency = primary and 0 or 0.3,
                BorderSizePixel = 0,
                AutoButtonColor = false,
                Text = text,
                Font = Enum.Font.GothamBold,
                TextSize = 12,
                TextColor3 = T("OnAccent"),
                Parent = row,
            }, { corner(8) })
            if primary then
                accentGradient(button, 0)
            end
            pressEffect(button)
            return button
        end

        local function rebuild()
            clearRows()
            local entries = getEntries()
            if #entries == 0 then
                newLabel({
                    Size = UDim2.new(1, 0, 0, 24),
                    Text = "nothing found",
                    TextColor3 = T("SubText"),
                    TextSize = 12,
                    Parent = listFrame,
                })
                return
            end
            for index, entry in ipairs(entries) do
                if index > 40 then
                    newLabel({
                        LayoutOrder = index,
                        Size = UDim2.new(1, 0, 0, 22),
                        Text = "+" .. (#entries - 40) .. " more not shown",
                        TextColor3 = T("SubText"),
                        TextSize = 12,
                        Parent = listFrame,
                    })
                    break
                end
                local row = create("Frame", {
                    LayoutOrder = index,
                    Size = UDim2.new(1, 0, 0, 32),
                    BackgroundColor3 = T("Raised"),
                    BackgroundTransparency = 0.6,
                    BorderSizePixel = 0,
                    Parent = listFrame,
                }, { corner(8) })
                local labelWidth = (entry.deletable and onDelete) and -120 or -78
                newLabel({
                    Position = UDim2.fromOffset(10, 0),
                    Size = UDim2.new(1, labelWidth, 1, 0),
                    Text = entry.label,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    Parent = row,
                })
                local go = smallButton(row, "TP", -6, 52, true)
                go.MouseButton1Click:Connect(function()
                    safeCall(onTeleport, entry)
                end)
                if entry.deletable and onDelete then
                    local delete = smallButton(row, "x", -64, 34, false)
                    delete.MouseButton1Click:Connect(function()
                        safeCall(onDelete, entry)
                    end)
                end
            end
        end

        refresh.MouseButton1Click:Connect(function()
            safeCall(rebuild)
        end)

        if hint then
            newLabel({
                Size = UDim2.new(1, 0, 0, 24),
                Text = hint,
                TextColor3 = T("SubText"),
                TextSize = 12,
                Parent = listFrame,
            })
        else
            safeCall(rebuild)
        end
        return { Refresh = rebuild }
    end

    return kit
end

--------------------------------------------------------------------------------
-- Module: hub window, tabs, minimized icon, cleanup
--------------------------------------------------------------------------------

function Build.hub()
    local Esp, Move, Flight, Econ = Mod.esp, Mod.move, Mod.flight, Mod.econ
    local Screen, Targets, World, Kit = Mod.screen, Mod.targets, Mod.world, Mod.kit
    local addCard, addLabel, addToggle, addSlider = Kit.addCard, Kit.addLabel, Kit.addToggle, Kit.addSlider
    local addColorPicker, addDropdown, addMultiDropdown = Kit.addColorPicker, Kit.addDropdown, Kit.addMultiDropdown
    local addButton, addTextBox, addTargetList = Kit.addButton, Kit.addTextBox, Kit.addTargetList
    local makeDraggable = Kit.makeDraggable
    local api = {}

    local HEADER_H = 46
    local TABBAR_H = 44
    local TAB_COUNT = 4
    local CONTENT_TOP = HEADER_H + TABBAR_H

    local function computeWindowSize()
        local screen = getScreenSize()
        return math.clamp(screen.X - 40, 320, 430), math.clamp(screen.Y - 40, 250, 390)
    end

    local normalW, normalH = computeWindowSize()
    local winW, winH = normalW, normalH
    local startScreen = getScreenSize()
    local startX = math.floor((startScreen.X - winW) / 2)
    local startY = math.floor((startScreen.Y - winH) / 2)
    local iconSize = Settings.IconSize

    -- Body: slightly see-through dark glass with a slowly turning purple outline.
    local window = create("CanvasGroup", {
        Name = "Window",
        Active = true,
        BackgroundColor3 = T("Background"),
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        GroupTransparency = 1,
        Position = UDim2.fromOffset(startX, startY + 14),
        Size = UDim2.fromOffset(winW, winH),
        Parent = screenGui,
    }, { corner(18), gradientStroke(2) })

    create("Frame", {
        Name = "Glow",
        Size = UDim2.new(1, 0, 0, 150),
        BackgroundColor3 = T("Accent"),
        BorderSizePixel = 0,
        Parent = window,
    }, {
        create("UIGradient", {
            Rotation = 90,
            Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.76), NumberSequenceKeypoint.new(1, 1) }),
        }),
    })

    ----------------------------------------------------------------------------
    -- Header: window dots, logo, title
    ----------------------------------------------------------------------------

    local header = create("Frame", {
        Name = "Header",
        Active = true,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, HEADER_H),
        Parent = window,
    })
    create("Frame", {
        Position = UDim2.new(0, 14, 1, -1),
        Size = UDim2.new(1, -28, 0, 1),
        BackgroundColor3 = WHITE,
        BackgroundTransparency = 0.92,
        BorderSizePixel = 0,
        Parent = header,
    })

    local function makeDot(color, xOffset)
        return create("TextButton", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, xOffset, 0.5, 0),
            Size = UDim2.fromOffset(15, 15),
            BackgroundColor3 = color,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = "",
            Parent = header,
        }, { pill() })
    end

    local closeDot = makeDot(Color3.fromRGB(255, 95, 87), 16)
    local minimizeDot = makeDot(Color3.fromRGB(254, 188, 46), 40)
    local zoomDot = makeDot(Color3.fromRGB(40, 200, 64), 64)

    -- Small crescent next to the title.
    local logo = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, -58, 0.5, 0),
        Size = UDim2.fromOffset(24, 24),
        BackgroundTransparency = 1,
        Parent = header,
    })
    create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.446, 0.5),
        Size = UDim2.fromScale(0.536, 0.536),
        BackgroundColor3 = T("Moon"),
        BorderSizePixel = 0,
        Parent = logo,
    }, { pill() })
    create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.607, 0.411),
        Size = UDim2.fromScale(0.464, 0.464),
        BackgroundColor3 = T("Background"),
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        ZIndex = 2,
        Parent = logo,
    }, { pill() })
    newLabel({
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 6, 0.5, 0),
        Size = UDim2.fromOffset(120, 20),
        Text = HUB_NAME,
        Font = Enum.Font.GothamBold,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = header,
    })
    local tag = create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(38, 20),
        BackgroundColor3 = T("Accent"),
        BackgroundTransparency = 0.45,
        BorderSizePixel = 0,
        Parent = header,
    }, { pill() })
    newLabel({
        Size = UDim2.fromScale(1, 1),
        Text = "YBA",
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Center,
        Parent = tag,
    })

    ----------------------------------------------------------------------------
    -- Tabs: a segmented bar with a sliding indicator
    ----------------------------------------------------------------------------

    local tabTrack = create("Frame", {
        Name = "TabBar",
        Position = UDim2.fromOffset(14, HEADER_H + 7),
        Size = UDim2.new(1, -28, 0, 32),
        BackgroundColor3 = T("Panel"),
        BackgroundTransparency = 0.45,
        BorderSizePixel = 0,
        Parent = window,
    }, { pill(), stroke(WHITE, 1, 0.92) })
    local indicator = create("Frame", {
        Size = UDim2.new(1 / TAB_COUNT, -6, 1, -6),
        Position = UDim2.new(0, 3, 0, 3),
        BackgroundColor3 = WHITE,
        BorderSizePixel = 0,
        ZIndex = 1,
        Parent = tabTrack,
    }, {
        pill(),
        create("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, T("Accent")),
                ColorSequenceKeypoint.new(1, T("Accent2")),
            }),
        }),
    })

    local content = create("Frame", {
        Name = "Content",
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        Position = UDim2.fromOffset(0, CONTENT_TOP),
        Size = UDim2.new(1, 0, 1, -CONTENT_TOP),
        Parent = window,
    })

    local Tabs = {}
    local activeTab = nil

    local function selectTab(name)
        if activeTab == name then
            return
        end
        activeTab = name
        for tabName, tab in pairs(Tabs) do
            local isSelected = tabName == name
            tab.page.Visible = isSelected
            TweenService:Create(tab.button, TweenInfo.new(0.18), {
                TextColor3 = isSelected and T("OnAccent") or T("SubText"),
            }):Play()
            if isSelected then
                tab.page.Position = UDim2.fromOffset(0, 14)
                TweenService:Create(tab.page, TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                    Position = UDim2.fromOffset(0, 0),
                }):Play()
                TweenService:Create(indicator, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                    Position = UDim2.new((tab.index - 1) / TAB_COUNT, 3, 0, 3),
                }):Play()
            end
        end
    end

    local function addTab(name, index)
        local button = create("TextButton", {
            Name = name,
            Position = UDim2.new((index - 1) / TAB_COUNT, 0, 0, 0),
            Size = UDim2.new(1 / TAB_COUNT, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = name,
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextColor3 = T("SubText"),
            ZIndex = 2,
            Parent = tabTrack,
        })
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
            ScrollBarImageColor3 = T("Accent2"),
            Parent = content,
        }, {
            create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
            create("UIPadding", {
                PaddingTop = UDim.new(0, 8),
                PaddingBottom = UDim.new(0, 14),
                PaddingLeft = UDim.new(0, 14),
                PaddingRight = UDim.new(0, 16),
            }),
        })
        Tabs[name] = { page = page, button = button, index = index }
        button.MouseButton1Click:Connect(function()
            selectTab(name)
        end)
        return page
    end

    ----------------------------------------------------------------------------
    -- Tab: Farming
    ----------------------------------------------------------------------------

    local farmingPage = addTab("Farming", 1)

    local farmCard = addCard(farmingPage, "Auto farm items")
    addToggle(farmCard, "Auto farm items", false, function(value)
        if value then
            Flight.startFarm()
        else
            Flight.stopFarm()
        end
    end)
    addSlider(farmCard, "Tween speed", 100, 2000, State.Farm.Speed, 10, " studs/s", function(value)
        State.Farm.Speed = value
    end)
    addToggle(farmCard, "Safe mode (humanized)", State.Farm.Humanize, function(value)
        State.Farm.Humanize = value
    end)
    addDropdown(farmCard, "Target priority", { "Distance", "Value" }, State.Farm.Priority, function(option)
        State.Farm.Priority = option
    end)
    addMultiDropdown(farmCard, "Items filter", FILTER_OPTIONS, State.Farm.Selected, function(selectedMap)
        State.Farm.Selected = selectedMap
    end)
    addButton(farmCard, "Fly to nearest item", Flight.flyToNearest)
    Flight.statusLabel = addLabel(farmCard, "Status: idle")

    local sellCard = addCard(farmingPage, "Auto sell")
    addToggle(sellCard, "Auto sell", false, function(value)
        State.Sell.Enabled = value
        if not value then
            Econ.setSellStatus("idle")
        end
    end)
    addMultiDropdown(sellCard, "Items to sell", ITEM_LABELS, State.Sell.Selected, function(selectedMap)
        State.Sell.Selected = selectedMap
    end)
    addToggle(sellCard, "Don't sell rare items", State.Sell.ProtectRare, function(value)
        State.Sell.ProtectRare = value
    end)
    addSlider(sellCard, "Sell every", 5, 120, State.Sell.Interval, 5, " s", function(value)
        State.Sell.Interval = value
    end)
    addButton(sellCard, "Sell now", function()
        task.spawn(Econ.runSellCycle)
    end, true)
    Econ.sellLabel = addLabel(sellCard, "Status: idle")
    addLabel(sellCard, "Rare items kept: Lucky Arrow, Lucky Stone Mask")

    local buyCard = addCard(farmingPage, "Auto buy")
    addToggle(buyCard, "Auto buy Lucky Arrows", false, function(value)
        State.Buy.Enabled = value
        if not value then
            Econ.setBuyStatus("idle")
        end
    end)
    addSlider(buyCard, "Hold up to", 1, 25, State.Buy.Target, 1, " arrows", function(value)
        State.Buy.Target = value
    end)
    Econ.buyLabel = addLabel(buyCard, "Status: idle")
    addLabel(buyCard, "Price: $75,000 each")

    local utilsCard = addCard(farmingPage, "Utilities")
    addToggle(utilsCard, "Anti AFK", State.Utils.AntiAfk, function(value)
        State.Utils.AntiAfk = value
    end)
    addToggle(utilsCard, "Auto press Play after rejoin", State.Utils.AutoPlay, function(value)
        State.Utils.AutoPlay = value
    end)
    Screen.toggle = addToggle(utilsCard, "Farm screen", false, function(value)
        Screen.set(value)
        if value then
            safeCall(Screen.update)
        end
    end)

    ----------------------------------------------------------------------------
    -- Tab: Visuals
    ----------------------------------------------------------------------------

    local visualsPage = addTab("Visuals", 2)

    local itemEspCard = addCard(visualsPage, "Items ESP")
    addToggle(itemEspCard, "Show items", false, function(value)
        State.ItemESP.Enabled = value
        if value then
            task.spawn(safeCall, Esp.refreshItems)
        else
            Esp.clearItems()
        end
    end)
    addSlider(itemEspCard, "Range", 500, 5000, State.ItemESP.Range, 50, " studs", function(value)
        State.ItemESP.Range = value
    end)
    addColorPicker(itemEspCard, "Items color", State.ItemESP.Color, function(color)
        State.ItemESP.Color = color
    end)

    local playerEspCard = addCard(visualsPage, "Players ESP")
    addToggle(playerEspCard, "Show players", false, function(value)
        State.PlayerESP.Enabled = value
        if not value then
            Esp.clearPlayers()
        end
    end)
    addMultiDropdown(
        playerEspCard,
        "Display",
        { "Name", "Distance", "Health", "Stand", "Spec", "Level" },
        State.PlayerESP.Fields,
        function(selectedMap)
            State.PlayerESP.Fields = selectedMap
        end
    )
    addSlider(playerEspCard, "Range", 500, 5000, State.PlayerESP.Range, 50, " studs", function(value)
        State.PlayerESP.Range = value
    end)
    addToggle(playerEspCard, "Tracers", false, function(value)
        State.PlayerESP.Tracers = value
        if not value then
            Esp.clearTracers()
        end
    end)
    addColorPicker(playerEspCard, "Players color", State.PlayerESP.Color, function(color)
        State.PlayerESP.Color = color
    end)

    local worldCard = addCard(visualsPage, "World")
    addToggle(worldCard, "Fullbright", false, World.setFullbright)
    addToggle(worldCard, "No fog", false, World.setNoFog)
    addToggle(worldCard, "Override time of day", false, World.setTimeOverride)
    addSlider(worldCard, "Time of day", 0, 24, State.World.TimeValue, 0.5, " h", function(value)
        State.World.TimeValue = value
    end)
    addToggle(worldCard, "Override FOV", false, World.setFovOverride)
    addSlider(worldCard, "FOV", 40, 120, State.World.FovValue, 1, "", function(value)
        State.World.FovValue = value
    end)

    ----------------------------------------------------------------------------
    -- Tab: Player
    ----------------------------------------------------------------------------

    local playerPage = addTab("Player", 3)

    local moveCard = addCard(playerPage, "Movement")
    addToggle(moveCard, "Walk speed", false, Move.setWalk)
    addSlider(moveCard, "Speed", 16, 150, State.Walk.Speed, 1, "", function(value)
        State.Walk.Speed = value
    end)
    addToggle(moveCard, "Fly", false, Move.setFly)
    addSlider(moveCard, "Fly speed", 10, 300, State.Fly.Speed, 5, " studs/s", function(value)
        State.Fly.Speed = value
    end)
    addToggle(moveCard, "Noclip", false, Move.setNoclip)
    addLabel(moveCard, "Fly: move stick or WASD, look up/down to climb, Space/Ctrl on PC")

    local tpCard = addCard(playerPage, "Teleports")
    Flight.tpLabel = addLabel(tpCard, "Status: idle")
    addLabel(tpCard, "Teleports are instant. The anticheat can rubber-band them back.")

    local playersCard = addCard(playerPage, nil)
    local playersList
    playersList = addTargetList(playersCard, "Players on the server", function()
        local entries = {}
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local label = player.DisplayName
                if player.DisplayName ~= player.Name then
                    label = label .. " (@" .. player.Name .. ")"
                end
                table.insert(entries, { label = label, name = player.Name })
            end
        end
        table.sort(entries, function(a, b)
            return string.lower(a.label) < string.lower(b.label)
        end)
        return entries
    end, function(entry)
        local target = Players:FindFirstChild(entry.name)
        local char = target and target.Character
        local targetRoot = char and char:FindFirstChild("HumanoidRootPart")
        if not targetRoot then
            Flight.setTpStatus(entry.label .. " has no character yet")
            return
        end
        local position = (targetRoot.CFrame * CFrame.new(0, 0, 4)).Position + Vector3.new(0, 1, 0)
        Flight.teleportInstant(position, entry.label)
    end)
    track(Players.PlayerAdded:Connect(function()
        task.defer(safeCall, playersList.Refresh)
    end))
    track(Players.PlayerRemoving:Connect(function()
        task.defer(safeCall, playersList.Refresh)
    end))

    local npcCard = addCard(playerPage, nil)
    addTargetList(npcCard, "NPCs", function()
        local entries = {}
        for _, name in ipairs(Targets.listNpcs()) do
            table.insert(entries, { label = name, name = name })
        end
        return entries
    end, function(entry)
        local model = Targets.npcModel(entry.name)
        local position = model and model.Parent and Targets.frontPosition(model)
        if position then
            Flight.teleportInstant(position, entry.label)
        else
            Flight.setTpStatus(entry.label .. " is not available")
        end
    end, nil, "Tap Refresh to scan for NPCs")

    local placesCard = addCard(playerPage, nil)
    local placesList
    placesList = addTargetList(placesCard, "Places", function()
        local entries = {}
        local saved = {}
        for _, place in ipairs(Settings.Places) do
            saved[place.name] = true
        end
        for _, name in ipairs(Targets.listPlaces()) do
            table.insert(entries, { label = name, name = name, deletable = saved[name] == true })
        end
        return entries
    end, function(entry)
        local position = Targets.placePosition(entry.name)
        if position then
            Flight.teleportInstant(position, entry.label)
        else
            Flight.setTpStatus("pick a place first")
        end
    end, function(entry)
        for index = #Settings.Places, 1, -1 do
            if Settings.Places[index].name == entry.name then
                table.remove(Settings.Places, index)
            end
        end
        saveSettings()
        Flight.setTpStatus("deleted " .. entry.label)
        placesList.Refresh()
    end, "Tap Refresh to list places")
    local placeNameBox = addTextBox(placesCard, "New place name")
    addButton(placesCard, "Save current position", function()
        local root = getRoot()
        if not root then
            Flight.setTpStatus("waiting for character")
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
        Flight.setTpStatus("saved place " .. name)
        placesList.Refresh()
    end, true)

    ----------------------------------------------------------------------------
    -- Minimized icon
    ----------------------------------------------------------------------------

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
    }, { corner(16), gradientStroke(2), iconScale })

    -- Crescent: a disc with a background-colored disc cut out of it (scale based, follows the icon size).
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

    makeDraggable(header, window)
    makeDraggable(icon, icon, restoreWindow)

    minimizeDot.MouseButton1Click:Connect(minimizeWindow)
    zoomDot.MouseButton1Click:Connect(toggleZoom)

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

    ----------------------------------------------------------------------------
    -- Tab: Settings
    ----------------------------------------------------------------------------

    local settingsPage = addTab("Settings", 4)

    local interfaceCard = addCard(settingsPage, "Interface")
    addSlider(interfaceCard, "Mini icon size", 40, 96, iconSize, 2, " px", function(value)
        iconSize = value
        Settings.IconSize = value
        if icon.Visible then
            local x, y = clampPosition(icon.Position.X.Offset, icon.Position.Y.Offset, value, value)
            icon.Position = UDim2.fromOffset(x, y)
            icon.Size = UDim2.fromOffset(value, value)
        end
        saveSettings()
    end)
    addToggle(interfaceCard, "Show FPS", Settings.ShowFps, function(value)
        Settings.ShowFps = value
        Screen.setFpsVisible(value)
        saveSettings()
    end)

    local aboutCard = addCard(settingsPage, "About")
    addLabel(aboutCard, "RightShift or the yellow dot minimizes the window. Drag the header to move it.")

    selectTab("Farming")

    ----------------------------------------------------------------------------
    -- Cleanup
    ----------------------------------------------------------------------------

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
        Flight.cancelAll()
        Move.reset()
        World.restoreAll()
        Screen.set(false)
        Esp.clearItems()
        Esp.clearPlayers()
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
        if env.MoonlightHub and env.MoonlightHub.Destroy == api.Destroy then
            env.MoonlightHub = nil
        end
    end
    api.Destroy = destroyHub

    closeDot.MouseButton1Click:Connect(function()
        TweenService:Create(window, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { GroupTransparency = 1 }):Play()
        task.delay(0.2, destroyHub)
    end)

    -- Intro: the window fades in and slides up once the loading screen is leaving.
    function api.Show()
        TweenService:Create(window, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
            GroupTransparency = 0,
            Position = UDim2.fromOffset(startX, startY),
        }):Play()
    end

    return api
end

--------------------------------------------------------------------------------
-- Boot
--------------------------------------------------------------------------------

local function emergencyCleanup()
    alive = false
    for _, connection in ipairs(Connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    for _, gui in ipairs({ screenGui, farmGui, tracerGui, espFolder }) do
        if gui then
            pcall(function()
                gui:Destroy()
            end)
        end
    end
    pcall(function()
        RunService:Set3dRenderingEnabled(true)
    end)
end

local function boot()
    Loader.Step(0.04, "Preparing interface")
    screenGui = newScreenGui(HUB_NAME, 50, true)
    farmGui = newScreenGui(HUB_NAME .. "_FarmScreen", 40, false)
    tracerGui = newScreenGui(HUB_NAME .. "_Tracers", 10, true)
    espFolder = create("Folder", { Name = HUB_NAME .. "_ESP" })
    if not (mount(screenGui) and mount(farmGui) and mount(tracerGui) and mount(espFolder)) then
        error("no writable UI container found", 0)
    end
    task.wait(0.45)

    local order = {
        { "esp", "Loading ESP engine" },
        { "move", "Loading movement" },
        { "flight", "Loading flight system" },
        { "econ", "Loading automation" },
        { "screen", "Loading farm screen" },
        { "targets", "Loading teleports" },
        { "world", "Loading world effects" },
        { "kit", "Loading interface kit" },
        { "hub", "Building window" },
    }
    for index, entry in ipairs(order) do
        Loader.Step(0.08 + 0.87 * (index - 1) / #order, entry[2])
        local ok, result = pcall(Build[entry[1]])
        if not ok then
            error(entry[1] .. ": " .. tostring(result), 0)
        end
        Mod[entry[1]] = result
        task.wait(0.22)
    end

    env.MoonlightHub = { Destroy = Mod.hub.Destroy }
end

local booted, bootError = pcall(boot)
if booted then
    task.spawn(Loader.Finish)
    task.delay(0.55, Mod.hub.Show)
else
    warn("[" .. HUB_NAME .. "] failed to start: " .. tostring(bootError))
    emergencyCleanup()
    Loader.Fail(bootError)
end