--CONFIG
backgroundChar = {"▒", false}

--NO TOUCHY BEYOND THIS POINT
_WINNAME = "Windows"
_WINVER = 0.1
_WINFULLNAME = _WINNAME .. " " .. _WINVER
local term = require("term")
local os = require("os")
--local event = require("event")
local component = require("component")
local keyboard = require("keyboard")
local gpu = component.gpu
local computer = component.computer
screenWidth, screenHeight = gpu.getResolution()

local windowList = {}
--local windowRects = {{5, 3, 40, 7},{2, 1, 40, 7},{6, 7, 40, 7}}

--sets characters for screen change
local screenChanges = {}

gpu.fill(1, 1, screenWidth, screenHeight, " ")
gpu.set(1, 1, "Kleadron Software Windows")

for x = 1, screenWidth do
	screenChanges[x] = {}
	for y = 1, screenHeight do
		screenChanges[x][y] = true
	end
end

local function setScreenChanges(set)
	for x = 1, screenWidth do
		for y = 1, screenHeight do
			screenChanges[x][y] = set
		end
	end
end

local function setScreenChange(x,y,layer,override)
	if x > screenWidth or x < 1 or y > screenHeight or y < 1 then
		return true
	end
	if layer + 1 > #windowList then
		screenChanges[x][y] = true
		return true
	end
	--overrides
	if layer < 0 then
		screenChanges[x][y] = true
		return true
	end
	if override then
		screenChanges[x][y] = true
		return true
	end
	for i = layer + 1, #windowList do
		if x >= windowList[i].x and x <= windowList[i].x + windowList[i].w then
			if y >= windowList[i].y and y <= windowList[i].y + windowList[i].h then
				return false
			end
		end
	end
	screenChanges[x][y] = true
	return true
end

local function getScreenChange(x,y)
	if x > screenWidth or x < 1 or y > screenHeight or y < 1 then
		return false
	end
	return screenChanges[x][y]
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

checkLayer(1,1,1)
checkLayer(2,1,1)
checkLayer(2,9,1)

local ignoreScreenChange = false
--Draws a character onto the screen safely, checks if there is anything above the layer of the window rect
local function drawChar(x,y,character,inverted,layer)
	if x > screenWidth or x < 1 or y > screenHeight or y < 1 then
		return
	end
	if not screenChanges[x][y] then
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
		screenChanges[x][y] = false
	end
end

--Draws a string onto the screen using drawChar
local function drawString(x, y, inputString, inverted, layer)
	for i = 0, string.len(inputString) do
		drawChar(x - 1 + i, y, string.sub(inputString, i, i), inverted, layer)
	end
end


local initialBGDraw = false
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
					exclusionMap[i][j] = false;
				else
					exclusionMap[i][j] = true;
				end
			else
				exclusionMap[i][j] = true;
			end
		end
	end
	return exclusionMap
end

--Draws window
--isSelected should be true for the topmost or "selected" window in the list
local function drawWindow(x,y,w,h,title,layer,exclusionMap,isSelected)
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
				drawChar(x+i,y,"▤",false,layer)
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
			if exclusionMap[i][o] then
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
			if exclusionMap[i][o] then
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
	ignoreScreenChange = true
	--Draw top
	for i=0, w do
		if x+i <= screenWidth and x+i >= 1 then
			if y <= screenHeight and y >= 1 then
				charAtPos, charFG, charBG = gpu.get(x+i,y)
				doInvert = true
				needRepaint = getScreenChange(x+i,y)
				if charFG == 0x000000 then
					doInvert = false
				end
				drawChar(x+i,y,charAtPos,doInvert,-1)
				if needRepaint then
					setScreenChange(x+i,y,-1,true)
				end
			end
		end
		
	end
	--Draw walls
	for i=1, h-1 do
		if x <= screenWidth and x >= 1 then
			if y+i <= screenHeight and y+i >= 1 then
				charAtPos, charFG, charBG = gpu.get(x,y+i)
				doInvert = true
				needRepaint = getScreenChange(x,y+i)
				if charFG == 0x000000 then
					doInvert = false
				end
				drawChar(x,y+i,charAtPos,doInvert,-1)
				if needRepaint then
					setScreenChange(x,y+i,-1,true)
				end
			end
		end
		if x+w <= screenWidth and x+w >= 1 then
			if y+i <= screenHeight and y+i >= 1 then
				charAtPos, charFG, charBG = gpu.get(x+w,y+i)
				doInvert = true
				needRepaint = getScreenChange(x+w,y+i)
				if charFG == 0x000000 then
					doInvert = false
				end
				drawChar(x+w,y+i,charAtPos,doInvert,-1)
				if needRepaint then
					setScreenChange(x+w,y+i,-1,true)
				end
			end
		end
	end
	--Draw bottom
	for i=0, w do
		if x+i <= screenWidth and x+i >= 1 then
			if y+h <= screenHeight and y+h >= 1 then
				charAtPos, charFG, charBG = gpu.get(x+i,y+h)
				doInvert = true
				needRepaint = getScreenChange(x+i,y+h)
				if charFG == 0x000000 then
					doInvert = false
				end
				drawChar(x+i,y+h,charAtPos,doInvert,-1)
				if needRepaint then
					setScreenChange(x+i,y+h,-1,true)
				end
			end
		end
	end
	ignoreScreenChange = false
end

local function flashWindowOutline(layer)
	drawOutline(windowRects[layer][1],windowRects[layer][2],windowRects[layer][3],windowRects[layer][4])
	drawOutline(windowRects[layer][1],windowRects[layer][2],windowRects[layer][3],windowRects[layer][4])
end

local function drawButton(x,y,text,clicked,layer)
	if clicked then
		drawString(x,y,text,false,layer)
	else
		drawString(x,y,text,true,layer)
	end
end

local function windowDialog(x,y,w,h,title,text,layer,selected)
	local active = false
	
	local exclusionMap = makeExclusionMap(w, h, text)
	drawWindow(x, y, w, h, title, layer, exclusionMap, selected)
	
	for i = 1, h do
		if text[i] ~= nil then 
			drawString(x+1,y+i,text[i],false,layer)
		end
	end
	
	ignoreScreenChange = true
	drawButton(x + w - 17, y + h - 1, "Cancel", false,layer)
	drawButton(x + w - 8, y + h - 1, "  OK  ", false,layer)
	ignoreScreenChange = false
	
	while active do 
		local id, _, touchX, touchY = event.pull("touch")
		if id == "touch" then
			if touchX >= x+w-8 and touchX <= x+w-3 then 
				if touchY >= y+h-1 and touchY <= y+h-1 then
					drawButton(x + w - 8, y + h - 1, "  OK  ", true, layer)
					computer.beep(700)
					drawButton(x + w - 8, y + h - 1, "  OK  ", false, layer)
					active = false
					return 0
				end
			end
			if touchX >= x+w-17 and touchX <= x+w-12 then 
				if touchY >= y+h-1 and touchY <= y+h-1 then
					drawButton(x + w - 17, y + h - 1, "Cancel", true, layer)
					computer.beep(500)
					drawButton(x + w - 17, y + h - 1, "Cancel", false, layer)
					active = false
					return 1
				end
			end
		end
		os.sleep(0.1)
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

local function markRectRepaint(rect)
	for x = windowRects[rect][1], windowRects[rect][1] + windowRects[rect][3] do
		for y = windowRects[rect][2], windowRects[rect][2] + windowRects[rect][4] do
			setScreenChange(x, y, rect, true)
		end
	end
end

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

--marks a window area for repainting, internal use only
function winAPI.markRepaint(name, ID)
	if ID == nil then
		ID = 0
	end
	foundWindow = winAPI.findWindow(name, ID)
	if foundWindow > 0 then
		for x = windowList[foundWindow].x, windowList[foundWindow].x + windowList[foundWindow].w do
			for y = windowList[foundWindow].y, windowList[foundWindow].y + windowList[foundWindow].h do
				setScreenChange(x, y, foundWindow, true)
			end
		end
		return true
	end
	return false
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
		winAPI.markRepaint(name, ID)
		windowCache = windowList[foundWindow] --store the found window in a cache for later
		--shift all windows after the found window downward
		for i = foundWindow, #windowList-1 do
			windowList[i] = windowList[i+1]
			winAPI.markRepaint(windowList[i].name, windowList[i].ID)
		end
		windowList[#windowList] = windowCache --set the topmost window as the cached(found) window
		return true --the operation completed succesfully
	end
	return false --window not found - could not bring to front
end

--Add a window to the window list
--window layer is the position in the table
function winAPI.addWindow(x, y, w, h, name, ID, windowType, title, content)
	if #windowList > 0 then
		winAPI.markRepaint(windowList[#windowList].name, windowList[#windowList].ID)
	end
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
	
	winAPI.markRepaint(name, ID)
	
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
		winAPI.markRepaint(name, ID)
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
		winAPI.markRepaint(name, ID)
		table.remove(windowList, foundWindow)
		if #windowList > 0 then
			winAPI.markRepaint(windowList[#windowList].name, windowList[#windowList].ID)
		end
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
			winAPI.markRepaint(name, ID)
			windowList[foundWindow].x = windowList[foundWindow].x + x
			windowList[foundWindow].y = windowList[foundWindow].y + y
			winAPI.markRepaint(name, ID)
			return true
		end
		if moveType == "Reposition" then
			winAPI.markRepaint(name, ID)
			windowList[foundWindow].x = x
			windowList[foundWindow].y = y
			winAPI.markRepaint(name, ID)
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
	drawOutline(x,y,w,h)
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

--end window utilities

local function repaint()
	--repainting from forward to backward
	i = #windowList
	while i > 0 do
		--computer.beep(300, 0)
		isTopMost = false
		if i == #windowList then
			isTopMost = true
		end
		if windowList[i].windowType == "Dialog" then
			windowDialog(windowList[i].x, windowList[i].y, windowList[i].w, windowList[i].h, windowList[i].title, windowList[i].content, i, isTopMost)
		end
		if windowList[i].windowType == "Generic" then
			windowGeneric(windowList[i].x, windowList[i].y, windowList[i].w, windowList[i].h, windowList[i].title, windowList[i].content, i, isTopMost)
		end
		i = i - 1
	end
	drawBG(backgroundChar[1], backgroundChar[2])
end

--scheduler functions
local processes = {}
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
		error('Scheduler: Process "' .. program.details.name ..'" already exists!')
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
local function errorScreen(err)
	local crashText = "Windows has crashed :["
	
	gpu.setForeground(0xFFFFFF)
	if gpu.getDepth() > 1 then
		gpu.setBackground(0x0000FF)
	else
		gpu.setBackground(0x000000)
	end
	gpu.fill(1, 1, screenWidth, screenHeight, " ")
	
	term.setCursor(1,1)
	term.write(crashText)
	term.setCursor(1,2)
	print("")
	print(err)
	print("")
	print("Processes:")
	for i = 1, #processes do
		print(" N[" .. processes[i].program.details.name .. "] F[" .. processes[i].filename .. "]")
	end
	--while #processes > 0 do
	--	scheduler.removeProcess(processes[#processes].program.details.name, true)
	--end
	--print("Processes terminated")
	print("")
	
	term.setCursor(1,screenHeight-1)
	print(debug.traceback)
	term.setCursor(1,screenHeight)
	term.write("Press SPACE to exit")
	
	pressedSpace = false
	while not pressedSpace do
		if keyboard.isKeyDown(0x39) then
			pressedSpace = true
		end
		os.sleep(0.1)
	end
	--computer.shutdown(true)
	gpu.setForeground(0xFFFFFF)
	gpu.setBackground(0x000000)
	term.clear()
	term.setCursor(1,1)
end


--THE MAIN FUNCTION :D
local function main()
	scheduler.runProcesses()
	repaint()
end

function runWinApp(filename)
	local file = require(filename)
	if file ~= nil then
		scheduler.addProcess(file, filename)
		--repaint()
		return true
	end
	return false
end

local demoDialog1text = {"This is a test message.", "Click OK to do something.", "Cancel works too."}
local demoDialog2text = {"You won't see the text under this line.", "Click OK to go boom boom.", "  konata best"}
local demoDialog3text = {"This is testing bringToFront", "Click OK to do nothing.", "Cancel never worked."}

function demo()
	winAPI.addWindow(6,7,40,7,"dialog1",nil,"Dialog","Warning",demoDialog1text)
	winAPI.addWindow(2,1,40,7,"dialog2",nil,"Dialog","Warning",demoDialog2text)
	winAPI.addWindow(5,3,40,7,"dialog3",nil,"Dialog","Warning",demoDialog3text)
	repaint()
	os.sleep(1)
	
	runWinApp("test")
	runWinApp("test2")
	for i = 1, 5 do
		main()
	end
	--error("poo")
	scheduler.removeProcess("Iterator", false)
	scheduler.removeProcess("Iterator 2", false)
	repaint()
	os.sleep(1)
	
	winAPI.bringToFront("dialog1",nil)
	repaint()
	os.sleep(1)
	
	for i = 0, 5 do
		winAPI.flashOutline(6,7+i,40,7)
	end
	for i = 0, 5 do
		winAPI.flashOutline(6+i,12,40,7)
	end
	
	winAPI.moveWindow(5,5,"dialog1",nil,"Translate")
	repaint()
	--os.sleep(1)
	--winAPI.addWindow(screenWidth/2 - 15,screenHeight/2 - 2,30,4,"crashmsg",nil,"Generic","Uh oh",{"Windows will now...","CRASH :D"})
	--repaint()
	--os.sleep(0.5)
	--error("Test crash :D")
end

function demo2()
	winAPI.addWindow(4,2,40,7,"dialog1",nil,"Dialog","Dialog",{"This is a dialog box","This is also an example"})
	winAPI.addWindow(49,6,30,4,"generic1",nil,"Generic","Generic",{"This is a generic window","This is also an example, too"})
	repaint()
	os.sleep(5)
end

function runOS()
	while true do
		
	end
end

--Main code
drawBG(backgroundChar[1], backgroundChar[2])
setScreenChanges(false)
local status, err = pcall(demo)

if not status then
	errorScreen(err)
	--os.sleep(5)
end

term.setCursor(1,1)