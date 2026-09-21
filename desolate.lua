-- Desolate Client v4.2.7
-- Optimized + Visual category + Draw FOV (circle only) + Watermark in HUD

local VERSION = "4.2.7"

local AUTH_URL  = "https://desolate-auth.desolate-ezi.workers.dev"
local KEY_FILE  = "desolate_key.txt"
local HWID_FILE = "desolate_hwid.txt"
local CONFIG_FILE = "desolate_config.json"

local Players          = game:GetService("Players")
local HttpService      = game:GetService("HttpService")
local TweenService     = game:GetService("TweenService")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting         = game:GetService("Lighting")
local Workspace        = game:GetService("Workspace")
local VirtualUser      = game:GetService("VirtualUser")
local TeleportService  = game:GetService("TeleportService")
local Camera           = Workspace.CurrentCamera

local player = Players.LocalPlayer

-- =========================================================
-- CACHE
-- =========================================================
local CACHE = {
    character = nil, hrp = nil, humanoid = nil, head = nil, isAlive = false,
}
local function refreshCharacterCache()
    local char = player.Character
    if not char then
        CACHE.character, CACHE.hrp, CACHE.humanoid, CACHE.head, CACHE.isAlive = nil, nil, nil, nil, false
        return
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local head = char:FindFirstChild("Head")
    CACHE.character = char
    CACHE.humanoid = hum
    CACHE.hrp = hrp
    CACHE.head = head
    CACHE.isAlive = (hum ~= nil) and (hrp ~= nil) and (hum.Health > 0)
end
refreshCharacterCache()
player.CharacterAdded:Connect(function() task.wait(0.1); refreshCharacterCache() end)
player.CharacterRemoving:Connect(function()
    CACHE.character, CACHE.hrp, CACHE.humanoid, CACHE.head, CACHE.isAlive = nil, nil, nil, nil, false
end)

-- =========================================================
-- HWID
-- =========================================================
local function getHwid()
    if gethwid then
        local ok, id = pcall(gethwid)
        if ok and id and tostring(id) ~= "" then return tostring(id) end
    end
    if type(isfile) == "function" and type(readfile) == "function"
       and isfile(HWID_FILE) then
        local ok, cached = pcall(readfile, HWID_FILE)
        if ok and cached and #cached > 0 then return cached end
    end
    local random = tostring(math.random(1, 1e15)) .. tostring(os.time())
    local h = 0
    for i = 1, #random do h = (h * 31 + random:byte(i)) % (2 ^ 32) end
    local id = string.format("fallback_%08x_%08x", h, os.time() % 2 ^ 32)
    if type(writefile) == "function" then pcall(writefile, HWID_FILE, id) end
    return id
end

-- =========================================================
-- FS
-- =========================================================
local fs = {
    available = (type(writefile) == "function")
        and (type(readfile) == "function")
        and (type(isfile) == "function")
        and (type(delfile) == "function"),
}
function fs.read(path)
    if not fs.available then return nil end
    local ok, exists = pcall(isfile, path)
    if not ok or not exists then return nil end
    local ok2, data = pcall(readfile, path)
    if ok2 and type(data) == "string" then return (data:gsub("%s+$", "")) end
    return nil
end
function fs.write(path, data)
    if not fs.available then return false end
    return pcall(writefile, path, data)
end
function fs.delete(path)
    if not fs.available then return false end
    return pcall(delfile, path)
end

-- =========================================================
-- HTTP
-- =========================================================
local function httpPost(url, body)
    local payload = HttpService:JSONEncode(body)
    if request then
        local ok, res = pcall(function()
            return request({ Url = url, Method = "POST",
                Headers = { ["Content-Type"] = "application/json" }, Body = payload })
        end)
        if ok and res and res.Body then return res.Body end
    end
    local ok, res = pcall(function()
        return game:HttpGet(url .. "?" .. HttpService:UrlEncode(payload))
    end)
    if ok then return res end
    return nil
end

local function validateKey(key)
    local body = { userid = tostring(player.UserId), hwid = getHwid(), key = key }
    local response = httpPost(AUTH_URL, body)
    if not response then return false, "Server offline." end
    local ok, data = pcall(function() return HttpService:JSONDecode(response) end)
    if not ok or type(data) ~= "table" then return false, "Bad response." end
    if not data.valid then
        local reasons = {
            invalid_key = "Invalid key", expired = "Key expired",
            banned = "Key banned",
            hwid_mismatch = "Key bound to another device",
            userid_mismatch = "Key bound to another account",
        }
        return false, reasons[data.reason] or ("Denied: " .. tostring(data.reason))
    end
    return true, data
end

-- =========================================================
-- AUTH UI
-- =========================================================
local function showKeyUI(opts)
    local ACCENT = Color3.fromRGB(0, 200, 230)
    local BG, BG2 = Color3.fromRGB(6, 6, 10), Color3.fromRGB(14, 14, 20)
    local TEXT, MUTED = Color3.fromRGB(200, 200, 210), Color3.fromRGB(100, 100, 115)
    local ERROR, OK = Color3.fromRGB(255, 60, 60), Color3.fromRGB(60, 255, 130)
    local FONT = Enum.Font.Code
    local sg = Instance.new("ScreenGui")
    sg.Name = "DesolateAuth_" .. math.random(1, 1e6)
    sg.ResetOnSpawn = false; sg.IgnoreGuiInset = true; sg.DisplayOrder = 1000
    if gethui then local ok, h = pcall(gethui); if ok and h then sg.Parent = h end end
    if not sg.Parent then
        local ok = pcall(function() sg.Parent = game:GetService("CoreGui") end)
        if not ok or not sg.Parent then sg.Parent = player:WaitForChild("PlayerGui") end
    end
    local box = Instance.new("Frame")
    box.Size = UDim2.new(0, 400, 0, 220)
    box.Position = UDim2.new(0.5, -200, 0.5, -110)
    box.BackgroundColor3 = BG; box.BorderSizePixel = 0; box.Parent = sg
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 12)
    local st = Instance.new("UIStroke"); st.Color = ACCENT; st.Thickness = 1
    st.Transparency = 0.5; st.Parent = box
    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1; title.Position = UDim2.new(0, 14, 0, 12)
    title.Size = UDim2.new(1, -28, 0, 22); title.Font = FONT; title.TextSize = 16
    title.TextColor3 = ACCENT; title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = "Desolate - Activation"; title.Parent = box
    local inputHolder = Instance.new("Frame")
    inputHolder.Position = UDim2.new(0, 14, 0, 58)
    inputHolder.Size = UDim2.new(1, -28, 0, 40)
    inputHolder.BackgroundColor3 = BG2; inputHolder.BorderSizePixel = 0
    inputHolder.Parent = box
    Instance.new("UICorner", inputHolder).CornerRadius = UDim.new(0, 8)
    local textBox = Instance.new("TextBox")
    textBox.Size = UDim2.new(1, -20, 1, 0); textBox.Position = UDim2.new(0, 10, 0, 0)
    textBox.BackgroundTransparency = 1; textBox.Font = FONT; textBox.TextSize = 14
    textBox.TextColor3 = TEXT; textBox.PlaceholderText = "DESO-XXXX-XXXX-XXXX"
    textBox.PlaceholderColor3 = MUTED
    textBox.TextXAlignment = Enum.TextXAlignment.Left; textBox.ClearTextOnFocus = false
    textBox.Text = opts.initial or ""; textBox.Parent = inputHolder
    local status = Instance.new("TextLabel")
    status.BackgroundTransparency = 1; status.Position = UDim2.new(0, 14, 0, 108)
    status.Size = UDim2.new(1, -28, 0, 18); status.Font = FONT; status.TextSize = 12
    status.TextColor3 = MUTED; status.TextXAlignment = Enum.TextXAlignment.Left
    status.Parent = box
    local activate = Instance.new("TextButton")
    activate.Size = UDim2.new(1, -28, 0, 36); activate.Position = UDim2.new(0, 14, 1, -50)
    activate.BackgroundColor3 = ACCENT; activate.TextColor3 = Color3.fromRGB(6, 6, 10)
    activate.Font = FONT; activate.TextSize = 14; activate.Text = "ACTIVATE"
    activate.BorderSizePixel = 0; activate.AutoButtonColor = false; activate.Parent = box
    Instance.new("UICorner", activate).CornerRadius = UDim.new(0, 8)
    local function tryActivate()
        local key = textBox.Text:gsub("%s+", "")
        if #key < 6 then status.TextColor3 = ERROR; status.Text = "Key too short"; return end
        activate.Text = "CHECKING..."; activate.Active = false
        task.spawn(function()
            local ok, info = validateKey(key)
            if ok then
                status.TextColor3 = OK; status.Text = "Activation success"
                fs.write(KEY_FILE, key); task.wait(0.5); sg:Destroy()
                if opts.onSuccess then opts.onSuccess(info) end
            else
                status.TextColor3 = ERROR; status.Text = tostring(info)
                activate.Text = "ACTIVATE"; activate.Active = true
            end
        end)
    end
    activate.MouseButton1Click:Connect(tryActivate)
    textBox.FocusLost:Connect(function(e) if e then tryActivate() end end)
end

local authData = { plan = "lifetime", expires = nil }
local function requireAuth()
    local savedKey = fs.read(KEY_FILE)
    if savedKey and #savedKey >= 6 then
        local ok, info = validateKey(savedKey)
        if ok then
            authData.plan = info.plan or "lifetime"; authData.expires = info.expires
            return true
        end
        fs.delete(KEY_FILE)
    end
    local completed, success = false, false
    showKeyUI({
        initial = savedKey or "",
        onSuccess = function(info)
            authData.plan = info.plan or "lifetime"; authData.expires = info.expires
            completed, success = true, true
        end,
    })
    while not completed do task.wait(0.1) end
    return success
end
if not requireAuth() then return end

-- =========================================================
-- THEMES
-- =========================================================
local THEMES = {
    Dark    = { accent = Color3.fromRGB(0, 200, 230), bg = Color3.fromRGB(6, 6, 10),   bg2 = Color3.fromRGB(10, 10, 14),  bg3 = Color3.fromRGB(14, 14, 20),  bg4 = Color3.fromRGB(20, 20, 28),  text = Color3.fromRGB(200, 200, 210), muted = Color3.fromRGB(100, 100, 115) },
    Blood   = { accent = Color3.fromRGB(255, 40, 40), bg = Color3.fromRGB(12, 4, 4),    bg2 = Color3.fromRGB(20, 8, 8),    bg3 = Color3.fromRGB(28, 12, 12),  bg4 = Color3.fromRGB(40, 18, 18),  text = Color3.fromRGB(230, 200, 200), muted = Color3.fromRGB(140, 100, 100) },
    Ocean   = { accent = Color3.fromRGB(60, 180, 255),bg = Color3.fromRGB(4, 8, 14),    bg2 = Color3.fromRGB(8, 14, 22),   bg3 = Color3.fromRGB(14, 22, 32),  bg4 = Color3.fromRGB(20, 30, 44),  text = Color3.fromRGB(200, 220, 240), muted = Color3.fromRGB(100, 120, 140) },
    Purple  = { accent = Color3.fromRGB(180, 80, 255),bg = Color3.fromRGB(10, 4, 16),   bg2 = Color3.fromRGB(16, 8, 24),   bg3 = Color3.fromRGB(22, 12, 32),  bg4 = Color3.fromRGB(32, 18, 44),  text = Color3.fromRGB(220, 200, 240), muted = Color3.fromRGB(120, 100, 140) },
    Pink    = { accent = Color3.fromRGB(255, 100, 200),bg = Color3.fromRGB(14, 4, 12),  bg2 = Color3.fromRGB(22, 8, 18),   bg3 = Color3.fromRGB(30, 12, 24),  bg4 = Color3.fromRGB(42, 18, 34),  text = Color3.fromRGB(240, 200, 220), muted = Color3.fromRGB(140, 100, 120) },
    Matrix  = { accent = Color3.fromRGB(50, 255, 100),bg = Color3.fromRGB(2, 8, 4),     bg2 = Color3.fromRGB(4, 12, 6),    bg3 = Color3.fromRGB(6, 18, 10),   bg4 = Color3.fromRGB(10, 26, 14),  text = Color3.fromRGB(200, 255, 210), muted = Color3.fromRGB(100, 140, 110) },
    Light   = { accent = Color3.fromRGB(0, 150, 200), bg = Color3.fromRGB(230, 230, 235),bg2 = Color3.fromRGB(215, 215, 220),bg3 = Color3.fromRGB(200, 200, 210),bg4 = Color3.fromRGB(180, 180, 195),text = Color3.fromRGB(20, 20, 30),  muted = Color3.fromRGB(100, 100, 115) },
}

local ACCENT = THEMES.Dark.accent
local BG  = THEMES.Dark.bg
local BG2 = THEMES.Dark.bg2
local BG3 = THEMES.Dark.bg3
local BG4 = THEMES.Dark.bg4
local TEXT = THEMES.Dark.text
local MUTED = THEMES.Dark.muted
local ERROR = Color3.fromRGB(255, 60, 60)
local OK = Color3.fromRGB(60, 255, 130)
local SYNC_COLOR = Color3.fromRGB(50, 255, 100)
local FONT = Enum.Font.Code
local OPEN_KEY = Enum.KeyCode.RightShift
local currentTheme = "Dark"

-- =========================================================
-- STATE
-- =========================================================
local state = {
    Visual = {
        { name = "Visuals",          isHeader = true },
        { name = "Fullbright",   enabled = false, actions = {} },
        { name = "Custom Sky",   enabled = false, actions = {},
          slider = { min = 0, max = 24, value = 12 } },
        { name = "Sky Preset",   enabled = false, actions = {},
          slider = { min = 1, max = 5, value = 4 } },
        { name = "Fog",          enabled = false, actions = {},
          slider = { min = 0, max = 500, value = 100 } },
        { name = "Time Changer", enabled = false, actions = {},
          slider = { min = 0, max = 24, value = 12 } },

        { name = "Player Info",      isHeader = true },
        { name = "Show Desolate Users", enabled = false, actions = {} },
        { name = "NameTags",     enabled = false, actions = {} },
        { name = "ESP",          enabled = false, actions = {} },

        { name = "Effects",          isHeader = true },
        { name = "JumpCircle",   enabled = false, actions = {} },
        { name = "Trails",       enabled = false, actions = {} },
        { name = "Particles",    enabled = false, actions = {},
          sliders = {
            { label = "Rate",  min = 1, max = 50, value = 12 },
            { label = "Speed", min = 5, max = 50, value = 18 },
            { label = "Size",  min = 1, max = 10, value = 3 },
          } },
        { name = "China Hat",    enabled = false, actions = {},
          sliders = {
            { label = "Distance", min = 0.5, max = 5,   value = 1.6 },
            { label = "Neon",     min = 0,   max = 100, value = 100 },
            { label = "Light",    min = 0,   max = 10,  value = 4 },
          } },
        { name = "Damage Ind",   enabled = false, actions = {} },

        { name = "Overlay",          isHeader = true },
        { name = "Draw FOV",     enabled = false, actions = {},
          slider = { min = 1, max = 30, value = 15 } },
    },
    HUD = {
        { name = "Info",          isHeader = true },
        { name = "Watermark",    enabled = true,  actions = {} },

        { name = "Overlay",       isHeader = true },
        { name = "Coordinates", enabled = false, actions = {} },
        { name = "TargetHUD",   enabled = false, actions = {} },
        { name = "Crosshair",   enabled = false, actions = {} },
    },
    Misc = {
        { name = "Utility",       isHeader = true },
        { name = "AntiAFK",       enabled = false, actions = {} },
        { name = "Noclip",        enabled = false, actions = {} },
        { name = "AutoClicker",   enabled = false, actions = {},
          slider = { min = 1, max = 20, value = 8 } },
        { name = "ServerHop",     enabled = false, actions = {} },
        { name = "Reset HUD Pos", enabled = false, actions = {} },
    },
    Player = {
        { name = "Movement",      isHeader = true },
        { name = "WalkSpeed", enabled = false, actions = {},
          slider = { min = 8, max = 200, value = 16 } },
        { name = "JumpPower", enabled = false, actions = {},
          slider = { min = 30, max = 300, value = 50 } },
        { name = "Fly",       enabled = false, actions = {},
          slider = { min = 10, max = 200, value = 60 } },
        { name = "BunnyHop",  enabled = false, actions = {} },

        { name = "Combat",        isHeader = true },
        { name = "Reach",     enabled = false, actions = {},
          slider = { min = 5, max = 50, value = 10 } },
        { name = "Kill Effect", enabled = false, actions = {} },

        { name = "Camera",        isHeader = true },
        { name = "FOV",       enabled = false, actions = {},
          slider = { min = 40, max = 140, value = 70 } },
    },
}

local function findMod(cat, name)
    for _, m in ipairs(state[cat] or {}) do
        if m.name == name then return m end
    end
    return nil
end

-- =========================================================
-- MOD CACHE
-- =========================================================
local MOD = {}
local function cacheModuleRefs()
    MOD.fullbright  = findMod("Visual", "Fullbright")
    MOD.customSky   = findMod("Visual", "Custom Sky")
    MOD.skyPreset   = findMod("Visual", "Sky Preset")
    MOD.fog         = findMod("Visual", "Fog")
    MOD.timeChanger = findMod("Visual", "Time Changer")
    MOD.showUsers   = findMod("Visual", "Show Desolate Users")
    MOD.nameTags    = findMod("Visual", "NameTags")
    MOD.esp         = findMod("Visual", "ESP")
    MOD.jumpCircle  = findMod("Visual", "JumpCircle")
    MOD.trails      = findMod("Visual", "Trails")
    MOD.particles   = findMod("Visual", "Particles")
    MOD.chinaHat    = findMod("Visual", "China Hat")
    MOD.damageInd   = findMod("Visual", "Damage Ind")
    MOD.drawFov     = findMod("Visual", "Draw FOV")
    MOD.watermark   = findMod("HUD", "Watermark")
    MOD.coords      = findMod("HUD", "Coordinates")
    MOD.targetHUD   = findMod("HUD", "TargetHUD")
    MOD.crosshair   = findMod("HUD", "Crosshair")
    MOD.antiAFK     = findMod("Misc", "AntiAFK")
    MOD.noclip      = findMod("Misc", "Noclip")
    MOD.autoClicker = findMod("Misc", "AutoClicker")
    MOD.serverHop   = findMod("Misc", "ServerHop")
    MOD.resetHUDPos = findMod("Misc", "Reset HUD Pos")
    MOD.walkSpeed   = findMod("Player", "WalkSpeed")
    MOD.jumpPower   = findMod("Player", "JumpPower")
    MOD.fly         = findMod("Player", "Fly")
    MOD.bunnyHop    = findMod("Player", "BunnyHop")
    MOD.reach       = findMod("Player", "Reach")
    MOD.fov         = findMod("Player", "FOV")
end

-- =========================================================
-- SYNC
-- =========================================================
local syncSet = {}

local function syncPing()
    task.spawn(function()
        while gui and gui.Parent do
            if MOD.showUsers and MOD.showUsers.enabled then
                pcall(function()
                    httpPost(AUTH_URL .. "/sync", {
                        action = "ping",
                        userid = tostring(player.UserId),
                        jobId = tostring(game.JobId),
                    })
                end)
            end
            task.wait(25)
        end
    end)
end

local function syncFetch()
    task.spawn(function()
        while gui and gui.Parent do
            if MOD.showUsers and MOD.showUsers.enabled then
                local body = httpPost(AUTH_URL .. "/sync", {
                    action = "list",
                    jobId = tostring(game.JobId),
                })
                if body then
                    local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
                    if ok and data and data.users then
                        local newSet = {}
                        for _, id in ipairs(data.users) do newSet[tostring(id)] = true end
                        syncSet = newSet
                    end
                end
            else
                syncSet = {}
            end
            task.wait(20)
        end
    end)
end

local function isSyncUser(plr)
    return syncSet[tostring(plr.UserId)] == true
end

-- =========================================================
-- CONFIG
-- =========================================================
local function saveConfig()
    local data = { version = VERSION, theme = currentTheme, modules = {} }
    for cat, list in pairs(state) do
        data.modules[cat] = {}
        for _, mod in ipairs(list) do
            if not mod.isHeader then
                local entry = { enabled = mod.enabled }
                if mod.slider then entry.slider = mod.slider.value end
                if mod.sliders then
                    entry.sliders = {}
                    for i, s in ipairs(mod.sliders) do entry.sliders[i] = s.value end
                end
                data.modules[cat][mod.name] = entry
            end
        end
    end
    return fs.write(CONFIG_FILE, HttpService:JSONEncode(data))
end

local function loadConfig()
    local raw = fs.read(CONFIG_FILE)
    if not raw then return false end
    local ok, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok or type(data) ~= "table" or not data.modules then return false end
    if data.theme and THEMES[data.theme] then currentTheme = data.theme end
    for cat, list in pairs(state) do
        if data.modules[cat] then
            for _, mod in ipairs(list) do
                if not mod.isHeader then
                    local saved = data.modules[cat][mod.name]
                    if saved then
                        if saved.enabled ~= nil then mod.enabled = saved.enabled end
                        if saved.slider and mod.slider then mod.slider.value = saved.slider end
                        if saved.sliders and mod.sliders then
                            for i, v in ipairs(saved.sliders) do
                                if mod.sliders[i] then mod.sliders[i].value = v end
                            end
                        end
                    end
                end
            end
        end
    end
    return true
end

local function resetConfig()
    fs.delete(CONFIG_FILE)
    for cat, list in pairs(state) do
        for _, mod in ipairs(list) do
            if not mod.isHeader then
                mod.enabled = false
                if mod.slider then mod.slider.value = (mod.slider.min + mod.slider.max) / 2 end
                if mod.sliders then
                    for _, s in ipairs(mod.sliders) do s.value = (s.min + s.max) / 2 end
                end
            end
        end
    end
end

-- =========================================================
-- GUI ROOT
-- =========================================================
local gui = Instance.new("ScreenGui")
gui.Name = "Desolate_" .. math.random(1, 1e6)
gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true; gui.DisplayOrder = 999
if gethui then local ok, h = pcall(gethui); if ok and h then gui.Parent = h end end
if not gui.Parent then
    local ok = pcall(function() gui.Parent = game:GetService("CoreGui") end)
    if not ok or not gui.Parent then gui.Parent = player:WaitForChild("PlayerGui") end
end

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 500, 0, 400)
main.Position = UDim2.new(0.5, -250, 0.5, -200)
main.BackgroundColor3 = BG; main.BorderSizePixel = 0
main.Active = true; main.Visible = false; main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)

local stroke = Instance.new("UIStroke")
stroke.Color = ACCENT; stroke.Thickness = 1; stroke.Transparency = 0.6
stroke.Parent = main

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 36)
header.BackgroundColor3 = BG2; header.BorderSizePixel = 0; header.Parent = main
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 12)

local headerMask = Instance.new("Frame")
headerMask.Size = UDim2.new(1, 0, 0, 10); headerMask.Position = UDim2.new(0, 0, 1, -10)
headerMask.BackgroundColor3 = BG2; headerMask.BorderSizePixel = 0; headerMask.Parent = header

local titleLbl = Instance.new("TextLabel")
titleLbl.BackgroundTransparency = 1
titleLbl.Position = UDim2.new(0, 14, 0, 0); titleLbl.Size = UDim2.new(1, -170, 1, 0)
titleLbl.Font = FONT; titleLbl.TextSize = 14
titleLbl.TextXAlignment = Enum.TextXAlignment.Left; titleLbl.TextColor3 = ACCENT
titleLbl.Text = "Desolate v" .. VERSION
titleLbl.Parent = header

local headerBtns = {}
local function makeHeaderBtn(text, xOff, onClick)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 26, 0, 24)
    b.Position = UDim2.new(1, xOff, 0, 6)
    b.BackgroundColor3 = BG4
    b.TextColor3 = TEXT; b.Font = FONT; b.TextSize = 12
    b.Text = text; b.BorderSizePixel = 0; b.Parent = header
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    local s = Instance.new("UIStroke")
    s.Color = ACCENT; s.Thickness = 1; s.Transparency = 0.85; s.Parent = b
    b.MouseButton1Click:Connect(function()
        local ok = onClick()
        b.TextColor3 = (ok ~= false) and OK or ERROR
        task.delay(0.4, function() b.TextColor3 = TEXT end)
    end)
    table.insert(headerBtns, b)
    return b
end

makeHeaderBtn("S", -110, function() return saveConfig() end)
makeHeaderBtn("L", -80, function()
    local ok = loadConfig(); refreshModules(); applyLoadedModules(); return ok
end)
makeHeaderBtn("R", -50, function()
    resetConfig(); refreshModules(); applyLoadedModules(); return true
end)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 22, 0, 24); closeBtn.Position = UDim2.new(1, -26, 0, 6)
closeBtn.BackgroundColor3 = BG4
closeBtn.TextColor3 = TEXT; closeBtn.Font = FONT; closeBtn.TextSize = 14
closeBtn.Text = "X"; closeBtn.BorderSizePixel = 0; closeBtn.Parent = header
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
closeBtn.MouseButton1Click:Connect(function() main.Visible = false; saveConfig() end)

local body = Instance.new("Frame")
body.Position = UDim2.new(0, 0, 0, 36); body.Size = UDim2.new(1, 0, 1, -36)
body.BackgroundTransparency = 1; body.Parent = main

local catPanel = Instance.new("Frame")
catPanel.Size = UDim2.new(0, 120, 1, -90); catPanel.Position = UDim2.new(0, 8, 0, 8)
catPanel.BackgroundColor3 = BG2; catPanel.BorderSizePixel = 0; catPanel.Parent = body
Instance.new("UICorner", catPanel).CornerRadius = UDim.new(0, 8)

local catList = Instance.new("UIListLayout")
catList.Padding = UDim.new(0, 4); catList.SortOrder = Enum.SortOrder.LayoutOrder
catList.Parent = catPanel

local catPad = Instance.new("UIPadding")
catPad.PaddingTop = UDim.new(0, 6); catPad.PaddingLeft = UDim.new(0, 6)
catPad.PaddingRight = UDim.new(0, 6); catPad.Parent = catPanel

local modPanel = Instance.new("Frame")
modPanel.Size = UDim2.new(1, -140, 1, -16); modPanel.Position = UDim2.new(0, 132, 0, 8)
modPanel.BackgroundColor3 = BG2; modPanel.BorderSizePixel = 0; modPanel.Parent = body
Instance.new("UICorner", modPanel).CornerRadius = UDim.new(0, 8)

local modScroll = Instance.new("ScrollingFrame")
modScroll.Size = UDim2.new(1, -8, 1, -8); modScroll.Position = UDim2.new(0, 4, 0, 4)
modScroll.BackgroundTransparency = 1; modScroll.BorderSizePixel = 0
modScroll.ScrollBarThickness = 3; modScroll.ScrollBarImageColor3 = ACCENT
modScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
modScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y; modScroll.Parent = modPanel

local modList = Instance.new("UIListLayout")
modList.Padding = UDim.new(0, 6); modList.SortOrder = Enum.SortOrder.LayoutOrder
modList.Parent = modScroll

local profileBtn = Instance.new("TextButton")
profileBtn.Size = UDim2.new(0, 120, 0, 74)
profileBtn.Position = UDim2.new(0, 8, 1, -82)
profileBtn.BackgroundColor3 = BG3
profileBtn.BorderSizePixel = 0
profileBtn.Text = ""
profileBtn.AutoButtonColor = false
profileBtn.Parent = body
Instance.new("UICorner", profileBtn).CornerRadius = UDim.new(0, 8)
local profileStroke = Instance.new("UIStroke")
profileStroke.Color = ACCENT; profileStroke.Thickness = 1; profileStroke.Transparency = 0.7
profileStroke.Parent = profileBtn

local avatarImg = Instance.new("ImageLabel")
avatarImg.Size = UDim2.new(0, 40, 0, 40)
avatarImg.Position = UDim2.new(0, 8, 0, 8)
avatarImg.BackgroundColor3 = BG2
avatarImg.BorderSizePixel = 0
avatarImg.Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150"
avatarImg.Parent = profileBtn
Instance.new("UICorner", avatarImg).CornerRadius = UDim.new(0, 999)

local profName = Instance.new("TextLabel")
profName.BackgroundTransparency = 1
profName.Position = UDim2.new(0, 54, 0, 8)
profName.Size = UDim2.new(1, -58, 0, 14)
profName.Font = FONT; profName.TextSize = 11
profName.TextColor3 = TEXT
profName.TextXAlignment = Enum.TextXAlignment.Left
profName.TextTruncate = Enum.TextTruncate.AtEnd
profName.Text = player.Name
profName.Parent = profileBtn

local profPlan = Instance.new("TextLabel")
profPlan.BackgroundTransparency = 1
profPlan.Position = UDim2.new(0, 54, 0, 24)
profPlan.Size = UDim2.new(1, -58, 0, 14)
profPlan.Font = FONT; profPlan.TextSize = 10
profPlan.TextColor3 = ACCENT
profPlan.TextXAlignment = Enum.TextXAlignment.Left
profPlan.TextTruncate = Enum.TextTruncate.AtEnd
profPlan.Text = "Loading..."
profPlan.Parent = profileBtn

local profHint = Instance.new("TextLabel")
profHint.BackgroundTransparency = 1
profHint.Position = UDim2.new(0, 8, 1, -18)
profHint.Size = UDim2.new(1, -16, 0, 14)
profHint.Font = FONT; profHint.TextSize = 9
profHint.TextColor3 = MUTED
profHint.TextXAlignment = Enum.TextXAlignment.Center
profHint.Text = "> Settings & Themes"
profHint.Parent = profileBtn

local function updateProfilePlan()
    if authData.plan == "lifetime" or not authData.expires then
        profPlan.Text = "Lifetime"; profPlan.TextColor3 = OK
    else
        local left = authData.expires - os.time()
        if left <= 0 then
            profPlan.Text = "Expired"; profPlan.TextColor3 = ERROR
        else
            local days = math.floor(left / 86400)
            local hours = math.floor((left % 86400) / 3600)
            profPlan.Text = string.format("%s %dd %dh", authData.plan, days, hours)
            profPlan.TextColor3 = ACCENT
        end
    end
end
updateProfilePlan()
task.spawn(function() while gui.Parent do updateProfilePlan(); task.wait(60) end end)

local currentCat = "Visual"
cacheModuleRefs()

local function refreshModules()
    for _, c in ipairs(modScroll:GetChildren()) do
        if c:IsA("Frame") or c:IsA("TextLabel") then c:Destroy() end
    end
    local list = state[currentCat] or {}
    for i, mod in ipairs(list) do
        if mod.isHeader then
            local hdr = Instance.new("TextLabel")
            hdr.Name = "HDR_" .. mod.name
            hdr.Size = UDim2.new(1, -8, 0, 22)
            hdr.BackgroundTransparency = 1
            hdr.Font = FONT; hdr.TextSize = 11
            hdr.TextColor3 = ACCENT
            hdr.TextXAlignment = Enum.TextXAlignment.Left
            hdr.Text = string.upper(mod.name)
            hdr.LayoutOrder = i
            hdr.Parent = modScroll
        else
            local cardHeight = 30
            if mod.sliders then cardHeight = 30 + #mod.sliders * 22 + 6
            elseif mod.slider then cardHeight = 62 end

            local card = Instance.new("Frame")
            card.Name = mod.name
            card.Size = UDim2.new(1, -8, 0, cardHeight)
            card.BackgroundColor3 = BG3; card.BorderSizePixel = 0
            card.LayoutOrder = i; card.Parent = modScroll
            Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

            local nameLbl = Instance.new("TextLabel")
            nameLbl.BackgroundTransparency = 1
            nameLbl.Position = UDim2.new(0, 12, 0, 0); nameLbl.Size = UDim2.new(1, -60, 0, 30)
            nameLbl.Font = FONT; nameLbl.TextSize = 13
            nameLbl.TextXAlignment = Enum.TextXAlignment.Left
            nameLbl.TextColor3 = mod.enabled and TEXT or MUTED
            nameLbl.Text = mod.name; nameLbl.Parent = card

            local checkbox = Instance.new("TextButton")
            checkbox.Size = UDim2.new(0, 18, 0, 18); checkbox.Position = UDim2.new(1, -24, 0, 6)
            checkbox.BackgroundColor3 = mod.enabled and ACCENT or BG4
            checkbox.Text = ""; checkbox.BorderSizePixel = 0; checkbox.Parent = card
            Instance.new("UICorner", checkbox).CornerRadius = UDim.new(0, 5)

            checkbox.MouseButton1Click:Connect(function()
                mod.enabled = not mod.enabled
                checkbox.BackgroundColor3 = mod.enabled and ACCENT or BG4
                nameLbl.TextColor3 = mod.enabled and TEXT or MUTED
                if mod.actions.onToggle then pcall(mod.actions.onToggle, mod.enabled) end
            end)

            local function createSlider(sl, yPos, onUpdate)
                local track = Instance.new("Frame")
                track.Size = UDim2.new(1, -30, 0, 6); track.Position = UDim2.new(0, 15, 0, yPos)
                track.BackgroundColor3 = BG4
                track.BorderSizePixel = 0; track.Parent = card
                Instance.new("UICorner", track).CornerRadius = UDim.new(0, 4)

                local fill = Instance.new("Frame")
                fill.Size = UDim2.new((sl.value - sl.min) / (sl.max - sl.min), 0, 1, 0)
                fill.BackgroundColor3 = ACCENT; fill.BorderSizePixel = 0; fill.Parent = track
                Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 4)

                local valueLbl = Instance.new("TextLabel")
                valueLbl.BackgroundTransparency = 1
                valueLbl.Position = UDim2.new(1, -70, 0, yPos - 8)
                valueLbl.Size = UDim2.new(0, 60, 0, 16)
                valueLbl.Font = FONT; valueLbl.TextSize = 11; valueLbl.TextColor3 = ACCENT
                valueLbl.Text = string.format("%.1f", sl.value); valueLbl.Parent = card

                if sl.label then
                    local labLbl = Instance.new("TextLabel")
                    labLbl.BackgroundTransparency = 1
                    labLbl.Position = UDim2.new(0, 15, 0, yPos - 10)
                    labLbl.Size = UDim2.new(0, 80, 0, 12)
                    labLbl.Font = FONT; labLbl.TextSize = 9
                    labLbl.TextColor3 = MUTED
                    labLbl.TextXAlignment = Enum.TextXAlignment.Left
                    labLbl.Text = sl.label
                    labLbl.Parent = card
                end

                local dragging = false
                local function update(ip)
                    local abs = track.AbsolutePosition.X
                    local w = track.AbsoluteSize.X
                    local pct = math.clamp((ip.Position.X - abs) / w, 0, 1)
                    local newVal = sl.min + (sl.max - sl.min) * pct
                    sl.value = newVal
                    fill.Size = UDim2.new(pct, 0, 1, 0)
                    valueLbl.Text = string.format("%.1f", newVal)
                    if onUpdate then pcall(onUpdate, newVal) end
                end
                track.InputBegan:Connect(function(ip)
                    if ip.UserInputType == Enum.UserInputType.MouseButton1
                       or ip.UserInputType == Enum.UserInputType.Touch then
                        dragging = true; update(ip)
                    end
                end)
                UserInputService.InputChanged:Connect(function(ip)
                    if dragging and (ip.UserInputType == Enum.UserInputType.MouseMovement
                       or ip.UserInputType == Enum.UserInputType.Touch) then update(ip) end
                end)
                UserInputService.InputEnded:Connect(function(ip)
                    if ip.UserInputType == Enum.UserInputType.MouseButton1
                       or ip.UserInputType == Enum.UserInputType.Touch then dragging = false end
                end)
            end

            if mod.slider then
                createSlider(mod.slider, 46, mod.actions.onChange)
                if mod.actions.onChange then pcall(mod.actions.onChange, mod.slider.value) end
            end
            if mod.sliders then
                for idx, sl in ipairs(mod.sliders) do
                    local y = 40 + (idx - 1) * 22
                    createSlider(sl, y, function(v)
                        if mod.actions.onSliderChange then pcall(mod.actions.onSliderChange, idx, v) end
                    end)
                    if mod.actions.onSliderChange then pcall(mod.actions.onSliderChange, idx, sl.value) end
                end
            end
        end
    end
end

local function refreshCategories()
    for _, c in ipairs(catPanel:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    local i = 1
    for catName in pairs(state) do
        local btn = Instance.new("TextButton")
        btn.Name = catName; btn.Size = UDim2.new(1, 0, 0, 26)
        btn.BackgroundColor3 = (catName == currentCat) and ACCENT or BG4
        btn.TextColor3 = (catName == currentCat) and BG or TEXT
        btn.Font = FONT; btn.TextSize = 12; btn.Text = catName
        btn.BorderSizePixel = 0; btn.LayoutOrder = i; btn.Parent = catPanel
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        btn.MouseButton1Click:Connect(function()
            currentCat = catName; refreshCategories(); refreshModules()
        end)
        i += 1
    end
end

-- =========================================================
-- SUB MENU
-- =========================================================
local subGui = Instance.new("ScreenGui")
subGui.Name = "DesolateSub_" .. math.random(1, 1e6)
subGui.ResetOnSpawn = false; subGui.IgnoreGuiInset = true
subGui.DisplayOrder = 1001
if gethui then local ok, h = pcall(gethui); if ok and h then subGui.Parent = h end end
if not subGui.Parent then
    local ok = pcall(function() subGui.Parent = game:GetService("CoreGui") end)
    if not ok or not subGui.Parent then subGui.Parent = player:WaitForChild("PlayerGui") end
end

local subMenu = Instance.new("Frame")
subMenu.Size = UDim2.new(0, 500, 0, 400)
subMenu.Position = UDim2.new(0.5, -250, 0.5, -200)
subMenu.BackgroundColor3 = BG; subMenu.BorderSizePixel = 0
subMenu.Visible = false; subMenu.Active = true; subMenu.Parent = subGui
Instance.new("UICorner", subMenu).CornerRadius = UDim.new(0, 12)

local subStroke = Instance.new("UIStroke")
subStroke.Color = ACCENT; subStroke.Thickness = 1; subStroke.Transparency = 0.6
subStroke.Parent = subMenu

local subHeader = Instance.new("Frame")
subHeader.Size = UDim2.new(1, 0, 0, 36)
subHeader.BackgroundColor3 = BG2; subHeader.BorderSizePixel = 0; subHeader.Parent = subMenu
Instance.new("UICorner", subHeader).CornerRadius = UDim.new(0, 12)

local subHeaderMask = Instance.new("Frame")
subHeaderMask.Size = UDim2.new(1, 0, 0, 10); subHeaderMask.Position = UDim2.new(0, 0, 1, -10)
subHeaderMask.BackgroundColor3 = BG2; subHeaderMask.BorderSizePixel = 0; subHeaderMask.Parent = subHeader

local backBtn = Instance.new("TextButton")
backBtn.Size = UDim2.new(0, 30, 0, 24); backBtn.Position = UDim2.new(0, 10, 0, 6)
backBtn.BackgroundColor3 = BG4; backBtn.TextColor3 = TEXT
backBtn.Font = FONT; backBtn.TextSize = 14; backBtn.Text = "<"
backBtn.BorderSizePixel = 0; backBtn.Parent = subHeader
Instance.new("UICorner", backBtn).CornerRadius = UDim.new(0, 6)
backBtn.MouseButton1Click:Connect(function() subMenu.Visible = false end)

local subTitle = Instance.new("TextLabel")
subTitle.BackgroundTransparency = 1
subTitle.Position = UDim2.new(0, 48, 0, 0); subTitle.Size = UDim2.new(1, -60, 1, 0)
subTitle.Font = FONT; subTitle.TextSize = 14
subTitle.TextXAlignment = Enum.TextXAlignment.Left
subTitle.TextColor3 = ACCENT
subTitle.Text = "Settings & Themes"
subTitle.Parent = subHeader

local subBody = Instance.new("Frame")
subBody.Position = UDim2.new(0, 0, 0, 36); subBody.Size = UDim2.new(1, 0, 1, -36)
subBody.BackgroundTransparency = 1; subBody.Parent = subMenu

local themesHdr = Instance.new("TextLabel")
themesHdr.BackgroundTransparency = 1
themesHdr.Position = UDim2.new(0, 16, 0, 12)
themesHdr.Size = UDim2.new(1, -32, 0, 20)
themesHdr.Font = FONT; themesHdr.TextSize = 12
themesHdr.TextColor3 = ACCENT
themesHdr.TextXAlignment = Enum.TextXAlignment.Left
themesHdr.Text = "THEMES"
themesHdr.Parent = subBody

local themeGrid = Instance.new("Frame")
themeGrid.Position = UDim2.new(0, 16, 0, 38)
themeGrid.Size = UDim2.new(1, -32, 0, 130)
themeGrid.BackgroundTransparency = 1
themeGrid.Parent = subBody

local themeOrder = { "Dark", "Blood", "Ocean", "Purple", "Pink", "Matrix", "Light" }

local function rebuildThemeGrid()
    for _, c in ipairs(themeGrid:GetChildren()) do c:Destroy() end
    for i, tName in ipairs(themeOrder) do
        local th = THEMES[tName]
        local row = math.floor((i - 1) / 4)
        local col = (i - 1) % 4

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 105, 0, 50)
        btn.Position = UDim2.new(0, col * 112, 0, row * 58)
        btn.BackgroundColor3 = th.bg3
        btn.Text = ""; btn.BorderSizePixel = 0
        btn.AutoButtonColor = false; btn.Parent = themeGrid
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

        local btnStroke = Instance.new("UIStroke")
        btnStroke.Color = th.accent
        btnStroke.Thickness = (currentTheme == tName) and 2 or 1
        btnStroke.Transparency = (currentTheme == tName) and 0 or 0.5
        btnStroke.Parent = btn

        local dot = Instance.new("Frame")
        dot.Size = UDim2.new(0, 18, 0, 18)
        dot.Position = UDim2.new(0, 10, 0, 10)
        dot.BackgroundColor3 = th.accent
        dot.BorderSizePixel = 0; dot.Parent = btn
        Instance.new("UICorner", dot).CornerRadius = UDim.new(0, 999)

        local lbl = Instance.new("TextLabel")
        lbl.BackgroundTransparency = 1
        lbl.Position = UDim2.new(0, 34, 0, 10)
        lbl.Size = UDim2.new(1, -38, 0, 18)
        lbl.Font = FONT; lbl.TextSize = 12
        lbl.TextColor3 = th.text
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Text = tName; lbl.Parent = btn

        local sub = Instance.new("TextLabel")
        sub.BackgroundTransparency = 1
        sub.Position = UDim2.new(0, 10, 0, 30)
        sub.Size = UDim2.new(1, -14, 0, 14)
        sub.Font = FONT; sub.TextSize = 9
        sub.TextColor3 = th.muted
        sub.TextXAlignment = Enum.TextXAlignment.Left
        sub.Text = (currentTheme == tName) and "Active" or "click to apply"
        sub.Parent = btn

        btn.MouseButton1Click:Connect(function() applyTheme(tName) end)
    end
end

local settingsHdr = Instance.new("TextLabel")
settingsHdr.BackgroundTransparency = 1
settingsHdr.Position = UDim2.new(0, 16, 0, 186)
settingsHdr.Size = UDim2.new(1, -32, 0, 20)
settingsHdr.Font = FONT; settingsHdr.TextSize = 12
settingsHdr.TextColor3 = ACCENT
settingsHdr.TextXAlignment = Enum.TextXAlignment.Left
settingsHdr.Text = "MENU SETTINGS"
settingsHdr.Parent = subBody

local settingsNote = Instance.new("TextLabel")
settingsNote.BackgroundTransparency = 1
settingsNote.Position = UDim2.new(0, 16, 0, 210)
settingsNote.Size = UDim2.new(1, -32, 0, 100)
settingsNote.Font = FONT; settingsNote.TextSize = 11
settingsNote.TextColor3 = MUTED
settingsNote.TextXAlignment = Enum.TextXAlignment.Left
settingsNote.TextYAlignment = Enum.TextYAlignment.Top
settingsNote.TextWrapped = true
settingsNote.Text = "- RightShift / button D - toggle menu\n- S save, L load, R reset\n- HUD drag with mouse\n- Auto-save on close"
settingsNote.Parent = subBody

local function applyStaticColors()
    main.BackgroundColor3 = BG
    stroke.Color = ACCENT
    header.BackgroundColor3 = BG2
    headerMask.BackgroundColor3 = BG2
    titleLbl.TextColor3 = ACCENT
    closeBtn.BackgroundColor3 = BG4; closeBtn.TextColor3 = TEXT
    catPanel.BackgroundColor3 = BG2
    modPanel.BackgroundColor3 = BG2
    modScroll.ScrollBarImageColor3 = ACCENT
    profileBtn.BackgroundColor3 = BG3
    profileStroke.Color = ACCENT
    profName.TextColor3 = TEXT
    profHint.TextColor3 = MUTED
    subMenu.BackgroundColor3 = BG
    subStroke.Color = ACCENT
    subHeader.BackgroundColor3 = BG2
    subHeaderMask.BackgroundColor3 = BG2
    backBtn.BackgroundColor3 = BG4; backBtn.TextColor3 = TEXT
    subTitle.TextColor3 = ACCENT
    themesHdr.TextColor3 = ACCENT
    settingsHdr.TextColor3 = ACCENT
    settingsNote.TextColor3 = MUTED
    watermark.BackgroundColor3 = BG2
    wAccent.BackgroundColor3 = ACCENT
    wLabel.TextColor3 = TEXT
    coordFrame.BackgroundColor3 = BG2
    coordLabel.TextColor3 = TEXT
    targetHud.BackgroundColor3 = BG2
    thName.TextColor3 = TEXT
    thInfo.TextColor3 = MUTED
    buildCrosshair()
    if drawFovFrame then
        drawFovStroke.Color = ACCENT
    end
    mobileBtn.BackgroundColor3 = BG2
    mobileBtn.TextColor3 = ACCENT
    mStroke.Color = ACCENT
    for _, b in ipairs(headerBtns) do
        b.BackgroundColor3 = BG4; b.TextColor3 = TEXT
    end
end

function applyTheme(themeName)
    local th = THEMES[themeName]
    if not th then return end
    ACCENT = th.accent
    BG = th.bg; BG2 = th.bg2; BG3 = th.bg3; BG4 = th.bg4
    TEXT = th.text; MUTED = th.muted
    currentTheme = themeName
    applyStaticColors()
    refreshCategories()
    refreshModules()
    rebuildThemeGrid()
    saveConfig()
    print("[Desolate] theme applied:", themeName)
end

profileBtn.MouseButton1Click:Connect(function()
    subMenu.Visible = not subMenu.Visible
    if subMenu.Visible then
        subMenu.Position = main.Position
        rebuildThemeGrid()
    end
end)

main:GetPropertyChangedSignal("Visible"):Connect(function()
    if not main.Visible then subMenu.Visible = false end
end)

-- =========================================================
-- HUD LAYER
-- =========================================================
local hudGui = Instance.new("ScreenGui")
hudGui.Name = "DesolateHUD_" .. math.random(1, 1e6)
hudGui.ResetOnSpawn = false; hudGui.IgnoreGuiInset = true
hudGui.DisplayOrder = 998
if gethui then local ok, h = pcall(gethui); if ok and h then hudGui.Parent = h end end
if not hudGui.Parent then
    local ok = pcall(function() hudGui.Parent = game:GetService("CoreGui") end)
    if not ok or not hudGui.Parent then hudGui.Parent = player:WaitForChild("PlayerGui") end
end

local function makeDraggable(frame, name, defaultX, defaultY)
    frame.Active = true
    local dragging, dragStart, startPos
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = frame.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
           or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            if dragging then
                dragging = false
                pcall(function()
                    fs.write("desolate_hud_" .. name .. ".txt",
                        frame.Position.X.Scale .. "," .. frame.Position.X.Offset .. "," ..
                        frame.Position.Y.Scale .. "," .. frame.Position.Y.Offset)
                end)
            end
        end
    end)
    local saved = fs.read("desolate_hud_" .. name .. ".txt")
    local loaded = false
    if saved then
        local nums = {}
        for v in saved:gmatch("([^,]+)") do table.insert(nums, tonumber(v)) end
        if #nums >= 4 then
            frame.Position = UDim2.new(nums[1], nums[2], nums[3], nums[4]); loaded = true
        end
    end
    if not loaded and defaultX and defaultY then
        frame.Position = UDim2.new(0, defaultX, 0, defaultY)
    end
    local hint = Instance.new("UIStroke")
    hint.Color = ACCENT; hint.Thickness = 1; hint.Transparency = 0.75
    hint.Parent = frame
end

local watermark = Instance.new("Frame")
watermark.Size = UDim2.new(0, 380, 0, 40); watermark.Position = UDim2.new(0, 10, 0, 10)
watermark.BackgroundColor3 = BG2; watermark.BackgroundTransparency = 0.15
watermark.BorderSizePixel = 0; watermark.Visible = false; watermark.Parent = hudGui
Instance.new("UICorner", watermark).CornerRadius = UDim.new(0, 8)

local wAccent = Instance.new("Frame")
wAccent.Size = UDim2.new(0, 3, 1, 0); wAccent.BackgroundColor3 = ACCENT
wAccent.BorderSizePixel = 0; wAccent.Parent = watermark
Instance.new("UICorner", wAccent).CornerRadius = UDim.new(0, 8)

local wLabel = Instance.new("TextLabel")
wLabel.BackgroundTransparency = 1; wLabel.Position = UDim2.new(0, 10, 0, 0)
wLabel.Size = UDim2.new(1, -14, 1, 0); wLabel.Font = FONT; wLabel.TextSize = 12
wLabel.TextXAlignment = Enum.TextXAlignment.Left; wLabel.TextColor3 = TEXT
wLabel.Text = "Desolate"; wLabel.Parent = watermark

MOD.watermark.actions.onToggle = function(on) watermark.Visible = on end
watermark.Visible = MOD.watermark.enabled
makeDraggable(watermark, "watermark", 10, 10)

local coordFrame = Instance.new("Frame")
coordFrame.Size = UDim2.new(0, 200, 0, 24); coordFrame.Position = UDim2.new(0, 10, 0, 60)
coordFrame.BackgroundColor3 = BG2; coordFrame.BackgroundTransparency = 0.2
coordFrame.BorderSizePixel = 0; coordFrame.Visible = false; coordFrame.Parent = hudGui
Instance.new("UICorner", coordFrame).CornerRadius = UDim.new(0, 6)

local coordLabel = Instance.new("TextLabel")
coordLabel.BackgroundTransparency = 1; coordLabel.Size = UDim2.new(1, -8, 1, 0)
coordLabel.Position = UDim2.new(0, 4, 0, 0); coordLabel.Font = FONT
coordLabel.TextSize = 12; coordLabel.TextXAlignment = Enum.TextXAlignment.Left
coordLabel.TextColor3 = TEXT; coordLabel.Text = "X: -- Y: -- Z: --"
coordLabel.Parent = coordFrame

MOD.coords.actions.onToggle = function(on) coordFrame.Visible = on end
makeDraggable(coordFrame, "coords", 10, 60)

local crosshair = Instance.new("Frame")
crosshair.Name = "Crosshair"
crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
crosshair.Position = UDim2.new(0.5, 0, 0.5, 0)
crosshair.Size = UDim2.new(0, 20, 0, 20)
crosshair.BackgroundTransparency = 1
crosshair.Visible = false; crosshair.Parent = hudGui

local chMode = "circle"
function buildCrosshair()
    if not crosshair or not crosshair.Parent then return end
    for _, c in ipairs(crosshair:GetChildren()) do c:Destroy() end
    if chMode == "dot" then
        local dot = Instance.new("Frame")
        dot.Size = UDim2.new(0, 3, 0, 3); dot.Position = UDim2.new(0.5, -1, 0.5, -1)
        dot.BackgroundColor3 = ACCENT; dot.BorderSizePixel = 0; dot.Parent = crosshair
        Instance.new("UICorner", dot).CornerRadius = UDim.new(0, 999)
    elseif chMode == "circle" then
        local c = Instance.new("Frame")
        c.Size = UDim2.new(0, 14, 0, 14); c.Position = UDim2.new(0.5, -7, 0.5, -7)
        c.BackgroundTransparency = 1; c.Parent = crosshair
        local st2 = Instance.new("UIStroke")
        st2.Color = ACCENT; st2.Thickness = 1.5; st2.Parent = c
        Instance.new("UICorner", c).CornerRadius = UDim.new(0, 999)
    elseif chMode == "cross" then
        for _, data in ipairs({
            { UDim2.new(0, 1, 0, 8), UDim2.new(0.5, -0.5, 0.5, -10) },
            { UDim2.new(0, 1, 0, 8), UDim2.new(0.5, -0.5, 0.5, 2) },
            { UDim2.new(0, 8, 0, 1), UDim2.new(0.5, -10, 0.5, -0.5) },
            { UDim2.new(0, 8, 0, 1), UDim2.new(0.5, 2, 0.5, -0.5) },
        }) do
            local bar = Instance.new("Frame")
            bar.Size = data[1]; bar.Position = data[2]
            bar.BackgroundColor3 = ACCENT; bar.BorderSizePixel = 0; bar.Parent = crosshair
        end
    end
end
buildCrosshair()
MOD.crosshair.actions.onToggle = function(on) crosshair.Visible = on end

-- =========================================================
-- DRAW FOV (circle only)
-- =========================================================
local drawFovFrame = Instance.new("Frame")
drawFovFrame.Name = "DrawFOV"
drawFovFrame.AnchorPoint = Vector2.new(0.5, 0.5)
drawFovFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
drawFovFrame.Size = UDim2.new(0, 300, 0, 300)
drawFovFrame.BackgroundTransparency = 1
drawFovFrame.Visible = false
drawFovFrame.Parent = hudGui

local drawFovInner = Instance.new("Frame")
drawFovInner.Size = UDim2.new(1, 0, 1, 0)
drawFovInner.BackgroundTransparency = 1
drawFovInner.Parent = drawFovFrame
Instance.new("UICorner", drawFovInner).CornerRadius = UDim.new(0, 999)

local drawFovStroke = Instance.new("UIStroke")
drawFovStroke.Color = ACCENT
drawFovStroke.Thickness = 1.5
drawFovStroke.Transparency = 0.4
drawFovStroke.Parent = drawFovInner

local function updateDrawFov(v)
    -- slider 1-30 → 1 = 20px, 30 = 600px radius
    local radius = v * 20
    drawFovFrame.Size = UDim2.new(0, radius * 2, 0, radius * 2)
    drawFovStroke.Color = ACCENT
end

MOD.drawFov.actions.onToggle = function(on)
    drawFovFrame.Visible = on
    if on then updateDrawFov(MOD.drawFov.slider.value) end
end
MOD.drawFov.actions.onChange = function(v)
    if not MOD.drawFov.enabled then return end
    updateDrawFov(v)
end

-- =========================================================
-- NAMETAGS
-- =========================================================
local nametagFolder = Instance.new("Folder")
nametagFolder.Name = "DesolateNameTags"; nametagFolder.Parent = hudGui
local nametags = {}

local function createNametag(plr)
    local bb = Instance.new("BillboardGui")
    bb.Name = "NT_" .. plr.Name
    bb.Size = UDim2.new(0, 140, 0, 44)
    bb.StudsOffset = Vector3.new(0, 3.2, 0)
    bb.AlwaysOnTop = true; bb.LightInfluence = 0

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = BG; bg.BackgroundTransparency = 0.15
    bg.BorderSizePixel = 0; bg.Parent = bb
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 6)

    local name = Instance.new("TextLabel")
    name.BackgroundTransparency = 1; name.Position = UDim2.new(0, 6, 0, 2)
    name.Size = UDim2.new(1, -12, 0, 14); name.Font = FONT; name.TextSize = 12
    name.TextColor3 = ACCENT; name.TextXAlignment = Enum.TextXAlignment.Center
    name.Text = plr.Name; name.Parent = bg

    local info = Instance.new("TextLabel")
    info.BackgroundTransparency = 1; info.Position = UDim2.new(0, 6, 0, 16)
    info.Size = UDim2.new(1, -12, 0, 14); info.Font = FONT; info.TextSize = 11
    info.TextColor3 = TEXT; info.TextXAlignment = Enum.TextXAlignment.Center
    info.Text = "HP: -- | --m"; info.Parent = bg

    local hbBg = Instance.new("Frame")
    hbBg.Position = UDim2.new(0, 6, 1, -6)
    hbBg.Size = UDim2.new(1, -12, 0, 3)
    hbBg.BackgroundColor3 = BG4
    hbBg.BorderSizePixel = 0; hbBg.Parent = bg
    Instance.new("UICorner", hbBg).CornerRadius = UDim.new(0, 4)

    local hb = Instance.new("Frame")
    hb.Size = UDim2.new(1, 0, 1, 0)
    hb.BackgroundColor3 = OK; hb.BorderSizePixel = 0; hb.Parent = hbBg
    Instance.new("UICorner", hb).CornerRadius = UDim.new(0, 4)

    return bb, name, info, hb
end

MOD.nameTags.actions.onToggle = function(on)
    if on then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= player and plr.Character then
                local bb, n, i, hb = createNametag(plr)
                bb.Adornee = plr.Character:FindFirstChild("Head") or plr.Character:FindFirstChild("HumanoidRootPart")
                bb.Parent = nametagFolder
                nametags[plr] = { gui = bb, name = n, info = i, hbar = hb }
            end
        end
    else
        for _, d in pairs(nametags) do if d.gui then d.gui:Destroy() end end
        nametags = {}
    end
end

Players.PlayerAdded:Connect(function(plr)
    if not MOD.nameTags.enabled then return end
    plr.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        if not MOD.nameTags.enabled then return end
        local bb, n, i, hb = createNametag(plr)
        bb.Adornee = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
        bb.Parent = nametagFolder
        nametags[plr] = { gui = bb, name = n, info = i, hbar = hb }
    end)
end)

Players.PlayerRemoving:Connect(function(plr)
    if nametags[plr] then
        if nametags[plr].gui then nametags[plr].gui:Destroy() end
        nametags[plr] = nil
    end
end)

-- =========================================================
-- ESP
-- =========================================================
local espHighlights = {}
MOD.esp.actions.onToggle = function(on)
    if on then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= player and plr.Character then
                local hl = Instance.new("Highlight")
                hl.Name = "DesolateESP"; hl.Adornee = plr.Character
                hl.FillColor = Color3.fromRGB(255, 60, 60); hl.OutlineColor = ACCENT
                hl.FillTransparency = 0.65; hl.OutlineTransparency = 0
                hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                hl.Parent = plr.Character
                espHighlights[plr] = hl
            end
        end
    else
        for _, hl in pairs(espHighlights) do if hl then hl:Destroy() end end
        espHighlights = {}
    end
end

-- =========================================================
-- JUMP CIRCLE
-- =========================================================
local jumpRings = {}
MOD.jumpCircle.actions.onToggle = function(on)
    if not on then
        for _, r in ipairs(jumpRings) do if r.part then r.part:Destroy() end end
        jumpRings = {}
    end
end

local wasOnGround = true
RunService.Heartbeat:Connect(function()
    if not MOD.jumpCircle.enabled then return end
    local hum = CACHE.humanoid
    local hrp = CACHE.hrp
    if not hum or not hrp then return end
    local onGround = hum.FloorMaterial ~= Enum.Material.Air
    if wasOnGround and not onGround then
        local ring = Instance.new("Part")
        ring.Shape = Enum.PartType.Cylinder
        ring.Anchored = true; ring.CanCollide = false
        ring.CanQuery = false; ring.CanTouch = false
        ring.Material = Enum.Material.Neon
        ring.Color = ACCENT; ring.Transparency = 0.2
        ring.Size = Vector3.new(0.15, 2, 2)
        ring.CFrame = CFrame.new(hrp.Position - Vector3.new(0, 2.9, 0)) * CFrame.Angles(0, 0, math.rad(90))
        ring.Parent = Workspace
        table.insert(jumpRings, { part = ring, born = tick() })
    end
    wasOnGround = onGround
    for i = #jumpRings, 1, -1 do
        local r = jumpRings[i]
        local age = tick() - r.born
        if age > 0.7 then
            if r.part then r.part:Destroy() end
            table.remove(jumpRings, i)
        else
            local size = 2 + age * 8
            r.part.Size = Vector3.new(0.15, size, size)
            r.part.Transparency = 0.2 + age / 0.7 * 0.7
        end
    end
end)

-- =========================================================
-- TRAILS
-- =========================================================
local trailEmitter = nil
local trailAccum = 0

local function ensureTrailEmitter()
    if trailEmitter and trailEmitter.Parent then return trailEmitter end
    local hrp = CACHE.hrp
    if not hrp then return nil end
    local att = hrp:FindFirstChild("DesolateTrailAtt")
    if not att then
        att = Instance.new("Attachment")
        att.Name = "DesolateTrailAtt"
        att.Position = Vector3.new(0, -1.5, 0)
        att.Parent = hrp
    end
    local em = att:FindFirstChild("Emitter")
    if not em then
        em = Instance.new("ParticleEmitter")
        em.Name = "Emitter"
        em.Texture = "rbxassetid://243098098"
        em.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.5),
            NumberSequenceKeypoint.new(1, 0),
        })
        em.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.2),
            NumberSequenceKeypoint.new(1, 1),
        })
        em.Lifetime = NumberRange.new(0.6)
        em.Rate = 0
        em.Speed = NumberRange.new(0)
        em.Parent = att
    end
    trailEmitter = em
    return em
end

RunService.Heartbeat:Connect(function(dt)
    if not MOD.trails.enabled then return end
    if not CACHE.hrp then return end
    trailAccum += dt
    if trailAccum >= 0.06 then
        trailAccum = 0
        local em = ensureTrailEmitter()
        if em then
            em.Color = ColorSequence.new(ACCENT)
            em:Emit(2)
        end
    end
end)

-- =========================================================
-- PARTICLES
-- =========================================================
local function destroyParticlesEmitter()
    if CACHE.hrp then
        local att = CACHE.hrp:FindFirstChild("DesolateFallingEmitter")
        if att then pcall(function() att:Destroy() end) end
    end
end

local function buildParticles()
    destroyParticlesEmitter()
    local hrp = CACHE.hrp
    if not hrp then return end
    if not MOD.particles.enabled then return end

    local rate  = MOD.particles.sliders[1].value
    local speed = MOD.particles.sliders[2].value
    local size  = MOD.particles.sliders[3].value

    local att = Instance.new("Attachment")
    att.Name = "DesolateFallingEmitter"
    att.Position = Vector3.new(0, 25, 0)
    att.Parent = hrp

    local em = Instance.new("ParticleEmitter")
    em.Name = "Emitter"
    em.Texture = "rbxassetid://243098098"
    em.Color = ColorSequence.new(ACCENT)
    em.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(1, 0.9),
    })
    em.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, size / 5),
        NumberSequenceKeypoint.new(1, size / 20),
    })
    em.Lifetime = NumberRange.new(3)
    em.Speed = NumberRange.new(speed)
    em.Direction = Vector3.new(0, -1, 0)
    em.SpreadAngle = Vector2.new(20, 20)
    em.Acceleration = Vector3.new(0, -25, 0)
    em.Rotation = NumberRange.new(0, 360)
    em.RotSpeed = NumberRange.new(-90, 90)
    em.Rate = rate
    em.LightEmission = 0.6
    em.LightInfluence = 0
    em.Parent = att
end

MOD.particles.actions.onToggle = function(on)
    if on then buildParticles() else destroyParticlesEmitter() end
end

MOD.particles.actions.onSliderChange = function(idx, v)
    local hrp = CACHE.hrp
    if not hrp then return end
    local att = hrp:FindFirstChild("DesolateFallingEmitter")
    if not att then return end
    local em = att:FindFirstChild("Emitter")
    if not em then return end

    if idx == 1 then em.Rate = v
    elseif idx == 2 then em.Speed = NumberRange.new(v)
    elseif idx == 3 then
        em.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, v / 5),
            NumberSequenceKeypoint.new(1, v / 20),
        })
    end
    em.Color = ColorSequence.new(ACCENT)
end

player.CharacterAdded:Connect(function()
    task.wait(1)
    refreshCharacterCache()
    if MOD.particles.enabled then buildParticles() end
end)

task.spawn(function()
    while gui.Parent do
        task.wait(1)
        if MOD.particles.enabled then
            if not CACHE.hrp then refreshCharacterCache() end
            if CACHE.hrp and not CACHE.hrp:FindFirstChild("DesolateFallingEmitter") then
                buildParticles()
            end
        end
    end
end)

-- =========================================================
-- SKY / FOG
-- =========================================================
local SKY_PRESETS = {
    { clockTime = 12,   ambient = Color3.fromRGB(128, 128, 128), outdoor = Color3.fromRGB(128, 128, 128), fogColor = Color3.fromRGB(200, 220, 255), fogEnd = 1000 },
    { clockTime = 17.5, ambient = Color3.fromRGB(90, 70, 80),    outdoor = Color3.fromRGB(140, 90, 80),   fogColor = Color3.fromRGB(255, 130, 80),  fogEnd = 500 },
    { clockTime = 0,    ambient = Color3.fromRGB(20, 20, 40),    outdoor = Color3.fromRGB(30, 30, 60),    fogColor = Color3.fromRGB(10, 10, 30),    fogEnd = 300 },
    { clockTime = 22,   ambient = Color3.fromRGB(20, 25, 35),    outdoor = Color3.fromRGB(25, 30, 45),    fogColor = Color3.fromRGB(0, 40, 60),     fogEnd = 250 },
    { clockTime = 2,    ambient = Color3.fromRGB(60, 15, 15),    outdoor = Color3.fromRGB(80, 20, 20),    fogColor = Color3.fromRGB(120, 0, 0),     fogEnd = 200 },
}
local currentSkyPreset = 4
local customSkyObj = nil
local originalLighting = {
    Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
    FogColor = Lighting.FogColor, FogStart = Lighting.FogStart, FogEnd = Lighting.FogEnd,
    ClockTime = Lighting.ClockTime, Brightness = Lighting.Brightness,
}

local function ensureSkyObject()
    if not customSkyObj or not customSkyObj.Parent then
        customSkyObj = Instance.new("Sky")
        customSkyObj.Name = "DesolateCustomSky"
        customSkyObj.SkyboxBk = "rbxasset://textures/sky/sky512_bk.tex"
        customSkyObj.SkyboxDn = "rbxasset://textures/sky/sky512_dn.tex"
        customSkyObj.SkyboxFt = "rbxasset://textures/sky/sky512_ft.tex"
        customSkyObj.SkyboxLf = "rbxasset://textures/sky/sky512_lf.tex"
        customSkyObj.SkyboxRt = "rbxasset://textures/sky/sky512_rt.tex"
        customSkyObj.SkyboxUp = "rbxasset://textures/sky/sky512_up.tex"
        customSkyObj.Parent = Lighting
    end
    return customSkyObj
end

local function applySkyPreset(idx)
    local p = SKY_PRESETS[idx]
    if not p then return end
    ensureSkyObject()
    Lighting.ClockTime = p.clockTime
    Lighting.Ambient = p.ambient
    Lighting.OutdoorAmbient = p.outdoor
    Lighting.FogColor = p.fogColor
    Lighting.FogStart = 0; Lighting.FogEnd = p.fogEnd
    Lighting.Brightness = 2
end

MOD.customSky.actions.onToggle = function(on)
    if on then
        applySkyPreset(currentSkyPreset)
        Lighting.ClockTime = MOD.customSky.slider.value
    else
        if customSkyObj then customSkyObj:Destroy(); customSkyObj = nil end
        pcall(function() Lighting.ClockTime = originalLighting.ClockTime end)
        pcall(function() Lighting.Ambient = originalLighting.Ambient end)
        pcall(function() Lighting.OutdoorAmbient = originalLighting.OutdoorAmbient end)
        pcall(function() Lighting.Brightness = originalLighting.Brightness end)
    end
end
MOD.customSky.actions.onChange = function(v)
    if not MOD.customSky.enabled then return end
    Lighting.ClockTime = v
end

MOD.fog.actions.onToggle = function(on)
    if on then
        Lighting.FogStart = 0; Lighting.FogEnd = MOD.fog.slider.value
        if not MOD.customSky.enabled then Lighting.FogColor = Color3.fromRGB(40, 45, 65) end
    else
        if not MOD.customSky.enabled then
            pcall(function() Lighting.FogColor = originalLighting.FogColor end)
            pcall(function() Lighting.FogStart = originalLighting.FogStart end)
            pcall(function() Lighting.FogEnd = originalLighting.FogEnd end)
        end
    end
end
MOD.fog.actions.onChange = function(v)
    if not MOD.fog.enabled then return end
    Lighting.FogStart = 0; Lighting.FogEnd = v
end

MOD.skyPreset.actions.onToggle = function(on)
    if not on then return end
    currentSkyPreset = math.floor(MOD.skyPreset.slider.value)
    if MOD.customSky.enabled then
        applySkyPreset(currentSkyPreset)
        Lighting.ClockTime = MOD.customSky.slider.value
    end
end
MOD.skyPreset.actions.onChange = function(v)
    currentSkyPreset = math.floor(v)
    if not MOD.customSky.enabled then return end
    applySkyPreset(currentSkyPreset)
    Lighting.ClockTime = MOD.customSky.slider.value
end

-- =========================================================
-- CHINA HAT
-- =========================================================
local chinaParts = {}
local chinaPointLight = nil

local function destroyChinaHat()
    for _, p in ipairs(chinaParts) do if p and p.Parent then p:Destroy() end end
    chinaParts = {}; chinaPointLight = nil
end

local function buildChinaHat()
    destroyChinaHat()
    local layers = {
        { y = 0.00, r = 1.55, t = 0.10 }, { y = 0.07, r = 1.45, t = 0.10 },
        { y = 0.14, r = 1.32, t = 0.10 }, { y = 0.21, r = 1.18, t = 0.10 },
        { y = 0.28, r = 1.03, t = 0.10 }, { y = 0.35, r = 0.87, t = 0.10 },
        { y = 0.42, r = 0.70, t = 0.10 }, { y = 0.49, r = 0.53, t = 0.10 },
        { y = 0.56, r = 0.37, t = 0.10 }, { y = 0.63, r = 0.22, t = 0.10 },
        { y = 0.70, r = 0.10, t = 0.12 },
    }

    local neonVal  = MOD.chinaHat.sliders[2] and MOD.chinaHat.sliders[2].value or 100
    local lightVal = MOD.chinaHat.sliders[3] and MOD.chinaHat.sliders[3].value or 4
    local transparency = 1 - (neonVal / 100) * 0.95

    for _, layer in ipairs(layers) do
        local p = Instance.new("Part")
        p.Shape = Enum.PartType.Cylinder
        p.Material = Enum.Material.Neon
        p.Color = ACCENT
        p.Size = Vector3.new(layer.t, layer.r * 2, layer.r * 2)
        p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
        p.Anchored = true; p.CastShadow = false; p.Massless = true
        p.Transparency = transparency
        p.LightInfluence = 0
        p.Parent = Workspace
        table.insert(chinaParts, { part = p, offsetY = layer.y })
    end

    chinaPointLight = Instance.new("PointLight")
    chinaPointLight.Color = ACCENT
    chinaPointLight.Brightness = lightVal
    chinaPointLight.Range = lightVal * 6
    chinaPointLight.Shadows = false
    chinaPointLight.Parent = chinaParts[#chinaParts].part
end

MOD.chinaHat.actions.onToggle = function(on)
    if on then buildChinaHat() else destroyChinaHat() end
end
MOD.chinaHat.actions.onSliderChange = function(idx, v)
    if idx == 2 then
        local transparency = 1 - (v / 100) * 0.95
        for _, entry in ipairs(chinaParts) do
            entry.part.Transparency = transparency
            entry.part.Color = ACCENT
        end
        if chinaPointLight then
            chinaPointLight.Brightness = (v / 100) * 8
            chinaPointLight.Color = ACCENT
        end
    elseif idx == 3 then
        if chinaPointLight then chinaPointLight.Range = v * 6 end
    end
end

RunService.Heartbeat:Connect(function()
    if not MOD.chinaHat.enabled then return end
    local head = CACHE.head
    if not head then return end
    if not chinaParts[1] or not chinaParts[1].part.Parent then
        buildChinaHat(); return
    end
    local dist = MOD.chinaHat.sliders[1] and MOD.chinaHat.sliders[1].value or 1.6
    local neonVal = MOD.chinaHat.sliders[2] and MOD.chinaHat.sliders[2].value or 100
    local transparency = 1 - (neonVal / 100) * 0.95
    local t = tick()
    local baseCF = head.CFrame * CFrame.new(0, dist + math.sin(t * 2) * 0.06, 0)
        * CFrame.Angles(0, t * 0.8, math.rad(90))
    for _, entry in ipairs(chinaParts) do
        entry.part.CFrame = baseCF * CFrame.new(entry.offsetY, 0, 0)
        entry.part.Color = ACCENT
        entry.part.Transparency = transparency
    end
    if chinaPointLight then chinaPointLight.Color = ACCENT end
end)

-- =========================================================
-- TIME CHANGER
-- =========================================================
MOD.timeChanger.actions.onToggle = function(on)
    if on then Lighting.ClockTime = MOD.timeChanger.slider.value
    else pcall(function() Lighting.ClockTime = originalLighting.ClockTime end) end
end
MOD.timeChanger.actions.onChange = function(v)
    if not MOD.timeChanger.enabled then return end
    Lighting.ClockTime = v
end

-- =========================================================
-- DAMAGE INDICATOR
-- =========================================================
local damageIndGui = Instance.new("ScreenGui")
damageIndGui.Name = "DesolateDmg"
damageIndGui.ResetOnSpawn = false; damageIndGui.IgnoreGuiInset = true
damageIndGui.DisplayOrder = 997
if gethui then local ok, h = pcall(gethui); if ok and h then damageIndGui.Parent = h end end
if not damageIndGui.Parent then
    local ok = pcall(function() damageIndGui.Parent = game:GetService("CoreGui") end)
    if not ok or not damageIndGui.Parent then damageIndGui.Parent = player:WaitForChild("PlayerGui") end
end

local lastHealth = nil
local healthConn = nil
local function showDamageIndicator(dmg)
    local lbl = Instance.new("TextLabel")
    lbl.AnchorPoint = Vector2.new(0.5, 0.5)
    lbl.Position = UDim2.new(0.5, math.random(-30, 30), 0.5, 30)
    lbl.Size = UDim2.new(0, 200, 0, 30)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 18
    lbl.TextStrokeTransparency = 0.4
    lbl.TextColor3 = Color3.fromRGB(255, 80, 80)
    lbl.Text = "-" .. dmg
    lbl.Parent = damageIndGui
    TweenService:Create(lbl, TweenInfo.new(0.8), {
        Position = UDim2.new(0.5, lbl.Position.X.Offset, 0.5, -20),
        TextTransparency = 1, TextStrokeTransparency = 1,
    }):Play()
    task.delay(0.9, function() if lbl and lbl.Parent then lbl:Destroy() end end)
end

MOD.damageInd.actions.onToggle = function(on)
    if on then
        healthConn = RunService.Heartbeat:Connect(function()
            local hum = CACHE.humanoid
            if not hum then return end
            if lastHealth == nil then lastHealth = hum.Health; return end
            if hum.Health < lastHealth then
                local dmg = math.floor(lastHealth - hum.Health)
                if dmg > 0 then showDamageIndicator(dmg) end
            end
            lastHealth = hum.Health
        end)
    else
        if healthConn then healthConn:Disconnect(); healthConn = nil end
        lastHealth = nil
    end
end

-- =========================================================
-- TARGET HUD
-- =========================================================
local targetHud = Instance.new("Frame")
targetHud.Size = UDim2.new(0, 220, 0, 70)
targetHud.Position = UDim2.new(0.5, 40, 0.5, 40)
targetHud.BackgroundColor3 = BG2
targetHud.BackgroundTransparency = 0.1
targetHud.BorderSizePixel = 0
targetHud.Visible = false; targetHud.Parent = hudGui
Instance.new("UICorner", targetHud).CornerRadius = UDim.new(0, 8)

local thName = Instance.new("TextLabel")
thName.BackgroundTransparency = 1; thName.Position = UDim2.new(0, 10, 0, 4)
thName.Size = UDim2.new(1, -14, 0, 18); thName.Font = FONT
thName.TextSize = 13; thName.TextColor3 = TEXT
thName.TextXAlignment = Enum.TextXAlignment.Left
thName.Text = "Target"; thName.Parent = targetHud

local thInfo = Instance.new("TextLabel")
thInfo.BackgroundTransparency = 1; thInfo.Position = UDim2.new(0, 10, 0, 22)
thInfo.Size = UDim2.new(1, -14, 0, 14); thInfo.Font = FONT
thInfo.TextSize = 11; thInfo.TextColor3 = MUTED
thInfo.TextXAlignment = Enum.TextXAlignment.Left
thInfo.Text = "HP: -- | --m"; thInfo.Parent = targetHud

local thBarBg = Instance.new("Frame")
thBarBg.Position = UDim2.new(0, 10, 1, -16)
thBarBg.Size = UDim2.new(1, -20, 0, 6)
thBarBg.BackgroundColor3 = BG4
thBarBg.BorderSizePixel = 0; thBarBg.Parent = targetHud
Instance.new("UICorner", thBarBg).CornerRadius = UDim.new(0, 6)

local thBar = Instance.new("Frame")
thBar.Size = UDim2.new(1, 0, 1, 0)
thBar.BackgroundColor3 = ERROR
thBar.BorderSizePixel = 0; thBar.Parent = thBarBg
Instance.new("UICorner", thBar).CornerRadius = UDim.new(0, 6)

MOD.targetHUD.actions.onToggle = function(on) targetHud.Visible = on end
makeDraggable(targetHud, "targethud")

local function getTarget()
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = { CACHE.character, Camera }
    params.FilterType = Enum.RaycastFilterType.Exclude
    local result = Workspace:Raycast(Camera.CFrame.Position, Camera.CFrame.LookVector * 300, params)
    if result and result.Instance then
        local model = result.Instance:FindFirstAncestorOfClass("Model")
        if model then
            local hum = model:FindFirstChildOfClass("Humanoid")
            local plr = Players:GetPlayerFromCharacter(model)
            if hum and plr then return plr, hum end
        end
    end
    return nil
end

-- =========================================================
-- FPS
-- =========================================================
local fps = 0
local frames = 0
local t0 = tick()
RunService.RenderStepped:Connect(function()
    frames += 1
    local now = tick()
    if now - t0 >= 1 then fps = frames; frames = 0; t0 = now end
end)

-- =========================================================
-- MAIN LOOP
-- =========================================================
task.spawn(function()
    local tickCount = 0
    while gui.Parent do
        tickCount += 1

        if not CACHE.character or not CACHE.hrp or not CACHE.head then
            refreshCharacterCache()
        end

        if MOD.watermark.enabled then
            local ping = 0
            pcall(function() ping = math.floor(player:GetNetworkPing() * 1000) end)
            wLabel.Text = string.format("Desolate %s | FPS: %d | PING: %d",
                player.Name, fps, ping)
        end

        if MOD.coords.enabled and CACHE.hrp then
            coordLabel.Text = string.format("X: %.1f Y: %.1f Z: %.1f",
                CACHE.hrp.Position.X, CACHE.hrp.Position.Y, CACHE.hrp.Position.Z)
        end

        if tickCount % 2 == 0 then
            if MOD.nameTags.enabled then
                for plr, data in pairs(nametags) do
                    if not plr or not plr.Parent then
                        if data.gui then data.gui:Destroy() end; nametags[plr] = nil
                    elseif plr.Character and CACHE.hrp then
                        local hum = plr.Character:FindFirstChildOfClass("Humanoid")
                        local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
                        if hum and hrp then
                            local dist = (hrp.Position - CACHE.hrp.Position).Magnitude
                            local sync = isSyncUser(plr)
                            local prefix = sync and "* " or ""
                            data.name.Text = prefix .. plr.Name
                            data.name.TextColor3 = sync and SYNC_COLOR or ACCENT
                            data.info.Text = string.format("HP: %d/%d | %dm", math.floor(hum.Health), math.floor(hum.MaxHealth), math.floor(dist))
                            local pct = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                            data.hbar.Size = UDim2.new(pct, 0, 1, 0)
                            data.hbar.BackgroundColor3 = pct > 0.5 and OK
                                or pct > 0.25 and Color3.fromRGB(255, 220, 100) or ERROR
                        end
                    end
                end
            end

            if MOD.esp.enabled then
                for plr, hl in pairs(espHighlights) do
                    if not plr or not plr.Character or not plr.Character.Parent then
                        if hl then hl:Destroy() end; espHighlights[plr] = nil
                    elseif hl and hl.Adornee ~= plr.Character then
                        hl.Adornee = plr.Character
                    end
                end
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= player and plr.Character then
                        local hl = espHighlights[plr]
                        if not hl then
                            hl = Instance.new("Highlight")
                            hl.Name = "DesolateESP"; hl.Adornee = plr.Character
                            hl.FillTransparency = 0.65; hl.OutlineTransparency = 0
                            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                            hl.Parent = plr.Character
                            espHighlights[plr] = hl
                        end
                        if isSyncUser(plr) then
                            hl.FillColor = SYNC_COLOR
                            hl.OutlineColor = Color3.fromRGB(120, 255, 150)
                        else
                            hl.FillColor = Color3.fromRGB(255, 60, 60)
                            hl.OutlineColor = ACCENT
                        end
                    end
                end
            end

            if MOD.targetHUD.enabled then
                local plr, hum = getTarget()
                if plr and hum then
                    local hrp = hum.Parent:FindFirstChild("HumanoidRootPart")
                    local dist = 0
                    if hrp and CACHE.hrp then
                        dist = (hrp.Position - CACHE.hrp.Position).Magnitude
                    end
                    local sync = isSyncUser(plr)
                    thName.Text = (sync and "* " or "") .. plr.Name
                    thName.TextColor3 = sync and SYNC_COLOR or TEXT
                    thInfo.Text = string.format("HP: %d/%d | %dm", math.floor(hum.Health), math.floor(hum.MaxHealth), math.floor(dist))
                    local pct = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                    thBar.Size = UDim2.new(pct, 0, 1, 0)
                    thBar.BackgroundColor3 = pct > 0.5 and OK
                        or pct > 0.25 and Color3.fromRGB(255, 220, 100) or ERROR
                else
                    thName.Text = "No target"; thInfo.Text = "---"
                    thBar.Size = UDim2.new(0, 0, 1, 0)
                end
            end
        end

        task.wait(0.05)
    end
end)

-- =========================================================
-- FULLBRIGHT
-- =========================================================
MOD.fullbright.actions.onToggle = function(on)
    if on then
        Lighting.Ambient = Color3.fromRGB(200, 200, 200)
        Lighting.OutdoorAmbient = Color3.fromRGB(200, 200, 200)
        Lighting.Brightness = 3
    else
        Lighting.Ambient = originalLighting.Ambient
        Lighting.OutdoorAmbient = originalLighting.OutdoorAmbient
        Lighting.Brightness = originalLighting.Brightness
    end
end

-- =========================================================
-- PLAYER
-- =========================================================
RunService.Heartbeat:Connect(function()
    local hum = CACHE.humanoid
    if not hum then return end
    if MOD.walkSpeed.enabled then hum.WalkSpeed = MOD.walkSpeed.slider.value end
    if MOD.jumpPower.enabled then
        hum.UseJumpPower = true
        hum.JumpPower = MOD.jumpPower.slider.value
    end
end)

local flyBV, flyBG
MOD.fly.actions.onToggle = function(on)
    local hrp = CACHE.hrp
    if not hrp then return end
    if on then
        flyBV = Instance.new("BodyVelocity")
        flyBV.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        flyBV.Velocity = Vector3.new(0, 0, 0); flyBV.Parent = hrp
        flyBG = Instance.new("BodyGyro")
        flyBG.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        flyBG.CFrame = hrp.CFrame; flyBG.Parent = hrp
    else
        if flyBV then flyBV:Destroy(); flyBV = nil end
        if flyBG then flyBG:Destroy(); flyBG = nil end
    end
end

RunService.Heartbeat:Connect(function()
    if not MOD.fly.enabled or not flyBV or not flyBG then return end
    local speed = MOD.fly.slider.value
    local move = Vector3.new(0, 0, 0)
    local camCF = Camera.CFrame
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then move += camCF.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then move -= camCF.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then move -= camCF.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += camCF.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.new(0, 1, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then move -= Vector3.new(0, 1, 0) end
    if move.Magnitude > 0 then move = move.Unit * speed end
    flyBV.Velocity = move; flyBG.CFrame = camCF
end)

MOD.bunnyHop.actions.onToggle = function(on) end
RunService.Heartbeat:Connect(function()
    if not MOD.bunnyHop.enabled then return end
    local hum = CACHE.humanoid
    if not hum then return end
    local vel = hum.RootPart and hum.RootPart.Velocity or Vector3.new(0, 0, 0)
    if vel.Magnitude > 2 and hum.FloorMaterial ~= Enum.Material.Air then
        hum.Jump = true
    end
end)

MOD.reach.actions.onChange = function(v)
    if not MOD.reach.enabled then return end
    pcall(function() player.Reach = v end)
end
MOD.reach.actions.onToggle = function(on)
    pcall(function() player.Reach = on and MOD.reach.slider.value or 10 end)
end

local originalFOV = Camera.FieldOfView
MOD.fov.actions.onToggle = function(on)
    Camera.FieldOfView = on and MOD.fov.slider.value or originalFOV
end
MOD.fov.actions.onChange = function(v)
    if not MOD.fov.enabled then return end
    Camera.FieldOfView = v
end

-- =========================================================
-- KILL EFFECT
-- =========================================================
local killGui = Instance.new("ScreenGui")
killGui.Name = "DesolateKill"
killGui.ResetOnSpawn = false; killGui.IgnoreGuiInset = true
killGui.DisplayOrder = 996
if gethui then local ok, h = pcall(gethui); if ok and h then killGui.Parent = h end end
if not killGui.Parent then
    local ok = pcall(function() killGui.Parent = game:GetService("CoreGui") end)
    if not ok or not killGui.Parent then killGui.Parent = player:WaitForChild("PlayerGui") end
end

local function showKillEffect(victimName)
    local lbl = Instance.new("TextLabel")
    lbl.AnchorPoint = Vector2.new(0.5, 0.5)
    lbl.Position = UDim2.new(0.5, 0, 0.4, 0)
    lbl.Size = UDim2.new(0, 400, 0, 60)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamBlack; lbl.TextSize = 36
    lbl.TextColor3 = ACCENT; lbl.TextStrokeTransparency = 0.3
    lbl.Text = "KILLED " .. victimName
    lbl.Parent = killGui
    TweenService:Create(lbl, TweenInfo.new(1.2), {
        Position = UDim2.new(0.5, 0, 0.3, 0),
        TextTransparency = 1, TextStrokeTransparency = 1,
    }):Play()
    task.delay(1.3, function() if lbl and lbl.Parent then lbl:Destroy() end end)
end

local killEffectMod = findMod("Player", "Kill Effect")
killEffectMod.actions.onToggle = function(on) end
Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function(char)
        local hum = char:WaitForChild("Humanoid", 5)
        if not hum then return end
        hum.Died:Connect(function()
            if not killEffectMod.enabled then return end
            local myHrp = CACHE.hrp
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if not myHrp or not hrp then return end
            if (myHrp.Position - hrp.Position).Magnitude < 60 then
                showKillEffect(plr.Name)
            end
        end)
    end)
end)

-- =========================================================
-- MISC
-- =========================================================
MOD.antiAFK.actions.onToggle = function(on)
    if on then
        if not _G.Desolate_AntiAFK then
            _G.Desolate_AntiAFK = player.Idled:Connect(function()
                pcall(function()
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new())
                end)
            end)
        end
    else
        if _G.Desolate_AntiAFK then _G.Desolate_AntiAFK:Disconnect(); _G.Desolate_AntiAFK = nil end
    end
end

MOD.noclip.actions.onToggle = function(on)
    if on then
        if _G.Desolate_Noclip then _G.Desolate_Noclip:Disconnect() end
        _G.Desolate_Noclip = RunService.Stepped:Connect(function()
            local char = CACHE.character
            if not char then return end
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
            end
        end)
    else
        if _G.Desolate_Noclip then _G.Desolate_Noclip:Disconnect(); _G.Desolate_Noclip = nil end
        local char = CACHE.character
        if char then
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
                    pcall(function() p.CanCollide = true end)
                end
            end
        end
    end
end

MOD.autoClicker.actions.onToggle = function(on) end
RunService.Heartbeat:Connect(function()
    if not MOD.autoClicker.enabled then return end
    local cps = MOD.autoClicker.slider.value
    local interval = 1 / math.max(cps, 1)
    if math.random() < math.min(interval, 1) then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton1(Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2))
        end)
    end
end)

MOD.serverHop.actions.onToggle = function(on)
    if not on then return end
    task.spawn(function()
        local placeId = game.PlaceId
        local url = "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100"
        local ok, body = pcall(function() return game:HttpGet(url) end)
        if not ok or not body then MOD.serverHop.enabled = false; return end
        local data = HttpService:JSONDecode(body)
        if data and data.data then
            for _, srv in ipairs(data.data) do
                if srv.playing < srv.maxPlayers and srv.id ~= game.JobId then
                    pcall(function()
                        TeleportService:TeleportToPlaceInstance(placeId, srv.id, player)
                    end)
                    break
                end
            end
        end
        MOD.serverHop.enabled = false
    end)
end

MOD.resetHUDPos.actions.onToggle = function(on)
    if not on then return end
    for _, f in ipairs({
        "desolate_hud_watermark.txt", "desolate_hud_coords.txt",
        "desolate_hud_targethud.txt",
    }) do
        pcall(function() if isfile(f) then delfile(f) end end)
    end
    watermark.Position = UDim2.new(0, 10, 0, 10)
    coordFrame.Position = UDim2.new(0, 10, 0, 60)
    targetHud.Position = UDim2.new(0.5, 40, 0.5, 40)
    task.spawn(function()
        task.wait(0.3); MOD.resetHUDPos.enabled = false; refreshModules()
    end)
end

function applyLoadedModules()
    for cat, list in pairs(state) do
        for _, mod in ipairs(list) do
            if not mod.isHeader and mod.actions.onToggle then
                pcall(mod.actions.onToggle, mod.enabled)
            end
        end
    end
end

-- =========================================================
-- DRAG MAIN + MOBILE + OPEN KEY
-- =========================================================
do
    local dragging, dragStart, startPos
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = main.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
           or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            if subMenu.Visible then subMenu.Position = main.Position end
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
end

local mobileBtn = Instance.new("TextButton")
mobileBtn.Size = UDim2.new(0, 44, 0, 44)
mobileBtn.Position = UDim2.new(0, 10, 0.5, -22)
mobileBtn.BackgroundColor3 = BG2; mobileBtn.TextColor3 = ACCENT
mobileBtn.Font = FONT; mobileBtn.TextSize = 16; mobileBtn.Text = "D"
mobileBtn.BorderSizePixel = 0; mobileBtn.Parent = gui
Instance.new("UICorner", mobileBtn).CornerRadius = UDim.new(0, 22)
local mStroke = Instance.new("UIStroke")
mStroke.Color = ACCENT; mStroke.Thickness = 1; mStroke.Transparency = 0.4
mStroke.Parent = mobileBtn

mobileBtn.MouseButton1Click:Connect(function() main.Visible = not main.Visible end)
main:GetPropertyChangedSignal("Visible"):Connect(function()
    mobileBtn.Visible = not main.Visible
end)

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == OPEN_KEY then main.Visible = not main.Visible end
end)

-- =========================================================
-- INIT
-- =========================================================
loadConfig()
refreshCategories()
refreshModules()

if currentTheme ~= "Dark" then
    local th = THEMES[currentTheme]
    if th then
        ACCENT = th.accent
        BG = th.bg; BG2 = th.bg2; BG3 = th.bg3; BG4 = th.bg4
        TEXT = th.text; MUTED = th.muted
        applyStaticColors()
        refreshCategories(); refreshModules()
    end
end

applyLoadedModules()

watermark.Visible = MOD.watermark.enabled
crosshair.Visible = MOD.crosshair.enabled

syncPing()
syncFetch()

print("[Desolate] v" .. VERSION .. " loaded - " .. player.Name)
