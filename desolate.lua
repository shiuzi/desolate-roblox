--[[
    Desolate Client — v2.2.0
    Xeno v1.3.60+ | loadstring(game:HttpGet("URL"))()
    New: Custom Sky + Fog + Sky Preset
]]

local VERSION = "2.2.0"

-- =========================================================
-- AUTH CONFIG
-- =========================================================
local AUTH_URL  = "https://desolate-auth.desolate-ezi.workers.dev"
local KEY_FILE  = "desolate_key.txt"
local HWID_FILE = "desolate_hwid.txt"

local Players          = game:GetService("Players")
local HttpService      = game:GetService("HttpService")
local TweenService     = game:GetService("TweenService")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting         = game:GetService("Lighting")
local Workspace        = game:GetService("Workspace")
local VirtualUser      = game:GetService("VirtualUser")
local Camera           = Workspace.CurrentCamera

local player = Players.LocalPlayer

-- === HWID ===
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

-- === FS ===
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

-- === HTTP ===
local function httpPost(url, body)
    local payload = HttpService:JSONEncode(body)
    if request then
        local ok, res = pcall(function()
            return request({
                Url = url, Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = payload,
            })
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
    if not response then return false, "Сервер недоступен." end
    local ok, data = pcall(function() return HttpService:JSONDecode(response) end)
    if not ok or type(data) ~= "table" then return false, "Некорректный ответ." end
    if not data.valid then
        local reasons = {
            invalid_key = "Неверный ключ", expired = "Ключ истёк",
            banned = "Ключ заблокирован",
            hwid_mismatch = "Ключ привязан к другому устройству",
            userid_mismatch = "Ключ привязан к другому аккаунту",
        }
        return false, reasons[data.reason] or ("Отказ: " .. tostring(data.reason))
    end
    return true, data
end

-- === UI активации ===
local function showKeyUI(opts)
    local ACCENT = Color3.fromRGB(0, 224, 255)
    local BG, BG2 = Color3.fromRGB(14, 14, 18), Color3.fromRGB(24, 24, 30)
    local TEXT, MUTED = Color3.fromRGB(230, 230, 230), Color3.fromRGB(140, 140, 150)
    local ERROR, OK = Color3.fromRGB(255, 80, 80), Color3.fromRGB(80, 255, 140)
    local FONT = Enum.Font.Code

    local sg = Instance.new("ScreenGui")
    sg.Name = "DesolateAuth_" .. math.random(1, 1e6)
    sg.ResetOnSpawn = false; sg.IgnoreGuiInset = true; sg.DisplayOrder = 1000
    if gethui then
        local ok, h = pcall(gethui); if ok and h then sg.Parent = h end
    end
    if not sg.Parent then
        local ok = pcall(function() sg.Parent = game:GetService("CoreGui") end)
        if not ok or not sg.Parent then sg.Parent = player:WaitForChild("PlayerGui") end
    end

    local box = Instance.new("Frame")
    box.Size = UDim2.new(0, 400, 0, 220)
    box.Position = UDim2.new(0.5, -200, 0.5, -110)
    box.BackgroundColor3 = BG; box.BorderSizePixel = 0; box.Parent = sg
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 8)
    local st = Instance.new("UIStroke"); st.Color = ACCENT; st.Parent = box

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1; title.Position = UDim2.new(0, 14, 0, 12)
    title.Size = UDim2.new(1, -28, 0, 22); title.Font = FONT; title.TextSize = 16
    title.TextColor3 = ACCENT; title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = "Desolate · Activation"; title.Parent = box

    local inputHolder = Instance.new("Frame")
    inputHolder.Position = UDim2.new(0, 14, 0, 58)
    inputHolder.Size = UDim2.new(1, -28, 0, 40)
    inputHolder.BackgroundColor3 = BG2; inputHolder.BorderSizePixel = 0
    inputHolder.Parent = box
    Instance.new("UICorner", inputHolder).CornerRadius = UDim.new(0, 6)

    local textBox = Instance.new("TextBox")
    textBox.Size = UDim2.new(1, -20, 1, 0); textBox.Position = UDim2.new(0, 10, 0, 0)
    textBox.BackgroundTransparency = 1; textBox.Font = FONT; textBox.TextSize = 14
    textBox.TextColor3 = TEXT; textBox.PlaceholderText = "DESO-XXXX-XXXX-XXXX"
    textBox.TextXAlignment = Enum.TextXAlignment.Left; textBox.ClearTextOnFocus = false
    textBox.Text = opts.initial or ""; textBox.Parent = inputHolder

    local status = Instance.new("TextLabel")
    status.BackgroundTransparency = 1; status.Position = UDim2.new(0, 14, 0, 108)
    status.Size = UDim2.new(1, -28, 0, 18); status.Font = FONT; status.TextSize = 12
    status.TextColor3 = MUTED; status.TextXAlignment = Enum.TextXAlignment.Left
    status.Parent = box

    local activate = Instance.new("TextButton")
    activate.Size = UDim2.new(1, -28, 0, 36); activate.Position = UDim2.new(0, 14, 1, -50)
    activate.BackgroundColor3 = ACCENT; activate.TextColor3 = Color3.fromRGB(10, 10, 12)
    activate.Font = FONT; activate.TextSize = 14; activate.Text = "ACTIVATE"
    activate.BorderSizePixel = 0; activate.AutoButtonColor = false; activate.Parent = box
    Instance.new("UICorner", activate).CornerRadius = UDim.new(0, 6)

    local function tryActivate()
        local key = textBox.Text:gsub("%s+", "")
        if #key < 6 then
            status.TextColor3 = ERROR; status.Text = "Ключ слишком короткий"; return
        end
        activate.Text = "CHECKING..."; activate.Active = false
        task.spawn(function()
            local ok, info = validateKey(key)
            if ok then
                status.TextColor3 = OK; status.Text = "Активация успешна"
                fs.write(KEY_FILE, key); task.wait(0.5); sg:Destroy()
                if opts.onSuccess then opts.onSuccess() end
            else
                status.TextColor3 = ERROR; status.Text = tostring(info)
                activate.Text = "ACTIVATE"; activate.Active = true
            end
        end)
    end
    activate.MouseButton1Click:Connect(tryActivate)
    textBox.FocusLost:Connect(function(e) if e then tryActivate() end end)
end

local function requireAuth()
    local savedKey = fs.read(KEY_FILE)
    if savedKey and #savedKey >= 6 then
        local ok = validateKey(savedKey)
        if ok then return true end
        fs.delete(KEY_FILE)
    end
    local completed, success = false, false
    showKeyUI({
        initial = savedKey or "",
        onSuccess = function() completed, success = true, true end,
    })
    while not completed do task.wait(0.1) end
    return success
end

if not requireAuth() then return end

-- =========================================================
-- CONFIG
-- =========================================================
local ACCENT = Color3.fromRGB(0, 224, 255)
local BG, BG2, BG3 = Color3.fromRGB(14, 14, 18), Color3.fromRGB(20, 20, 26), Color3.fromRGB(24, 24, 30)
local TEXT, MUTED = Color3.fromRGB(230, 230, 230), Color3.fromRGB(140, 140, 150)
local FONT = Enum.Font.Code
local OPEN_KEY = Enum.KeyCode.RightShift

-- =========================================================
-- MODULE STATE
-- =========================================================
local state = {
    Render = {
        { name = "Watermark",  enabled = true,  actions = {} },   -- [1]
        { name = "Fullbright", enabled = false, actions = {} },   -- [2]
        { name = "Arrows",     enabled = false, actions = {} },   -- [3]
        { name = "NameTags",   enabled = false, actions = {} },   -- [4]
        { name = "ESP",        enabled = false, actions = {} },   -- [5]
        { name = "JumpCircle", enabled = false, actions = {} },   -- [6]
        { name = "Trails",     enabled = false, actions = {} },   -- [7]
        { name = "Particles",  enabled = false, actions = {} },   -- [8]
        { name = "Custom Sky", enabled = false, actions = {},     -- [9]
          slider = { min = 0, max = 24, value = 12 } },
        { name = "Fog",        enabled = false, actions = {},     -- [10]
          slider = { min = 0, max = 500, value = 100 } },
        { name = "Sky Preset", enabled = false, actions = {},     -- [11]
          slider = { min = 1, max = 5, value = 1 } },
    },
    HUD = {
        { name = "FPS Counter", enabled = true,  actions = {} },  -- [1]
        { name = "Coordinates", enabled = false, actions = {} },  -- [2]
        { name = "TargetHUD",   enabled = false, actions = {} },  -- [3]
        { name = "Crosshair",   enabled = true,  actions = {} },  -- [4]
    },
    Misc = {
        { name = "AntiAFK",       enabled = false, actions = {} },  -- [1]
        { name = "Noclip",        enabled = false, actions = {} },  -- [2]
        { name = "AutoClicker",   enabled = false, actions = {},    -- [3]
          slider = { min = 1, max = 20, value = 8 } },
        { name = "ServerHop",     enabled = false, actions = {} },  -- [4]
        { name = "Reset HUD Pos", enabled = false, actions = {} },  -- [5]
    },
    Player = {
        { name = "WalkSpeed", enabled = false, actions = {},        -- [1]
          slider = { min = 8, max = 200, value = 16 } },
        { name = "JumpPower", enabled = false, actions = {},        -- [2]
          slider = { min = 30, max = 300, value = 50 } },
        { name = "Fly",       enabled = false, actions = {},        -- [3]
          slider = { min = 10, max = 200, value = 60 } },
        { name = "BunnyHop",  enabled = false, actions = {} },      -- [4]
        { name = "Reach",     enabled = false, actions = {},        -- [5]
          slider = { min = 5, max = 50, value = 10 } },
    },
}

-- =========================================================
-- GUI ROOT
-- =========================================================
local gui = Instance.new("ScreenGui")
gui.Name = "Desolate_" .. math.random(1, 1e6)
gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true; gui.DisplayOrder = 999

if gethui then
    local ok, h = pcall(gethui); if ok and h then gui.Parent = h end
end
if not gui.Parent then
    local ok = pcall(function() gui.Parent = game:GetService("CoreGui") end)
    if not ok or not gui.Parent then gui.Parent = player:WaitForChild("PlayerGui") end
end

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 500, 0, 380)
main.Position = UDim2.new(0.5, -250, 0.5, -190)
main.BackgroundColor3 = BG; main.BorderSizePixel = 0
main.Active = true; main.Visible = false; main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 8)

local stroke = Instance.new("UIStroke")
stroke.Color = ACCENT; stroke.Thickness = 1; stroke.Transparency = 0.6
stroke.Parent = main

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 32)
header.BackgroundColor3 = BG2; header.BorderSizePixel = 0; header.Parent = main
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 8)

local headerMask = Instance.new("Frame")
headerMask.Size = UDim2.new(1, 0, 0, 8); headerMask.Position = UDim2.new(0, 0, 1, -8)
headerMask.BackgroundColor3 = BG2; headerMask.BorderSizePixel = 0; headerMask.Parent = header

local accentBar = Instance.new("Frame")
accentBar.Size = UDim2.new(0, 3, 1, 0); accentBar.BackgroundColor3 = ACCENT
accentBar.BorderSizePixel = 0; accentBar.Parent = header
Instance.new("UICorner", accentBar).CornerRadius = UDim.new(0, 8)

local titleLbl = Instance.new("TextLabel")
titleLbl.BackgroundTransparency = 1
titleLbl.Position = UDim2.new(0, 12, 0, 0); titleLbl.Size = UDim2.new(1, -50, 1, 0)
titleLbl.Font = FONT; titleLbl.TextSize = 14
titleLbl.TextXAlignment = Enum.TextXAlignment.Left; titleLbl.TextColor3 = ACCENT
titleLbl.Text = "Desolate · " .. player.Name .. " · v" .. VERSION
titleLbl.Parent = header

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 24, 0, 24); closeBtn.Position = UDim2.new(1, -30, 0, 4)
closeBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
closeBtn.TextColor3 = TEXT; closeBtn.Font = FONT; closeBtn.TextSize = 14
closeBtn.Text = "×"; closeBtn.BorderSizePixel = 0; closeBtn.Parent = header
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 4)
closeBtn.MouseButton1Click:Connect(function() main.Visible = false end)

local body = Instance.new("Frame")
body.Position = UDim2.new(0, 0, 0, 32); body.Size = UDim2.new(1, 0, 1, -32)
body.BackgroundTransparency = 1; body.Parent = main

local catPanel = Instance.new("Frame")
catPanel.Size = UDim2.new(0, 115, 1, -16); catPanel.Position = UDim2.new(0, 8, 0, 8)
catPanel.BackgroundColor3 = BG2; catPanel.BorderSizePixel = 0; catPanel.Parent = body
Instance.new("UICorner", catPanel).CornerRadius = UDim.new(0, 6)

local catList = Instance.new("UIListLayout")
catList.Padding = UDim.new(0, 4); catList.SortOrder = Enum.SortOrder.LayoutOrder
catList.Parent = catPanel

local catPad = Instance.new("UIPadding")
catPad.PaddingTop = UDim.new(0, 6); catPad.PaddingLeft = UDim.new(0, 6)
catPad.PaddingRight = UDim.new(0, 6); catPad.Parent = catPanel

local modPanel = Instance.new("Frame")
modPanel.Size = UDim2.new(1, -135, 1, -16); modPanel.Position = UDim2.new(0, 127, 0, 8)
modPanel.BackgroundColor3 = BG2; modPanel.BorderSizePixel = 0; modPanel.Parent = body
Instance.new("UICorner", modPanel).CornerRadius = UDim.new(0, 6)

local modScroll = Instance.new("ScrollingFrame")
modScroll.Size = UDim2.new(1, -8, 1, -8); modScroll.Position = UDim2.new(0, 4, 0, 4)
modScroll.BackgroundTransparency = 1; modScroll.BorderSizePixel = 0
modScroll.ScrollBarThickness = 3; modScroll.ScrollBarImageColor3 = ACCENT
modScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
modScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y; modScroll.Parent = modPanel

local modList = Instance.new("UIListLayout")
modList.Padding = UDim.new(0, 6); modList.SortOrder = Enum.SortOrder.LayoutOrder
modList.Parent = modScroll

local currentCat = "Render"

local function refreshModules()
    for _, c in ipairs(modScroll:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    local list = state[currentCat] or {}
    for i, mod in ipairs(list) do
        local card = Instance.new("Frame")
        card.Name = mod.name
        card.Size = UDim2.new(1, -8, 0, mod.slider and 62 or 30)
        card.BackgroundColor3 = BG3; card.BorderSizePixel = 0
        card.LayoutOrder = i; card.Parent = modScroll
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 5)

        local stateBar = Instance.new("Frame")
        stateBar.Size = UDim2.new(0, 3, 1, 0)
        stateBar.BackgroundColor3 = mod.enabled and ACCENT or Color3.fromRGB(60, 60, 70)
        stateBar.BorderSizePixel = 0; stateBar.Parent = card
        Instance.new("UICorner", stateBar).CornerRadius = UDim.new(0, 5)

        local nameLbl = Instance.new("TextLabel")
        nameLbl.BackgroundTransparency = 1
        nameLbl.Position = UDim2.new(0, 12, 0, 0); nameLbl.Size = UDim2.new(1, -60, 0, 30)
        nameLbl.Font = FONT; nameLbl.TextSize = 13
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.TextColor3 = mod.enabled and TEXT or MUTED
        nameLbl.Text = mod.name; nameLbl.Parent = card

        local checkbox = Instance.new("TextButton")
        checkbox.Size = UDim2.new(0, 18, 0, 18); checkbox.Position = UDim2.new(1, -24, 0, 6)
        checkbox.BackgroundColor3 = mod.enabled and ACCENT or Color3.fromRGB(40, 40, 48)
        checkbox.Text = ""; checkbox.BorderSizePixel = 0; checkbox.Parent = card
        Instance.new("UICorner", checkbox).CornerRadius = UDim.new(0, 4)

        checkbox.MouseButton1Click:Connect(function()
            mod.enabled = not mod.enabled
            checkbox.BackgroundColor3 = mod.enabled and ACCENT or Color3.fromRGB(40, 40, 48)
            stateBar.BackgroundColor3 = mod.enabled and ACCENT or Color3.fromRGB(60, 60, 70)
            nameLbl.TextColor3 = mod.enabled and TEXT or MUTED
            if mod.actions.onToggle then pcall(mod.actions.onToggle, mod.enabled) end
        end)

        if mod.slider then
            local sl = mod.slider
            local track = Instance.new("Frame")
            track.Size = UDim2.new(1, -30, 0, 6); track.Position = UDim2.new(0, 15, 0, 46)
            track.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
            track.BorderSizePixel = 0; track.Parent = card
            Instance.new("UICorner", track).CornerRadius = UDim.new(0, 3)

            local fill = Instance.new("Frame")
            fill.Size = UDim2.new((sl.value - sl.min) / (sl.max - sl.min), 0, 1, 0)
            fill.BackgroundColor3 = ACCENT; fill.BorderSizePixel = 0; fill.Parent = track
            Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 3)

            local valueLbl = Instance.new("TextLabel")
            valueLbl.BackgroundTransparency = 1
            valueLbl.Position = UDim2.new(1, -70, 0, 38)
            valueLbl.Size = UDim2.new(0, 60, 0, 16)
            valueLbl.Font = FONT; valueLbl.TextSize = 11; valueLbl.TextColor3 = ACCENT
            valueLbl.Text = string.format("%.0f", sl.value); valueLbl.Parent = card

            local dragging = false
            local function update(ip)
                local abs = track.AbsolutePosition.X
                local w = track.AbsoluteSize.X
                local pct = math.clamp((ip.Position.X - abs) / w, 0, 1)
                local newVal = sl.min + (sl.max - sl.min) * pct
                sl.value = newVal
                fill.Size = UDim2.new(pct, 0, 1, 0)
                valueLbl.Text = string.format("%.0f", newVal)
                if mod.actions.onChange then pcall(mod.actions.onChange, newVal) end
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
            if mod.actions.onChange then pcall(mod.actions.onChange, sl.value) end
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
        btn.BackgroundColor3 = (catName == currentCat) and ACCENT or Color3.fromRGB(30, 30, 36)
        btn.TextColor3 = (catName == currentCat) and Color3.fromRGB(10, 10, 12) or TEXT
        btn.Font = FONT; btn.TextSize = 12; btn.Text = catName
        btn.BorderSizePixel = 0; btn.LayoutOrder = i; btn.Parent = catPanel
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
        btn.MouseButton1Click:Connect(function()
            currentCat = catName; refreshCategories(); refreshModules()
        end)
        i += 1
    end
end

-- =========================================================
-- HUD LAYER
-- =========================================================
local hudGui = Instance.new("ScreenGui")
hudGui.Name = "DesolateHUD_" .. math.random(1, 1e6)
hudGui.ResetOnSpawn = false; hudGui.IgnoreGuiInset = true
hudGui.DisplayOrder = 998

if gethui then
    local ok, h = pcall(gethui); if ok and h then hudGui.Parent = h end
end
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
            local s = frame:FindFirstChildOfClass("UIStroke")
            if s then s.Transparency = 0 end
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
           or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            if dragging then
                dragging = false
                local s = frame:FindFirstChildOfClass("UIStroke")
                if s then s.Transparency = 0.75 end
                pcall(function()
                    fs.write("desolate_hud_" .. name .. ".txt",
                        frame.Position.X.Scale .. "," ..
                        frame.Position.X.Offset .. "," ..
                        frame.Position.Y.Scale .. "," ..
                        frame.Position.Y.Offset)
                end)
            end
        end
    end)
    local saved = fs.read("desolate_hud_" .. name .. ".txt")
    local loaded = false
    if saved then
        local nums = {}
        for v in saved:gmatch("([^,]+)") do
            table.insert(nums, tonumber(v))
        end
        if #nums >= 4 then
            frame.Position = UDim2.new(nums[1], nums[2], nums[3], nums[4])
            loaded = true
        end
    end
    if not loaded and defaultX and defaultY then
        frame.Position = UDim2.new(0, defaultX, 0, defaultY)
    end
    local hint = Instance.new("UIStroke")
    hint.Color = ACCENT; hint.Thickness = 1; hint.Transparency = 0.75
    hint.Parent = frame
end

-- =========================================================
-- WATERMARK
-- =========================================================
local watermark = Instance.new("Frame")
watermark.Size = UDim2.new(0, 320, 0, 40); watermark.Position = UDim2.new(0, 10, 0, 10)
watermark.BackgroundColor3 = BG2; watermark.BackgroundTransparency = 0.25
watermark.BorderSizePixel = 0; watermark.Visible = false; watermark.Parent = hudGui
Instance.new("UICorner", watermark).CornerRadius = UDim.new(0, 6)

local wAccent = Instance.new("Frame")
wAccent.Size = UDim2.new(0, 3, 1, 0); wAccent.BackgroundColor3 = ACCENT
wAccent.BorderSizePixel = 0; wAccent.Parent = watermark
Instance.new("UICorner", wAccent).CornerRadius = UDim.new(0, 6)

local wLabel = Instance.new("TextLabel")
wLabel.BackgroundTransparency = 1; wLabel.Position = UDim2.new(0, 10, 0, 0)
wLabel.Size = UDim2.new(1, -14, 1, 0); wLabel.Font = FONT; wLabel.TextSize = 12
wLabel.TextXAlignment = Enum.TextXAlignment.Left; wLabel.TextColor3 = TEXT
wLabel.Text = "Desolate"; wLabel.Parent = watermark

state.Render[1].actions.onToggle = function(on) watermark.Visible = on end
watermark.Visible = state.Render[1].enabled
makeDraggable(watermark, "watermark", 10, 10)

-- =========================================================
-- FPS COUNTER
-- =========================================================
local fpsFrame = Instance.new("Frame")
fpsFrame.Size = UDim2.new(0, 110, 0, 24); fpsFrame.Position = UDim2.new(0, 10, 0, 60)
fpsFrame.BackgroundColor3 = BG2; fpsFrame.BackgroundTransparency = 0.3
fpsFrame.BorderSizePixel = 0; fpsFrame.Visible = true; fpsFrame.Parent = hudGui
Instance.new("UICorner", fpsFrame).CornerRadius = UDim.new(0, 4)

local fpsLabel = Instance.new("TextLabel")
fpsLabel.BackgroundTransparency = 1; fpsLabel.Size = UDim2.new(1, -8, 1, 0)
fpsLabel.Position = UDim2.new(0, 4, 0, 0); fpsLabel.Font = FONT; fpsLabel.TextSize = 12
fpsLabel.TextXAlignment = Enum.TextXAlignment.Left; fpsLabel.TextColor3 = TEXT
fpsLabel.Text = "FPS: --"; fpsLabel.Parent = fpsFrame

state.HUD[1].actions.onToggle = function(on) fpsFrame.Visible = on end
makeDraggable(fpsFrame, "fps", 10, 60)

-- =========================================================
-- COORDINATES
-- =========================================================
local coordFrame = Instance.new("Frame")
coordFrame.Size = UDim2.new(0, 200, 0, 24); coordFrame.Position = UDim2.new(0, 10, 0, 90)
coordFrame.BackgroundColor3 = BG2; coordFrame.BackgroundTransparency = 0.3
coordFrame.BorderSizePixel = 0; coordFrame.Visible = false; coordFrame.Parent = hudGui
Instance.new("UICorner", coordFrame).CornerRadius = UDim.new(0, 4)

local coordLabel = Instance.new("TextLabel")
coordLabel.BackgroundTransparency = 1; coordLabel.Size = UDim2.new(1, -8, 1, 0)
coordLabel.Position = UDim2.new(0, 4, 0, 0); coordLabel.Font = FONT
coordLabel.TextSize = 12; coordLabel.TextXAlignment = Enum.TextXAlignment.Left
coordLabel.TextColor3 = TEXT; coordLabel.Text = "X: -- Y: -- Z: --"
coordLabel.Parent = coordFrame

state.HUD[2].actions.onToggle = function(on) coordFrame.Visible = on end
makeDraggable(coordFrame, "coords", 10, 90)

-- =========================================================
-- CROSSHAIR
-- =========================================================
local crosshair = Instance.new("Frame")
crosshair.Name = "Crosshair"
crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
crosshair.Position = UDim2.new(0.5, 0, 0.5, 0)
crosshair.Size = UDim2.new(0, 20, 0, 20)
crosshair.BackgroundTransparency = 1
crosshair.Visible = true
crosshair.Parent = hudGui

local chMode = "circle"

local function buildCrosshair()
    for _, c in ipairs(crosshair:GetChildren()) do c:Destroy() end
    if chMode == "dot" then
        local dot = Instance.new("Frame")
        dot.Size = UDim2.new(0, 3, 0, 3)
        dot.Position = UDim2.new(0.5, -1, 0.5, -1)
        dot.BackgroundColor3 = ACCENT; dot.BorderSizePixel = 0
        dot.Parent = crosshair
        Instance.new("UICorner", dot).CornerRadius = UDim.new(0, 999)
    elseif chMode == "circle" then
        local c = Instance.new("Frame")
        c.Size = UDim2.new(0, 14, 0, 14)
        c.Position = UDim2.new(0.5, -7, 0.5, -7)
        c.BackgroundTransparency = 1
        c.Parent = crosshair
        local stroke2 = Instance.new("UIStroke")
        stroke2.Color = ACCENT; stroke2.Thickness = 1.5; stroke2.Parent = c
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
            bar.BackgroundColor3 = ACCENT; bar.BorderSizePixel = 0
            bar.Parent = crosshair
        end
    end
end
buildCrosshair()

state.HUD[4].actions.onToggle = function(on) crosshair.Visible = on end

-- =========================================================
-- ARROWS
-- =========================================================
local arrowsContainer = Instance.new("Frame")
arrowsContainer.Size = UDim2.new(1, 0, 1, 0)
arrowsContainer.BackgroundTransparency = 1
arrowsContainer.Visible = false
arrowsContainer.Parent = hudGui

local arrowPool = {}
local function getArrow()
    for _, a in ipairs(arrowPool) do
        if not a.Visible then return a end
    end
    local f = Instance.new("TextLabel")
    f.AnchorPoint = Vector2.new(0.5, 0.5)
    f.Size = UDim2.new(0, 30, 0, 30)
    f.BackgroundTransparency = 1
    f.Font = Enum.Font.GothamBold
    f.TextSize = 24
    f.Text = "▶"
    f.TextColor3 = ACCENT
    f.Visible = false
    f.Parent = arrowsContainer
    table.insert(arrowPool, f)
    return f
end

state.Render[3].actions.onToggle = function(on) arrowsContainer.Visible = on end

-- =========================================================
-- NAMETAGS
-- =========================================================
local nametagFolder = Instance.new("Folder")
nametagFolder.Name = "DesolateNameTags"
nametagFolder.Parent = hudGui

local nametags = {}

local function createNametag(plr)
    local bb = Instance.new("BillboardGui")
    bb.Name = "NT_" .. plr.Name
    bb.Size = UDim2.new(0, 140, 0, 40)
    bb.StudsOffset = Vector3.new(0, 3.2, 0)
    bb.AlwaysOnTop = true
    bb.LightInfluence = 0

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
    bg.BackgroundTransparency = 0.25
    bg.BorderSizePixel = 0
    bg.Parent = bb
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 5)

    local name = Instance.new("TextLabel")
    name.BackgroundTransparency = 1
    name.Position = UDim2.new(0, 6, 0, 2)
    name.Size = UDim2.new(1, -12, 0, 14)
    name.Font = FONT; name.TextSize = 12
    name.TextColor3 = ACCENT
    name.TextXAlignment = Enum.TextXAlignment.Center
    name.Text = plr.Name
    name.Parent = bg

    local info = Instance.new("TextLabel")
    info.BackgroundTransparency = 1
    info.Position = UDim2.new(0, 6, 0, 16)
    info.Size = UDim2.new(1, -12, 0, 14)
    info.Font = FONT; info.TextSize = 11
    info.TextColor3 = TEXT
    info.TextXAlignment = Enum.TextXAlignment.Center
    info.Text = "HP: -- | --m"
    info.Parent = bg

    local healthBarBg = Instance.new("Frame")
    healthBarBg.Position = UDim2.new(0, 6, 1, -6)
    healthBarBg.Size = UDim2.new(1, -12, 0, 3)
    healthBarBg.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
    healthBarBg.BorderSizePixel = 0
    healthBarBg.Parent = bg
    Instance.new("UICorner", healthBarBg).CornerRadius = UDim.new(0, 3)

    local healthBar = Instance.new("Frame")
    healthBar.Size = UDim2.new(1, 0, 1, 0)
    healthBar.BackgroundColor3 = Color3.fromRGB(80, 255, 120)
    healthBar.BorderSizePixel = 0
    healthBar.Parent = healthBarBg
    Instance.new("UICorner", healthBar).CornerRadius = UDim.new(0, 3)

    return bb, name, info, healthBar
end

state.Render[4].actions.onToggle = function(on)
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
        for _, data in pairs(nametags) do
            if data.gui then data.gui:Destroy() end
        end
        nametags = {}
    end
end

Players.PlayerAdded:Connect(function(plr)
    if not state.Render[4].enabled then return end
    plr.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        if not state.Render[4].enabled then return end
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

state.Render[5].actions.onToggle = function(on)
    if on then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= player and plr.Character then
                local hl = Instance.new("Highlight")
                hl.Name = "DesolateESP"
                hl.Adornee = plr.Character
                hl.FillColor = Color3.fromRGB(255, 60, 60)
                hl.OutlineColor = ACCENT
                hl.FillTransparency = 0.65
                hl.OutlineTransparency = 0
                hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                hl.Parent = plr.Character
                espHighlights[plr] = hl
            end
        end
    else
        for _, hl in pairs(espHighlights) do
            if hl then hl:Destroy() end
        end
        espHighlights = {}
    end
end

-- =========================================================
-- JUMP CIRCLE
-- =========================================================
local jumpRings = {}

state.Render[6].actions.onToggle = function(on)
    if not on then
        for _, r in ipairs(jumpRings) do
            if r.part then r.part:Destroy() end
        end
        jumpRings = {}
    end
end

local wasOnGround = true
RunService.Heartbeat:Connect(function()
    if not state.Render[6].enabled then return end
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return end

    local onGround = hum.FloorMaterial ~= Enum.Material.Air
    if wasOnGround and not onGround then
        local ring = Instance.new("Part")
        ring.Shape = Enum.PartType.Cylinder
        ring.Anchored = true
        ring.CanCollide = false
        ring.CanQuery = false
        ring.CanTouch = false
        ring.Material = Enum.Material.Neon
        ring.Color = ACCENT
        ring.Transparency = 0.2
        ring.Size = Vector3.new(0.15, 2, 2)
        ring.CFrame = CFrame.new(hrp.Position - Vector3.new(0, 2.9, 0)) * CFrame.Angles(0, 0, math.rad(90))
        ring.Parent = Workspace
        table.insert(jumpRings, { part = ring, born = tick(), pos = hrp.Position })
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
-- TRAILS / PARTICLES
-- =========================================================
local trailAccum = 0
local particleAccum = 0

RunService.Heartbeat:Connect(function(dt)
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    if state.Render[7].enabled then
        trailAccum += dt
        if trailAccum >= 0.05 then
            trailAccum = 0
            local att = Instance.new("Attachment")
            att.Position = Vector3.new(0, -1.5, 0)
            att.Parent = hrp
            local emitter = Instance.new("ParticleEmitter")
            emitter.Texture = "rbxassetid://243098098"
            emitter.Color = ColorSequence.new(ACCENT)
            emitter.Size = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.5),
                NumberSequenceKeypoint.new(1, 0),
            })
            emitter.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.2),
                NumberSequenceKeypoint.new(1, 1),
            })
            emitter.Lifetime = NumberRange.new(0.6)
            emitter.Rate = 0
            emitter.Speed = NumberRange.new(0)
            emitter.Parent = att
            emitter:Emit(3)
            task.delay(1, function() if att and att.Parent then att:Destroy() end end)
        end
    end

    if state.Render[8].enabled then
        particleAccum += dt
        if particleAccum >= 0.1 then
            particleAccum = 0
            local p = Instance.new("Part")
            p.Size = Vector3.new(0.2, 0.2, 0.2)
            p.Anchored = true
            p.CanCollide = false
            p.CanQuery = false
            p.Material = Enum.Material.Neon
            p.Color = ACCENT
            p.Transparency = 0.3
            local angle = math.random() * math.pi * 2
            local r = 2
            p.CFrame = CFrame.new(
                hrp.Position + Vector3.new(math.cos(angle) * r, -1 + math.random() * 0.5, math.sin(angle) * r))
            p.Parent = Workspace
            TweenService:Create(p, TweenInfo.new(1), {
                Transparency = 1, Size = Vector3.new(0.05, 0.05, 0.05)
            }):Play()
            task.delay(1.1, function() if p and p.Parent then p:Destroy() end end)
        end
    end
end)

-- =========================================================
-- CUSTOM SKY + FOG + SKY PRESET
-- =========================================================
local SKY_PRESETS = {
    {
        name = "Day",
        clockTime = 12,
        ambient = Color3.fromRGB(128, 128, 128),
        outdoor = Color3.fromRGB(128, 128, 128),
        fogColor = Color3.fromRGB(200, 220, 255),
        fogEnd = 1000,
    },
    {
        name = "Sunset",
        clockTime = 17.5,
        ambient = Color3.fromRGB(90, 70, 80),
        outdoor = Color3.fromRGB(140, 90, 80),
        fogColor = Color3.fromRGB(255, 130, 80),
        fogEnd = 500,
    },
    {
        name = "Night",
        clockTime = 0,
        ambient = Color3.fromRGB(20, 20, 40),
        outdoor = Color3.fromRGB(30, 30, 60),
        fogColor = Color3.fromRGB(10, 10, 30),
        fogEnd = 300,
    },
    {
        name = "Desolate",
        clockTime = 22,
        ambient = Color3.fromRGB(20, 25, 35),
        outdoor = Color3.fromRGB(25, 30, 45),
        fogColor = Color3.fromRGB(0, 40, 60),
        fogEnd = 250,
    },
    {
        name = "Blood Moon",
        clockTime = 2,
        ambient = Color3.fromRGB(60, 15, 15),
        outdoor = Color3.fromRGB(80, 20, 20),
        fogColor = Color3.fromRGB(120, 0, 0),
        fogEnd = 200,
    },
}

local currentSkyPreset = 1
local customSkyObj = nil

-- Сохраняем оригинальные значения Lighting при запуске скрипта
local originalLighting = {
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    FogColor = Lighting.FogColor,
    FogStart = Lighting.FogStart,
    FogEnd = Lighting.FogEnd,
    ClockTime = Lighting.ClockTime,
    Brightness = Lighting.Brightness,
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
    Lighting.FogStart = 0
    Lighting.FogEnd = p.fogEnd
    Lighting.Brightness = 2
end

-- [9] Custom Sky
state.Render[9].actions.onToggle = function(on)
    if on then
        applySkyPreset(currentSkyPreset)
        Lighting.ClockTime = state.Render[9].slider.value
        -- если туман включён - синхронизируем с его слайдером
        if state.Render[10].enabled then
            Lighting.FogStart = 0
            Lighting.FogEnd = state.Render[10].slider.value
        end
    else
        if customSkyObj then
            customSkyObj:Destroy()
            customSkyObj = nil
        end
        pcall(function() Lighting.ClockTime = originalLighting.ClockTime end)
        pcall(function() Lighting.Ambient = originalLighting.Ambient end)
        pcall(function() Lighting.OutdoorAmbient = originalLighting.OutdoorAmbient end)
        pcall(function() Lighting.Brightness = originalLighting.Brightness end)
        -- если туман тоже выключен - возвращаем туман
        if not state.Render[10].enabled then
            pcall(function() Lighting.FogColor = originalLighting.FogColor end)
            pcall(function() Lighting.FogStart = originalLighting.FogStart end)
            pcall(function() Lighting.FogEnd = originalLighting.FogEnd end)
        end
    end
end

state.Render[9].actions.onChange = function(v)
    if not state.Render[9].enabled then return end
    Lighting.ClockTime = v
end

-- [10] Fog
state.Render[10].actions.onToggle = function(on)
    if on then
        Lighting.FogStart = 0
        Lighting.FogEnd = state.Render[10].slider.value
        if not state.Render[9].enabled then
            Lighting.FogColor = Color3.fromRGB(60, 70, 90)
        end
    else
        if not state.Render[9].enabled then
            Lighting.FogColor = originalLighting.FogColor
            Lighting.FogStart = originalLighting.FogStart
            Lighting.FogEnd = originalLighting.FogEnd
        end
    end
end

state.Render[10].actions.onChange = function(v)
    if not state.Render[10].enabled then return end
    Lighting.FogStart = 0
    Lighting.FogEnd = v
end

-- [11] Sky Preset
state.Render[11].actions.onToggle = function(on)
    if not on then return end
    currentSkyPreset = math.floor(state.Render[11].slider.value)
    if state.Render[9].enabled then
        applySkyPreset(currentSkyPreset)
        Lighting.ClockTime = state.Render[9].slider.value
        if state.Render[10].enabled then
            Lighting.FogEnd = state.Render[10].slider.value
        end
    end
end

state.Render[11].actions.onChange = function(v)
    currentSkyPreset = math.floor(v)
    if not state.Render[9].enabled then return end
    applySkyPreset(currentSkyPreset)
    Lighting.ClockTime = state.Render[9].slider.value
    if state.Render[10].enabled then
        Lighting.FogEnd = state.Render[10].slider.value
    end
end

-- =========================================================
-- TARGET HUD
-- =========================================================
local targetHud = Instance.new("Frame")
targetHud.Size = UDim2.new(0, 220, 0, 70)
targetHud.Position = UDim2.new(0.5, 40, 0.5, 40)
targetHud.BackgroundColor3 = BG2
targetHud.BackgroundTransparency = 0.2
targetHud.BorderSizePixel = 0
targetHud.Visible = false
targetHud.Parent = hudGui
Instance.new("UICorner", targetHud).CornerRadius = UDim.new(0, 6)

local thAccent = Instance.new("Frame")
thAccent.Size = UDim2.new(0, 3, 1, 0)
thAccent.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
thAccent.BorderSizePixel = 0; thAccent.Parent = targetHud
Instance.new("UICorner", thAccent).CornerRadius = UDim.new(0, 6)

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
thBarBg.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
thBarBg.BorderSizePixel = 0; thBarBg.Parent = targetHud
Instance.new("UICorner", thBarBg).CornerRadius = UDim.new(0, 6)

local thBar = Instance.new("Frame")
thBar.Size = UDim2.new(1, 0, 1, 0)
thBar.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
thBar.BorderSizePixel = 0; thBar.Parent = thBarBg
Instance.new("UICorner", thBar).CornerRadius = UDim.new(0, 6)

state.HUD[3].actions.onToggle = function(on) targetHud.Visible = on end
makeDraggable(targetHud, "targethud")

local function getTarget()
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = { player.Character, Workspace.CurrentCamera }
    params.FilterType = Enum.RaycastFilterType.Exclude
    local origin = Camera.CFrame.Position
    local dir = Camera.CFrame.LookVector * 300
    local result = Workspace:Raycast(origin, dir, params)
    if result and result.Instance then
        local model = result.Instance:FindFirstAncestorOfClass("Model")
        if model then
            local hum = model:FindFirstChildOfClass("Humanoid")
            if hum and Players:GetPlayerFromCharacter(model) then
                return Players:GetPlayerFromCharacter(model), hum, model
            end
        end
    end
    return nil
end

-- =========================================================
-- MAIN UPDATE LOOP
-- =========================================================
local fps = 0
local frames = 0
local t0 = tick()

RunService.RenderStepped:Connect(function()
    frames += 1
    local now = tick()
    if now - t0 >= 1 then fps = frames; frames = 0; t0 = now end
end)

task.spawn(function()
    while gui.Parent do
        if state.Render[1].enabled then
            local ping = 0
            pcall(function() ping = math.floor(player:GetNetworkPing() * 1000) end)
            wLabel.Text = string.format("Desolate | FPS: %d | PING: %d | %s", fps, ping, player.Name)
        end

        if state.HUD[1].enabled then
            fpsLabel.Text = "FPS: " .. fps
            fpsLabel.TextColor3 = fps >= 60 and Color3.fromRGB(120, 255, 120)
                or fps >= 30 and Color3.fromRGB(255, 220, 100)
                or Color3.fromRGB(255, 100, 100)
        end

        if state.HUD[2].enabled then
            local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                coordLabel.Text = string.format("X: %.1f Y: %.1f Z: %.1f",
                    hrp.Position.X, hrp.Position.Y, hrp.Position.Z)
            end
        end

        if state.Render[3].enabled then
            for _, a in ipairs(arrowPool) do a.Visible = false end
            local myChar = player.Character
            local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
            if myHrp and Camera then
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= player and plr.Character then
                        local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
                        local head = plr.Character:FindFirstChild("Head")
                        if hrp and head then
                            local targetPos = head.Position
                            local screenPos, onScreen = Camera:WorldToViewportPoint(targetPos)
                            local arrow = getArrow()
                            arrow.Visible = true

                            local myPos = Camera.CFrame.Position
                            local dir = (targetPos - myPos).Unit
                            local camDir = Camera.CFrame.LookVector
                            local dot = dir:Dot(camDir)
                            local behind = dot < 0

                            if onScreen and not behind and screenPos.Z > 0 then
                                arrow.Position = UDim2.new(0, screenPos.X, 0, screenPos.Y - 40)
                                local angle = math.atan2(
                                    targetPos.Y - Camera.CFrame.Position.Y,
                                    (Vector2.new(targetPos.X, targetPos.Z) - Vector2.new(myPos.X, myPos.Z)).Magnitude
                                )
                                arrow.Rotation = math.deg(angle)
                            else
                                local vpSize = Camera.ViewportSize
                                local rel = Camera.CFrame:PointToObjectSpace(targetPos)
                                local angle = math.atan2(rel.Y, rel.X)
                                local radius = math.min(vpSize.X, vpSize.Y) * 0.35
                                local cx, cy = vpSize.X / 2, vpSize.Y / 2
                                local ax = cx + math.cos(angle) * radius
                                local ay = cy + math.sin(angle) * radius
                                arrow.Position = UDim2.new(0, ax, 0, ay)
                                arrow.Rotation = math.deg(angle) + 180
                            end
                        end
                    end
                end
            end
        end

        if state.Render[4].enabled then
            for plr, data in pairs(nametags) do
                if not plr or not plr.Parent then
                    if data.gui then data.gui:Destroy() end
                    nametags[plr] = nil
                elseif plr.Character then
                    local hum = plr.Character:FindFirstChildOfClass("Humanoid")
                    local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
                    if hum and hrp and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                        local dist = (hrp.Position - player.Character.HumanoidRootPart.Position).Magnitude
                        local hp = hum.Health
                        local maxHp = hum.MaxHealth
                        data.info.Text = string.format("HP: %d/%d | %dm", math.floor(hp), math.floor(maxHp), math.floor(dist))
                        local pct = math.clamp(hp / maxHp, 0, 1)
                        data.hbar.Size = UDim2.new(pct, 0, 1, 0)
                        data.hbar.BackgroundColor3 = pct > 0.5 and Color3.fromRGB(80, 255, 120)
                            or pct > 0.25 and Color3.fromRGB(255, 220, 100)
                            or Color3.fromRGB(255, 80, 80)
                    end
                end
            end
        end

        if state.Render[5].enabled then
            for plr, hl in pairs(espHighlights) do
                if not plr or not plr.Character or not plr.Character.Parent then
                    if hl then hl:Destroy() end
                    espHighlights[plr] = nil
                elseif hl and hl.Adornee ~= plr.Character then
                    hl.Adornee = plr.Character
                end
            end
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= player and plr.Character and not espHighlights[plr] then
                    local hl = Instance.new("Highlight")
                    hl.Name = "DesolateESP"
                    hl.Adornee = plr.Character
                    hl.FillColor = Color3.fromRGB(255, 60, 60)
                    hl.OutlineColor = ACCENT
                    hl.FillTransparency = 0.65
                    hl.OutlineTransparency = 0
                    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    hl.Parent = plr.Character
                    espHighlights[plr] = hl
                end
            end
        end

        if state.HUD[3].enabled then
            local plr, hum = getTarget()
            if plr and hum then
                local hrp = hum.Parent:FindFirstChild("HumanoidRootPart")
                local dist = 0
                if hrp and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                    dist = (hrp.Position - player.Character.HumanoidRootPart.Position).Magnitude
                end
                thName.Text = plr.Name
                thInfo.Text = string.format("HP: %d/%d | %dm", math.floor(hum.Health), math.floor(hum.MaxHealth), math.floor(dist))
                local pct = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                thBar.Size = UDim2.new(pct, 0, 1, 0)
                thBar.BackgroundColor3 = pct > 0.5 and Color3.fromRGB(80, 255, 120)
                    or pct > 0.25 and Color3.fromRGB(255, 220, 100)
                    or Color3.fromRGB(255, 80, 80)
            else
                thName.Text = "No target"
                thInfo.Text = "---"
                thBar.Size = UDim2.new(0, 0, 1, 0)
            end
        end

        task.wait(0.05)
    end
end)

-- =========================================================
-- PLAYER ACTIONS
-- =========================================================
-- [2] Fullbright
state.Render[2].actions.onToggle = function(on)
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

RunService.Heartbeat:Connect(function()
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if state.Player[1].enabled then hum.WalkSpeed = state.Player[1].slider.value end
    if state.Player[2].enabled then
        hum.UseJumpPower = true
        hum.JumpPower = state.Player[2].slider.value
    end
end)

local flyBV, flyBG
state.Player[3].actions.onToggle = function(on)
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    if on then
        flyBV = Instance.new("BodyVelocity")
        flyBV.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        flyBV.Velocity = Vector3.new(0, 0, 0)
        flyBV.Parent = hrp
        flyBG = Instance.new("BodyGyro")
        flyBG.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        flyBG.CFrame = hrp.CFrame
        flyBG.Parent = hrp
    else
        if flyBV then flyBV:Destroy(); flyBV = nil end
        if flyBG then flyBG:Destroy(); flyBG = nil end
    end
end

RunService.Heartbeat:Connect(function()
    if not state.Player[3].enabled then return end
    if not flyBV or not flyBG then return end
    local speed = state.Player[3].slider.value
    local move = Vector3.new(0, 0, 0)
    local camCF = Camera.CFrame
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then move += camCF.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then move -= camCF.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then move -= camCF.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += camCF.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.new(0, 1, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then move -= Vector3.new(0, 1, 0) end
    if move.Magnitude > 0 then move = move.Unit * speed end
    flyBV.Velocity = move
    flyBG.CFrame = camCF
end)

state.Player[4].actions.onToggle = function(on) end
RunService.Heartbeat:Connect(function()
    if not state.Player[4].enabled then return end
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local vel = hum.RootPart and hum.RootPart.Velocity or Vector3.new(0, 0, 0)
    if vel.Magnitude > 2 and hum.FloorMaterial ~= Enum.Material.Air then
        hum.Jump = true
    end
end)

state.Player[5].actions.onChange = function(v)
    if not state.Player[5].enabled then return end
    pcall(function() player.Reach = v end)
end
state.Player[5].actions.onToggle = function(on)
    if on then
        pcall(function() player.Reach = state.Player[5].slider.value end)
    else
        pcall(function() player.Reach = 10 end)
    end
end

-- =========================================================
-- MISC ACTIONS
-- =========================================================
state.Misc[1].actions.onToggle = function(on)
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

state.Misc[2].actions.onToggle = function(on)
    if on then
        if _G.Desolate_Noclip then _G.Desolate_Noclip:Disconnect() end
        _G.Desolate_Noclip = RunService.Stepped:Connect(function()
            local char = player.Character
            if not char then return end
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") and p.CanCollide then
                    p.CanCollide = false
                end
            end
        end)
    else
        if _G.Desolate_Noclip then
            _G.Desolate_Noclip:Disconnect()
            _G.Desolate_Noclip = nil
        end
        local char = player.Character
        if char then
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
                    pcall(function() p.CanCollide = true end)
                end
            end
        end
    end
end

state.Misc[3].actions.onToggle = function(on) end
RunService.Heartbeat:Connect(function()
    if not state.Misc[3].enabled then return end
    local cps = state.Misc[3].slider.value
    local interval = 1 / math.max(cps, 1)
    if math.random() < math.min(interval, 1) then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton1(Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2))
        end)
    end
end)

state.Misc[4].actions.onToggle = function(on)
    if not on then return end
    task.spawn(function()
        local placeId = game.PlaceId
        local url = "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100"
        local ok, body = pcall(function() return game:HttpGet(url) end)
        if not ok or not body then
            state.Misc[4].enabled = false
            return
        end
        local data = HttpService:JSONDecode(body)
        if data and data.data then
            for _, srv in ipairs(data.data) do
                if srv.playing < srv.maxPlayers and srv.id ~= game.JobId then
                    pcall(function()
                        game:GetService("TeleportService"):TeleportToPlaceInstance(placeId, srv.id, player)
                    end)
                    break
                end
            end
        end
        state.Misc[4].enabled = false
    end)
end

state.Misc[5].actions.onToggle = function(on)
    if not on then return end
    local files = {
        "desolate_hud_watermark.txt",
        "desolate_hud_fps.txt",
        "desolate_hud_coords.txt",
        "desolate_hud_targethud.txt",
    }
    for _, f in ipairs(files) do
        pcall(function() if isfile(f) then delfile(f) end end)
    end
    watermark.Position = UDim2.new(0, 10, 0, 10)
    fpsFrame.Position = UDim2.new(0, 10, 0, 60)
    coordFrame.Position = UDim2.new(0, 10, 0, 90)
    targetHud.Position = UDim2.new(0.5, 40, 0.5, 40)
    task.spawn(function()
        task.wait(0.3)
        state.Misc[5].enabled = false
        refreshModules()
    end)
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
            main.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y)
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
mStroke.Color = ACCENT; mStroke.Thickness = 1; mStroke.Transparency = 0.5
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
refreshCategories()
refreshModules()

watermark.Visible = state.Render[1].enabled
fpsFrame.Visible = state.HUD[1].enabled
crosshair.Visible = state.HUD[4].enabled

print("[Desolate] v" .. VERSION .. " loaded · " .. player.Name)
