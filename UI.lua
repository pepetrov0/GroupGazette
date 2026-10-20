local addonName, GG = ...

local lower, find, format = string.lower, string.find, string.format

local ROW_H, NUM_ROWS = 20, 22
local FRAME_W, FRAME_H = 860, 564
local LIST_W = FRAME_W - 32
local ROW_W = LIST_W - 32

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function FormatAge(s)
    s = math.floor(s)
    if s < 60 then return s .. "s" end
    return math.floor(s / 60) .. "m"
end

local function NewButton(parent, text, w, h)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetWidth(w)
    b:SetHeight(h)
    b:SetText(text)
    return b
end

local function NewRowFS(parent, w, template)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("MIDDLE")
    fs:SetHeight(ROW_H)
    fs:SetWidth(w)
    if fs.SetWordWrap then fs:SetWordWrap(false) end
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
    GameTooltip:AddLine("Click: whisper", 0.5, 1, 0.5)
    GameTooltip:Show()
end

---------------------------------------------------------------------------
-- View building / row updating
---------------------------------------------------------------------------
local function SortByMessage(a, b)
    if a.sortKey ~= b.sortKey then return a.sortKey < b.sortKey end
    return a.key < b.key
end

function GG:BuildView()
    local search = self.state.search
    local view, total = {}, 0

    for _, e in pairs(self.entries) do
        total = total + 1
        if search == "" or find(e.sortKey .. " " .. lower(e.name), search, 1, true) then
            view[#view + 1] = e
        end
    end

    -- Alphabetical by message text (ties broken by name) so rows keep
    -- their place instead of reshuffling every time someone reposts.
    table.sort(view, SortByMessage)
    self.view = view
    self.total = total
end

function GG:UpdateRows()
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

-- True while the mouse is resting on one of our rows.
local function MouseOverRow()
    local focus = GetMouseFocus()
    return focus and focus.ggRow and focus:IsShown()
end

-- Rebuilds the panel. While the user hovers an entry the panel is frozen
-- (no new rows, no reordering, no expiry, no timer changes) so the message
-- can be read in peace. Pass force = true for user-driven changes such as
-- dismissing an entry or typing in the search box.
function GG:Refresh(force)
    local f = self.frame
    if not f or not f:IsShown() then return end

    if self.frozen and not force then
        if MouseOverRow() then return end
        self.frozen = false     -- safety net: the row we were hovering is gone
    end

    self:BuildView()
    self:UpdateRows()
    f.count:SetText(format("%d / %d groups", #self.view, self.total))
    f.footer:SetText(format("Listings expire after %ds", self.db and self.db.expire or 60))
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
    f:SetScript("OnShow", function() GG.frozen = false GG:Refresh(true) end)
    f:SetScript("OnHide", function() GG.frozen = false end)
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

    f.close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)

    ---------------------------------------------------------------- search row
    f.searchLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.searchLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -44)
    f.searchLabel:SetText("Search:")

    local sb = CreateFrame("EditBox", "GroupGazetteSearch", f, "InputBoxTemplate")
    sb:SetWidth(220)
    sb:SetHeight(20)
    sb:SetPoint("LEFT", f.searchLabel, "RIGHT", 10, 0)
    sb:SetAutoFocus(false)
    sb:SetMaxLetters(40)
    sb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    sb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    sb:SetScript("OnTextChanged", function(self)
        GG.state.search = lower(self:GetText() or "")
        GG:Refresh(true)
    end)
    f.search = sb

    f.clear = NewButton(f, "Clear board", 100, 22)
    f.clear:SetPoint("TOPRIGHT", f, "TOPRIGHT", -18, -40)
    f.clear:SetScript("OnClick", function() GG:Clear() end)

    f.count = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.count:SetPoint("RIGHT", f.clear, "LEFT", -12, 0)

    ---------------------------------------------------------------- list
    local list = CreateFrame("Frame", nil, f)
    list:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -72)
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

    -- Columns: time since posted | poster | message
    local AGE_X, AGE_W   = 4, 40
    local NAME_X, NAME_W = 48, 112
    local MSG_X          = 164
    local MSG_W          = ROW_W - MSG_X - 4

    self.rows = {}
    for i = 1, NUM_ROWS do
        local row = CreateFrame("Button", nil, list)
        row:SetWidth(ROW_W)
        row:SetHeight(ROW_H)
        row:SetPoint("TOPLEFT", list, "TOPLEFT", 4, -4 - (i - 1) * ROW_H)
        row.ggRow = true
        row:RegisterForClicks("LeftButtonUp")
        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel", OnWheel)

        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
        row.bg:SetVertexColor(1, 1, 1, 0)

        row:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
        row.hl = row:GetHighlightTexture()
        row.hl:SetVertexColor(1, 0.82, 0, 0.18)

        row.age = NewRowFS(row, AGE_W)
        row.age:SetPoint("LEFT", row, "LEFT", AGE_X, 0)
        row.age:SetTextColor(0.6, 0.6, 0.6)

        row.name = NewRowFS(row, NAME_W, "GameFontNormal")
        row.name:SetPoint("LEFT", row, "LEFT", NAME_X, 0)

        row.msg = NewRowFS(row, MSG_W)
        row.msg:SetPoint("LEFT", row, "LEFT", MSG_X, 0)

        row:SetScript("OnClick", function(self)
            local e = self.entry
            if e then ChatFrame_SendTell(e.name) end
        end)
        row:SetScript("OnEnter", function(self)
            GG.frozen = true
            f.footer:SetText("|cffffd100Paused|r while hovering - updates resume when you move away")
            ShowTooltip(self)
        end)
        row:SetScript("OnLeave", function()
            -- Don't refresh here: moving from one row straight onto the next
            -- would shift rows under the cursor. The 0.5s ticker catches up.
            GG.frozen = false
            GameTooltip:Hide()
        end)

        row:Hide()
        self.rows[i] = row
    end

    ---------------------------------------------------------------- footer
    f.footer = f:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    f.footer:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 22, 18)

    f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    f.hint:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -22, 18)
    f.hint:SetText("Click an entry to whisper")

    if self.ApplyElvUISkin then self:ApplyElvUISkin() end
end
