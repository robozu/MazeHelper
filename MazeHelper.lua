local ADDON_NAME, MazeHelper = ...;
local L, E, M = MazeHelper.L, MazeHelper.E, MazeHelper.M;
local Version = GetAddOnMetadata(ADDON_NAME, 'Version');

-- Lua API
local tonumber = tonumber;

-- WoW API
local IsInRaid, IsInGroup, GetMinimapZoneText = IsInRaid, IsInGroup, GetMinimapZoneText;

local ADDON_COMM_PREFIX = 'MAZEHELPER';
local ADDON_COMM_MODE   = 'NORMAL';
C_ChatInfo.RegisterAddonMessagePrefix(ADDON_COMM_PREFIX);

local playerNameWithRealm, playerRole, inInstance, inMOTS, bossKilled, inEncounter, isMinimized;
local startedInMinMode = false;

-- NANO-OPTIMIZATIONS!
local EMPTY_STRING = '';
local PLAYER_STRING = 'player';

local MAX_BUTTONS = 8;
local MAX_ACTIVE_BUTTONS = 4;
local NUM_ACTIVE_BUTTONS = 0;

local FRAME_SIZE = 300;
local X_OFFSET = 2;
local Y_OFFSET = -2;
local BUTTON_SIZE = 64;
local SLIDER_FULL_WIDTH = FRAME_SIZE + X_OFFSET * (MAX_ACTIVE_BUTTONS - 1) - 50;

local RESERVED_BUTTONS_SEQUENCE = {
    [1] = false,
    [2] = false,
    [3] = false,
    [4] = false,
};

local nameplatesMarkers = {};

local USED_MARKERS = {
    [1] = false,
    [2] = false,
    [3] = false,
    [4] = false,
    [5] = false,
    [6] = false,
    [7] = false,
    [8] = false,
};

local MARKER_UNITS = {
    'player',
    'party1',
    'party2',
    'party3',
    'party4',
    'boss1',
};

local SOLUTION_PLAYER_MARKER = 4;

local PASSED_COUNTER = 1;
local SOLUTION_BUTTON_ID;
local PREDICTED_SOLUTION_BUTTON_ID;
local ANNOUNCED_BUTTON_ID;

local MOTS_INSTANCE_ID = 2290;
local MISTCALLER_ENCOUNTER_ID = 2392;
local ILLUSIONARY_CLONE_ID = 165108;
local DEPLETED_ANIMA_SEED_IDS = {
    [173702] = true,
    [357703] = true,
    [357707] = true,
};

local EVENTS_INSTANCE = {
    'ZONE_CHANGED',
    'ZONE_CHANGED_INDOORS',
    'ZONE_CHANGED_NEW_AREA',
    'ENCOUNTER_START',
    'ENCOUNTER_END',
    'BOSS_KILL',
    'GOSSIP_SHOW',
};

local EVENTS_AUTOMARKER = {
    'NAME_PLATE_UNIT_ADDED',
    'NAME_PLATE_UNIT_REMOVED',
};

local buttons = {}
local buttonsData = {
    [1] = {
        name = L['LEAF_FULL_CIRCLE'],
        ename = L['ENGLISH_LEAF_FULL_CIRCLE'],
        coords = M.Symbols.COORDS_COLOR.LEAF_CIRCLE_FILL,
        coords_white = M.Symbols.COORDS_WHITE.LEAF_CIRCLE_FILL,
        leaf = true,
        flower = false,
        circle = true,
        fill = true,
    },
    [2] = {
        name = L['LEAF_NOFULL_CIRCLE'],
        ename = L['ENGLISH_LEAF_NOFULL_CIRCLE'],
        coords = M.Symbols.COORDS_COLOR.LEAF_CIRCLE_NOFILL,
        coords_white = M.Symbols.COORDS_WHITE.LEAF_CIRCLE_NOFILL,
        leaf = true,
        flower = false,
        circle = true,
        fill = false,
    },
    [3] = {
        name = L['FLOWER_FULL_CIRCLE'],
        ename = L['ENGLISH_FLOWER_FULL_CIRCLE'],
        coords = M.Symbols.COORDS_COLOR.FLOWER_CIRCLE_FILL,
        coords_white = M.Symbols.COORDS_WHITE.FLOWER_CIRCLE_FILL,
        leaf = false,
        flower = true,
        circle = true,
        fill = true,
    },
    [4] = {
        name = L['FLOWER_NOFULL_CIRCLE'],
        ename = L['ENGLISH_FLOWER_NOFULL_CIRCLE'],
        coords = M.Symbols.COORDS_COLOR.FLOWER_CIRCLE_NOFILL,
        coords_white = M.Symbols.COORDS_WHITE.FLOWER_CIRCLE_NOFILL,
        leaf = false,
        flower = true,
        circle = true,
        fill = false,
    },
    [5] = {
        name = L['LEAF_FULL_NOCIRCLE'],
        ename = L['ENGLISH_LEAF_FULL_NOCIRCLE'],
        coords = M.Symbols.COORDS_COLOR.LEAF_NOCIRCLE_FILL,
        coords_white = M.Symbols.COORDS_WHITE.LEAF_NOCIRCLE_FILL,
        leaf = true,
        flower = false,
        circle = false,
        fill = true,
    },
    [6] = {
        name = L['LEAF_NOFULL_NOCIRCLE'],
        ename = L['ENGLISH_LEAF_NOFULL_NOCIRCLE'],
        coords = M.Symbols.COORDS_COLOR.LEAF_NOCIRCLE_NOFILL,
        coords_white = M.Symbols.COORDS_WHITE.LEAF_NOCIRCLE_NOFILL,
        leaf = true,
        flower = false,
        circle = false,
        fill = false,
    },
    [7] = {
        name = L['FLOWER_FULL_NOCIRCLE'],
        ename = L['ENGLISH_FLOWER_FULL_NOCIRCLE'],
        coords = M.Symbols.COORDS_COLOR.FLOWER_NOCIRCLE_FILL,
        coords_white = M.Symbols.COORDS_WHITE.FLOWER_NOCIRCLE_FILL,
        leaf = false,
        flower = true,
        circle = false,
        fill = true,
    },
    [8] = {
        name = L['FLOWER_NOFULL_NOCIRCLE'],
        ename = L['ENGLISH_FLOWER_NOFULL_NOCIRCLE'],
        coords = M.Symbols.COORDS_COLOR.FLOWER_NOCIRCLE_NOFILL,
        coords_white = M.Symbols.COORDS_WHITE.FLOWER_NOCIRCLE_NOFILL,
        leaf = false,
        flower = true,
        circle = false,
        fill = false,
    },
};

MazeHelper.ButtonsData = buttonsData;

local function GetPartyChatType()
    if IsInRaid() then
        return false;
    end

    return IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and 'INSTANCE_CHAT' or (IsInGroup(LE_PARTY_CATEGORY_HOME) and 'PARTY' or false);
end

local function AnnounceInChat(partyChatType)
    if not SOLUTION_BUTTON_ID or not partyChatType then
        return;
    end

    if MHMOTSConfig.AnnounceWithEnglish and MazeHelper.currentLocale ~= 'enUS' then
        SendChatMessage(string.format(L['ANNOUNCE_SOLUTION_WITH_ENGLISH'], buttons[SOLUTION_BUTTON_ID].data.name, buttons[SOLUTION_BUTTON_ID].data.ename), partyChatType);
    else
        SendChatMessage(string.format(L['ANNOUNCE_SOLUTION'], buttons[SOLUTION_BUTTON_ID].data.name), partyChatType);
    end
end

local function BetterOnDragStop(frame, saveTable)
    local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint();

    saveTable[1] = point;
    saveTable[2] = relativeTo
    saveTable[3] = relativePoint;
    saveTable[4] = xOfs;
    saveTable[5] = yOfs;

    frame:StopMovingOrSizing();

    frame:ClearAllPoints();
    PixelUtil.SetPoint(frame, point, UIParent, relativePoint, xOfs, yOfs);
    frame:SetUserPlaced(true);
end

MazeHelper.frame = CreateFrame('Frame', 'ST_Maze_Helper', UIParent);
PixelUtil.SetPoint(MazeHelper.frame, 'CENTER', UIParent, 'CENTER', -FRAME_SIZE, FRAME_SIZE);
PixelUtil.SetSize(MazeHelper.frame, FRAME_SIZE + X_OFFSET * (MAX_ACTIVE_BUTTONS - 1), FRAME_SIZE * 3/4);
MazeHelper.frame:EnableMouse(true);
MazeHelper.frame:SetMovable(true);
MazeHelper.frame:SetClampedToScreen(true);
MazeHelper.frame:SetClampRectInsets(-4, 4, 24, 0);
MazeHelper.frame:RegisterForDrag('LeftButton');
MazeHelper.frame:SetScript('OnDragStart', function(self)
    if self:IsMovable() then
        self:StartMoving();
    end
end);
MazeHelper.frame:SetScript('OnDragStop', function(self)
    BetterOnDragStop(self, MHMOTSConfig.SavedPosition);
end);
E.CreateSmoothShowing(MazeHelper.frame);

-- Background
MazeHelper.frame.background = MazeHelper.frame:CreateTexture(nil, 'BACKGROUND');
PixelUtil.SetPoint(MazeHelper.frame.background, 'TOPLEFT', MazeHelper.frame, 'TOPLEFT', -15, 22);
PixelUtil.SetPoint(MazeHelper.frame.background, 'BOTTOMRIGHT', MazeHelper.frame, 'BOTTOMRIGHT', 15, -98);
MazeHelper.frame.background:SetTexture(M.BACKGROUND_WHITE);
MazeHelper.frame.background:SetVertexColor(0.05, 0.05, 0.05);

-- Close Button
MazeHelper.frame.CloseButton = CreateFrame('Button', nil, MazeHelper.frame);
PixelUtil.SetPoint(MazeHelper.frame.CloseButton, 'TOPRIGHT', MazeHelper.frame, 'TOPRIGHT', -8, -4);
PixelUtil.SetSize(MazeHelper.frame.CloseButton, 12, 12);
MazeHelper.frame.CloseButton:SetNormalTexture(M.Icons.TEXTURE);
MazeHelper.frame.CloseButton:GetNormalTexture():SetTexCoord(unpack(M.Icons.COORDS.CROSS_WHITE));
MazeHelper.frame.CloseButton:GetNormalTexture():SetVertexColor(0.7, 0.7, 0.7, 1);
MazeHelper.frame.CloseButton:SetHighlightTexture(M.Icons.TEXTURE, 'BLEND');
MazeHelper.frame.CloseButton:GetHighlightTexture():SetTexCoord(unpack(M.Icons.COORDS.CROSS_WHITE));
MazeHelper.frame.CloseButton:GetHighlightTexture():SetVertexColor(1, 0.85, 0, 1);
MazeHelper.frame.CloseButton:SetScript('OnClick', function()
    if MazeHelper.frame.Settings:IsShown() then
        MazeHelper.frame.Settings:SetShown(false);
        MazeHelper.frame.SettingsButton:SetShown(true);
        MazeHelper.frame.MainHolder:SetShown(true);
        MazeHelper.frame.MinButton:SetShown(true);

        return;
    end

    MazeHelper.frame:SetShown(false);
end);

-- Settings Button
MazeHelper.frame.SettingsButton = CreateFrame('Button', nil, MazeHelper.frame);
PixelUtil.SetPoint(MazeHelper.frame.SettingsButton, 'RIGHT', MazeHelper.frame.CloseButton, 'LEFT', -8, 0);
PixelUtil.SetSize(MazeHelper.frame.SettingsButton, 14, 14);
MazeHelper.frame.SettingsButton:SetNormalTexture(M.Icons.TEXTURE);
MazeHelper.frame.SettingsButton:GetNormalTexture():SetTexCoord(unpack(M.Icons.COORDS.GEAR_WHITE));
MazeHelper.frame.SettingsButton:GetNormalTexture():SetVertexColor(0.7, 0.7, 0.7, 1);
MazeHelper.frame.SettingsButton:SetHighlightTexture(M.Icons.TEXTURE, 'BLEND');
MazeHelper.frame.SettingsButton:GetHighlightTexture():SetTexCoord(unpack(M.Icons.COORDS.GEAR_WHITE));
MazeHelper.frame.SettingsButton:GetHighlightTexture():SetVertexColor(1, 0.85, 0, 1);
MazeHelper.frame.SettingsButton:SetScript('OnClick', function(self)
    local settingsIsShown = MazeHelper.frame.Settings:IsShown();

    self:SetShown(false);

    MazeHelper.frame.Settings:SetShown(not settingsIsShown);
    MazeHelper.frame.MainHolder:SetShown(settingsIsShown);
    MazeHelper.frame.MinButton:SetShown(settingsIsShown);
end);

-- Minimize Button
MazeHelper.frame.MinButton = CreateFrame('Button', nil, MazeHelper.frame);
PixelUtil.SetPoint(MazeHelper.frame.MinButton, 'RIGHT', MazeHelper.frame.SettingsButton, 'LEFT', -8, 1);
PixelUtil.SetSize(MazeHelper.frame.MinButton, 14, 14);
MazeHelper.frame.MinButton.icon = MazeHelper.frame.MinButton:CreateTexture(nil, 'OVERLAY');
PixelUtil.SetPoint(MazeHelper.frame.MinButton.icon, 'BOTTOM', MazeHelper.frame.MinButton, 'BOTTOM', 0, 0);
PixelUtil.SetSize(MazeHelper.frame.MinButton.icon, 10, 2);
MazeHelper.frame.MinButton.icon:SetTexture('Interface\\Buttons\\WHITE8x8');
MazeHelper.frame.MinButton.icon:SetVertexColor(0.7, 0.7, 0.7, 1);
MazeHelper.frame.MinButton:SetScript('OnClick', function()
    isMinimized = true;

    PixelUtil.SetHeight(MazeHelper.frame, 40);
    for i = 1, MAX_BUTTONS do
        buttons[i]:Hide();
    end

    PixelUtil.SetPoint(MazeHelper.frame.SolutionText, 'LEFT', MazeHelper.frame, 'LEFT', 2, 4);

    MazeHelper.frame.BottomButtonsHolder:SetShown(false);

    PixelUtil.SetPoint(MazeHelper.frame.background, 'TOPLEFT', MazeHelper.frame, 'TOPLEFT', -15, 0);
    PixelUtil.SetPoint(MazeHelper.frame.background, 'BOTTOMRIGHT', MazeHelper.frame, 'BOTTOMRIGHT', 15, 0);

    PixelUtil.SetPoint(MazeHelper.frame.CloseButton, 'TOPRIGHT', MazeHelper.frame, 'TOPRIGHT', -8, -8);

    MazeHelper.frame.PassedCounter:ClearAllPoints();
    PixelUtil.SetPoint(MazeHelper.frame.PassedCounter, 'LEFT', MazeHelper.frame, 'LEFT', -18, 5);
    MazeHelper.frame.PassedCounter:SetScale(1);
    PixelUtil.SetPoint(MazeHelper.frame.PassedCounter.Text, 'CENTER', MazeHelper.frame.PassedCounter, 'CENTER', (PASSED_COUNTER == 1) and -2 or 0, 0);

    if SOLUTION_BUTTON_ID then
        MazeHelper.frame.MiniSolution:SetShown(true);
        MazeHelper.frame.MiniSolution.Icon:SetTexCoord(unpack(MHMOTSConfig.UseColoredSymbols and buttonsData[SOLUTION_BUTTON_ID].coords or buttonsData[SOLUTION_BUTTON_ID].coords_white));
    else
        MazeHelper.frame.MiniSolution:SetShown(false);
    end

    MazeHelper.frame.PassedCounter:SetShown(not MazeHelper.frame.MiniSolution:IsShown());

    MazeHelper.frame.AnnounceButton:SetShown(false);

    MazeHelper.frame.SettingsButton:SetShown(false);

    MazeHelper.frame.InvisibleMaxButton:SetShown(true);

    MazeHelper.frame.MinButton:SetShown(false);

    MazeHelper.frame:SetClampRectInsets(-8, 4, 4, 0);
end);
MazeHelper.frame.MinButton:SetScript('OnEnter', function(self) self.icon:SetVertexColor(1, 0.85, 0, 1); end);
MazeHelper.frame.MinButton:SetScript('OnLeave', function(self) self.icon:SetVertexColor(0.7, 0.7, 0.7, 1); end);

-- Invisible Maximize Button
MazeHelper.frame.InvisibleMaxButton = CreateFrame('Button', nil, MazeHelper.frame);
PixelUtil.SetPoint(MazeHelper.frame.InvisibleMaxButton, 'TOPLEFT', MazeHelper.frame, 'TOPLEFT', 0, 0);
PixelUtil.SetPoint(MazeHelper.frame.InvisibleMaxButton, 'BOTTOMRIGHT', MazeHelper.frame, 'BOTTOMRIGHT', 0, 0);
MazeHelper.frame.InvisibleMaxButton:SetScript('OnClick', function()
    if not isMinimized then
        return;
    end

    isMinimized = false;

    PixelUtil.SetHeight(MazeHelper.frame, FRAME_SIZE * 3/4);
    for i = 1, MAX_BUTTONS do
        buttons[i]:Show();
    end

    PixelUtil.SetPoint(MazeHelper.frame.SolutionText, 'LEFT', MazeHelper.frame, 'LEFT', 2, -54);

    MazeHelper.frame.BottomButtonsHolder:SetShown(true);
    MazeHelper.frame.PassedButton:SetShown(not inEncounter);
    if inEncounter then
        PixelUtil.SetSize(MazeHelper.frame.BottomButtonsHolder, MazeHelper.frame.ResetButton:GetWidth(), 22);
    else
        PixelUtil.SetSize(MazeHelper.frame.BottomButtonsHolder, MazeHelper.frame.ResetButton:GetWidth() + MazeHelper.frame.PassedButton:GetWidth() + 8, 22);
    end

    PixelUtil.SetPoint(MazeHelper.frame.background, 'TOPLEFT', MazeHelper.frame, 'TOPLEFT', -15, 22);
    PixelUtil.SetPoint(MazeHelper.frame.background, 'BOTTOMRIGHT', MazeHelper.frame, 'BOTTOMRIGHT', 15, -98);

    PixelUtil.SetPoint(MazeHelper.frame.CloseButton, 'TOPRIGHT', MazeHelper.frame, 'TOPRIGHT', -8, -4);

    MazeHelper.frame.PassedCounter:ClearAllPoints();
    PixelUtil.SetPoint(MazeHelper.frame.PassedCounter, 'BOTTOM', MazeHelper.frame, 'TOP', 0, -32);
    MazeHelper.frame.PassedCounter:SetScale(1.25);
    PixelUtil.SetPoint(MazeHelper.frame.PassedCounter.Text, 'CENTER', MazeHelper.frame.PassedCounter, 'CENTER', (PASSED_COUNTER == 1) and -2 or 0, -1);
    MazeHelper.frame.PassedCounter:SetShown(true);

    MazeHelper.frame.MiniSolution:SetShown(false);

    MazeHelper.frame.AnnounceButton:SetShown((SOLUTION_BUTTON_ID and not MazeHelper.frame.AnnounceButton.clicked and GetPartyChatType() and not MHMOTSConfig.AutoAnnouncer) and true or false);

    MazeHelper.frame.SettingsButton:SetShown(true);

    MazeHelper.frame.InvisibleMaxButton:SetShown(false);

    MazeHelper.frame.MinButton:SetShown(true);

    MazeHelper.frame:SetClampRectInsets(-4, 4, 24, 0);
end);
MazeHelper.frame.InvisibleMaxButton:RegisterForDrag('LeftButton');
MazeHelper.frame.InvisibleMaxButton:SetScript('OnDragStart', function()
    if MazeHelper.frame:IsMovable() then
        MazeHelper.frame:StartMoving();
    end
end);
MazeHelper.frame.InvisibleMaxButton:SetScript('OnDragStop', function()
    BetterOnDragStop(MazeHelper.frame, MHMOTSConfig.SavedPosition);
end);
MazeHelper.frame.InvisibleMaxButton:SetShown(false);

MazeHelper.frame.MainHolder = CreateFrame('Frame', nil, MazeHelper.frame);
MazeHelper.frame.MainHolder:SetAllPoints();

-- Large Solution Symbol
MazeHelper.frame.LargeSymbol = CreateFrame('Frame', nil, MazeHelper.frame);
PixelUtil.SetPoint(MazeHelper.frame.LargeSymbol, 'TOP', UIParent, 'TOP', 0, -32);
PixelUtil.SetSize(MazeHelper.frame.LargeSymbol, 64, 64)
MazeHelper.frame.LargeSymbol:SetIgnoreParentScale(true);
MazeHelper.frame.LargeSymbol:EnableMouse(true);
MazeHelper.frame.LargeSymbol:SetMovable(true);
MazeHelper.frame.LargeSymbol:SetClampedToScreen(true);
MazeHelper.frame.LargeSymbol:RegisterForDrag('LeftButton');
MazeHelper.frame.LargeSymbol:SetScript('OnDragStart', function(self)
    if self:IsMovable() then
        self:StartMoving();
    end
end);
MazeHelper.frame.LargeSymbol:SetScript('OnDragStop', function(self)
    BetterOnDragStop(self, MHMOTSConfig.SavedPositionLargeSymbol);
end);
MazeHelper.frame.LargeSymbol.Icon = MazeHelper.frame.LargeSymbol:CreateTexture(nil, 'ARTWORK');
MazeHelper.frame.LargeSymbol.Icon:SetAllPoints();
MazeHelper.frame.LargeSymbol.Icon:SetTexture(M.Symbols.TEXTURE);
MazeHelper.frame.LargeSymbol.Background = MazeHelper.frame.LargeSymbol:CreateTexture(nil, 'BACKGROUND');
PixelUtil.SetPoint(MazeHelper.frame.LargeSymbol.Background, 'TOPLEFT', MazeHelper.frame.LargeSymbol, 'TOPLEFT', -64, 64);
PixelUtil.SetPoint(MazeHelper.frame.LargeSymbol.Background, 'BOTTOMRIGHT', MazeHelper.frame.LargeSymbol, 'BOTTOMRIGHT', 64, -64);
MazeHelper.frame.LargeSymbol.Background:SetTexture(M.Rings.TEXTURE);
MazeHelper.frame.LargeSymbol.Background:SetTexCoord(unpack(M.Rings.COORDS.GREEN));
MazeHelper.frame.LargeSymbol:SetShown(false);
MazeHelper.frame.LargeSymbol:HookScript('OnShow', function()
    PlaySoundFile(M.Sounds.Notification, 'SFX');
end);
E.CreateSmoothShowing(MazeHelper.frame.LargeSymbol);
MazeHelper.frame.LargeSymbol.AnimIn:HookScript('OnFinished', function()
    C_Timer.After(0, function()
        MazeHelper.frame.LargeSymbol.Background:SetAlpha(MHMOTSConfig.SavedBackgroundAlphaLargeSymbol);
    end);
end);

-- Solution Text
MazeHelper.frame.SolutionText = MazeHelper.frame.MainHolder:CreateFontString(nil, 'ARTWORK', 'GameFontNormalLarge');
PixelUtil.SetPoint(MazeHelper.frame.SolutionText, 'LEFT', MazeHelper.frame, 'LEFT', 2, -54);
PixelUtil.SetPoint(MazeHelper.frame.SolutionText, 'RIGHT', MazeHelper.frame, 'RIGHT', -2, 0);
MazeHelper.frame.SolutionText:SetShadowColor(0.15, 0.15, 0.15);
MazeHelper.frame.SolutionText:SetText(L['CHOOSE_SYMBOLS_4']);

local function ResetAll()
    NUM_ACTIVE_BUTTONS = 0;
    SOLUTION_BUTTON_ID = nil;
    PREDICTED_SOLUTION_BUTTON_ID = nil;
    ANNOUNCED_BUTTON_ID = nil;

    for i = 1, #RESERVED_BUTTONS_SEQUENCE do
        RESERVED_BUTTONS_SEQUENCE[i] = false;
    end

    for i = 1, MAX_BUTTONS do
        buttons[i]:SetUnactive();
        buttons[i]:ResetSequence();

        buttons[i].state = false;
        buttons[i].sender = nil;
        buttons[i].sequence = nil;
    end

    MazeHelper.frame.SolutionText:SetText(L['CHOOSE_SYMBOLS_4']);
    MazeHelper.frame.PassedButton:SetEnabled(false);
    MazeHelper.frame.AnnounceButton:SetShown(false);
    MazeHelper.frame.AnnounceButton.clicked = false;

    MazeHelper.frame.LargeSymbol:SetShown(false);
    MazeHelper.frame.MiniSolution:SetShown(false);
    MazeHelper.frame.PassedCounter:SetShown(true);

    MazeHelper.frame.ResetButton:SetEnabled(false);

    if MHMOTSConfig.SetMarkerSolutionPlayer then
        if GetRaidTargetIndex(PLAYER_STRING) == SOLUTION_PLAYER_MARKER then
            SetRaidTarget(PLAYER_STRING, 0);
        end
    end
end

MazeHelper.frame.BottomButtonsHolder = CreateFrame('Frame', nil, MazeHelper.frame.MainHolder);
PixelUtil.SetPoint(MazeHelper.frame.BottomButtonsHolder, 'TOP', MazeHelper.frame.SolutionText, 'BOTTOM', 0, -8);
PixelUtil.SetSize(MazeHelper.frame.BottomButtonsHolder, MazeHelper.frame.MainHolder:GetWidth(), 22);

-- Reset Button
MazeHelper.frame.ResetButton = CreateFrame('Button', nil, MazeHelper.frame.BottomButtonsHolder, 'SharedButtonSmallTemplate');
PixelUtil.SetPoint(MazeHelper.frame.ResetButton, 'RIGHT', MazeHelper.frame.BottomButtonsHolder, 'RIGHT', 0, 0);
MazeHelper.frame.ResetButton:SetText(L['RESET']);
PixelUtil.SetSize(MazeHelper.frame.ResetButton, tonumber(MazeHelper.frame.ResetButton:GetTextWidth()) + 20, 22);
MazeHelper.frame.ResetButton:SetScript('OnClick', function()
    if NUM_ACTIVE_BUTTONS == 0 then
        return;
    end

    MazeHelper:SendResetCommand();
    ResetAll();
end);
MazeHelper.frame.ResetButton:SetEnabled(false);

-- Passed Button
MazeHelper.frame.PassedButton = CreateFrame('Button', nil, MazeHelper.frame.BottomButtonsHolder, 'SharedButtonSmallTemplate');
PixelUtil.SetPoint(MazeHelper.frame.PassedButton, 'RIGHT', MazeHelper.frame.ResetButton, 'LEFT', -8, 0);
MazeHelper.frame.PassedButton:SetText(L['PASSED']);
PixelUtil.SetSize(MazeHelper.frame.PassedButton, tonumber(MazeHelper.frame.PassedButton:GetTextWidth()) + 20, 22);
MazeHelper.frame.PassedButton:SetScript('OnClick', function()
    PASSED_COUNTER = PASSED_COUNTER + 1;

    MazeHelper.frame.PassedCounter.Text:SetText(PASSED_COUNTER);
    PixelUtil.SetPoint(MazeHelper.frame.PassedCounter.Text, 'CENTER', MazeHelper.frame.PassedCounter, 'CENTER', (PASSED_COUNTER == 1) and -2 or 0, isMinimized and 0 or -1);

    MazeHelper:SendPassedCommand(PASSED_COUNTER);
    ResetAll();
end);
MazeHelper.frame.PassedButton:SetEnabled(false);

PixelUtil.SetSize(MazeHelper.frame.BottomButtonsHolder, MazeHelper.frame.ResetButton:GetWidth() + MazeHelper.frame.PassedButton:GetWidth() + 8, 22);

-- Passed Counter Text
MazeHelper.frame.PassedCounter = CreateFrame('Frame', nil, MazeHelper.frame.MainHolder);
PixelUtil.SetPoint(MazeHelper.frame.PassedCounter, 'BOTTOM', MazeHelper.frame, 'TOP', 0, -32);
PixelUtil.SetSize(MazeHelper.frame.PassedCounter, 64, 64);
MazeHelper.frame.PassedCounter:SetScale(1.25);
MazeHelper.frame.PassedCounter.Background = MazeHelper.frame.PassedCounter:CreateTexture(nil, 'BACKGROUND');
MazeHelper.frame.PassedCounter.Background:SetAllPoints();
MazeHelper.frame.PassedCounter.Background:SetTexture(M.Rings.TEXTURE);
MazeHelper.frame.PassedCounter.Background:SetTexCoord(unpack(M.Rings.COORDS.BLUE));
MazeHelper.frame.PassedCounter.Text = MazeHelper.frame.PassedCounter:CreateFontString(nil, 'ARTWORK', 'GameFontNormalShadowHuge2');
PixelUtil.SetPoint(MazeHelper.frame.PassedCounter.Text, 'CENTER', MazeHelper.frame.PassedCounter, 'CENTER', -2, -1);
MazeHelper.frame.PassedCounter.Text:SetShadowColor(0.15, 0.15, 0.15);
MazeHelper.frame.PassedCounter.Text:SetText(PASSED_COUNTER);
MazeHelper.frame.PassedCounter.Text:SetJustifyH('CENTER');

-- Mini solution icon
MazeHelper.frame.MiniSolution = CreateFrame('Frame', nil, MazeHelper.frame.MainHolder);
MazeHelper.frame.MiniSolution:SetAllPoints(MazeHelper.frame.PassedCounter);
PixelUtil.SetPoint(MazeHelper.frame.MiniSolution, 'CENTER', MazeHelper.frame.PassedCounter, 'CENTER', 0, 0);
MazeHelper.frame.MiniSolution.Icon = MazeHelper.frame.MiniSolution:CreateTexture(nil, 'OVERLAY');
PixelUtil.SetPoint(MazeHelper.frame.MiniSolution.Icon, 'CENTER', MazeHelper.frame.MiniSolution, 'CENTER', 0, 0);
PixelUtil.SetSize(MazeHelper.frame.MiniSolution.Icon, 40, 40);
MazeHelper.frame.MiniSolution.Icon:SetTexture(M.Symbols.TEXTURE);
MazeHelper.frame.MiniSolution:SetShown(false);

-- Announce Button
MazeHelper.frame.AnnounceButton = CreateFrame('Button', nil, MazeHelper.frame.MainHolder);
PixelUtil.SetPoint(MazeHelper.frame.AnnounceButton, 'TOPLEFT', MazeHelper.frame, 'TOPLEFT', 2, 4);
PixelUtil.SetSize(MazeHelper.frame.AnnounceButton, 18, 18);
MazeHelper.frame.AnnounceButton:SetNormalTexture(M.Icons.TEXTURE);
MazeHelper.frame.AnnounceButton:GetNormalTexture():SetTexCoord(unpack(M.Icons.COORDS.MEGAPHONE_WHITE));
MazeHelper.frame.AnnounceButton:GetNormalTexture():SetVertexColor(1, 0.85, 0, 1);
MazeHelper.frame.AnnounceButton:SetHighlightTexture(M.Icons.TEXTURE, 'BLEND');
MazeHelper.frame.AnnounceButton:GetHighlightTexture():SetTexCoord(unpack(M.Icons.COORDS.MEGAPHONE_WHITE));
MazeHelper.frame.AnnounceButton:GetHighlightTexture():SetVertexColor(1, 1, 0, 1);
MazeHelper.frame.AnnounceButton.Background = MazeHelper.frame.AnnounceButton:CreateTexture(nil, 'BACKGROUND');
PixelUtil.SetPoint(MazeHelper.frame.AnnounceButton.Background, 'TOPLEFT', MazeHelper.frame.AnnounceButton, 'TOPLEFT', -26, 22);
PixelUtil.SetPoint(MazeHelper.frame.AnnounceButton.Background, 'BOTTOMRIGHT', MazeHelper.frame.AnnounceButton, 'BOTTOMRIGHT', 26, -26);
MazeHelper.frame.AnnounceButton.Background:SetTexture(M.Rings.TEXTURE);
MazeHelper.frame.AnnounceButton.Background:SetTexCoord(unpack(M.Rings.COORDS.VIOLET));
MazeHelper.frame.AnnounceButton:SetScript('OnClick', function(self)
    if not SOLUTION_BUTTON_ID then
        return;
    end

    AnnounceInChat(GetPartyChatType());

    self.clicked = true;
    self:SetShown(false);
end);
MazeHelper.frame.AnnounceButton:SetShown(false);

MazeHelper.frame.Settings = CreateFrame('Frame', nil, MazeHelper.frame);
MazeHelper.frame.Settings:SetAllPoints();
MazeHelper.frame.Settings:SetShown(false);

MazeHelper.frame.PracticeModeButton = CreateFrame('Button', nil, MazeHelper.frame.Settings);
PixelUtil.SetPoint(MazeHelper.frame.PracticeModeButton, 'BOTTOM', MazeHelper.frame.Settings, 'TOP', 0, -4);
PixelUtil.SetSize(MazeHelper.frame.PracticeModeButton, 24, 24);
MazeHelper.frame.PracticeModeButton:SetNormalTexture(M.Icons.TEXTURE);
MazeHelper.frame.PracticeModeButton:GetNormalTexture():SetTexCoord(unpack(M.Icons.COORDS.MAZE_BRAIN));
MazeHelper.frame.PracticeModeButton:GetNormalTexture():SetVertexColor(0.7, 0.7, 0.7, 1);
MazeHelper.frame.PracticeModeButton:SetHighlightTexture(M.Icons.TEXTURE, 'BLEND');
MazeHelper.frame.PracticeModeButton:GetHighlightTexture():SetTexCoord(unpack(M.Icons.COORDS.MAZE_BRAIN));
MazeHelper.frame.PracticeModeButton:GetHighlightTexture():SetVertexColor(1, 0.85, 0, 1);
MazeHelper.frame.PracticeModeButton:SetScript('OnClick', function()
    MazeHelper.frame:SetShown(false);
    MazeHelper.PracticeFrame:SetShown(true);
end);
E.CreateTooltip(MazeHelper.frame.PracticeModeButton, L['PRACTICE_BUTTON_TOOLTIP']);

MazeHelper.frame.PracticeModeButton.Background = MazeHelper.frame.PracticeModeButton:CreateTexture(nil, 'BACKGROUND');
PixelUtil.SetPoint(MazeHelper.frame.PracticeModeButton.Background, 'TOPLEFT', MazeHelper.frame.PracticeModeButton, 'TOPLEFT', -30, 30);
PixelUtil.SetPoint(MazeHelper.frame.PracticeModeButton.Background, 'BOTTOMRIGHT', MazeHelper.frame.PracticeModeButton, 'BOTTOMRIGHT', 30, -30);
MazeHelper.frame.PracticeModeButton.Background:SetTexture(M.Rings.TEXTURE);
MazeHelper.frame.PracticeModeButton.Background:SetTexCoord(unpack(M.Rings.COORDS.GREEN));

local settingsScrollChild = E.CreateScrollFrame(MazeHelper.frame.Settings, 26);

settingsScrollChild.Data.SyncEnabled = E.CreateRoundedCheckButton(settingsScrollChild);
settingsScrollChild.Data.SyncEnabled:SetPosition('TOPLEFT', settingsScrollChild, 'TOPLEFT', 12, 0);
settingsScrollChild.Data.SyncEnabled:SetLabel(L['SETTINGS_SYNC_ENABLED_LABEL']);
settingsScrollChild.Data.SyncEnabled:SetTooltip(L['SETTINGS_SYNC_ENABLED_TOOLTIP']);
settingsScrollChild.Data.SyncEnabled:SetScript('OnClick', function(self)
    MHMOTSConfig.SyncEnabled = self:GetChecked();
end);

settingsScrollChild.Data.ShowAtBoss = E.CreateRoundedCheckButton(settingsScrollChild);
settingsScrollChild.Data.ShowAtBoss:SetPosition('TOPLEFT', settingsScrollChild.Data.SyncEnabled, 'BOTTOMLEFT', 0, 0);
settingsScrollChild.Data.ShowAtBoss:SetLabel(L['SETTINGS_SHOW_AT_BOSS_LABEL']);
settingsScrollChild.Data.ShowAtBoss:SetTooltip(L['SETTINGS_SHOW_AT_BOSS_TOOLTIP']);
settingsScrollChild.Data.ShowAtBoss:SetScript('OnClick', function(self)
    MHMOTSConfig.ShowAtBoss = self:GetChecked();
end);

settingsScrollChild.Data.PredictSolution = E.CreateRoundedCheckButton(settingsScrollChild);
settingsScrollChild.Data.PredictSolution:SetPosition('TOPLEFT', settingsScrollChild.Data.ShowAtBoss, 'BOTTOMLEFT', 0, 0);
settingsScrollChild.Data.PredictSolution:SetLabel(L['SETTINGS_PREDICT_SOLUTION_LABEL']);
settingsScrollChild.Data.PredictSolution:SetTooltip(L['SETTINGS_PREDICT_SOLUTION_TOOLTIP']);
settingsScrollChild.Data.PredictSolution:SetScript('OnClick', function(self)
    MHMOTSConfig.PredictSolution = self:GetChecked();
    ResetAll();
end);

settingsScrollChild.Data.ShowLargeSymbol = E.CreateRoundedCheckButton(settingsScrollChild);
settingsScrollChild.Data.ShowLargeSymbol:SetPosition('TOPLEFT', settingsScrollChild.Data.PredictSolution, 'BOTTOMLEFT', 0, 0);
settingsScrollChild.Data.ShowLargeSymbol:SetLabel(L['SETTINGS_SHOW_LARGE_SYMBOL_LABEL']);
settingsScrollChild.Data.ShowLargeSymbol:SetTooltip(L['SETTINGS_SHOW_LARGE_SYMBOL_TOOLTIP']);
settingsScrollChild.Data.ShowLargeSymbol:SetScript('OnClick', function(self)
    MHMOTSConfig.ShowLargeSymbol = self:GetChecked();

    if SOLUTION_BUTTON_ID then
        MazeHelper.frame.LargeSymbol:SetShown(MHMOTSConfig.ShowLargeSymbol);
    end
end);

settingsScrollChild.Data.SetMarkerSolutionPlayer = E.CreateRoundedCheckButton(settingsScrollChild);
settingsScrollChild.Data.SetMarkerSolutionPlayer:SetPosition('TOPLEFT', settingsScrollChild.Data.ShowLargeSymbol, 'BOTTOMLEFT', 0, 0);
settingsScrollChild.Data.SetMarkerSolutionPlayer:SetLabel(L['SETTINGS_SET_MARKER_SOLUTION_PLAYER_LABEL']);
settingsScrollChild.Data.SetMarkerSolutionPlayer:SetTooltip(L['SETTINGS_SET_MARKER_SOLUTION_PLAYER_TOOLTIP']);
settingsScrollChild.Data.SetMarkerSolutionPlayer:SetScript('OnClick', function(self)
    MHMOTSConfig.SetMarkerSolutionPlayer = self:GetChecked();

    if not MHMOTSConfig.SetMarkerSolutionPlayer then
        if GetRaidTargetIndex(PLAYER_STRING) == SOLUTION_PLAYER_MARKER then
            SetRaidTarget(PLAYER_STRING, 0);
        end
    end
end);

settingsScrollChild.Data.UseCloneAutoMarker = E.CreateRoundedCheckButton(settingsScrollChild);
settingsScrollChild.Data.UseCloneAutoMarker:SetPosition('TOPLEFT', settingsScrollChild.Data.SetMarkerSolutionPlayer, 'BOTTOMLEFT', 0, 0);
settingsScrollChild.Data.UseCloneAutoMarker:SetLabel(L['SETTINGS_USE_CLONE_AUTOMARKER_LABEL']);
settingsScrollChild.Data.UseCloneAutoMarker:SetTooltip(L['SETTINGS_USE_CLONE_AUTOMARKER_TOOLTIP']);
settingsScrollChild.Data.UseCloneAutoMarker:SetScript('OnClick', function(self)
    MHMOTSConfig.UseCloneAutoMarker = self:GetChecked();

    if MHMOTSConfig.UseCloneAutoMarker and inMOTS then
        for _, event in ipairs(EVENTS_AUTOMARKER) do
            MazeHelper.frame:RegisterEvent(event);
        end
    else
        for _, event in ipairs(EVENTS_AUTOMARKER) do
            MazeHelper.frame:UnregisterEvent(event);
        end
    end
end);

settingsScrollChild.Data.UseColoredSymbols = E.CreateRoundedCheckButton(settingsScrollChild);
settingsScrollChild.Data.UseColoredSymbols:SetPosition('TOPLEFT', settingsScrollChild.Data.UseCloneAutoMarker, 'BOTTOMLEFT', 0, 0);
settingsScrollChild.Data.UseColoredSymbols:SetLabel(L['SETTINGS_USE_COLORED_SYMBOLS_LABEL']);
settingsScrollChild.Data.UseColoredSymbols:SetTooltip(L['SETTINGS_USE_COLORED_SYMBOLS_TOOLTIP']);
settingsScrollChild.Data.UseColoredSymbols:SetScript('OnClick', function(self)
    MHMOTSConfig.UseColoredSymbols = self:GetChecked();

    for i = 1, MAX_BUTTONS do
        buttons[i].Icon:SetTexCoord(unpack(MHMOTSConfig.UseColoredSymbols and buttonsData[i].coords or buttonsData[i].coords_white));
    end

    if SOLUTION_BUTTON_ID then
        MazeHelper.frame.LargeSymbol.Icon:SetTexCoord(unpack(MHMOTSConfig.UseColoredSymbols and buttonsData[SOLUTION_BUTTON_ID].coords or buttonsData[SOLUTION_BUTTON_ID].coords_white));
    end
end);

settingsScrollChild.Data.ShowSequenceNumbers = E.CreateRoundedCheckButton(settingsScrollChild);
settingsScrollChild.Data.ShowSequenceNumbers:SetPosition('TOPLEFT', settingsScrollChild.Data.UseColoredSymbols, 'BOTTOMLEFT', 0, 0);
settingsScrollChild.Data.ShowSequenceNumbers:SetLabel(L['SETTINGS_SHOW_SEQUENCE_NUMBERS_LABEL']);
settingsScrollChild.Data.ShowSequenceNumbers:SetTooltip(L['SETTINGS_SHOW_SEQUENCE_NUMBERS_TOOLTIP']);
settingsScrollChild.Data.ShowSequenceNumbers:SetScript('OnClick', function(self)
    MHMOTSConfig.ShowSequenceNumbers = self:GetChecked();

    for i = 1, MAX_BUTTONS do
        buttons[i].SequenceText:SetShown(MHMOTSConfig.ShowSequenceNumbers);
    end
end);

settingsScrollChild.Data.AnnounceWithEnglish = E.CreateRoundedCheckButton(settingsScrollChild);
settingsScrollChild.Data.AnnounceWithEnglish:SetPosition('TOPLEFT', settingsScrollChild.Data.ShowSequenceNumbers, 'BOTTOMLEFT', 0, 0);
settingsScrollChild.Data.AnnounceWithEnglish:SetLabel(L['SETTINGS_ANNOUNCE_WITH_ENGLISH_LABEL']);
settingsScrollChild.Data.AnnounceWithEnglish:SetTooltip(L['SETTINGS_ANNOUNCE_WITH_ENGLISH_TOOLTIP']);
settingsScrollChild.Data.AnnounceWithEnglish:SetScript('OnClick', function(self)
    MHMOTSConfig.AnnounceWithEnglish = self:GetChecked();
end);

settingsScrollChild.Data.PrintResettedPlayerName = E.CreateRoundedCheckButton(settingsScrollChild);
settingsScrollChild.Data.PrintResettedPlayerName:SetPosition('TOPLEFT', settingsScrollChild.Data.AnnounceWithEnglish, 'BOTTOMLEFT', 0, 0);
settingsScrollChild.Data.PrintResettedPlayerName:SetLabel(L['SETTINGS_REVEAL_RESETTER_LABEL']);
settingsScrollChild.Data.PrintResettedPlayerName:SetTooltip(L['SETTINGS_REVEAL_RESETTER_TOOLTIP']);
settingsScrollChild.Data.PrintResettedPlayerName:SetScript('OnClick', function(self)
    MHMOTSConfig.PrintResettedPlayerName = self:GetChecked();
end);

settingsScrollChild.Data.StartInMinMode = E.CreateRoundedCheckButton(settingsScrollChild);
settingsScrollChild.Data.StartInMinMode:SetPosition('TOPLEFT', settingsScrollChild.Data.PrintResettedPlayerName, 'BOTTOMLEFT', 0, 0);
settingsScrollChild.Data.StartInMinMode:SetLabel(L['SETTINGS_START_IN_MINMODE_LABEL']);
settingsScrollChild.Data.StartInMinMode:SetTooltip(L['SETTINGS_START_IN_MINMODE_TOOLTIP']);
settingsScrollChild.Data.StartInMinMode:SetScript('OnClick', function(self)
    MHMOTSConfig.StartInMinMode = self:GetChecked();
end);

settingsScrollChild.Data.AutoAnnouncer = E.CreateRoundedCheckButton(settingsScrollChild);
settingsScrollChild.Data.AutoAnnouncer:SetPosition('TOPLEFT', settingsScrollChild.Data.StartInMinMode, 'BOTTOMLEFT', 0, 0);
settingsScrollChild.Data.AutoAnnouncer:SetLabel(L['SETTINGS_AUTOANNOUNCER_LABEL']);
settingsScrollChild.Data.AutoAnnouncer:SetTooltip(L['SETTINGS_AUTOANNOUNCER_TOOLTIP']);
settingsScrollChild.Data.AutoAnnouncer:SetScript('OnClick', function(self)
    MHMOTSConfig.AutoAnnouncer = self:GetChecked();

    settingsScrollChild.Data.AutoAnnouncerAsPartyLeader:SetEnabled(MHMOTSConfig.AutoAnnouncer);
    settingsScrollChild.Data.AutoAnnouncerAsAlways:SetEnabled(MHMOTSConfig.AutoAnnouncer);
    settingsScrollChild.Data.AutoAnnouncerAsTank:SetEnabled(MHMOTSConfig.AutoAnnouncer);
    settingsScrollChild.Data.AutoAnnouncerAsHealer:SetEnabled(MHMOTSConfig.AutoAnnouncer);
end);

settingsScrollChild.Data.AutoAnnouncerAsPartyLeader = E.CreateCheckButton('MazeHelper_Settings_AutoAnnouncerAsPartyLeader_CheckButton', settingsScrollChild);
settingsScrollChild.Data.AutoAnnouncerAsPartyLeader:SetPosition('TOPLEFT', settingsScrollChild.Data.AutoAnnouncer, 'BOTTOMRIGHT', 0, 2);
settingsScrollChild.Data.AutoAnnouncerAsPartyLeader:SetLabel(M.INLINE_LEADER_ICON);
settingsScrollChild.Data.AutoAnnouncerAsPartyLeader:SetTooltip(L['SETTINGS_AA_PARTY_LEADER']);
settingsScrollChild.Data.AutoAnnouncerAsPartyLeader:SetScript('OnClick', function(self)
    MHMOTSConfig.AutoAnnouncerAsPartyLeader = self:GetChecked();
end);

settingsScrollChild.Data.AutoAnnouncerAsAlways = E.CreateCheckButton('MazeHelper_Settings_AutoAnnouncerAsAlways_CheckButton', settingsScrollChild);
settingsScrollChild.Data.AutoAnnouncerAsAlways:SetPosition('LEFT', settingsScrollChild.Data.AutoAnnouncerAsPartyLeader.Label, 'RIGHT', 12, 0);
settingsScrollChild.Data.AutoAnnouncerAsAlways:SetLabel(M.INLINE_INFINITY_ICON);
settingsScrollChild.Data.AutoAnnouncerAsAlways:SetTooltip(L['SETTINGS_AA_ALWAYS']);
settingsScrollChild.Data.AutoAnnouncerAsAlways:SetScript('OnClick', function(self)
    MHMOTSConfig.AutoAnnouncerAsAlways = self:GetChecked();
end);

settingsScrollChild.Data.AutoAnnouncerAsTank = E.CreateCheckButton('MazeHelper_Settings_AutoAnnouncerAsTank_CheckButton', settingsScrollChild);
settingsScrollChild.Data.AutoAnnouncerAsTank:SetPosition('LEFT', settingsScrollChild.Data.AutoAnnouncerAsAlways.Label, 'RIGHT', 12, 0);
settingsScrollChild.Data.AutoAnnouncerAsTank:SetLabel(M.INLINE_TANK_ICON);
settingsScrollChild.Data.AutoAnnouncerAsTank:SetTooltip(L['SETTINGS_AA_TANK']);
settingsScrollChild.Data.AutoAnnouncerAsTank:SetScript('OnClick', function(self)
    MHMOTSConfig.AutoAnnouncerAsTank = self:GetChecked();
end);

settingsScrollChild.Data.AutoAnnouncerAsHealer = E.CreateCheckButton('MazeHelper_Settings_AutoAnnouncerAsHealer_CheckButton', settingsScrollChild);
settingsScrollChild.Data.AutoAnnouncerAsHealer:SetPosition('LEFT', settingsScrollChild.Data.AutoAnnouncerAsTank.Label, 'RIGHT', 12, 0);
settingsScrollChild.Data.AutoAnnouncerAsHealer:SetLabel(M.INLINE_HEALER_ICON);
settingsScrollChild.Data.AutoAnnouncerAsHealer:SetTooltip(L['SETTINGS_AA_HEALER']);
settingsScrollChild.Data.AutoAnnouncerAsHealer:SetScript('OnClick', function(self)
    MHMOTSConfig.AutoAnnouncerAsHealer = self:GetChecked();
end);

settingsScrollChild.Data.Scale = E.CreateSlider('Scale', settingsScrollChild);
settingsScrollChild.Data.Scale:SetPosition('TOPLEFT', settingsScrollChild.Data.AutoAnnouncer, 'BOTTOMLEFT', 4, -42);
PixelUtil.SetWidth(settingsScrollChild.Data.Scale, SLIDER_FULL_WIDTH);
settingsScrollChild.Data.Scale:SetLabel(L['SETTINGS_SCALE_LABEL']);
settingsScrollChild.Data.Scale:SetTooltip(L['SETTINGS_SCALE_TOOLTIP']);
settingsScrollChild.Data.Scale.OnMouseUpCallback = function(_, value)
    MHMOTSConfig.SavedScale = tonumber(value);

    local point, relativeTo, relativePoint, xOfs, yOfs = MazeHelper.frame:GetPoint();
    local s = MazeHelper.frame:GetScale();
    s = MHMOTSConfig.SavedScale / s;

    MHMOTSConfig.SavedPosition[1] = point;
    MHMOTSConfig.SavedPosition[2] = relativeTo;
    MHMOTSConfig.SavedPosition[3] = relativePoint;
    MHMOTSConfig.SavedPosition[4] = xOfs / s;
    MHMOTSConfig.SavedPosition[5] = yOfs / s;

    MazeHelper.frame:SetScale(MHMOTSConfig.SavedScale);

    MazeHelper.frame:ClearAllPoints();
    PixelUtil.SetPoint(MazeHelper.frame, point, UIParent, relativePoint, xOfs / s, yOfs / s);
    MazeHelper.frame:SetUserPlaced(true);
end

settingsScrollChild.Data.ScaleLargeSymbol = E.CreateSlider('Scale', settingsScrollChild);
settingsScrollChild.Data.ScaleLargeSymbol:SetPosition('TOPLEFT', settingsScrollChild.Data.Scale, 'BOTTOMLEFT', 0, -42);
PixelUtil.SetWidth(settingsScrollChild.Data.ScaleLargeSymbol, SLIDER_FULL_WIDTH);
settingsScrollChild.Data.ScaleLargeSymbol:SetLabel(L['SETTINGS_SCALE_LARGE_SYMBOL_LABEL']);
settingsScrollChild.Data.ScaleLargeSymbol:SetTooltip(L['SETTINGS_SCALE_LARGE_SYMBOL_TOOLTIP']);
settingsScrollChild.Data.ScaleLargeSymbol.OnMouseUpCallback = function(_, value)
    MHMOTSConfig.SavedScaleLargeSymbol = tonumber(value);

    local point, relativeTo, relativePoint, xOfs, yOfs = MazeHelper.frame.LargeSymbol:GetPoint();
    local s = MazeHelper.frame.LargeSymbol:GetScale();
    s = PixelUtil.GetPixelToUIUnitFactor() * MHMOTSConfig.SavedScaleLargeSymbol / s;

    MHMOTSConfig.SavedPositionLargeSymbol[1] = point;
    MHMOTSConfig.SavedPositionLargeSymbol[2] = relativeTo;
    MHMOTSConfig.SavedPositionLargeSymbol[3] = relativePoint;
    MHMOTSConfig.SavedPositionLargeSymbol[4] = xOfs / s;
    MHMOTSConfig.SavedPositionLargeSymbol[5] = yOfs / s;

    MazeHelper.frame.LargeSymbol:SetScale(PixelUtil.GetPixelToUIUnitFactor() * MHMOTSConfig.SavedScaleLargeSymbol);

    MazeHelper.frame.LargeSymbol:ClearAllPoints();
    PixelUtil.SetPoint(MazeHelper.frame.LargeSymbol, point, UIParent, relativePoint, xOfs / s, yOfs / s);
    MazeHelper.frame.LargeSymbol:SetUserPlaced(true);
end

settingsScrollChild.Data.SavedBackgroundAlpha = E.CreateSlider('Scale', settingsScrollChild);
settingsScrollChild.Data.SavedBackgroundAlpha:SetPosition('TOPLEFT', settingsScrollChild.Data.ScaleLargeSymbol, 'BOTTOMLEFT', 0, -42);
PixelUtil.SetWidth(settingsScrollChild.Data.SavedBackgroundAlpha, SLIDER_FULL_WIDTH);
settingsScrollChild.Data.SavedBackgroundAlpha:SetLabel(M.INLINE_NEW_ICON .. L['SETTINGS_ALPHA_BACKGROUND_LABEL']);
settingsScrollChild.Data.SavedBackgroundAlpha:SetTooltip(L['SETTINGS_ALPHA_BACKGROUND_TOOLTIP']);
settingsScrollChild.Data.SavedBackgroundAlpha.OnValueChangedCallback = function(_, value)
    MHMOTSConfig.SavedBackgroundAlpha = tonumber(value);
    MazeHelper.frame.background:SetAlpha(MHMOTSConfig.SavedBackgroundAlpha);
end

settingsScrollChild.Data.SavedBackgroundAlphaLargeSymbol = E.CreateSlider('Scale', settingsScrollChild);
settingsScrollChild.Data.SavedBackgroundAlphaLargeSymbol:SetPosition('TOPLEFT', settingsScrollChild.Data.SavedBackgroundAlpha, 'BOTTOMLEFT', 0, -42);
PixelUtil.SetWidth(settingsScrollChild.Data.SavedBackgroundAlphaLargeSymbol, SLIDER_FULL_WIDTH);
settingsScrollChild.Data.SavedBackgroundAlphaLargeSymbol:SetLabel(M.INLINE_NEW_ICON .. L['SETTINGS_ALPHA_BACKGROUND_LARGE_SYMBOL_LABEL']);
settingsScrollChild.Data.SavedBackgroundAlphaLargeSymbol:SetTooltip(L['SETTINGS_ALPHA_BACKGROUND_LARGE_SYMBOL_TOOLTIP']);
settingsScrollChild.Data.SavedBackgroundAlphaLargeSymbol.OnValueChangedCallback = function(_, value)
    MHMOTSConfig.SavedBackgroundAlphaLargeSymbol = tonumber(value);
    MazeHelper.frame.LargeSymbol.Background:SetAlpha(MHMOTSConfig.SavedBackgroundAlphaLargeSymbol);
end

MazeHelper.frame.Settings.VersionText = MazeHelper.frame.Settings:CreateFontString(nil, 'ARTWORK', 'GameFontDisable');
PixelUtil.SetPoint(MazeHelper.frame.Settings.VersionText, 'TOP', MazeHelper.frame.Settings, 'BOTTOM', 0, 12);
MazeHelper.frame.Settings.VersionText:SetText(Version);

-- send & sender can be nil
local function Button_SetActive(button, send, sender)
    if button.state or NUM_ACTIVE_BUTTONS == MAX_ACTIVE_BUTTONS then
        return;
    end

    MazeHelper.frame.ResetButton:SetEnabled(true);

    NUM_ACTIVE_BUTTONS = math.min(MAX_ACTIVE_BUTTONS, NUM_ACTIVE_BUTTONS + 1);

    button.state  = true;
    button.sender = sender;

    button:UpdateBorder();
    button:UpdateSequence();

    MazeHelper.frame.SolutionText:SetText(L['CHOOSE_SYMBOLS_' .. (MAX_ACTIVE_BUTTONS - NUM_ACTIVE_BUTTONS)]);

    if send then
        MazeHelper:SendButtonID(button.id, 'ACTIVE');
    end

    MazeHelper:UpdateSolution();

    if MHMOTSConfig.SetMarkerSolutionPlayer then
        if not inEncounter and not sender and SOLUTION_BUTTON_ID and not PREDICTED_SOLUTION_BUTTON_ID and button.id == SOLUTION_BUTTON_ID then
            if GetRaidTargetIndex(PLAYER_STRING) ~= SOLUTION_PLAYER_MARKER then
                SetRaidTarget(PLAYER_STRING, SOLUTION_PLAYER_MARKER);
            end
        end
    end
end

-- send & sender can be nil
local function Button_SetUnactive(button, send, sender)
    if not button.state then
        return;
    end

    NUM_ACTIVE_BUTTONS = math.max(0, NUM_ACTIVE_BUTTONS - 1);

    button.state  = false;
    button.sender = sender;

    button:SetUnactive();
    button:ResetSequence();

    if NUM_ACTIVE_BUTTONS < MAX_ACTIVE_BUTTONS then
        MazeHelper.frame.SolutionText:SetText(L['CHOOSE_SYMBOLS_' .. (MAX_ACTIVE_BUTTONS - NUM_ACTIVE_BUTTONS)]);

        if SOLUTION_BUTTON_ID then
            buttons[SOLUTION_BUTTON_ID]:SetUnactive();
        end

        for i = 1, MAX_BUTTONS do
            buttons[i]:UpdateBorder();
        end

        MazeHelper.frame.PassedButton:SetEnabled(false);
        MazeHelper.frame.AnnounceButton:SetShown(false);
        MazeHelper.frame.AnnounceButton.clicked = false;

        if MHMOTSConfig.SetMarkerSolutionPlayer then
            if not inEncounter and not sender and SOLUTION_BUTTON_ID and not PREDICTED_SOLUTION_BUTTON_ID and button.id == SOLUTION_BUTTON_ID then
                if GetRaidTargetIndex(PLAYER_STRING) == SOLUTION_PLAYER_MARKER then
                    SetRaidTarget(PLAYER_STRING, 0);
                end
            end
        end

        MazeHelper:UpdateSolution();
    end

    if NUM_ACTIVE_BUTTONS == 0 then
        MazeHelper.frame.ResetButton:SetEnabled(false);
    end

    if send then
        MazeHelper:SendButtonID(button.id, 'UNACTIVE');
    end
end

local function GetMinimumReservedSequence()
    for i = 1, #RESERVED_BUTTONS_SEQUENCE do
        if RESERVED_BUTTONS_SEQUENCE[i] == false then
            return i;
        end
    end
end

function MazeHelper:CreateButton(index)
    local button = CreateFrame('Button', nil, MazeHelper.frame.MainHolder, 'BackdropTemplate');

    button.id    = index;
    button.data  = buttonsData[index];
    button.state = false;

    if index == 1 then
        PixelUtil.SetPoint(button, 'TOPLEFT', MazeHelper.frame.MainHolder, 'TOPLEFT', 20, -20);
    elseif index == 5 then
        PixelUtil.SetPoint(button, 'TOPLEFT', buttons[1], 'BOTTOMLEFT', 0, Y_OFFSET);
    else
        PixelUtil.SetPoint(button, 'LEFT', buttons[index - 1], 'RIGHT', X_OFFSET, 0);
    end

    PixelUtil.SetSize(button, BUTTON_SIZE, BUTTON_SIZE);

    button.Icon = button:CreateTexture(nil, 'ARTWORK');
    PixelUtil.SetPoint(button.Icon, 'TOPLEFT', button, 'TOPLEFT', 4, -4);
    PixelUtil.SetPoint(button.Icon, 'BOTTOMRIGHT', button, 'BOTTOMRIGHT', -4, 4);
    button.Icon:SetTexture(M.Symbols.TEXTURE);
    button.Icon:SetTexCoord(unpack(MHMOTSConfig.UseColoredSymbols and buttonsData[index].coords or buttonsData[index].coords_white));

    button.SequenceText = button:CreateFontString(nil, 'ARTWORK', 'GameFontNormal');
    PixelUtil.SetPoint(button.SequenceText, 'BOTTOMRIGHT', button, 'BOTTOMRIGHT', -2, 2);
    button.SequenceText:SetShown(MHMOTSConfig.ShowSequenceNumbers);

    button:SetBackdrop({
        insets   = { top = 1, left = 1, bottom = 1, right = 1 },
        edgeFile = 'Interface\\Buttons\\WHITE8x8',
        edgeSize = 2,
    });

    button.SetActive = function(self)
        self:SetBackdropBorderColor(0.4, 0.52, 0.95, 1);
    end

    button.SetUnactive = function(self)
        self:SetBackdropBorderColor(0, 0, 0, 0);
    end

    button.SetReceived = function(self)
        self:SetBackdropBorderColor(0.9, 1, 0.1, 1);
    end

    button.SetSolution = function(self)
        self:SetBackdropBorderColor(0.2, 0.8, 0.4, 1);
    end

    button.SetPredicted = function(self)
        self:SetBackdropBorderColor(1, 0.9, 0.71, 1);
    end

    button.UpdateBorder = function(self)
        if self.state then
            if self.sender then
                self:SetReceived();
            else
                self:SetActive();
            end
        else
            self:SetUnactive();
        end
    end

    button.UpdateSequence = function(self)
        self.sequence = GetMinimumReservedSequence();
        RESERVED_BUTTONS_SEQUENCE[self.sequence] = true;

        self.SequenceText:SetText((MHMOTSConfig.PredictSolution and self.sequence == 1) and M.INLINE_ENTRANCE_ICON or self.sequence);
    end

    button.ResetSequence = function(self)
        if self.sequence then
            RESERVED_BUTTONS_SEQUENCE[self.sequence] = false;
            self.sequence = nil;
        end

        self.SequenceText:SetText(EMPTY_STRING);
    end

    button:SetUnactive();
    button:RegisterForClicks('LeftButtonUp', 'RightButtonUp');

    button:SetScript('OnClick', function(self, b)
        if b == 'LeftButton' then
            Button_SetActive(self, true);
        elseif b == 'RightButton' then
            Button_SetUnactive(self, true);
        end
    end);

    button:HookScript('OnEnter', function(self)
        if self.sender then
            self.tooltip = self.state and string.format(L['SENDED_BY'], self.sender) or string.format(L['CLEARED_BY'], self.sender);
        else
            self.tooltip = nil;
        end
    end);

    E.CreateTooltip(button);

    button:RegisterForDrag('LeftButton');
    button:SetScript('OnDragStart', function()
        if MazeHelper.frame:IsMovable() then
            MazeHelper.frame:StartMoving();
        end
    end);
    button:SetScript('OnDragStop', function()
        BetterOnDragStop(MazeHelper.frame, MHMOTSConfig.SavedPosition);
    end);

    table.insert(buttons, index, button); -- index for just to be sure
end

function MazeHelper:CreateButtons()
    for i = 1, MAX_BUTTONS do
        MazeHelper:CreateButton(i);
    end
end

-- Credit to Garthul#2712
-- Main idea: The solution is the opposite of entrance symbol or opposite of an existing symbol that shares two features with entrance symbol. Order of conditions matter.
local TryHeuristicSolution do
    local filterTable = {};

    local reusableOppositeTable = {
        fill   = false,
        leaf   = false,
        circle = false,
    };

    local function Filter(b, f) wipe(filterTable); for i, v in pairs(b) do if f(v) then filterTable[i] = v; end end return filterTable; end
    local function Find(b, f) for i, v in pairs(b) do if f(v) then return i, v; end end end
    local function Equals(s1, s2) return s1.fill == s2.fill and s1.leaf == s2.leaf and s1.circle == s2.circle; end
    local function Opposite(s)
        reusableOppositeTable.fill   = not s.fill;
        reusableOppositeTable.leaf   = not s.leaf;
        reusableOppositeTable.circle = not s.circle;

        return reusableOppositeTable;
    end
    local function NumberOfSharedFeatures(s1, s2) return (s1.fill == s2.fill and 1 or 0) + (s1.leaf == s2.leaf and 1 or 0) + (s1.circle == s2.circle and 1 or 0); end

    local IsActiveButtonFunction = function(b) return b.state; end
    local IsEntranceButtonFunction = function(b) return b.state and b.sequence == 1; end

    function TryHeuristicSolution()
        if inEncounter then
            return nil;
        end

        local activeButtons = Filter(buttons, IsActiveButtonFunction);
        local _, entranceButton = Find(activeButtons, IsEntranceButtonFunction);

        if entranceButton ~= nil then
            local IsOppositeOfEntranceFunction = function(b) return Equals(b.data, Opposite(entranceButton.data)); end
            local i, solutionButton = Find(activeButtons, IsOppositeOfEntranceFunction);
            if solutionButton ~= nil then
                return i;
            end

            local IsSharingTwoFeaturesWithEntrance = function(b) return NumberOfSharedFeatures(b.data, entranceButton.data) == 2; end
            local _, helperButton = Find(activeButtons, IsSharingTwoFeaturesWithEntrance);

            if helperButton ~= nil then
                local IsOppositeOfHelperFunction = function(b) return Equals(b.data, Opposite(helperButton.data)); end
                i, solutionButton = Find(activeButtons, IsOppositeOfHelperFunction);
                if solutionButton ~= nil then
                    return i;
                end

                local IsDifferentFromFirstAndSecond = function(b) return not Equals(b.data, helperButton.data) and not Equals(b.data, entranceButton.data); end
                local _, thirdButton = Find(activeButtons, IsDifferentFromFirstAndSecond);

                if thirdButton ~= nil then
                    local solutionSymbol;
                    local numSharedFeatures = NumberOfSharedFeatures(thirdButton.data, entranceButton.data);

                    if numSharedFeatures == 1 then
                        solutionSymbol = Opposite(helperButton.data);
                    elseif numSharedFeatures == 2 then
                        solutionSymbol = Opposite(entranceButton.data);
                    end

                    if solutionSymbol ~= nil then
                        local IsSolutionSymbol = function(b) return Equals(b.data, solutionSymbol); end
                        return Find(buttons, IsSolutionSymbol);
                    end
                end
            end
        end

        return nil;
    end
end

local TryFullSolution do
    local function GetSumCharacteristics()
        local fillSum, leafSum, circleSum = 0, 0, 0;

        for i = 1, MAX_BUTTONS do
            if buttons[i].state then
                if buttons[i].data.circle then
                    circleSum = circleSum + 1;
                end

                if buttons[i].data.leaf then
                    leafSum = leafSum + 1;
                end

                if buttons[i].data.fill then
                    fillSum = fillSum + 1;
                end
            end
        end

        return fillSum, leafSum, circleSum;
    end

    local function GetStagedSolution(kindSum, kind, sButtonId, sFoundCount)
        for i = 1, MAX_BUTTONS do
            if buttons[i].state then
                if (kindSum == 1 and buttons[i].data[kind]) or (kindSum == 3 and not buttons[i].data[kind]) then
                    return i, sFoundCount + 1;
                end
            end
        end

        return sButtonId, sFoundCount;
    end

    function TryFullSolution()
        local fillSum, leafSum, circleSum = GetSumCharacteristics();
        local sButtonId;
        local sFoundCount = 0;

        sButtonId, sFoundCount = GetStagedSolution(fillSum, 'fill', sButtonId, sFoundCount);
        sButtonId, sFoundCount = GetStagedSolution(leafSum, 'leaf', sButtonId, sFoundCount);
        sButtonId, sFoundCount = GetStagedSolution(circleSum, 'circle', sButtonId, sFoundCount);

        if sFoundCount > 1 then
            return;
        end

        return sButtonId;
    end
end

function MazeHelper:UpdateSolution()
    SOLUTION_BUTTON_ID = nil;

    if MHMOTSConfig.PredictSolution and NUM_ACTIVE_BUTTONS < MAX_ACTIVE_BUTTONS then
        SOLUTION_BUTTON_ID = TryHeuristicSolution();
        PREDICTED_SOLUTION_BUTTON_ID = SOLUTION_BUTTON_ID or nil;
    end

    if NUM_ACTIVE_BUTTONS == MAX_ACTIVE_BUTTONS then
        if PREDICTED_SOLUTION_BUTTON_ID then
            buttons[PREDICTED_SOLUTION_BUTTON_ID]:UpdateBorder();

            PREDICTED_SOLUTION_BUTTON_ID = nil;
        end

        SOLUTION_BUTTON_ID = TryFullSolution();
    end

    if SOLUTION_BUTTON_ID then
        local partyChatType = GetPartyChatType();

        for i = 1, MAX_BUTTONS do
            if not buttons[i].state then
                buttons[i]:SetUnactive();
            end
        end

        if PREDICTED_SOLUTION_BUTTON_ID then
            buttons[PREDICTED_SOLUTION_BUTTON_ID]:SetPredicted();
        else
            buttons[SOLUTION_BUTTON_ID]:SetSolution();
        end

        MazeHelper.frame.LargeSymbol.Icon:SetTexCoord(unpack(MHMOTSConfig.UseColoredSymbols and buttonsData[SOLUTION_BUTTON_ID].coords or buttonsData[SOLUTION_BUTTON_ID].coords_white));
        MazeHelper.frame.LargeSymbol:SetShown(MHMOTSConfig.ShowLargeSymbol);

        MazeHelper.frame.MiniSolution.Icon:SetTexCoord(unpack(MHMOTSConfig.UseColoredSymbols and buttonsData[SOLUTION_BUTTON_ID].coords or buttonsData[SOLUTION_BUTTON_ID].coords_white));

        MazeHelper.frame.AnnounceButton:SetShown((not isMinimized and partyChatType and not MHMOTSConfig.AutoAnnouncer) and true or false);
        MazeHelper.frame.PassedButton:SetEnabled(true);
        MazeHelper.frame.SolutionText:SetText(string.format(L['SOLUTION'], buttons[SOLUTION_BUTTON_ID].data.name));

        if isMinimized then
            MazeHelper.frame.MiniSolution:SetShown(true);
            MazeHelper.frame.PassedCounter:SetShown(false);
        end

        if MHMOTSConfig.AutoAnnouncer and partyChatType then
            local announce = false;

            if MHMOTSConfig.AutoAnnouncerAsAlways then
                announce = true;
            elseif MHMOTSConfig.AutoAnnouncerAsPartyLeader and UnitIsGroupLeader(PLAYER_STRING) then
                announce = true;
            elseif MHMOTSConfig.AutoAnnouncerAsTank and playerRole == 'TANK' then
                announce = true;
            elseif MHMOTSConfig.AutoAnnouncerAsHealer and playerRole == 'HEALER' then
                announce = true;
            end

            if announce and ANNOUNCED_BUTTON_ID ~= SOLUTION_BUTTON_ID then
                ANNOUNCED_BUTTON_ID = SOLUTION_BUTTON_ID;
                AnnounceInChat(partyChatType);
            end
        end
    else
        MazeHelper.frame.LargeSymbol:SetShown(false);
        MazeHelper.frame.MiniSolution:SetShown(false);
        MazeHelper.frame.PassedCounter:SetShown(true);
        MazeHelper.frame.AnnounceButton:SetShown(false);

        MazeHelper.frame.PassedButton:SetEnabled(false);

        if NUM_ACTIVE_BUTTONS == MAX_ACTIVE_BUTTONS then
            for i = 1, MAX_BUTTONS do
                buttons[i]:UpdateBorder();
            end

            MazeHelper.frame.SolutionText:SetText(L['SOLUTION_NA']);
        end
    end
end

function MazeHelper:SendResetCommand()
    if not MHMOTSConfig.SyncEnabled then
        return;
    end

    local partyChatType = GetPartyChatType();
    if not partyChatType then
        return;
    end

    ChatThrottleLib:SendAddonMessage(ADDON_COMM_MODE, ADDON_COMM_PREFIX, 'SendReset', partyChatType);
end

function MazeHelper:SendPassedCommand(step)
    if not MHMOTSConfig.SyncEnabled then
        return;
    end

    local partyChatType = GetPartyChatType();
    if not partyChatType then
        return;
    end

    ChatThrottleLib:SendAddonMessage(ADDON_COMM_MODE, ADDON_COMM_PREFIX, string.format('SendPassed|%s', step), partyChatType);
end

function MazeHelper:SendPassedCounter(step)
    if not MHMOTSConfig.SyncEnabled then
        return;
    end

    if step == PASSED_COUNTER then
        return;
    end

    local partyChatType = GetPartyChatType();
    if not partyChatType then
        return;
    end

    ChatThrottleLib:SendAddonMessage(ADDON_COMM_MODE, ADDON_COMM_PREFIX, string.format('RECPC|%s', PASSED_COUNTER), partyChatType);
end

function MazeHelper:RequestPassedCounter()
    if not MHMOTSConfig.SyncEnabled then
        return;
    end

    local partyChatType = GetPartyChatType();
    if not partyChatType then
        return;
    end

    ChatThrottleLib:SendAddonMessage(ADDON_COMM_MODE, ADDON_COMM_PREFIX, string.format('REQPC|%s', PASSED_COUNTER), partyChatType);
end

function MazeHelper:SendButtonID(buttonID, mode)
    if not MHMOTSConfig.SyncEnabled then
        return;
    end

    local partyChatType = GetPartyChatType();
    if not partyChatType then
        return;
    end

    ChatThrottleLib:SendAddonMessage(ADDON_COMM_MODE, ADDON_COMM_PREFIX, string.format('SendButtonID|%s|%s', buttonID, mode), partyChatType);
end

function MazeHelper:ReceiveResetCommand()
    ResetAll();
end

function MazeHelper:ReceivePassedCommand(step)
    PASSED_COUNTER = step;

    MazeHelper.frame.PassedCounter.Text:SetText(PASSED_COUNTER);
    PixelUtil.SetPoint(MazeHelper.frame.PassedCounter.Text, 'CENTER', MazeHelper.frame.PassedCounter, 'CENTER', (PASSED_COUNTER == 1) and -2 or 0, isMinimized and 0 or -1);

    ResetAll();
end

function MazeHelper:ReceivePassedCounter(step)
    if step and step == PASSED_COUNTER then
        return;
    end

    PASSED_COUNTER = step;

    MazeHelper.frame.PassedCounter.Text:SetText(PASSED_COUNTER);
    PixelUtil.SetPoint(MazeHelper.frame.PassedCounter.Text, 'CENTER', MazeHelper.frame.PassedCounter, 'CENTER', (PASSED_COUNTER == 1) and -2 or 0, isMinimized and 0 or -1);
end

function MazeHelper:ReceiveActiveButtonID(buttonID, sender)
    if not buttons[buttonID] then
        return;
    end

    Button_SetActive(buttons[buttonID], false, sender);
end

function MazeHelper:ReceiveUnactiveButtonID(buttonID, sender)
    if not buttons[buttonID] then
        return;
    end

    Button_SetUnactive(buttons[buttonID], false, sender);
end

local function GetFreeMarkerIndex()
    for i = 1, 8 do
        if USED_MARKERS[i] == false then
            return i;
        end
    end

    return false;
end

local function SetFreeMarkerIndex(index)
    USED_MARKERS[index] = false;
end

local function SetUnfreeMarkerIndex(index)
    USED_MARKERS[index] = true;
end

local function UpdateUsedMarkers()
    for i = 1, 8 do
        SetFreeMarkerIndex(i);
    end

    local index;

    for _, unit in ipairs(MARKER_UNITS) do
        index = GetRaidTargetIndex(unit);
        if index then
            SetUnfreeMarkerIndex(index);
        end
    end

    for _, frame in pairs(C_NamePlate.GetNamePlates()) do
        index = GetRaidTargetIndex(frame.namePlateUnitToken);
        if index then
            SetUnfreeMarkerIndex(index);
        end
    end
end

local function UpdateShown()
    if MHMOTSConfig.ShowAtBoss then
        MazeHelper.frame:SetShown((not bossKilled and inMOTS and GetMinimapZoneText() == L['ZONE_NAME']));
    else
        MazeHelper.frame:SetShown((not inEncounter and inMOTS and GetMinimapZoneText() == L['ZONE_NAME']));
    end

    if MazeHelper.frame:IsShown() then
        if MHMOTSConfig.StartInMinMode and not startedInMinMode then
            MazeHelper.frame.MinButton:Click();
            startedInMinMode = true;
        end
    end

    if inEncounter then
        PixelUtil.SetSize(MazeHelper.frame.BottomButtonsHolder, MazeHelper.frame.ResetButton:GetWidth(), 22);

        MazeHelper.frame.PassedButton:Hide();
        MazeHelper.frame.PassedCounter:Hide();
    else
        PixelUtil.SetSize(MazeHelper.frame.BottomButtonsHolder, MazeHelper.frame.ResetButton:GetWidth() + MazeHelper.frame.PassedButton:GetWidth() + 8, 22);

        MazeHelper.frame.PassedButton:Show();
        MazeHelper.frame.PassedCounter:Show();
    end
end

local function UpdateState(frame)
    local playerName, playerShortenedRealm = UnitFullName(PLAYER_STRING);
    playerNameWithRealm = playerName .. '-' .. playerShortenedRealm;

    inInstance = IsInInstance();

    if inInstance then
        local instanceId = select(8, GetInstanceInfo());
        inMOTS = instanceId == MOTS_INSTANCE_ID;
    else
        inMOTS = false;
    end

    bossKilled = inMOTS and (select(3, GetInstanceLockTimeRemainingEncounter(2))) or false;
    inEncounter = inMOTS and not bossKilled and UnitExists('boss1');

    PASSED_COUNTER = 1;
    MazeHelper.frame.PassedCounter.Text:SetText(PASSED_COUNTER);
    PixelUtil.SetPoint(MazeHelper.frame.PassedCounter.Text, 'CENTER', MazeHelper.frame.PassedCounter, 'CENTER', (PASSED_COUNTER == 1) and -2 or 0, isMinimized and 0 or -1);

    startedInMinMode = false;

    if inMOTS then
        MazeHelper:RequestPassedCounter(); -- if you were dc'ed or reloading ui

        for _, event in ipairs(EVENTS_INSTANCE) do
            frame:RegisterEvent(event);
        end

        if MHMOTSConfig.UseCloneAutoMarker then
            for _, event in ipairs(EVENTS_AUTOMARKER) do
                frame:RegisterEvent(event);
            end
        end
    else
        for _, event in ipairs(EVENTS_INSTANCE) do
            frame:UnregisterEvent(event);
        end

        for _, event in ipairs(EVENTS_AUTOMARKER) do
            frame:UnregisterEvent(event);
        end
    end

    UpdateUsedMarkers();
    UpdateShown();
end

local function UpdateBossState(encounterID, inFight, killed)
    if encounterID ~= MISTCALLER_ENCOUNTER_ID then
        return;
    end

    inEncounter = inFight;
    bossKilled  = killed;

    UpdateUsedMarkers();
    ResetAll();
    UpdateShown();
end

MazeHelper.frame.ResetAll    = ResetAll;
MazeHelper.frame.UpdateShown = UpdateShown;

MazeHelper.frame:RegisterEvent('ADDON_LOADED');
MazeHelper.frame:SetScript('OnEvent', function(self, event, ...)
    if self[event] then
        return self[event](self, ...);
    end
end);

function MazeHelper.frame:PLAYER_LOGIN()
    if MHMOTSConfig.SavedPosition and #MHMOTSConfig.SavedPosition > 1 then
        self:ClearAllPoints();
        PixelUtil.SetPoint(self, MHMOTSConfig.SavedPosition[1], UIParent, MHMOTSConfig.SavedPosition[3], MHMOTSConfig.SavedPosition[4], MHMOTSConfig.SavedPosition[5]);
        self:SetUserPlaced(true);
    end

    if MHMOTSConfig.SavedPositionLargeSymbol and #MHMOTSConfig.SavedPositionLargeSymbol > 1 then
        self.LargeSymbol:ClearAllPoints();
        PixelUtil.SetPoint(self.LargeSymbol, MHMOTSConfig.SavedPositionLargeSymbol[1], UIParent, MHMOTSConfig.SavedPositionLargeSymbol[3], MHMOTSConfig.SavedPositionLargeSymbol[4], MHMOTSConfig.SavedPositionLargeSymbol[5]);
        self.LargeSymbol:SetUserPlaced(true);
	end

    UpdateState(self);
end

function MazeHelper.frame:PLAYER_ENTERING_WORLD()
    UpdateState(self);
end

function MazeHelper.frame:ZONE_CHANGED()
    UpdateShown();
end

function MazeHelper.frame:ZONE_CHANGED_INDOORS()
    UpdateShown();
end

function MazeHelper.frame:ZONE_CHANGED_NEW_AREA()
    UpdateShown();
end

function MazeHelper.frame:ENCOUNTER_START(encounterID)
    UpdateBossState(encounterID, true, false);
end

function MazeHelper.frame:ENCOUNTER_END(encounterID, _, _, _, success)
    UpdateBossState(encounterID, false, success);
end

function MazeHelper.frame:BOSS_KILL(encounterID)
    UpdateBossState(encounterID, false, true);
end

function MazeHelper.frame:NAME_PLATE_UNIT_ADDED(unit)
    if not inEncounter then
        return;
    end

    local npcId = select(6, strsplit('-', UnitGUID(unit)));
    npcId = tonumber(npcId);

    if not npcId or npcId ~= ILLUSIONARY_CLONE_ID then
        return;
    end

    if not GetRaidTargetIndex(unit) then
        local index = GetFreeMarkerIndex();
        if index then
            SetRaidTarget(unit, index);
            SetUnfreeMarkerIndex(index);
            nameplatesMarkers[unit] = index;
        end
    end
end

function MazeHelper.frame:NAME_PLATE_UNIT_REMOVED(unit)
    if not inEncounter then
        return;
    end

    if not nameplatesMarkers[unit] then
        return;
    end

    SetFreeMarkerIndex(nameplatesMarkers[unit]);
    nameplatesMarkers[unit] = nil;
end

function MazeHelper.frame:CHAT_MSG_ADDON(prefix, message, _, sender)
    if not MHMOTSConfig.SyncEnabled then
        return;
    end

    if sender == playerNameWithRealm then
        return;
    end

    if prefix == ADDON_COMM_PREFIX then
        local command, arg1, arg2 = strsplit('|', message);

        if command == 'SendButtonID'  then
            local buttonId, buttonMode = arg1, arg2;

            if buttonMode == 'ACTIVE' then
                MazeHelper:ReceiveActiveButtonID(tonumber(buttonId), sender);
            elseif buttonMode == 'UNACTIVE' then
                MazeHelper:ReceiveUnactiveButtonID(tonumber(buttonId), sender);
            end
        elseif command == 'SendPassed' then
            MazeHelper:ReceivePassedCommand(tonumber(arg1));

            if MHMOTSConfig.PrintResettedPlayerName then
                print(string.format(L['PASSED_PLAYER'], sender));
            end
        elseif command == 'SendReset' then
            MazeHelper:ReceiveResetCommand();

            if MHMOTSConfig.PrintResettedPlayerName then
                print(string.format(L['RESETED_PLAYER'], sender));
            end
        elseif command == 'REQPC' then
            MazeHelper:SendPassedCounter(tonumber(arg1));
        elseif command == 'RECPC' then
            MazeHelper:ReceivePassedCounter(tonumber(arg1));
        end
    end
end

function MazeHelper.frame:PLAYER_SPECIALIZATION_CHANGED(unit)
    if unit ~= PLAYER_STRING then
        return;
    end

    playerRole = (select(5, GetSpecializationInfo(GetSpecialization())) or EMPTY_STRING);
end

function MazeHelper.frame:GOSSIP_SHOW()
    if C_GossipInfo.GetNumOptions() ~= 1 then
        return;
    end

    local npcId = tonumber((select(6, strsplit('-', UnitGUID('npc') or ''))) or '0');
    if not npcId or not DEPLETED_ANIMA_SEED_IDS[npcId] then
		return;
    end

    C_GossipInfo.SelectOption(1);
    C_GossipInfo.CloseGossip();
end

function MazeHelper.frame:ADDON_LOADED(addonName)
    if addonName ~= ADDON_NAME then
        return;
    end

    self:UnregisterEvent('ADDON_LOADED');

    MHMOTSConfig = MHMOTSConfig or {};

    MHMOTSConfig.SavedPosition                   = MHMOTSConfig.SavedPosition or {};
    MHMOTSConfig.SavedPositionLargeSymbol        = MHMOTSConfig.SavedPositionLargeSymbol or {};
    MHMOTSConfig.SavedScale                      = MHMOTSConfig.SavedScale or 1;
    MHMOTSConfig.SavedScaleLargeSymbol           = MHMOTSConfig.SavedScaleLargeSymbol or 1;
    MHMOTSConfig.SavedBackgroundAlpha            = MHMOTSConfig.SavedBackgroundAlpha or 0.85;
    MHMOTSConfig.SavedBackgroundAlphaLargeSymbol = MHMOTSConfig.SavedBackgroundAlphaLargeSymbol or 0.8;

    MHMOTSConfig.SyncEnabled             = MHMOTSConfig.SyncEnabled == nil and true or MHMOTSConfig.SyncEnabled;
    MHMOTSConfig.PredictSolution         = MHMOTSConfig.PredictSolution == nil and false or MHMOTSConfig.PredictSolution;
    MHMOTSConfig.PrintResettedPlayerName = MHMOTSConfig.PrintResettedPlayerName == nil and true or MHMOTSConfig.PrintResettedPlayerName;
    MHMOTSConfig.ShowAtBoss              = MHMOTSConfig.ShowAtBoss == nil and true or MHMOTSConfig.ShowAtBoss;
    MHMOTSConfig.StartInMinMode          = MHMOTSConfig.StartInMinMode == nil and false or MHMOTSConfig.StartInMinMode;
    MHMOTSConfig.UseColoredSymbols       = MHMOTSConfig.UseColoredSymbols == nil and true or MHMOTSConfig.UseColoredSymbols;
    MHMOTSConfig.ShowSequenceNumbers     = MHMOTSConfig.ShowSequenceNumbers == nil and true or MHMOTSConfig.ShowSequenceNumbers;
    MHMOTSConfig.ShowLargeSymbol         = MHMOTSConfig.ShowLargeSymbol == nil and true or MHMOTSConfig.ShowLargeSymbol;
    MHMOTSConfig.UseCloneAutoMarker      = MHMOTSConfig.UseCloneAutoMarker == nil and true or MHMOTSConfig.UseCloneAutoMarker;
    MHMOTSConfig.AnnounceWithEnglish     = MHMOTSConfig.AnnounceWithEnglish == nil and true or MHMOTSConfig.AnnounceWithEnglish;
    MHMOTSConfig.SetMarkerSolutionPlayer = MHMOTSConfig.SetMarkerSolutionPlayer == nil and false or MHMOTSConfig.SetMarkerSolutionPlayer;

    MHMOTSConfig.AutoAnnouncer              = MHMOTSConfig.AutoAnnouncer == nil and false or MHMOTSConfig.AutoAnnouncer;
    MHMOTSConfig.AutoAnnouncerAsPartyLeader = MHMOTSConfig.AutoAnnouncerAsPartyLeader == nil and true or MHMOTSConfig.AutoAnnouncerAsPartyLeader;
    MHMOTSConfig.AutoAnnouncerAsAlways      = MHMOTSConfig.AutoAnnouncerAsAlways == nil and false or MHMOTSConfig.AutoAnnouncerAsAlways;
    MHMOTSConfig.AutoAnnouncerAsTank        = MHMOTSConfig.AutoAnnouncerAsTank == nil and false or MHMOTSConfig.AutoAnnouncerAsTank;
    MHMOTSConfig.AutoAnnouncerAsHealer      = MHMOTSConfig.AutoAnnouncerAsHealer == nil and false or MHMOTSConfig.AutoAnnouncerAsHealer;

    MHMOTSConfig.PracticeNoSound = MHMOTSConfig.PracticeNoSound == nil and false or MHMOTSConfig.PracticeNoSound;

    settingsScrollChild.Data.SyncEnabled:SetChecked(MHMOTSConfig.SyncEnabled);
    settingsScrollChild.Data.PredictSolution:SetChecked(MHMOTSConfig.PredictSolution);
    settingsScrollChild.Data.UseColoredSymbols:SetChecked(MHMOTSConfig.UseColoredSymbols);
    settingsScrollChild.Data.ShowSequenceNumbers:SetChecked(MHMOTSConfig.ShowSequenceNumbers);
    settingsScrollChild.Data.PrintResettedPlayerName:SetChecked(MHMOTSConfig.PrintResettedPlayerName);
    settingsScrollChild.Data.ShowAtBoss:SetChecked(MHMOTSConfig.ShowAtBoss);
    settingsScrollChild.Data.ShowLargeSymbol:SetChecked(MHMOTSConfig.ShowLargeSymbol);
    settingsScrollChild.Data.StartInMinMode:SetChecked(MHMOTSConfig.StartInMinMode);
    settingsScrollChild.Data.UseCloneAutoMarker:SetChecked(MHMOTSConfig.UseCloneAutoMarker);
    settingsScrollChild.Data.AnnounceWithEnglish:SetChecked(MHMOTSConfig.AnnounceWithEnglish);
    settingsScrollChild.Data.SetMarkerSolutionPlayer:SetChecked(MHMOTSConfig.SetMarkerSolutionPlayer);

    settingsScrollChild.Data.AutoAnnouncer:SetChecked(MHMOTSConfig.AutoAnnouncer);
    settingsScrollChild.Data.AutoAnnouncerAsPartyLeader:SetChecked(MHMOTSConfig.AutoAnnouncerAsPartyLeader);
    settingsScrollChild.Data.AutoAnnouncerAsAlways:SetChecked(MHMOTSConfig.AutoAnnouncerAsAlways);
    settingsScrollChild.Data.AutoAnnouncerAsTank:SetChecked(MHMOTSConfig.AutoAnnouncerAsTank);
    settingsScrollChild.Data.AutoAnnouncerAsHealer:SetChecked(MHMOTSConfig.AutoAnnouncerAsHealer);

    settingsScrollChild.Data.AutoAnnouncerAsPartyLeader:SetEnabled(MHMOTSConfig.AutoAnnouncer);
    settingsScrollChild.Data.AutoAnnouncerAsAlways:SetEnabled(MHMOTSConfig.AutoAnnouncer);
    settingsScrollChild.Data.AutoAnnouncerAsTank:SetEnabled(MHMOTSConfig.AutoAnnouncer);
    settingsScrollChild.Data.AutoAnnouncerAsHealer:SetEnabled(MHMOTSConfig.AutoAnnouncer);

    settingsScrollChild.Data.Scale:SetValues(MHMOTSConfig.SavedScale, 0.25, 3, 0.05);
    settingsScrollChild.Data.ScaleLargeSymbol:SetValues(MHMOTSConfig.SavedScaleLargeSymbol, 0.25, 3, 0.05);

    MazeHelper.PracticeFrame.NoSoundButton:SetChecked(MHMOTSConfig.PracticeNoSound);
    MazeHelper.PracticeFrame.NoSoundButton:SetTurned(not MHMOTSConfig.PracticeNoSound);

    MazeHelper.frame:SetScale(MHMOTSConfig.SavedScale);
    MazeHelper.frame.LargeSymbol:SetScale(PixelUtil.GetPixelToUIUnitFactor() * MHMOTSConfig.SavedScaleLargeSymbol);

    settingsScrollChild.Data.SavedBackgroundAlpha:SetValues(MHMOTSConfig.SavedBackgroundAlpha, 0, 1, 0.05);
    settingsScrollChild.Data.SavedBackgroundAlphaLargeSymbol:SetValues(MHMOTSConfig.SavedBackgroundAlphaLargeSymbol, 0, 1, 0.05);

    MazeHelper.frame.background:SetAlpha(MHMOTSConfig.SavedBackgroundAlpha);
    MazeHelper.frame.LargeSymbol.Background:SetAlpha(MHMOTSConfig.SavedBackgroundAlphaLargeSymbol);

    if MazeHelper.currentLocale == 'enUS' then
        settingsScrollChild.Data.AnnounceWithEnglish:SetShown(false);
        settingsScrollChild.Data.PrintResettedPlayerName:SetPosition('TOPLEFT', settingsScrollChild.Data.ShowSequenceNumbers, 'BOTTOMLEFT', 0, 0);
    end

    MazeHelper:CreateButtons();

    self:RegisterEvent('PLAYER_LOGIN');
    self:RegisterEvent('PLAYER_ENTERING_WORLD');
    self:RegisterEvent('PLAYER_SPECIALIZATION_CHANGED');
    self:RegisterEvent('CHAT_MSG_ADDON');

    _G['SLASH_MAZEHELPER1'] = '/mh';
    SlashCmdList['MAZEHELPER'] = function(input)
        if input and string.find(input, 'scale') then
            local _, scale = strsplit(' ', input);
            if not scale or scale == '' or scale == 'reset' or scale == 'r' then
                scale = 1;
            end

            scale = tonumber(scale);
            scale = math.min(scale, 3);
            scale = math.max(scale, 0.25);

            MHMOTSConfig.SavedScale = scale;

            local point, relativeTo, relativePoint, xOfs, yOfs = MazeHelper.frame:GetPoint();
            local s = MazeHelper.frame:GetScale();
            s = MHMOTSConfig.SavedScale / s;

            MHMOTSConfig.SavedPosition[1] = point;
            MHMOTSConfig.SavedPosition[2] = relativeTo;
            MHMOTSConfig.SavedPosition[3] = relativePoint;
            MHMOTSConfig.SavedPosition[4] = xOfs / s;
            MHMOTSConfig.SavedPosition[5] = yOfs / s;

            MazeHelper.frame:SetScale(MHMOTSConfig.SavedScale);

            MazeHelper.frame:ClearAllPoints();
            PixelUtil.SetPoint(MazeHelper.frame, point, UIParent, relativePoint, xOfs / s, yOfs / s);
            MazeHelper.frame:SetUserPlaced(true);

            settingsScrollChild.Data.Scale:SetValue(MHMOTSConfig.SavedScale);

            return;
        end

        if not MazeHelper.PracticeFrame:IsShown() then
            MazeHelper.frame:SetShown(not MazeHelper.frame:IsShown());
        end
    end
end