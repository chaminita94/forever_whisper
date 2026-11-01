"""Run the addon in Lua 5.1 with a small WoW API test double.

This checks event/state behavior, not the actual WoW renderer.
"""
from pathlib import Path
import sys
import re
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / ".tools" / "lua"))
from lupa.lua51 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
WOW_MOCK = r'''
objects, filters, sent = {}, {}, {}
local methods = {}
local function object(kind, name, parent)
    local o = setmetatable({kind=kind, name=name, parent=parent, scripts={}, points={},
        shown=true, text="", width=0, height=0, lines={}, offset=0}, {__index=methods})
    objects[#objects+1] = o
    if name then _G[name] = o end
    return o
end
function CreateFrame(kind,name,parent) return object(kind,name,parent) end
function methods:CreateTexture(name,layer) local t=object("Texture",name,self); t.layer=layer; return t end
function methods:CreateFontString(name,layer) return object("FontString",name,self) end
local nativeScripts={OnEvent=true,OnShow=true,OnHide=true,OnSizeChanged=true,OnUpdate=true,
    OnEnter=true,OnLeave=true,OnMouseDown=true,OnMouseUp=true,OnMouseWheel=true,OnClick=true,OnKeyDown=true,OnKeyUp=true,
    OnDragStart=true,OnDragStop=true,OnEscapePressed=true,OnEnterPressed=true,OnTextChanged=true,
    OnEditFocusGained=true,OnEditFocusLost=true,OnHyperlinkClick=true,OnValueChanged=true}
function methods:SetScript(name,fn)
    assert(nativeScripts[name],"Unsupported native WoW script: "..tostring(name))
    self.scripts[name]=fn
end
function methods:GetScript(name)
    assert(nativeScripts[name],"Unsupported native WoW script: "..tostring(name))
    return self.scripts[name]
end
function methods:HookScript(name,fn)
    assert(nativeScripts[name],"Unsupported native WoW script: "..tostring(name))
    local previous=self.scripts[name]
    self.scripts[name]=function(...) if previous then previous(...) end;fn(...) end
end
function methods:SetPoint(...) self.points[#self.points+1]={...} end
function methods:GetPoint() return unpack(self.points[1] or {"CENTER",self.parent,"CENTER",0,0}) end
function methods:ClearAllPoints() self.points={} end
function methods:SetSize(w,h)
    self.width=w;self.height=h
    if self.scripts.OnSizeChanged then self.scripts.OnSizeChanged(self,w,h) end
end
function methods:SetWidth(v) self.width=v end
function methods:SetHeight(v) self.height=v end
function methods:GetWidth() return self.width>0 and self.width or (self.parent and self.parent:GetWidth() or 800) end
function methods:GetHeight() return self.height>0 and self.height or (self.parent and self.parent:GetHeight() or 600) end
function methods:SetFont(path,size) self.font=path;self.fontSize=size end
function methods:SetFontString(f) self.fontText=f end
function methods:SetText(text)
    self.text=tostring(text or "")
    if self.fontText then self.fontText.text=self.text end
    if self.kind=="EditBox" and self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end
end
function methods:GetText() return self.text end
function methods:Insert(text) self:SetText(self.text..text) end
function methods:SetShown(v)
    v=not not v
    local changed=self.shown~=v; self.shown=v
    if changed then local fn=self.scripts[v and "OnShow" or "OnHide"];if fn then fn(self) end end
end
function methods:IsShown() return self.shown and (not self.parent or self.parent:IsShown()) end
function methods:Hide() self:SetShown(false) end
function methods:Show() self:SetShown(true) end
function methods:SetFocus()
    for _,o in ipairs(objects) do if o~=self and o.focus then o:ClearFocus() end end
    self.focus=true;if self.scripts.OnEditFocusGained then self.scripts.OnEditFocusGained(self) end
end
function methods:ClearFocus() self.focus=false;if self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self) end end
function methods:SetEnabled(v) self.enabled=not not v end
function methods:SetChecked(v) self.checked=v end
function methods:GetChecked() return self.checked end
function methods:SetValue(v) self.value=v;if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self,v) end end
function methods:SetColorTexture(...) self.color={...} end
function methods:SetTextColor(...) self.textColor={...} end
function methods:SetTexture(t) self.texture=t end
function methods:SetTexCoord(...) self.texCoord={...} end
function methods:SetVertexColor(...) self.vertexColor={...} end
function methods:SetDesaturated(v) self.desaturated=v end
function methods:SetHyperlinksEnabled(value) self.hyperlinks=value end
function methods:GetFrameLevel() return self.level or (self.parent and self.parent:GetFrameLevel()+1 or 1) end
function methods:HasFocus() return not not self.focus end
function methods:GetParent() return self.parent end
function methods:SetFrameLevel(n) self.level=n end
function methods:GetEffectiveScale() return 1 end
function methods:GetCenter() return 400,300 end
function methods:AddMessage(t) self.lines[#self.lines+1]=t end
function methods:Clear() self.lines={} end
function methods:ScrollToBottom() self.offset=0 end
function methods:ScrollUp() self.offset=self.offset+1 end
function methods:ScrollDown() self.offset=math.max(0,self.offset-1) end
function methods:GetScrollOffset() return self.offset end
function methods:SetScrollOffset(v) self.offset=v end
function methods:GetVerticalScroll() return self.verticalScroll or 0 end
function methods:SetVerticalScroll(v) self.verticalScroll=v end
local function plain(text)
    text=text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    text=text:gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", "OO")
    return text
end
function methods:GetStringWidth()
    local longest=0
    for line in (plain(self.text).."\n"):gmatch("(.-)\n") do longest=math.max(longest,#line) end
    return longest*(self.fontSize or 14)*0.52
end
function methods:GetStringHeight()
    local lines=0
    for line in (plain(self.text).."\n"):gmatch("(.-)\n") do
        lines=lines+math.max(1,math.ceil(#line*(self.fontSize or 14)*0.52/math.max(1,self.width)))
    end
    return lines*((self.fontSize or 14)+2)
end
for _,name in ipairs({"SetAllPoints","SetAutoFocus","SetClampedToScreen","SetFading",
    "SetFrameStrata","SetHighlightTexture","SetJustifyH","SetMaxLetters","SetMaxLines",
    "SetMaxResize","SetMinMaxValues","SetMinResize","SetMovable","SetMultiLine",
    "SetNormalTexture","SetObeyStepOnDrag","SetOwner","SetPushedTexture","SetResizable",
    "SetResizeBounds","SetScale","SetScrollChild","SetSpacing","SetTextInsets","SetValueStep",
    "SetWordWrap","EnableMouse","EnableMouseWheel","RegisterEvent","UnregisterEvent",
    "RegisterForClicks","RegisterForDrag","StartMoving","StartSizing","StopMovingOrSizing",
    "HighlightText","AddLine","SetThumbTexture","SetOrientation"}) do methods[name]=function() end end
function methods:SetAllPoints(target) self.allPoints=target or self.parent end
function methods:SetScrollChild(target) self.scrollChild=target end
function methods:SetJustifyH(value) self.justify=value end
function methods:SetTextInsets(left,right) self.insetLeft=left;self.insetRight=right end
UIParent=CreateFrame("Frame","UIParent");UIParent:SetSize(1920,1080)
Minimap=CreateFrame("Frame","Minimap",UIParent);Minimap:SetSize(140,140)
GameTooltip=CreateFrame("Frame","GameTooltip",UIParent)
DEFAULT_CHAT_FRAME=CreateFrame("Frame","DEFAULT_CHAT_FRAME",UIParent)
UISpecialFrames={};SlashCmdList={};StaticPopupDialogs={};YES="Yes";NO="No"
clock=100000;combat=false
timers={};C_Timer={After=function(_,fn) timers[#timers+1]=fn end}
function C_Timer.NewTimer(delay,fn)
    local timer={delay=delay,cancelled=false,Cancel=function(self) self.cancelled=true end}
    timers[#timers+1]=function() if not timer.cancelled then fn() end end
    return timer
end
addonSent={}
C_ChatInfo={RegisterAddonMessagePrefix=function() return true end,
    SendAddonMessage=function(prefix,payload,channel,target)
        addonSent[#addonSent+1]={prefix=prefix,payload=payload,channel=channel,target=target}
        return true
    end}
function time() return clock end
function date(format,t) return os.date(format,t) end
function InCombatLockdown() return combat end
function IsInGuild() return false end
function IsShiftKeyDown() return false end
function GetRealmName() return "TestRealm" end
function GetRealZoneText() return "Stormwind" end
function position(x,y) return {GetXY=function() return x,y end} end
C_Map={
    GetBestMapForUnit=function() return 37 end,
    GetPlayerMapPosition=function() if not positionUnavailable then return position(0.425,0.68) end end,
    GetMapInfo=function(id) return {name="Elwynn Forest"} end,
}
WorldMapFrame=CreateFrame("Frame","WorldMapFrame",UIParent)
WorldMapFrame.canvas=CreateFrame("Frame",nil,WorldMapFrame)
WorldMapFrame.canvas:SetSize(1000,666)
WorldMapFrame.GetCanvas=function(self) return self.canvas end
WorldMapFrame.SetMapID=function(self,id) self.mapID=id end
WorldMapFrame.GetMapID=function(self) return self.mapID end
WorldMapFrame:Hide()
function ShowUIPanel(frame) frame:Show() end
function hooksecurefunc(owner,method,fn)
    local old=owner[method]
    owner[method]=function(...) local result=old(...);fn(...);return result end
end
function UnitPopup_OpenMenu(which,data) nativeMenu={which=which,data=data} end
function SetItemRef(link,text,button) nativeLink={link=link,button=button} end
function ChatFrame_OpenChat(text) preparedCommand=text end
C_PartyInfo={InviteUnit=function(name) invited=name end}
C_FriendList={AddFriend=function(name) addedFriend=name end}
function ChatFrame_AddMessageEventFilter(e,f) filters[e]=f end
function SendChatMessage(text,kind,lang,name) sent[#sent+1]={text=text,name=name} end
function StaticPopup_Show(which,text,_,data) popup={which=which,text=text,data=data} end
function event(name,...)
    for _,o in ipairs(objects) do if o.kind=="Frame" and o.scripts.OnEvent then o.scripts.OnEvent(o,name,...) end end
end
function find(kind,text)
    for _,o in ipairs(objects) do
        if o.kind==kind and o.text==text and o:IsShown() then return o end
    end
    error("Missing visible "..kind..": "..text)
end
function click(text) local b=find("Button",text);assert(b.enabled~=false);b.scripts.OnClick(b) end
function selectDropdown(value)
    local menu=ForeverWhisperDropdown
    assert(menu and menu:IsShown(),"Dropdown did not open")
    for _,entry in ipairs(menu.entries) do
        if entry.value==value then
            if menu.search:IsShown() then menu.search:SetText(entry.text) end
            for _,row in ipairs(menu.rows) do
                if row:IsShown() and row.entry and row.entry.value==value then row.scripts.OnClick(row);return end
            end
        end
    end
    error("Dropdown value missing: "..tostring(value))
end
function visibleInput()
    for _,o in ipairs(objects) do if o.kind=="EditBox" and o:IsShown() and o.hint then return o end end
    error("No composer")
end
ForeverWhisperDB={schema=2,identitySchema=1,width=620,height=480,font=5,theme=7,opacity=0.94,
    customActions={
        {label="Ask to group",template="Want to group up, {name}?"},
        {label="Send my location",template="I'm in {zone}."},
        {label="Keep my shortcut",template="A personal custom message"},
    },
    conversations={legacy={name="Legacy",last=1,unread=0,pinned=true,
        messages={{text="Existing saved history",at=1,outgoing=false}}},
        ["bnet:saved#1234"]={kind="bnet",name="Saved#1234",battleTag="Saved#1234",last=0,messages={}}}}
'''
lua.execute(WOW_MOCK)
ns = lua.table()
for name in ("Localization.lua","MessengerUI.lua","Social.lua","BattleNet.lua","ForeverWhisper.lua"):
    source = (ROOT / name).read_text(encoding="utf-8")
    lua.execute("assert(loadstring(...))", source)
    lua.execute(source, "ForeverWhisper", ns)
lua.execute(r'''
event("ADDON_LOADED","ForeverWhisper")
assert(ForeverWhisperDB.identitySchema==2 and ForeverWhisperDB.conversations["bnet:saved#1234"].name=="Saved",
    "Existing profiles did not migrate private BattleTag labels")
assert(ForeverWhisperWindow.sendButton and ForeverWhisperCombatPreview and ForeverWhisperMinimapButton,
    "Startup did not complete: composer, combat preview or minimap missing")
assert(ForeverWhisperMinimapButton:IsShown(),"Default minimap button missing after initialization")
assert(#ForeverWhisperDB.recentEmoji==0)
assert(ForeverWhisperDB.width==700)
assert(ForeverWhisperDB.conversations.legacy.messages[1].text=="Existing saved history")
assert(ForeverWhisperDB.conversations.legacy.pinned)
assert(ForeverWhisperDB.shape==nil)
assert(#ForeverWhisperDB.customActions==1 and ForeverWhisperDB.customActions[1].label=="Keep my shortcut")
assert(ForeverWhisperDB.theme==9)
assert(not ForeverWhisperWindow:IsShown())
SlashCmdList.FOREVERWHISPER("Alice")
local composer=visibleInput()
composer:SetText("Draft for Alice")
event("CHAT_MSG_WHISPER","Hey :skull:","Bob")
assert(composer:GetText()=="Draft for Alice","Incoming whisper stole draft")
assert(ForeverWhisperDB.conversations.bob.unread==1)
click("Send")
assert(sent[#sent].name=="Alice","Incoming whisper changed recipient")
assert(sent[#sent].text=="Draft for Alice")
composer:SetText("Keep this")
SlashCmdList.FOREVERWHISPER("Bob")
assert(composer:GetText()=="")
composer:SetText("Bob draft")
SlashCmdList.FOREVERWHISPER("Alice")
assert(composer:GetText()=="Keep this")
event("CHAT_MSG_WHISPER_INFORM","hello :heart_hands: :bruh:","Alice")
local log=ForeverWhisperWindow.transcript
assert(log.lines[#log.lines]:find("|cff89cfff[You]",1,true),"Outgoing sender label unclear")
assert(log.lines[#log.lines]:find("|cffd6e1eb  ",1,true),"Message indentation missing")
assert(log.lines[#log.lines]:find("1faf6.png",1,true),"Underscore emoji failed")
assert(log.lines[#log.lines]:find("1f5ff.png",1,true),"Alias emoji failed")
assert(log.rows[#log.lines].outgoing and log.rows[#log.lines].body.justify=="RIGHT")
log:SetSize(420,100)
for i=1,5 do event("CHAT_MSG_WHISPER_INFORM","Scroll seed "..i,"Alice") end
log.offset=3
event("CHAT_MSG_WHISPER","another","Alice")
assert(log.lines[#log.lines]:find("|cffffcf83|Hfwplayer:alice|h[Alice]|h",1,true),"Incoming sender label unclear")
assert(log.offset==4,"Incoming message lost scroll position")
assert(not log.rows[#log.lines].outgoing and log.rows[#log.lines].body.justify=="LEFT")
local bubbleCount=#objects
for i=1,10 do log:Restyle() end
assert(#objects==bubbleCount,"Reflow allocated more message rows")
assert(log.rows[#log.lines].width<=log:GetWidth()*0.80)
for _, row in ipairs(log.rows) do
    assert(ForeverWhisperWindow.latest:GetFrameLevel()>row.body:GetFrameLevel(),
        "Message text intercepts Latest messages clicks")
    assert(ForeverWhisperWindow.latest:GetFrameLevel()>row.reply:GetFrameLevel(),
        "Reply controls intercept Latest messages clicks")
end
click("Latest messages")
assert(log.offset==0)
assert(not ForeverWhisperWindow.latest:IsShown())
local bottomPixels=log:GetVerticalScroll()
log.scripts.OnMouseWheel(log,1)
assert(log:GetVerticalScroll()<bottomPixels,"First wheel step did not move the chat")
local firstWheel=log:GetVerticalScroll()
log.rows[#log.lines].body.scripts.OnMouseWheel(nil,1)
assert(log:GetVerticalScroll()<firstWheel,"Wheel over a bubble did not move immediately")
log.scripts.OnMouseWheel(log,-1)
assert(math.abs(log:GetVerticalScroll()-firstWheel)<0.001,"Wheel direction did not reverse consistently")
click("Latest messages")
click("More ...")
click("Ignore player...")
assert(popup.which=="FOREVERWHISPER_IGNORE" and popup.data=="Alice")
click("Search")
for _,o in ipairs(objects) do
    if o.kind=="EditBox" and o:IsShown() then o:SetText("Bob");o.scripts.OnEnterPressed(o);break end
end
find("FontString","|cff72eadbPERSON|r  Bob")
click("Back")
-- Emoji drawer: search, category, reusable slots and recent history.
local emojiButton
for _,o in ipairs(objects) do
    if o.kind=="Button" and o.text=="" and o.width==50 then emojiButton=o end
end
emojiButton.scripts.OnClick(emojiButton)
click("Memes")
local chosen
for _,o in ipairs(objects) do
    if o.kind=="Button" and o.entry and o.entry[1]=="skull" and o:IsShown() then chosen=o end
end
assert(chosen,"Skull missing from memes")
chosen.scripts.OnClick(chosen)
assert(composer:GetText():find(":skull:",1,true))
assert(ForeverWhisperDB.recentEmoji[1]=="skull")
emojiButton.scripts.OnClick(emojiButton)
click("Recent")
local recent=0
for _,o in ipairs(objects) do if o.kind=="Button" and o.entry and o:IsShown() then recent=recent+1 end end
assert(recent==1,"Recent filter failed")
local frameCount=#objects
for i=1,20 do
    emojiButton.scripts.OnClick(emojiButton)
    emojiButton.scripts.OnClick(emojiButton)
end
assert(#objects==frameCount,"Emoji drawer allocated frames while toggling")
click("Settings")
event("CHAT_MSG_WHISPER","While in settings","Alice")
assert(ForeverWhisperDB.conversations.alice.unread==1,"Settings incorrectly marked whisper read")
click("Back")
assert(ForeverWhisperDB.conversations.alice.unread==0,"Opening chat did not clear unread")
-- Combat routing and reopening.
combat=true;event("PLAYER_REGEN_DISABLED")
assert(not ForeverWhisperWindow:IsShown())
assert(filters.CHAT_MSG_WHISPER(nil,"CHAT_MSG_WHISPER")==false)
event("CHAT_MSG_WHISPER","Combat test","Carol")
assert(not ForeverWhisperWindow:IsShown())
assert(ForeverWhisperCombatPreview:IsShown(),"Combat preview missing")
assert(ForeverWhisperCombatPreview.title.text=="Carol")
local oldTimer=timers[#timers]
event("CHAT_MSG_WHISPER","Another preview","Carol")
oldTimer();assert(ForeverWhisperCombatPreview:IsShown(),"Old timer hid newer preview")
timers[#timers]();assert(not ForeverWhisperCombatPreview:IsShown())
ForeverWhisperDB.combatPreview=false
event("CHAT_MSG_WHISPER","No preview","Carol")
assert(not ForeverWhisperCombatPreview:IsShown())
ForeverWhisperDB.combatPreview=true
combat=false;event("PLAYER_REGEN_ENABLED")
assert(not ForeverWhisperCombatPreview:IsShown())
assert(ForeverWhisperWindow:IsShown())
assert(ForeverWhisperDB.conversations.carol.messages[1].text=="Combat test")
assert(filters.CHAT_MSG_WHISPER(nil,"CHAT_MSG_WHISPER")==true)
-- Context menus bind to the clicked person even while the list is re-sorted.
SlashCmdList.FOREVERWHISPER("Alice")
composer:SetText("Still writing Alice")
local function rightClick(name)
    for _,o in ipairs(objects) do
        if o.kind=="Button" and o.key==name:lower() then o.scripts.OnClick(o,"RightButton");return end
    end
    error("Missing contact: "..name)
end
rightClick("Bob")
event("CHAT_MSG_WHISPER","Resort the list","Carol")
click("Invite to group")
assert(invited=="Bob","Context action targeted the active chat or a recycled row")
assert(composer:GetText()=="Still writing Alice")
click("Send")
assert(sent[#sent].name=="Alice")
event("CHAT_MSG_WHISPER","Report evidence","Bob","", "", "", "", "", "", "", "", 55,"Player-1-B0B")
rightClick("Bob");click("Report / WoW player menu...")
assert(nativeMenu.which=="FRIEND" and nativeMenu.data.name=="Bob")
assert(nativeMenu.data.guid=="Player-1-B0B" and nativeMenu.data.lineID==55)
rightClick("Bob");click("Copy character name")
find("EditBox","Bob")
click("Close")
rightClick("Bob");click("Add friend");assert(addedFriend=="Bob")
rightClick("Bob");click("Ignore player...")
assert(popup.data=="Bob")
rightClick("Bob");click("Customize actions...")
local editor=ForeverWhisperCustomActions
editor.fields[1].label:SetText("Wave")
editor.fields[1].template:SetText("/wave {name}")
editor.fields[2].label:SetText("Group note")
editor.fields[2].template:SetText("Meet me in {zone}, {name}.")
click("Save shortcuts")
rightClick("Bob");click("Wave")
assert(preparedCommand=="/wave Bob","Custom command was not prepared for clicked contact")
rightClick("Bob");click("Group note")
assert(composer:GetText()=="Meet me in Stormwind, Bob.")
log.onHyperlinkClick(log,"fwplayer:alice","Alice","RightButton")
assert(log.hyperlinks,"Transcript links were not enabled")
click("Copy character name");find("EditBox","Alice");click("Close")
ForeverWhisperWindow.nameTarget.scripts.OnClick(ForeverWhisperWindow.nameTarget)
click("Copy character name");find("EditBox","Bob");click("Close")
local native=UnitPopup_OpenMenu;UnitPopup_OpenMenu=nil
rightClick("Bob");click("Report / WoW player menu...")
assert(nativeLink.link:find("player:Bob:",1,true) and nativeLink.button=="RightButton")
UnitPopup_OpenMenu=native
click("Settings")
local nextTheme=ForeverWhisperSettings.themeSelector
nextTheme.scripts.OnClick(nextTheme);selectDropdown(ForeverWhisperDB.theme)
local geometryObjects=#objects
click("Preview art")
local artPreview=ForeverWhisperArtPreview
assert(artPreview:IsShown())
assert(artPreview.image.texture==ForeverWhisperWindow.artCorner.texture)
assert(artPreview.ambient.texture==ForeverWhisperWindow.artAmbient.texture)
assert(artPreview.headerArt.texture==ForeverWhisperWindow.artHeader.texture)
artPreview.brightness:SetValue(0.8)
assert(math.abs(ForeverWhisperWindow.artCorner.vertexColor[4]-0.8)<0.001)
-- Change panel opacity independently from artwork visibility.
ForeverWhisperDB.opacity=0.2
artPreview.brightness:SetValue(1)
assert(ForeverWhisperWindow.artCorner.vertexColor[4]==1)
assert(ForeverWhisperWindow.artAmbient.vertexColor[4]==0.30)
assert(ForeverWhisperWindow.artHeader.vertexColor[4]==0.60)
ForeverWhisperDB.opacity=0.94
local artNames={"IronCorner","FrostCorner",false,"ForestCorner","DoomCorner","IronCorner","CelestialCorner","CelestialCorner","SakuraCorner"}
for i=1,9 do
    nextTheme.scripts.OnClick(nextTheme)
    selectDropdown(ForeverWhisperDB.theme%9+1)
    if ForeverWhisperDB.theme==3 then
        assert(not ForeverWhisperWindow.artCorner.shown and not ForeverWhisperWindow.artHeader.shown)
        assert(not ForeverWhisperWindow.artAmbient.shown and not ForeverWhisperWindow.artSide.shown)
        assert(not ForeverWhisperWindow.accent.shown and not log.rows[1].rail.shown)
        assert(not ForeverWhisperWindow.artCorner.texture and not artPreview.image.texture)
        assert(artPreview.emptyMessage.shown and not artPreview.brightnessRow.shown)
        assert(ForeverWhisperDB.artwork,"Minimal changed the player's global artwork preference")
        assert(not find("Button","No artwork").enabled)
    else
    assert(ForeverWhisperWindow.artCorner.texture:find(artNames[ForeverWhisperDB.theme]..".tga",1,true))
    assert(artPreview.image.texture==ForeverWhisperWindow.artCorner.texture)
    assert(ForeverWhisperWindow.artAmbient.texture:find(artNames[ForeverWhisperDB.theme]:gsub("Corner","Atmosphere")..".tga",1,true))
    assert(artPreview.headerArt.texture==ForeverWhisperWindow.artHeader.texture)
    end
end
click("Artwork: On");assert(not ForeverWhisperDB.artwork)
for i=1,9 do
    nextTheme.scripts.OnClick(nextTheme)
    selectDropdown(ForeverWhisperDB.theme%9+1)
    assert(not ForeverWhisperWindow.artCorner.shown and not ForeverWhisperWindow.artSide.shown)
    assert(not ForeverWhisperWindow.artAmbient.shown and not ForeverWhisperWindow.artHeader.shown)
end
click("Artwork: Off");assert(ForeverWhisperDB.artwork)
assert(#objects==geometryObjects,"Toggling artwork recreated textures")
click("Back")
assert(not artPreview:IsShown(),"Preview stayed open outside Settings")
assert(ForeverWhisperWindow.artCorner:IsShown())
-- Coordinate sharing does not send until Enter and preserves existing drafts.
composer:SetText("Meet here:")
local sendCount=#sent
rightClick("Bob");click("Share my position pin")
assert(#sent==sendCount)
assert(composer:GetText():find("Meet here:",1,true))
assert(composer:GetText():find("[Pin: Elwynn Forest 42.5, 68.0] {fwmap:37:4250:6800}",1,true))
click("Send");assert(sent[#sent].name=="Bob")
event("CHAT_MSG_WHISPER_INFORM",sent[#sent].text,"Bob")
assert(log.lines[#log.lines]:find("|Hfwmap:37:4250:6800|h",1,true),"Pin was not rendered clickable")
log.onHyperlinkClick(log,"fwmap:37:4250:6800","Pin","LeftButton")
assert(WorldMapFrame:GetMapID()==37 and WorldMapFrame:IsShown())
assert(ForeverWhisperMapPin:IsShown() and ForeverWhisperMapPin.x==0.425)
WorldMapFrame:SetMapID(38);assert(not ForeverWhisperMapPin:IsShown())
WorldMapFrame:SetMapID(37);assert(ForeverWhisperMapPin:IsShown())
log.onHyperlinkClick(log,"fwmap:37:999999:1","Pin","LeftButton")
assert(ForeverWhisperMapPin.x==0.425,"Invalid pin changed marker")
local mapInfo=C_Map.GetMapInfo
C_Map.GetMapInfo=function(id) if id~=9999 then return mapInfo(id) end end
log.onHyperlinkClick(log,"fwmap:9999:4250:6800","Pin","LeftButton")
assert(WorldMapFrame:GetMapID()==37,"Unknown map was opened")
C_Map.GetMapInfo=mapInfo
composer:SetText("Keep this draft")
positionUnavailable=true
rightClick("Bob");click("Share my position pin")
assert(composer:GetText()=="Keep this draft")
positionUnavailable=false
-- Modern/native path: generating a link restores the prior user waypoint.
UiMapPoint={CreateFromCoordinates=function(id,x,y) return {uiMapID=id,position=position(x,y)} end}
local original=UiMapPoint.CreateFromCoordinates(37,0.1,0.2)
userWaypoint=original
C_Map.GetUserWaypoint=function() return userWaypoint end
C_Map.SetUserWaypoint=function(point) userWaypoint=point;return true end
C_Map.ClearUserWaypoint=function() userWaypoint=nil end
C_Map.CanSetUserWaypointOnMap=function() return true end
C_Map.GetUserWaypointHyperlink=function()
    local x,y=userWaypoint.position:GetXY()
    return string.format("|Hworldmap:%d:%d:%d|h[Map Pin]|h",userWaypoint.uiMapID,x*10000,y*10000)
end
C_SuperTrack={SetSuperTrackedUserWaypoint=function(value) tracked=value end}
rightClick("Bob");click("Share my position pin")
assert(userWaypoint==original,"Generating pin replaced existing waypoint")
assert(composer:GetText():find("|Hworldmap:37:4250:6800",1,true))
composer:SetText("")
rightClick("Bob");click("Share active map pin")
assert(composer:GetText():find("|Hworldmap:37:1000:2000",1,true))
assert(userWaypoint==original)
log.onHyperlinkClick(log,"fwmap:37:4250:6800","Pin","LeftButton")
assert(tracked and not ForeverWhisperMapPin:IsShown())
local modernMap=C_Map
C_Map=nil
GetCurrentMapAreaID=function() return 37 end
GetPlayerMapPosition=function() return 0.125,0.25 end
composer:SetText("")
rightClick("Bob");click("Share my position pin")
assert(composer:GetText():find("{fwmap:37:1250:2500}",1,true),"Legacy coordinates failed")
C_Map=modernMap
-- Reply actions preserve drafts/recipients and include a readable fallback on the wire.
SlashCmdList.FOREVERWHISPER("Alice")
event("CHAT_MSG_WHISPER","Please bring potions","Alice")
log.rows[#log.lines].reply.scripts.OnClick()
assert(ForeverWhisperWindow.replyBar:IsShown())
composer:SetText("On my way")
SlashCmdList.FOREVERWHISPER("Bob")
assert(not ForeverWhisperWindow.replyBar:IsShown())
SlashCmdList.FOREVERWHISPER("Alice")
assert(ForeverWhisperWindow.replyBar:IsShown() and composer:GetText()=="On my way")
click("Send")
assert(sent[#sent].name=="Alice" and sent[#sent].text=="[Reply to: Please bring potions] On my way")
assert(not ForeverWhisperWindow.replyBar:IsShown())
event("CHAT_MSG_WHISPER_INFORM",sent[#sent].text,"Alice")
assert(log.lines[#log.lines]:find("Reply to:|r\n|cff98aaa9Please bring potions",1,true))
log.rows[#log.lines].reply.scripts.OnClick()
composer:SetText(string.rep("x",250))
local beforeOversize=#sent
composer.scripts.OnEnterPressed(composer)
assert(#sent==beforeOversize,"Oversized quoted reply was sent")
composer:SetText("Short reply");click("Send")
-- Native friends do not need the addon, while unknown people stay unknown.
local friendRows={{name="Alice",connected=true,area="Stormwind"},{name="Bob",connected=false}}
C_FriendList.GetNumFriends=function() return #friendRows end
C_FriendList.GetFriendInfoByIndex=function(i) return friendRows[i] end
event("FRIENDLIST_UPDATE")
assert(ForeverWhisperWindow.presence.text=="Online  ·  Stormwind")
SlashCmdList.FOREVERWHISPER("Bob")
assert(ForeverWhisperWindow.presence.text=="Offline (friend)")
SlashCmdList.FOREVERWHISPER("Carol")
assert(ForeverWhisperWindow.presence.text=="Status: friends and guild only")
SlashCmdList.FOREVERWHISPER("Alice")
event("CHAT_MSG_ADDON","FWCHAT1","H","WHISPER","Alice-TestRealm")
event("CHAT_MSG_ADDON","FWCHAT1","T","WHISPER","Alice-TestRealm")
assert(ForeverWhisperWindow.presence.text=="Typing...")
timers[#timers]()
assert(ForeverWhisperWindow.presence.text=="Online  ·  Stormwind")
local beforeUnknown=#addonSent
event("CHAT_MSG_ADDON","FWCHAT1","H","WHISPER","Unknownperson")
assert(#addonSent==beforeUnknown and not ForeverWhisperDB.conversations.unknownperson)
-- Typing is throttled and sends only tiny state markers, never the draft text.
clock=clock+10
composer:SetText("private draft")
local beforeTyping=#addonSent
for i=1,50 do composer.scripts.OnTextChanged(composer,true) end
assert(#addonSent==beforeTyping+1 and addonSent[#addonSent].payload=="T")
composer:ClearFocus()
assert(addonSent[#addonSent].payload=="0")
ForeverWhisperDB.typing=false
local beforeDisabled=#addonSent
composer.scripts.OnTextChanged(composer,true)
event("CHAT_MSG_ADDON","FWCHAT1","T","WHISPER","Alice")
assert(#addonSent==beforeDisabled and ForeverWhisperWindow.presence.text~="Typing...")
ForeverWhisperDB.typing=true
-- Battle.net uses its own event stream and stable BattleTag identity, never a character name.
local bnRows={
    {bnetAccountID=10,battleTag="freddy#1111",accountName="freddy",gameAccountInfo={isOnline=true,clientProgram="WoW",gameAccountID=110,areaName="Stormwind"}},
    {bnetAccountID=20,battleTag="freddy#2222",accountName="freddy",gameAccountInfo={isOnline=true,clientProgram="D3",gameAccountID=220}},
}
local bnOnline=true
function BNConnected() return bnOnline end
function BNGetNumFriends() return #bnRows end
bnSent={}
C_BattleNet={
    GetFriendAccountInfo=function(i) return bnRows[i] end,
    GetAccountInfoByID=function(id)
        for _,info in ipairs(bnRows) do if info.bnetAccountID==id then return info end end
    end,
    SendWhisper=function(id,text) bnSent[#bnSent+1]={id=id,text=text};return true end,
    InviteFriend=function(id) bnInvited=id end,
}
local function bnArgs(text,id)
    return {[1]=text,[2]="freddy",[11]=90,[12]="",[13]=id}
end
local function bnEvent(kind,text,id) event(kind,unpack(bnArgs(text,id),1,13)) end
event("BN_CONNECTED")
bnEvent("CHAT_MSG_BN_WHISPER_INFORM","Native outgoing",10)
assert(ForeverWhisperDB.conversations["bnet:freddy#1111"].messages[1].text=="Native outgoing")
assert(ForeverWhisperWindow.heading.text=="freddy","Native outgoing did not select BNet conversation")
local bnChat=ForeverWhisperDB.conversations["bnet:freddy#1111"]
local function contactRow(key)
    for _,o in ipairs(objects) do if o.key==key and o.statusDot and o:IsShown() then return o end end
    error("Missing sidebar contact "..key)
end
local bnSidebar=contactRow("bnet:freddy#1111")
assert(bnSidebar.detail.text:find("Online",1,true) and bnSidebar.detail.text:find("Battle.net",1,true))
assert(bnSidebar.statusDot.parent==bnSidebar.avatarBackground.parent,
    "Presence icon must be drawn on the avatar, above its background")
bnRows[1].gameAccountInfo.isOnline=false
event("BN_FRIEND_ACCOUNT_OFFLINE",10)
assert(contactRow("bnet:freddy#1111").detail.text=="Offline  ·  Battle.net")
bnRows[1].gameAccountInfo.isOnline=true
event("BN_FRIEND_ACCOUNT_ONLINE",10)
assert(contactRow("bnet:freddy#1111").detail.text:find("Online",1,true))
-- Online alerts are opt-in per contact and do not repeat on ordinary roster updates.
assert(ForeverWhisperDB.onlineNotifyMode=="popup")
ForeverWhisperDB.onlineNotifyMode="chat"
assert(not bnChat.notifyOnline)
bnRows[1].gameAccountInfo.isOnline=false;event("BN_FRIEND_ACCOUNT_OFFLINE",10)
rightClick("bnet:freddy#1111");click("Notify when online")
local noticeCount=#DEFAULT_CHAT_FRAME.lines
bnRows[1].gameAccountInfo.isOnline=true;event("BN_FRIEND_ACCOUNT_ONLINE",10)
assert(#DEFAULT_CHAT_FRAME.lines==noticeCount+1 and DEFAULT_CHAT_FRAME.lines[#DEFAULT_CHAT_FRAME.lines]:find("freddy is now online",1,true))
event("BN_FRIEND_INFO_CHANGED",10)
assert(#DEFAULT_CHAT_FRAME.lines==noticeCount+1,"Online alert repeated without a transition")
rightClick("bnet:freddy#1111");click("Disable online notification")
bnRows[1].gameAccountInfo.isOnline=false;event("BN_FRIEND_ACCOUNT_OFFLINE",10)
bnRows[1].gameAccountInfo.isOnline=true;event("BN_FRIEND_ACCOUNT_ONLINE",10)
assert(#DEFAULT_CHAT_FRAME.lines==noticeCount+1,"Disabled contact still notified")
ForeverWhisperDB.onlineNotifyMode="popup"
rightClick("bnet:freddy#1111");click("Nickname / private note...")
ForeverWhisperContactDetails.nickname:SetText("Raid Buddy")
ForeverWhisperContactDetails.note:SetText("Tuesday healer")
click("Save details")
assert(bnChat.name=="freddy" and bnChat.nickname=="Raid Buddy" and bnChat.note=="Tuesday healer")
assert(ForeverWhisperWindow.heading.text=="Raid Buddy")
ForeverWhisperWindow.contactFilter:SetText("Tuesday")
assert(contactRow("bnet:freddy#1111").name.text=="Raid Buddy","Private note was not searchable")
ForeverWhisperWindow.contactFilter:SetText("")
rightClick("bnet:freddy#1111");click("Nickname / private note...")
ForeverWhisperContactDetails.nickname:SetText("");click("Save details")
assert(bnChat.kind=="bnet" and not ForeverWhisperDB.conversations["freddy#1111"])
assert(bnChat.name=="freddy" and bnChat.battleTag=="freddy#1111")
assert(log.rows[#log.lines].reply.width==48, "Reply target must be readable and clickable")
local charCount=#sent
composer:SetText("BNet reply");click("Send")
assert(#sent==charCount and bnSent[#bnSent].id==10 and bnSent[#bnSent].text=="BNet reply")
bnEvent("CHAT_MSG_BN_WHISPER","Other friend, same display name",20)
assert(ForeverWhisperDB.conversations["bnet:freddy#2222"] and #bnChat.messages==1)
assert(filters.CHAT_MSG_BN_WHISPER(nil,"CHAT_MSG_BN_WHISPER",unpack(bnArgs("test",10),1,13))==true)
assert(filters.CHAT_MSG_BN_WHISPER(nil,"CHAT_MSG_BN_WHISPER",unpack(bnArgs("unknown",999),1,13))==false)
composer:SetText("Typing on BNet")
local beforeBNType=#addonSent
composer.scripts.OnTextChanged(composer,true)
assert(#addonSent==beforeBNType,"Character addon protocol was sent to a BattleTag")
SlashCmdList.FOREVERWHISPER("freddy#2222")
assert(ForeverWhisperWindow.inviteButton.enabled==false and ForeverWhisperWindow.ignoreButton.enabled==false)
SlashCmdList.FOREVERWHISPER("freddy#1111")
click("Invite");assert(bnInvited==110)
-- Reused account IDs cannot redirect a reply to another BattleTag.
bnRows[1]={bnetAccountID=30,battleTag="freddy#1111",accountName="freddy",gameAccountInfo={isOnline=true,clientProgram="WoW",gameAccountID=330}}
bnRows[3]={bnetAccountID=10,battleTag="SomeoneElse#3333",gameAccountInfo={isOnline=true}}
composer:SetText("After reconnect");click("Send")
assert(bnSent[#bnSent].id==30 and bnSent[#bnSent].text=="After reconnect")
assert(#sent==charCount)
-- Failed API calls/disconnects preserve drafts and never fall back to character whispers.
C_BattleNet.SendWhisper=function() return false end
composer:SetText("Keep this draft");composer.scripts.OnEnterPressed(composer)
assert(composer:GetText()=="Keep this draft" and #sent==charCount)
bnOnline=false;event("BN_DISCONNECTED")
composer.scripts.OnEnterPressed(composer)
assert(composer:GetText()=="Keep this draft" and ForeverWhisperWindow.presence.text=="Offline (Battle.net)")
bnOnline=true;event("BN_CONNECTED")
C_BattleNet.SendWhisper=nil
BNSendWhisper=function(id,text) bnSent[#bnSent+1]={id=id,text=text} end
click("Send");assert(bnSent[#bnSent].id==30 and composer:GetText()=="")
combat=true;event("PLAYER_REGEN_DISABLED")
bnEvent("CHAT_MSG_BN_WHISPER","BNet in combat",30)
assert(not ForeverWhisperWindow:IsShown() and ForeverWhisperCombatPreview:IsShown())
assert(not ForeverWhisperCombatPreview.title.text:find("#",1,true))
assert(filters.CHAT_MSG_BN_WHISPER(nil,"CHAT_MSG_BN_WHISPER",unpack(bnArgs("combat",30),1,13))==false)
combat=false;event("PLAYER_REGEN_ENABLED")
assert(ForeverWhisperWindow.heading.text=="freddy")
event("CHAT_MSG_WHISPER","Character with similar name","freddy")
assert(ForeverWhisperDB.conversations.freddy.kind~="bnet")
assert(ForeverWhisperDB.conversations["bnet:freddy#1111"]==bnChat)
-- Resizing starts at the current size, follows scaled deltas, and never snaps on release.
local win=ForeverWhisperWindow
UIParent:SetSize(1920,1080)
win:SetSize(900,600)
win.GetEffectiveScale=function() return 1.25 end
win.GetLeft=function() return 120 end
win.GetTop=function() return 650 end
win.GetCenter=function(self) return 120+self:GetWidth()/2,650-self:GetHeight()/2 end
local cursorX,cursorY=1100,400
function GetCursorPosition() return cursorX,cursorY end
win.resizeGrip.scripts.OnMouseDown(win.resizeGrip,"LeftButton")
assert(win:GetWidth()==900 and win:GetHeight()==600,"Resize jumped on mouse-down")
win.resizeGrip.scripts.OnUpdate()
assert(win:GetWidth()==900 and win:GetHeight()==600,"Stationary cursor resized the window")
cursorX,cursorY=1153,373
win.resizeGrip.scripts.OnUpdate()
assert(math.abs(win:GetWidth()-942.4)<0.001 and math.abs(win:GetHeight()-621.6)<0.001)
win.resizeGrip.scripts.OnMouseUp()
assert(math.abs(win:GetWidth()-942.4)<0.001 and math.abs(win:GetHeight()-621.6)<0.001,
    "Settings sliders snapped dimensions after resizing")
assert(not win.resizeGrip.scripts.OnUpdate,"Resize polling continued after release")
assert(math.abs(ForeverWhisperDB.x-(120+942.4/2-400/1.25))<0.001,
    "Saved position mixed top-left offsets with center offsets")
-- Dragging the frame or its title preserves the grab offset at non-default scale.
win.GetCenter=function(self)
    local _,_,_,left,top=self:GetPoint()
    return left+self:GetWidth()/2,top-self:GetHeight()/2
end
cursorX,cursorY=1000,800
win.scripts.OnDragStart(win)
local _,_,_,dragLeft,dragTop=win:GetPoint()
assert(dragLeft==120 and dragTop==650,"Window jumped at drag start")
win.scripts.OnUpdate(win)
local _,_,_,stillLeft,stillTop=win:GetPoint()
assert(stillLeft==120 and stillTop==650,"Stationary cursor moved the window")
cursorX,cursorY=1037.5,775
win.scripts.OnUpdate(win)
local _,_,_,movedLeft,movedTop=win:GetPoint()
assert(movedLeft==150 and movedTop==630,"Drag did not respect UI scale/grab offset")
cursorX,cursorY=1000,800;win.scripts.OnUpdate(win)
local _,_,_,returnedLeft,returnedTop=win:GetPoint()
assert(returnedLeft==120 and returnedTop==650,"Returning cursor did not restore original position")
win.scripts.OnDragStop(win)
assert(not win.scripts.OnUpdate and not win.cursorDragging)
win.nameTarget.scripts.OnDragStart()
assert(win.cursorDragging,"Title bar did not use the same drag behavior")
win.nameTarget.scripts.OnDragStop()
assert(not win.scripts.OnUpdate)
win.nameTarget.scripts.OnDragStart()
win:Hide()
assert(not win.cursorDragging and not win.scripts.OnUpdate,"Hidden window kept dragging")
win.GetEffectiveScale,win.GetLeft,win.GetTop,win.GetCenter=nil,nil,nil,nil
GetCursorPosition=nil
-- Deleting an active conversation removes only that contact and discards its draft.
SlashCmdList.FOREVERWHISPER("DeleteMe")
event("CHAT_MSG_WHISPER","Delete this history","DeleteMe")
local copiedMessage=ForeverWhisperDB.conversations.deleteme.messages[1].text
log.rows[#log.lines].body.scripts.OnMouseDown(nil,"RightButton")
click("Copy text")
assert(find("EditBox",copiedMessage),"Copy text copied the whole conversation instead of one message")
click("Close")
event("CHAT_MSG_WHISPER",string.rep("Long message ",20),"DeleteMe")
log.rows[#log.lines].reply.scripts.OnClick()
composer:SetText("Short answer");click("Send")
assert(sent[#sent].text:find("^%[Reply to: .-%.%.%.%] Short answer$") and #sent[#sent].text<90,
    "Long quoted message was not shortened")
log.rows[#log.lines].reply.scripts.OnClick()
composer:SetText("Deleted draft")
rightClick("DeleteMe");click("Delete conversation...")
assert(popup.which=="FOREVERWHISPER_DELETE" and popup.data=="deleteme")
assert(ForeverWhisperDB.conversations.deleteme,"Conversation deleted before confirmation")
StaticPopupDialogs.FOREVERWHISPER_DELETE.OnAccept(nil,popup.data)
assert(not ForeverWhisperDB.conversations.deleteme and composer:GetText()=="")
assert(not win.replyBar:IsShown() and ForeverWhisperDB.conversations["bnet:freddy#1111"]==bnChat)
event("CHAT_MSG_WHISPER","New conversation","DeleteMe")
SlashCmdList.FOREVERWHISPER("DeleteMe")
assert(#ForeverWhisperDB.conversations.deleteme.messages==1 and composer:GetText()=="")
assert(not win.replyBar:IsShown(),"Deleted quote draft came back")
StaticPopupDialogs.FOREVERWHISPER_DELETE.OnAccept(nil,"bnet:freddy#1111")
assert(not ForeverWhisperDB.conversations["bnet:freddy#1111"] and ForeverWhisperDB.conversations.deleteme)
-- Combat popup geometry is independent, saved, and editable without auto-dismissal.
local toast=ForeverWhisperCombatPreview
SlashCmdList.FOREVERWHISPER("popup reset")
assert(toast:IsShown() and toast.editing and not toast.timer)
assert(toast:GetWidth()==320 and toast:GetHeight()==92)
toast.GetLeft=function() return 80 end
toast.GetTop=function() return 800 end
toast.GetCenter=function(self) return 80+self:GetWidth()/2,800-self:GetHeight()/2 end
local px,py=400,300
function GetCursorPosition() return px,py end
combat=true
toast:ShowWhisper("Alice","Adjust during combat")
local expiring=timers[#timers]
toast.resizeGrip.scripts.OnMouseDown(toast.resizeGrip,"LeftButton")
expiring();assert(toast:IsShown(),"Popup expired while resizing")
toast.resizeGrip.scripts.OnUpdate()
assert(toast:GetWidth()==320 and toast:GetHeight()==92,"Popup jumped on resize start")
px,py=480,180
toast.resizeGrip.scripts.OnUpdate()
toast.resizeGrip.scripts.OnMouseUp()
assert(toast:GetWidth()==400 and toast:GetHeight()==212)
assert(ForeverWhisperDB.popupWidth==400 and ForeverWhisperDB.popupHeight==212)
assert(type(ForeverWhisperDB.popupX)=="number" and not toast.resizeGrip.scripts.OnUpdate)
local beforeMove=timers[#timers]
toast.scripts.OnDragStart(toast)
beforeMove();assert(toast:IsShown(),"Popup expired while moving")
toast.scripts.OnDragStop(toast)
timers[#timers]();assert(not toast:IsShown(),"Dismissal did not resume after moving")
combat=false
toast.GetLeft,toast.GetTop,toast.GetCenter=nil,nil,nil
GetCursorPosition=nil
SlashCmdList.FOREVERWHISPER("popup reset")
assert(not ForeverWhisperDB.popupX and not ForeverWhisperDB.popupWidth and toast:GetWidth()==320)
toast:Hide()
-- New-message dividers preserve real message indices and survive ordinary refreshes.
SlashCmdList.FOREVERWHISPER("UnreadCase")
log:SetSize(420,100)
for i=1,12 do event("CHAT_MSG_WHISPER_INFORM","Older "..i,"UnreadCase") end
combat=true;event("PLAYER_REGEN_DISABLED")
event("CHAT_MSG_WHISPER","First pending","UnreadCase")
event("CHAT_MSG_WHISPER_INFORM","Outgoing between pending messages","UnreadCase")
event("CHAT_MSG_WHISPER","Second pending","UnreadCase")
event("CHAT_MSG_WHISPER","Third pending","UnreadCase")
local pending=ForeverWhisperDB.conversations.unreadcase
assert(pending.unread==3)
combat=false;event("PLAYER_REGEN_ENABLED")
SlashCmdList.FOREVERWHISPER("UnreadCase")
local firstPending=#pending.messages-3
assert(log.dividers[firstPending] and not log.dividers[firstPending+1],"Divider did not precede first unread incoming message")
assert(#log.lines==#pending.messages,"Divider shifted reply/search message indices")
assert(log.rows[firstPending].divider:IsShown() and log.rows[firstPending].divider.label.text=="New messages")
assert(math.abs(log:GetVerticalScroll()-log.rows[firstPending].top)<0.001,
    "Opening unread conversation skipped the first unread message")
log.offset=3;log:SetVerticalScroll(20)
event("CHAT_MSG_WHISPER","While reading older messages","UnreadCase")
assert(pending.unread==1 and log:GetVerticalScroll()==20,"Incoming message moved the reader or was prematurely marked read")
local dividerCount=0
for _, value in ipairs(log.dividers) do if value then dividerCount=dividerCount+1 end end
assert(dividerCount==1,"Refresh duplicated the new-messages divider")
click("Latest messages");assert(pending.unread==0)
SlashCmdList.FOREVERWHISPER("Alice");SlashCmdList.FOREVERWHISPER("UnreadCase")
for _,value in ipairs(log.dividers) do assert(not value,"Read conversation retained an old-session divider") end
-- Muting blocks notifications and automatic opening, while preserving history and unread counts.
rightClick("UnreadCase");click("Mute notifications")
win:Hide()
event("CHAT_MSG_WHISPER","Muted message","UnreadCase")
assert(not win:IsShown() and pending.unread==1 and pending.messages[#pending.messages].text=="Muted message")
combat=true;event("PLAYER_REGEN_DISABLED")
event("CHAT_MSG_WHISPER","Muted combat message","UnreadCase")
assert(not toast:IsShown())
combat=false;event("PLAYER_REGEN_ENABLED")
assert(not win:IsShown(),"Muted combat message reopened the main window")
SlashCmdList.FOREVERWHISPER("UnreadCase")
rightClick("UnreadCase");click("Unmute notifications")
-- Popup options apply font, duration, message privacy, and movement lock immediately.
click("Settings");click("Popup options")
local opts=ForeverWhisperPopupOptions
opts.durationSlider:SetValue(12);opts.fontSlider:SetValue(17)
toast:ShowWhisper("Alice","Hidden preview text")
assert(toast.timer.delay==12 and toast.preview.fontSize==17)
opts.nameOnly:SetChecked(true);opts.nameOnly.scripts.OnClick(opts.nameOnly)
assert(not toast.preview:IsShown() and toast.title:IsShown())
opts.locked:SetChecked(true);opts.locked.scripts.OnClick(opts.locked)
toast.scripts.OnDragStart(toast)
toast.resizeGrip.scripts.OnMouseDown(toast.resizeGrip,"LeftButton")
assert(not toast.moving and not toast.resizing and not toast.resizeGrip:IsShown())
opts.nameOnly:SetChecked(false);opts.nameOnly.scripts.OnClick(opts.nameOnly)
opts.locked:SetChecked(false);opts.locked.scripts.OnClick(opts.locked)
click("Done");toast:Hide();click("Back")
-- Sorting cycles without changing contacts or losing their pinned status.
local function sidebarKeys()
    local keys={}
    for _,o in ipairs(objects) do if o.statusDot and o.key and o:IsShown() then keys[#keys+1]=o.key end end
    return keys
end
win.contactCount.scripts.OnClick()
selectDropdown("name")
assert(ForeverWhisperDB.contactSort=="name")
local keys=sidebarKeys()
local previousName
for _,key in ipairs(keys) do
    local c=ForeverWhisperDB.conversations[key]
    if not c.pinned then
        local name=(c.nickname or c.name):lower()
        assert(not previousName or previousName<=name,"Alphabetic sort is unstable")
        previousName=name
    end
end
win.contactCount.scripts.OnClick();selectDropdown("online");assert(ForeverWhisperDB.contactSort=="online")
win.contactCount.scripts.OnClick();selectDropdown("recent");assert(ForeverWhisperDB.contactSort=="recent")
-- Online popups share geometry but never replace a whisper or create fake chat history.
local alice=ForeverWhisperDB.conversations.alice
alice.notifyOnline,alice.muted=true,nil
friendRows[1].connected=false;event("FRIENDLIST_UPDATE")
ForeverWhisperDB.onlineNotifyMode="popup"
toast:Reset()
toast:ShowWhisper("Whisper first","Do not replace this")
local onlineHistory,onlineUnread=#alice.messages,alice.unread
local onlineChatCount=#DEFAULT_CHAT_FRAME.lines
friendRows[1].connected=true;event("FRIENDLIST_UPDATE")
assert(toast.kind=="whisper" and toast.title.text=="Whisper first" and #toast.onlineQueue==1)
assert(#alice.messages==onlineHistory and alice.unread==onlineUnread,"Online alert created a fake message/unread badge")
assert(#DEFAULT_CHAT_FRAME.lines==onlineChatCount,"Popup-only mode also printed to chat")
timers[#timers]();timers[#timers]()
assert(toast.kind=="online" and toast.title.text=="Alice is now online")
assert(not toast.preview:IsShown() and toast.icon.texture:find("StatusIcon-Online",1,true))
toast:ShowWhisper("Actual whisper","Has priority")
assert(toast.kind=="whisper" and toast.title.text=="Actual whisper" and toast.count==1)
friendRows[1].connected=false;event("FRIENDLIST_UPDATE")
friendRows[1].connected=true;event("FRIENDLIST_UPDATE")
assert(#toast.onlineQueue==1)
alice.notifyOnline=nil
timers[#timers]();timers[#timers]()
assert(not toast:IsShown(),"Disabled contact's queued alert was still displayed")
alice.notifyOnline=true
ForeverWhisperDB.onlineNotifyMode="both"
friendRows[1].connected=false;event("FRIENDLIST_UPDATE")
friendRows[1].connected=true;event("FRIENDLIST_UPDATE")
assert(toast.kind=="online" and #DEFAULT_CHAT_FRAME.lines==onlineChatCount+1)
toast:Reset()
alice.muted=true
friendRows[1].connected=false;event("FRIENDLIST_UPDATE")
friendRows[1].connected=true;event("FRIENDLIST_UPDATE")
assert(not toast:IsShown() and #DEFAULT_CHAT_FRAME.lines==onlineChatCount+1)
alice.notifyOnline,alice.muted=nil,nil
ForeverWhisperDB.onlineNotifyMode="popup"
-- URL display/copy stays local and never changes what is sent or saved.
SlashCmdList.FOREVERWHISPER("LinkTester")
local imageURL="https://i.imgur.com/JBkdqbz.png"
local linkedText=imageURL.." Look at this chad"
composer:SetText(linkedText);click("Send")
assert(sent[#sent].text==linkedText,"URL markup leaked into the sent whisper")
event("CHAT_MSG_WHISPER_INFORM",linkedText,"LinkTester")
local urlLink=log.lines[#log.lines]:match("|H(fwurl:[^|]+)|h")
assert(urlLink and ForeverWhisperDB.conversations.linktester.messages[1].text==linkedText)
log.onHyperlinkClick(log,urlLink,imageURL,"LeftButton")
assert(find("EditBox",imageURL).focus,"Clicking URL did not focus its copy field")
assert(ForeverWhisperWindow.urlCopy:GetHeight()==60 and not ForeverWhisperCopyWindow:IsShown(),
    "Link copying opened the oversized history window")
click("Close")
composer:SetText("Keep this unfinished draft")
log.onHyperlinkClick(log,urlLink,imageURL,"RightButton")
assert(find("EditBox",imageURL).focus and composer:GetText()=="Keep this unfinished draft")
ForeverWhisperWindow.urlCopy.box.scripts.OnEscapePressed()
assert(not ForeverWhisperWindow.urlCopy:IsShown() and composer:GetText()=="Keep this unfinished draft")
assert(not composer.focus and not ForeverWhisperWindow.urlCopy.box.focus,"Closing link copy stole movement keys")
log.onHyperlinkClick(log,urlLink,imageURL,"RightButton")
function IsControlKeyDown() return true end
ForeverWhisperWindow.urlCopy.box.scripts.OnKeyDown(ForeverWhisperWindow.urlCopy.box,"C")
ForeverWhisperWindow.urlCopy.box.scripts.OnKeyUp(ForeverWhisperWindow.urlCopy.box,"C")
assert(not ForeverWhisperWindow.urlCopy:IsShown() and not composer.focus and not ForeverWhisperWindow.urlCopy.box.focus,
    "Ctrl+C did not release keyboard focus after the copy keystroke")
IsControlKeyDown=nil
log.rows[#log.lines].body.scripts.OnMouseDown(nil,"RightButton");click("Copy link")
find("EditBox",imageURL);click("Close")
event("CHAT_MSG_WHISPER","See https://example.com/a?x=1&y=2 and www.example.org/test.","LinkTester")
log.rows[#log.lines].body.scripts.OnMouseDown(nil,"RightButton");click("Copy links")
find("EditBox","https://example.com/a?x=1&y=2\nwww.example.org/test");click("Close")
event("CHAT_MSG_WHISPER","[Reply to: old excerpt] "..imageURL,"LinkTester")
log.rows[#log.lines].body.scripts.OnMouseDown(nil,"RightButton");click("Copy link")
find("EditBox",imageURL);click("Close")
-- Clicking outside releases only this addon's fields, without discarding drafts.
composer:SetText("Keep movement draft");composer:SetFocus()
function GetMouseFoci() return {composer} end
event("GLOBAL_MOUSE_DOWN","LeftButton")
assert(composer.focus,"Click inside an edit box lost focus")
GetMouseFoci=function() return {UIParent} end
event("GLOBAL_MOUSE_DOWN","LeftButton")
assert(not composer.focus and composer:GetText()=="Keep movement draft")
event("CHAT_MSG_WHISPER","Incoming should not focus typing","LinkTester")
assert(not composer.focus,"Incoming whisper stole movement keys")
local foreign=CreateFrame("EditBox",nil,UIParent);foreign:SetFocus()
event("GLOBAL_MOUSE_DOWN","LeftButton")
assert(foreign.focus,"Outside click changed another addon's keyboard field")
foreign:ClearFocus();GetMouseFoci=nil
-- Sound preview is explicit; alerts obey global sound and contact mute settings.
click("Settings");click("Sound / language")
local general=ForeverWhisperGeneralOptions
local playedSounds={}
function PlaySound(id) playedSounds[#playedSounds+1]=id;return true end
general.soundChoice.scripts.OnClick()
selectDropdown(2)
click("Listen")
assert(playedSounds[#playedSounds]==8960 and not ForeverWhisperDB.sound)
local playedFiles={}
function PlaySoundFile(file) playedFiles[#playedFiles+1]=file;return true,99 end
general.soundChoice.scripts.OnClick()
local soundMenu=ForeverWhisperDropdown
assert(soundMenu.search:IsShown() and not soundMenu.search.focus)
soundMenu.search:SetText("gong")
assert(soundMenu.rows[1].entry.value==7)
soundMenu.rows[1].preview.scripts.OnClick(soundMenu.rows[1].preview)
assert(playedFiles[#playedFiles]==565564 and ForeverWhisperDB.soundChoice==2,"Sound preview changed saved selection")
soundMenu.search:SetText("")
soundMenu.scripts.OnMouseWheel(soundMenu,-0.25)
assert(soundMenu.offset==3 and soundMenu.rows[1].entry,"Fractional wheel delta broke the sound list")
GetMouseFoci=function() return {UIParent} end
event("GLOBAL_MOUSE_DOWN","LeftButton")
assert(not soundMenu:IsShown() and ForeverWhisperDB.soundChoice==2)
GetMouseFoci=nil
local media={HashTable=function() return {["Hey!"]="Interface/AddOns/SoundPack/Hey.ogg"} end,
    Fetch=function(_,kind,name) if name=="Hey!" then return "Interface/AddOns/SoundPack/Hey.ogg" end end}
function LibStub() return media end
general.soundChoice.scripts.OnClick();selectDropdown("lsm:Hey!")
click("Listen")
assert(playedFiles[#playedFiles]=="Interface/AddOns/SoundPack/Hey.ogg")
LibStub=nil
general.soundChoice.scripts.OnClick();selectDropdown(2)
click("Done");click("Back")
ForeverWhisperDB.sound=true
event("CHAT_MSG_WHISPER","Selected sound","SoundTester")
assert(playedSounds[#playedSounds]==8960)
local soundCount=#playedSounds
ForeverWhisperDB.conversations.soundtester.muted=true
event("CHAT_MSG_WHISPER","Muted sound","SoundTester")
assert(#playedSounds==soundCount)
ForeverWhisperDB.sound=false;ForeverWhisperDB.soundChoice=1
-- No idle per-frame handlers; minimap drag adds one only during dragging.
for _,o in ipairs(objects) do assert(not o.scripts.OnUpdate,"Unexpected idle polling") end
''')
catalogue = source.split("-- BEGIN BUNDLED EMOJI", 1)[1].split("-- END BUNDLED EMOJI", 1)[0]
lua.execute(r'''
local ns=...
local function identity(text) return text end
local text,urls=ns.URLs("(https://example.com/a_(b)). www.example.org/path,",identity)
assert(#urls==2 and urls[1]=="https://example.com/a_(b)" and urls[2]=="www.example.org/path")
local native="|Hitem:123|h[Gear https://example.com/not-a-web-link]|h |TInterface/path.tga:16|t"
local rendered,found=ns.URLs(native,identity)
assert(rendered==native and #found==0,"Native item links/textures were rewritten")
local unicode="https://example.com/caf"..string.char(195,169).."?a=1&b=2"
local display=ns.URLs(unicode,identity)
local encoded=display:match("|Hfwurl:([^|]+)|h")
assert(ns.DecodeURL(encoded)==unicode,"URL bytes/query string did not round-trip")
assert(not ns.DecodeURL("zz") and not ns.DecodeURL("a") and not ns.DecodeURL("6a6176617363726970743a616c657274283129"))
''',ns)
lua.execute(r'''
local ns=...
local saved={
    short={name="Tester",last=2,pinned=true,unread=1,note="Keep metadata",messages={{text="second",at=2,outgoing=true}}},
    full={name="Tester-TestRealm",last=3,unread=2,messages={{text="first",at=1,outgoing=false}}},
    foreign={name="Tester-OtherRealm",last=1,messages={{text="different realm",at=1}}},
    spaced={name="Alpha Beta",last=1,messages={}},
    joined={name="AlphaBeta",last=1,messages={}},
    bnet={kind="bnet",battleTag="Tester#1234",name="Tester#1234",last=1,messages={}},
}
local merged=ns.CanonicalConversations(saved)
assert(merged.tester and #merged.tester.messages==2)
assert(merged.tester.messages[1].text=="first" and merged.tester.messages[2].text=="second")
assert(merged.tester.unread==3 and merged.tester.pinned and merged.tester.note=="Keep metadata")
assert(merged.tester.name=="Tester" and merged["tester-otherrealm"])
assert(merged["alpha beta"] and merged.alphabeta,"Distinct spaced names were merged")
assert(merged["bnet:tester#1234"] and not merged["tester#1234"],"Battle.net identity lost its namespace")
assert(merged["bnet:tester#1234"].name=="Tester" and merged["bnet:tester#1234"].battleTag=="Tester#1234")
assert(ns.BNetDisplayMessage("[Reply to Tester#1234: old message] hello")=="[Reply to: old message] hello")
assert(#saved.short.messages==1 and #saved.full.messages==1,"Source histories mutated")
local again=ns.CanonicalConversations(merged)
assert(#again.tester.messages==2 and again.tester.unread==3,"Migration duplicated history")
''',ns)
assets = re.findall(r'\{\s*"[^"]+",\s*"([^"]+)"', catalogue)
assert len(assets) == 103
for asset in assets:
    assert (ROOT / "Emoji" / (asset + ".png")).exists()
from PIL import Image
for name in ("Sakura", "Frost", "Doom", "Forest", "Celestial", "Iron"):
    im=Image.open(ROOT / "UI" / (name+"Corner.tga"))
    assert im.size==(512,512) and im.mode=="RGBA" and im.getextrema()[3][0]==0
    atmosphere=Image.open(ROOT / "UI" / (name+"Atmosphere.tga"))
    assert atmosphere.size==(1024,1024) and atmosphere.mode=="RGBA"
    assert atmosphere.getextrema()[3][0]==0
print("PASS: left/right bubbles, pooled reflow, combat previews/expiry/toggle, and combat fallback.")
print("PASS: native-script validation, complete startup/minimap, and lossless same-realm contact merging.")
print("PASS: BNet capture/send, stable identities, same-name friends, reconnected IDs, drafts on failure, combat and legacy send.")
print("PASS: reply arrows/quotes, per-contact quote drafts, wire limit, native presence, and negotiated/throttled typing.")
print("PASS: theme preview, brightness independent of opacity, pooled artwork controls, and sender labels.")
print("PASS: Lua 5.1 load, drafts, unread routing, send target, emoji aliases/picker/recent,")
print("      search, scroll preservation, confirmations, combat fallback, and no idle polling.")
print("PASS: context recipients, native report menu/fallback, name copying, custom shortcuts,")
print("      header/transcript right-clicks, artwork toggles, and shape/default-shortcut removal.")
print("PASS: map-pin drafts, native waypoint preservation, active-pin sharing, Classic marker,")
print("      map changes, invalid/missing coordinates, and no automatic location messages.")

# Exercise real startup for both Spanish clients and both manual language overrides.
for game_locale, choice, spanish in (
    ("esES", "auto", True), ("esMX", "auto", True),
    ("enUS", "es", True), ("esES", "en", False), ("deDE", "auto", False),
):
    vm = LuaRuntime(unpack_returned_tuples=True)
    vm.execute(WOW_MOCK)
    vm.execute(r'''
        local locale, choice = ...
        function GetLocale() return locale end
        function ReloadUI() requestedReload=true end
        ForeverWhisperDB.language = choice
        ForeverWhisperDB.conversations.keep = {name="EnglishName",nickname="Settings",note="Search",last=1,
            messages={{text="Send Online Settings",at=1,outgoing=false}}}
    ''', game_locale, choice)
    locale_ns = vm.table()
    for module in ("Localization.lua", "MessengerUI.lua", "Social.lua", "BattleNet.lua", "ForeverWhisper.lua"):
        vm.execute((ROOT / module).read_text(encoding="utf-8"), "ForeverWhisper", locale_ns)
    vm.execute(r'''
        local spanish = ...
        event("ADDON_LOADED","ForeverWhisper")
        SlashCmdList.FOREVERWHISPER("EnglishName")
        local win=ForeverWhisperWindow
        assert(win.sendButton.text==(spanish and "Enviar" or "Send"))
        assert(win.settingsButton.text==(spanish and "Ajustes" or "Settings"))
        assert(win.transcript.rows[1].reply:GetWidth()==(spanish and 70 or 48))
        assert(win.heading.text=="Settings","Nickname was translated as UI text")
        local c=ForeverWhisperDB.conversations.englishname
        assert(c.name=="EnglishName" and c.note=="Search" and c.messages[1].text=="Send Online Settings")
        assert(not visibleInput().focus,"Opening a conversation stole keyboard focus")
        assert(StaticPopupDialogs.FOREVERWHISPER_CLEAR.text==(spanish and "¿Vaciar el historial con %s?" or "Clear saved chat history with %s?"))
        SlashCmdList.FOREVERWHISPER("settings")
        click(spanish and "Sonido / idioma" or "Sound / language")
        local panel=ForeverWhisperGeneralOptions
        assert(panel:IsShown())
        local oldChoice=ForeverWhisperDB.language
        panel.languageChoice.scripts.OnClick()
        selectDropdown(oldChoice=="auto" and "es" or (oldChoice=="es" and "en" or "auto"))
        assert(ForeverWhisperDB.language~=oldChoice,"Language choice did not persist")
        assert(not requestedReload,"Changing the language forced an unexpected UI reload")
        assert(win.settingsButton.text==(spanish and "Volver" or "Back"),"Language changed before the requested reload")
        click(spanish and "Recargar interfaz" or "Reload UI")
        assert(requestedReload,"Explicit reload button did not apply the player's choice")
        click(spanish and "Listo" or "Done")
    ''', spanish)
print("PASS: esES/esMX automatic locale, manual English/Spanish overrides, dialogs, untouched user text, sound choice, and outside-click focus.")
