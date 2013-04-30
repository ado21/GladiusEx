local GladiusEx = _G.GladiusEx
local L = LibStub("AceLocale-3.0"):GetLocale("GladiusEx")
local LSM

-- global functions
local strfind = string.find
local pairs = pairs
local min = math.min
local GetTime = GetTime
local GetSpellInfo, UnitCastingInfo, UnitChannelInfo = GetSpellInfo, UnitCastingInfo, UnitChannelInfo

local CastBar = GladiusEx:NewGladiusExModule("CastBar", true, {
	castBarAttachTo = "ClassIcon",

	castBarHeight = 12,
	castBarAdjustWidth = true,
	castBarWidth = 150,

	castBarOffsetX = 0,
	castBarOffsetY = 0,

	castBarAnchor = "TOPLEFT",
	castBarRelativePoint = "BOTTOMLEFT",

	castBarInverse = false,
	castBarColor = { r = 1, g = 1, b = 0, a = 1 },
	castBarBackgroundColor = { r = 1, g = 1, b = 1, a = 0.3 },
	castBarTexture = "Minimalist",

	castIcon = true,
	castIconPosition = "LEFT",

	castText = true,
	castTextSize = 11,
	castTextColor = { r = 2.55, g = 2.55, b = 2.55, a = 1 },
	castTextAlign = "LEFT",
	castTextOffsetX = 0,
	castTextOffsetY = 0,

	castTimeText = true,
	castTimeTextSize = 11,
	castTimeTextColor = { r = 2.55, g = 2.55, b = 2.55, a = 1 },
	castTimeTextAlign = "RIGHT",
	castTimeTextOffsetX = 0,
	castTimeTextOffsetY = 0,
})

function CastBar:OnEnable()
	self:RegisterEvent("UNIT_SPELLCAST_START")
	self:RegisterEvent("UNIT_SPELLCAST_STOP")
	self:RegisterEvent("UNIT_SPELLCAST_DELAYED")
	self:RegisterEvent("UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_STOP")
	self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_STOP")
	self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
	self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_DELAYED")
	self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_STOP")

	LSM = GladiusEx.LSM

	self.isBar = true

	if (not self.frame) then
		self.frame = {}
	end
end

function CastBar:OnDisable()
	self:UnregisterAllEvents()

	for unit in pairs(self.frame) do
		self.frame[unit]:SetAlpha(0)
	end
end

function CastBar:GetAttachTo()
	return self.db.castBarAttachTo
end

function CastBar:GetModuleAttachPoints()
	return {
		["CastBar"] = L["CastBar"],
		["CastBarIcon"] = L["CastBar Icon"],
	}
end

function CastBar:GetAttachFrame(unit, point)
	if not self.frame[unit] then
		self:CreateBar(unit)
	end

	if point == "CastBar" then
		return self.frame[unit]
	else
		return self.frame[unit].icon
	end
end

local function CastUpdate(self)
	if self.isCasting or self.isChanneling then
		local currentTime = min(self.endTime, GetTime())
		local value = self.endTime - currentTime

		if (self.isChanneling and not CastBar.db.castBarInverse) or (self.isCasting and CastBar.db.castBarInverse) then
			self:SetValue(value)
		else
			self:SetValue(self.endTime - self.startTime - value)
		end

		if self.delay > 0 then
			self.timeText:SetFormattedText("+%.2f %.2f", self.delay, value)
		else
			self.timeText:SetFormattedText("%.2f", value)
		end
	else
		self:SetScript("OnUpdate", nil)
	end
end

local function UpdateCastText(f, spell, rank)
	if rank ~= "" then
		f.castText:SetFormattedText("%s (%s)", spell, rank)
	else
		f.castText:SetText(spell)
	end
end

function CastBar:UNIT_SPELLCAST_START(event, unit)
	local f = self.frame[unit]
	if not f then return end

	local spell, rank, displayName, icon, startTime, endTime, isTradeSkill = UnitCastingInfo(unit)
	if (spell) then
		f.spellName = spell
		f.isChanneling = false
		f.isCasting = true
		f.startTime = startTime / 1000
		f.endTime = endTime / 1000
		f.delay = 0
		f:SetMinMaxValues(0, (endTime - startTime) / 1000)
		f.icon:SetTexture(icon)
		f:SetScript("OnUpdate", CastUpdate)
		CastUpdate(f)

		UpdateCastText(f, spell, rank)
	end
end

function CastBar:UNIT_SPELLCAST_CHANNEL_START(event, unit)
	local f = self.frame[unit]
	if not f then return end

	local spell, rank, displayName, icon, startTime, endTime, isTradeSkill = UnitChannelInfo(unit)
	if (spell) then
		f.spellName = spell
		f.isChanneling = true
		f.isCasting = false
		f.startTime = startTime / 1000
		f.endTime = endTime / 1000
		f.delay = 0
		f:SetMinMaxValues(0, (endTime - startTime) / 1000)
		f.icon:SetTexture(icon)
		f:SetScript("OnUpdate", CastUpdate)
		CastUpdate(f)

		UpdateCastText(f, spell, rank)
	end
end

function CastBar:UNIT_SPELLCAST_STOP(event, unit, spell)
	if not self.frame[unit] then return end

	if self.frame[unit].spellName ~= spell or (event == "UNIT_SPELLCAST_FAILED" and self.frame[unit].isChanneling) then return end

	self:CastEnd(self.frame[unit])
end

function CastBar:UNIT_SPELLCAST_DELAYED(event, unit)
	if not self.frame[unit] then return end
	if not self.frame[unit].isCasting or self.frame[unit].isChanneling then return end

	local spell, rank, displayName, icon, startTime, endTime, isTradeSkill
	if event == "UNIT_SPELLCAST_DELAYED" then
		spell, rank, displayName, icon, startTime, endTime, isTradeSkill = UnitCastingInfo(unit)
	else
		spell, rank, displayName, icon, startTime, endTime, isTradeSkill = UnitChannelInfo(unit)
	end

	if not startTime or not endTime then return end

	if event == "UNIT_SPELLCAST_DELAYED" then
		self.frame[unit].delay = self.frame[unit].delay + (startTime / 1000 - self.frame[unit].startTime)
	else
		self.frame[unit].delay = self.frame[unit].delay + (self.startTime - startTime / 1000)
	end

	self.frame[unit].startTime = startTime / 1000
	self.frame[unit].endTime = endTime / 1000
	self.frame[unit]:SetMinMaxValues(0, (endTime - startTime) / 1000)
end

function CastBar:CastEnd(bar)
	bar.isCasting = false
	bar.isChanneling = false
	bar.timeText:SetText("")
	bar.castText:SetText("")
	bar.icon:SetTexture("")
	bar:SetValue(0)
end

function CastBar:CreateBar(unit)
	local button = GladiusEx.buttons[unit]
	if (not button) then return end

	-- create bar + text
	self.frame[unit] = CreateFrame("STATUSBAR", "GladiusEx" .. self:GetName() .. unit, button)
	self.frame[unit].background = self.frame[unit]:CreateTexture("GladiusEx" .. self:GetName() .. unit .. "Background", "BACKGROUND")
	self.frame[unit].highlight = self.frame[unit]:CreateTexture("GladiusEx" .. self:GetName() .. "Highlight" .. unit, "OVERLAY")
	self.frame[unit].castText = self.frame[unit]:CreateFontString("GladiusEx" .. self:GetName() .. "CastText" .. unit, "OVERLAY")
	self.frame[unit].timeText = self.frame[unit]:CreateFontString("GladiusEx" .. self:GetName() .. "TimeText" .. unit, "OVERLAY")
	self.frame[unit].icon = self.frame[unit]:CreateTexture("GladiusEx" .. self:GetName() .. "IconFrame" .. unit, "ARTWORK")
	self.frame[unit].icon.bg = self.frame[unit]:CreateTexture("GladiusEx" .. self:GetName() .. "IconFrameBackground" .. unit, "BACKGROUND")
end

function CastBar:GetBarHeight()
	return self.db.castBarHeight
end

function CastBar:Update(unit)
	-- check parent module
	if (not GladiusEx:GetAttachFrame(unit, self.db.castBarAttachTo)) then
		if (self.frame[unit]) then
			self.frame[unit]:Hide()
		end
		return
	end

	-- create power bar
	if (not self.frame[unit]) then
		self:CreateBar(unit)
	end

	-- set bar type
	local parent = GladiusEx:GetAttachFrame(unit, self.db.castBarAttachTo)

	-- update bar
	self.frame[unit]:ClearAllPoints()

	local width = self.db.castBarAdjustWidth and GladiusEx.db.barWidth or self.db.castBarWidth
	if (self.db.castIcon) then
		width = width - self.db.castBarHeight
	end

	-- add width of the widget if attached to an widget
	if (self.db.castBarAttachTo ~= "Frame" and not GladiusEx:GetModule(self.db.castBarAttachTo).isBar and self.db.castBarAdjustWidth) then
		if (not GladiusEx:GetModule(self.db.castBarAttachTo).frame or not GladiusEx:GetModule(self.db.castBarAttachTo).frame[unit]) then
			GladiusEx:GetModule(self.db.castBarAttachTo):Update(unit)
		end

		width = width + GladiusEx:GetModule(self.db.castBarAttachTo).frame[unit]:GetWidth()

		-- hack: needed for whatever reason, must be a bug elsewhere
		width = width + 1
	end

	self.frame[unit]:SetHeight(self.db.castBarHeight)
	self.frame[unit]:SetWidth(width)

	local offsetX
	if (not strfind(self.db.castBarAnchor, "RIGHT") and strfind(self.db.castBarRelativePoint, "RIGHT")) then
		offsetX = self.db.castIcon and self.db.castIconPosition == "LEFT" and self.frame[unit]:GetHeight() or 0
	elseif (not strfind(self.db.castBarAnchor, "LEFT") and strfind(self.db.castBarRelativePoint, "LEFT")) then
		offsetX = self.db.castIcon and self.db.castIconPosition == "RIGHT" and -self.frame[unit]:GetHeight() or 0
	elseif (strfind(self.db.castBarAnchor, "LEFT") and strfind(self.db.castBarRelativePoint, "LEFT")) then
		offsetX = self.db.castIcon and self.db.castIconPosition == "LEFT" and self.frame[unit]:GetHeight() or 0
	elseif (strfind(self.db.castBarAnchor, "RIGHT") and strfind(self.db.castBarRelativePoint, "RIGHT")) then
		offsetX = self.db.castIcon and self.db.castIconPosition == "RIGHT" and -self.frame[unit]:GetHeight() or 0
	end

	self.frame[unit]:SetPoint(self.db.castBarAnchor, parent, self.db.castBarRelativePoint, self.db.castBarOffsetX + (offsetX or 0), self.db.castBarOffsetY)
	self.frame[unit]:SetMinMaxValues(0, 100)
	self.frame[unit]:SetValue(0)
	self.frame[unit]:SetStatusBarTexture(LSM:Fetch(LSM.MediaType.STATUSBAR, self.db.castBarTexture))

	-- disable tileing
	self.frame[unit]:GetStatusBarTexture():SetHorizTile(false)
	self.frame[unit]:GetStatusBarTexture():SetVertTile(false)

	-- set color
	local color = self.db.castBarColor
	self.frame[unit]:SetStatusBarColor(color.r, color.g, color.b, color.a)

	-- update cast text
	if self.db.castText then
		self.frame[unit].castText:Show()
	else
		self.frame[unit].castText:Hide()
	end

	self.frame[unit].castText:SetFont(LSM:Fetch(LSM.MediaType.FONT, GladiusEx.db.globalFont), self.db.castTextSize)

	local color = self.db.castTextColor
	self.frame[unit].castText:SetTextColor(color.r, color.g, color.b, color.a)

	self.frame[unit].castText:SetShadowOffset(1, -1)
	self.frame[unit].castText:SetShadowColor(0, 0, 0, 1)
	self.frame[unit].castText:SetJustifyH(self.db.castTextAlign)
	self.frame[unit].castText:SetPoint(self.db.castTextAlign, self.db.castTextOffsetX, self.db.castTextOffsetY)

	-- update cast time text
	if self.db.castTimeText then
		self.frame[unit].timeText:Show()
	else
		self.frame[unit].timeText:Hide()
	end
	
	self.frame[unit].timeText:SetFont(LSM:Fetch(LSM.MediaType.FONT, GladiusEx.db.globalFont), self.db.castTimeTextSize)

	local color = self.db.castTimeTextColor
	self.frame[unit].timeText:SetTextColor(color.r, color.g, color.b, color.a)

	self.frame[unit].timeText:SetShadowOffset(1, -1)
	self.frame[unit].timeText:SetShadowColor(0, 0, 0, 1)
	self.frame[unit].timeText:SetJustifyH(self.db.castTimeTextAlign)
	self.frame[unit].timeText:SetPoint(self.db.castTimeTextAlign, self.db.castTimeTextOffsetX, self.db.castTimeTextOffsetY)

	-- update icon
	self.frame[unit].icon:ClearAllPoints()
	self.frame[unit].icon:SetPoint(self.db.castIconPosition == "LEFT" and "RIGHT" or "LEFT", self.frame[unit], self.db.castIconPosition)

	self.frame[unit].icon:SetWidth(self.frame[unit]:GetHeight())
	self.frame[unit].icon:SetHeight(self.frame[unit]:GetHeight())

	self.frame[unit].icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

	self.frame[unit].icon.bg:ClearAllPoints()
	self.frame[unit].icon.bg:SetAllPoints(self.frame[unit].icon)
	self.frame[unit].icon.bg:SetTexture(LSM:Fetch(LSM.MediaType.STATUSBAR, self.db.castBarTexture))
	self.frame[unit].icon.bg:SetVertexColor(self.db.castBarBackgroundColor.r, self.db.castBarBackgroundColor.g,
		self.db.castBarBackgroundColor.b, self.db.castBarBackgroundColor.a)


	if (not self.db.castIcon) then
		self.frame[unit].icon:SetAlpha(0)
	else
		self.frame[unit].icon:SetAlpha(1)
	end

	-- update cast bar background
	self.frame[unit].background:ClearAllPoints()
	self.frame[unit].background:SetAllPoints(self.frame[unit])

	-- Maybe it looks better if the background covers the whole castbar
	--[[
	if (self.db.castIcon) then
		self.frame[unit].background:SetWidth(self.frame[unit]:GetWidth() + self.frame[unit].icon:GetWidth())
	else
		self.frame[unit].background:SetWidth(self.frame[unit]:GetWidth())
	end
	--]]

	self.frame[unit].background:SetHeight(self.frame[unit]:GetHeight())

	self.frame[unit].background:SetTexture(LSM:Fetch(LSM.MediaType.STATUSBAR, self.db.castBarTexture))

	self.frame[unit].background:SetVertexColor(self.db.castBarBackgroundColor.r, self.db.castBarBackgroundColor.g,
		self.db.castBarBackgroundColor.b, self.db.castBarBackgroundColor.a)

	-- disable tileing
	self.frame[unit].background:SetHorizTile(false)
	self.frame[unit].background:SetVertTile(false)

	-- update highlight texture
	self.frame[unit].highlight:SetAllPoints(self.frame[unit])
	self.frame[unit].highlight:SetTexture([[Interface\QuestFrame\UI-QuestTitleHighlight]])
	self.frame[unit].highlight:SetBlendMode("ADD")
	self.frame[unit].highlight:SetVertexColor(1.0, 1.0, 1.0, 1.0)
	self.frame[unit].highlight:SetAlpha(0)

	-- hide
	self.frame[unit]:SetAlpha(0)
end

function CastBar:Show(unit)
	-- show frame
	self.frame[unit]:SetAlpha(1)
end

function CastBar:Reset(unit)
	-- reset bar
	self.frame[unit]:SetMinMaxValues(0, 1)
	self.frame[unit]:SetValue(0)

	-- reset text
	if (self.frame[unit].castText:GetFont()) then
		self.frame[unit].castText:SetText("")
	end

	if (self.frame[unit].timeText:GetFont()) then
		self.frame[unit].timeText:SetText("")
	end

	-- hide
	self.frame[unit]:SetAlpha(0)
end

function CastBar:Test(unit)
	self.frame[unit]:SetMinMaxValues(0, 100)
	self.frame[unit]:SetValue(70)

	self.frame[unit].timeText:SetFormattedText("+1.5 %.1f", 1.379)

	local texture = select(3, GetSpellInfo(1))
	self.frame[unit].icon:SetTexture(texture)
	self.frame[unit].castText:SetText(L["Example Spell Name"])
end

function CastBar:GetOptions()
	return {
		general = {
			type = "group",
			name = L["General"],
			order = 1,
			args = {
				bar = {
					type = "group",
					name = L["Bar"],
					desc = L["Bar settings"],
					inline = true,
					order = 1,
					args = {
						castBarColor = {
							type = "color",
							name = L["Color"],
							desc = L["Color of the cast bar"],
							hasAlpha = true,
							get = function(info) return GladiusEx:GetColorOption(self.db, info) end,
							set = function(info, r, g, b, a) return GladiusEx:SetColorOption(self.db, info, r, g, b, a) end,
							disabled = function() return not self:IsEnabled() end,
							order = 5,
						},
						castBarBackgroundColor = {
							type = "color",
							name = L["Background color"],
							desc = L["Color of the cast bar background"],
							hasAlpha = true,
							get = function(info) return GladiusEx:GetColorOption(self.db, info) end,
							set = function(info, r, g, b, a) return GladiusEx:SetColorOption(self.db, info, r, g, b, a) end,
							disabled = function() return not self:IsEnabled() end,
							hidden = function() return not GladiusEx.db.advancedOptions end,
							order = 10,
						},
						sep = {
							type = "description",
							name = "",
							width = "full",
							hidden = function() return not GladiusEx.db.advancedOptions end,
							order = 13,
						},
						castBarInverse = {
							type = "toggle",
							name = L["Inverse"],
							desc = L["Invert the bar colors"],
							disabled = function() return not self:IsEnabled() end,
							hidden = function() return not GladiusEx.db.advancedOptions end,
							order = 15,
						},
						castBarTexture = {
							type = "select",
							name = L["Texture"],
							desc = L["Texture of the cast bar"],
							dialogControl = "LSM30_Statusbar",
							values = AceGUIWidgetLSMlists.statusbar,
							disabled = function() return not self:IsEnabled() end,
							order = 20,
						},
						sep2 = {
							type = "description",
							name = "",
							width = "full",
							order = 23,
						},
						castIcon = {
							type = "toggle",
							name = L["Icon"],
							desc = L["Toggle the cast bar spell icon"],
							disabled = function() return not self:IsEnabled() end,
							order = 25,
						},
						castIconPosition = {
							type = "select",
							name = L["Icon position"],
							desc = L["Position of the cast bar icon"],
							values = { ["LEFT"] = L["Left"], ["RIGHT"] = L["Right"] },
							disabled = function() return not self.db.castIcon or not self:IsEnabled() end,
							order = 30,
						},
					},
				},
				size = {
					type = "group",
					name = L["Size"],
					desc = L["Size settings"],
					inline = true,
					order = 2,
					args = {
						castBarAdjustWidth = {
							type = "toggle",
							name = L["Adjust width"],
							desc = L["Adjust bar width to the frame width"],
							disabled = function() return not self:IsEnabled() end,
							order = 5,
						},
						sep = {
							type = "description",
							name = "",
							width = "full",
							order = 13,
						},
						castBarWidth = {
							type = "range",
							name = L["Bar width"],
							desc = L["Width of the cast bar"],
							min = 10, max = 500, step = 1,
							disabled = function() return self.db.castBarAdjustWidth or not self:IsEnabled() end,
							order = 15,
						},
						castBarHeight = {
							type = "range",
							name = L["Height"],
							desc = L["Height of the cast bar"],
							min = 10, max = 200, step = 1,
							disabled = function() return not self:IsEnabled() end,
							order = 20,
						},
					},
				},
				position = {
					type = "group",
					name = L["Position"],
					desc = L["Position settings"],
					inline = true,
					hidden = function() return not GladiusEx.db.advancedOptions end,
					order = 3,
					args = {
						castBarAttachTo = {
							type = "select",
							name = L["Attach to"],
							desc = L["Attach to the given frame"],
							values = function() return CastBar:GetAttachPoints() end,
							disabled = function() return not self:IsEnabled() end,
							width = "double",
							order = 5,
						},
						sep = {
							type = "description",
							name = "",
							width = "full",
							order = 7,
						},
						castBarAnchor = {
							type = "select",
							name = L["Anchor"],
							desc = L["Anchor of the frame"],
							values = function() return GladiusEx:GetPositions() end,
							disabled = function() return not self:IsEnabled() end,
							order = 10,
						},
						castBarRelativePoint = {
							type = "select",
							name = L["Relative point"],
							desc = L["Relative point of the frame"],
							values = function() return GladiusEx:GetPositions() end,
							disabled = function() return not self:IsEnabled() end,
							order = 15,
						},
						sep2 = {
							type = "description",
							name = "",
							width = "full",
							order = 17,
						},
						castBarOffsetX = {
							type = "range",
							name = L["Offset X"],
							desc = L["X offset of the frame"],
							min = -100, max = 100, step = 1,
							disabled = function() return  not self:IsEnabled() end,
							order = 20,
						},
						castBarOffsetY = {
							type = "range",
							name = L["Offset Y"],
							desc = L["Y offset of the frame"],
							disabled = function() return not self:IsEnabled() end,
							min = -100, max = 100, step = 1,
							order = 25,
						},
					},
				},
			},
		},
		castText = {
			type = "group",
			name = L["Cast text"],
			order = 2,
			args = {
				text = {
					type = "group",
					name = L["Text"],
					desc = L["Text settings"],
					inline = true,
					order = 1,
					args = {
						castText = {
							type = "toggle",
							name = L["Cast text"],
							desc = L["Toggle cast text"],
							disabled = function() return not self:IsEnabled() end,
							order = 5,
						},
						sep = {
							type = "description",
							name = "",
							width = "full",
							order = 7,
						},
						castTextColor = {
							type = "color",
							name = L["Text color"],
							desc = L["Text color of the cast text"],
							hasAlpha = true,
							get = function(info) return GladiusEx:GetColorOption(self.db, info) end,
							set = function(info, r, g, b, a) return GladiusEx:SetColorOption(self.db, info, r, g, b, a) end,
							disabled = function() return not self.db.castText or not self:IsEnabled() end,
							order = 10,
						},
						castTextSize = {
							type = "range",
							name = L["Text size"],
							desc = L["Text size of the cast text"],
							min = 1, max = 20, step = 1,
							disabled = function() return not self.db.castText or not self:IsEnabled() end,
							order = 15,
						},
					},
				},
				position = {
					type = "group",
					name = L["Position"],
					desc = L["Position settings"],
					inline = true,
					hidden = function() return not GladiusEx.db.advancedOptions end,
					order = 2,
					args = {
						castTextAlign = {
							type = "select",
							name = L["Text align"],
							desc = L["Text align of the cast text"],
							values = { ["LEFT"] = L["Left"], ["CENTER"] = L["Center"], ["RIGHT"] = L["Right"] },
							disabled = function() return not self.db.castText or not self:IsEnabled() end,
							width = "double",
							order = 5,
						},
						sep = {
							type = "description",
							name = "",
							width = "full",
							order = 7,
						},
						castTextOffsetX = {
							type = "range",
							name = L["Offset X"],
							desc = L["X offset of the cast text"],
							min = -100, max = 100, step = 1,
							disabled = function() return not self.db.castText or not self:IsEnabled() end,
							order = 10,
						},
						castTextOffsetY = {
							type = "range",
							name = L["Offset Y"],
							desc = L["Y offset of the cast text"],
							disabled = function() return not self.db.castText or not self:IsEnabled() end,
							min = -100, max = 100, step = 1,
							order = 15,
						},
					},
				},
			},
		},
		castTimeText = {
			type = "group",
			name = L["Cast time text"],
			order = 3,
			args = {
				text = {
					type = "group",
					name = L["Text"],
					desc = L["Text settings"],
					inline = true,
					order = 1,
					args = {
						castTimeText = {
							type = "toggle",
							name = L["Cast time text"],
							desc = L["Toggle cast time text"],
							disabled = function() return not self:IsEnabled() end,
							order = 5,
						},
						sep = {
							type = "description",
							name = "",
							width = "full",
							order = 7,
						},
						castTimeTextColor = {
							type = "color",
							name = L["Text color"],
							desc = L["Text color of the cast time text"],
							hasAlpha = true,
							get = function(info) return GladiusEx:GetColorOption(self.db, info) end,
							set = function(info, r, g, b, a) return GladiusEx:SetColorOption(self.db, info, r, g, b, a) end,
							disabled = function() return not self.db.castTimeText or not self:IsEnabled() end,
							order = 10,
						},
						castTimeTextSize = {
							type = "range",
							name = L["Text size"],
							desc = L["Text size of the cast time text"],
							min = 1, max = 20, step = 1,
							disabled = function() return not self.db.castTimeText or not self:IsEnabled() end,
							order = 15,
						},

					},
				},
				position = {
					type = "group",
					name = L["Position"],
					desc = L["Position settings"],
					inline = true,
					hidden = function() return not GladiusEx.db.advancedOptions end,
					order = 2,
					args = {
						castTimeTextAlign = {
							type = "select",
							name = L["Text align"],
							desc = L["Text align of the cast time text"],
							values = { ["LEFT"] = L["Left"], ["CENTER"] = L["Center"], ["RIGHT"] = L["Right"] },
							disabled = function() return not self.db.castTimeText or not self:IsEnabled() end,
							width = "double",
							order = 5,
						},
						sep = {
							type = "description",
							name = "",
							width = "full",
							order = 7,
						},
						castTimeTextOffsetX = {
							type = "range",
							name = L["Offset X"],
							desc = L["X offset of the cast time text"],
							min = -100, max = 100, step = 1,
							disabled = function() return not self.db.castTimeText or not self:IsEnabled() end,
							order = 10,
						},
						castTimeTextOffsetY = {
							type = "range",
							name = L["Offset Y"],
							desc = L["Y offset of the cast time text"],
							disabled = function() return not self.db.castTimeText or not self:IsEnabled() end,
							min = -100, max = 100, step = 1,
							order = 15,
						},
					},
				},
			},
		},
	}
end
