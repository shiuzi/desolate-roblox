-- Desolate Client v4.3.2
-- Fixed: Out of local registers (REFS table)

local VERSION = "4.3.2"

local AUTH_URL  = "https://desolate-auth.desolate-ezi.workers.dev"
local KEY_FILE  = "desolate_key.txt"
local HWID_FILE = "desolate_hwid.txt"
local CONFIG_FILE = "desolate_config.json"

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local VirtualUser = game:GetService("VirtualUser")
local TeleportService = game:GetService("TeleportService")
local Camera = Workspace.CurrentCamera

local player = Players.LocalPlayer
local REFS = {}

-- =========================================================
-- CACHE
-- =========================================================
local CACHE = { character = nil, hrp = nil, humanoid = nil, head = nil, isAlive = false }
local function refreshCharacterCache()
    local char = player.Character
    if not char then
        CACHE.character, CACHE.hrp, CACHE.humanoid, CACHE.head, CACHE.isAlive = nil, nil, nil, nil, false
        return
    end
    CACHE.character = char
    CACHE.humanoid = char:FindFirstChildOfClass("Humanoid")
    CACHE.hrp = char:FindFirstChild("HumanoidRootPart")
    CACHE.head = char:FindFirstChild("Head")
    CACHE.isAlive = CACHE.humanoid and CACHE.hrp and CACHE.humanoid.Health > 0
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
    if type(isfile) == "function" and type(readfile) == "function" and isfile(HWID_FILE) then
        local ok, cached = pcall(readfile, HWID_FILE)
        if ok and cached and #cached > 0 then return cached end
    end
    local exec = "unknown"
    if type(identifyexecutor) == "function" then
        local ok, name = pcall(identifyexecutor)
        if ok and name then exec = tostring(name) end
    end
    local seed = exec .. "|" .. tostring(player.UserId) .. "|desolate_v4"
    local h = 0
    for i = 1, #seed do h = (h * 31 + seed:byte(i)) % (2 ^ 32) end
    local id = string.format("fb_%s_%08x", exec:lower():gsub("%W", ""), h)
    if type(writefile) == "function" then pcall(writefile, HWID_FILE, id) end
    return id
end

-- =========================================================
-- FS
-- =========================================================
local fs = { available = (type(writefile) == "function") and (type(readfile) == "function") and (type(isfile) == "function") and (type(delfile) == "function") }
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
    if type(request) == "function" then
        local ok, res = pcall(function()
            return request({ Url = url, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = payload })
        end)
        if ok and res and res.Body then return res.Body end
    end
    if type(http_request) == "function" then
        local ok, res = pcall(function()
            return http_request({ Url = url, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = payload })
        end)
        if ok and res and res.Body then return res.Body end
    end
    return nil
end

local function validateKey(key)
    local response = httpPost(AUTH_URL, { userid = tostring(player.UserId), hwid = getHwid(), key = key })
    if not response then return false, "Server offline." end
    local ok, data = pcall(function() return HttpService:JSONDecode(response) end)
    if not ok or type(data) ~= "table" then return false, "Bad response." end
    if not data.valid then
        local reasons = { invalid_key = "Invalid key", expired = "Key expired", banned = "Key banned", hwid_mismatch = "Bound to another device", userid_mismatch = "Bound to another account" }
        return false, reasons[data.reason] or ("Denied: " .. tostring(data.reason))
    end
    return true, data
end

-- =========================================================
-- AUTH UI
-- =========================================================
local function showKeyUI(opts)
    local A, BG_, BG2_ = Color3.fromRGB(0, 200, 230), Color3.fromRGB(6, 6, 10), Color3.fromRGB(14, 14, 20)
    local TX, MU = Color3.fromRGB(200, 200, 210), Color3.fromRGB(100, 100, 115)
    local ER, OK_ = Color3.fromRGB(255, 60, 60), Color3.fromRGB(60, 255, 130)
    local F = Enum.Font.Code
    local sg = Instance.new("ScreenGui")
    sg.Name = "DesolateAuth_" .. math.random(1, 1e6)
    sg.ResetOnSpawn = false; sg.IgnoreGuiInset = true; sg.DisplayOrder = 1000
    if gethui then local ok, h = pcall(gethui); if ok and h then sg.Parent = h end end
    if not sg.Parent then local ok = pcall(function() sg.Parent = game:GetService("CoreGui") end); if not ok or not sg.Parent then sg.Parent = player:WaitForChild("PlayerGui") end end
    local box = Instance.new("Frame")
    box.Size = UDim2.new(0, 400, 0, 220); box.Position = UDim2.new(0.5, -200, 0.5, -110)
    box.BackgroundColor3 = BG_; box.BorderSizePixel = 0; box.Parent = sg
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 12)
    local st = Instance.new("UIStroke"); st.Color = A; st.Thickness = 1; st.Transparency = 0.5; st.Parent = box
    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1; title.Position = UDim2.new(0, 14, 0, 12); title.Size = UDim2.new(1, -28, 0, 22)
    title.Font = F; title.TextSize = 16; title.TextColor3 = A; title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = "Desolate - Activation"; title.Parent = box
    local ih = Instance.new("Frame")
    ih.Position = UDim2.new(0, 14, 0, 58); ih.Size = UDim2.new(1, -28, 0, 40)
    ih.BackgroundColor3 = BG2_; ih.BorderSizePixel = 0; ih.Parent = box
    Instance.new("UICorner", ih).CornerRadius = UDim.new(0, 8)
    local tb = Instance.new("TextBox")
    tb.Size = UDim2.new(1, -20, 1, 0); tb.Position = UDim2.new(0, 10, 0, 0)
    tb.BackgroundTransparency = 1; tb.Font = F; tb.TextSize = 14; tb.TextColor3 = TX
    tb.PlaceholderText = "DESO-XXXX-XXXX-XXXX"; tb.PlaceholderColor3 = MU
    tb.TextXAlignment = Enum.TextXAlignment.Left; tb.ClearTextOnFocus = false
    tb.Text = opts.initial or ""; tb.Parent = ih
    local status = Instance.new("TextLabel")
    status.BackgroundTransparency = 1; status.Position = UDim2.new(0, 14, 0, 108); status.Size = UDim2.new(1, -28, 0, 18)
    status.Font = F; status.TextSize = 12; status.TextColor3 = MU; status.TextXAlignment = Enum.TextXAlignment.Left; status.Parent = box
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -28, 0, 36); btn.Position = UDim2.new(0, 14, 1, -50)
    btn.BackgroundColor3 = A; btn.TextColor3 = Color3.fromRGB(6, 6, 10); btn.Font = F; btn.TextSize = 14
    btn.Text = "ACTIVATE"; btn.BorderSizePixel = 0; btn.AutoButtonColor = false; btn.Parent = box
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    local function tryActivate()
        local key = tb.Text:gsub("%s+", "")
        if #key < 6 then status.TextColor3 = ER; status.Text = "Key too short"; return end
        btn.Text = "CHECKING..."; btn.Active = false
        task.spawn(function()
            local ok, info = validateKey(key)
            if ok then
                status.TextColor3 = OK_; status.Text = "Activation success"
                fs.write(KEY_FILE, key); task.wait(0.5); sg:Destroy()
                if opts.onSuccess then opts.onSuccess(info) end
            else
                status.TextColor3 = ER; status.Text = tostring(info)
                btn.Text = "ACTIVATE"; btn.Active = true
            end
        end)
    end
    btn.MouseButton1Click:Connect(tryActivate)
    tb.FocusLost:Connect(function(e) if e then tryActivate() end end)
end

local authData = { plan = "lifetime", expires = nil }
local function requireAuth()
    local saved = fs.read(KEY_FILE)
    if saved and #saved >= 6 then
        local ok, info = validateKey(saved)
        if ok then authData.plan = info.plan or "lifetime"; authData.expires = info.expires; return true end
        fs.delete(KEY_FILE)
    end
    local done, success = false, false
    showKeyUI({ initial = saved or "", onSuccess = function(info) authData.plan = info.plan or "lifetime"; authData.expires = info.expires; done, success = true, true end })
    while not done do task.wait(0.1) end
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
local BG = THEMES.Dark.bg
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
    Combat = {
        { name = "Main", isHeader = true },
        { name = "Reach",  enabled = false, actions = {}, keybind = nil,
          slider = { min = 5, max = 50, value = 10 } },
        { name = "Noclip", enabled = false, actions = {}, keybind = nil },
        { name = "Anti-Fling", enabled = false, actions = {}, keybind = nil },
        { name = "Hitbox", enabled = false, actions = {}, keybind = nil,
          slider = { min = 1, max = 20, value = 6 } },
        { name = "Auto Parry", enabled = false, actions = {}, keybind = nil,
          sliders = {
            { label = "Radius",   min = 5,  max = 30, value = 12 },
            { label = "Cooldown", min = 30, max = 90, value = 50 },
          } },
    },
    Movement = {
        { name = "Main", isHeader = true },
        { name = "WalkSpeed", enabled = false, actions = {}, keybind = nil,
          slider = { min = 8, max = 200, value = 16 } },
        { name = "JumpPower", enabled = false, actions = {}, keybind = nil,
          slider = { min = 30, max = 300, value = 50 } },
        { name = "Fly",       enabled = false, actions = {}, keybind = nil,
          slider = { min = 10, max = 200, value = 60 } },
        { name = "Moonwalk",  enabled = false, actions = {}, keybind = nil },
    },
    Visual = {
        { name = "Environment", isHeader = true },
        { name = "Custom Sky",   enabled = false, actions = {}, keybind = nil,
          slider = { min = 0, max = 24, value = 12 } },
        { name = "Sky Preset",   enabled = false, actions = {}, keybind = nil,
          slider = { min = 1, max = 5, value = 4 } },
        { name = "Fog",          enabled = false, actions = {}, keybind = nil,
          slider = { min = 0, max = 500, value = 100 } },
        { name = "Time Changer", enabled = false, actions = {}, keybind = nil,
          slider = { min = 0, max = 24, value = 12 } },
        { name = "Fullbright",   enabled = false, actions = {}, keybind = nil,
          slider = { min = 1, max = 10, value = 5 } },
        { name = "Custom Skybox",enabled = false, actions = {}, keybind = nil,
          slider = { min = 1, max = 5, value = 1 } },

        { name = "Effects",      isHeader = true },
        { name = "JumpCircle",   enabled = false, actions = {}, keybind = nil },
        { name = "MoveCircle",   enabled = false, actions = {}, keybind = nil,
          sliders = {
            { label = "Size",    min = 1,   max = 10, value = 3 },
            { label = "Fade",    min = 0.1, max = 2,  value = 0.8 },
            { label = "Spacing", min = 0.5, max = 5,  value = 2 },
          } },
        { name = "Trails",       enabled = false, actions = {}, keybind = nil,
          sliders = {
            { label = "Length", min = 0.1, max = 3, value = 0.6 },
            { label = "Fade",   min = 0,   max = 1, value = 0.8 },
            { label = "Mode",   min = 1,   max = 2, value = 1 },
          } },
        { name = "Particles",    enabled = false, actions = {}, keybind = nil,
          sliders = {
            { label = "Rate",  min = 1, max = 50, value = 12 },
            { label = "Speed", min = 5, max = 50, value = 18 },
            { label = "Size",  min = 1, max = 10, value = 3 },
          } },
        { name = "Damage Ind",   enabled = false, actions = {}, keybind = nil },
        { name = "Kill Effect",  enabled = false, actions = {}, keybind = nil },
        { name = "Kill Sound",   enabled = false, actions = {}, keybind = nil,
          sliders = {
            { label = "Volume",   min = 1, max = 10, value = 5 },
            { label = "MaxDist",  min = 10, max = 500, value = 60 },
          } },
        { name = "BulletTracer", enabled = false, actions = {}, keybind = nil },
        { name = "ChinaHat",     enabled = false, actions = {}, keybind = nil,
          slider = { min = 1, max = 5, value = 2 } },

        { name = "Overlay",      isHeader = true },
        { name = "Draw FOV",     enabled = false, actions = {}, keybind = nil,
          slider = { min = 1, max = 30, value = 15 } },
        { name = "ESP",          enabled = false, actions = {}, keybind = nil },
        { name = "NameTags",     enabled = false, actions = {}, keybind = nil },
        { name = "Skeleton ESP", enabled = false, actions = {}, keybind = nil,
          sliders = {
            { label = "Thickness", min = 1,  max = 5,   value = 2 },
            { label = "Dist",      min = 20, max = 500, value = 200 },
          } },
    },
    Misc = {
        { name = "Utility",       isHeader = true },
        { name = "Camera",        enabled = false, actions = {}, keybind = nil },
        { name = "FOV",           enabled = false, actions = {}, keybind = nil,
          slider = { min = 40, max = 140, value = 70 } },
        { name = "Show Desolate Users", enabled = false, actions = {}, keybind = nil },
        { name = "ServerHop",     enabled = false, actions = {}, keybind = nil },
        { name = "Reset HUD Pos", enabled = false, actions = {}, keybind = nil },
        { name = "Spectate",      enabled = false, actions = {}, keybind = nil,
          slider = { min = 1, max = 50, value = 1 } },
        { name = "PlayerList",    enabled = false, actions = {}, keybind = nil },
        { name = "FPS Unlock",    enabled = false, actions = {}, keybind = nil },
        { name = "Ping Spoof",    enabled = false, actions = {}, keybind = nil,
          slider = { min = 10, max = 500, value = 20 } },
        { name = "Anti-AFK",      enabled = false, actions = {}, keybind = nil },
    },
    HUD = {
        { name = "Info",          isHeader = true },
        { name = "Watermark",     enabled = true,  actions = {}, keybind = nil },
        { name = "Coordinates",   enabled = false, actions = {}, keybind = nil },
        { name = "TargetHUD",     enabled = false, actions = {}, keybind = nil },
        { name = "Crosshair",     enabled = false, actions = {}, keybind = nil },
        { name = "Keybind Display", isHeader = true },
        { name = "KeyBinds",      enabled = false, actions = {}, keybind = nil },
    },
    Keybind = { { name = "Bound Keys", isHeader = true } },
}

local CATEGORY_ORDER = { "Combat", "Movement", "Visual", "Misc", "HUD", "Keybind" }

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
    MOD.reach = findMod("Combat", "Reach")
    MOD.noclip = findMod("Combat", "Noclip")
    MOD.antiFling = findMod("Combat", "Anti-Fling")
    MOD.hitbox = findMod("Combat", "Hitbox")
    MOD.autoParry = findMod("Combat", "Auto Parry")
    MOD.walkSpeed = findMod("Movement", "WalkSpeed")
    MOD.jumpPower = findMod("Movement", "JumpPower")
    MOD.fly = findMod("Movement", "Fly")
    MOD.moonwalk = findMod("Movement", "Moonwalk")
    MOD.customSky = findMod("Visual", "Custom Sky")
    MOD.skyPreset = findMod("Visual", "Sky Preset")
    MOD.fog = findMod("Visual", "Fog")
    MOD.timeChanger = findMod("Visual", "Time Changer")
    MOD.fullbright = findMod("Visual", "Fullbright")
    MOD.customSkybox = findMod("Visual", "Custom Skybox")
    MOD.jumpCircle = findMod("Visual", "JumpCircle")
    MOD.moveCircle = findMod("Visual", "MoveCircle")
    MOD.trails = findMod("Visual", "Trails")
    MOD.particles = findMod("Visual", "Particles")
    MOD.damageInd = findMod("Visual", "Damage Ind")
    MOD.killEffect = findMod("Visual", "Kill Effect")
    MOD.killSound = findMod("Visual", "Kill Sound")
    MOD.bulletTracer = findMod("Visual", "BulletTracer")
    MOD.chinaHat = findMod("Visual", "ChinaHat")
    MOD.drawFov = findMod("Visual", "Draw FOV")
    MOD.esp = findMod("Visual", "ESP")
    MOD.nameTags = findMod("Visual", "NameTags")
    MOD.skeleton = findMod("Visual", "Skeleton ESP")
    MOD.camera = findMod("Misc", "Camera")
    MOD.fov = findMod("Misc", "FOV")
    MOD.showUsers = findMod("Misc", "Show Desolate Users")
    MOD.serverHop = findMod("Misc", "ServerHop")
    MOD.resetHUDPos = findMod("Misc", "Reset HUD Pos")
    MOD.spectate = findMod("Misc", "Spectate")
    MOD.playerList = findMod("Misc", "PlayerList")
    MOD.fpsUnlock = findMod("Misc", "FPS Unlock")
    MOD.pingSpoof = findMod("Misc", "Ping Spoof")
    MOD.antiAfk = findMod("Misc", "Anti-AFK")
    MOD.watermark = findMod("HUD", "Watermark")
    MOD.coords = findMod("HUD", "Coordinates")
    MOD.targetHUD = findMod("HUD", "TargetHUD")
    MOD.crosshair = findMod("HUD", "Crosshair")
    MOD.keyBinds = findMod("HUD", "KeyBinds")
end

local function getBoundModules()
    local out = {}
    for cat, list in pairs(state) do
        if cat ~= "Keybind" then
            for _, mod in ipairs(list) do
                if not mod.isHeader and mod.keybind then
                    table.insert(out, { mod = mod, cat = cat })
                end
            end
        end
    end
    return out
end

-- =========================================================
-- SYNC
-- =========================================================
REFS.syncSet = {}
local gui
local function syncPing()
    task.spawn(function()
        while gui and gui.Parent do
            if MOD.showUsers and MOD.showUsers.enabled then
                pcall(function() httpPost(AUTH_URL .. "/sync", { action = "ping", userid = tostring(player.UserId), jobId = tostring(game.JobId) }) end)
            end
            task.wait(25)
        end
    end)
end
local function syncFetch()
    task.spawn(function()
        while gui and gui.Parent do
            if MOD.showUsers and MOD.showUsers.enabled then
                local body = httpPost(AUTH_URL .. "/sync", { action = "list", jobId = tostring(game.JobId) })
                if body then
                    local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
                    if ok and data and data.users then
                        local ns = {}
                        for _, id in ipairs(data.users) do ns[tostring(id)] = true end
                        REFS.syncSet = ns
                    end
                end
            else
                REFS.syncSet = {}
            end
            task.wait(20)
        end
    end)
end
local function isSyncUser(plr) return REFS.syncSet[tostring(plr.UserId)] == true end

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
                if mod.keybind then entry.keybind = mod.keybind.Name end
                if mod.mode then entry.mode = mod.mode end
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
                        if saved.keybind then
                            local kb = Enum.KeyCode[saved.keybind]
                            if kb then mod.keybind = kb end
                        end
                        if saved.mode then mod.mode = saved.mode end
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
        if cat ~= "Keybind" then
            for _, mod in ipairs(list) do
                if not mod.isHeader then
                    mod.enabled = false
                    mod.keybind = nil
                    mod.mode = "toggle"
                    if mod.slider then mod.slider.value = (mod.slider.min + mod.slider.max) / 2 end
                    if mod.sliders then
                        for _, s in ipairs(mod.sliders) do s.value = (s.min + s.max) / 2 end
                    end
                end
            end
        end
    end
end

-- =========================================================
-- GUI ROOT
-- =========================================================
gui = Instance.new("ScreenGui")
gui.Name = "Desolate_" .. math.random(1, 1e6)
gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true; gui.DisplayOrder = 999
if gethui then local ok, h = pcall(gethui); if ok and h then gui.Parent = h end end
if not gui.Parent then local ok = pcall(function() gui.Parent = game:GetService("CoreGui") end); if not ok or not gui.Parent then gui.Parent = player:WaitForChild("PlayerGui") end end

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 500, 0, 400)
main.Position = UDim2.new(0.5, -250, 0.5, -200)
main.BackgroundColor3 = BG; main.BorderSizePixel = 0
main.Active = true; main.Visible = false; main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)

local stroke = Instance.new("UIStroke")
stroke.Color = ACCENT; stroke.Thickness = 1; stroke.Transparency = 0.6; stroke.Parent = main

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 36)
header.BackgroundColor3 = BG2; header.BorderSizePixel = 0; header.Parent = main
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 12)
local hMask = Instance.new("Frame")
hMask.Size = UDim2.new(1, 0, 0, 10); hMask.Position = UDim2.new(0, 0, 1, -10)
hMask.BackgroundColor3 = BG2; hMask.BorderSizePixel = 0; hMask.Parent = header

local titleLbl = Instance.new("TextLabel")
titleLbl.BackgroundTransparency = 1
titleLbl.Position = UDim2.new(0, 14, 0, 0); titleLbl.Size = UDim2.new(1, -170, 1, 0)
titleLbl.Font = FONT; titleLbl.TextSize = 14; titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.TextColor3 = ACCENT; titleLbl.Text = "Desolate v" .. VERSION; titleLbl.Parent = header

REFS.headerBtns = {}
local function makeHeaderBtn(text, xOff, onClick)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 26, 0, 24); b.Position = UDim2.new(1, xOff, 0, 6)
    b.BackgroundColor3 = BG4; b.TextColor3 = TEXT; b.Font = FONT; b.TextSize = 12
    b.Text = text; b.BorderSizePixel = 0; b.Parent = header
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    local s = Instance.new("UIStroke"); s.Color = ACCENT; s.Thickness = 1; s.Transparency = 0.85; s.Parent = b
    b.MouseButton1Click:Connect(function()
        local ok = onClick()
        b.TextColor3 = (ok ~= false) and OK or ERROR
        task.delay(0.4, function() b.TextColor3 = TEXT end)
    end)
    table.insert(REFS.headerBtns, b); return b
end

makeHeaderBtn("S", -110, function() return saveConfig() end)
makeHeaderBtn("L", -80, function() local ok = loadConfig(); refreshModules(); applyLoadedModules(); return ok end)
makeHeaderBtn("R", -50, function() resetConfig(); refreshModules(); applyLoadedModules(); return true end)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 22, 0, 24); closeBtn.Position = UDim2.new(1, -26, 0, 6)
closeBtn.BackgroundColor3 = BG4; closeBtn.TextColor3 = TEXT; closeBtn.Font = FONT; closeBtn.TextSize = 14
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
catList.Padding = UDim.new(0, 4); catList.SortOrder = Enum.SortOrder.LayoutOrder; catList.Parent = catPanel
local catPad = Instance.new("UIPadding")
catPad.PaddingTop = UDim.new(0, 6); catPad.PaddingLeft = UDim.new(0, 6); catPad.PaddingRight = UDim.new(0, 6); catPad.Parent = catPanel

local modPanel = Instance.new("Frame")
modPanel.Size = UDim2.new(1, -140, 1, -16); modPanel.Position = UDim2.new(0, 132, 0, 8)
modPanel.BackgroundColor3 = BG2; modPanel.BorderSizePixel = 0; modPanel.Parent = body
Instance.new("UICorner", modPanel).CornerRadius = UDim.new(0, 8)

local modScroll = Instance.new("ScrollingFrame")
modScroll.Size = UDim2.new(1, -8, 1, -8); modScroll.Position = UDim2.new(0, 4, 0, 4)
modScroll.BackgroundTransparency = 1; modScroll.BorderSizePixel = 0
modScroll.ScrollBarThickness = 3; modScroll.ScrollBarImageColor3 = ACCENT
modScroll.CanvasSize = UDim2.new(0, 0, 0, 0); modScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
modScroll.Parent = modPanel
local modList = Instance.new("UIListLayout")
modList.Padding = UDim.new(0, 6); modList.SortOrder = Enum.SortOrder.LayoutOrder; modList.Parent = modScroll

local profileBtn = Instance.new("TextButton")
profileBtn.Size = UDim2.new(0, 120, 0, 74); profileBtn.Position = UDim2.new(0, 8, 1, -82)
profileBtn.BackgroundColor3 = BG3; profileBtn.BorderSizePixel = 0
profileBtn.Text = ""; profileBtn.AutoButtonColor = false; profileBtn.Parent = body
Instance.new("UICorner", profileBtn).CornerRadius = UDim.new(0, 8)
local profileStroke = Instance.new("UIStroke"); profileStroke.Color = ACCENT; profileStroke.Thickness = 1; profileStroke.Transparency = 0.7; profileStroke.Parent = profileBtn

local avatarImg = Instance.new("ImageLabel")
avatarImg.Size = UDim2.new(0, 40, 0, 40); avatarImg.Position = UDim2.new(0, 8, 0, 8)
avatarImg.BackgroundColor3 = BG2; avatarImg.BorderSizePixel = 0
avatarImg.Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150"
avatarImg.Parent = profileBtn
Instance.new("UICorner", avatarImg).CornerRadius = UDim.new(0, 999)

local profName = Instance.new("TextLabel")
profName.BackgroundTransparency = 1; profName.Position = UDim2.new(0, 54, 0, 8)
profName.Size = UDim2.new(1, -58, 0, 14); profName.Font = FONT; profName.TextSize = 11
profName.TextColor3 = TEXT; profName.TextXAlignment = Enum.TextXAlignment.Left
profName.TextTruncate = Enum.TextTruncate.AtEnd; profName.Text = player.Name; profName.Parent = profileBtn

local profPlan = Instance.new("TextLabel")
profPlan.BackgroundTransparency = 1; profPlan.Position = UDim2.new(0, 54, 0, 24)
profPlan.Size = UDim2.new(1, -58, 0, 14); profPlan.Font = FONT; profPlan.TextSize = 10
profPlan.TextColor3 = ACCENT; profPlan.TextXAlignment = Enum.TextXAlignment.Left
profPlan.TextTruncate = Enum.TextTruncate.AtEnd; profPlan.Text = "Loading..."; profPlan.Parent = profileBtn

local profHint = Instance.new("TextLabel")
profHint.BackgroundTransparency = 1; profHint.Position = UDim2.new(0, 8, 1, -18)
profHint.Size = UDim2.new(1, -16, 0, 14); profHint.Font = FONT; profHint.TextSize = 9
profHint.TextColor3 = MUTED; profHint.TextXAlignment = Enum.TextXAlignment.Center
profHint.Text = "> Settings & Themes"; profHint.Parent = profileBtn

local function updateProfilePlan()
    if authData.plan == "lifetime" or not authData.expires then
        profPlan.Text = "Lifetime"; profPlan.TextColor3 = OK
    else
        local left = authData.expires - os.time()
        if left <= 0 then profPlan.Text = "Expired"; profPlan.TextColor3 = ERROR
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

-- =========================================================
-- MODULE BUILDER
-- =========================================================
REFS.currentCat = "Combat"
cacheModuleRefs()

REFS.capturingBind = nil
REFS.capturingBtn = nil
REFS.expandedModules = {}

function refreshModules()
    for _, c in ipairs(modScroll:GetChildren()) do
        if c:IsA("Frame") or c:IsA("TextLabel") then c:Destroy() end
    end

    if REFS.currentCat == "Keybind" then
        local bound = getBoundModules()
        state.Keybind = { { name = "Bound Keys", isHeader = true } }
        if #bound == 0 then
            table.insert(state.Keybind, { name = "No keybinds set", enabled = false, actions = {}, isReadOnly = true })
        else
            for _, entry in ipairs(bound) do
                local m = entry.mod
                table.insert(state.Keybind, {
                    name = m.name .. "  [" .. entry.cat .. "]",
                    enabled = m.enabled,
                    actions = { onToggle = function(on) m.enabled = on; if m.actions.onToggle then m.actions.onToggle(on) end end },
                })
            end
        end
    end

    local list = state[REFS.currentCat] or {}
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
            local hasSettings = mod.slider or mod.sliders
            local isExpanded = hasSettings and REFS.expandedModules[mod.name] == true
            local openHeight = 30
            if mod.sliders then openHeight = 30 + #mod.sliders * 22 + 6
            elseif mod.slider then openHeight = 62 end
            local cardHeight = isExpanded and openHeight or 30

            local card = Instance.new("Frame")
            card.Name = mod.name
            card.Size = UDim2.new(1, -8, 0, cardHeight)
            card.BackgroundColor3 = BG3; card.BorderSizePixel = 0
            card.LayoutOrder = i; card.Parent = modScroll
            Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
            card.ClipsDescendants = true

            local nameLbl = Instance.new("TextLabel")
            nameLbl.BackgroundTransparency = 1
            nameLbl.Position = UDim2.new(0, 12, 0, 0); nameLbl.Size = UDim2.new(1, -130, 0, 30)
            nameLbl.Font = FONT; nameLbl.TextSize = 13
            nameLbl.TextXAlignment = Enum.TextXAlignment.Left
            nameLbl.TextColor3 = mod.enabled and TEXT or MUTED
            nameLbl.Text = mod.name; nameLbl.Parent = card

            local modeBtn = Instance.new("TextButton")
            modeBtn.Size = UDim2.new(0, 16, 0, 20); modeBtn.Position = UDim2.new(1, -94, 0, 5)
            modeBtn.BackgroundColor3 = BG4
            modeBtn.TextColor3 = (mod.mode == "hold") and ACCENT or MUTED
            modeBtn.Font = FONT; modeBtn.TextSize = 10
            modeBtn.Text = (mod.mode == "hold") and "H" or "T"
            modeBtn.BorderSizePixel = 0; modeBtn.Parent = card
            Instance.new("UICorner", modeBtn).CornerRadius = UDim.new(0, 4)
            modeBtn.MouseButton1Click:Connect(function()
                mod.mode = (mod.mode == "hold") and "toggle" or "hold"
                modeBtn.Text = (mod.mode == "hold") and "H" or "T"
                modeBtn.TextColor3 = (mod.mode == "hold") and ACCENT or MUTED
            end)

            local kbBtn = Instance.new("TextButton")
            kbBtn.Size = UDim2.new(0, 46, 0, 20); kbBtn.Position = UDim2.new(1, -74, 0, 5)
            kbBtn.BackgroundColor3 = BG4; kbBtn.TextColor3 = MUTED
            kbBtn.Font = FONT; kbBtn.TextSize = 10
            kbBtn.Text = mod.keybind and mod.keybind.Name or "[NONE]"
            kbBtn.BorderSizePixel = 0; kbBtn.Parent = card
            Instance.new("UICorner", kbBtn).CornerRadius = UDim.new(0, 4)

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

            local function startCapture()
                REFS.capturingBind = mod
                REFS.capturingBtn = kbBtn
                kbBtn.Text = "[...]"
                kbBtn.TextColor3 = ACCENT
            end
            kbBtn.MouseButton1Click:Connect(startCapture)

            local settings = nil
            if hasSettings then
                settings = Instance.new("Frame")
                settings.Name = "Settings"
                settings.Position = UDim2.new(0, 0, 0, 30)
                settings.Size = UDim2.new(1, 0, 0, openHeight - 30)
                settings.BackgroundTransparency = 1
                settings.Visible = isExpanded
                settings.Parent = card
            end

            card.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton3 then
                    startCapture()
                end
                if input.UserInputType == Enum.UserInputType.MouseButton2 and hasSettings and settings then
                    REFS.expandedModules[mod.name] = not REFS.expandedModules[mod.name]
                    local newExpanded = REFS.expandedModules[mod.name]
                    settings.Visible = newExpanded
                    card.Size = UDim2.new(1, -8, 0, newExpanded and openHeight or 30)
                end
            end)

            local function createSlider(sl, yPos, onUpdate)
                local track = Instance.new("Frame")
                track.Size = UDim2.new(1, -30, 0, 6); track.Position = UDim2.new(0, 15, 0, yPos)
                track.BackgroundColor3 = BG4; track.BorderSizePixel = 0; track.Parent = settings
                Instance.new("UICorner", track).CornerRadius = UDim.new(0, 4)

                local fill = Instance.new("Frame")
                fill.Size = UDim2.new((sl.value - sl.min) / (sl.max - sl.min), 0, 1, 0)
                fill.BackgroundColor3 = ACCENT; fill.BorderSizePixel = 0; fill.Parent = track
                Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 4)

                local valueLbl = Instance.new("TextLabel")
                valueLbl.BackgroundTransparency = 1; valueLbl.Position = UDim2.new(1, -70, 0, yPos - 8)
                valueLbl.Size = UDim2.new(0, 60, 0, 16); valueLbl.Font = FONT
                valueLbl.TextSize = 11; valueLbl.TextColor3 = ACCENT
                valueLbl.Text = string.format("%.1f", sl.value); valueLbl.Parent = settings

                if sl.label then
                    local labLbl = Instance.new("TextLabel")
                    labLbl.BackgroundTransparency = 1
                    labLbl.Position = UDim2.new(0, 15, 0, yPos - 10)
                    labLbl.Size = UDim2.new(0, 80, 0, 12)
                    labLbl.Font = FONT; labLbl.TextSize = 9
                    labLbl.TextColor3 = MUTED
                    labLbl.TextXAlignment = Enum.TextXAlignment.Left
                    labLbl.Text = sl.label
                    labLbl.Parent = settings
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
                    if ip.UserInputType == Enum.UserInputType.MouseButton1 or ip.UserInputType == Enum.UserInputType.Touch then
                        dragging = true; update(ip)
                    end
                end)
                UserInputService.InputChanged:Connect(function(ip)
                    if dragging and (ip.UserInputType == Enum.UserInputType.MouseMovement or ip.UserInputType == Enum.UserInputType.Touch) then update(ip) end
                end)
                UserInputService.InputEnded:Connect(function(ip)
                    if ip.UserInputType == Enum.UserInputType.MouseButton1 or ip.UserInputType == Enum.UserInputType.Touch then dragging = false end
                end)
            end

            if hasSettings then
                if mod.slider then
                    createSlider(mod.slider, 16, mod.actions.onChange)
                    if mod.actions.onChange then pcall(mod.actions.onChange, mod.slider.value) end
                end
                if mod.sliders then
                    for idx, sl in ipairs(mod.sliders) do
                        local y = 10 + (idx - 1) * 22
                        createSlider(sl, y, function(v)
                            if mod.actions.onSliderChange then pcall(mod.actions.onSliderChange, idx, v) end
                        end)
                        if mod.actions.onSliderChange then pcall(mod.actions.onSliderChange, idx, sl.value) end
                    end
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
    for _, catName in ipairs(CATEGORY_ORDER) do
        if state[catName] then
            local btn = Instance.new("TextButton")
            btn.Name = catName; btn.Size = UDim2.new(1, 0, 0, 26)
            btn.BackgroundColor3 = (catName == REFS.currentCat) and ACCENT or BG4
            btn.TextColor3 = (catName == REFS.currentCat) and BG or TEXT
            btn.Font = FONT; btn.TextSize = 12; btn.Text = catName
            btn.BorderSizePixel = 0; btn.LayoutOrder = i; btn.Parent = catPanel
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
            btn.MouseButton1Click:Connect(function()
                REFS.currentCat = catName; refreshCategories(); refreshModules()
            end)
            i += 1
        end
    end
end

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if REFS.capturingBind and input.UserInputType == Enum.UserInputType.Keyboard then
        if input.KeyCode == Enum.KeyCode.Escape then
            REFS.capturingBind.keybind = nil
            if REFS.capturingBtn then REFS.capturingBtn.Text = "[NONE]"; REFS.capturingBtn.TextColor3 = MUTED end
        else
            REFS.capturingBind.keybind = input.KeyCode
            if REFS.capturingBtn then REFS.capturingBtn.Text = input.KeyCode.Name; REFS.capturingBtn.TextColor3 = MUTED end
        end
        REFS.capturingBind = nil; REFS.capturingBtn = nil
    end
end)

-- =========================================================
-- SUB MENU
-- =========================================================
local subGui = Instance.new("ScreenGui")
subGui.Name = "DesolateSub_" .. math.random(1, 1e6)
subGui.ResetOnSpawn = false; subGui.IgnoreGuiInset = true; subGui.DisplayOrder = 1001
if gethui then local ok, h = pcall(gethui); if ok and h then subGui.Parent = h end end
if not subGui.Parent then local ok = pcall(function() subGui.Parent = game:GetService("CoreGui") end); if not ok or not subGui.Parent then subGui.Parent = player:WaitForChild("PlayerGui") end end

local subMenu = Instance.new("Frame")
subMenu.Size = UDim2.new(0, 500, 0, 400); subMenu.Position = UDim2.new(0.5, -250, 0.5, -200)
subMenu.BackgroundColor3 = BG; subMenu.BorderSizePixel = 0
subMenu.Visible = false; subMenu.Active = true; subMenu.Parent = subGui
Instance.new("UICorner", subMenu).CornerRadius = UDim.new(0, 12)
local subStroke = Instance.new("UIStroke"); subStroke.Color = ACCENT; subStroke.Thickness = 1; subStroke.Transparency = 0.6; subStroke.Parent = subMenu

local subHeader = Instance.new("Frame")
subHeader.Size = UDim2.new(1, 0, 0, 36); subHeader.BackgroundColor3 = BG2; subHeader.BorderSizePixel = 0; subHeader.Parent = subMenu
Instance.new("UICorner", subHeader).CornerRadius = UDim.new(0, 12)
local subMask = Instance.new("Frame")
subMask.Size = UDim2.new(1, 0, 0, 10); subMask.Position = UDim2.new(0, 0, 1, -10); subMask.BackgroundColor3 = BG2; subMask.BorderSizePixel = 0; subMask.Parent = subHeader

local backBtn = Instance.new("TextButton")
backBtn.Size = UDim2.new(0, 30, 0, 24); backBtn.Position = UDim2.new(0, 10, 0, 6)
backBtn.BackgroundColor3 = BG4; backBtn.TextColor3 = TEXT; backBtn.Font = FONT; backBtn.TextSize = 14
backBtn.Text = "<"; backBtn.BorderSizePixel = 0; backBtn.Parent = subHeader
Instance.new("UICorner", backBtn).CornerRadius = UDim.new(0, 6)
backBtn.MouseButton1Click:Connect(function() subMenu.Visible = false end)

local subTitle = Instance.new("TextLabel")
subTitle.BackgroundTransparency = 1; subTitle.Position = UDim2.new(0, 48, 0, 0); subTitle.Size = UDim2.new(1, -60, 1, 0)
subTitle.Font = FONT; subTitle.TextSize = 14; subTitle.TextXAlignment = Enum.TextXAlignment.Left
subTitle.TextColor3 = ACCENT; subTitle.Text = "Settings & Themes"; subTitle.Parent = subHeader

local subBody = Instance.new("Frame")
subBody.Position = UDim2.new(0, 0, 0, 36); subBody.Size = UDim2.new(1, 0, 1, -36)
subBody.BackgroundTransparency = 1; subBody.Parent = subMenu

local themesHdr = Instance.new("TextLabel")
themesHdr.BackgroundTransparency = 1; themesHdr.Position = UDim2.new(0, 16, 0, 12)
themesHdr.Size = UDim2.new(1, -32, 0, 20); themesHdr.Font = FONT; themesHdr.TextSize = 12
themesHdr.TextColor3 = ACCENT; themesHdr.TextXAlignment = Enum.TextXAlignment.Left
themesHdr.Text = "THEMES"; themesHdr.Parent = subBody

local themeGrid = Instance.new("Frame")
themeGrid.Position = UDim2.new(0, 16, 0, 38); themeGrid.Size = UDim2.new(1, -32, 0, 130)
themeGrid.BackgroundTransparency = 1; themeGrid.Parent = subBody

local themeOrder = { "Dark", "Blood", "Ocean", "Purple", "Pink", "Matrix", "Light" }

local function rebuildThemeGrid()
    for _, c in ipairs(themeGrid:GetChildren()) do c:Destroy() end
    for i, tName in ipairs(themeOrder) do
        local th = THEMES[tName]
        local row = math.floor((i - 1) / 4); local col = (i - 1) % 4
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 105, 0, 50); btn.Position = UDim2.new(0, col * 112, 0, row * 58)
        btn.BackgroundColor3 = th.bg3; btn.Text = ""; btn.BorderSizePixel = 0
        btn.AutoButtonColor = false; btn.Parent = themeGrid
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
        local bS = Instance.new("UIStroke"); bS.Color = th.accent
        bS.Thickness = (currentTheme == tName) and 2 or 1
        bS.Transparency = (currentTheme == tName) and 0 or 0.5; bS.Parent = btn
        local dot = Instance.new("Frame"); dot.Size = UDim2.new(0, 18, 0, 18)
        dot.Position = UDim2.new(0, 10, 0, 10); dot.BackgroundColor3 = th.accent
        dot.BorderSizePixel = 0; dot.Parent = btn
        Instance.new("UICorner", dot).CornerRadius = UDim.new(0, 999)
        local lbl = Instance.new("TextLabel"); lbl.BackgroundTransparency = 1
        lbl.Position = UDim2.new(0, 34, 0, 10); lbl.Size = UDim2.new(1, -38, 0, 18)
        lbl.Font = FONT; lbl.TextSize = 12; lbl.TextColor3 = th.text
        lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Text = tName; lbl.Parent = btn
        local sub = Instance.new("TextLabel"); sub.BackgroundTransparency = 1
        sub.Position = UDim2.new(0, 10, 0, 30); sub.Size = UDim2.new(1, -14, 0, 14)
        sub.Font = FONT; sub.TextSize = 9; sub.TextColor3 = th.muted
        sub.TextXAlignment = Enum.TextXAlignment.Left
        sub.Text = (currentTheme == tName) and "Active" or "click to apply"; sub.Parent = btn
        btn.MouseButton1Click:Connect(function() applyTheme(tName) end)
    end
end

local settingsHdr = Instance.new("TextLabel")
settingsHdr.BackgroundTransparency = 1; settingsHdr.Position = UDim2.new(0, 16, 0, 186)
settingsHdr.Size = UDim2.new(1, -32, 0, 20); settingsHdr.Font = FONT; settingsHdr.TextSize = 12
settingsHdr.TextColor3 = ACCENT; settingsHdr.TextXAlignment = Enum.TextXAlignment.Left
settingsHdr.Text = "MENU SETTINGS"; settingsHdr.Parent = subBody

local settingsNote = Instance.new("TextLabel")
settingsNote.BackgroundTransparency = 1; settingsNote.Position = UDim2.new(0, 16, 0, 210)
settingsNote.Size = UDim2.new(1, -32, 0, 130); settingsNote.Font = FONT; settingsNote.TextSize = 11
settingsNote.TextColor3 = MUTED; settingsNote.TextXAlignment = Enum.TextXAlignment.Left
settingsNote.TextYAlignment = Enum.TextYAlignment.Top; settingsNote.TextWrapped = true
settingsNote.Text = "- RightShift — toggle menu\n- ПКМ по модулю — настройки\n- Mouse3 / клик по бинду — назначить\n- Кнопка H/T — hold/toggle\n- Escape во время бинда — очистить"
settingsNote.Parent = subBody

local function applyStaticColors()
    main.BackgroundColor3 = BG; stroke.Color = ACCENT
    header.BackgroundColor3 = BG2; hMask.BackgroundColor3 = BG2
    titleLbl.TextColor3 = ACCENT
    closeBtn.BackgroundColor3 = BG4; closeBtn.TextColor3 = TEXT
    catPanel.BackgroundColor3 = BG2; modPanel.BackgroundColor3 = BG2
    modScroll.ScrollBarImageColor3 = ACCENT
    profileBtn.BackgroundColor3 = BG3; profileStroke.Color = ACCENT
    profName.TextColor3 = TEXT; profHint.TextColor3 = MUTED
    subMenu.BackgroundColor3 = BG; subStroke.Color = ACCENT
    subHeader.BackgroundColor3 = BG2; subMask.BackgroundColor3 = BG2
    backBtn.BackgroundColor3 = BG4; backBtn.TextColor3 = TEXT
    subTitle.TextColor3 = ACCENT; themesHdr.TextColor3 = ACCENT
    settingsHdr.TextColor3 = ACCENT; settingsNote.TextColor3 = MUTED
    for _, b in ipairs(REFS.headerBtns) do b.BackgroundColor3 = BG4; b.TextColor3 = TEXT end
end

function applyTheme(themeName)
    local th = THEMES[themeName]; if not th then return end
    ACCENT = th.accent; BG = th.bg; BG2 = th.bg2; BG3 = th.bg3; BG4 = th.bg4
    TEXT = th.text; MUTED = th.muted; currentTheme = themeName
    applyStaticColors(); refreshCategories(); refreshModules(); rebuildThemeGrid(); saveConfig()
    print("[Desolate] theme:", themeName)
end

profileBtn.MouseButton1Click:Connect(function()
    subMenu.Visible = not subMenu.Visible
    if subMenu.Visible then subMenu.Position = main.Position; rebuildThemeGrid() end
end)

main:GetPropertyChangedSignal("Visible"):Connect(function()
    if not main.Visible then subMenu.Visible = false end
end)

-- =========================================================
-- HUD LAYER
-- =========================================================
local hudGui = Instance.new("ScreenGui")
hudGui.Name = "DesolateHUD_" .. math.random(1, 1e6)
hudGui.ResetOnSpawn = false; hudGui.IgnoreGuiInset = true; hudGui.DisplayOrder = 998
if gethui then local ok, h = pcall(gethui); if ok and h then hudGui.Parent = h end end
if not hudGui.Parent then local ok = pcall(function() hudGui.Parent = game:GetService("CoreGui") end); if not ok or not hudGui.Parent then hudGui.Parent = player:WaitForChild("PlayerGui") end end

local function makeDraggable(frame, name, dx, dy)
    frame.Active = true
    local dragging, dragStart, startPos
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = frame.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if dragging then
                dragging = false
                pcall(function()
                    fs.write("desolate_hud_" .. name .. ".txt",
                        frame.Position.X.Scale .. "," .. frame.Position.X.Offset .. "," .. frame.Position.Y.Scale .. "," .. frame.Position.Y.Offset)
                end)
            end
        end
    end)
    local saved = fs.read("desolate_hud_" .. name .. ".txt")
    local loaded = false
    if saved then
        local nums = {}
        for v in saved:gmatch("([^,]+)") do table.insert(nums, tonumber(v)) end
        if #nums >= 4 then frame.Position = UDim2.new(nums[1], nums[2], nums[3], nums[4]); loaded = true end
    end
    if not loaded and dx and dy then frame.Position = UDim2.new(0, dx, 0, dy) end
end

REFS.watermark = Instance.new("Frame")
REFS.watermark.Size = UDim2.new(0, 380, 0, 40); REFS.watermark.Position = UDim2.new(0, 10, 0, 10)
REFS.watermark.BackgroundColor3 = BG2; REFS.watermark.BackgroundTransparency = 0.15
REFS.watermark.BorderSizePixel = 0; REFS.watermark.Visible = false; REFS.watermark.Parent = hudGui
Instance.new("UICorner", REFS.watermark).CornerRadius = UDim.new(0, 8)
REFS.wAccent = Instance.new("Frame")
REFS.wAccent.Size = UDim2.new(0, 3, 1, 0); REFS.wAccent.BackgroundColor3 = ACCENT; REFS.wAccent.BorderSizePixel = 0; REFS.wAccent.Parent = REFS.watermark
Instance.new("UICorner", REFS.wAccent).CornerRadius = UDim.new(0, 8)
REFS.wLabel = Instance.new("TextLabel")
REFS.wLabel.BackgroundTransparency = 1; REFS.wLabel.Position = UDim2.new(0, 10, 0, 0)
REFS.wLabel.Size = UDim2.new(1, -14, 1, 0); REFS.wLabel.Font = FONT; REFS.wLabel.TextSize = 12
REFS.wLabel.TextXAlignment = Enum.TextXAlignment.Left; REFS.wLabel.TextColor3 = TEXT
REFS.wLabel.Text = "Desolate"; REFS.wLabel.Parent = REFS.watermark

MOD.watermark.actions.onToggle = function(on) REFS.watermark.Visible = on end
REFS.watermark.Visible = MOD.watermark.enabled
makeDraggable(REFS.watermark, "watermark", 10, 10)

REFS.coordFrame = Instance.new("Frame")
REFS.coordFrame.Size = UDim2.new(0, 200, 0, 24); REFS.coordFrame.Position = UDim2.new(0, 10, 0, 60)
REFS.coordFrame.BackgroundColor3 = BG2; REFS.coordFrame.BackgroundTransparency = 0.2
REFS.coordFrame.BorderSizePixel = 0; REFS.coordFrame.Visible = false; REFS.coordFrame.Parent = hudGui
Instance.new("UICorner", REFS.coordFrame).CornerRadius = UDim.new(0, 6)
REFS.coordLabel = Instance.new("TextLabel")
REFS.coordLabel.BackgroundTransparency = 1; REFS.coordLabel.Size = UDim2.new(1, -8, 1, 0)
REFS.coordLabel.Position = UDim2.new(0, 4, 0, 0); REFS.coordLabel.Font = FONT
REFS.coordLabel.TextSize = 12; REFS.coordLabel.TextXAlignment = Enum.TextXAlignment.Left
REFS.coordLabel.TextColor3 = TEXT; REFS.coordLabel.Text = "X: -- Y: -- Z: --"; REFS.coordLabel.Parent = REFS.coordFrame

MOD.coords.actions.onToggle = function(on) REFS.coordFrame.Visible = on end
makeDraggable(REFS.coordFrame, "coords", 10, 60)

REFS.crosshair = Instance.new("Frame")
REFS.crosshair.Name = "Crosshair"; REFS.crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
REFS.crosshair.Position = UDim2.new(0.5, 0, 0.5, 0); REFS.crosshair.Size = UDim2.new(0, 20, 0, 20)
REFS.crosshair.BackgroundTransparency = 1; REFS.crosshair.Visible = false; REFS.crosshair.Parent = hudGui

function buildCrosshair()
    if not REFS.crosshair or not REFS.crosshair.Parent then return end
    for _, c in ipairs(REFS.crosshair:GetChildren()) do c:Destroy() end
    local c = Instance.new("Frame")
    c.Size = UDim2.new(0, 14, 0, 14); c.Position = UDim2.new(0.5, -7, 0.5, -7)
    c.BackgroundTransparency = 1; c.Parent = REFS.crosshair
    local s = Instance.new("UIStroke"); s.Color = ACCENT; s.Thickness = 1.5; s.Parent = c
    Instance.new("UICorner", c).CornerRadius = UDim.new(0, 999)
end
buildCrosshair()
MOD.crosshair.actions.onToggle = function(on) REFS.crosshair.Visible = on end

local drawFovFrame = Instance.new("Frame")
drawFovFrame.Name = "DrawFOV"; drawFovFrame.AnchorPoint = Vector2.new(0.5, 0.5)
drawFovFrame.Position = UDim2.new(0.5, 0, 0.5, 0); drawFovFrame.Size = UDim2.new(0, 300, 0, 300)
drawFovFrame.BackgroundTransparency = 1; drawFovFrame.Visible = false; drawFovFrame.Parent = hudGui
local drawFovInner = Instance.new("Frame")
drawFovInner.Size = UDim2.new(1, 0, 1, 0); drawFovInner.BackgroundTransparency = 1; drawFovInner.Parent = drawFovFrame
Instance.new("UICorner", drawFovInner).CornerRadius = UDim.new(0, 999)
local drawFovStroke = Instance.new("UIStroke")
drawFovStroke.Color = ACCENT; drawFovStroke.Thickness = 1.5; drawFovStroke.Transparency = 0.4; drawFovStroke.Parent = drawFovInner

local function updateDrawFov(v)
    local r = v * 20
    drawFovFrame.Size = UDim2.new(0, r * 2, 0, r * 2)
    drawFovStroke.Color = ACCENT
end
MOD.drawFov.actions.onToggle = function(on) drawFovFrame.Visible = on; if on then updateDrawFov(MOD.drawFov.slider.value) end end
MOD.drawFov.actions.onChange = function(v) if not MOD.drawFov.enabled then return end; updateDrawFov(v) end

REFS.kbFrame = Instance.new("Frame")
REFS.kbFrame.Name = "KeyBindsHUD"
REFS.kbFrame.Size = UDim2.new(0, 200, 0, 80)
REFS.kbFrame.Position = UDim2.new(0, 400, 0, 10)
REFS.kbFrame.BackgroundColor3 = BG2; REFS.kbFrame.BackgroundTransparency = 0.2
REFS.kbFrame.BorderSizePixel = 0; REFS.kbFrame.Visible = false; REFS.kbFrame.Parent = hudGui
Instance.new("UICorner", REFS.kbFrame).CornerRadius = UDim.new(0, 8)
local kbAccent = Instance.new("Frame")
kbAccent.Size = UDim2.new(0, 3, 1, 0); kbAccent.BackgroundColor3 = ACCENT; kbAccent.BorderSizePixel = 0; kbAccent.Parent = REFS.kbFrame
Instance.new("UICorner", kbAccent).CornerRadius = UDim.new(0, 8)
REFS.kbTitle = Instance.new("TextLabel")
REFS.kbTitle.BackgroundTransparency = 1; REFS.kbTitle.Position = UDim2.new(0, 10, 0, 4)
REFS.kbTitle.Size = UDim2.new(1, -14, 0, 16); REFS.kbTitle.Font = FONT; REFS.kbTitle.TextSize = 11
REFS.kbTitle.TextXAlignment = Enum.TextXAlignment.Left; REFS.kbTitle.TextColor3 = ACCENT
REFS.kbTitle.Text = "KEYBINDS"; REFS.kbTitle.Parent = REFS.kbFrame
REFS.kbList = Instance.new("TextLabel")
REFS.kbList.BackgroundTransparency = 1; REFS.kbList.Position = UDim2.new(0, 10, 0, 22)
REFS.kbList.Size = UDim2.new(1, -14, 1, -26); REFS.kbList.Font = FONT; REFS.kbList.TextSize = 11
REFS.kbList.TextXAlignment = Enum.TextXAlignment.Left; REFS.kbList.TextYAlignment = Enum.TextYAlignment.Top
REFS.kbList.TextColor3 = TEXT; REFS.kbList.TextWrapped = true; REFS.kbList.Text = ""; REFS.kbList.Parent = REFS.kbFrame

MOD.keyBinds.actions.onToggle = function(on) REFS.kbFrame.Visible = on end
makeDraggable(REFS.kbFrame, "keybinds", 400, 10)
-- =========================================================
-- NAMETAGS
-- =========================================================
local nametagFolder = Instance.new("Folder")
nametagFolder.Name = "DesolateNameTags"; nametagFolder.Parent = hudGui
REFS.nametags = {}

local function createNametag(plr)
    local bb = Instance.new("BillboardGui")
    bb.Name = "NT_" .. plr.Name; bb.Size = UDim2.new(0, 140, 0, 44)
    bb.StudsOffset = Vector3.new(0, 3.2, 0); bb.AlwaysOnTop = true; bb.LightInfluence = 0
    local bg = Instance.new("Frame"); bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = BG; bg.BackgroundTransparency = 0.15; bg.BorderSizePixel = 0; bg.Parent = bb
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 6)
    local name = Instance.new("TextLabel")
    name.BackgroundTransparency = 1; name.Position = UDim2.new(0, 6, 0, 2); name.Size = UDim2.new(1, -12, 0, 14)
    name.Font = FONT; name.TextSize = 12; name.TextColor3 = ACCENT
    name.TextXAlignment = Enum.TextXAlignment.Center; name.Text = plr.Name; name.Parent = bg
    local info = Instance.new("TextLabel")
    info.BackgroundTransparency = 1; info.Position = UDim2.new(0, 6, 0, 16); info.Size = UDim2.new(1, -12, 0, 14)
    info.Font = FONT; info.TextSize = 11; info.TextColor3 = TEXT
    info.TextXAlignment = Enum.TextXAlignment.Center; info.Text = "HP: -- | --m"; info.Parent = bg
    local hbBg = Instance.new("Frame"); hbBg.Position = UDim2.new(0, 6, 1, -6)
    hbBg.Size = UDim2.new(1, -12, 0, 3); hbBg.BackgroundColor3 = BG4; hbBg.BorderSizePixel = 0; hbBg.Parent = bg
    Instance.new("UICorner", hbBg).CornerRadius = UDim.new(0, 4)
    local hb = Instance.new("Frame"); hb.Size = UDim2.new(1, 0, 1, 0)
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
                REFS.nametags[plr] = { gui = bb, name = n, info = i, hbar = hb }
            end
        end
    else
        for _, d in pairs(REFS.nametags) do if d.gui then d.gui:Destroy() end end
        REFS.nametags = {}
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
        REFS.nametags[plr] = { gui = bb, name = n, info = i, hbar = hb }
    end)
end)
Players.PlayerRemoving:Connect(function(plr)
    if REFS.nametags[plr] then
        if REFS.nametags[plr].gui then REFS.nametags[plr].gui:Destroy() end
        REFS.nametags[plr] = nil
    end
end)

-- =========================================================
-- ESP
-- =========================================================
REFS.espHighlights = {}
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
                REFS.espHighlights[plr] = hl
            end
        end
    else
        for _, hl in pairs(REFS.espHighlights) do if hl then hl:Destroy() end end
        REFS.espHighlights = {}
    end
end

-- =========================================================
-- SKELETON ESP
-- =========================================================
local skeletonGui = Instance.new("ScreenGui")
skeletonGui.Name = "DesolateSkeleton"
skeletonGui.ResetOnSpawn = false
skeletonGui.IgnoreGuiInset = true
skeletonGui.DisplayOrder = 998
if gethui then local ok, h = pcall(gethui); if ok and h then skeletonGui.Parent = h end end
if not skeletonGui.Parent then
    local ok = pcall(function() skeletonGui.Parent = game:GetService("CoreGui") end)
    if not ok or not skeletonGui.Parent then skeletonGui.Parent = player:WaitForChild("PlayerGui") end
end

REFS.skeletonConns = {}

local BONES_R15 = {
    {"Head", "UpperTorso"},
    {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"},
    {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"},
    {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"},
    {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"},
    {"RightUpperLeg", "RightLowerLeg"},
    {"RightLowerLeg", "RightFoot"},
}

local BONES_R6 = {
    {"Head", "Torso"},
    {"Torso", "Left Arm"},
    {"Torso", "Right Arm"},
    {"Torso", "Left Leg"},
    {"Torso", "Right Leg"},
}

local function getBonesFor(char)
    if char:FindFirstChild("UpperTorso") then return BONES_R15 end
    if char:FindFirstChild("Torso") then return BONES_R6 end
    return BONES_R15
end

local function destroySkeleton(plr)
    local data = REFS.skeletonConns[plr]
    if data then
        if data.conn then data.conn:Disconnect() end
        if data.folder then data.folder:Destroy() end
        REFS.skeletonConns[plr] = nil
    end
end

local function buildSkeleton(plr)
    destroySkeleton(plr)
    if not plr.Character then return end

    local folder = Instance.new("Folder")
    folder.Name = "Skeleton_" .. plr.Name
    folder.Parent = skeletonGui

    local bones = getBonesFor(plr.Character)
    local lines = {}

    for i, pair in ipairs(bones) do
        local p0 = plr.Character:FindFirstChild(pair[1])
        local p1 = plr.Character:FindFirstChild(pair[2])
        if p0 and p1 then
            local line = Instance.new("Frame")
            line.AnchorPoint = Vector2.new(0.5, 0.5)
            line.BackgroundColor3 = ACCENT
            line.BorderSizePixel = 0
            line.Visible = false
            line.ZIndex = 2
            line.Parent = folder
            table.insert(lines, { frame = line, a = p0, b = p1 })
        end
    end

    local conn = RunService.RenderStepped:Connect(function()
        if not MOD.skeleton.enabled then return end
        if not plr.Character or not plr.Character.Parent then return end

        local thickness = MOD.skeleton.sliders[1].value
        local maxDist = MOD.skeleton.sliders[2].value

        if CACHE.hrp then
            local theirHrp = plr.Character:FindFirstChild("HumanoidRootPart")
            if theirHrp then
                local dist = (theirHrp.Position - CACHE.hrp.Position).Magnitude
                if dist > maxDist then
                    for _, data in ipairs(lines) do data.frame.Visible = false end
                    return
                end
            end
        end

        for _, data in ipairs(lines) do
            if not data.a.Parent or not data.b.Parent then
                data.frame.Visible = false
            else
                local posA, onA = Camera:WorldToViewportPoint(data.a.Position)
                local posB, onB = Camera:WorldToViewportPoint(data.b.Position)
                if onA and onB and posA.Z > 0 and posB.Z > 0 then
                    local midX = (posA.X + posB.X) / 2
                    local midY = (posA.Y + posB.Y) / 2
                    local dx = posB.X - posA.X
                    local dy = posB.Y - posA.Y
                    local len = math.sqrt(dx * dx + dy * dy)
                    local angle = math.atan2(dy, dx)
                    data.frame.Position = UDim2.new(0, midX, 0, midY)
                    data.frame.Size = UDim2.new(0, len, 0, thickness)
                    data.frame.Rotation = math.deg(angle)
                    data.frame.BackgroundColor3 = ACCENT
                    data.frame.Visible = true
                else
                    data.frame.Visible = false
                end
            end
        end
    end)

    REFS.skeletonConns[plr] = { folder = folder, conn = conn }
end

MOD.skeleton.actions.onToggle = function(on)
    if on then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= player and plr.Character then buildSkeleton(plr) end
        end
    else
        for plr, _ in pairs(REFS.skeletonConns) do destroySkeleton(plr) end
    end
end

Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function()
        if MOD.skeleton.enabled then
            task.wait(0.5)
            if MOD.skeleton.enabled then buildSkeleton(plr) end
        end
    end)
end)
Players.PlayerRemoving:Connect(function(plr) destroySkeleton(plr) end)

task.spawn(function()
    while gui.Parent do
        task.wait(2)
        if MOD.skeleton.enabled then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= player and plr.Character and not REFS.skeletonConns[plr] then
                    buildSkeleton(plr)
                end
            end
        end
    end
end)

-- =========================================================
-- JUMP CIRCLE
-- =========================================================
REFS.jumpRings = {}
MOD.jumpCircle.actions.onToggle = function(on)
    if not on then
        for _, r in ipairs(REFS.jumpRings) do if r.part then r.part:Destroy() end end
        REFS.jumpRings = {}
    end
end

REFS.wasOnGround = true
RunService.Heartbeat:Connect(function()
    if not MOD.jumpCircle.enabled then return end
    local hum, hrp = CACHE.humanoid, CACHE.hrp
    if not hum or not hrp then return end
    local onG = hum.FloorMaterial ~= Enum.Material.Air
    if REFS.wasOnGround and not onG then
        local ring = Instance.new("Part")
        ring.Shape = Enum.PartType.Cylinder; ring.Anchored = true; ring.CanCollide = false
        ring.CanQuery = false; ring.CanTouch = false; ring.Material = Enum.Material.Neon
        ring.Color = ACCENT; ring.Transparency = 0.2; ring.Size = Vector3.new(0.15, 2, 2)
        ring.CFrame = CFrame.new(hrp.Position - Vector3.new(0, 2.9, 0)) * CFrame.Angles(0, 0, math.rad(90))
        ring.Parent = Workspace
        table.insert(REFS.jumpRings, { part = ring, born = tick() })
    end
    REFS.wasOnGround = onG
    for i = #REFS.jumpRings, 1, -1 do
        local r = REFS.jumpRings[i]
        local age = tick() - r.born
        if age > 0.7 then
            if r.part then r.part:Destroy() end
            table.remove(REFS.jumpRings, i)
        else
            local s = 2 + age * 8
            r.part.Size = Vector3.new(0.15, s, s)
            r.part.Transparency = 0.2 + age / 0.7 * 0.7
        end
    end
end)

-- =========================================================
-- MOVE CIRCLE
-- =========================================================
REFS.moveCircleParts = {}
REFS.lastStepPos = Vector3.new()

local function spawnMoveCircle(pos)
    local part = Instance.new("Part")
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.Material = Enum.Material.Neon
    part.Color = ACCENT
    part.Shape = Enum.PartType.Cylinder
    part.Size = Vector3.new(0.08, 0.6, 0.6)
    part.Transparency = 0
    part.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
    part.Parent = Workspace
    table.insert(REFS.moveCircleParts, { part = part, born = tick() })
end

MOD.moveCircle.actions.onToggle = function(on)
    if not on then
        for _, c in ipairs(REFS.moveCircleParts) do if c.part then c.part:Destroy() end end
        REFS.moveCircleParts = {}
        REFS.lastStepPos = Vector3.new()
    end
end

player.CharacterAdded:Connect(function()
    task.wait(0.5)
    REFS.lastStepPos = Vector3.new()
end)

RunService.Heartbeat:Connect(function()
    if MOD.moveCircle.enabled then
        local hrp, hum = CACHE.hrp, CACHE.humanoid
        if hrp and hum and hum.FloorMaterial ~= Enum.Material.Air then
            local spacing = MOD.moveCircle.sliders[3].value
            local dist = (hrp.Position - REFS.lastStepPos).Magnitude
            if dist >= spacing then
                REFS.lastStepPos = hrp.Position
                spawnMoveCircle(Vector3.new(hrp.Position.X, hrp.Position.Y - 2.5, hrp.Position.Z))
            end
        end
    end
    if #REFS.moveCircleParts > 0 then
        local fadeTime = MOD.moveCircle.sliders[2].value
        local targetSize = MOD.moveCircle.sliders[1].value
        for i = #REFS.moveCircleParts, 1, -1 do
            local c = REFS.moveCircleParts[i]
            if not c.part or not c.part.Parent then
                table.remove(REFS.moveCircleParts, i)
            else
                local age = tick() - c.born
                if age >= fadeTime then
                    c.part:Destroy()
                    table.remove(REFS.moveCircleParts, i)
                else
                    local a = age / fadeTime
                    local sz = 0.6 + a * targetSize
                    c.part.Size = Vector3.new(0.08, sz, sz)
                    c.part.Transparency = a
                end
            end
        end
    end
end)

-- =========================================================
-- TRAILS
-- =========================================================
REFS.trailEmitter = nil
REFS.trailObj = nil

local function destroyAllTrails()
    if REFS.trailEmitter and REFS.trailEmitter.Parent then REFS.trailEmitter:Destroy() end
    REFS.trailEmitter = nil
    if REFS.trailObj and REFS.trailObj.Parent then REFS.trailObj:Destroy() end
    REFS.trailObj = nil
    if CACHE.hrp then
        for _, n in ipairs({ "DesolateTrailAtt", "DesolateTrailA0", "DesolateTrailA1", "DesolateTrailLine" }) do
            local x = CACHE.hrp:FindFirstChild(n)
            if x then pcall(function() x:Destroy() end) end
        end
    end
end

function applyTrailParams()
    local length = MOD.trails.sliders[1].value
    local fade   = MOD.trails.sliders[2].value
    local endT   = math.clamp(fade, 0.01, 1)
    if REFS.trailEmitter then
        REFS.trailEmitter.Lifetime = NumberRange.new(length)
        REFS.trailEmitter.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.2),
            NumberSequenceKeypoint.new(1, endT),
        })
        REFS.trailEmitter.Color = ColorSequence.new(ACCENT)
    end
    if REFS.trailObj then
        REFS.trailObj.Lifetime = length
        REFS.trailObj.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.1),
            NumberSequenceKeypoint.new(1, endT),
        })
        REFS.trailObj.Color = ColorSequence.new(ACCENT)
    end
end

local function buildTrails()
    destroyAllTrails()
    local hrp = CACHE.hrp; if not hrp then return end
    local mode = math.floor(MOD.trails.sliders[3].value)
    if mode >= 2 then
        local a0 = Instance.new("Attachment"); a0.Name = "DesolateTrailA0"
        a0.Position = Vector3.new(0, 1, 0); a0.Parent = hrp
        local a1 = Instance.new("Attachment"); a1.Name = "DesolateTrailA1"
        a1.Position = Vector3.new(0, -2, 0); a1.Parent = hrp
        local tr = Instance.new("Trail"); tr.Name = "DesolateTrailLine"
        tr.Attachment0 = a0; tr.Attachment1 = a1
        tr.WidthScale = NumberSequence.new(0.8)
        tr.FaceCamera = true
        tr.LightEmission = 0.6; tr.LightInfluence = 0
        tr.Parent = hrp
        REFS.trailObj = tr
    else
        local att = Instance.new("Attachment"); att.Name = "DesolateTrailAtt"
        att.Position = Vector3.new(0, -1.5, 0); att.Parent = hrp
        local em = Instance.new("ParticleEmitter"); em.Name = "Emitter"
        em.Texture = "rbxassetid://243098098"
        em.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
        em.Rate = 0; em.Speed = NumberRange.new(0)
        em.LightEmission = 0.6; em.LightInfluence = 0
        em.Parent = att
        REFS.trailEmitter = em
    end
    applyTrailParams()
end

MOD.trails.actions.onToggle = function(on)
    if on then buildTrails() else destroyAllTrails() end
end

MOD.trails.actions.onSliderChange = function(idx, v)
    if not MOD.trails.enabled then return end
    if idx == 3 then buildTrails() else applyTrailParams() end
end

player.CharacterAdded:Connect(function()
    task.wait(0.5); refreshCharacterCache()
    if MOD.trails.enabled then buildTrails() end
end)

REFS.trailAccum = 0
RunService.Heartbeat:Connect(function(dt)
    if not MOD.trails.enabled or not REFS.trailEmitter or not CACHE.hrp then return end
    local hrp = CACHE.hrp
    if hrp.AssemblyLinearVelocity.Magnitude < 1 then return end
    REFS.trailAccum += dt
    if REFS.trailAccum >= 0.06 then
        REFS.trailAccum = 0
        REFS.trailEmitter.Color = ColorSequence.new(ACCENT)
        REFS.trailEmitter:Emit(2)
    end
end)

-- =========================================================
-- PARTICLES
-- =========================================================
local function destroyParticlesEmitter()
    if Camera then
        local old = Camera:FindFirstChild("DesolateFallingEmitter")
        if old then pcall(function() old:Destroy() end) end
    end
end

local function buildParticles()
    destroyParticlesEmitter()
    if not MOD.particles.enabled then return end
    local rate = MOD.particles.sliders[1].value
    local speed = MOD.particles.sliders[2].value
    local size = MOD.particles.sliders[3].value

    local att = Instance.new("Attachment")
    att.Name = "DesolateFallingEmitter"
    att.Position = Vector3.new(0, 20, 0)
    att.Parent = Camera

    local em = Instance.new("ParticleEmitter")
    em.Name = "Emitter"
    em.Texture = "rbxassetid://243098098"
    em.Color = ColorSequence.new(ACCENT)
    em.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0.9) })
    em.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size / 5), NumberSequenceKeypoint.new(1, size / 20) })
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

MOD.particles.actions.onToggle = function(on) if on then buildParticles() else destroyParticlesEmitter() end end

MOD.particles.actions.onSliderChange = function(idx, v)
    if not Camera then return end
    local att = Camera:FindFirstChild("DesolateFallingEmitter"); if not att then return end
    local em = att:FindFirstChild("Emitter"); if not em then return end
    if idx == 1 then em.Rate = v
    elseif idx == 2 then em.Speed = NumberRange.new(v)
    elseif idx == 3 then em.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, v / 5),
        NumberSequenceKeypoint.new(1, v / 20)
    }) end
    em.Color = ColorSequence.new(ACCENT)
end

task.spawn(function()
    while gui.Parent do
        task.wait(2)
        if MOD.particles.enabled and Camera then
            if not Camera:FindFirstChild("DesolateFallingEmitter") then
                buildParticles()
            end
        end
    end
end)

-- =========================================================
-- BULLET TRACER
-- =========================================================
local tracerFolder = Instance.new("Folder")
tracerFolder.Name = "DesolateTracers"; tracerFolder.Parent = Workspace

local function spawnTracer(fromPos, toPos)
    local dist = (toPos - fromPos).Magnitude
    if dist < 1 then return end
    local part = Instance.new("Part")
    part.Anchored = true; part.CanCollide = false
    part.CanQuery = false; part.CanTouch = false
    part.Material = Enum.Material.Neon
    part.Color = ACCENT
    part.Size = Vector3.new(0.08, 0.08, dist)
    part.CFrame = CFrame.new((fromPos + toPos) / 2, toPos)
    part.Parent = tracerFolder
    local start = tick()
    task.spawn(function()
        while tick() - start < 0.25 do
            local a = (tick() - start) / 0.25
            if part.Parent then part.Transparency = a end
            task.wait(0.016)
        end
        if part.Parent then part:Destroy() end
    end)
end

REFS.bulletTracerConn = nil
MOD.bulletTracer.actions.onToggle = function(on)
    if REFS.bulletTracerConn then REFS.bulletTracerConn:Disconnect(); REFS.bulletTracerConn = nil end
    if not on then return end
    REFS.bulletTracerConn = UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        local origin = Camera.CFrame.Position
        local lookDir = Camera.CFrame.LookVector
        local params = RaycastParams.new()
        params.FilterDescendantsInstances = { CACHE.character, Camera }
        params.FilterType = Enum.RaycastFilterType.Exclude
        local result = Workspace:Raycast(origin, lookDir * 1000, params)
        local endPos = result and result.Position or (origin + lookDir * 1000)
        spawnTracer(origin, endPos)
    end)
end

-- =========================================================
-- CHINA HAT
-- =========================================================
REFS.chinaHatBB = nil
REFS.chinaHatImg = nil

local function destroyChinaHat()
    if REFS.chinaHatBB and REFS.chinaHatBB.Parent then REFS.chinaHatBB:Destroy() end
    REFS.chinaHatBB, REFS.chinaHatImg = nil, nil
end

local function buildChinaHat()
    destroyChinaHat()
    local head = CACHE.head
    if not head then return end
    local size = MOD.chinaHat.slider.value

    local bb = Instance.new("BillboardGui")
    bb.Name = "DesolateChinaHat"
    bb.Size = UDim2.new(0, 100 * size, 0, 60 * size)
    bb.StudsOffset = Vector3.new(0, 2.5 * size, 0)
    bb.AlwaysOnTop = true
    bb.LightInfluence = 0
    bb.Adornee = head
    bb.Parent = head

    local img = Instance.new("ImageLabel")
    img.Name = "HatImage"
    img.Size = UDim2.new(1, 0, 1, 0)
    img.BackgroundTransparency = 1
    img.Image = "rbxassetid://131007693"
    img.ImageColor3 = ACCENT
    img.Parent = bb

    REFS.chinaHatBB = bb
    REFS.chinaHatImg = img
end

MOD.chinaHat.actions.onToggle = function(on)
    if on then buildChinaHat() else destroyChinaHat() end
end

MOD.chinaHat.actions.onChange = function(v)
    if not MOD.chinaHat.enabled then return end
    if REFS.chinaHatBB then
        REFS.chinaHatBB.Size = UDim2.new(0, 100 * v, 0, 60 * v)
        REFS.chinaHatBB.StudsOffset = Vector3.new(0, 2.5 * v, 0)
    end
end

player.CharacterAdded:Connect(function()
    task.wait(0.5)
    refreshCharacterCache()
    if MOD.chinaHat.enabled then buildChinaHat() end
end)

task.spawn(function()
    while gui.Parent do
        task.wait(2)
        if MOD.chinaHat.enabled then
            local head = CACHE.head
            if head and (not REFS.chinaHatBB or not REFS.chinaHatBB.Parent or REFS.chinaHatBB.Adornee ~= head) then
                buildChinaHat()
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
REFS.currentSkyPreset = 4
REFS.customSkyObj = nil
local originalLighting = {
    Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
    FogColor = Lighting.FogColor, FogStart = Lighting.FogStart, FogEnd = Lighting.FogEnd,
    ClockTime = Lighting.ClockTime, Brightness = Lighting.Brightness,
}
local function ensureSkyObject()
    if not REFS.customSkyObj or not REFS.customSkyObj.Parent then
        REFS.customSkyObj = Instance.new("Sky"); REFS.customSkyObj.Name = "DesolateCustomSky"
        REFS.customSkyObj.SkyboxBk = "rbxasset://textures/sky/sky512_bk.tex"
        REFS.customSkyObj.SkyboxDn = "rbxasset://textures/sky/sky512_dn.tex"
        REFS.customSkyObj.SkyboxFt = "rbxasset://textures/sky/sky512_ft.tex"
        REFS.customSkyObj.SkyboxLf = "rbxasset://textures/sky/sky512_lf.tex"
        REFS.customSkyObj.SkyboxRt = "rbxasset://textures/sky/sky512_rt.tex"
        REFS.customSkyObj.SkyboxUp = "rbxasset://textures/sky/sky512_up.tex"
        REFS.customSkyObj.Parent = Lighting
    end
    return REFS.customSkyObj
end
local function applySkyPreset(idx)
    local p = SKY_PRESETS[idx]; if not p then return end
    ensureSkyObject()
    Lighting.ClockTime = p.clockTime; Lighting.Ambient = p.ambient
    Lighting.OutdoorAmbient = p.outdoor; Lighting.FogColor = p.fogColor
    Lighting.FogStart = 0; Lighting.FogEnd = p.fogEnd; Lighting.Brightness = 2
end
MOD.customSky.actions.onToggle = function(on)
    if on then applySkyPreset(REFS.currentSkyPreset); Lighting.ClockTime = MOD.customSky.slider.value
    else
        if REFS.customSkyObj then REFS.customSkyObj:Destroy(); REFS.customSkyObj = nil end
        pcall(function() Lighting.ClockTime = originalLighting.ClockTime end)
        pcall(function() Lighting.Ambient = originalLighting.Ambient end)
        pcall(function() Lighting.OutdoorAmbient = originalLighting.OutdoorAmbient end)
        pcall(function() Lighting.Brightness = originalLighting.Brightness end)
    end
end
MOD.customSky.actions.onChange = function(v) if not MOD.customSky.enabled then return end; Lighting.ClockTime = v end
MOD.skyPreset.actions.onToggle = function(on)
    if not on then return end
    REFS.currentSkyPreset = math.floor(MOD.skyPreset.slider.value)
    if MOD.customSky.enabled then applySkyPreset(REFS.currentSkyPreset); Lighting.ClockTime = MOD.customSky.slider.value end
end
MOD.skyPreset.actions.onChange = function(v)
    REFS.currentSkyPreset = math.floor(v)
    if not MOD.customSky.enabled then return end
    applySkyPreset(REFS.currentSkyPreset); Lighting.ClockTime = MOD.customSky.slider.value
end

REFS.fogActive = false
REFS.fogConn = nil

local function applyFog()
    if not REFS.fogActive then return end
    pcall(function()
        Lighting.FogStart = 0
        Lighting.FogEnd = MOD.fog.slider.value
        if not MOD.customSky.enabled then
            Lighting.FogColor = Color3.fromRGB(40, 45, 65)
        end
    end)
end

MOD.fog.actions.onToggle = function(on)
    REFS.fogActive = on
    if REFS.fogConn then REFS.fogConn:Disconnect(); REFS.fogConn = nil end
    if on then
        applyFog()
        REFS.fogConn = RunService.Heartbeat:Connect(applyFog)
    else
        pcall(function()
            Lighting.FogColor = originalLighting.FogColor
            Lighting.FogStart = originalLighting.FogStart
            Lighting.FogEnd = originalLighting.FogEnd
        end)
    end
end
MOD.fog.actions.onChange = function(v) applyFog() end

MOD.timeChanger.actions.onToggle = function(on)
    if on then Lighting.ClockTime = MOD.timeChanger.slider.value
    else pcall(function() Lighting.ClockTime = originalLighting.ClockTime end) end
end
MOD.timeChanger.actions.onChange = function(v) if not MOD.timeChanger.enabled then return end; Lighting.ClockTime = v end

-- =========================================================
-- FULLBRIGHT
-- =========================================================
REFS.fullbrightActive = false
REFS.fullbrightConn = nil

local function applyFullbright()
    if not REFS.fullbrightActive then return end
    local lvl = MOD.fullbright.slider.value
    pcall(function()
        Lighting.Ambient = Color3.fromRGB(150, 150, 150)
        Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 150)
        Lighting.Brightness = lvl
        Lighting.GlobalShadows = false
        Lighting.EnvironmentDiffuseScale = 1
        Lighting.EnvironmentSpecularScale = 1
    end)
end

MOD.fullbright.actions.onToggle = function(on)
    REFS.fullbrightActive = on
    if REFS.fullbrightConn then REFS.fullbrightConn:Disconnect(); REFS.fullbrightConn = nil end
    if on then
        applyFullbright()
        REFS.fullbrightConn = RunService.Heartbeat:Connect(applyFullbright)
    else
        pcall(function()
            Lighting.Ambient = originalLighting.Ambient
            Lighting.OutdoorAmbient = originalLighting.OutdoorAmbient
            Lighting.Brightness = originalLighting.Brightness
            Lighting.GlobalShadows = true
        end)
    end
end
MOD.fullbright.actions.onChange = function(v) applyFullbright() end

-- =========================================================
-- CUSTOM SKYBOX
-- =========================================================
local SKYBOX_SETS = {
    { name = "Cartoon",  bk = "rbxassetid://151166353", dn = "rbxassetid://151166564", ft = "rbxassetid://151166637", lf = "rbxassetid://151166726", rt = "rbxassetid://151166856", up = "rbxassetid://151166925" },
    { name = "Nebula",   bk = "rbxassetid://159454299", dn = "rbxassetid://159454296", ft = "rbxassetid://159454293", lf = "rbxassetid://159454286", rt = "rbxassetid://159454300", up = "rbxassetid://159454288" },
    { name = "Space",    bk = "rbxassetid://162034038", dn = "rbxassetid://162034052", ft = "rbxassetid://162034019", lf = "rbxassetid://162034039", rt = "rbxassetid://162034034", up = "rbxassetid://162034055" },
    { name = "Sunset",   bk = "rbxassetid://161536924", dn = "rbxassetid://161536889", ft = "rbxassetid://161536890", lf = "rbxassetid://161536895", rt = "rbxassetid://161536907", up = "rbxassetid://161536908" },
    { name = "Cloudy",   bk = "rbxassetid://161007076", dn = "rbxassetid://161007027", ft = "rbxassetid://161007047", lf = "rbxassetid://161007059", rt = "rbxassetid://161007067", up = "rbxassetid://161007083" },
}

REFS.customSkyboxObj = nil

local function buildCustomSkybox()
    if REFS.customSkyboxObj and REFS.customSkyboxObj.Parent then REFS.customSkyboxObj:Destroy() end
    REFS.customSkyboxObj = nil
    if not MOD.customSkybox.enabled then return end
    local idx = math.clamp(math.floor(MOD.customSkybox.slider.value), 1, #SKYBOX_SETS)
    local set = SKYBOX_SETS[idx]
    if not set then return end
    local s = Instance.new("Sky")
    s.Name = "DesolateCustomSkybox"
    s.SkyboxBk = set.bk
    s.SkyboxDn = set.dn
    s.SkyboxFt = set.ft
    s.SkyboxLf = set.lf
    s.SkyboxRt = set.rt
    s.SkyboxUp = set.up
    s.SunAngularSize = 0
    s.MoonAngularSize = 0
    s.Parent = Lighting
    REFS.customSkyboxObj = s
end

MOD.customSkybox.actions.onToggle = function(on)
    if on then buildCustomSkybox() else
        if REFS.customSkyboxObj then REFS.customSkyboxObj:Destroy(); REFS.customSkyboxObj = nil end
    end
end
MOD.customSkybox.actions.onChange = function(v)
    if not MOD.customSkybox.enabled then return end
    buildCustomSkybox()
end

-- =========================================================
-- DAMAGE INDICATOR
-- =========================================================
local damageIndGui = Instance.new("ScreenGui")
damageIndGui.Name = "DesolateDmg"; damageIndGui.ResetOnSpawn = false; damageIndGui.IgnoreGuiInset = true
damageIndGui.DisplayOrder = 997
if gethui then local ok, h = pcall(gethui); if ok and h then damageIndGui.Parent = h end end
if not damageIndGui.Parent then local ok = pcall(function() damageIndGui.Parent = game:GetService("CoreGui") end); if not ok or not damageIndGui.Parent then damageIndGui.Parent = player:WaitForChild("PlayerGui") end end
REFS.lastHealth = nil
REFS.healthConn = nil
local function showDamageIndicator(dmg)
    local lbl = Instance.new("TextLabel")
    lbl.AnchorPoint = Vector2.new(0.5, 0.5)
    lbl.Position = UDim2.new(0.5, math.random(-30, 30), 0.5, 30)
    lbl.Size = UDim2.new(0, 200, 0, 30); lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 18
    lbl.TextStrokeTransparency = 0.4; lbl.TextColor3 = Color3.fromRGB(255, 80, 80)
    lbl.Text = "-" .. dmg; lbl.Parent = damageIndGui
    TweenService:Create(lbl, TweenInfo.new(0.8), {
        Position = UDim2.new(0.5, lbl.Position.X.Offset, 0.5, -20),
        TextTransparency = 1, TextStrokeTransparency = 1,
    }):Play()
    task.delay(0.9, function() if lbl and lbl.Parent then lbl:Destroy() end end)
end
MOD.damageInd.actions.onToggle = function(on)
    if on then
        REFS.healthConn = RunService.Heartbeat:Connect(function()
            local hum = CACHE.humanoid; if not hum then return end
            if REFS.lastHealth == nil then REFS.lastHealth = hum.Health; return end
            if hum.Health < REFS.lastHealth then
                local dmg = math.floor(REFS.lastHealth - hum.Health)
                if dmg > 0 then showDamageIndicator(dmg) end
            end
            REFS.lastHealth = hum.Health
        end)
    else
        if REFS.healthConn then REFS.healthConn:Disconnect(); REFS.healthConn = nil end
        REFS.lastHealth = nil
    end
end

-- =========================================================
-- TARGET HUD
-- =========================================================
REFS.targetHud = Instance.new("Frame")
REFS.targetHud.Size = UDim2.new(0, 220, 0, 70); REFS.targetHud.Position = UDim2.new(0.5, 40, 0.5, 40)
REFS.targetHud.BackgroundColor3 = BG2; REFS.targetHud.BackgroundTransparency = 0.1
REFS.targetHud.BorderSizePixel = 0; REFS.targetHud.Visible = false; REFS.targetHud.Parent = hudGui
Instance.new("UICorner", REFS.targetHud).CornerRadius = UDim.new(0, 8)
REFS.thName = Instance.new("TextLabel")
REFS.thName.BackgroundTransparency = 1; REFS.thName.Position = UDim2.new(0, 10, 0, 4); REFS.thName.Size = UDim2.new(1, -14, 0, 18)
REFS.thName.Font = FONT; REFS.thName.TextSize = 13; REFS.thName.TextColor3 = TEXT
REFS.thName.TextXAlignment = Enum.TextXAlignment.Left; REFS.thName.Text = "Target"; REFS.thName.Parent = REFS.targetHud
REFS.thInfo = Instance.new("TextLabel")
REFS.thInfo.BackgroundTransparency = 1; REFS.thInfo.Position = UDim2.new(0, 10, 0, 22); REFS.thInfo.Size = UDim2.new(1, -14, 0, 14)
REFS.thInfo.Font = FONT; REFS.thInfo.TextSize = 11; REFS.thInfo.TextColor3 = MUTED
REFS.thInfo.TextXAlignment = Enum.TextXAlignment.Left; REFS.thInfo.Text = "HP: -- | --m"; REFS.thInfo.Parent = REFS.targetHud
local thBarBg = Instance.new("Frame")
thBarBg.Position = UDim2.new(0, 10, 1, -16); thBarBg.Size = UDim2.new(1, -20, 0, 6)
thBarBg.BackgroundColor3 = BG4; thBarBg.BorderSizePixel = 0; thBarBg.Parent = REFS.targetHud
Instance.new("UICorner", thBarBg).CornerRadius = UDim.new(0, 6)
REFS.thBar = Instance.new("Frame")
REFS.thBar.Size = UDim2.new(1, 0, 1, 0); REFS.thBar.BackgroundColor3 = ERROR
REFS.thBar.BorderSizePixel = 0; REFS.thBar.Parent = thBarBg
Instance.new("UICorner", REFS.thBar).CornerRadius = UDim.new(0, 6)
MOD.targetHUD.actions.onToggle = function(on) REFS.targetHud.Visible = on end
makeDraggable(REFS.targetHud, "targethud")

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
REFS.fps = 0; REFS.frames = 0; REFS.t0 = tick()
RunService.RenderStepped:Connect(function()
    REFS.frames += 1
    local now = tick()
    if now - REFS.t0 >= 1 then REFS.fps = REFS.frames; REFS.frames = 0; REFS.t0 = now end
end)

-- =========================================================
-- MAIN LOOP
-- =========================================================
task.spawn(function()
    local tickCount = 0
    while gui.Parent do
        tickCount += 1
        if not CACHE.character or not CACHE.hrp or not CACHE.head then refreshCharacterCache() end

        if MOD.watermark.enabled then
            local ping = 0
            pcall(function() ping = math.floor(player:GetNetworkPing() * 1000) end)
            REFS.wLabel.Text = string.format("Desolate %s | FPS: %d | PING: %d", player.Name, REFS.fps, ping)
        end

        if MOD.coords.enabled and CACHE.hrp then
            REFS.coordLabel.Text = string.format("X: %.1f Y: %.1f Z: %.1f", CACHE.hrp.Position.X, CACHE.hrp.Position.Y, CACHE.hrp.Position.Z)
        end

        if MOD.keyBinds.enabled then
            local bound = getBoundModules()
            local lines = {}
            for _, entry in ipairs(bound) do
                if entry.mod.enabled then
                    table.insert(lines, string.format("%s — %s", entry.mod.keybind.Name, entry.mod.name))
                end
            end
            REFS.kbList.Text = #lines > 0 and table.concat(lines, "\n") or "no active binds"
        end

        if tickCount % 2 == 0 then
            if MOD.nameTags.enabled then
                for plr, data in pairs(REFS.nametags) do
                    if not plr or not plr.Parent then
                        if data.gui then data.gui:Destroy() end; REFS.nametags[plr] = nil
                    elseif plr.Character and CACHE.hrp then
                        local hum = plr.Character:FindFirstChildOfClass("Humanoid")
                        local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
                        if hum and hrp then
                            local dist = (hrp.Position - CACHE.hrp.Position).Magnitude
                            local sync = isSyncUser(plr)
                            data.name.Text = (sync and "* " or "") .. plr.Name
                            data.name.TextColor3 = sync and SYNC_COLOR or ACCENT
                            data.info.Text = string.format("HP: %d/%d | %dm", math.floor(hum.Health), math.floor(hum.MaxHealth), math.floor(dist))
                            local pct = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                            data.hbar.Size = UDim2.new(pct, 0, 1, 0)
                            data.hbar.BackgroundColor3 = pct > 0.5 and OK or pct > 0.25 and Color3.fromRGB(255, 220, 100) or ERROR
                        end
                    end
                end
            end

            if MOD.esp.enabled then
                for plr, hl in pairs(REFS.espHighlights) do
                    if not plr or not plr.Character or not plr.Character.Parent then
                        if hl then hl:Destroy() end; REFS.espHighlights[plr] = nil
                    elseif hl and hl.Adornee ~= plr.Character then hl.Adornee = plr.Character end
                end
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= player and plr.Character then
                        local hl = REFS.espHighlights[plr]
                        if not hl then
                            hl = Instance.new("Highlight"); hl.Name = "DesolateESP"
                            hl.Adornee = plr.Character; hl.FillTransparency = 0.65; hl.OutlineTransparency = 0
                            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                            hl.Parent = plr.Character; REFS.espHighlights[plr] = hl
                        end
                        if isSyncUser(plr) then hl.FillColor = SYNC_COLOR; hl.OutlineColor = Color3.fromRGB(120, 255, 150)
                        else hl.FillColor = Color3.fromRGB(255, 60, 60); hl.OutlineColor = ACCENT end
                    end
                end
            end

            if MOD.targetHUD.enabled then
                local plr, hum = getTarget()
                if plr and hum then
                    local hrp = hum.Parent:FindFirstChild("HumanoidRootPart")
                    local dist = 0
                    if hrp and CACHE.hrp then dist = (hrp.Position - CACHE.hrp.Position).Magnitude end
                    local sync = isSyncUser(plr)
                    REFS.thName.Text = (sync and "* " or "") .. plr.Name
                    REFS.thName.TextColor3 = sync and SYNC_COLOR or TEXT
                    REFS.thInfo.Text = string.format("HP: %d/%d | %dm", math.floor(hum.Health), math.floor(hum.MaxHealth), math.floor(dist))
                    local pct = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                    REFS.thBar.Size = UDim2.new(pct, 0, 1, 0)
                    REFS.thBar.BackgroundColor3 = pct > 0.5 and OK or pct > 0.25 and Color3.fromRGB(255, 220, 100) or ERROR
                else
                    REFS.thName.Text = "No target"; REFS.thInfo.Text = "---"
                    REFS.thBar.Size = UDim2.new(0, 0, 1, 0)
                end
            end
        end
        task.wait(0.05)
    end
end)

-- =========================================================
-- CAMERA
-- =========================================================
MOD.camera.actions.onToggle = function(on)
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
-- MOVEMENT
-- =========================================================
RunService.Heartbeat:Connect(function()
    local hum = CACHE.humanoid; if not hum then return end
    if MOD.walkSpeed.enabled then hum.WalkSpeed = MOD.walkSpeed.slider.value end
    if MOD.jumpPower.enabled then hum.UseJumpPower = true; hum.JumpPower = MOD.jumpPower.slider.value end
end)

REFS.flyBV = nil
REFS.flyBG = nil
MOD.fly.actions.onToggle = function(on)
    local hrp = CACHE.hrp; if not hrp then return end
    if on then
        REFS.flyBV = Instance.new("BodyVelocity"); REFS.flyBV.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        REFS.flyBV.Velocity = Vector3.new(0, 0, 0); REFS.flyBV.Parent = hrp
        REFS.flyBG = Instance.new("BodyGyro"); REFS.flyBG.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        REFS.flyBG.CFrame = hrp.CFrame; REFS.flyBG.Parent = hrp
    else
        if REFS.flyBV then REFS.flyBV:Destroy(); REFS.flyBV = nil end
        if REFS.flyBG then REFS.flyBG:Destroy(); REFS.flyBG = nil end
    end
end
RunService.Heartbeat:Connect(function()
    if not MOD.fly.enabled or not REFS.flyBV or not REFS.flyBG then return end
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
    REFS.flyBV.Velocity = move; REFS.flyBG.CFrame = camCF
end)

-- =========================================================
-- MOONWALK
-- =========================================================
REFS.moonwalkConn = nil
MOD.moonwalk.actions.onToggle = function(on)
    local hum = CACHE.humanoid
    if REFS.moonwalkConn then REFS.moonwalkConn:Disconnect(); REFS.moonwalkConn = nil end
    if on and hum then
        hum.AutoRotate = false
        REFS.moonwalkConn = RunService.RenderStepped:Connect(function()
            local h, hrp = CACHE.humanoid, CACHE.hrp
            if not h or not hrp then return end
            local look = Camera.CFrame.LookVector
            local flat = Vector3.new(look.X, 0, look.Z)
            if flat.Magnitude > 0.01 then
                flat = flat.Unit
                hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + flat)
            end
        end)
    else
        if hum then hum.AutoRotate = true end
    end
end

player.CharacterAdded:Connect(function()
    task.wait(0.5); refreshCharacterCache()
    if MOD.moonwalk.enabled and CACHE.humanoid then CACHE.humanoid.AutoRotate = false end
end)

MOD.reach.actions.onChange = function(v) if not MOD.reach.enabled then return end; pcall(function() player.Reach = v end) end
MOD.reach.actions.onToggle = function(on) pcall(function() player.Reach = on and MOD.reach.slider.value or 10 end) end

REFS.originalFOV = Camera.FieldOfView
MOD.fov.actions.onToggle = function(on) Camera.FieldOfView = on and MOD.fov.slider.value or REFS.originalFOV end
MOD.fov.actions.onChange = function(v) if not MOD.fov.enabled then return end; Camera.FieldOfView = v end

-- =========================================================
-- KILL EFFECT + KILL SOUND
-- =========================================================
local killGui = Instance.new("ScreenGui")
killGui.Name = "DesolateKill"; killGui.ResetOnSpawn = false; killGui.IgnoreGuiInset = true; killGui.DisplayOrder = 996
if gethui then local ok, h = pcall(gethui); if ok and h then killGui.Parent = h end end
if not killGui.Parent then local ok = pcall(function() killGui.Parent = game:GetService("CoreGui") end); if not ok or not killGui.Parent then killGui.Parent = player:WaitForChild("PlayerGui") end end
local function showKillEffect(name)
    local lbl = Instance.new("TextLabel")
    lbl.AnchorPoint = Vector2.new(0.5, 0.5); lbl.Position = UDim2.new(0.5, 0, 0.4, 0)
    lbl.Size = UDim2.new(0, 400, 0, 60); lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamBlack; lbl.TextSize = 36
    lbl.TextColor3 = ACCENT; lbl.TextStrokeTransparency = 0.3
    lbl.Text = "KILLED " .. name; lbl.Parent = killGui
    TweenService:Create(lbl, TweenInfo.new(1.2), { Position = UDim2.new(0.5, 0, 0.3, 0), TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
    task.delay(1.3, function() if lbl and lbl.Parent then lbl:Destroy() end end)
end
MOD.killEffect.actions.onToggle = function(on) end

REFS.killSoundObj = nil
local function ensureKillSound()
    if not REFS.killSoundObj or not REFS.killSoundObj.Parent then
        REFS.killSoundObj = Instance.new("Sound")
        REFS.killSoundObj.Name = "DesolateKillSound"
        REFS.killSoundObj.SoundId = "rbxassetid://5454616755"
        REFS.killSoundObj.Volume = MOD.killSound.sliders[1].value / 10
        REFS.killSoundObj.Parent = hudGui
    end
    return REFS.killSoundObj
end

local function playKillSound()
    local s = ensureKillSound()
    if s then
        s.Volume = MOD.killSound.sliders[1].value / 10
        s:Stop()
        s:Play()
    end
end

MOD.killSound.actions.onToggle = function(on)
    if not on and REFS.killSoundObj then REFS.killSoundObj:Stop() end
end
MOD.killSound.actions.onSliderChange = function(idx, v)
    if idx == 1 and REFS.killSoundObj then REFS.killSoundObj.Volume = v / 10 end
end

Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function(char)
        local hum = char:WaitForChild("Humanoid", 5); if not hum then return end
        hum.Died:Connect(function()
            local myHrp = CACHE.hrp; local hrp = char:FindFirstChild("HumanoidRootPart")
            if not myHrp or not hrp then return end
            local dist = (myHrp.Position - hrp.Position).Magnitude
            if MOD.killEffect.enabled and dist < 60 then showKillEffect(plr.Name) end
            if MOD.killSound.enabled and dist < MOD.killSound.sliders[2].value then playKillSound() end
        end)
    end)
end)

-- =========================================================
-- NOCLIP
-- =========================================================
REFS.noclipParts = {}
local function collectNoclipParts()
    REFS.noclipParts = {}
    local char = CACHE.character; if not char then return end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then table.insert(REFS.noclipParts, p) end
    end
end

MOD.noclip.actions.onToggle = function(on)
    if _G.Desolate_Noclip then _G.Desolate_Noclip:Disconnect(); _G.Desolate_Noclip = nil end
    if on then
        collectNoclipParts()
        _G.Desolate_Noclip = RunService.Stepped:Connect(function()
            for _, p in ipairs(REFS.noclipParts) do
                if p.Parent and p.CanCollide then p.CanCollide = false end
            end
        end)
    else
        for _, p in ipairs(REFS.noclipParts) do
            if p.Parent and p.Name ~= "HumanoidRootPart" then pcall(function() p.CanCollide = true end) end
        end
        REFS.noclipParts = {}
    end
end

player.CharacterAdded:Connect(function()
    task.wait(0.5); refreshCharacterCache()
    if MOD.noclip.enabled then collectNoclipParts() end
end)

-- =========================================================
-- ANTI-FLING
-- =========================================================
REFS.antiFlingConn = nil
MOD.antiFling.actions.onToggle = function(on)
    if REFS.antiFlingConn then REFS.antiFlingConn:Disconnect(); REFS.antiFlingConn = nil end
    if not on then return end
    REFS.antiFlingConn = RunService.Heartbeat:Connect(function()
        local char, hrp = CACHE.character, CACHE.hrp
        if not char or not hrp then return end
        local vel = hrp.AssemblyLinearVelocity
        if vel.Magnitude > 150 then
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") then pcall(function() p:SetNetworkOwner(player) end) end
            end
        end
        if hrp.Position.Y < -80 then
            hrp.CFrame = CFrame.new(0, 30, 0)
        end
    end)
end

-- =========================================================
-- HITBOX EXPANDER
-- =========================================================
REFS.hitboxOrig = {}
REFS.hitboxConn = nil

local function applyHitbox(plr)
    if not plr or plr == player or not plr.Character then return end
    local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    if not REFS.hitboxOrig[plr] then
        REFS.hitboxOrig[plr] = { size = hrp.Size, trans = hrp.Transparency, collide = hrp.CanCollide, massless = hrp.Massless }
    end
    local size = MOD.hitbox.slider.value
    hrp.Size = Vector3.new(size, size, size)
    hrp.Transparency = 0.5
    hrp.CanCollide = false
    hrp.Massless = true
end

local function restoreHitbox(plr)
    if not plr or not plr.Character then return end
    local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local orig = REFS.hitboxOrig[plr]
    if orig then
        hrp.Size = orig.size
        hrp.Transparency = orig.trans
        hrp.CanCollide = orig.collide
        hrp.Massless = orig.massless
    end
end

MOD.hitbox.actions.onToggle = function(on)
    if REFS.hitboxConn then REFS.hitboxConn:Disconnect(); REFS.hitboxConn = nil end
    if on then
        for _, plr in ipairs(Players:GetPlayers()) do applyHitbox(plr) end
        REFS.hitboxConn = RunService.Heartbeat:Connect(function()
            if not MOD.hitbox.enabled then return end
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= player and plr.Character then
                    local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        local size = MOD.hitbox.slider.value
                        if hrp.Size.X ~= size then applyHitbox(plr) end
                    end
                end
            end
        end)
    else
        for plr, _ in pairs(REFS.hitboxOrig) do restoreHitbox(plr) end
        REFS.hitboxOrig = {}
    end
end

MOD.hitbox.actions.onChange = function(v)
    if not MOD.hitbox.enabled then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player then applyHitbox(plr) end
    end
end

Players.PlayerAdded:Connect(function(plr)
    if MOD.hitbox.enabled then task.wait(1); applyHitbox(plr) end
end)
Players.PlayerRemoving:Connect(function(plr)
    REFS.hitboxOrig[plr] = nil
end)

-- =========================================================
-- AUTO PARRY
-- =========================================================
REFS.autoParryConn = nil
REFS.lastParryTime = 0

local function findNearestEnemy()
    local myHrp = CACHE.hrp
    if not myHrp then return nil, math.huge end
    local closest, closestDist = nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character then
            local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health > 0 then
                local d = (hrp.Position - myHrp.Position).Magnitude
                if d < closestDist then closest, closestDist = plr, d end
            end
        end
    end
    return closest, closestDist
end

local function activateDagger()
    local char = CACHE.character
    if char then
        local tool = char:FindFirstChildOfClass("Tool")
        if tool then
            pcall(function() tool:Activate() end)
        end
    end
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton1(Vector2.new())
    end)
end

MOD.autoParry.actions.onToggle = function(on)
    if REFS.autoParryConn then REFS.autoParryConn:Disconnect(); REFS.autoParryConn = nil end
    if not on then return end

    REFS.autoParryConn = RunService.Heartbeat:Connect(function()
        if not MOD.autoParry.enabled then return end
        local cooldown = MOD.autoParry.sliders[2].value
        if tick() - REFS.lastParryTime < cooldown then return end

        local _, dist = findNearestEnemy()
        if not dist or dist > MOD.autoParry.sliders[1].value then return end

        activateDagger()
        REFS.lastParryTime = tick()
    end)
end

-- =========================================================
-- ANTI-AFK
-- =========================================================
player.Idled:Connect(function()
    if not MOD.antiAfk or not MOD.antiAfk.enabled then return end
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end)

-- =========================================================
-- SPECTATE
-- =========================================================
REFS.spectateConn = nil
REFS.originalCameraSubject = nil
MOD.spectate.actions.onToggle = function(on)
    if REFS.spectateConn then REFS.spectateConn:Disconnect(); REFS.spectateConn = nil end
    if on then
        REFS.originalCameraSubject = Camera.CameraSubject
        REFS.spectateConn = RunService.Heartbeat:Connect(function()
            local cams = {}
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= player and plr.Character then
                    local hum = plr.Character:FindFirstChildOfClass("Humanoid")
                    if hum then table.insert(cams, hum) end
                end
            end
            if #cams == 0 then return end
            local idx = math.clamp(math.floor(MOD.spectate.slider.value), 1, #cams)
            Camera.CameraSubject = cams[idx]
        end)
    else
        if REFS.originalCameraSubject then pcall(function() Camera.CameraSubject = REFS.originalCameraSubject end) end
    end
end

-- =========================================================
-- FPS UNLOCK
-- =========================================================
REFS.originalFpsCap = 60

local function setFpsCap(v)
    if type(setfpscap) == "function" then
        local ok = pcall(setfpscap, v)
        if ok then return true end
    end
    if type(settings) == "function" then
        local ok = pcall(function()
            local s = settings()
            if s and s.Rendering then
                REFS.originalFpsCap = s.Rendering.FramerateCap or 60
                s.Rendering.FramerateCap = v
            end
        end)
        if ok then return true end
    end
    if type(sethiddenproperty) == "function" then
        local ok = pcall(sethiddenproperty, game, "FramerateCap", v)
        if ok then return true end
    end
    return false
end

MOD.fpsUnlock.actions.onToggle = function(on)
    if on then
        local ok = setFpsCap(9999)
        if not ok then
            warn("[Desolate] FPS Unlock: no supported method")
            MOD.fpsUnlock.enabled = false
            task.spawn(function() task.wait(0.05); refreshModules() end)
        end
    else
        setFpsCap(REFS.originalFpsCap or 60)
    end
end

-- =========================================================
-- PING SPOOF
-- =========================================================
REFS.fakePingSec = 0.02
REFS.pingSpoofed = false
REFS.pingHookInstalled = false

local function installPingHook()
    if REFS.pingHookInstalled then return true end
    if type(hookmetamethod) == "function" and type(newcclosure) == "function" and type(getnamecallmethod) == "function" then
        local ok = pcall(function()
            local old
            old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
                local method = getnamecallmethod()
                if REFS.pingSpoofed and (method == "GetNetworkPing" or method == "getnetworkping") then
                    return REFS.fakePingSec
                end
                return old(self, ...)
            end))
        end)
        if ok then REFS.pingHookInstalled = true; return true end
    end
    if type(getrawmetatable) == "function" and type(setreadonly) == "function"
       and type(newcclosure) == "function" and type(getnamecallmethod) == "function" then
        local ok = pcall(function()
            local mt = getrawmetatable(game)
            local oldNamecall = mt.__namecall
            setreadonly(mt, false)
            mt.__namecall = newcclosure(function(self, ...)
                local method = getnamecallmethod()
                if REFS.pingSpoofed and (method == "GetNetworkPing" or method == "getnetworkping") then
                    return REFS.fakePingSec
                end
                return oldNamecall(self, ...)
            end)
            setreadonly(mt, true)
        end)
        if ok then REFS.pingHookInstalled = true; return true end
    end
    return false
end

MOD.pingSpoof.actions.onToggle = function(on)
    if on then
        if not installPingHook() then
            warn("[Desolate] Ping Spoof: нет поддержки хука")
            MOD.pingSpoof.enabled = false
            task.spawn(function() task.wait(0.05); refreshModules() end)
            return
        end
        REFS.fakePingSec = MOD.pingSpoof.slider.value / 1000
        REFS.pingSpoofed = true
    else
        REFS.pingSpoofed = false
    end
end

MOD.pingSpoof.actions.onChange = function(v) REFS.fakePingSec = v / 1000 end

-- =========================================================
-- SERVER HOP + RESET HUD
-- =========================================================
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
                    pcall(function() TeleportService:TeleportToPlaceInstance(placeId, srv.id, player) end)
                    break
                end
            end
        end
        MOD.serverHop.enabled = false
    end)
end

MOD.resetHUDPos.actions.onToggle = function(on)
    if not on then return end
    for _, f in ipairs({ "desolate_hud_watermark.txt", "desolate_hud_coords.txt", "desolate_hud_targethud.txt", "desolate_hud_keybinds.txt" }) do
        pcall(function() if isfile(f) then delfile(f) end end)
    end
    REFS.watermark.Position = UDim2.new(0, 10, 0, 10)
    REFS.coordFrame.Position = UDim2.new(0, 10, 0, 60)
    REFS.targetHud.Position = UDim2.new(0.5, 40, 0.5, 40)
    REFS.kbFrame.Position = UDim2.new(0, 400, 0, 10)
    task.spawn(function() task.wait(0.3); MOD.resetHUDPos.enabled = false; refreshModules() end)
end

function applyLoadedModules()
    for cat, list in pairs(state) do
        for _, mod in ipairs(list) do
            if not mod.isHeader and mod.actions.onToggle then pcall(mod.actions.onToggle, mod.enabled) end
        end
    end
end

-- =========================================================
-- GLOBAL KEY HANDLER
-- =========================================================
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == OPEN_KEY then main.Visible = not main.Visible; return end
    for cat, list in pairs(state) do
        if cat ~= "Keybind" then
            for _, mod in ipairs(list) do
                if not mod.isHeader and mod.keybind and input.KeyCode == mod.keybind then
                    if (mod.mode or "toggle") == "hold" then
                        if not mod.enabled then
                            mod.enabled = true
                            if mod.actions.onToggle then pcall(mod.actions.onToggle, true) end
                        end
                    else
                        mod.enabled = not mod.enabled
                        if mod.actions.onToggle then pcall(mod.actions.onToggle, mod.enabled) end
                    end
                    if REFS.currentCat == cat then refreshModules() end
                end
            end
        end
    end
end)

UserInputService.InputEnded:Connect(function(input, gpe)
    if gpe then return end
    for cat, list in pairs(state) do
        if cat ~= "Keybind" then
            for _, mod in ipairs(list) do
                if not mod.isHeader and mod.keybind and input.KeyCode == mod.keybind then
                    if (mod.mode or "toggle") == "hold" and mod.enabled then
                        mod.enabled = false
                        if mod.actions.onToggle then pcall(mod.actions.onToggle, false) end
                        if REFS.currentCat == cat then refreshModules() end
                    end
                end
            end
        end
    end
end)

-- =========================================================
-- DRAG MAIN + MOBILE BUTTON
-- =========================================================
do
    local dragging, dragStart, startPos
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = main.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            if subMenu.Visible then subMenu.Position = main.Position end
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
end

REFS.mobileBtn = Instance.new("TextButton")
REFS.mobileBtn.Size = UDim2.new(0, 44, 0, 44); REFS.mobileBtn.Position = UDim2.new(0, 10, 0.5, -22)
REFS.mobileBtn.BackgroundColor3 = BG2; REFS.mobileBtn.TextColor3 = ACCENT
REFS.mobileBtn.Font = FONT; REFS.mobileBtn.TextSize = 16; REFS.mobileBtn.Text = "D"
REFS.mobileBtn.BorderSizePixel = 0; REFS.mobileBtn.Parent = gui
Instance.new("UICorner", REFS.mobileBtn).CornerRadius = UDim.new(0, 22)
REFS.mStroke = Instance.new("UIStroke"); REFS.mStroke.Color = ACCENT; REFS.mStroke.Thickness = 1; REFS.mStroke.Transparency = 0.4; REFS.mStroke.Parent = REFS.mobileBtn
REFS.mobileBtn.MouseButton1Click:Connect(function() main.Visible = not main.Visible end)
main:GetPropertyChangedSignal("Visible"):Connect(function() REFS.mobileBtn.Visible = not main.Visible end)

-- =========================================================
-- INIT
-- =========================================================
loadConfig()
refreshCategories()
refreshModules()

if currentTheme ~= "Dark" then
    local th = THEMES[currentTheme]
    if th then
        ACCENT = th.accent; BG = th.bg; BG2 = th.bg2; BG3 = th.bg3; BG4 = th.bg4
        TEXT = th.text; MUTED = th.muted
        applyStaticColors(); refreshCategories(); refreshModules()
    end
end

applyLoadedModules()
REFS.watermark.Visible = MOD.watermark.enabled
REFS.crosshair.Visible = MOD.crosshair.enabled
if MOD.chinaHat.enabled then buildChinaHat() end
if MOD.moonwalk.enabled and CACHE.humanoid then CACHE.humanoid.AutoRotate = false end
syncPing()
syncFetch()

print("[Desolate] v" .. VERSION .. " loaded - " .. player.Name)
