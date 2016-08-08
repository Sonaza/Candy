------------------------------------------------------------
-- Candy by Sonaza
------------------------------------------------------------

local ADDON_NAME, SHARED_DATA = ...;

local _G = getfenv(0);

local LibStub = LibStub;
local A = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME, "AceEvent-3.0");
_G[ADDON_NAME] = A;
SHARED_DATA[1] = A;

local ldb = LibStub("LibDataBroker-1.1");
local AceDB = LibStub("AceDB-3.0");

local LSM = LibStub("LibSharedMedia-3.0");
LSM:Register("font", "DorisPP", [[Interface\Addons\Candy\media\DORISPP.ttf]]);

local CANDY_DEFAULT_FONT = "DorisPP";

local ICON_PATTERN = "|T%s:12:12:0:0|t ";

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
A.frameStrata = frameStrata;

-- ENUMS
SHARED_DATA[2] = {
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
local E = SHARED_DATA[2];

function A:OnInitialize()
	A:RegisterEvent("PLAYER_ENTERING_WORLD");
	A:RegisterEvent("ZONE_CHANGED");
	A:RegisterEvent("ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED");
	
	A:RegisterEvent("PLAYER_REGEN_DISABLED");
	A:RegisterEvent("PLAYER_REGEN_ENABLED");
	
	A:RegisterEvent("PET_BATTLE_OPENING_START");
	A:RegisterEvent("PET_BATTLE_OVER");
	
	A:RegisterEvent("MODIFIER_STATE_CHANGED");
end

function A:OnEnable()
	SLASH_CANDY1	= "/candy";
	SLASH_CANDY2	= "/cd";
	SlashCmdList["CANDY"] = function(command) A:ShowOptions(command); end
	
	local defaults = {
		global = {
			enabled = true,
			locked = false,
			
			fontFace = CANDY_DEFAULT_FONT,
			fontSize = 10,
			fontOutline = nil,
			frameStrata = "MEDIUM",
			
			bars = {
				["*"] = {
					enabled = false,
					showTooltip = true,
					isClickthrough = false,
					stripColor = false,
					
					showIcon = false,
					
					fontSize = 10,
					fontOutline = nil,
					frameStrata = "MEDIUM",
					
					luaTextFilter = nil,
					
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
	
	A.ActiveBars = {};
	
	CreateFrame("Frame"):SetScript("OnUpdate", function(self, elapsed)
		self.elapsed = (self.elapsed or 0) + elapsed;
		
		if(self.elapsed >= 0.02) then
			A:UpdateVisibility();
			self.elapsed = 0;
		end
	end);
end

function A:PLAYER_ENTERING_WORLD()
	A:RestoreBars();
	A:UnregisterEvent("PLAYER_ENTERING_WORLD");
end

function A:ZONE_CHANGED()
	A:UpdateVisibility();
end

function A:PLAYER_REGEN_DISABLED()
	A:LockBars();
	A:UpdateVisibility(true);
end

function A:PLAYER_REGEN_ENABLED()
	A:UpdateVisibility(false);
end

function A:MODIFIER_STATE_CHANGED()
	A:UpdateVisibility();
end

function A:PET_BATTLE_OPENING_START()
	A:UpdateVisibility();
end

function A:PET_BATTLE_OVER()
	A:UpdateVisibility();
end

function A:PlayerInInstance()
	local name, instanceType = GetInstanceInfo();
	
	if(instanceType == "none" or C_Garrison.IsOnGarrisonMap()) then
		return false;
	end
	
	return true, instanceType;
end

function A:IsPlayerInAGroup()
	return IsInRaid() or IsInGroup();
end

function A:UpdateCandyBars()
	for broker, candyBar in pairs(A.ActiveBars) do
		candyBar:SetFrameStrata(candyBar.data.frameStrata);
		A:UpdateCandyText(broker);
	end
	
	A:UpdateVisibility();
end

function A:StripColor(text)
	if(not text) then return "" end
	return string.gsub(string.gsub(text, "\124c%w%w%w%w%w%w%w%w", ""), "\124r", "");
end

function A:UpdateVisibility(inCombat)
	local inCombat = inCombat or InCombatLockdown();
	
	for broker, candyBar in pairs(A.ActiveBars) do
		local shouldShow = true;
		
		if(self.db.global.locked) then
			local visibility = candyBar.data.visibility;
			
			if(inCombat and visibility.mode == E.VISIBILITY_OUT_OF_COMBAT) then
				shouldShow = false;
			elseif(not inCombat and visibility.mode == E.VISIBILITY_IN_COMBAT) then
				shouldShow = false;
			end
			
			if(visibility.hideInPetBattle and C_PetBattles.IsInBattle()) then
				shouldShow = false;
			end
			
			if(shouldShow and visibility.instanceMode ~= E.INSTANCEMODE_EVERYWHERE) then
				local inInstance = A:PlayerInInstance();
				
				if(not inInstance and visibility.instanceMode == E.INSTANCEMODE_INSIDE) then
					shouldShow = false;
				elseif(inInstance and visibility.instanceMode == E.INSTANCEMODE_OUTSIDE) then
					shouldShow = false;
				end
			end
			
			if(shouldShow and visibility.groupMode ~= E.GROUPMODE_ALWAYS) then
				local playerInGroup = A:IsPlayerInAGroup();
				
				if(visibility.groupMode == E.GROUPMODE_SOLO and playerInGroup) then
					shouldShow = false;
				elseif(visibility.groupMode == E.GROUPMODE_INPARTY and not playerInGroup) then
					shouldShow = false;
				end
			end
			
			if(shouldShow) then
				if(visibility.showCtrl and not IsControlKeyDown()) then shouldShow = false; end
				if(visibility.showShift and not IsShiftKeyDown()) then shouldShow = false; end
				if(visibility.showAlt and not IsAltKeyDown()) then shouldShow = false; end
			end
			
			if(shouldShow and visibility.customLua) then
				local script = string.format('return (function(text, icon) %s end)(...)', visibility.customLua or "return true;");
				local callbackFunction, scriptError = loadstring(script, "Candy-Visibility-" .. broker);
				
				if(callbackFunction) then
					local module = ldb:GetDataObjectByName(broker);
					
					local result = callbackFunction(A:StripColor(module.text), module.icon);
					shouldShow = shouldShow and result;
				end
			end
		end
		
		if(shouldShow and not candyBar.isVisible) then
			candyBar.fadeout:Stop();
			candyBar.fadein:Play();
		elseif(not shouldShow and candyBar.isVisible) then
			candyBar.fadein:Stop();
			candyBar.fadeout:Play();
		end
	end
end

function CandyFrame_OnFadeIn(self)
	if(InCombatLockdown()) then return end
	if(not self:GetParent().data.isClickthrough) then
		self:GetParent():EnableMouse(true);
	end
	self:GetParent().isVisible = true;
	self:GetParent():Show();
	A:UpdateCandyText(self:GetParent().broker);
end

function CandyFrame_OnFadeOut(self)
	if(InCombatLockdown()) then return end
	self:GetParent():EnableMouse(false);
	self:GetParent().isVisible = false;
end

function CandyFrame_OnFadeOutFinish(self)
	self:GetParent().text:SetText("");
	if(not InCombatLockdown()) then
		self:GetParent():Hide();
	end
end

function A:AddCandy(broker)
	local broker = strtrim(broker or "");
	
	A:UnlockBars();
	
	local candyBar = A:CreateCandyBar(broker, true);
	if(candyBar) then
		candyBar.data = self.db.global.bars[broker];
		A:UpdateCandyText(broker);
	end
end

function A:RemoveCandy(broker)
	if(self.db.global.bars[broker]) then
		A.ActiveBars[broker]:Hide();
		
		self.db.global.bars[broker] = nil;
		A.ActiveBars[broker] = nil;
		
		ldb.UnregisterCallback(self, "LibDataBroker_AttributeChanged_" .. broker);
	end
end

function A:GetCandy(broker)
	return A.ActiveBars[broker], ldb:GetDataObjectByName(broker);
end

function A:CreateCandyBar(broker, isNew)
	local module = ldb:GetDataObjectByName(broker);
	if(not module) then return false end
	
	local frameName = string.format("Candy%sFrame", broker);
	
	local candyBar = _G[frameName];
	if(not candyBar) then
		candyBar = CreateFrame("Button", frameName, UIParent, "CandyBarFrameTemplate");
		candyBar.broker = broker;
	else
		candyBar:Show();
	end
	
	candyBar.isVisible = true;
	
	local settings = self.db.global.bars[broker];
	
	if(isNew) then
		settings.enabled = true;
		
		settings.fontSize = self.db.global.fontSize;
		settings.fontOutline = self.db.global.fontOutline;
		settings.frameStrata = self.db.global.frameStrata;
	end
	
	candyBar:ClearAllPoints();
	candyBar:SetPoint("CENTER", UIParent, "CENTER", 0, 0);
	candyBar.text:SetText(broker);
	
	if(isNew) then
		settings.anchors[1].absolute = {
			x = candyBar:GetLeft(),
			y = candyBar:GetBottom(),
		};
	end
	
	candyBar:SetFrameStrata(self.db.global.bars[broker].frameStrata);
	
	A.ActiveBars[broker] = candyBar;
	
	ldb.RegisterCallback(self, "LibDataBroker_AttributeChanged_" .. broker, "AttributeChanged");
	
	return candyBar, module;
end

function A:RestoreBars()
	if(not A.db.global.enabled) then return end
	
	for broker, data in pairs(self.db.global.bars) do
		local candyBar, module = A:CreateCandyBar(broker);
		
		if(candyBar) then
			candyBar.data = data;
			
			candyBar:SetFrameStrata(data.frameStrata);
		end
	end
	
	for broker, candyBar in pairs(A.ActiveBars) do
		candyBar:ClearAllPoints();
		
		-- Actually there will never be more than 1 anchor per frame
		local anchor = candyBar.data.anchors[1];
		
		local relativeFrame;
		if(anchor.relativeTo) then
			relativeFrame = _G[anchor.relativeTo];
		end
		
		local useAbsoluteAnchor = anchor.relativeTo and not _G[anchor.relativeTo];
		
		if(not useAbsoluteAnchor) then
			candyBar:SetPoint(anchor.point, relativeFrame or UIParent, anchor.relativePoint, anchor.x, anchor.y);
		else
			candyBar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", anchor.absolute.x, anchor.absolute.y);
		end
		
		local hasParent = (relativeFrame ~= nil);
		A:ChangeBackground(candyBar, hasParent);
	end
	
	if(self.db.global.locked) then
		A:LockBars();
	end
	
	A:UpdateCandyBars();
end

function A:ChangeBackground(frame, hasParent)
	if(not frame) then return end
	
	if(hasParent) then
		frame.background:SetVertexColor(0.0, 0.0, 0.0, 0.4);
	else
		frame.background:SetVertexColor(1.0, 1.0, 0.0, 0.2);
	end
end

function A:ResetAnchors()
	local numBrokers = 0;
	for broker, candyBar in pairs(A.ActiveBars) do
		numBrokers = numBrokers + 1;
	end
	
	local index = 0;
	for broker, candyBar in pairs(A.ActiveBars) do
		local y = index * 20 - (numBrokers / 2 * 20);
		
		candyBar:ClearAllPoints();
		candyBar:SetPoint("CENTER", UIParent, "CENTER", 0, y);
		
		A:ChangeBackground(candyBar, false);
		
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

function A:GetModuleText(module)
	if(module.text) then return tostring(module.text) end
	if(module.label) then return tostring(module.label) end
	return "";
end

function A:UpdateCandyText(broker)
	local candyBar, module = A:GetCandy(broker);
	if(not candyBar or not module) then return end
	
	candyBar.text:SetJustifyH(candyBar.data.justify);
	
	local text = A:GetModuleText(module);
	
	if(candyBar.data.stripColor) then
		text = A:StripColor(text);
	end
	
	if(candyBar.data.luaTextFilter ~= nil) then
		local script = string.format('return (function(text) %s end)(...)', candyBar.data.luaTextFilter or "return text;");
		local filterFunction, scriptError = loadstring(script, "Candy-TextFilter-" .. candyBar.broker);
		
		if(filterFunction) then
			local result = filterFunction(text or "");
			text = tostring(result) or text;
		end
	end
	
	if(candyBar.data.showIcon and module.icon) then
		text = string.format("%s%s", ICON_PATTERN:format(module.icon) or "", text)
	end
	
	candyBar.text:SetText(text);
	
	local fontPath = LSM:Fetch("font", self.db.global.fontFace);
	
	candyBar.text:SetFont(fontPath, candyBar.data.fontSize, candyBar.data.fontOutline or "");
	candyBar.text:SetShadowColor(0, 0, 0, 0.9);
	candyBar.text:SetShadowOffset(0, -1);
	
	local stringWidth = candyBar.text:GetStringWidth();
	stringWidth = math.max(10, math.ceil(stringWidth));
	candyBar:SetWidth(stringWidth + 6);
end

function A:UpdateCandy()
	for broker, candyBar in pairs(A.ActiveBars) do
		local module = ldb:GetDataObjectByName(broker);
		if(module) then
			A:UpdateCandyText(broker);
		end
	end
end

function A:AttributeChanged(event, name, key, value)
	if(key == "text" or key == "icon") then
		A:UpdateCandyText(name);
	end
end

function A:LockBars()
	self.db.global.locked = true;
	
	for broker, candyBar in pairs(A.ActiveBars) do
		candyBar.background:Hide();
		if(candyBar.data.isClickthrough) then
			candyBar:EnableMouse(false);
		end
		
		-- Update absolute coordinates just in case
		candyBar.data.anchors[1].absolute = {
			x = candyBar:GetLeft(),
			y = candyBar:GetBottom(),
		};
	end
	
	A:UpdateVisibility();
end

function A:UnlockBars()
	self.db.global.locked = false;
	
	for broker, candyBar in pairs(A.ActiveBars) do
		candyBar.background:Show();
		candyBar:EnableMouse(true);
	end
	
	A:UpdateVisibility();
end

function CandyBarFrame_OnLoad(self)
	self:RegisterForClicks("LeftButtonUp", "MiddleButtonUp", "RightButtonUp");
	self:EnableMouse(true);
	
	A:ChangeBackground(self, false);
end

function A:ChangeJustify(candyBar, newJustify)
	if(not candyBar or not newJustify) then return end
	if(candyBar.data.justify == newJustify) then return end
	
	candyBar.data.justify = newJustify;
	A:ConvertAnchor(candyBar, newJustify);
	
	A:UpdateCandyText(candyBar.broker);
end

function A:ConvertAnchor(frame, justify)
	if(not frame or not justify) then return end
	
	local numAnchors = #frame.data.anchors;
	local anchor = frame.data.anchors[1];
	
	-- Only convert anchor if the frame doesn't have a parent
	if(numAnchors == 1 and not anchor.relativeTo) then
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
		
		-- print(anchor.point, anchor.x, anchor.y, "    TO    ", point, nil, "BOTTOMLEFT", x, y);
		
		if(point) then
			frame:ClearAllPoints();
			frame:SetPoint(point, nil, "BOTTOMLEFT", x, y);
			
			anchor.point, anchor.relativePoint, anchor.x, anchor.y = point, "BOTTOMLEFT", x, y;
		end
	end
	
	-- return false;
end

function CandyBarFrame_OnClick(self, ...)
	if(A.db.global.locked) then
		local module = ldb:GetDataObjectByName(self.broker);
		if(module.OnClick) then
			module.OnClick(self, ...);
		end
	else
		local button = ...;
		if(button == "RightButton") then
			A:OpenCandyOptions(self, self.broker);
		end
	end
end

function A:GetAnchors(frame)
	local B, T = "BOTTOM", "TOP";
	local x, y = frame:GetCenter();
	
	if(y < _G.GetScreenHeight() / 2) then
		return B, T;
	else
		return T, B;
	end
end

function A:PrepareTooltip(frame, anchorFrame)
	if(not frame or not anchorFrame) then return end
	
	frame:ClearAllPoints()
	if(frame.SetOwner) then
		frame:SetOwner(anchorFrame, "ANCHOR_NONE");
	end	
	
	local a1, a2 = A:GetAnchors(anchorFrame);
	frame:SetPoint(a1, anchorFrame, a2);
end

function CandyBarFrame_OnEnter(self)
	if(not A.db.global.locked) then return end
	if(not self.data.showTooltip) then return end
	if(InCombatLockdown()) then return end
	
	local module = ldb:GetDataObjectByName(self.broker);
	
	if(module.tooltip) then
		A:PrepareTooltip(module.tooltip, self);
		if(module.tooltiptext) then
			module.tooltip:SetText(module.tooltiptext);
		end
		module.tooltip:Show();
	
	elseif(module.OnTooltipShow) then
		A:PrepareTooltip(GameTooltip, self);
		module.OnTooltipShow(GameTooltip);
		GameTooltip:Show();
	
	elseif(module.tooltiptext) then
		A:PrepareTooltip(GameTooltip, self)
		GameTooltip:SetText(module.tooltiptext);
		GameTooltip:Show();		
	
	elseif(module.OnEnter) then
		module.OnEnter(self);
	end
end

function CandyBarFrame_OnLeave(self)
	if(not self.data.showTooltip) then return end
	
	local module = ldb:GetDataObjectByName(self.broker);
	
	if(module.OnTooltipShow) then
		GameTooltip:Hide();
	end
	
	if(module.OnLeave) then
		module.OnLeave(self);
	elseif(module.tooltip) then
		module.tooltip:Hide();
	else
		GameTooltip:Hide();
	end
end

function CandyBarFrame_OnMouseDown(self, button)
	if(A.db.global.locked) then return end
	
	if(button == "LeftButton") then
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

function A:GetFrameKeyPoints(frame)
	local left, bottom, width, height = frame:GetRect();
	return left, left + width, bottom + height, bottom;
end

function A:FindClosestFrame(frame, tolerance)
	if(not frame) then return nil end
	local tolerance = tolerance or 100;
	
	local x, y = frame:GetCenter();
	
	local nearestFrame = nil;
	local nearestDist = -1;
	
	for broker, candyBar in pairs(A.ActiveBars) do
		if(frame.broker ~= broker) then
			local ax, ay = candyBar:GetCenter();
			
			local dist = distance2D(x, y, ax, ay);
			if(dist < tolerance and dist < nearestDist or nearestDist < 0) then
				nearestDist = dist;
				nearestFrame = candyBar;
			end
		end
	end
	
	return nearestFrame;
end

function A:FrameHasParent(frame)
	if(not frame) then return end
	
	local _, relativeTo = frame:GetPoint();
	return relativeTo ~= nil;
end

function A:VerticalSnap(frame, tolerance)
	if(not frame) then return end
	
	local numPoints = frame:GetNumPoints();
	if(numPoints > 1) then return end
	
	local point, relativeTo, relativePoint, x, y = frame:GetPoint();
	local bottom = frame:GetBottom();
	
	for broker, otherFrame in pairs(A.ActiveBars) do
		if(frame.broker ~= broker and not A:FrameHasParent(otherFrame)) then
			local obottom = otherFrame:GetBottom();
			
			local diff = bottom - obottom;
			
			if(distance(bottom, obottom) <= tolerance) then
				frame:SetPoint(point, relativeTo, relativePoint, x, y - diff);
				return true;
			end
		end
	end
end

function CandyBarFrame_OnMouseUp(self, button)
	if(A.db.global.locked) then return end
	
	if(self.isMoving and button == "LeftButton") then
		self:StopMovingOrSizing();
		self.isMoving = false;
		
		if(not IsAltKeyDown() and FlyPaper) then
			local offset = IsShiftKeyDown() and 5 or 0;
			
			local foundSnap = false;
			for broker, candyBar in pairs(A.ActiveBars) do
				if(self.broker ~= candyBar.broker) then
					local stickyPoint = FlyPaper.Stick(self, candyBar, 12 + offset, offset, offset);
					if(stickyPoint) then
						foundSnap = true;
						-- print(self.broker, "sticky on", candyBar.broker, stickyPoint);
						break;
					end
				end
			end
			
			if(not foundSnap) then
				A:VerticalSnap(self, 8);
			end
		end
		
		self.data.anchors = {};
		
		local numPoints = self:GetNumPoints();
		
		for index = 1, numPoints do
			local point, relativeTo, relativePoint, x, y = self:GetPoint(index);
			
			local hasParent = (relativeTo ~= nil);
			A:ChangeBackground(self, hasParent);
			
			if(relativeTo) then
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
		
		if(numPoints == 1) then
			A:ConvertAnchor(self, self.data.justify);
		end
	end
end

function CandyBarFrame_OnMouseWheel(self, delta)
	
end
