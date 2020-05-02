--CONFIG
--backroung character, inverted
backgroundChar = {"▒", false}

--NO TOUCHY BEYOND THIS POINT
_WINNAME = "Windows"
_WINVER = "0.0.0.2"
_WINFULLNAME = _WINNAME .. " " .. _WINVER
local term = require("term")
local os = require("os")
local event = require("event")
local component = require("component")
local keyboard = require("keyboard")
local gpu = component.gpu
local screen = component.screen
local computer = require("computer")
local screenWidth, screenHeight = gpu.getResolution()

local running = true

local windowList = {}
--local windowRects = {{5, 3, 40, 7},{2, 1, 40, 7},{6, 7, 40, 7}}

--not exactly a buffer but a change tracker stored in memory seperately from the screen because gpu calls = slow >:(
local screenBuffer = {}

--gpu.fill(1, 1, screenWidth, screenHeight, " ")
--gpu.set(1, 1, _WINFULLNAME)
term.clear()
print(_WINFULLNAME)
print("If you have been returned to the prompt, idk what happened but you may not have enough memory.")
print("Please increase your system memory or lower your screen resolution.")



for x = 1, screenWidth do
	screenBuffer[x] = {}
	for y = 1, screenHeight do
		screenBuffer[x][y] = {}
		screenBuffer[x][y].character = backgroundChar[1]
		screenBuffer[x][y].inverted = backgroundChar[2]
	end
end

local errorStackTrace = nil
function getStackTrace()
	errorStackTrace = debug.traceback()
end

--checks all window rectangle layers above the layer given, returns true if the point doesn't intrude on any, false if the point is obstructed
local function checkLayer(x,y,layer)
	if layer + 1 > #windowList then
		return true
	end
	--override
	if layer < 0 then
		return true
	end
	for i = layer + 1, #windowList do
		if x >= windowList[i].x and x <= windowList[i].x + windowList[i].w then
			if y >= windowList[i].y and y <= windowList[i].y + windowList[i].h then
				return false
			end
		end
	end
	return true
end

local ignoreScreenChange = false
--Draws a character onto the screen safely, checks if there is anything above the layer of the window rect
local function drawChar(x,y,character,inverted,layer)
	if x > screenWidth or x < 1 or y > screenHeight or y < 1 then
		return
	end
	if screenBuffer[x][y].character == character and screenBuffer[x][y].inverted == inverted then
		if not ignoreScreenChange then
			return
		end
	end
	if checkLayer(x,y,layer) then
		if inverted then
			gpu.setForeground(0x000000)
			gpu.setBackground(0xFFFFFF)
		else
			gpu.setForeground(0xFFFFFF)
			gpu.setBackground(0x000000)
		end
		gpu.set(x, y, character)
		screenBuffer[x][y].character = character
		screenBuffer[x][y].inverted = inverted
	end
end

--Draws a string onto the screen using drawChar
local function drawString(x, y, inputString, inverted, layer)
	for i = 0, string.len(inputString) do
		drawChar(x - 1 + i, y, string.sub(inputString, i, i), inverted, layer)
	end
end


local initialBGDraw = false --has the background been drawn yet?
function drawBG(bgChar, inverted)
	if not initialBGDraw then
		if inverted then
			gpu.setForeground(0x000000)
			gpu.setBackground(0xFFFFFF)
		else
			gpu.setForeground(0xFFFFFF)
			gpu.setBackground(0x000000)
		end
		gpu.fill(1, 1, screenWidth, screenHeight, bgChar)
		initialBGDraw = true
		return
	end
	--ignoreScreenChange = true
	for y = 1, screenHeight do
		for x = 1, screenWidth do
			drawChar(x, y, bgChar, inverted, 0)
		end
	end
	--ignoreScreenChange = false
end

--create exclusion map for background of window using content array
--width of rect, height of rect
--exclusion: true = paint, false = don't paint
--this is for putting stuff inside the window
local function makeExclusionMap(w,h,content)
	local exclusionMap = {}
	for i = 1, h-1 do
		exclusionMap[i] = {}
		for j = 1, w-1 do
			if content[i] ~= nil then
				if j <= string.len(content[i]) then
					exclusionMap[i][j] = true;
				else
					exclusionMap[i][j] = false;
				end
			else
				exclusionMap[i][j] = false;
			end
		end
	end
	return exclusionMap
end

--Draws window
--isSelected should be true for the topmost or "selected" window in the list
local function drawWindow(x,y,w,h,title,layer,exclusionMap,isSelected,important)
	--ignoreScreenChange = true
	fullTitle = " " .. title .. " "
	if exclusionMap == nil then
		exclusionMap = makeExclusionMap(w,h,{""})
	end
	--Draw top
	--drawChar(x,y,"☰",false,layer)
	drawChar(x,y,"⣿",false,layer)
	for i=1, w-1 do
		if i > string.len(fullTitle) then
			if isSelected then
				if important then
					drawChar(x+i,y,"▨",false,layer)
				else 
					drawChar(x+i,y,"▤",false,layer)
				end
				--drawChar(x+i,y,"▒",false,layer)
			else
				drawChar(x+i,y,"⣿",false,layer)
			end
		end
	end
	drawChar(x+w,y,"⣿",false,layer)
	--Draw walls and inner
	for i=1, h-1 do
		drawChar(x,y+i,"⡇",false,layer)
		for o=1, w-1 do
			if not exclusionMap[i][o] then
				drawChar(x+o,y+i," ",false,layer)
			end
		end
		drawChar(x+w,y+i,"⢸",false,layer)
	end
	--Draw bottom
	drawChar(x,y+h,"⣇",false,layer)
	for i=1, w-1 do
		drawChar(x+i,y+h,"⣀",false,layer)
	end
	drawChar(x+w,y+h,"⣸",false,layer)
	
	--done drawing the frame, draw title bar
	--ignoreScreenChange = true
	drawString(x+1,y,fullTitle,not isSelected,layer)
	--ignoreScreenChange = false
end

--like a window but without a titlebar
local function drawBox(x,y,w,h,layer,exclusionMap)
	if exclusionMap == nil then
		exclusionMap = makeExclusionMap(w,h,{""})
	end
	--Draw top
	drawChar(x,y,"⡏",false,layer)
	for i=1, w-1 do
		drawChar(x+i,y,"⠉",false,layer)
	end
	drawChar(x+w,y,"⢹",false,layer)
	--Draw walls and inner
	for i=1, h-1 do
		drawChar(x,y+i,"⡇",false,layer)
		for o=1, w-1 do
			if not exclusionMap[i][o] then
				drawChar(x+o,y+i," ",false,layer)
			end
		end
		drawChar(x+w,y+i,"⢸",false,layer)
	end
	--Draw bottom
	drawChar(x,y+h,"⣇",false,layer)
	for i=1, w-1 do
		drawChar(x+i,y+h,"⣀",false,layer)
	end
	drawChar(x+w,y+h,"⣸",false,layer)
end

--Draws inverted outline (useful for determining moved window location)
local function drawOutline(x,y,w,h)
	--ignoreScreenChange = true
	--Draw top
	for i=0, w do
		if x+i <= screenWidth and x+i >= 1 then
			if y <= screenHeight and y >= 1 then
				charAtPos, charFG, charBG = gpu.get(x+i,y)
				doInvert = true
				if charFG == 0x000000 then
					doInvert = false
				end
				drawChar(x+i,y,charAtPos,doInvert,-1)
			end
		end
		
	end
	--Draw walls
	for i=1, h-1 do
		if x <= screenWidth and x >= 1 then
			if y+i <= screenHeight and y+i >= 1 then
				charAtPos, charFG, charBG = gpu.get(x,y+i)
				doInvert = true
				if charFG == 0x000000 then
					doInvert = false
				end
				drawChar(x,y+i,charAtPos,doInvert,-1)
			end
		end
		if x+w <= screenWidth and x+w >= 1 then
			if y+i <= screenHeight and y+i >= 1 then
				charAtPos, charFG, charBG = gpu.get(x+w,y+i)
				doInvert = true
				if charFG == 0x000000 then
					doInvert = false
				end
				drawChar(x+w,y+i,charAtPos,doInvert,-1)
			end
		end
	end
	--Draw bottom
	for i=0, w do
		if x+i <= screenWidth and x+i >= 1 then
			if y+h <= screenHeight and y+h >= 1 then
				charAtPos, charFG, charBG = gpu.get(x+i,y+h)
				doInvert = true
				if charFG == 0x000000 then
					doInvert = false
				end
				drawChar(x+i,y+h,charAtPos,doInvert,-1)
			end
		end
	end
	--ignoreScreenChange = false
end

--Draws inverted outline (useful for determining moved window location)
local function drawLineX(x,y,w)
	--ignoreScreenChange = true
	--Draw top
	for i=0, w do
		if x+i <= screenWidth and x+i >= 1 then
			if y <= screenHeight and y >= 1 then
				charAtPos, charFG, charBG = gpu.get(x+i,y)
				doInvert = true
				if charFG == 0x000000 then
					doInvert = false
				end
				drawChar(x+i,y,charAtPos,doInvert,-1)
			end
		end
		
	end
end

local function drawButton(x,y,text,clicked,layer)
	if clicked then
		drawString(x,y,text,false,layer)
	else
		drawString(x,y,text,true,layer)
	end
end

--repurposed for internal system use
--applications should have their own 
local function windowSystemDialog(x,y,w,h,title,text,layer,selected,doCancel)
	x = math.floor(x)
	y = math.floor(y)

	--computer.beep(200)
	
	local active = true
	
	local exclusionMap = makeExclusionMap(w, h, text)
	drawWindow(x, y, w, h, title, layer, exclusionMap, selected, true)
	
	for i = 1, h do
		if text[i] ~= nil then 
			drawString(x+1,y+i,text[i],false,layer)
		end
	end
	
	if doCancel then
		drawButton(x + w - 17, y + h - 1, "Cancel", false,layer)
	end
	drawButton(x + w - 8, y + h - 1, "  OK  ", false,layer)
	
	while active do 
		local id, _, touchX, touchY = event.pull()
		if id == "touch" then
			if touchX >= x+w-8 and touchX <= x+w-3 then 
				if touchY >= y+h-1 and touchY <= y+h-1 then
					drawButton(x + w - 8, y + h - 1, "  OK  ", true, layer)
					--computer.beep(700)
					os.sleep(0.1)
					drawButton(x + w - 8, y + h - 1, "  OK  ", false, layer)
					os.sleep(0.1)
					active = false
					return true
				end
			end
			if doCancel then
				if touchX >= x+w-17 and touchX <= x+w-12 then 
					if touchY >= y+h-1 and touchY <= y+h-1 then
						drawButton(x + w - 17, y + h - 1, "Cancel", true, layer)
						--computer.beep(500)
						os.sleep(0.1)
						drawButton(x + w - 17, y + h - 1, "Cancel", false, layer)
						os.sleep(0.1)
						active = false
						return false
					end
				end
			end
		end
		if id == "key_down" then
			--return true
		end
		--os.sleep(0.1)
	end
end

local function windowGeneric(x,y,w,h,title,text,layer,selected)
	local exclusionMap = makeExclusionMap(w, h, text)
	drawWindow(x, y, w, h, title, layer, exclusionMap, selected)
	for i = 1, h do
		if text[i] ~= nil then 
			drawString(x+1,y+i,text[i],false,layer)
		end
	end
	--ignoreScreenChange = true
	--drawChar(x,y,"☰",true,layer)
	--drawChar(x+w-2,y,"▁",true,layer)
	--drawChar(x+w-1,y,"▯",true,layer)
	--drawChar(x+w,y,"╳",true,layer)
	--drawChar(x+w,y+h,"▨",true,layer)
	--ignoreScreenChange = false
end

--windowDialog(window1x,window1y,window1w, window1h,"Lol title", "Lol text")

--window API
winAPI = {}

--Returns the position of the window in the window list
function winAPI.findWindow(name, ID)
	if ID == nil then
		ID = 0
	end
	for i = 1, #windowList do
		if windowList[i].name == name then
			if windowList[i].ID == ID then
				return i
			end
		end
	end
	--couldn't find it :(
	return -1
end

--Shift a window to the front by name and ID
function winAPI.bringToFront(name, ID)
	if ID == nil then
		ID = 0
	end
	foundWindow = winAPI.findWindow(name, ID)
	windowCache = {}
	if foundWindow == #windowList then
		return true --window is already the topmost
	end
	if foundWindow > 0 then
		windowCache = windowList[foundWindow] --store the found window in a cache for later
		--shift all windows after the found window downward
		for i = foundWindow, #windowList-1 do
			windowList[i] = windowList[i+1]
		end
		windowList[#windowList] = windowCache --set the topmost window as the cached(found) window
		return true --the operation completed succesfully
	end
	return false --window not found - could not bring to front
end

--Add a window to the window list
--window layer is the position in the table
function winAPI.addWindow(x, y, w, h, name, ID, windowType, title, content)
	currentLayer = #windowList+1
	windowList[currentLayer] = {} --add a new window spot
	
	--add parameters
	--rect, name, id, title, content, window type
	windowList[currentLayer].x = x
	windowList[currentLayer].y = y
	windowList[currentLayer].w = w
	windowList[currentLayer].h = h
	
	windowList[currentLayer].name = name
	
	--ID is supposed to be for if there are multiple windows with the same name
	if ID == nil then
		ID = 0
	end
	windowList[currentLayer].ID = ID
	
	windowList[currentLayer].windowType = windowType
	
	if title == nil then
		windowList[currentLayer].title = windowList[currentLayer].name
	else
		windowList[currentLayer].title = title
	end
	
	if content == nil then
		windowList[currentLayer].content = {""}
	else
		windowList[currentLayer].content = content
	end
	
	--winAPI.markRepaint(name, ID)
	
	return true --no problems, window added?
end

--returns the window table as-is
function winAPI.getWindow(name, ID)
	if ID == nil then
		ID = 0
	end
	foundWindow = winAPI.findWindow(name, ID)
	if (foundWindow > 0) then
		return windowList[foundWindow]
	end
	return nil --could not find window to get
end

--sets the window table as-is with the window table given
--i recommend against using this and just using the other helper functions, unless you know what you're doing. use getWindow first
function winAPI.setWindow(name, ID, windowData)
	if ID == nil then
		ID = 0
	end
	foundWindow = winAPI.findWindow(name, ID)
	if (foundWindow > 0) then
		windowList[foundWindow] = windowData
		winAPI.markRepaint(name, ID)
		return true --set window succesfully
	end
	return false --could not find window to set
end

--enables you to refresh and change the contents of a window
function winAPI.updateWindow(name, ID, title, content)
	if ID == nil then
		ID = 0
	end
	foundWindow = winAPI.findWindow(name, ID)
	if (foundWindow > 0) then
		--if not title == nil then
			windowList[foundWindow].title = title
			--print(title)
			--print(windowList[foundWindow].title)
		--end
		--if not content == nil then
			windowList[foundWindow].content = content
		--end
		return true --window found - updated
	end
	return false --window not found - could not update
end

--Remove a window by name and ID
function winAPI.removeWindow(name, ID)
	if ID == nil then
		ID = 0
	end
	foundWindow = winAPI.findWindow(name, ID)
	if foundWindow > 0 then
		table.remove(windowList, foundWindow)
		return true --the window was succesfully deleted
	end
	return false --the window could not be found, not deleted
end

--move types: Translate(adds given coordinates to the existing ones) Reposition(Directly repositions the window to a position)
function winAPI.moveWindow(x, y, name, ID, moveType)
	if ID == nil then
		ID = 0
	end
	foundWindow = winAPI.findWindow(name, ID)
	if foundWindow > 0 then
		if moveType == "Translate" then
			windowList[foundWindow].x = windowList[foundWindow].x + x
			windowList[foundWindow].y = windowList[foundWindow].y + y
			return true
		end
		if moveType == "Reposition" then
			windowList[foundWindow].x = x
			windowList[foundWindow].y = y
			return true
		end
		return false --invalid moveType
	end
	return false --window not found - could not move
end

function winAPI.resizeWindow(w, h, name, ID, resizeType)
	if ID == nil then
		ID = 0
	end
	foundWindow = winAPI.findWindow(name, ID)
	if foundWindow > 0 then
		if resizeType == "Additive" then
			winAPI.markRepaint(name, ID)
			windowList[foundWindow].w = windowList[foundWindow].w + w
			windowList[foundWindow].h = windowList[foundWindow].h + h
			winAPI.markRepaint(name, ID)
			return true
		end
		if resizeType == "Absolute" then
			winAPI.markRepaint(name, ID)
			windowList[foundWindow].w = w
			windowList[foundWindow].h = h
			winAPI.markRepaint(name, ID)
			return true
		end
		return false --invalid resizeType
	end
	return false --window not found - could not resize
end

--flashes the edges of a window
function winAPI.flashWindowOutline(name, ID)
	if ID == nil then
		ID = 0
	end
	foundWindow = winAPI.findWindow(name, ID)
	if foundWindow > 0 then
		drawOutline(windowList[foundWindow].x,windowList[foundWindow].y,windowList[foundWindow].w,windowList[foundWindow].h)
		drawOutline(windowList[foundWindow].x,windowList[foundWindow].y,windowList[foundWindow].w,windowList[foundWindow].h)
		return true
	end
	return false --window not found - could not flash
end

--flash an outline
function winAPI.flashOutline(x, y, w, h)
	drawOutline(x,y,w,h)
	--os.sleep(0.05)
	drawOutline(x,y,w,h)
end

--flash an horizontal line
function winAPI.flashLineX(x, y, w)
	drawLineX(x,y,w)
	--os.sleep(0.05)
	drawLineX(x,y,w)
end

--[[
--template for new functions, do not use
function winAPI.generalTemplate(name, ID)
	if ID == nil then
		ID = 0
	end
	foundWindow = winAPI.findWindow(name, ID)
	if (foundWindow > 0) then
		
	end
end
--]]

--also usable for layer
local windowContextPosition = 0
local windowContextExclusionMap = nil
local windowContextClickX = 0
local windowContextClickY = 0
local windowContextID = 0
local windowContextName = ""

function winAPI.text(x, y, text, inverted)
	wX = windowList[windowContextPosition].x + x
	wY = windowList[windowContextPosition].y + y
	drawString(wX, wY, text, inverted, windowContextPosition)
	for i = 0, text:len()-1 do
		windowContextExclusionMap[y][x+i] = true
	end
end

function winAPI.button(x, y, text)
	wX = windowList[windowContextPosition].x + x
	wY = windowList[windowContextPosition].y + y
	if windowContextClickX >= wX and windowContextClickX <= wX+text:len()-1 then 
		if windowContextClickY == wY then
			winAPI.text(x, y, text, false)
			os.sleep(0.05)
			return true
		end
	end
	winAPI.text(x, y, text, true)
	return false
end

--end window utilities

local processes = {}

local function repaintWindow(position, clickX, clickY)
	windowContextPosition = position
	windowContextExclusionMap = makeExclusionMap(windowList[position].w, windowList[position].h, {""})
	windowContextClickX = clickX
	windowContextClickY = clickY
	windowContextID = windowList[position].ID
	windowContextName = windowList[position].name
	local appName = windowList[position].name
	if #processes < 1 then
		return
	end
	for i = 1, #processes do
		if processes[i].program.details.name == appName then
			if processes[i].program.repaint ~= nil then
				local selected = false
				if position == #windowList then
					selected = true
				end
				local status2 = xpcall(processes[i].program.repaint, getStackTrace, windowList[position].ID)
				if not status2 then
					local f = io.open("repainterr.log","w")
					f:write(errorStackTrace)
					f:close()
					computer.beep(1000)
					computer.beep(1000)
					computer.beep(1000)
					if windowSystemDialog(screenWidth/2-20,screenHeight/2-5,39,8,"Repaint Error - System Halted",{"The window", "\"" .. windowContextName .. "\" " .. windowContextID , "errored during repaint.", "Stack trace written to repainterr.log.", "Click OK to exit, or Cancel to try to", "continue running."},-1,true,true) then
						running = false
					end
				end
				if windowList[position].windowType == "Generic" then
					drawWindow(windowList[position].x, windowList[position].y, windowList[position].w, windowList[position].h, windowList[position].title, position, windowContextExclusionMap, selected)
				end
				--processes[i].program.repaint(windowList[position].ID)
			end
		end
	end
end

local function repaint()
	--repainting from forward to backward
	for j = #windowList, 1, -1 do
	--repainting from backward to forward
	--for i = 1, #windowList do
		--computer.beep(300, 0)
		--isTopMost = false
		--if i == #windowList then
		--	isTopMost = true
		--end
		--if windowList[i].windowType == "Dialog" then
		--	windowDialog(windowList[i].x, windowList[i].y, windowList[i].w, windowList[i].h, windowList[i].title, windowList[i].content, i, isTopMost)
		--end
		--if windowList[i].windowType == "Generic" then
		--	windowGeneric(windowList[i].x, windowList[i].y, windowList[i].w, windowList[i].h, windowList[i].title, windowList[i].content, i, isTopMost)
		--end
		repaintWindow(j, 0, 0)
	end
	drawBG(backgroundChar[1], backgroundChar[2])
end

--returns window's position in the window list based on position
--returns nil for all three if none could be found at the position
local function getWindowAtPos(x, y)
	--forward to backward (important)
	for i = #windowList, 1, -1 do
		isTopMost = false
		if i == #windowList then
			isTopMost = true
		end
		if x >= windowList[i].x and x <= windowList[i].x + windowList[i].w then
			if y >= windowList[i].y and y <= windowList[i].y + windowList[i].h then
				return i
			end
		end
	end
	return nil
end

--scheduler functions

local scheduler = {}

--find process location in oprocess list
function scheduler.findProcess(processName)
	for i = 1, #processes do
		if processes[i].program.details.name == processName then
			return i
		end
	end
	return -1
end

--add process
function scheduler.addProcess(program, filename)
	foundProcess = scheduler.findProcess(program.details.name)
	if foundProcess > 0 then
		windowSystemDialog(screenWidth/2-20,screenHeight/2-4,39,6,"Error Adding Process",{"The program:",program.details.name,"is already loaded"},-1,true,false)
		--error('Scheduler: Process "' .. program.details.name ..'" already exists!')
		return false
	end
	processes[#processes+1] = {}
	processes[#processes].program = program
	processes[#processes].filename = filename
	if processes[#processes].program.start ~= nil then
		processes[#processes].program.start()
	end
	return true
end

--run processes
function scheduler.runProcesses()
	for i = 1, #processes do
		if processes[i].program.run ~= nil then
			processes[i].program.run()
		end
	end
end

--interaction friendly running of processes
local processCounter = 1
local ranProcessName = "none"
function scheduler.runProcessesSlow()
	if #processes > 0 then
		ranProcessName = processes[processCounter].program.details.name
		if processes[processCounter].program.run ~= nil then
			processes[processCounter].program.run()
		end
		processCounter = processCounter + 1
		if processCounter > #processes then
			processCounter = 1
		end
	end
end

--remove process
function scheduler.removeProcess(processName, forceUnload)
	foundProcess = scheduler.findProcess(processName)
	if foundProcess > 0 then
		if processes[foundProcess].program.stop ~= nil then
			processes[foundProcess].program.stop()
		end
		if not processes[foundProcess].program.details.stayResident or forceUnload then
			filename = processes[foundProcess].filename
			package.loaded[filename] = nil
		end
		table.remove(processes, foundProcess)
		return true
	end
	return false
end

--bsod
local function errorScreen()
	local f = io.open("syserror.log","w")
	f:write(errorStackTrace)
	f:close()
	
	local crashText = _WINFULLNAME .. " has encountered a problem"
	
	gpu.setForeground(0xFFFFFF)
	if gpu.getDepth() > 1 then
		gpu.setBackground(0x0000FF)
	else
		gpu.setBackground(0x000000)
	end
	gpu.fill(1, 1, screenWidth, screenHeight, " ")
	
	term.setCursor(1,1)
	print(crashText)
	print("")
	--if err == "interrupted" then
	--	print("i was interrupted >:[")
	--else 
	--	print(err)
	--end
	print("Stack traceback written to syserror.log")
	print("")
	if #processes > 0 then
		print("Processes:")
		for i = 1, #processes do
			print(" " .. processes[i].program.details.name,  "File: " .. processes[i].filename)
		end
	else
		print("No processes loaded, how did this even happen?")
	end
	--while #processes > 0 do
	--	scheduler.removeProcess(processes[#processes].program.details.name, true)
	--end
	--print("Processes terminated")
	print("")
	
	term.setCursor(1,screenHeight-1)
	print(debug.traceback)
	term.setCursor(1,screenHeight)
	term.write("Press CTRL + C to exit")
	
	pressedSpace = false
	while true do
		local id, _, x, y = event.pull(1)
		if id == "interrupted" then
			break
		end
	end
	--computer.shutdown(true)
	gpu.setForeground(0xFFFFFF)
	gpu.setBackground(0x000000)
	term.clear()
	--term.setCursor(1,1)
end


--THE MAIN FUNCTION :D
local function main()
	scheduler.runProcesses()
	repaint()
end

local appLibHandle = nil

function loadAppLib(filename)
	appLibHandle = require(filename)
end

function runWinApp(filename)
	if pcall(loadAppLib, filename) then
		scheduler.addProcess(appLibHandle, filename)
		--repaint()
		return true
	else
		windowSystemDialog(screenWidth/2-20,screenHeight/2-4,39,6,"Program Loading Error",{"The program","\"" .. filename .. "\"","does not exist or cannot be found."},-1,true,false)
		return false
	end
end

local dragFlashWait = 0.25
local lastDragTime = computer.uptime()
local dragging = false
local dragOffset = 0
local dX, dY = 1, 1
local lX, lY = 1, 1

function run()
	--winAPI.addWindow(4,2,12,2,"dragtest",nil,"Generic","test",{"drag me :^)"})
	runWinApp("test")
	--runWinApp("teste")
	--repaint()
	while running do
		local id, _, x, y = event.pull(0)
		if id == "interrupted" then
			--print("soft interrupt, closing")
			if windowSystemDialog(screenWidth/2-20,screenHeight/2-3,40,4,"Exit",{"Are you sure you want to exit Windows?"},-1,true,true) then
				break
			end
		elseif id == "touch" or id == "drag" or id == "drop" or id == "scroll" then
			handleClick(id, x, y, 0)
			--repaint()
		end
		local status1 = xpcall(scheduler.runProcessesSlow, getStackTrace)
		if not status1 then
			local f = io.open("error.log","w")
			f:write(errorStackTrace)
			f:close()
			computer.beep(1000)
			computer.beep(1000)
			computer.beep(1000)
			if windowSystemDialog(screenWidth/2-20,screenHeight/2-5,39,8,"Process Error - System Halted",{"The process", "\"" .. ranProcessName .. "\"", "has encountered an error.", "Stack trace written to error.log.", "Click OK to exit, or Cancel to try to", "continue running."},-1,true,true) then
				break
			end
		end
		if dragging then
			if lastDragTime + dragFlashWait < computer.uptime() then
				lastDragTime = computer.uptime()
				--winAPI.flashOutline(dX - dragOffset, dY, windowList[#windowList].w, windowList[#windowList].h)
				winAPI.flashLineX(dX - dragOffset, dY, windowList[#windowList].w, windowList[#windowList].h)
			end
		else 
			if #processes < 1 then
				--windowSystemDialog(screenWidth/2-20,screenHeight/2-3,40,5,"No Processes",{"No processes are running.","Windows will exit."},-1,true,false)
				--break
			end
			--scheduler.runProcessesSlow()
			if running then
				repaint()
			end
		end
	end
	--runWinApp("test")
end

function handleClick(id, x, y, scrollSpeed)
	if id == "touch" then
		local position = getWindowAtPos(x, y)
		if position ~= nil then
			if not selected then
				winAPI.bringToFront(windowList[position].name, windowList[position].ID)
			end
			repaintWindow(position, x, y)
			if running then
				repaintWindow(position, 0, 0)
			end
		else
			--computer.beep(300)
		end
	end
	if id == "drag" then
		--winAPI.flashOutline(x, y, 40, 7)
		if not dragging then
			if #windowList > 0 then
				if lX >= windowList[#windowList].x and lX <= windowList[#windowList].x + windowList[#windowList].w then
					if lY == windowList[#windowList].y then
						dragging = true
						dragOffset = lX - windowList[#windowList].x
						dX = x
						dY = y
					end
				end
			end
		else 
			dX = x
			dY = y
		end
	end
	if id == "drop" then
		if dragging then
			dragging = false
			winAPI.moveWindow(x - dragOffset, y, windowList[#windowList].name, windowList[#windowList].ID, "Reposition")
		end
		--winAPI.bringToFront("dragtest",nil)
	end
	lX = x
	lY = y
end

--Main code
drawBG(backgroundChar[1], backgroundChar[2])
--setScreenChanges(false)
--run()
local status = xpcall(run, getStackTrace)

if not status then
	errorScreen()
	--os.sleep(5)
end

for i = 1, #processes do
	scheduler.removeProcess(processes[i].program.details.name, false)
end

term.setCursor(1,1)

