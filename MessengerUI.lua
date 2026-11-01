local _, NS = ...

-- Move from cursor deltas in frame coordinates; never let StartMoving re-anchor the frame.
function NS.AttachCursorDrag(frame, stopped, allowed, started)
    function frame:EndCursorDrag()
        if not self.cursorDragging then return end
        self.cursorDragging = nil
        self:SetScript("OnUpdate", nil)
        if stopped then stopped(self) end
    end
    function frame:BeginCursorDrag()
        if self.cursorDragging or (allowed and not allowed()) then return end
        local left, top = self:GetLeft(), self:GetTop()
        if not left or not top then return end
        local x, y = GetCursorPosition()
        local scale = self:GetEffectiveScale()
        local ratio = UIParent:GetEffectiveScale() / scale
        self.cursorDragging = { x=x, y=y, lastX=x, lastY=y, left=left, top=top, scale=scale,
            screenWidth=UIParent:GetWidth()*ratio, screenHeight=UIParent:GetHeight()*ratio }
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        if started then started(self) end
        self:SetScript("OnUpdate", function(owner)
            if (allowed and not allowed()) or (IsMouseButtonDown and not IsMouseButtonDown("LeftButton")) then
                owner:EndCursorDrag()
                return
            end
            local state = owner.cursorDragging
            local cx, cy = GetCursorPosition()
            if state.lastX == cx and state.lastY == cy then return end
            state.lastX, state.lastY = cx, cy
            local nextLeft = math.max(0, math.min(state.screenWidth-owner:GetWidth(), state.left+(cx-state.x)/state.scale))
            local nextTop = math.max(owner:GetHeight(), math.min(state.screenHeight, state.top+(cy-state.y)/state.scale))
            owner:ClearAllPoints()
            owner:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", nextLeft, nextTop)
        end)
    end
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:BeginCursorDrag() end)
    frame:SetScript("OnDragStop", function(self) self:EndCursorDrag() end)
end

-- Native, pooled message rows. One scrollbar owns incoming and outgoing messages.
function NS.CreateTranscript(parent, getStyle)
    local view = CreateFrame("ScrollFrame", nil, parent)
    local content = CreateFrame("Frame", nil, view)
    content:SetPoint("TOPLEFT")
    content:SetSize(1, 1)
    view:SetScrollChild(content)
    view.lines, view.rows, view.directions, view.dividers = {}, {}, {}, {}
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
        local replyWidth = NS.language == "es" and 70 or 48
        local maxWidth = math.max(100, math.min(available * 0.80, available - replyWidth - 12))
        row.reply:SetWidth(replyWidth)
        measure:SetFont(path, size, "")
        measure:SetWordWrap(false)
        measure:SetWidth(0)
        measure:SetText(text)
        local width = math.min(maxWidth, math.max(110, measure:GetStringWidth() + 24))
        measure:SetWidth(width - 24)
        measure:SetWordWrap(true)
        local height = math.max(size + 20, measure:GetStringHeight() + 22)
        row.top = view.totalHeight
        row.divider:SetShown(view.dividers[index])
        row.divider:ClearAllPoints()
        row.divider:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -view.totalHeight)
        row.divider:SetSize(available, 24)
        row.divider.label:SetTextColor(t[5], t[6], t[7])
        row.divider.left:SetColorTexture(t[5], t[6], t[7], 0.45)
        row.divider.right:SetColorTexture(t[5], t[6], t[7], 0.45)
        if view.dividers[index] then view.totalHeight = view.totalHeight + 24 end
        row:ClearAllPoints()
        row:SetPoint(outgoing and "TOPRIGHT" or "TOPLEFT", content,
            outgoing and "TOPRIGHT" or "TOPLEFT", outgoing and -4 or 4, -view.totalHeight)
        row:SetSize(width, height)
        row.outgoing = outgoing
        row.reply:ClearAllPoints()
        row.reply:SetPoint(outgoing and "TOPRIGHT" or "TOPLEFT", row, outgoing and "TOPLEFT" or "TOPRIGHT", outgoing and -6 or 6, -8)
        row.reply.bg:SetColorTexture(t[2], t[3], t[4], 0.94)
        row.bg:SetColorTexture(outgoing and t[5] * 0.20 or t[2] * 1.45,
            outgoing and t[6] * 0.20 or t[3] * 1.45,
            outgoing and t[7] * 0.20 or t[4] * 1.45, math.max(0.80, opacity))
        row.rail:SetColorTexture(outgoing and 0.54 or 1, outgoing and 0.81 or 0.81,
            outgoing and 1 or 0.51, 0.85)
        row.rail:SetShown(t[1] ~= "Minimal")
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
        self.lines, self.directions, self.dividers = {}, {}, {}
        self.totalHeight, self.offset = 0, 0
    end
    function view:AddMessage(text, outgoing, divider)
        local index = #self.lines + 1
        self.lines[index], self.directions[index] = text, not not outgoing
        self.dividers[index] = not not divider
        if not self.rows[index] then
            local row = CreateFrame("Frame", nil, content)
            row.divider = CreateFrame("Frame", nil, row)
            row.divider.label = row.divider:CreateFontString(nil, "OVERLAY")
            row.divider.label:SetFont("Fonts\\ARIALN.TTF", 11, "")
            row.divider.label:SetPoint("CENTER")
            row.divider.label:SetText(NS.L["New messages"])
            row.divider.left = row.divider:CreateTexture(nil, "ARTWORK")
            row.divider.left:SetPoint("LEFT")
            row.divider.left:SetPoint("RIGHT", row.divider.label, "LEFT", -10, 0)
            row.divider.left:SetHeight(1)
            row.divider.right = row.divider:CreateTexture(nil, "ARTWORK")
            row.divider.right:SetPoint("LEFT", row.divider.label, "RIGHT", 10, 0)
            row.divider.right:SetPoint("RIGHT")
            row.divider.right:SetHeight(1)
            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()
            row.rail = row:CreateTexture(nil, "BORDER")
            row.rail:SetWidth(2)
            row.reply = CreateFrame("Button", nil, row)
            row.reply:SetSize(48, 24)
            row.reply.index = index
            row.reply.bg = row.reply:CreateTexture(nil, "BACKGROUND")
            row.reply.bg:SetAllPoints()
            local arrow = row.reply:CreateFontString(nil, "OVERLAY")
            arrow:SetFont("Fonts\\ARIALN.TTF", 11, "")
            arrow:SetPoint("CENTER")
            arrow:SetText(NS.L["Reply"])
            arrow:SetTextColor(0.48, 0.73, 0.79)
            row.reply:SetScript("OnClick", function()
                if view.onReply then view.onReply(view, row.reply.index) end
            end)
            row.reply:SetScript("OnEnter", function(self)
                arrow:SetTextColor(0.85, 1, 1)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:AddLine(NS.L["Reply to this message"])
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
            row.body:SetScript("OnMouseDown", function(_, mouseButton)
                forward("OnMouseDown", mouseButton)
                if mouseButton == "RightButton" and view.onMessageMenu then view.onMessageMenu(view, index, row.body) end
            end)
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
    function view:ScrollToMessage(index)
        local row = self.rows[index]
        if not row then return end
        local top = math.max(0, math.min(row.top, self.totalHeight - self:GetHeight()))
        local last = index
        for i = index, #self.lines do
            if self.rows[i].top < top + self:GetHeight() then last = i else break end
        end
        self.offset = #self.lines - last
        self:SetVerticalScroll(top)
    end
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

function NS.CreateCombatPreview(getStyle, options)
    options = options or {}
    local function bound(value, low, high, fallback)
        value = tonumber(value)
        if not value or value ~= value then value = fallback end
        return math.max(low, math.min(high, value))
    end
    local toast = CreateFrame("Frame", "ForeverWhisperCombatPreview", UIParent)
    toast:SetSize(bound(options.popupWidth, 260, 600, 320), bound(options.popupHeight, 92, 240, 92))
    if type(options.popupX) == "number" and type(options.popupY) == "number" then
        toast:SetPoint("CENTER", UIParent, "CENTER", options.popupX, options.popupY)
    else
        toast:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -30, -160)
    end
    toast:SetFrameStrata("DIALOG")
    toast:SetFrameLevel(60)
    toast:SetClampedToScreen(true)
    toast:EnableMouse(true)
    toast:SetMovable(true)
    toast:RegisterForDrag("LeftButton")
    toast.bg = toast:CreateTexture(nil, "BACKGROUND")
    toast.bg:SetAllPoints()
    local icon = toast:CreateTexture(nil, "ARTWORK")
    toast.icon = icon
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
    toast.preview:SetPoint("BOTTOMRIGHT", -12, 28)
    toast.preview:SetJustifyH("LEFT")
    toast.preview:SetWordWrap(true)
    toast.note = toast:CreateFontString(nil, "OVERLAY")
    toast.note:SetPoint("BOTTOMLEFT", 12, 9)
    toast.note:SetPoint("BOTTOMRIGHT", -28, 9)
    toast.note:SetJustifyH("LEFT")
    toast.note:SetWordWrap(false)
    toast.note:SetFont("Fonts\\ARIALN.TTF", 10, "")
    toast.note:SetText(NS.L["Saved — opens after combat"])
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
    toast.onlineQueue, toast.onlinePending = {}, {}
    function toast:ShowNextOnline()
        if self:IsShown() or self.editing then return end
        while #self.onlineQueue > 0 do
            local entry = table.remove(self.onlineQueue, 1)
            self.onlinePending[entry.key] = nil
            if not self.onlineAllowed or self.onlineAllowed(entry.key) then
                self.kind, self.onlineKey, self.count = "online", entry.key, 0
                local _, _, t = getStyle()
                self.bg:SetColorTexture(t[2], t[3], t[4], 0.97)
                self.icon:SetTexture("Interface\\FriendsFrame\\StatusIcon-Online")
                self.title:SetText(entry.author .. NS.L[" is now online"])
                self.title:SetTextColor(0.42, 0.90, 0.64)
                self.preview:SetText("")
                self.note:SetText(NS.L["Friend online"])
                self:ApplyOptions()
                self:Show()
                self:ArmTimer()
                return
            end
        end
    end
    function toast:QueueOnline(key, author)
        if self.onlinePending[key] or (self.kind == "online" and self.onlineKey == key) then return end
        if #self.onlineQueue >= 8 then
            local removed = table.remove(self.onlineQueue, 1)
            self.onlinePending[removed.key] = nil
        end
        self.onlineQueue[#self.onlineQueue + 1] = { key = key, author = author }
        self.onlinePending[key] = true
        self:ShowNextOnline()
    end
    function toast:DropOnline(key)
        for i = #self.onlineQueue, 1, -1 do
            if self.onlineQueue[i].key == key then table.remove(self.onlineQueue, i) end
        end
        self.onlinePending[key] = nil
        if self.kind == "online" and self.onlineKey == key then self:Hide() end
    end
    function toast:SaveGeometry()
        options.popupWidth, options.popupHeight = self:GetWidth(), self:GetHeight()
        local x, y = self:GetCenter()
        local px, py = UIParent:GetCenter()
        if x and y and px and py then
            local ratio = UIParent:GetEffectiveScale() / self:GetEffectiveScale()
            options.popupX, options.popupY = x - px * ratio, y - py * ratio
        end
    end
    function toast:CancelTimer()
        self.serial = self.serial + 1
        if self.timer then self.timer:Cancel(); self.timer = nil end
    end
    function toast:ArmTimer()
        self:CancelTimer()
        if self.editing or self.moving or self.resizing then return end
        local serial = self.serial
        local function expire() if toast.serial == serial then toast:Hide() end end
        local duration = bound(options.popupDuration, 3, 30, 7)
        if C_Timer and C_Timer.NewTimer then self.timer = C_Timer.NewTimer(duration, expire)
        elseif C_Timer and C_Timer.After then C_Timer.After(duration, expire) end
    end
    local resize = CreateFrame("Button", nil, toast)
    toast.resizeGrip = resize
    resize:SetSize(20, 20)
    resize:SetPoint("BOTTOMRIGHT", -2, 2)
    resize:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resize:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    local function finishInteraction()
        if toast.cursorDragging then toast:EndCursorDrag(); return end
        if not toast.moving and not toast.resizing then return end
        toast.moving, toast.resizing = nil, nil
        resize:SetScript("OnUpdate", nil)
        toast:SaveGeometry()
        if toast:IsShown() then toast:ArmTimer() end
    end
    NS.AttachCursorDrag(toast, finishInteraction, function() return not toast.resizing and not options.popupLocked end, function(self)
        self:CancelTimer()
        self.moving = true
    end)
    resize:SetScript("OnMouseDown", function(_, mouseButton)
        if mouseButton ~= "LeftButton" or toast.moving or options.popupLocked then return end
        local left, top = toast:GetLeft(), toast:GetTop()
        if not left or not top then return end
        local x, y = GetCursorPosition()
        local scale = toast:GetEffectiveScale()
        toast:CancelTimer()
        toast.resizing = true
        local width, height = toast:GetWidth(), toast:GetHeight()
        local maxWidth = math.max(width, math.min(600, UIParent:GetWidth() * UIParent:GetEffectiveScale() / scale - left))
        local maxHeight = math.max(height, math.min(240, top))
        toast:ClearAllPoints()
        toast:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        resize:SetScript("OnUpdate", function()
            if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then finishInteraction(); return end
            local cx, cy = GetCursorPosition()
            local w, h = bound(width + (cx-x)/scale, 260, maxWidth, width), bound(height - (cy-y)/scale, 92, maxHeight, height)
            if w ~= toast:GetWidth() or h ~= toast:GetHeight() then toast:SetSize(w, h) end
        end)
    end)
    resize:SetScript("OnMouseUp", finishInteraction)
    toast:SetScript("OnHide", function(self)
        finishInteraction()
        self.editing = nil
        self.kind, self.onlineKey = nil, nil
        self:CancelTimer()
        if #self.onlineQueue > 0 and not self.pendingDispatch and C_Timer and C_Timer.After then
            self.pendingDispatch = true
            C_Timer.After(0, function()
                self.pendingDispatch = nil
                self:ShowNextOnline()
            end)
        end
    end)
    function toast:ApplyOptions()
        if options.popupLocked then finishInteraction() end
        self:SetMovable(not options.popupLocked)
        resize:SetShown(not options.popupLocked)
        self.preview:SetShown(self.kind ~= "online" and not options.popupNameOnly)
        local path = getStyle()
        local size = bound(options.popupFontSize, 10, 20, 13)
        self.title:SetFont(path, size + 1, "")
        self.preview:SetFont(path, size, "")
        if self.editing then
            self.note:SetText(options.popupLocked and NS.L["Locked - change in Popup options"] or NS.L["Position and size saved automatically"])
        end
    end
    function toast:ShowWhisper(author, text)
        self.editing = nil
        if self.kind == "online" then self.count = 0 end
        self.kind, self.onlineKey = "whisper", nil
        self.icon:SetTexture("Interface\\AddOns\\ForeverWhisper\\UI\\WhisperMark.tga")
        self.count, self.serial = self.count + 1, self.serial + 1
        local path, size, t = getStyle()
        self.bg:SetColorTexture(t[2], t[3], t[4], 0.97)
        self.title:SetFont(path, math.min(size, 15), "")
        self.title:SetTextColor(1, 0.81, 0.51)
        self.title:SetText(author .. (self.count > 1 and ("  ·  " .. self.count .. NS.L[" new"]) or ""))
        self.preview:SetFont(path, math.min(size, 13), "")
        self.preview:SetTextColor(0.84, 0.89, 0.94)
        self.preview:SetText(text)
        self:ApplyOptions()
        self:Show()
        self.note:SetText(NS.L["Saved - opens after combat"])
        self:ArmTimer()
    end
    function toast:Arrange()
        self:Reset()
        self:ShowWhisper(NS.L["Whisper preview"], NS.L["Drag this popup to move it. Drag the bottom-right corner to change its size."])
        self.editing, self.count = true, 0
        self:CancelTimer()
        self:ApplyOptions()
    end
    function toast:ResetGeometry()
        self:Reset()
        options.popupX, options.popupY, options.popupWidth, options.popupHeight = nil, nil, nil, nil
        self:ClearAllPoints()
        self:SetSize(320, 92)
        self:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -30, -160)
    end
    function toast:Reset(preserveOnline)
        if not preserveOnline then self.onlineQueue, self.onlinePending = {}, {} end
        if self.timer then self.timer:Cancel(); self.timer = nil end
        self.serial, self.count = self.serial + 1, 0
        self:Hide()
    end
    toast:Hide()
    toast:ApplyOptions()
    return toast
end
