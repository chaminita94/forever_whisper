local _, NS = ...

-- Native, pooled message rows. One scrollbar owns incoming and outgoing messages.
function NS.CreateTranscript(parent, getStyle)
    local view = CreateFrame("ScrollFrame", nil, parent)
    local content = CreateFrame("Frame", nil, view)
    content:SetPoint("TOPLEFT")
    content:SetSize(1, 1)
    view:SetScrollChild(content)
    view.lines, view.rows, view.directions = {}, {}, {}
    view.offset, view.totalHeight = 0, 0
    local measure = content:CreateFontString(nil, "OVERLAY")
    measure:Hide()

    function view:SetFont(path, size)
        self.font, self.fontSize = path, size
    end
    function view:SetHyperlinksEnabled(value) self.hyperlinks = value end
    local function forward(script, ...)
        local fn
        if script == "OnHyperlinkClick" then fn = view.onHyperlinkClick
        else fn = view:GetScript(script) end
        if fn then fn(view, ...) end
    end
    local function layoutRow(index)
        local row = view.rows[index]
        local text, outgoing = view.lines[index], view.directions[index]
        local path, size, t, opacity = getStyle()
        local available = math.max(100, view:GetWidth() - 8)
        local maxWidth = math.max(100, available * 0.80)
        measure:SetFont(path, size, "")
        measure:SetWordWrap(false)
        measure:SetWidth(0)
        measure:SetText(text)
        local width = math.min(maxWidth, math.max(110, measure:GetStringWidth() + 24))
        measure:SetWidth(width - 24)
        measure:SetWordWrap(true)
        local height = math.max(size + 20, measure:GetStringHeight() + 22)
        row:ClearAllPoints()
        row:SetPoint(outgoing and "TOPRIGHT" or "TOPLEFT", content,
            outgoing and "TOPRIGHT" or "TOPLEFT", outgoing and -4 or 4, -view.totalHeight)
        row:SetSize(width, height)
        row.outgoing = outgoing
        row.reply:ClearAllPoints()
        row.reply:SetPoint(outgoing and "RIGHT" or "LEFT", row, outgoing and "LEFT" or "RIGHT", outgoing and -4 or 4, 0)
        row.bg:SetColorTexture(outgoing and t[5] * 0.20 or t[2] * 1.45,
            outgoing and t[6] * 0.20 or t[3] * 1.45,
            outgoing and t[7] * 0.20 or t[4] * 1.45, math.max(0.80, opacity))
        row.rail:SetColorTexture(outgoing and 0.54 or 1, outgoing and 0.81 or 0.81,
            outgoing and 1 or 0.51, 0.85)
        row.rail:ClearAllPoints()
        row.rail:SetPoint(outgoing and "TOPRIGHT" or "TOPLEFT")
        row.rail:SetPoint(outgoing and "BOTTOMRIGHT" or "BOTTOMLEFT")
        row.body:SetFont(path, size, "")
        row.body:SetJustifyH(outgoing and "RIGHT" or "LEFT")
        row.body:Clear()
        row.body:AddMessage(text)
        row.body:ScrollToBottom()
        view.totalHeight = view.totalHeight + height + 8
        row.bottom = view.totalHeight
        row:Show()
    end
    function view:Clear()
        for _, row in ipairs(self.rows) do row:Hide() end
        self.lines, self.directions = {}, {}
        self.totalHeight, self.offset = 0, 0
    end
    function view:AddMessage(text, outgoing)
        local index = #self.lines + 1
        self.lines[index], self.directions[index] = text, not not outgoing
        if not self.rows[index] then
            local row = CreateFrame("Frame", nil, content)
            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()
            row.rail = row:CreateTexture(nil, "BORDER")
            row.rail:SetWidth(2)
            row.reply = CreateFrame("Button", nil, row)
            row.reply:SetSize(24, 24)
            row.reply.index = index
            local arrow = row.reply:CreateFontString(nil, "OVERLAY")
            arrow:SetFont("Fonts\\ARIALN.TTF", 18, "")
            arrow:SetPoint("CENTER")
            arrow:SetText("<")
            arrow:SetTextColor(0.48, 0.73, 0.79)
            row.reply:SetScript("OnClick", function()
                if view.onReply then view.onReply(view, row.reply.index) end
            end)
            row.reply:SetScript("OnEnter", function(self)
                arrow:SetTextColor(0.85, 1, 1)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:AddLine("Reply to this message")
                GameTooltip:Show()
            end)
            row.reply:SetScript("OnLeave", function() arrow:SetTextColor(0.48, 0.73, 0.79); GameTooltip:Hide() end)
            row.body = CreateFrame("ScrollingMessageFrame", nil, row)
            row.body:SetPoint("TOPLEFT", 12, -10)
            row.body:SetPoint("BOTTOMRIGHT", -12, 10)
            row.body:SetFading(false)
            row.body:SetSpacing(0)
            row.body:SetMaxLines(64)
            row.body:EnableMouse(true)
            row.body:EnableMouseWheel(true)
            if row.body.SetHyperlinksEnabled then row.body:SetHyperlinksEnabled(true) end
            row.body:SetScript("OnHyperlinkClick", function(_, ...) forward("OnHyperlinkClick", ...) end)
            row.body:SetScript("OnMouseDown", function(_, ...) forward("OnMouseDown", ...) end)
            row.body:SetScript("OnMouseWheel", function(_, ...) forward("OnMouseWheel", ...) end)
            self.rows[index] = row
        end
        layoutRow(index)
        content:SetSize(math.max(1, self:GetWidth()), math.max(1, self.totalHeight))
    end
    function view:GetScrollOffset() return self.offset end
    function view:SetScrollOffset(offset)
        self.offset = math.max(0, math.min(#self.lines - 1, math.floor(offset)))
        local last = self.rows[#self.lines - self.offset]
        local bottom = last and last.bottom or 0
        self:SetVerticalScroll(math.max(0, math.min(bottom - self:GetHeight(), self.totalHeight - self:GetHeight())))
    end
    function view:ScrollToBottom() self:SetScrollOffset(0) end
    function view:ScrollUp() self:SetScrollOffset(self.offset + 1) end
    function view:ScrollDown() self:SetScrollOffset(self.offset - 1) end
    function view:Restyle()
        self.totalHeight = 0
        for index = 1, #self.lines do layoutRow(index) end
        content:SetSize(math.max(1, self:GetWidth()), math.max(1, self.totalHeight))
        self:SetScrollOffset(self.offset)
    end
    view:SetScript("OnSizeChanged", function() view:Restyle() end)
    view:SetScript("OnShow", function() view:Restyle() end)
    return view
end

function NS.CreateCombatPreview(getStyle)
    local toast = CreateFrame("Frame", "ForeverWhisperCombatPreview", UIParent)
    toast:SetSize(320, 92)
    toast:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -30, -160)
    toast:SetFrameStrata("DIALOG")
    toast:SetClampedToScreen(true)
    toast:EnableMouse(true)
    toast.bg = toast:CreateTexture(nil, "BACKGROUND")
    toast.bg:SetAllPoints()
    local icon = toast:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\AddOns\\ForeverWhisper\\UI\\WhisperMark.tga")
    icon:SetPoint("TOPLEFT", 10, -10)
    icon:SetSize(26, 26)
    toast.title = toast:CreateFontString(nil, "OVERLAY")
    toast.title:SetPoint("TOPLEFT", 44, -10)
    toast.title:SetPoint("TOPRIGHT", -30, -10)
    toast.title:SetJustifyH("LEFT")
    toast.title:SetWordWrap(false)
    toast.preview = toast:CreateFontString(nil, "OVERLAY")
    toast.preview:SetPoint("TOPLEFT", 12, -35)
    toast.preview:SetPoint("TOPRIGHT", -12, -35)
    toast.preview:SetHeight(30)
    toast.preview:SetJustifyH("LEFT")
    toast.preview:SetWordWrap(true)
    toast.note = toast:CreateFontString(nil, "OVERLAY")
    toast.note:SetPoint("BOTTOMLEFT", 12, 9)
    toast.note:SetFont("Fonts\\ARIALN.TTF", 10, "")
    toast.note:SetText("Saved — opens after combat")
    toast.note:SetTextColor(0.63, 0.73, 0.81)
    local close = CreateFrame("Button", nil, toast)
    close:SetPoint("TOPRIGHT", -6, -5)
    close:SetSize(24, 24)
    local x = close:CreateFontString(nil, "OVERLAY")
    x:SetFont("Fonts\\ARIALN.TTF", 13, "")
    x:SetPoint("CENTER")
    x:SetText("×")
    close:SetScript("OnClick", function() toast:Hide() end)
    toast:SetScript("OnMouseDown", function(_, button) if button == "RightButton" then toast:Hide() end end)
    toast.count, toast.serial = 0, 0
    function toast:ShowWhisper(author, text)
        self.count, self.serial = self.count + 1, self.serial + 1
        local path, size, t = getStyle()
        self.bg:SetColorTexture(t[2], t[3], t[4], 0.97)
        self.title:SetFont(path, math.min(size, 15), "")
        self.title:SetTextColor(1, 0.81, 0.51)
        self.title:SetText(author .. (self.count > 1 and ("  ·  " .. self.count .. " new") or ""))
        self.preview:SetFont(path, math.min(size, 13), "")
        self.preview:SetTextColor(0.84, 0.89, 0.94)
        self.preview:SetText(text)
        self:Show()
        local serial = self.serial
        if self.timer then self.timer:Cancel(); self.timer = nil end
        local function expire() if toast.serial == serial then toast:Hide() end end
        if C_Timer and C_Timer.NewTimer then
            self.timer = C_Timer.NewTimer(7, expire)
        elseif C_Timer and C_Timer.After then
            C_Timer.After(7, expire)
        end
    end
    function toast:Reset()
        if self.timer then self.timer:Cancel(); self.timer = nil end
        self.serial, self.count = self.serial + 1, 0
        self:Hide()
    end
    toast:Hide()
    return toast
end
