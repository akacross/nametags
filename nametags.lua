script_name("Nametags")
script_author("akacross", "SK1DGARD")
script_url("http://akacross.net/")

local script_version = 2.2
local script_version_text = '2.2'

if getMoonloaderVersion() >= 27 then
	require 'libstd.deps' {
	   'fyp:mimgui',
	   'fyp:samp-lua', 
	   'fyp:fa-icons-4',
	   'donhomka:extensions-lite'
	}
end

require"lib.moonloader"
require"lib.sampfuncs"
require 'extensions-lite'

local imgui, ffi = require 'mimgui', require 'ffi'
local new, str, sizeof = imgui.new, ffi.string, ffi.sizeof
local ped, h = playerPed, playerHandle
local vk = require 'vkeys'
local sampev = require 'lib.samp.events'
local encoding = require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8
local faicons = require 'fa-icons'
local ti = require 'tabler_icons'
local mem = require 'memory'
local wm  = require('lib.windows.message')
local dlstatus = require('moonloader').download_status
local https = require 'ssl.https'
local path = getWorkingDirectory() .. '\\config\\' 
local cfg = path .. 'nametags.ini' 
local script_path = thisScript().path
local script_url = "https://raw.githubusercontent.com/akacross/nametags/main/nametags.lua"
local update_url = "https://raw.githubusercontent.com/akacross/nametags/main/nametags.txt"

local function loadIconicFont(fontSize, min, max, fontdata)
    local config = imgui.ImFontConfig()
    config.MergeMode = true
    config.PixelSnapH = true
    local iconRanges = imgui.new.ImWchar[3](min, max, 0)
    imgui.GetIO().Fonts:AddFontFromMemoryCompressedBase85TTF(fontdata, fontSize, config, iconRanges)
end

local blank = {}
local nt = {
	autosave = false,
	autoupdate = false,
	showplayername = false,
	NICKNAME = {
		enabled = true,
		vertical_offset = 16,
		font_name = 'Arial',
		font_size = 10,
		font_flag = 13,
		opacity = 255
	},
	AFK = {
		enabled = true,
		font_name = 'Arial',
		font_size = 7,
		font_flag = 5,
		opacity = 255,
		indent = 20
	},
	HEALTH_BAR = {
		enabled = true,
		size_x = 80,
		size_y = 10,
		border_size = 1,
		main_color = 0xFFFF0000,
		border_color = 0xFF000000,
		background_color = 0x68000000
	},
	ARMOR_BAR = {
		enabled = true,
		indent = 3,
		size_x = 80,
		size_y = 10,
		border_size = 1,
		main_color = 0xFFFFFFFF,
		border_color = 0xFF000000,
		background_color = 0x68000000
	},
	HEALTH_COUNT = {
		enabled = true,
		font_name = 'Arial',
		font_size = 7,
		font_flag = 5,
		font_color = 0xFFFFFFFF
	},
	ARMOR_COUNT = {
		enabled = true,
		font_name = 'Arial',
		font_size = 7,
		font_flag = 5,
		font_color = 0xFFFFFFFF
	},
	CHAT_BUBBLE = {
		enabled = true,
		font_name = 'Arial',
		font_size = 7,
		font_flag = 5,
		opacity = 255,
		max_symbols = 15,
		indent = 20,
		line_offset = 2
	},
	GENERAL = {
		on = true,
		vertical_indent = 0.3
	}
}

local nick_font, afk_font, hp_font, armor_font, bubble_font = nil 
local window_state = new.bool(false)
local current_table = 1
local update = false
local server = {
	distance = 0,
}
local bubble_pool = {} 
local get_bone_pos = ffi.cast("int (__thiscall*)(void*, float*, int, bool)", 0x5E4280)

function update_script()
	update_text = https.request(update_url)
	update_version = update_text:match("version: (.+)")
	if tonumber(update_version) > script_version then
		message('NewUpdate')
		downloadUrlToFile(script_url, script_path, function(id, status)
			if status == dlstatus.STATUS_ENDDOWNLOADDATA then
				message("UpdateSuccessful")
				update = true
			end
		end)
	end
end

function main()
	blank = table.deepcopy(nt)
	if not doesDirectoryExist(path) then createDirectory(path) end
	if doesFileExist(cfg) then loadIni() else blankIni() end

	if nt.autoupdate then
		update_script()
	end

	while not isSampAvailable() do wait(100) end
	sampRegisterChatCommand('cusnt', function() window_state[0] = not window_state[0] end)
	serverPtr = sampGetServerSettingsPtr()
	load_fonts()

	while true do wait(0)
		if nameTags_getDistance(serverPtr) ~= server.distance then
			server.distance = nameTags_getDistance(serverPtr)
		end
		
		if nameTags_getState(serverPtr) == nt.GENERAL.on and 0 or 1 then 
			nameTags_setState(serverPtr, nt.GENERAL.on and 0 or 1)
		end
		
		if update then
			window_state[0] = false
			lua_thread.create(function() 
				wait(20000) 
				thisScript():reload()
				blankIni()
				update = false
			end)
		end
	end
end

function onScriptTerminate(scr, quitGame) 
	if scr == script.this then 
		if nt.autosave then 
			saveIni() 
		end 
	end
end

function onD3DPresent()
	if not isPauseMenuActive() and not sampIsDialogActive() and not sampIsScoreboardOpen() and not isSampfuncsConsoleActive() and sampGetChatDisplayMode() > 0 and nt.GENERAL.on then
		local ped_pool = getAllChars()
		for _, v in pairs(ped_pool) do
			if v ~= ped then
				rendernametags(v)
			end
		end
		if nt.showplayername then
			rendernametags(ped)
		end
	end
end

function rendernametags(v)
	if isCharOnScreen(v) then
		local cam_x, cam_y, cam_z = getActiveCameraCoordinates()
		local x, y, z = get_bodypart_coordinates(v, 5)
		local dist = getDistanceBetweenCoords3d(x, y, z, cam_x, cam_y, cam_z)
		local result, id = sampGetPlayerIdByCharHandle(v)
		if (isLineOfSightClear(cam_x, cam_y, cam_z, x, y, z, true, false, false, true, false) or server.distance == 1488.0) and result and dist < server.distance then			 
			z = z + nt.GENERAL.vertical_indent
			local hp = sampGetPlayerHealth(id)
			if v == PLAYER_PED then hp = hp - 5000000 end
			local armor = sampGetPlayerArmor(id)
			local text_nick = string.format('%s {FFFFFF}[%d]', sampGetPlayerNickname(id), id)
			local text_afk = '{FF0000}<AFK>'
						
			local _, r, g, b = hex_to_argb(sampGetPlayerColor(id))
			local clr = join_argb(nt.NICKNAME.opacity, r, g, b)
					
			local sx, sy = convert3DCoordsToScreen(x, y, z)		
			if nt.HEALTH_BAR.enabled then
				renderbar(
					sx - nt.HEALTH_BAR.size_x / 2, 
					sy - nt.HEALTH_BAR.size_y / 2, 
					nt.HEALTH_BAR.size_x, 
					nt.HEALTH_BAR.size_y, 
					nt.HEALTH_BAR.border_size, 
					100, 
					hp, 
					nt.HEALTH_BAR.main_color, 
					nt.HEALTH_BAR.background_color, 
					nt.HEALTH_BAR.border_color, 
					120
				)
			end

			if nt.HEALTH_COUNT.enabled then
				renderFontDrawText(
					hp_font,
					hp,
					sx - renderGetFontDrawTextLength(hp_font, hp) / 2,
					sy - renderGetFontDrawHeight(hp_font) / 2,
					nt.HEALTH_COUNT.font_color
				)
			end
						  
			if armor > 0 then
				sy = sy - nt.ARMOR_BAR.indent - nt.HEALTH_BAR.size_y

				if nt.ARMOR_BAR.enabled then
					renderbar(
						sx - nt.ARMOR_BAR.size_x / 2, 
						sy - nt.ARMOR_BAR.size_y / 2, 
						nt.ARMOR_BAR.size_x, 
						nt.ARMOR_BAR.size_y, 
						nt.ARMOR_BAR.border_size, 
						100, 
						armor, 
						nt.ARMOR_BAR.main_color, 
						nt.ARMOR_BAR.background_color, 
						nt.ARMOR_BAR.border_color
					)
				end

				if nt.ARMOR_COUNT.enabled then
					renderFontDrawText(
						armor_font,
						armor,
						sx - renderGetFontDrawTextLength(armor_font, armor) / 2,
						sy - renderGetFontDrawHeight(armor_font) / 2,
						nt.ARMOR_COUNT.font_color
					)
				end
			end
						
			if nt.NICKNAME.enabled then
				sy = sy - nt.NICKNAME.vertical_offset
				renderFontDrawText(
					nick_font,
					text_nick, 
					sx - renderGetFontDrawTextLength(nick_font, text_nick) / 2,
					sy - renderGetFontDrawHeight(nick_font) / 2,
					clr
				)
			end

			if nt.AFK.enabled and sampIsPlayerPaused(id) then
				sy = sy - nt.AFK.indent
				renderFontDrawText(
					afk_font,
					text_afk,
					sx - renderGetFontDrawTextLength(afk_font, text_afk) / 2,
					sy,
					-1
				)
			end

			if nt.CHAT_BUBBLE.enabled and bubble_pool[id] ~= nil and dist < bubble_pool[id].distance then	
				if os.time() < bubble_pool[id].remove_time then
					sy = sy - nt.CHAT_BUBBLE.indent
					render_text_wrapped(
						bubble_font, 
						sx, 
						sy,
						bubble_pool[id].text, 
						bubble_pool[id].color,
						nt.CHAT_BUBBLE.max_symbols, 
						nt.CHAT_BUBBLE.line_offset
					)
				else
					table.remove(bubble_pool, id)
				end
			end
		end
	end
end

function renderbar(x, y, sizex, sizey, border, maxvalue, value, color, color2, color3)
	if value > maxvalue then
		value = maxvalue
	end
	renderDrawBoxWithBorder(x, y, sizex, sizey, color2, border, color3)
	renderDrawBox(x + border, y + border, sizex / maxvalue * value - (2 * border), sizey - (2 * border), color)
end

function sampev.onPlayerChatBubble(playerId, color, distance, duration, message)
	lua_thread.create(function()
		while isGamePaused() do wait(0) end

		if nt.GENERAL.on and nt.CHAT_BUBBLE.enabled and playerId ~= nil then
			
			local r, g, b, _ = hex_to_argb(color)
			local var = {
				['text'] = message,
				['color'] = join_argb(nt.CHAT_BUBBLE.opacity, r, g, b),
				['remove_time'] = os.time() + duration / 1000.0,
				['distance'] = distance
			}
			table.insert(bubble_pool, playerId, var)
		end
	end)
	return false
end

function sampev.onPlayerQuit(playerId, _)
  if bubble_pool[playerId] ~= nil then table.remove(bubble_pool, playerId) end
end

function render_text_wrapped(font, x, y, text, color, max_symbols, line_offset)
  local str_list = {}
  local last_str = ''
  for i = 1, #text do
    if #last_str == max_symbols then
      table.insert(str_list, last_str)
      last_str = ''
    end
    last_str = last_str .. string.sub(text, i, i)
  end
  if #last_str > 0 then table.insert(str_list, last_str) end
  for i = 1, #str_list do
    renderFontDrawText(
      font, 
      str_list[i], 
      x - renderGetFontDrawTextLength(font, str_list[i]) / 2, 
      y - renderGetFontDrawHeight(font) * (#str_list - i ) - line_offset * (#str_list - i - 1), 
      color)
  end
end

function join_argb(a, r, g, b)
	local argb = b
	argb = bit.bor(argb, bit.lshift(g, 8))
	argb = bit.bor(argb, bit.lshift(r, 16))
	argb = bit.bor(argb, bit.lshift(a, 24))
	return argb
end

function hex_to_argb(hex)
	return 
		bit.band(bit.rshift(hex, 24), 0xFF),
		bit.band(bit.rshift(hex, 16), 0xFF), 
		bit.band(bit.rshift(hex, 8), 0xFF), 
		bit.band(hex, 0xFF)
end

function get_bodypart_coordinates(handle, id)
	if doesCharExist(handle) then
		local pedptr = getCharPointer(handle)
		local vec = ffi.new("float[3]")
		get_bone_pos(ffi.cast("void*", pedptr), vec, id, true)
		return vec[0], vec[1], vec[2]
	end
end

function load_fonts()
  nick_font = renderCreateFont(nt.NICKNAME.font_name, nt.NICKNAME.font_size, nt.NICKNAME.font_flag)
  afk_font = renderCreateFont(nt.AFK.font_name, nt.AFK.font_size, nt.AFK.font_flag)
  hp_font = renderCreateFont(nt.HEALTH_COUNT.font_name, nt.HEALTH_COUNT.font_size, nt.HEALTH_COUNT.font_flag)
  armor_font = renderCreateFont(nt.ARMOR_COUNT.font_name, nt.ARMOR_COUNT.font_size, nt.ARMOR_COUNT.font_flag)
  bubble_font = renderCreateFont(nt.CHAT_BUBBLE.font_name, nt.CHAT_BUBBLE.font_size, nt.CHAT_BUBBLE.font_flag)
end

function nameTags_getDistance(ptr) 
	return mem.getfloat(ptr + 39, 1) 
end

function nameTags_getState(ptr) 
	return mem.getint8(ptr + 56, 1) 
end

function nameTags_setState(ptr, state) 
	mem.setint8(ptr + 56, state) 
end

-- IMGUI_API bool          CustomButton(const char* label, const ImVec4& col, const ImVec4& col_focus, const ImVec4& col_click, const ImVec2& size = ImVec2(0,0));
function imgui.CustomButton(name, color, colorHovered, colorActive, size)
    local clr = imgui.Col
    imgui.PushStyleColor(clr.Button, color)
    imgui.PushStyleColor(clr.ButtonHovered, colorHovered)
    imgui.PushStyleColor(clr.ButtonActive, colorActive)
    if not size then size = imgui.ImVec2(0, 0) end
    local result = imgui.Button(name, size)
    imgui.PopStyleColor(3)
    return result
end

-- imgui.OnInitialize() called only once, before the first render
imgui.OnInitialize(function()
	apply_custom_style() -- apply custom style
	
	loadIconicFont(14, ti.min_range, ti.max_range, ti.get_font_data_base85())
	loadIconicFont(14, faicons.min_range, faicons.max_range, faicons.get_font_data_base85())

	imgui.GetIO().ConfigWindowsMoveFromTitleBarOnly = true
	imgui.GetIO().IniFilename = nil
end)


imgui.OnFrame(function() return window_state[0] end,
function()
	local width, height = getScreenResolution()
	imgui.SetNextWindowPos(imgui.ImVec2(width / 2, height / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
	imgui.SetNextWindowSize(imgui.ImVec2(723, 420), imgui.Cond.FirstUseEver)
	
    imgui.Begin(ti.ICON_SETTINGS .. u8('  Custom name tags | Author: SK1DGARD'), window_state, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoSavedSettings + imgui.WindowFlags.AlwaysAutoResize) 

		imgui.BeginChild("##1", imgui.ImVec2(85, 394), true)
			
			imgui.SetCursorPos(imgui.ImVec2(5, 5))
      
			if imgui.CustomButton(
				faicons.ICON_POWER_OFF, 
				nt.GENERAL.on and imgui.ImVec4(0.15, 0.59, 0.18, 0.7) or imgui.ImVec4(1, 0.19, 0.19, 0.5), 
				nt.GENERAL.on and imgui.ImVec4(0.15, 0.59, 0.18, 0.5) or imgui.ImVec4(1, 0.19, 0.19, 0.3), 
				nt.GENERAL.on and imgui.ImVec4(0.15, 0.59, 0.18, 0.4) or imgui.ImVec4(1, 0.19, 0.19, 0.2), 
				imgui.ImVec2(75, 75)) then
				nt.GENERAL.on = not nt.GENERAL.on
			end
			if imgui.IsItemHovered() then
				imgui.SetTooltip('Toggles nametags')
			end
		
			imgui.SetCursorPos(imgui.ImVec2(5, 81))

			if imgui.CustomButton(
				faicons.ICON_FLOPPY_O,
				imgui.ImVec4(0.16, 0.16, 0.16, 0.9), 
				imgui.ImVec4(0.40, 0.12, 0.12, 1), 
				imgui.ImVec4(0.30, 0.08, 0.08, 1), 
				imgui.ImVec2(75, 75)) then
				saveIni()
			end
			if imgui.IsItemHovered() then
				imgui.SetTooltip('Save the INI')
			end
      
			imgui.SetCursorPos(imgui.ImVec2(5, 157))

			if imgui.CustomButton(
				faicons.ICON_REPEAT, 
				imgui.ImVec4(0.16, 0.16, 0.16, 0.9), 
				imgui.ImVec4(0.40, 0.12, 0.12, 1), 
				imgui.ImVec4(0.30, 0.08, 0.08, 1), 
				imgui.ImVec2(75, 75)) then
				loadIni()
				load_fonts()
			end
			if imgui.IsItemHovered() then
				imgui.SetTooltip('Reload the INI')
			end

			imgui.SetCursorPos(imgui.ImVec2(5, 233))

			if imgui.CustomButton(
				faicons.ICON_ERASER, 
				imgui.ImVec4(0.16, 0.16, 0.16, 0.9), 
				imgui.ImVec4(0.40, 0.12, 0.12, 1), 
				imgui.ImVec4(0.30, 0.08, 0.08, 1), 
				imgui.ImVec2(75, 75)) then
				blankIni()
				load_fonts()
			end
			if imgui.IsItemHovered() then
				imgui.SetTooltip('Reset the INI to default settings')
			end

			imgui.SetCursorPos(imgui.ImVec2(5, 309))

			if imgui.CustomButton(
				faicons.ICON_RETWEET .. ' Update',
				imgui.ImVec4(0.16, 0.16, 0.16, 0.9), 
				imgui.ImVec4(0.40, 0.12, 0.12, 1), 
				imgui.ImVec4(0.30, 0.08, 0.08, 1),  
				imgui.ImVec2(75, 75)) then
				update_script()
			end
			if imgui.IsItemHovered() then
				imgui.SetTooltip('Update the script')
			end
      
		imgui.EndChild()
    
		imgui.SetCursorPos(imgui.ImVec2(92, 28))

		imgui.BeginChild("##2", imgui.ImVec2(615, 88), true)
      
			imgui.SetCursorPos(imgui.ImVec2(5,5))
			if imgui.CustomButton(faicons.ICON_MALE .. '  Nickname',
				current_table == 1 and imgui.ImVec4(0.56, 0.16, 0.16, 1) or imgui.ImVec4(0.16, 0.16, 0.16, 0.9),
				imgui.ImVec4(0.40, 0.12, 0.12, 1), 
				imgui.ImVec4(0.30, 0.08, 0.08, 1), 
				imgui.ImVec2(100, 75)) then
				current_table = 1
			end

			imgui.SetCursorPos(imgui.ImVec2(106, 5))
			  
			if imgui.CustomButton(faicons.ICON_HEART .. '  HP bar',
				current_table == 2 and imgui.ImVec4(0.56, 0.16, 0.16, 1) or imgui.ImVec4(0.16, 0.16, 0.16, 0.9),
				imgui.ImVec4(0.40, 0.12, 0.12, 1), 
				imgui.ImVec4(0.30, 0.08, 0.08, 1), 
				imgui.ImVec2(100, 75)) then
			  
				current_table = 2
			end

			imgui.SetCursorPos(imgui.ImVec2(207, 5))

			if imgui.CustomButton(faicons.ICON_SHIELD .. '  Armor bar',
				current_table == 3 and imgui.ImVec4(0.56, 0.16, 0.16, 1) or imgui.ImVec4(0.16, 0.16, 0.16, 0.9),
				imgui.ImVec4(0.40, 0.12, 0.12, 1), 
				imgui.ImVec4(0.30, 0.08, 0.08, 1), 
				imgui.ImVec2(100, 75)) then
			  
				current_table = 3
			end

			imgui.SetCursorPos(imgui.ImVec2(308, 5))

			if imgui.CustomButton(faicons.ICON_HEARTBEAT .. '  HP value',
				current_table == 4 and imgui.ImVec4(0.56, 0.16, 0.16, 1) or imgui.ImVec4(0.16, 0.16, 0.16, 0.9),
				imgui.ImVec4(0.40, 0.12, 0.12, 1), 
				imgui.ImVec4(0.30, 0.08, 0.08, 1), 
				imgui.ImVec2(100, 75)) then
			  
				current_table = 4
			end

			imgui.SetCursorPos(imgui.ImVec2(409, 5))

			if imgui.CustomButton(faicons.ICON_SHIELD .. '  Armor value',
				current_table == 5 and imgui.ImVec4(0.56, 0.16, 0.16, 1) or imgui.ImVec4(0.16, 0.16, 0.16, 0.9),
				imgui.ImVec4(0.40, 0.12, 0.12, 1), 
				imgui.ImVec4(0.30, 0.08, 0.08, 1), 
				imgui.ImVec2(100, 75)) then
			  
				current_table = 5
			end
			imgui.SetCursorPos(imgui.ImVec2(510, 5))
		 
			if imgui.CustomButton(faicons.ICON_PENCIL .. '  Chat bubble',
				current_table == 6 and imgui.ImVec4(0.56, 0.16, 0.16, 1) or imgui.ImVec4(0.16, 0.16, 0.16, 0.9),
				imgui.ImVec4(0.40, 0.12, 0.12, 1), 
				imgui.ImVec4(0.30, 0.08, 0.08, 1), 
				imgui.ImVec2(100, 75)) then
			  
				current_table = 6
			end
		imgui.EndChild()

		imgui.SetCursorPos(imgui.ImVec2(92, 112))
		imgui.BeginChild("##3", imgui.ImVec2(615, 276), true)

			if current_table == 1 then
				imgui.PushItemWidth(300)
				if imgui.Checkbox('Draw player nicknames##nick', new.bool(nt.NICKNAME.enabled)) then
					nt.NICKNAME.enabled = not nt.NICKNAME.enabled
				end
				
				text = new.char[256](nt.NICKNAME.font_name)
				if imgui.InputText('##font', text, sizeof(text), imgui.InputTextFlags.EnterReturnsTrue) then
					nt.NICKNAME.font_name = u8:decode(str(text))
					nick_font = renderCreateFont(nt.NICKNAME.font_name, nt.NICKNAME.font_size, nt.NICKNAME.font_flag)
				end

				imgui.SameLine()
				imgui.Text(faicons.ICON_FONT .. u8(string.format('  Font Name (%s)', nt.NICKNAME.font_name)))

				local fsize = new.int[1](nt.NICKNAME.font_size)
				if imgui.InputInt(faicons.ICON_TEXT_WIDTH .. "  Font size##nick", fsize, 1) then
					nt.NICKNAME.font_size = fsize[0]
					nick_font = renderCreateFont(nt.NICKNAME.font_name, nt.NICKNAME.font_size, nt.NICKNAME.font_flag)
				end

				local fontflag = new.int[1](nt.NICKNAME.font_flag)
				if imgui.InputInt(faicons.ICON_FLAG .. "  Font flag##nick", fontflag) then
					nt.NICKNAME.font_flag = fontflag[0]
					nick_font = renderCreateFont(nt.NICKNAME.font_name, nt.NICKNAME.font_size, nt.NICKNAME.font_flag)
				end
				
				local voffset = new.int[1](nt.NICKNAME.vertical_offset)
				if imgui.SliderInt(faicons.ICON_ARROW_UP .. '  Nickname offset by Y axis##nick', voffset, -100, 100) then
					nt.NICKNAME.vertical_offset = voffset[0]
				end

				local opacity = new.int[1](nt.NICKNAME.opacity)
				if imgui.SliderInt(faicons.ICON_MOON_O .. '  Nickname color opacity##nick', opacity, 0, 255) then
					nt.NICKNAME.opacity = opacity[0]
				end
				
				imgui.PopItemWidth()
			end
			if current_table == 2 then
				imgui.PushItemWidth(460)
				
				if imgui.Checkbox('Display player health bar##hpbar', new.bool(nt.HEALTH_BAR.enabled)) then
					nt.HEALTH_BAR.enabled = not nt.HEALTH_BAR.enabled
				end
				
				local sizex = new.int[1](nt.HEALTH_BAR.size_x)
				if imgui.SliderInt(faicons.ICON_SLIDERS .. ' Health bar width##hpbar', sizex, 0, 400) then
					nt.HEALTH_BAR.size_x = sizex[0]
				end
				
				local sizey = new.int[1](nt.HEALTH_BAR.size_y)
				if imgui.SliderInt(faicons.ICON_SLIDERS .. ' Health bar height##hpbar', sizey, 0, 400) then
					nt.HEALTH_BAR.size_y = sizey[0]
				end
				
				local bsize = new.int[1](nt.HEALTH_BAR.border_size)
				if imgui.SliderInt(faicons.ICON_SLIDERS .. ' Border thickness##hpbar', bsize, 0, 60) then
					nt.HEALTH_BAR.border_size = bsize[0]
				end
				
				local a, r, g, b = hex_to_argb(nt.HEALTH_BAR.main_color)
				local main_color = new.float[4](r / 255, g / 255, b / 255, a / 255) 
				if imgui.ColorEdit4(faicons.ICON_SPINNER .. "  Main color##hpbar", main_color) then
					nt.HEALTH_BAR.main_color = join_argb(main_color[3] * 255, main_color[0] * 255, main_color[1] * 255, main_color[2] * 255)
				end
				
				local a, r, g, b = hex_to_argb(nt.HEALTH_BAR.background_color)
				local background_color = new.float[4](r / 255, g / 255, b / 255, a / 255)  
				if imgui.ColorEdit4(faicons.ICON_SPINNER .. "  Background color##hpbar", background_color) then
					nt.HEALTH_BAR.background_color = join_argb(background_color[3] * 255, background_color[0]  * 255, background_color[1]  * 255, background_color[2]  * 255) 
				end
				
				local a, r, g, b = hex_to_argb(nt.HEALTH_BAR.border_color)
				local border_color = new.float[4](r / 255, g / 255, b / 255, a / 255) 
				if imgui.ColorEdit4(faicons.ICON_SPINNER .. "  Border color##hpbar", border_color) then
					nt.HEALTH_BAR.border_color = join_argb(border_color[3] * 255, border_color[0]  * 255, border_color[1]  * 255, border_color[2]  * 255) 
				end
				
				imgui.PopItemWidth()
			end
			if current_table == 3 then
				imgui.PushItemWidth(460)
				
				if imgui.Checkbox('Display player armor bar##armor', new.bool(nt.ARMOR_BAR.enabled)) then 
					nt.ARMOR_BAR.enabled = not nt.ARMOR_BAR.enabled
				end
				
				local sizex = new.int[1](nt.ARMOR_BAR.size_x)
				if imgui.SliderInt(faicons.ICON_SLIDERS .. ' Armor bar width##armor', sizex, 0, 400) then 
					nt.ARMOR_BAR.size_x = sizex[0]
				end
				
				local sizey = new.int[1](nt.ARMOR_BAR.size_y)
				if imgui.SliderInt(faicons.ICON_SLIDERS .. ' armor bar height##armor', sizey, 0, 400) then 
					nt.ARMOR_BAR.size_y = sizey[0]
				end
				
				local bsize = new.int[1](nt.ARMOR_BAR.border_size)
				if imgui.SliderInt(faicons.ICON_SLIDERS .. ' Border thickness##armor', bsize, 0, 60) then 
					nt.ARMOR_BAR.border_size = bsize[0]
				end
				
				local a, r, g, b = hex_to_argb(nt.ARMOR_BAR.main_color)
				local main_color = new.float[4](r / 255, g / 255, b / 255, a / 255) 
				if imgui.ColorEdit4(faicons.ICON_SPINNER .. "  Main color##armor", main_color) then
					nt.ARMOR_BAR.main_color = join_argb(main_color[3] * 255, main_color[0] * 255, main_color[1] * 255, main_color[2] * 255)
				end
				
				local a, r, g, b = hex_to_argb(nt.ARMOR_BAR.background_color)
				local background_color = new.float[4](r / 255, g / 255, b / 255, a / 255)  
				if imgui.ColorEdit4(faicons.ICON_SPINNER .. "  Background color##armor", background_color) then
					nt.ARMOR_BAR.background_color = join_argb(background_color[3] * 255, background_color[0]  * 255, background_color[1]  * 255, background_color[2]  * 255) 
				end
				
				local a, r, g, b = hex_to_argb(nt.ARMOR_BAR.border_color)
				local border_color = new.float[4](r / 255, g / 255, b / 255, a / 255) 
				if imgui.ColorEdit4(faicons.ICON_SPINNER .. "  Border color##armor", border_color) then
					nt.ARMOR_BAR.border_color = join_argb(border_color[3] * 255, border_color[0]  * 255, border_color[1]  * 255, border_color[2]  * 255) 
				end
				
				local indent = new.int[1](nt.ARMOR_BAR.indent)
				if imgui.SliderInt(faicons.ICON_SLIDERS .. ' Armor vertical offset##armor', indent, 0, 200) then
					nt.ARMOR_BAR.indent = indent[0]
				end
				
				imgui.PopItemWidth()
			end
			if current_table == 4 then
				imgui.PushItemWidth(300)

				if imgui.Checkbox('Draw player health count##hpcount', new.bool(nt.HEALTH_COUNT.enabled)) then
					nt.HEALTH_COUNT.enabled = not nt.HEALTH_COUNT.enabled
				end
				
				local a, r, g, b = hex_to_argb(nt.HEALTH_COUNT.font_color)
				local font_color = new.float[4](r / 255, g / 255, b / 255, a / 255) 
				if imgui.ColorEdit4(faicons.ICON_SPINNER .. "  Border color##hpcount", font_color) then
					nt.HEALTH_COUNT.font_color = join_argb(font_color[3] * 255, font_color[0]  * 255, font_color[1]  * 255, font_color[2]  * 255) 
				end

				imgui.PopItemWidth()
			end
			if current_table == 5 then
				imgui.PushItemWidth(300)
		  
				if imgui.Checkbox('Draw player health count##armorcount', new.bool(nt.ARMOR_COUNT.enabled)) then
					nt.ARMOR_COUNT.enabled = not nt.ARMOR_COUNT.enabled
				end
				
				
				text = new.char[256](nt.ARMOR_COUNT.font_name)
				if imgui.InputText('##font', text, sizeof(text), imgui.InputTextFlags.EnterReturnsTrue) then
					nt.ARMOR_COUNT.font_name = u8:decode(str(text))
					armor_font = renderCreateFont(nt.ARMOR_COUNT.font_name, nt.ARMOR_COUNT.font_size, nt.ARMOR_COUNT.font_flag)
				end
				
				imgui.SameLine()
				imgui.Text(faicons.ICON_FONT .. u8(string.format('  Font Name (%s)', nt.ARMOR_COUNT.font_name)))
		  
		  
				local font_size = new.int[1](nt.ARMOR_COUNT.font_size)
				if imgui.InputInt(faicons.ICON_TEXT_WIDTH .. "  Font size##armorcount", font_size) then
					  nt.ARMOR_COUNT.font_size = font_size[0]
					  armor_font = renderCreateFont(nt.ARMOR_COUNT.font_name, nt.ARMOR_COUNT.font_size, nt.ARMOR_COUNT.font_flag)
				end
			  
				local font_flag = new.int[1](nt.ARMOR_COUNT.font_flag)
				if imgui.InputInt(faicons.ICON_FLAG .. "  Font flag##armorcount", font_flag) then
					  nt.ARMOR_COUNT.font_flag = font_flag[0]
					  armor_font = renderCreateFont(nt.ARMOR_COUNT.font_name, nt.ARMOR_COUNT.font_size, nt.ARMOR_COUNT.font_flag)
				end
			  
				local a, r, g, b = hex_to_argb(nt.ARMOR_COUNT.font_color)
				local font_color = new.float[4](r / 255, g / 255, b / 255, a / 255) 
				if imgui.ColorEdit4(faicons.ICON_SPINNER .. "  Font color##armorcount", font_color) then
					nt.ARMOR_COUNT.font_color = join_argb(font_color[3] * 255, font_color[0]  * 255, font_color[1]  * 255, font_color[2]  * 255) 
				end
				imgui.PopItemWidth()
			end
			if current_table == 6 then
				imgui.PushItemWidth(300)
		  
				if imgui.Checkbox('Draw player chat bubble##chatbubble', new.bool(nt.CHAT_BUBBLE.enabled)) then
					nt.CHAT_BUBBLE.enabled = not nt.CHAT_BUBBLE.enabled
				end
		  
				text = new.char[256](nt.CHAT_BUBBLE.font_name)
				if imgui.InputText('##font', text, sizeof(text), imgui.InputTextFlags.EnterReturnsTrue) then
					nt.CHAT_BUBBLE.font_name = u8:decode(str(text))
					bubble_font = renderCreateFont(nt.CHAT_BUBBLE.font_name, nt.CHAT_BUBBLE.font_size, nt.CHAT_BUBBLE.font_flag)
				end
				imgui.SameLine()
				imgui.Text(faicons.ICON_FONT .. u8(string.format('  Font Name (%s)', nt.CHAT_BUBBLE.font_name)))
		  
				
				local font_size = new.int[1](nt.CHAT_BUBBLE.font_size)
				if imgui.InputInt(faicons.ICON_TEXT_WIDTH .. "  Font size##chatbubble", font_size) then
					  nt.CHAT_BUBBLE.font_size = font_size[0]
					  bubble_font = renderCreateFont(nt.CHAT_BUBBLE.font_name, nt.CHAT_BUBBLE.font_size, nt.CHAT_BUBBLE.font_flag)
				end
			  
				local font_flag = new.int[1](nt.CHAT_BUBBLE.font_flag)
				if imgui.InputInt(faicons.ICON_FLAG .. "  Font flag##chatbubble", font_flag) then
					  nt.CHAT_BUBBLE.font_flag = font_flag[0]
					  bubble_font = renderCreateFont(nt.CHAT_BUBBLE.font_name, nt.CHAT_BUBBLE.font_size, nt.CHAT_BUBBLE.font_flag)
				end
				
				local opacity = new.int[1](nt.CHAT_BUBBLE.opacity)
				if imgui.SliderInt(faicons.ICON_SPINNER .. ' Chat bubble text opacity', opacity, 0, 255) then
					nt.CHAT_BUBBLE.opacity = opacity[0]
				end
				
				local indent = new.int[1](nt.CHAT_BUBBLE.indent)
				if imgui.SliderInt(faicons.ICON_ARROW_UP .. ' Chat bubble offset by Y axis', indent, 0, 200) then 
					nt.CHAT_BUBBLE.indent = indent[0]
				end
				
				local line_offset = new.int[1](nt.CHAT_BUBBLE.line_offset)
				if imgui.SliderInt(faicons.ICON_SLIDERS .. ' Offset between lines', line_offset, 0, 200) then
					nt.CHAT_BUBBLE.line_offset = line_offset[0]
				end
				
				local line_offset = new.int[1](nt.CHAT_BUBBLE.max_symbols)
				if imgui.InputInt(faicons.ICON_FONT .. ' Maximal symbols in chat bubble line', line_offset) then
					nt.CHAT_BUBBLE.max_symbols = line_offset[0]
				end
				imgui.PopItemWidth()
			end
		imgui.EndChild()

		imgui.SetCursorPos(imgui.ImVec2(92, 384))
		
		imgui.BeginChild("##4", imgui.ImVec2(615, 38), true)
			imgui.SetCursorPos(imgui.ImVec2(10, 10))  
			imgui.PushItemWidth(300)
			
			local vertical_indent = new.float[1](nt.GENERAL.vertical_indent)
			if imgui.SliderFloat(faicons.ICON_COGS .. '  NameTag vertical offset', vertical_indent, -2, 2) then 
				nt.GENERAL.vertical_indent = vertical_indent[0]
			end
			imgui.PopItemWidth()
			imgui.SameLine()
			if imgui.Checkbox('Show Playertag', new.bool(nt.showplayername)) then
				nt.showplayername = not nt.showplayername
			end
		imgui.EndChild()
		
	imgui.End()
end)

function blankIni()
	nt = table.deepcopy(blank)
	saveIni()
	loadIni()
end

function loadIni() 
	local f = io.open(cfg, "r") 
	if f then 
		nt = decodeJson(f:read("*all")) 
		f:close() 
	end
end

function saveIni()
	if type(nt) == "table" then 
		local f = io.open(cfg, "w") 
		f:close() 
		if f then 
			f = io.open(cfg, "r+") 
			f:write(encodeJson(nt)) 
			f:close() 
		end 
	end
end


function apply_custom_style()
	imgui.SwitchContext()
	local ImVec4 = imgui.ImVec4
	local ImVec2 = imgui.ImVec2
	local style = imgui.GetStyle()
	style.WindowRounding = 0
	style.WindowPadding = ImVec2(8, 8)
	style.WindowTitleAlign = ImVec2(0.5, 0.5)
	--style.ChildWindowRounding = 0
	style.FrameRounding = 0
	style.ItemSpacing = ImVec2(8, 4)
	style.ScrollbarSize = 10
	style.ScrollbarRounding = 3
	style.GrabMinSize = 10
	style.GrabRounding = 0
	style.Alpha = 1
	style.FramePadding = ImVec2(4, 3)
	style.ItemInnerSpacing = ImVec2(4, 4)
	style.TouchExtraPadding = ImVec2(0, 0)
	style.IndentSpacing = 21
	style.ColumnsMinSpacing = 6
	style.ButtonTextAlign = ImVec2(0.5, 0.5)
	style.DisplayWindowPadding = ImVec2(22, 22)
	style.DisplaySafeAreaPadding = ImVec2(4, 4)
	style.AntiAliasedLines = true
	--style.AntiAliasedShapes = true
	style.CurveTessellationTol = 1.25
	local colors = style.Colors
	local clr = imgui.Col
	colors[clr.FrameBg]                = ImVec4(0.48, 0.16, 0.16, 0.54)
	colors[clr.FrameBgHovered]         = ImVec4(0.98, 0.26, 0.26, 0.40)
	colors[clr.FrameBgActive]          = ImVec4(0.98, 0.26, 0.26, 0.67)
	colors[clr.TitleBg]                = ImVec4(0.04, 0.04, 0.04, 1.00)
	colors[clr.TitleBgActive]          = ImVec4(0.48, 0.16, 0.16, 1.00)
	colors[clr.TitleBgCollapsed]       = ImVec4(0.00, 0.00, 0.00, 0.51)
	colors[clr.CheckMark]              = ImVec4(0.98, 0.26, 0.26, 1.00)
	colors[clr.SliderGrab]             = ImVec4(0.88, 0.26, 0.24, 1.00)
	colors[clr.SliderGrabActive]       = ImVec4(0.98, 0.26, 0.26, 1.00)
	colors[clr.Button]                 = ImVec4(0.98, 0.26, 0.26, 0.40)
	colors[clr.ButtonHovered]          = ImVec4(0.98, 0.26, 0.26, 1.00)
	colors[clr.ButtonActive]           = ImVec4(0.98, 0.06, 0.06, 1.00)
	colors[clr.Header]                 = ImVec4(0.98, 0.26, 0.26, 0.31)
	colors[clr.HeaderHovered]          = ImVec4(0.98, 0.26, 0.26, 0.80)
	colors[clr.HeaderActive]           = ImVec4(0.98, 0.26, 0.26, 1.00)
	colors[clr.Separator]              = colors[clr.Border]
	colors[clr.SeparatorHovered]       = ImVec4(0.75, 0.10, 0.10, 0.78)
	colors[clr.SeparatorActive]        = ImVec4(0.75, 0.10, 0.10, 1.00)
	colors[clr.ResizeGrip]             = ImVec4(0.98, 0.26, 0.26, 0.25)
	colors[clr.ResizeGripHovered]      = ImVec4(0.98, 0.26, 0.26, 0.67)
	colors[clr.ResizeGripActive]       = ImVec4(0.98, 0.26, 0.26, 0.95)
	colors[clr.TextSelectedBg]         = ImVec4(0.98, 0.26, 0.26, 0.35)
	colors[clr.Text]                   = ImVec4(1.00, 1.00, 1.00, 1.00)
	colors[clr.TextDisabled]           = ImVec4(0.50, 0.50, 0.50, 1.00)
	colors[clr.WindowBg]               = ImVec4(0.06, 0.06, 0.06, 0.94)
	--colors[clr.ChildWindowBg]          = ImVec4(1.00, 1.00, 1.00, 0.00)
	colors[clr.PopupBg]                = ImVec4(0.08, 0.08, 0.08, 0.94)
	--colors[clr.ComboBg]                = colors[clr.PopupBg]
	colors[clr.Border]                 = ImVec4(0.43, 0.43, 0.50, 0.50)
	colors[clr.BorderShadow]           = ImVec4(0.00, 0.00, 0.00, 0.00)
	colors[clr.MenuBarBg]              = ImVec4(0.14, 0.14, 0.14, 1.00)
	colors[clr.ScrollbarBg]            = ImVec4(0.02, 0.02, 0.02, 0.53)
	colors[clr.ScrollbarGrab]          = ImVec4(0.31, 0.31, 0.31, 1.00)
	colors[clr.ScrollbarGrabHovered]   = ImVec4(0.41, 0.41, 0.41, 1.00)
	colors[clr.ScrollbarGrabActive]    = ImVec4(0.51, 0.51, 0.51, 1.00)
	--colors[clr.CloseButton]            = ImVec4(0.41, 0.41, 0.41, 0.50)
	--colors[clr.CloseButtonHovered]     = ImVec4(0.98, 0.39, 0.36, 1.00)
	--colors[clr.CloseButtonActive]      = ImVec4(0.98, 0.39, 0.36, 1.00)
	colors[clr.PlotLines]              = ImVec4(0.61, 0.61, 0.61, 1.00)
	colors[clr.PlotLinesHovered]       = ImVec4(1.00, 0.43, 0.35, 1.00)
	colors[clr.PlotHistogram]          = ImVec4(0.90, 0.70, 0.00, 1.00)
	colors[clr.PlotHistogramHovered]   = ImVec4(1.00, 0.60, 0.00, 1.00)
	--colors[clr.ModalWindowDarkening]   = ImVec4(0.80, 0.80, 0.80, 0.35)
end