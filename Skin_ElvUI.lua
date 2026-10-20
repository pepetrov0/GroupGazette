local addonName, GG = ...

---------------------------------------------------------------------------
-- ElvUI skin
--
-- Called from GG:CreateUI() right after the board is built. Because the
-- board is created lazily (first /gazette), ElvUI and its Skins module are
-- guaranteed to be fully initialised by then.
--
-- Everything is wrapped in pcall so a different ElvUI version can never
-- break the addon: worst case you get the default Blizzard look.
-- Disable with /gazette skin (then /reload).
---------------------------------------------------------------------------

local function try(fn, ...)
    if type(fn) == "function" then
        local ok, err = pcall(fn, ...)
        if not ok then GG.skinError = err end
    end
end

local function DoSkin()
    local E = unpack(ElvUI)
    local S = E:GetModule("Skins", true)
    if not S then error("ElvUI Skins module not found") end

    local f = GG.frame

    -- Accent colour = ElvUI's value colour (used for selected filter buttons)
    local c = E.media and E.media.rgbvaluecolor
    if c then
        GG.accent = { c[1], c[2], c[3] }
    else
        GG.accent = { 0.2, 0.6, 1 }
    end

    -- Main window --------------------------------------------------------
    f:SetBackdrop(nil)
    if f.header then f.header:Hide() end
    try(f.SetTemplate, f, "Transparent")
    f.title:ClearAllPoints()
    f.title:SetPoint("TOP", f, "TOP", 0, -10)

    try(S.HandleCloseButton, S, f.close)
    f.close:ClearAllPoints()
    f.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)

    -- Buttons ------------------------------------------------------------
    for _, btn in pairs(f.catButtons) do try(S.HandleButton, S, btn) end
    for _, btn in pairs(f.roleButtons) do try(S.HandleButton, S, btn) end
    try(S.HandleButton, S, f.clear)

    -- Search box ---------------------------------------------------------
    try(S.HandleEditBox, S, f.search)
    f.search:SetHeight(22)

    -- List area + scrollbar ----------------------------------------------
    f.list:SetBackdrop(nil)
    try(f.list.SetTemplate, f.list, "Transparent")
    try(S.HandleScrollBar, S, _G["GroupGazetteScrollScrollBar"])

    -- Rows: accent-coloured hover highlight --------------------------------
    local r, g, b = GG.accent[1], GG.accent[2], GG.accent[3]
    for _, row in ipairs(GG.rows) do
        row.hl:SetVertexColor(r, g, b, 0.25)
    end

    -- Fonts: use ElvUI's chosen font everywhere --------------------------
    for _, fs in ipairs(GG.fontStrings) do
        if fs.FontTemplate then
            if fs == f.title then
                fs:FontTemplate(nil, 14, "OUTLINE")
            else
                fs:FontTemplate(nil, 11)
            end
        end
    end
    for _, btn in pairs(f.catButtons) do
        local fs = btn:GetFontString()
        if fs and fs.FontTemplate then fs:FontTemplate(nil, 11) end
    end
    for _, btn in pairs(f.roleButtons) do
        local fs = btn:GetFontString()
        if fs and fs.FontTemplate then fs:FontTemplate(nil, 11) end
    end
    do
        local fs = f.clear:GetFontString()
        if fs and fs.FontTemplate then fs:FontTemplate(nil, 11) end
    end
    if f.search.FontTemplate then f.search:FontTemplate(nil, 11) end
end

function GG:ApplyElvUISkin()
    if self.skinned or not self.frame then return end
    if not (self.db and self.db.skin) then return end
    if type(ElvUI) ~= "table" then return end

    local ok, err = pcall(DoSkin)
    if ok then
        self.skinned = true
        self:UpdateToggles()
        if self.skinError then
            self.Print("ElvUI skin applied with minor issues: " .. tostring(self.skinError))
        end
    else
        self.Print("ElvUI skin failed, using default look: " .. tostring(err))
    end
end
