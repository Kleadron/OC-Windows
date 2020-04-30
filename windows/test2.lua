if not _WINVER then
	print("This program requires Windows.")
	return
end

local component = require("component")
local computer = component.computer

local handles = {}
local details = {}
details.name = "Iterator 2"
details.priority = 2
details.stayResident = true

local iterator = 0
local testContent = {"This will count to 5","and then stay resident"}

local function start()
	--iterator = 0
	computer.beep(400, 0)
	winAPI.addWindow(17,11,30,4,"iteratorwindow2",nil,"Generic","counter " .. iterator,testContent)
end

local function run()
	computer.beep(300, 0)
	iterator = iterator + 1
	winAPI.updateWindow("iteratorwindow2", nil, "counter " .. iterator, testContent)
	--print("counter " .. iterator)
	--error("Test crash :D")
end

local function stop()
	computer.beep(200, 0)
	winAPI.removeWindow("iteratorwindow2", nil)
end

handles.details = details
handles.start = start
handles.run = run
handles.stop = stop
return handles