local addonName, GG = ...
_G.GroupGazette = GG

GG.entries = {}
GG.state = { cat = "all", roles = {}, search = "" }

local lower, find, match, gsub, format = string.lower, string.find, string.match, string.gsub, string.format
local GetTime = GetTime
local PREFIX = "|cff33ff99Group Gazette:|r "

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. msg)
end
GG.Print = Print

---------------------------------------------------------------------------
-- Saved variables
---------------------------------------------------------------------------
local defaults = {
    expire  = 180,      -- seconds before a listing disappears
    hide    = false,    -- hide LFM messages from the chat frames
    sound   = true,     -- play a sound on watch-keyword hits
    skin    = true,     -- apply the ElvUI skin (if ElvUI is loaded)
    watch   = {},       -- keywords that trigger an alert
}

local function CopyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

---------------------------------------------------------------------------
-- Compile the instance dictionary into Lua patterns
---------------------------------------------------------------------------
local function Escape(s)
    return (gsub(s, "[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
end

GG.Compiled = {}
for _, inst in ipairs(GG.Instances) do
    local pats = {}
    for i = 3, #inst do
        pats[#pats + 1] = "%f[%w]" .. Escape(GG.Normalize(inst[i])) .. "%f[%W]"
    end
    GG.Compiled[#GG.Compiled + 1] = { label = inst[1], cat = inst[2], pats = pats }
end

---------------------------------------------------------------------------
-- Message parsing
---------------------------------------------------------------------------
local ROLEWORD = {
    tank = true, tanks = true,
    heal = true, heals = true, healer = true, healers = true,
    dps = true, rdps = true, mdps = true, dd = true, dds = true,
}

-- Strip colour codes, hyperlinks (keeping "[Name]") and raid-target tags.
local function Clean(msg)
    msg = gsub(msg, "|c%x%x%x%x%x%x%x%x", "")
    msg = gsub(msg, "|r", "")
    msg = gsub(msg, "|H.-|h%[?(.-)%]?|h", "[%1]")
    msg = gsub(msg, "%b{}", "")
    return msg
end

local function IsLFM(l)
    if find(l, "%f[%w]lfm%f[%W]") then return true end
    if find(l, "%f[%w]lf%s*%d+%s*m%f[%W]") then return true end          -- lf1m, lf 2m
    for w in string.gmatch(l, "%f[%w]lf%s*%d*%s*(%a+)") do               -- "lf tank", "lf 2 dps"
        if ROLEWORD[w] then return true end
    end
    return false
end

-- Returns a table describing the message, or nil if it is not an LFM.
function GG:Parse(msg)
    if type(msg) ~= "string" or msg == "" then return end
    local clean = Clean(msg)
    local l = lower(clean)
    if not find(l, "lf", 1, true) then return end      -- cheap early-out
    if not IsLFM(l) then return end

    local n = GG.Normalize(l)
    local info = { clean = clean, l = n, roles = {} }

    -- Which instance is mentioned first?
    local bestPos, best
    for _, inst in ipairs(GG.Compiled) do
        for _, pat in ipairs(inst.pats) do
            local s = find(n, pat)
            if s and (not bestPos or s < bestPos) then
                bestPos, best = s, inst
            end
        end
    end
    if best then
        info.label, info.cat = best.label, best.cat
    else
        info.cat = "other"
    end

    -- Raid size
    if info.cat == "raid" then
        for num in string.gmatch(n, "%d+") do
            if num == "10" or num == "25" then info.size = num break end
        end
    end

    -- Heroic?
    if find(n, "%f[%w]hc%f[%W]") or find(n, "%f[%w]heroic%f[%W]") or find(n, "%f[%w]hm%f[%W]")
        or find(n, "%f[%w]%d+ h%f[%W]") or find(n, "%f[%w]h %d+") then
        info.heroic = true
    end

    -- Roles wanted
    if find(n, "%f[%w]tanks?%f[%W]") then info.roles.tank = true end
    if find(n, "%f[%w]heal%a*%f[%W]") or find(n, "%f[%w]hps%f[%W]") or find(n, "%f[%w]resto%f[%W]") then
        info.roles.heal = true
    end
    if find(n, "%f[%w]r?m?dps%f[%W]") or find(n, "%f[%w]dds?%f[%W]") then info.roles.dps = true end

    return info
end

---------------------------------------------------------------------------
-- Entry store
---------------------------------------------------------------------------
local function WatchMatch(e)
    local watch = GG.db and GG.db.watch
    if not watch then return end
    local label = lower(e.label or "")
    for _, kw in ipairs(watch) do
        if label == kw or find(e.l, kw, 1, true) then return kw end
    end
end

function GG:OnChat(event, msg, author, channelString, guid)
    if not self.db then return end
    local info = self:Parse(msg)
    if not info then return end

    local name = match(author or "", "^([^-]+)") or author
    if not name or name == "" or name == UnitName("player") then return end

    local key = lower(name)
    local old = self.entries[key]
    local e = old or { key = key, name = name }

    local class = e.class
    if guid and guid ~= "" and GetPlayerInfoByGUID then
        local _, c = GetPlayerInfoByGUID(guid)
        if c then class = c end
    end

    local channel
    if event == "CHAT_MSG_SAY" then
        channel = "Say"
    elseif event == "CHAT_MSG_YELL" then
        channel = "Yell"
    else
        channel = gsub(channelString or "", "^%d+%.%s*", "")
    end

    local isNew = (not old) or (old.label ~= info.label)

    e.class   = class
    e.time    = GetTime()
    e.clean   = info.clean
    e.l       = info.l
    e.label   = info.label
    e.cat     = info.cat
    e.size    = info.size
    e.heroic  = info.heroic
    e.roles   = info.roles
    e.channel = channel
    self.entries[key] = e

    if isNew then
        local kw = WatchMatch(e)
        if kw then
            Print(format("|Hplayer:%s|h[%s]|h is looking for: %s (watching \"%s\")",
                name, name, e.label or e.clean, kw))
            if self.db.sound then PlaySound("TellMessage") end
        end
    end
end

function GG:Prune()
    if not self.db then return end
    local now, expire = GetTime(), self.db.expire
    for key, e in pairs(self.entries) do
        if now - e.time > expire then self.entries[key] = nil end
    end
end

function GG:Clear()
    for key in pairs(self.entries) do self.entries[key] = nil end
    self:Refresh()
end

function GG:Toggle()
    self:CreateUI()
    if self.frame:IsShown() then self.frame:Hide() else self.frame:Show() end
end

-- Stub so Core can call it before UI.lua defines the real one.
function GG:Refresh() end

---------------------------------------------------------------------------
-- Optional: hide LFM spam from the chat frames
---------------------------------------------------------------------------
local function ChatFilter(self, event, msg, author)
    if GG.db and GG.db.hide then
        local name = match(author or "", "^([^-]+)") or author
        if name ~= UnitName("player") and GG:Parse(msg) then
            return true
        end
    end
    return false
end
ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", ChatFilter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_SAY", ChatFilter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_YELL", ChatFilter)

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("CHAT_MSG_CHANNEL")
frame:RegisterEvent("CHAT_MSG_SAY")
frame:RegisterEvent("CHAT_MSG_YELL")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        if ... == addonName then
            GroupGazetteDB = GroupGazetteDB or {}
            CopyDefaults(defaults, GroupGazetteDB)
            GG.db = GroupGazetteDB
        end
    elseif event == "PLAYER_LOGIN" then
        Print("loaded. Type |cffffff00/gazette|r to open the board.")
    else
        local msg, author, _, channelString, _, _, _, _, _, _, _, guid = ...
        GG:OnChat(event, msg, author, channelString, guid)
    end
end)

local acc = 0
frame:SetScript("OnUpdate", function(self, elapsed)
    acc = acc + elapsed
    if acc < 0.5 then return end
    acc = 0
    GG:Prune()
    if GG.frame and GG.frame:IsShown() then GG:Refresh() end
end)

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
local function OnOff(v) return v and "|cff33ff33on|r" or "|cffff4040off|r" end

local function Help()
    Print("commands:")
    print("  |cffffff00/gazette|r - open / close the board")
    print("  |cffffff00/gazette clear|r - empty the board")
    print("  |cffffff00/gazette expire <seconds>|r - how long listings stay (30-900)")
    print("  |cffffff00/gazette watch <keyword>|r - alert when a new LFM mentions it (toggle); |cffffff00/gazette watch|r lists")
    print("  |cffffff00/gazette sound|r - toggle the alert sound")
    print("  |cffffff00/gazette hide|r - toggle hiding LFM messages from chat")
    print("  |cffffff00/gazette skin|r - toggle the ElvUI skin (needs /reload)")
    print("  |cffffff00/gazette reset|r - reset window position")
end

SLASH_GROUPGAZETTE1 = "/gazette"
SLASH_GROUPGAZETTE2 = "/groupgazette"
SlashCmdList["GROUPGAZETTE"] = function(input)
    local db = GG.db
    if not db then return end
    local cmd, rest = match(input or "", "^(%S*)%s*(.-)%s*$")
    cmd = lower(cmd or "")

    if cmd == "" or cmd == "toggle" or cmd == "show" then
        GG:Toggle()
    elseif cmd == "clear" then
        GG:Clear()
        Print("board cleared.")
    elseif cmd == "expire" then
        local s = tonumber(rest)
        if s then
            db.expire = math.max(30, math.min(900, s))
            Print("listings now expire after " .. db.expire .. " seconds.")
        else
            Print("listings expire after " .. db.expire .. " seconds. Use /gazette expire <seconds>.")
        end
    elseif cmd == "watch" then
        rest = lower(rest or "")
        if rest == "" then
            if #db.watch == 0 then
                Print("no watch keywords. Example: |cffffff00/gazette watch icc|r")
            else
                Print("watching: " .. table.concat(db.watch, ", "))
            end
        elseif rest == "clear" then
            wipe(db.watch)
            Print("watch list cleared.")
        else
            for i, kw in ipairs(db.watch) do
                if kw == rest then
                    table.remove(db.watch, i)
                    Print("no longer watching \"" .. rest .. "\".")
                    return
                end
            end
            db.watch[#db.watch + 1] = rest
            Print("now watching \"" .. rest .. "\".")
        end
    elseif cmd == "sound" then
        db.sound = not db.sound
        Print("alert sound " .. OnOff(db.sound))
    elseif cmd == "hide" then
        db.hide = not db.hide
        Print("hiding LFM messages from chat: " .. OnOff(db.hide))
    elseif cmd == "skin" then
        db.skin = not db.skin
        Print("ElvUI skin " .. OnOff(db.skin) .. " - type |cffffff00/reload|r to apply.")
    elseif cmd == "reset" then
        db.pos = nil
        if GG.frame then
            GG.frame:ClearAllPoints()
            GG.frame:SetPoint("CENTER")
        end
        Print("window position reset.")
    else
        Help()
    end
end
