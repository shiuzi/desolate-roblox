--[[
    Desolate ClickGUI — с auth через UI + writefile
    Xeno v1.3.60+ | loadstring(game:HttpGet("URL"))()
]]

local VERSION = "1.4.0"

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

local player = Players.LocalPlayer

-- === HWID ===
local function getHwid()
    if gethwid then
        local ok, id = pcall(gethwid)
        if ok and id and tostring(id) ~= "" then return tostring(id) end
    end
    if syn and syn.get_hwid then
        local ok, id = pcall(function() return syn.get_hwid() end)
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
        if ok and res and res.Body then return res.Body, res.StatusCode or 200 end
    end
    if http_request then
        local ok, res = pcall(function()
            return http_request({
                Url = url, Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = payload,
            })
        end)
        if ok and res and res.Body then return res.Body, res.StatusCode or 200 end
    end
    local ok, res = pcall(function()
        return game:HttpGet(url .. "?" .. HttpService:UrlEncode(payload))
    end)
    if ok then return res, 200 end
    return nil, 0
end

-- === Server check ===
local function validateKey(key)
    local body = {
        userid = tostring(player.UserId),
        hwid   = getHwid(),
        key    = key,
    }
    local response = httpPost(AUTH_URL, body)
    if not response then return false, "Сервер недоступен." end

    local ok, data = pcall(function() return HttpService:JSONDecode(response) end)
    if not ok or type(data) ~= "table" then
        return false, "Некорректный ответ сервера."
    end

    if not data.valid then
        local reasons = {
            invalid_key     = "Неверный ключ",
            expired         = "Ключ истёк",
            banned          = "Ключ заблокирован",
            hwid_mismatch   = "Ключ привязан к другому устройству",
            userid_mismatch = "Ключ привязан к другому аккаунту",
        }
        return false, reasons[data.reason] or ("Отказ: " .. tostring(data.reason))
    end
    return true, data
end

-- === UI активации ===
local function showKeyUI(opts)
    local ACCENT = Color3.fromRGB(0, 224, 255)
    local BG     = Color3.fromRGB(14, 14, 18)
    local BG2    = Color3.fromRGB(24, 24, 30)
    local TEXT   = Color3.fromRGB(230, 230, 230)
    local MUTED  = Color3.fromRGB(140, 140, 150)
    local ERROR  = Color3.fromRGB(255, 80, 80)
    local OK     = Color3.fromRGB(80, 255, 140)
    local FONT   = Enum.Font.Code

    local sg = Instance.new("ScreenGui")
    sg.Name = "DesolateAuth_" .. tostring(math.random(1, 1e6))
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.DisplayOrder = 1000

    local parented = false
    if gethui then
        local ok, hui = pcall(gethui)
        if ok and hui then sg.Parent = hui; parented = true end
    end
    if not parented then
        local ok = pcall(function() sg.Parent = game:GetService("CoreGui") end)
        if not ok or not sg.Parent then
            sg.Parent = player:WaitForChild("PlayerGui")
        end
    end

    pcall(function()
        if xeno and xeno.protect_gui then xeno.protect_gui(sg) end
        if syn and syn.protect_gui then syn.protect_gui(sg) end
    end)

    local dim = Instance.new("Frame")
    dim.Size = UDim2.new(1, 0, 1, 0)
    dim.BackgroundColor3 = Color3.new(0, 0, 0)
    dim.BackgroundTransparency = 0.4
    dim.BorderSizePixel = 0
    dim.Parent = sg

    local W, H = 400, 220
    local box = Instance.new("Frame")
    box.Size = UDim2.new(0, W, 0, H)
    box.Position = UDim2.new(0.5, -W/2, 0.5, -H/2)
    box.BackgroundColor3 = BG
    box.BorderSizePixel = 0
    box.Active = true
    box.Parent = sg
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 8)

    local stroke = Instance.new("UIStroke")
    stroke.Color = ACCENT; stroke.Thickness = 1; stroke.Transparency = 0.5
    stroke.Parent = box

    local accentBar = Instance.new("Frame")
    accentBar.Size = UDim2.new(0, 3, 1, 0)
    accentBar.BackgroundColor3 = ACCENT
    accentBar.BorderSizePixel = 0
    accentBar.Parent = box
    Instance.new("UICorner", accentBar).CornerRadius = UDim.new(0, 8)

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Position = UDim2.new(0, 14, 0, 10)
    title.Size = UDim2.new(1, -28, 0, 22)
    title.Font = FONT; title.TextSize = 16
    title.TextColor3 = ACCENT
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = "Desolate · Activation"
    title.Parent = box

    local subtitle = Instance.new("TextLabel")
    subtitle.BackgroundTransparency = 1
    subtitle.Position = UDim2.new(0, 14, 0, 32)
    subtitle.Size = UDim2.new(1, -28, 0, 16)
    subtitle.Font = FONT; subtitle.TextSize = 12
    subtitle.TextColor3 = MUTED
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.Text = "Введи ключ активации"
    subtitle.Parent = box

    local inputHolder = Instance.new("Frame")
    inputHolder.Position = UDim2.new(0, 14, 0, 58)
    inputHolder.Size = UDim2.new(1, -28, 0, 40)
    inputHolder.BackgroundColor3 = BG2
    inputHolder.BorderSizePixel = 0
    inputHolder.Parent = box
    Instance.new("UICorner", inputHolder).CornerRadius = UDim.new(0, 6)

    local inputStroke = Instance.new("UIStroke")
    inputStroke.Color = Color3.fromRGB(50, 50, 60)
    inputStroke.Thickness = 1
    inputStroke.Parent = inputHolder

    local textBox = Instance.new("TextBox")
    textBox.Size = UDim2.new(1, -20, 1, 0)
    textBox.Position = UDim2.new(0, 10, 0, 0)
    textBox.BackgroundTransparency = 1
    textBox.Font = FONT; textBox.TextSize = 14
    textBox.TextColor3 = TEXT
    textBox.PlaceholderText = "DESO-XXXX-XXXX-XXXX"
    textBox.PlaceholderColor3 = Color3.fromRGB(90, 90, 100)
    textBox.TextXAlignment = Enum.TextXAlignment.Left
    textBox.ClearTextOnFocus = false
    textBox.Text = opts.initial or ""
    textBox.Parent = inputHolder

    local status = Instance.new("TextLabel")
    status.BackgroundTransparency = 1
    status.Position = UDim2.new(0, 14, 0, 108)
    status.Size = UDim2.new(1, -28, 0, 18)
    status.Font = FONT; status.TextSize = 12
    status.TextColor3 = MUTED
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.Text = ""
    status.Parent = box

    local activate = Instance.new("TextButton")
    activate.Size = UDim2.new(1, -28, 0, 36)
    activate.Position = UDim2.new(0, 14, 1, -56)
    activate.BackgroundColor3 = ACCENT
    activate.TextColor3 = Color3.fromRGB(10, 10, 12)
    activate.Font = FONT; activate.TextSize = 14
    activate.Text = "ACTIVATE"
    activate.BorderSizePixel = 0
    activate.AutoButtonColor = false
    activate.Parent = box
    Instance.new("UICorner", activate).CornerRadius = UDim.new(0, 6)

    local closeX = Instance.new("TextButton")
    closeX.Size = UDim2.new(0, 24, 0, 24)
    closeX.Position = UDim2.new(1, -32, 0, 8)
    closeX.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
    closeX.TextColor3 = TEXT
    closeX.Font = FONT; closeX.TextSize = 14
    closeX.Text = "×"
    closeX.BorderSizePixel = 0
    closeX.Parent = box
    Instance.new("UICorner", closeX).CornerRadius = UDim.new(0, 4)
    closeX.MouseButton1Click:Connect(function()
        sg:Destroy()
        if opts.onCancel then opts.onCancel() end
    end)

    local function setBusy(busy)
        activate.Active = not busy
        activate.Text = busy and "CHECKING..." or "ACTIVATE"
        activate.BackgroundColor3 = busy
            and Color3.fromRGB(60, 60, 70) or ACCENT
        textBox.TextEditable = not busy
    end

    local function tryActivate()
        local key = textBox.Text:gsub("%s+", "")
        if #key < 6 then
            status.TextColor3 = ERROR
            status.Text = "Ключ слишком короткий"
            inputStroke.Color = ERROR
            return
        end
        setBusy(true)
        status.TextColor3 = MUTED
        status.Text = "Проверка ключа..."
        inputStroke.Color = Color3.fromRGB(50, 50, 60)

        task.spawn(function()
            local ok, info = validateKey(key)
            task.wait(0.2)
            if ok then
                status.TextColor3 = OK
                status.Text = "Активация успешна"
                inputStroke.Color = OK
                fs.write(KEY_FILE, key)
                task.wait(0.5)
                sg:Destroy()
                if opts.onSuccess then opts.onSuccess(key, info) end
            else
                status.TextColor3 = ERROR
                status.Text = tostring(info)
                inputStroke.Color = ERROR
                setBusy(false)
            end
        end)
    end

    activate.MouseButton1Click:Connect(tryActivate)
    textBox.FocusLost:Connect(function(enterPressed)
        if enterPressed then tryActivate() end
    end)
end

-- === requireAuth ===
local function requireAuth()
    local savedKey = fs.read(KEY_FILE)
    if savedKey and #savedKey >= 6 then
        local ok = validateKey(savedKey)
        if ok then
            print("[Desolate] auto-auth OK")
            return true
        else
            fs.delete(KEY_FILE)
        end
    end

    local completed, success = false, false
    showKeyUI({
        initial = savedKey or "",
        onSuccess = function() completed, success = true, true end,
        onCancel = function() completed, success = true, false end,
    })
    while not completed do task.wait(0.1) end
    return success
end

if not requireAuth() then
    warn("[Desolate] access denied")
    return
end

-- =========================================================
-- CONFIG + STATE
-- =========================================================
local ACCENT = Color3.fromRGB(0, 224, 255)
local BG     = Color3.fromRGB(14, 14, 18)
local BG2    = Color3.fromRGB(20, 20, 26)
local BG3    = Color3.fromRGB(24, 24, 30)
local TEXT   = Color3.fromRGB(230, 230, 230)
local MUTED  = Color3.fromRGB(140, 140, 150)
local FONT   = Enum.Font.Code
local OPEN_KEY = Enum.KeyCode.RightShift

local state = {
    Render = {
        { name = "Watermark",  enabled = false, actions = {} },
        { name = "Fullbright", enabled = false, actions = {} },
    },
    HUD = {
        { name = "FPS Counter", enabled = true,  actions = {} },
        { name = "Coordinates", enabled = false, actions = {} },
    },
    Misc = {
        { name = "AntiAFK", enabled = false, actions = {} },
    },
    Player = {
        { name = "WalkSpeed", enabled = false, actions = {},
          slider = { min = 8, max = 100, value = 16 } },
        { name = "JumpPower", enabled = false, actions = {},
          slider = { min = 30, max = 150, value = 50 } },
    },
}

-- =========================================================
-- GUI ROOT
-- =========================================================
local gui = Instance.new("ScreenGui")
gui.Name = "Desolate_" .. tostring(math.random(1, 1e6))
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999

local parented = false
if gethui then
    local ok, hui = pcall(gethui)
    if ok and hui then gui.Parent = hui; parented = true end
end
if not parented then
    local ok = pcall(function() gui.Parent = game:GetService("CoreGui") end)
    if not ok or not gui.Parent then
        gui.Parent = player:WaitForChild("PlayerGui")
    end
end

pcall(function()
    if xeno and xeno.protect_gui then xeno.protect_gui(gui) end
    if syn and syn.protect_gui then syn.protect_gui(gui) end
end)

-- === MAIN WINDOW ===
local main = Instance.new("Frame")
main.Size = UDim2.new(0, 480, 0, 340)
main.Position = UDim2.new(0.5, -240, 0.5, -170)
main.BackgroundColor3 = BG
main.BorderSizePixel = 0
main.Active = true
main.Visible = false
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 8)

local stroke = Instance.new("UIStroke")
stroke.Color = ACCENT; stroke.Thickness = 1; stroke.Transparency = 0.6
stroke.Parent = main

-- Header
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 32)
header.BackgroundColor3 = BG2
header.BorderSizePixel = 0
header.Parent = main
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 8)

local headerMask = Instance.new("Frame")
headerMask.Size = UDim2.new(1, 0, 0, 8)
headerMask.Position = UDim2.new(0, 0, 1, -8)
headerMask.BackgroundColor3 = BG2
headerMask.BorderSizePixel = 0
headerMask.Parent = header

local accentBar = Instance.new("Frame")
accentBar.Size = UDim2.new(0, 3, 1, 0)
accentBar.BackgroundColor3 = ACCENT
accentBar.BorderSizePixel = 0
accentBar.Parent = header
Instance.new("UICorner", accentBar).CornerRadius = UDim.new(0, 8)

local titleLbl = Instance.new("TextLabel")
titleLbl.BackgroundTransparency = 1
titleLbl.Position = UDim2.new(0, 12, 0, 0)
titleLbl.Size = UDim2.new(1, -50, 1, 0)
titleLbl.Font = FONT; titleLbl.TextSize = 14
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.TextColor3 = ACCENT
titleLbl.Text = "Desolate · " .. player.Name .. " · v" .. VERSION
titleLbl.Parent = header

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 24, 0, 24)
closeBtn.Position = UDim2.new(1, -30, 0, 4)
closeBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
closeBtn.TextColor3 = TEXT
closeBtn.Font = FONT; closeBtn.TextSize = 14
closeBtn.Text = "×"
closeBtn.BorderSizePixel = 0
closeBtn.Parent = header
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 4)
closeBtn.MouseButton1Click:Connect(function() main.Visible = false end)

-- Body
local body = Instance.new("Frame")
body.Position = UDim2.new(0, 0, 0, 32)
body.Size = UDim2.new(1, 0, 1, -32)
body.BackgroundTransparency = 1
body.Parent = main

local catPanel = Instance.new("Frame")
catPanel.Size = UDim2.new(0, 115, 1, -16)
catPanel.Position = UDim2.new(0, 8, 0, 8)
catPanel.BackgroundColor3 = BG2
catPanel.BorderSizePixel = 0
catPanel.Parent = body
Instance.new("UICorner", catPanel).CornerRadius = UDim.new(0, 6)

local catList = Instance.new("UIListLayout")
catList.Padding = UDim.new(0, 4)
catList.SortOrder = Enum.SortOrder.LayoutOrder
catList.Parent = catPanel

local catPad = Instance.new("UIPadding")
catPad.PaddingTop = UDim.new(0, 6)
catPad.PaddingLeft = UDim.new(0, 6)
catPad.PaddingRight = UDim.new(0, 6)
catPad.Parent = catPanel

local modPanel = Instance.new("Frame")
modPanel.Size = UDim2.new(1, -135, 1, -16)
modPanel.Position = UDim2.new(0, 127, 0, 8)
modPanel.BackgroundColor3 = BG2
modPanel.BorderSizePixel = 0
modPanel.Parent = body
Instance.new("UICorner", modPanel).CornerRadius = UDim.new(0, 6)

local modScroll = Instance.new("ScrollingFrame")
modScroll.Size = UDim2.new(1, -8, 1, -8)
modScroll.Position = UDim2.new(0, 4, 0, 4)
modScroll.BackgroundTransparency = 1
modScroll.BorderSizePixel = 0
modScroll.ScrollBarThickness = 3
modScroll.ScrollBarImageColor3 = ACCENT
modScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
modScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
modScroll.Parent = modPanel

local modList = Instance.new("UIListLayout")
modList.Padding = UDim.new(0, 6)
modList.SortOrder = Enum.SortOrder.LayoutOrder
modList.Parent = modScroll

-- =========================================================
-- BUILDERS
-- =========================================================
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
        card.BackgroundColor3 = BG3
        card.BorderSizePixel = 0
        card.LayoutOrder = i
        card.Parent = modScroll
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 5)

        local stateBar = Instance.new("Frame")
        stateBar.Size = UDim2.new(0, 3, 1, 0)
        stateBar.BackgroundColor3 = mod.enabled and ACCENT or Color3.fromRGB(60, 60, 70)
        stateBar.BorderSizePixel = 0
        stateBar.Parent = card
        Instance.new("UICorner", stateBar).CornerRadius = UDim.new(0, 5)

        local nameLbl = Instance.new("TextLabel")
        nameLbl.BackgroundTransparency = 1
        nameLbl.Position = UDim2.new(0, 12, 0, 0)
        nameLbl.Size = UDim2.new(1, -60, 0, 30)
        nameLbl.Font = FONT; nameLbl.TextSize = 13
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.TextColor3 = mod.enabled and TEXT or MUTED
        nameLbl.Text = mod.name
        nameLbl.Parent = card

        local checkbox = Instance.new("TextButton")
        checkbox.Size = UDim2.new(0, 18, 0, 18)
        checkbox.Position = UDim2.new(1, -24, 0, 6)
        checkbox.BackgroundColor3 = mod.enabled and ACCENT or Color3.fromRGB(40, 40, 48)
        checkbox.Text = ""
        checkbox.BorderSizePixel = 0
        checkbox.Parent = card
        Instance.new("UICorner", checkbox).CornerRadius = UDim.new(0, 4)

        checkbox.MouseButton1Click:Connect(function()
            mod.enabled = not mod.enabled
            checkbox.BackgroundColor3 = mod.enabled and ACCENT or Color3.fromRGB(40, 40, 48)
            stateBar.BackgroundColor3 = mod.enabled and ACCENT or Color3.fromRGB(60, 60, 70)
            nameLbl.TextColor3 = mod.enabled and TEXT or MUTED
            if mod.actions.onToggle then
                pcall(mod.actions.onToggle, mod.enabled)
            end
        end)

        if mod.slider then
            local sl = mod.slider
            local track = Instance.new("Frame")
            track.Size = UDim2.new(1, -30, 0, 6)
            track.Position = UDim2.new(0, 15, 0, 46)
            track.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
            track.BorderSizePixel = 0
            track.Parent = card
            Instance.new("UICorner", track).CornerRadius = UDim.new(0, 3)

            local fill = Instance.new("Frame")
            fill.Size = UDim2.new((sl.value - sl.min) / (sl.max - sl.min), 0, 1, 0)
            fill.BackgroundColor3 = ACCENT
            fill.BorderSizePixel = 0
            fill.Parent = track
            Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 3)

            local valueLbl = Instance.new("TextLabel")
            valueLbl.BackgroundTransparency = 1
            valueLbl.Position = UDim2.new(1, -70, 0, 38)
            valueLbl.Size = UDim2.new(0, 60, 0, 16)
            valueLbl.Font = FONT; valueLbl.TextSize = 11
            valueLbl.TextColor3 = ACCENT
            valueLbl.Text = string.format("%.0f", sl.value)
            valueLbl.Parent = card

            local dragging = false
            local function update(input)
                local abs = track.AbsolutePosition.X
                local w = track.AbsoluteSize.X
                local pct = math.clamp((input.Position.X - abs) / w, 0, 1)
                local newVal = sl.min + (sl.max - sl.min) * pct
                sl.value = newVal
                fill.Size = UDim2.new(pct, 0, 1, 0)
                valueLbl.Text = string.format("%.0f", newVal)
                if mod.actions.onChange then
                    pcall(mod.actions.onChange, newVal)
                end
            end

            track.InputBegan:Connect(function(ip)
                if ip.UserInputType == Enum.UserInputType.MouseButton1
                   or ip.UserInputType == Enum.UserInputType.Touch then
                    dragging = true
                    update(ip)
                end
            end)
            UserInputService.InputChanged:Connect(function(ip)
                if dragging and (ip.UserInputType == Enum.UserInputType.MouseMovement
                   or ip.UserInputType == Enum.UserInputType.Touch) then
                    update(ip)
                end
            end)
            UserInputService.InputEnded:Connect(function(ip)
                if ip.UserInputType == Enum.UserInputType.MouseButton1
                   or ip.UserInputType == Enum.UserInputType.Touch then
                    dragging = false
                end
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
        btn.Name = catName
        btn.Size = UDim2.new(1, 0, 0, 26)
        btn.BackgroundColor3 = (catName == currentCat) and ACCENT or Color3.fromRGB(30, 30, 36)
        btn.TextColor3 = (catName == currentCat) and Color3.fromRGB(10, 10, 12) or TEXT
        btn.Font = FONT; btn.TextSize = 12
        btn.Text = catName
        btn.BorderSizePixel = 0
        btn.LayoutOrder = i
        btn.Parent = catPanel
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

        btn.MouseButton1Click:Connect(function()
            currentCat = catName
            refreshCategories()
            refreshModules()
        end)
        i += 1
    end
end

-- =========================================================
-- ACTIONS
-- =========================================================
-- Fullbright
state.Render[2].actions.onToggle = function(on)
    if on then
        Lighting.Ambient = Color3.fromRGB(200, 200, 200)
        Lighting.OutdoorAmbient = Color3.fromRGB(200, 200, 200)
        Lighting.Brightness = 3
    else
        Lighting.Ambient = Color3.fromRGB(70, 70, 70)
        Lighting.OutdoorAmbient = Color3.fromRGB(70, 70, 70)
        Lighting.Brightness = 2
    end
end

-- AntiAFK
state.Misc[1].actions.onToggle = function(on)
    if on then
        if not _G.Desolate_AntiAFK then
            _G.Desolate_AntiAFK = player.Idled:Connect(function()
                pcall(function()
                    game:GetService("VirtualUser"):CaptureController()
                    game:GetService("VirtualUser"):ClickButton2(Vector2.new())
                end)
            end)
        end
    else
        if _G.Desolate_AntiAFK then
            _G.Desolate_AntiAFK:Disconnect()
            _G.Desolate_AntiAFK = nil
        end
    end
end

-- WalkSpeed / JumpPower
RunService.Heartbeat:Connect(function()
    if not player.Character then return end
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if state.Player[1].enabled then
        hum.WalkSpeed = state.Player[1].slider.value
    end
    if state.Player[2].enabled then
        hum.UseJumpPower = true
        hum.JumpPower = state.Player[2].slider.value
    end
end)

-- =========================================================
-- WATERMARK + HUD
-- =========================================================
local hudGui = Instance.new("ScreenGui")
hudGui.Name = "DesolateHUD_" .. tostring(math.random(1, 1e6))
hudGui.ResetOnSpawn = false
hudGui.IgnoreGuiInset = true
hudGui.DisplayOrder = 998

local hudParented = false
if gethui then
    local ok, hui = pcall(gethui)
    if ok and hui then hudGui.Parent = hui; hudParented = true end
end
if not hudParented then
    local ok = pcall(function() hudGui.Parent = game:GetService("CoreGui") end)
    if not ok or not hudGui.Parent then
        hudGui.Parent = player:WaitForChild("PlayerGui")
    end
end

-- Watermark
local watermark = Instance.new("Frame")
watermark.Size = UDim2.new(0, 280, 0, 40)
watermark.Position = UDim2.new(0, 10, 0, 10)
watermark.BackgroundColor3 = BG2
watermark.BackgroundTransparency = 0.25
watermark.BorderSizePixel = 0
watermark.Visible = false
watermark.Parent = hudGui
Instance.new("UICorner", watermark).CornerRadius = UDim.new(0, 6)

local wAccent = Instance.new("Frame")
wAccent.Size = UDim2.new(0, 3, 1, 0)
wAccent.BackgroundColor3 = ACCENT
wAccent.BorderSizePixel = 0
wAccent.Parent = watermark
Instance.new("UICorner", wAccent).CornerRadius = UDim.new(0, 6)

local wLabel = Instance.new("TextLabel")
wLabel.BackgroundTransparency = 1
wLabel.Position = UDim2.new(0, 10, 0, 0)
wLabel.Size = UDim2.new(1, -14, 1, 0)
wLabel.Font = FONT; wLabel.TextSize = 12
wLabel.TextXAlignment = Enum.TextXAlignment.Left
wLabel.TextColor3 = TEXT
wLabel.Text = "Desolate"
wLabel.Parent = watermark

state.Render[1].actions.onToggle = function(on)
    watermark.Visible = on
end

-- FPS Counter
local fpsFrame = Instance.new("Frame")
fpsFrame.Size = UDim2.new(0, 110, 0, 24)
fpsFrame.Position = UDim2.new(0, 10, 0, 60)
fpsFrame.BackgroundColor3 = BG2
fpsFrame.BackgroundTransparency = 0.3
fpsFrame.BorderSizePixel = 0
fpsFrame.Visible = true
fpsFrame.Parent = hudGui
Instance.new("UICorner", fpsFrame).CornerRadius = UDim.new(0, 4)

local fpsLabel = Instance.new("TextLabel")
fpsLabel.BackgroundTransparency = 1
fpsLabel.Size = UDim2.new(1, -8, 1, 0)
fpsLabel.Position = UDim2.new(0, 4, 0, 0)
fpsLabel.Font = FONT; fpsLabel.TextSize = 12
fpsLabel.TextXAlignment = Enum.TextXAlignment.Left
fpsLabel.TextColor3 = TEXT
fpsLabel.Text = "FPS: --"
fpsLabel.Parent = fpsFrame

state.HUD[1].actions.onToggle = function(on)
    fpsFrame.Visible = on
end

-- Coordinates
local coordFrame = Instance.new("Frame")
coordFrame.Size = UDim2.new(0, 160, 0, 24)
coordFrame.Position = UDim2.new(0, 10, 0, 90)
coordFrame.BackgroundColor3 = BG2
coordFrame.BackgroundTransparency = 0.3
coordFrame.BorderSizePixel = 0
coordFrame.Visible = false
coordFrame.Parent = hudGui
Instance.new("UICorner", coordFrame).CornerRadius = UDim.new(0, 4)

local coordLabel = Instance.new("TextLabel")
coordLabel.BackgroundTransparency = 1
coordLabel.Size = UDim2.new(1, -8, 1, 0)
coordLabel.Position = UDim2.new(0, 4, 0, 0)
coordLabel.Font = FONT; coordLabel.TextSize = 12
coordLabel.TextXAlignment = Enum.TextXAlignment.Left
coordLabel.TextColor3 = TEXT
coordLabel.Text = "X: -- Y: -- Z: --"
coordLabel.Parent = coordFrame

state.HUD[2].actions.onToggle = function(on)
    coordFrame.Visible = on
end

-- FPS + Watermark + Coords обновление
local fps = 0
local frames = 0
local t0 = tick()

RunService.RenderStepped:Connect(function()
    frames += 1
    local now = tick()
    if now - t0 >= 1 then
        fps = frames
        frames = 0
        t0 = now
    end
end)

task.spawn(function()
    while gui.Parent do
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local ws = hum and hum.WalkSpeed or 0
        local ping = 0
        pcall(function()
            ping = math.floor(player:GetNetworkPing() * 1000)
        end)

        wLabel.Text = string.format("Desolate | FPS: %d | PING: %d | %s",
            fps, ping, player.Name)

        local fpsColor = fps >= 60 and Color3.fromRGB(120, 255, 120)
            or fps >= 30 and Color3.fromRGB(255, 220, 100)
            or Color3.fromRGB(255, 100, 100)
        fpsLabel.Text = string.format("FPS: %d", fps)
        fpsLabel.TextColor3 = fpsColor

        if hrp then
            coordLabel.Text = string.format("X: %.1f Y: %.1f Z: %.1f",
                hrp.Position.X, hrp.Position.Y, hrp.Position.Z)
        end

        task.wait(0.15)
    end
end)

-- =========================================================
-- DRAG WINDOW
-- =========================================================
do
    local dragging, dragStart, startPos
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
           or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

-- =========================================================
-- MOBILE BUTTON + OPEN KEY
-- =========================================================
local mobileBtn = Instance.new("TextButton")
mobileBtn.Size = UDim2.new(0, 44, 0, 44)
mobileBtn.Position = UDim2.new(0, 10, 0.5, -22)
mobileBtn.BackgroundColor3 = BG2
mobileBtn.TextColor3 = ACCENT
mobileBtn.Font = FONT; mobileBtn.TextSize = 16
mobileBtn.Text = "D"
mobileBtn.BorderSizePixel = 0
mobileBtn.Parent = gui
Instance.new("UICorner", mobileBtn).CornerRadius = UDim.new(0, 22)

local mStroke = Instance.new("UIStroke")
mStroke.Color = ACCENT
mStroke.Thickness = 1
mStroke.Transparency = 0.5
mStroke.Parent = mobileBtn

mobileBtn.MouseButton1Click:Connect(function()
    main.Visible = not main.Visible
end)

main:GetPropertyChangedSignal("Visible"):Connect(function()
    mobileBtn.Visible = not main.Visible
end)

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == OPEN_KEY then
        main.Visible = not main.Visible
    end
end)

-- =========================================================
-- INIT
-- =========================================================
refreshCategories()
refreshModules()

print("[Desolate] v" .. VERSION .. " loaded · " .. player.Name)
