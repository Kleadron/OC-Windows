if not _WINVER then
	print("This program requires Windows.")
	return
end

local component = require("component")
local computer = require("computer")

local handles = {}
local details = {}
details.name = "Iterator"
details.priority = 1
details.stayResident = false
handles.details = details

local iterator = 0
local testContent = {"This should count to 5","and then quit"}

handles.start = function()
	--iterator = 0
	--computer.beep(400, 0)
	winAPI.addWindow(15,7,30,4,details.name,1,"Generic","counter " .. iterator,{"counting test program", "placeholder"})
end

handles.run = function()
	--computer.beep(300, 0)
	--error("test")
	iterator = iterator + 1
	if iterator == 300 then
		error(300)
	end
	--this will be moved to repaint
	winAPI.updateWindow(details.name, 1, "counter " .. iterator, {"counting test program", math.floor(computer.freeMemory() / computer.totalMemory() * 100) .. "% free"})
	--print("counter " .. iterator)
end

handles.repaint = function(id, iInfo)
	--id will be for one of this application's windows that the system wants you to repaint
	--iInfo (interaction info) will be nil unless the user has directly interacted with specified window id
	--otherwise you can just create buttons and other controls
	--all positions will be relative to the window position
	
	--example text
	winAPI.text(1, 1, "Click test I dare you")
	
	--example control, button returns false if not clicked and true if clicked
	--width is pretty much determined by string length
	--if you want a wider button, add more spaces
	if winAPI.button(1, 2, " test ") then
		testButtonPressed()
	end
end 

handles.stop = function()
	computer.beep(200, 0)
	--debating if the application should need to do this itself or if the system can just do it for you, since it will kill all unlinked windows anyway
	winAPI.removeWindow(details.name, 1)
end

return handles