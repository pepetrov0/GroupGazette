local addonName, GG = ...

local lower, find, format = string.lower, string.find, string.format

local ROW_H, NUM_ROWS = 20, 15
local FRAME_W, FRAME_H = 640, 440
local LIST_W = FRAME_W - 32
local ROW_W = LIST_W - 32

local CATEGORIES = {
    { "all", "All" }, { "dungeon", "Dungeons" }, { "raid", "Raids" }, { "other", "Other" },
}
local ROLES = {
    { "tank", "T", "Tank" },
    { "heal", "H", "Healer" },
    { "dps",  "D", "DPS" },
}
local ROLE_HEX = { tank = "|cff4099ff", heal = "|cff4dff4d", dps = "|cffff4d4d" }
local CAT_COLOR = {
    raid    = { 1.0, 0.55, 0.25 },
    dungeon = { 0.45, 0.8, 1.0 },
    other   = { 0.65, 0.65, 0.65 },
}

GG.fontStrings = {}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function FormatAge(s)
    s = math.floor(s)
    if s < 60 then return s .. "s" end
    return math.floor(s / 60) .. "m"
end

local function TagText(e)
    local t = e.label or "-"
    if e.size then t = t .. " " .. e.size end
    if e.heroic then t = t .. " HC" end
    return t
end

local function RolesText(e)
    local parts = {}
    for _, r in ipairs(ROLES) do
        if e.roles and e.roles[r[1]] then
            parts[#parts + 1] = ROLE_HEX[r[1]] .. r[2] .. "|r"
        end
    end
    if #parts == 0 then return "|cff777777-|r" end
    return table.concat(parts, " ")
end

local function SetToggle(btn, on)
    local fs = btn:GetFontString()
    if not fs then return end
    if on then
        if GG.accent then
            fs:SetTextColor(GG.accent[1], GG.accent[2], GG.accent[3])
        else
            fs:SetTextColor(0.3, 1, 0.3)
        end
    elseif GG.skinned then
        fs:SetTextColor(1, 1, 1)
    else
        fs:SetTextColor(1, 0.82, 0)
    end
end

local function NewButton(parent, text, w, h)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetWidth(w)
    b:SetHeight(h)
    b:SetText(text)
    return b
end

local function NewRowFS(parent, w, template)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("MIDDLE")
    fs:SetHeight(ROW_H)
    fs:SetWidth(w)
    if fs.SetWordWrap then fs:SetWordWrap(false) end
    GG.fontStrings[#GG.fontStrings + 1] = fs
    return fs
end

---------------------------------------------------------------------------
-- Tooltip
---------------------------------------------------------------------------
local function ShowTooltip(row)
    local e = row.entry
    if not e then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    local c = e.class and RAID_CLASS_COLORS[e.class]
    if c then
        GameTooltip:AddLine(e.name, c.r, c.g, c.b)
    else
        GameTooltip:AddLine(e.name, 1, 0.82, 0)
    end
    GameTooltip:AddLine(e.clean, 1, 1, 1, true)
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Channel", e.channel or "?", 0.6, 0.6, 0.6, 1, 1, 1)
    GameTooltip:AddDoubleLine("Posted", FormatAge(GetTime() - e.time) .. " ago", 0.6, 0.6, 0.6, 1, 1, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Left-click: whisper", 0.5, 1, 0.5)
    GameTooltip:AddLine("Shift-click: /who", 0.5, 1, 0.5)
    GameTooltip:AddLine("Right-click: dismiss", 0.5, 1, 0.5)
    GameTooltip:Show()
end

---------------------------------------------------------------------------
-- View building / row updating
---------------------------------------------------------------------------
function GG:BuildView()
    local st = self.state
    local view, total = {}, 0
    local anyRole = next(st.roles) ~= nil
    local search = st.search

    for _, e in pairs(self.entries) do
        total = total + 1
        local ok = true

        if st.cat ~= "all" and e.cat ~= st.cat then ok = false end

        if ok and anyRole then
            local hasInfo = e.roles and (e.roles.tank or e.roles.heal or e.roles.dps)
            if hasInfo then
                local match = false
                for role in pairs(st.roles) do
                    if e.roles[role] then match = true break end
                end
                ok = match
            end
        end

        if ok and search ~= "" then
            local hay = lower(e.name) .. " " .. (e.l or "") .. " " .. lower(e.label or "")
            if not find(hay, search, 1, true) then ok = false end
        end

        if ok then view[#view + 1] = e end
    end

    table.sort(view, function(a, b) return a.time > b.time end)
    self.view = view
    self.total = total
end

function GG:UpdateRows()
    local f = self.frame
    local view = self.view or {}
    FauxScrollFrame_Update(self.scroll, #view, NUM_ROWS, ROW_H)
    local offset = FauxScrollFrame_GetOffset(self.scroll)
    local now = GetTime()

    for i = 1, NUM_ROWS do
        local row = self.rows[i]
        local e = view[i + offset]
        if e then
            row.entry = e
            row.age:SetText(FormatAge(now - e.time))

            local c = e.class and RAID_CLASS_COLORS[e.class]
            if c then row.name:SetTextColor(c.r, c.g, c.b) else row.name:SetTextColor(1, 0.82, 0) end
            row.name:SetText(e.name)

            local cc = CAT_COLOR[e.cat] or CAT_COLOR.other
            row.tag:SetTextColor(cc[1], cc[2], cc[3])
            row.tag:SetText(TagText(e))

            row.roles:SetText(RolesText(e))
            row.msg:SetText(e.clean)

            row.bg:SetVertexColor(1, 1, 1, ((i + offset) % 2 == 0) and 0.06 or 0)
            row:Show()
            if GameTooltip:IsOwned(row) then ShowTooltip(row) end
        else
            row.entry = nil
            row:Hide()
        end
    end
end

function GG:Refresh()
    local f = self.frame
    if not f or not f:IsShown() then return end
    self:BuildView()
    self:UpdateRows()
    f.count:SetText(format("%d / %d groups", #self.view, self.total))
    f.footer:SetText(format("Entries expire after %ds. Use /gazette for options.", self.db and self.db.expire or 180))
end

function GG:UpdateToggles()
    local f = self.frame
    if not f then return end
    for key, btn in pairs(f.catButtons) do SetToggle(btn, self.state.cat == key) end
    for key, btn in pairs(f.roleButtons) do SetToggle(btn, self.state.roles[key]) end
end

---------------------------------------------------------------------------
-- Frame construction (built lazily the first time the board is opened,
-- which also guarantees ElvUI is fully initialised before we skin it)
---------------------------------------------------------------------------
function GG:CreateUI()
    if self.frame then return end

    local f = CreateFrame("Frame", "GroupGazetteFrame", UIParent)
    f:SetWidth(FRAME_W)
    f:SetHeight(FRAME_H)
    f:SetFrameStrata("MEDIUM")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:Hide()
    self.frame = f

    local pos = self.db and self.db.pos
    if pos then
        f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    else
        f:SetPoint("CENTER")
    end

    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        if GG.db then GG.db.pos = { p, rp, x, y } end
    end)
    f:SetScript("OnShow", function() GG:UpdateToggles() GG:Refresh() end)
    table.insert(UISpecialFrames, "GroupGazetteFrame")

    -- Default (non-ElvUI) look
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })

    f.header = f:CreateTexture(nil, "ARTWORK")
    f.header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    f.header:SetWidth(300)
    f.header:SetHeight(64)
    f.header:SetPoint("TOP", f, "TOP", 0, 12)

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOP", f.header, "TOP", 0, -14)
    f.title:SetText("Group Gazette")
    GG.fontStrings[#GG.fontStrings + 1] = f.title

    f.close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)

    ---------------------------------------------------------------- filters
    f.catButtons, f.roleButtons = {}, {}
    local x = 18
    for _, c in ipairs(CATEGORIES) do
        local key, label = c[1], c[2]
        local b = NewButton(f, label, 74, 22)
        b:SetPoint("TOPLEFT", f, "TOPLEFT", x, -40)
        b:SetScript("OnClick", function()
            GG.state.cat = key
            GG:UpdateToggles()
            GG:Refresh()
        end)
        f.catButtons[key] = b
        x = x + 78
    end

    local rx = -18
    for i = #ROLES, 1, -1 do
        local key, letter, name = ROLES[i][1], ROLES[i][2], ROLES[i][3]
        local b = NewButton(f, letter, 28, 22)
        b:SetPoint("TOPRIGHT", f, "TOPRIGHT", rx, -40)
        b:SetScript("OnClick", function()
            GG.state.roles[key] = (not GG.state.roles[key]) or nil
            GG:UpdateToggles()
            GG:Refresh()
        end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Only show groups that need a " .. name)
            GameTooltip:AddLine("(groups that don't list roles are always shown)", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        f.roleButtons[key] = b
        rx = rx - 32
    end
    f.roleLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.roleLabel:SetPoint("RIGHT", f.roleButtons.tank, "LEFT", -6, 0)
    f.roleLabel:SetText("Needs:")
    GG.fontStrings[#GG.fontStrings + 1] = f.roleLabel

    ---------------------------------------------------------------- search row
    f.searchLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.searchLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -72)
    f.searchLabel:SetText("Search:")
    GG.fontStrings[#GG.fontStrings + 1] = f.searchLabel

    local sb = CreateFrame("EditBox", "GroupGazetteSearch", f, "InputBoxTemplate")
    sb:SetWidth(200)
    sb:SetHeight(20)
    sb:SetPoint("LEFT", f.searchLabel, "RIGHT", 10, 0)
    sb:SetAutoFocus(false)
    sb:SetMaxLetters(40)
    sb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    sb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    sb:SetScript("OnTextChanged", function(self)
        GG.state.search = lower(self:GetText() or "")
        GG:Refresh()
    end)
    f.search = sb

    f.clear = NewButton(f, "Clear board", 90, 22)
    f.clear:SetPoint("TOPRIGHT", f, "TOPRIGHT", -18, -68)
    f.clear:SetScript("OnClick", function() GG:Clear() end)

    f.count = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.count:SetPoint("RIGHT", f.clear, "LEFT", -12, 0)
    GG.fontStrings[#GG.fontStrings + 1] = f.count

    ---------------------------------------------------------------- list
    local list = CreateFrame("Frame", nil, f)
    list:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -96)
    list:SetWidth(LIST_W)
    list:SetHeight(NUM_ROWS * ROW_H + 8)
    list:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    list:SetBackdropColor(0, 0, 0, 0.55)
    list:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    list:EnableMouseWheel(true)
    f.list = list

    local sf = CreateFrame("ScrollFrame", "GroupGazetteScroll", list, "FauxScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", list, "TOPLEFT", 2, -4)
    sf:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", -24, 4)
    sf:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ROW_H, function() GG:UpdateRows() end)
    end)
    self.scroll = sf

    local function OnWheel(_, delta)
        local bar = _G["GroupGazetteScrollScrollBar"]
        if bar then bar:SetValue(bar:GetValue() - delta * ROW_H * 3) end
    end
    list:SetScript("OnMouseWheel", OnWheel)

    self.rows = {}
    local msgW = ROW_W - 284
    for i = 1, NUM_ROWS do
        local row = CreateFrame("Button", nil, list)
        row:SetWidth(ROW_W)
        row:SetHeight(ROW_H)
        row:SetPoint("TOPLEFT", list, "TOPLEFT", 4, -4 - (i - 1) * ROW_H)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel", OnWheel)

        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
        row.bg:SetVertexColor(1, 1, 1, 0)

        row:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
        row.hl = row:GetHighlightTexture()
        row.hl:SetVertexColor(1, 0.82, 0, 0.18)

        row.age = NewRowFS(row, 32)
        row.age:SetPoint("LEFT", row, "LEFT", 4, 0)
        row.age:SetTextColor(0.6, 0.6, 0.6)

        row.name = NewRowFS(row, 96, "GameFontNormalSmall")
        row.name:SetPoint("LEFT", row, "LEFT", 40, 0)

        row.tag = NewRowFS(row, 92)
        row.tag:SetPoint("LEFT", row, "LEFT", 140, 0)

        row.roles = NewRowFS(row, 40)
        row.roles:SetPoint("LEFT", row, "LEFT", 236, 0)

        row.msg = NewRowFS(row, msgW)
        row.msg:SetPoint("LEFT", row, "LEFT", 280, 0)

        row:SetScript("OnClick", function(self, button)
            local e = self.entry
            if not e then return end
            if button == "RightButton" then
                GG.entries[e.key] = nil
                GG:Refresh()
            elseif IsShiftKeyDown() then
                SendWho('n-"' .. e.name .. '"')
            else
                ChatFrame_SendTell(e.name)
            end
        end)
        row:SetScript("OnEnter", ShowTooltip)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)

        row:Hide()
        self.rows[i] = row
    end

    ---------------------------------------------------------------- footer
    f.footer = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.footer:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 22, 18)
    GG.fontStrings[#GG.fontStrings + 1] = f.footer

    f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.hint:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -22, 18)
    f.hint:SetText("Click: whisper  |  Shift: /who  |  Right-click: dismiss")
    GG.fontStrings[#GG.fontStrings + 1] = f.hint

    if self.ApplyElvUISkin then self:ApplyElvUISkin() end
    self:UpdateToggles()
end
