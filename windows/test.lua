if not _WINVER then
	print("This program requires Windows.")
	return
end

local component = require("component")
local computer = component.computer

local handles = {}
local details = {}
details.name = "Iterator"
details.priority = 1
details.stayResident = true

local iterator = 0
local testContent = {"This should count to 5","and then quit"}

local function start()
	--iterator = 0
	computer.beep(400, 0)
	winAPI.addWindow(15,7,30,4,"iteratorwindow",nil,"Generic","counter " .. iterator,testContent)
end

local function run()
	computer.beep(300, 0)
	iterator = iterator + 1
	winAPI.updateWindow("iteratorwindow", nil, "counter " .. iterator, testContent)
	--print("counter " .. iterator)
end

local function stop()
	computer.beep(200, 0)
	winAPI.removeWindow("iteratorwindow", nil)
end

handles.details = details
handles.start = start
handles.run = run
handles.stop = stop
return handles