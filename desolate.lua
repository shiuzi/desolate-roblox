-- Desolate Client v4.2.1
-- Xeno loader via request
-- Changes: Arrows removed, falling Particles, China Hat with Neon+Light, bugfix

local VERSION = "4.2.1"

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

local state = {
    Render = {
        { name = "Visuals",          isHeader = true },
        { name = "Watermark",    enabled = true,  actions = {} },
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
    },
    HUD = {
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

local syncSet = {}
local syncMod = findMod("Render", "Show Desolate Users")

local function syncPing()
    task.spawn(function()
        while gui and gui.Parent do
            if syncMod.enabled then
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
            if syncMod.enabled then
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
