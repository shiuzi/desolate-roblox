--[[
    Desolate ClickGUI — с auth через UI + writefile
    Xeno v1.3.60+ | loadstring(game:HttpGet("URL"))()
]]

local VERSION = "1.3.0"

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

-- === FS helpers ===
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

-- === HTTP POST ===
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
    stroke.Color = ACCENT
    stroke.Thickness = 1
    stroke.Transparency = 0.5
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
    title.Font = FONT
    title.TextSize = 16
    title.TextColor3 = ACCENT
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = "Desolate · Activation"
    title.Parent = box

    local subtitle = Instance.new("TextLabel")
    subtitle.BackgroundTransparency = 1
    subtitle.Position = UDim2.new(0, 14, 0, 32)
    subtitle.Size = UDim2.new(1, -28, 0, 16)
    subtitle.Font = FONT
    subtitle.TextSize = 12
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
    textBox.Font = FONT
    textBox.TextSize = 14
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
    status.Font = FONT
    status.TextSize = 12
    status.TextColor3 = MUTED
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.Text = ""
    status.Parent = box

    local activate = Instance.new("TextButton")
    activate.Size = UDim2.new(1, -28, 0, 36)
    activate.Position = UDim2.new(0, 14, 1, -56)
    activate.BackgroundColor3 = ACCENT
    activate.TextColor3 = Color3.fromRGB(10, 10, 12)
    activate.Font = FONT
    activate.TextSize = 14
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
    closeX.Font = FONT
    closeX.TextSize = 14
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

-- === Главная проверка ===
local function requireAuth()
    local savedKey = fs.read(KEY_FILE)

    if savedKey and #savedKey >= 6 then
        print("[Desolate] checking saved key...")
        local ok, info = validateKey(savedKey)
        if ok then
            print("[Desolate] auto-auth OK · plan=" .. tostring(info.plan))
            return true
        else
            warn("[Desolate] saved key invalid: " .. tostring(info))
            fs.delete(KEY_FILE)
        end
    end

    local completed, success = false, false
    showKeyUI({
        initial = savedKey or "",
        onSuccess = function(key, info)
            completed, success = true, true
        end,
        onCancel = function()
            completed, success = true, false
        end,
    })

    while not completed do task.wait(0.1) end
    return success
end

if not requireAuth() then
    warn("[Desolate] access denied")
    return
end

-- =========================================================
-- CLICKGUI (упрощённый — только HUD/Player для теста)
-- =========================================================
print("[Desolate] loading GUI...")

local ACCENT = Color3.fromRGB(0, 224, 255)
local BG     = Color3.fromRGB(14, 14, 18)
local BG2    = Color3.fromRGB(20, 20, 26)
local BG3    = Color3.fromRGB(24, 24, 30)
local TEXT   = Color3.fromRGB(230, 230, 230)
local MUTED  = Color3.fromRGB(140, 140, 150)
local FONT   = Enum.Font.Code

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
stroke.Color = ACCENT
stroke.Thickness = 1
stroke.Transparency = 0.6
stroke.Parent = main

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

local titleLbl = Instance.new("TextLabel")
titleLbl.BackgroundTransparency = 1
titleLbl.Position = UDim2.new(0, 12, 0, 0)
titleLbl.Size = UDim2.new(1, -50, 1, 0)
titleLbl.Font = FONT
titleLbl.TextSize = 14
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.TextColor3 = ACCENT
titleLbl.Text = "Desolate · " .. player.Name .. " · v" .. VERSION
titleLbl.Parent = header

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 24, 0, 24)
closeBtn.Position = UDim2.new(1, -30, 0, 4)
closeBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
closeBtn.TextColor3 = TEXT
closeBtn.Font = FONT
closeBtn.TextSize = 14
closeBtn.Text = "×"
closeBtn.BorderSizePixel = 0
closeBtn.Parent = header
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 4)
closeBtn.MouseButton1Click:Connect(function() main.Visible = false end)

-- Простой контент — просто текст-заглушка
local info = Instance.new("TextLabel")
info.BackgroundTransparency = 1
info.Position = UDim2.new(0, 20, 0, 60)
info.Size = UDim2.new(1, -40, 0, 200)
info.Font = FONT
info.TextSize = 14
info.TextColor3 = TEXT
info.TextXAlignment = Enum.TextXAlignment.Left
info.TextYAlignment = Enum.TextYAlignment.Top
info.TextWrapped = true
info.Text = "✅ Активация успешна!\n\nGUI работает.\n\nМодули (WalkSpeed, HUD и т.д.) — добавим в следующей итерации.\n\nНажми × чтобы закрыть, RightShift / кнопка D — открыть заново."
info.Parent = main

-- Мобильная кнопка
local mobileBtn = Instance.new("TextButton")
mobileBtn.Size = UDim2.new(0, 44, 0, 44)
mobileBtn.Position = UDim2.new(0, 10, 0.5, -22)
mobileBtn.BackgroundColor3 = BG2
mobileBtn.TextColor3 = ACCENT
mobileBtn.Font = FONT
mobileBtn.TextSize = 16
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

-- Драг окна
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

-- RightShift для открытия
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        main.Visible = not main.Visible
    end
end)

print("[Desolate] v" .. VERSION .. " ready! Press RightShift or D")
