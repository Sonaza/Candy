------------------------------------------------------------
-- Candy by Sonaza (https://sonaza.com)
-- Licensed under MIT License
-- See attached license text in file LICENSE
------------------------------------------------------------

local ADDON_NAME = ...;
local addon = LibStub("AceAddon-3.0"):NewAddon(select(2, ...), ADDON_NAME, "AceEvent-3.0");
_G[ADDON_NAME] = addon;

local LibDataBroker = LibStub("LibDataBroker-1.1");
local AceDB = LibStub("AceDB-3.0");

local LibSharedMedia = LibStub("LibSharedMedia-3.0");
LibSharedMedia:Register("font", "DorisPP", [[Interface\Addons\Candy\media\DORISPP.ttf]]);

local CANDY_DEFAULT_FONT = "DorisPP";

local ICON_PATTERN = "|T%s:12:12:0:0|t ";

local inClassicMode = (WOW_PROJECT_ID == WOW_PROJECT_CLASSIC);

local frameStrata = {
	"BACKGROUND",
	"LOW",
	"MEDIUM",
	"HIGH",
	"DIALOG",
	"FULLSCREEN",
	"FULLSCREEN_DIALOG",
	"TOOLTIP",
};
addon.frameStrata = frameStrata;

-- ENUMS
addon.E = {
	VISIBILITY_ALWAYS 			= 0x1,
	VISIBILITY_IN_COMBAT 		= 0x2,
	VISIBILITY_OUT_OF_COMBAT 	= 0x3,

	INSTANCEMODE_EVERYWHERE 	= 0x1,
	INSTANCEMODE_INSIDE 		= 0x2,
	INSTANCEMODE_OUTSIDE 		= 0x3,

	GROUPMODE_ALWAYS 			= 0x1,
	GROUPMODE_SOLO 				= 0x2,
	GROUPMODE_INPARTY 			= 0x3,
};
local E = addon.E;

function addon:OnInitialize()
	addon:RegisterEvent("PLAYER_ENTERING_WORLD");
	addon:RegisterEvent("ZONE_CHANGED");
	addon:RegisterEvent("ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED");
	
	addon:RegisterEvent("PLAYER_REGEN_DISABLED");
	addon:RegisterEvent("PLAYER_REGEN_ENABLED");
	
	if (not inClassicMode) then
		addon:RegisterEvent("PET_BATTLE_OPENING_START");
		addon:RegisterEvent("PET_BATTLE_OVER");
	end
	
	addon:RegisterEvent("MODIFIER_STATE_CHANGED");
end

function addon:OnEnable()
	SLASH_CANDY1	= "/candy";
	SLASH_CANDY2	= "/cd";
	SlashCmdList["CANDY"] = function(command) addon:ShowOptions(command); end
	
	local defaults = {
		global = {
			enabled = true,
			locked = false,
			
			fontFace = CANDY_DEFAULT_FONT,
			fontSize = 10,
			fontOutline = nil,
			frameStrata = "MEDIUM",
			
			backgroundColor = { 0.0, 0.0, 0.0, 0.0 },
			
			bars = {
				["*"] = {
					enabled = false,
					showTooltip = true,
					isClickthrough = false,
					stripColor = false,
					
					showIcon = false,
					showText = true,
					
					fontSize = 10,
					fontOutline = nil,
					frameStrata = "MEDIUM",
					
					luaTextFilter = nil,
					
					fixedWidth = 0,
					backgroundColor = { 0.0, 0.0, 0.0, 0.0 },
					
					visibility = {
						mode 			= E.VISIBILITY_ALWAYS,
						instanceMode 	= E.INSTANCEMODE_EVERYWHERE,
						groupMode 		= E.GROUPMODE_ALWAYS,
						
						showCtrl = false,
						showShift = false,
						showAlt = false,
						
						customLua = nil,
						
						hideInPetBattle	= true,
					},
					
					anchors = {
						["*"] = {
							point = "CENTER",
							relativeTo = nil,
							relativePoint = "CENTER",
							x = 0,
							y = 0,
							absolute = {
								x = 0,
								y = 0,
							},
						},
						[1] = {
							point = "CENTER",
							relativeTo = nil,
							relativePoint = "CENTER",
							x = 0,
							y = 0,
							absolute = {
								x = 0,
								y = 0,
							},
						},
					},
					
					justify = "LEFT",
				},
			},
		},
	};
	
	self.db = AceDB:New(ADDON_NAME .. "DB", defaults);
	
	addon.ActiveBars = {};
	
	LibDataBroker.RegisterCallback(self, "LibDataBroker_DataObjectCreated", "DataObjectCreated");
	
	CreateFrame("Frame"):SetScript("OnUpdate", function(self, elapsed)
		self.elapsed = (self.elapsed or 0) + elapsed;
		
		if (self.elapsed >= 0.05) then
			addon:UpdateVisibility();
			self.elapsed = 0;
		end
	end);
	
	ColorPickerFrame:HookScript("OnShow", function() addon:ColorPicker_OnShow(); end);
	ColorPickerFrame:HookScript("OnHide", function() addon:ColorPicker_OnHide(); end);
	
	addon.initialized = true;
end

function addon:PLAYER_ENTERING_WORLD()
	addon:RestoreBars();
	addon:UnregisterEvent("PLAYER_ENTERING_WORLD");
end

function addon:ZONE_CHANGED()
	addon:UpdateVisibility();
end

function addon:PLAYER_REGEN_DISABLED()
	addon:LockBars();
	addon:UpdateVisibility(true);
end

function addon:PLAYER_REGEN_ENABLED()
	addon:UpdateVisibility(false);
end

function addon:MODIFIER_STATE_CHANGED()
	addon:UpdateVisibility();
end

function addon:PET_BATTLE_OPENING_START()
	addon:UpdateVisibility();
end

function addon:PET_BATTLE_OVER()
	addon:UpdateVisibility();
end

function addon:PlayerInInstance()
	local name, instanceType = GetInstanceInfo();
	
	if (instanceType == "none") then
		return false;
	end
	if (not inClassicMode) then
		if (C_Garrison.IsOnGarrisonMap()) then
			return false;
		end
	end
	
	return true, instanceType;
end

function addon:IsPlayerInAGroup()
	return IsInRaid() or IsInGroup();
end

function addon:UpdateCandyBars()
	for broker, candyBar in pairs(addon.ActiveBars) do
		candyBar:SetFrameStrata(candyBar.data.frameStrata);
		addon:UpdateCandyText(broker);
	end
	
	addon:UpdateVisibility();
end

function addon:StripColor(text)
	if (not text) then return "" end
	return string.gsub(string.gsub(text, "\124c%w%w%w%w%w%w%w%w", ""), "\124r", "");
end

function addon:MarkForRecompile(broker)
	local candyBar = addon:GetCandy(broker);
	candyBar.textFilterCallback = nil;
	candyBar.visibilityCallback = nil;
	collectgarbage("collect");
end

function addon:CompileTextFilterScript(broker, candyBar, script)
	if (candyBar.textFilterCallback) then
		return candyBar.textFilterCallback;
	end
	
	local script = string.format('return (function(text) %s end)(...)', script or "return text;");
	local callbackFunction, scriptError = loadstring(script, "Candy-TextFilter-" .. broker);
	
	if (callbackFunction) then
		candyBar.textFilterCallback = callbackFunction;
	end
	
	return callbackFunction;
end

function addon:CompileVisibilityScript(broker, candyBar, script)
	if (candyBar.visibilityCallback) then
		return candyBar.visibilityCallback;
	end
	
	local script = string.format('return (function(text, icon) %s end)(...)', script or "return true;");
	local callbackFunction, scriptError = loadstring(script, "Candy-Visibility-" .. broker);
	
	if (callbackFunction) then
		candyBar.visibilityCallback = callbackFunction;
	end
	
	return callbackFunction;
end

function addon:UpdateVisibility(inCombat)
	local inCombat = inCombat or InCombatLockdown();
	
	for broker, candyBar in pairs(addon.ActiveBars) do
		local shouldShow = true;
		
		if (self.db.global.locked) then
			local visibility = candyBar.data.visibility;
			
			if (inCombat and visibility.mode == E.VISIBILITY_OUT_OF_COMBAT) then
				shouldShow = false;
			elseif (not inCombat and visibility.mode == E.VISIBILITY_IN_COMBAT) then
				shouldShow = false;
			end
			
			if (not inClassicMode) then
				if (visibility.hideInPetBattle and C_PetBattles.IsInBattle()) then
					shouldShow = false;
				end
			end
			
			if (shouldShow and visibility.instanceMode ~= E.INSTANCEMODE_EVERYWHERE) then
				local inInstance = addon:PlayerInInstance();
				
				if (not inInstance and visibility.instanceMode == E.INSTANCEMODE_INSIDE) then
					shouldShow = false;
				elseif (inInstance and visibility.instanceMode == E.INSTANCEMODE_OUTSIDE) then
					shouldShow = false;
				end
			end
			
			if (shouldShow and visibility.groupMode ~= E.GROUPMODE_ALWAYS) then
				local playerInGroup = addon:IsPlayerInAGroup();
				
				if (visibility.groupMode == E.GROUPMODE_SOLO and playerInGroup) then
					shouldShow = false;
				elseif (visibility.groupMode == E.GROUPMODE_INPARTY and not playerInGroup) then
					shouldShow = false;
				end
			end
			
			if (shouldShow) then
				if (visibility.showCtrl and not IsControlKeyDown()) then shouldShow = false; end
				if (visibility.showShift and not IsShiftKeyDown()) then shouldShow = false; end
				if (visibility.showAlt and not IsAltKeyDown()) then shouldShow = false; end
			end
			
			if (shouldShow and visibility.customLua) then
				local callbackFunction = addon:CompileVisibilityScript(broker, candyBar, visibility.customLua);
				
				if (callbackFunction) then
					local module = LibDataBroker:GetDataObjectByName(broker);
					
					local success, result = pcall(callbackFunction, addon:StripColor(module.text), module.icon);
					if (success) then
						shouldShow = shouldShow and result;
					else
						print(result);
					end
				end
			end
		end
		
		if (shouldShow and (not candyBar.isVisible or not candyBar:IsVisible())) then
			candyBar.fadeout:Stop();
			candyBar.fadein:Play();
		elseif (not shouldShow and (candyBar.isVisible or candyBar:IsVisible())) then
			candyBar.fadein:Stop();
			candyBar.fadeout:Play();
		end
	end
end

function CandyFrame_OnFadeIn(self)
	self:GetParent().isVisible = true;
	
	if (InCombatLockdown()) then return end
	if (not self:GetParent().data.isClickthrough) then
		self:GetParent():EnableMouse(true);
	end
	self:GetParent():Show();
	addon:UpdateCandyText(self:GetParent().broker);
end

function CandyFrame_OnFadeInFinish(self)
	self:GetParent():SetAlpha(1);
	
	if (InCombatLockdown()) then return end
	if (not self:GetParent().data.isClickthrough) then
		self:GetParent():EnableMouse(true);
	end
	self:GetParent():Show();
	addon:UpdateCandyText(self:GetParent().broker);
end

function CandyFrame_OnFadeOut(self)
	self:GetParent().isVisible = false;
	
	if (InCombatLockdown()) then return end
	self:GetParent():EnableMouse(false);
end

function CandyFrame_OnFadeOutFinish(self)
	self:GetParent().text:SetText("");
	self:GetParent():SetAlpha(0);
	
	if (not InCombatLockdown()) then
		self:GetParent():Hide();
	end
end

function addon:AddCandy(broker)
	local broker = strtrim(broker or "");
	
	if (addon.db.global.locked) then
		addon:UnlockBars();
	end
	
	local candyBar = addon:CreateCandyBar(broker, true);
	if (candyBar) then
		candyBar.data = self.db.global.bars[broker];
		
		-- Copy the background color (as opposed to setting table pointer)
		candyBar.data.backgroundColor = { unpack(addon.db.global.backgroundColor) };
		candyBar.background:SetVertexColor(unpack(candyBar.data.backgroundColor));
		candyBar.background:Hide();
		candyBar.configBackground:Show();
		
		addon:UpdateCandyText(broker);
	end
end

function addon:RemoveCandy(broker)
	if (self.db.global.bars[broker]) then
		addon.ActiveBars[broker]:Hide();
		
		self.db.global.bars[broker] = nil;
		addon.ActiveBars[broker] = nil;
		
		LibDataBroker.UnregisterCallback(self, "LibDataBroker_AttributeChanged_" .. broker);
	end
end

function addon:GetCandy(broker)
	return addon.ActiveBars[broker], LibDataBroker:GetDataObjectByName(broker);
end

function addon:CreateCandyBar(broker, isNew)
	local module = LibDataBroker:GetDataObjectByName(broker);
	if (not module) then return false end
	
	local frameName = string.format("Candy%sFrame", broker);
	frameName = string.gsub(frameName, " ", "");
	
	local candyBar = _G[frameName];
	if (not candyBar) then
		candyBar = CreateFrame("Button", frameName, UIParent, "CandyBarFrameTemplate");
		candyBar.broker = broker;
	else
		candyBar:Show();
	end
	
	candyBar.isVisible = true;
	
	local settings = self.db.global.bars[broker];
	
	if (isNew) then
		settings.enabled = true;
		
		settings.fontSize = self.db.global.fontSize;
		settings.fontOutline = self.db.global.fontOutline;
		settings.frameStrata = self.db.global.frameStrata;
	end
	
	candyBar:ClearAllPoints();
	candyBar:SetPoint("CENTER", UIParent, "CENTER", 0, 0);
	candyBar.text:SetText(broker);
	
	if (isNew) then
		settings.anchors[1].absolute = {
			x = candyBar:GetLeft(),
			y = candyBar:GetBottom(),
		};
	end
	
	candyBar:SetFrameStrata(self.db.global.bars[broker].frameStrata);
	
	addon.ActiveBars[broker] = candyBar;
	
	LibDataBroker.RegisterCallback(self, "LibDataBroker_AttributeChanged_" .. broker, "AttributeChanged");
	
	return candyBar, module;
end

function addon:DataObjectCreated(event, name, dataobj)
	if (not addon.db.global.enabled) then return end
	if (not name or not dataobj) then return end
	
	if (not self.db.global.bars[name] or not self.db.global.bars[name].enabled) then return end
	if (addon.ActiveBars[name]) then return end
	
	local candyBar, module = addon:CreateCandyBar(name);
	if (not candyBar) then return end
	
	candyBar.data = self.db.global.bars[name];
	candyBar:SetFrameStrata(candyBar.data.frameStrata);
	
	addon:UpdateCandyAnchors();
	
	if (self.db.global.locked) then
		addon:LockBars();
	end
	
	addon:UpdateCandyText(name);
end

function addon:UpdateCandyAnchors()
	for broker, candyBar in pairs(addon.ActiveBars) do
		candyBar:ClearAllPoints();
		
		-- Actually there will never be more than 1 anchor per frame
		local anchor = candyBar.data.anchors[1];
		
		local relativeFrame;
		if (anchor.relativeTo) then
			anchor.relativeTo = string.gsub(anchor.relativeTo, " ", "");
			relativeFrame = _G[anchor.relativeTo];
		end
		
		local useAbsoluteAnchor = anchor.relativeTo and not _G[anchor.relativeTo];
		
		if (not useAbsoluteAnchor) then
			candyBar:SetPoint(anchor.point, relativeFrame or UIParent, anchor.relativePoint, anchor.x, anchor.y);
		else
			candyBar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", anchor.absolute.x, anchor.absolute.y);
		end
		
		local hasParent = (relativeFrame ~= nil);
		addon:ChangeBackground(candyBar, hasParent);
	end
end

function addon:RestoreBars()
	if (not addon.db.global.enabled) then return end
	
	for broker, data in pairs(self.db.global.bars) do
		if (data.enabled) then
			local candyBar, module = addon:CreateCandyBar(broker);
			
			if (candyBar) then
				candyBar.data = data;
				candyBar:SetFrameStrata(data.frameStrata);
				
				local r, g, b, a = unpack(candyBar.data.backgroundColor);
				candyBar.background:SetVertexColor(r, g, b, a);
				candyBar.background:SetShown(not addon.db.global.locked);
			end
		end
	end
	
	addon:UpdateCandyAnchors();
	
	if (self.db.global.locked) then
		addon:LockBars();
	end
	
	addon:UpdateCandyBars();
	addon:ToggleConfigBackground(not addon.db.global.locked);
end

function addon:ChangeBackground(frame, hasParent)
	if (not frame) then return end
	
	if (hasParent) then
		frame.configBackground:SetVertexColor(0.0, 0.0, 0.0, 0.4);
	else
		frame.configBackground:SetVertexColor(1.0, 1.0, 0.0, 0.2);
	end
end

function addon:ResetAnchors()
	local numBrokers = 0;
	for broker, candyBar in pairs(addon.ActiveBars) do
		numBrokers = numBrokers + 1;
	end
	
	local index = 0;
	for broker, candyBar in pairs(addon.ActiveBars) do
		local y = index * 20 - (numBrokers / 2 * 20);
		
		candyBar:ClearAllPoints();
		candyBar:SetPoint("CENTER", UIParent, "CENTER", 0, y);
		
		addon:ChangeBackground(candyBar, false);
		
		candyBar.data.anchors = {};
		candyBar.data.anchors[1] = {
			point = "CENTER",
			relativeTo = "UIParent",
			relativePoint = "CENTER",
			x = 0,
			y = y,
			absolute = {
				x = candyBar:GetLeft(),
				y = candyBar:GetBottom(),
			},
		};
		
		index = index + 1;
	end
end

function addon:UpdateCandyText(broker)
	local candyBar, module = addon:GetCandy(broker);
	if (not candyBar or not module) then return end
	
	if (not addon.initialized) then return end
	
	candyBar.text:SetJustifyH(candyBar.data.justify);
	
	local text = "";
	
	if (candyBar.data.showText) then
		text = module.text or module.label or broker or "no text";
		
		if (candyBar.data.stripColor) then
			text = addon:StripColor(text);
		end
		
		if (candyBar.data.luaTextFilter ~= nil) then
			local callbackFunction = addon:CompileTextFilterScript(candyBar.broker, candyBar, candyBar.data.luaTextFilter);
			
			if (callbackFunction) then
				local success, result = pcall(callbackFunction, text or "");
				if (success) then
					text = tostring(result) or text;
				else
					print(result);
				end
			end
		end
	end
	
	local formattedIcon = module.icon and ICON_PATTERN:format(module.icon) or "";
	
	if (candyBar.data.showIcon or text == "") then
		text = string.format("%s%s", formattedIcon, text);
	end
	
	candyBar.text:SetText(text);
	
	local fontPath = LibSharedMedia:Fetch("font", self.db.global.fontFace);
	
	candyBar.text:SetFont(fontPath, candyBar.data.fontSize, candyBar.data.fontOutline or "");
	candyBar.text:SetShadowColor(0, 0, 0, 0.9);
	candyBar.text:SetShadowOffset(0, -1);
	
	local fixedWidth = tonumber(candyBar.data.fixedWidth) or 0;
	if (candyBar.data.fixedWidth > 0) then
		candyBar:SetWidth(candyBar.data.fixedWidth);
	else
		local stringWidth = candyBar.text:GetStringWidth();
		stringWidth = math.max(10, math.ceil(stringWidth));
		candyBar:SetWidth(stringWidth + 6);
	end
end

function addon:AttributeChanged(event, name, key, value)
	if (key == "text" or key == "label" or key == "icon") then
		addon:UpdateCandyText(name);
	end
end

function addon:LockBars()
	self.db.global.locked = true;
	
	for broker, candyBar in pairs(addon.ActiveBars) do
		candyBar.configBackground:Hide();
		candyBar.background:Show();
		
		if (candyBar.data.isClickthrough) then
			candyBar:EnableMouse(false);
		end
		
		-- Update absolute coordinates just in case
		candyBar.data.anchors[1].absolute = {
			x = candyBar:GetLeft(),
			y = candyBar:GetBottom(),
		};
	end
	
	addon:UpdateVisibility();
end

function addon:UnlockBars()
	self.db.global.locked = false;
	
	for broker, candyBar in pairs(addon.ActiveBars) do
		candyBar.configBackground:Show();
		candyBar.background:Hide();
		
		candyBar:EnableMouse(true);
	end
	
	addon:UpdateVisibility();
end

function addon:ToggleConfigBackground(configBackgroundEnabled)
	if (self.db.global.locked) then
		return;
	end
	
	for broker, candyBar in pairs(addon.ActiveBars) do
		candyBar:EnableMouse(configBackgroundEnabled);
		candyBar.configBackground:SetShown(configBackgroundEnabled);
		candyBar.background:SetShown(not configBackgroundEnabled);
	end
end

function addon:UpdateBackgroundColors()
	for broker, candyBar in pairs(addon.ActiveBars) do
		local r, g, b, a = unpack(candyBar.data.backgroundColor);
		candyBar.background:SetVertexColor(r, g, b, a);
	end
end

function CandyBarFrame_OnLoad(self)
	self:RegisterForClicks("LeftButtonUp", "MiddleButtonUp", "RightButtonUp");
	self:EnableMouse(true);
	
	addon:ChangeBackground(self, false);
end

function addon:ChangeJustify(candyBar, newJustify)
	if (not candyBar or not newJustify) then return end
	if (candyBar.data.justify == newJustify) then return end
	
	candyBar.data.justify = newJustify;
	addon:ConvertAnchor(candyBar, newJustify);
	
	addon:UpdateCandyText(candyBar.broker);
end

function addon:ConvertAnchor(frame, justify)
	if (not frame or not justify) then return end
	
	local numAnchors = #frame.data.anchors;
	local anchor = frame.data.anchors[1];
	
	-- Only convert anchor if the frame doesn't have a parent
	if (numAnchors == 1 and not anchor.relativeTo) then
		local left = frame:GetLeft()
		local right = frame:GetRight()
		local top = frame:GetTop()
		local bottom = frame:GetBottom()
		local centerX, centerY = frame:GetCenter();
		
		-- Coordinates translation based on current anchor
		
		local translated = {
			["TOPLEFT"]		= { left, 		top },
			["TOP"]			= { centerX, 	top },
			["TOPRIGHT"]	= { right, 		top },
			["LEFT"]		= { left, 		centerY },
			["CENTER"]		= { centerX, 	centerY },
			["RIGHT"]		= { right, 		centerY },
			["BOTTOMLEFT"]	= { left,		bottom },
			["BOTTOM"]		= { centerX,	bottom },
			["BOTTOMRIGHT"]	= { right,		bottom },
		};
		
		-- JUSTIFY -> CURRENT ANCHOR -> NEW POINT
		
		local newAnchor = {
			["LEFT"] 	= {
				["TOPLEFT"]		= "TOPLEFT",
				["TOP"]			= "TOPLEFT",
				["TOPRIGHT"]	= "TOPLEFT",
				["LEFT"]		= "LEFT",
				["CENTER"]		= "LEFT",
				["RIGHT"]		= "LEFT",
				["BOTTOMLEFT"]	= "BOTTOMLEFT",
				["BOTTOM"]		= "BOTTOMLEFT",
				["BOTTOMRIGHT"]	= "BOTTOMLEFT",
			},
			["CENTER"]	= {
				["TOPLEFT"]		= "TOP",
				["TOP"]			= "TOP",
				["TOPRIGHT"]	= "TOP",
				["LEFT"]		= "CENTER",
				["CENTER"]		= "CENTER",
				["RIGHT"]		= "CENTER",
				["BOTTOMLEFT"]	= "BOTTOM",
				["BOTTOM"]		= "BOTTOM",
				["BOTTOMRIGHT"]	= "BOTTOM",
			},
			["RIGHT"]	= {
				["TOPLEFT"]		= "TOPRIGHT",
				["TOP"]			= "TOPRIGHT",
				["TOPRIGHT"]	= "TOPRIGHT",
				["LEFT"]		= "RIGHT",
				["CENTER"]		= "RIGHT",
				["RIGHT"]		= "RIGHT",
				["BOTTOMLEFT"]	= "BOTTOMRIGHT",
				["BOTTOM"]		= "BOTTOMRIGHT",
				["BOTTOMRIGHT"]	= "BOTTOMRIGHT",
			},
		};
		
		local point = newAnchor[justify][anchor.point];
		local x, y = unpack(translated[point]);
		
		if (point) then
			frame:ClearAllPoints();
			frame:SetPoint(point, nil, "BOTTOMLEFT", x, y);
			
			anchor.point, anchor.relativePoint, anchor.x, anchor.y = point, "BOTTOMLEFT", x, y;
		end
	end
	
	-- return false;
end

function CandyBarFrame_OnClick(self, ...)
	if (addon.db.global.locked) then
		local module = LibDataBroker:GetDataObjectByName(self.broker);
		if (module.OnClick) then
			module.OnClick(self, ...);
		end
	else
		local button = ...;
		if (button == "RightButton") then
			addon:OpenCandyOptions(self, self.broker);
		end
	end
end

function addon:GetAnchors(frame)
	local B, T = "BOTTOM", "TOP";
	local x, y = frame:GetCenter();
	
	if (y < _G.GetScreenHeight() / 2) then
		return B, T;
	else
		return T, B;
	end
end

function addon:PrepareTooltip(frame, anchorFrame)
	if (not frame or not anchorFrame) then return end
	
	frame:ClearAllPoints()
	if (frame.SetOwner) then
		frame:SetOwner(anchorFrame, "ANCHOR_NONE");
	end	
	
	local a1, a2 = addon:GetAnchors(anchorFrame);
	frame:SetPoint(a1, anchorFrame, a2);
end

function CandyBarFrame_OnEnter(self)
	if (not addon.db.global.locked) then return end
	if (not self.data.showTooltip) then return end
	if (InCombatLockdown()) then return end
	
	local module = LibDataBroker:GetDataObjectByName(self.broker);
	
	if (module.tooltip) then
		addon:PrepareTooltip(module.tooltip, self);
		if (module.tooltiptext) then
			module.tooltip:SetText(module.tooltiptext);
		end
		module.tooltip:Show();
	
	elseif (module.OnTooltipShow) then
		addon:PrepareTooltip(GameTooltip, self);
		module.OnTooltipShow(GameTooltip);
		GameTooltip:Show();
	
	elseif (module.tooltiptext) then
		addon:PrepareTooltip(GameTooltip, self)
		GameTooltip:SetText(module.tooltiptext);
		GameTooltip:Show();		
	
	elseif (module.OnEnter) then
		module.OnEnter(self);
	end
end

function CandyBarFrame_OnLeave(self)
	if (not self.data.showTooltip) then return end
	
	local module = LibDataBroker:GetDataObjectByName(self.broker);
	
	if (module.OnTooltipShow) then
		GameTooltip:Hide();
	end
	
	if (module.OnLeave) then
		module.OnLeave(self);
	elseif (module.tooltip) then
		module.tooltip:Hide();
	else
		GameTooltip:Hide();
	end
end

function CandyBarFrame_OnMouseDown(self, button)
	if (addon.db.global.locked) then return end
	
	if (button == "LeftButton") then
		CloseMenus();
		GameTooltip:Hide();
		
		self:StartMoving();
		self.isMoving = true;
	end
end

local function distance(p1, p2)
	return math.abs(p2 - p1);
end

local function distance2D(x1, y1, x2, y2)
	return math.sqrt((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1));
end

function addon:GetFrameKeyPoints(frame)
	local left, bottom, width, height = frame:GetRect();
	return left, left + width, bottom + height, bottom;
end

function addon:FindClosestFrame(frame, tolerance)
	if (not frame) then return nil end
	local tolerance = tolerance or 100;
	
	local x, y = frame:GetCenter();
	
	local nearestFrame = nil;
	local nearestDist = -1;
	
	for broker, candyBar in pairs(addon.ActiveBars) do
		if (frame.broker ~= broker) then
			local ax, ay = candyBar:GetCenter();
			
			local dist = distance2D(x, y, ax, ay);
			if (dist < tolerance and dist < nearestDist or nearestDist < 0) then
				nearestDist = dist;
				nearestFrame = candyBar;
			end
		end
	end
	
	return nearestFrame;
end

function addon:FrameHasParent(frame)
	if (not frame) then return end
	
	local _, relativeTo = frame:GetPoint();
	return relativeTo ~= nil;
end

function addon:VerticalSnap(frame, tolerance)
	if (not frame) then return end
	
	local numPoints = frame:GetNumPoints();
	if (numPoints > 1) then return end
	
	local point, relativeTo, relativePoint, x, y = frame:GetPoint();
	local bottom = frame:GetBottom();
	
	for broker, otherFrame in pairs(addon.ActiveBars) do
		if (frame.broker ~= broker and not addon:FrameHasParent(otherFrame)) then
			local obottom = otherFrame:GetBottom();
			
			local diff = bottom - obottom;
			
			if (distance(bottom, obottom) <= tolerance) then
				frame:SetPoint(point, relativeTo, relativePoint, x, y - diff);
				return true;
			end
		end
	end
end

function CandyBarFrame_OnMouseUp(self, button)
	if (addon.db.global.locked) then return end
	
	if (self.isMoving and button == "LeftButton") then
		self:StopMovingOrSizing();
		self.isMoving = false;
		
		if (not IsAltKeyDown() and FlyPaper) then
			local offset = IsShiftKeyDown() and 5 or 0;
			
			local foundSnap = false;
			for broker, candyBar in pairs(addon.ActiveBars) do
				if (self.broker ~= candyBar.broker) then
					local stickyPoint = FlyPaper.Stick(self, candyBar, 12 + offset, offset, offset);
					if (stickyPoint) then
						foundSnap = true;
						break;
					end
				end
			end
			
			if (not foundSnap) then
				addon:VerticalSnap(self, 8);
			end
		end
		
		self.data.anchors = {};
		
		local numPoints = self:GetNumPoints();
		
		for index = 1, numPoints do
			local point, relativeTo, relativePoint, x, y = self:GetPoint(index);
			
			local hasParent = (relativeTo ~= nil);
			addon:ChangeBackground(self, hasParent);
			
			if (relativeTo) then
				relativeTo = relativeTo:GetName();
			end
			
			tinsert(self.data.anchors, {
				point = point,
				relativeTo = relativeTo,
				relativePoint = relativePoint,
				x = x,
				y = y,
				absolute = {
					x = self:GetLeft(),
					y = self:GetBottom(),
				},
			});
		end
		
		if (numPoints == 1) then
			addon:ConvertAnchor(self, self.data.justify);
		end
	end
end

function CandyBarFrame_OnMouseWheel(self, delta)
	
end
