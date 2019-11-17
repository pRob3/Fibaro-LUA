--[[
%% autostart
%% properties
%% weather
%% events
%% globals
--]]

-- whether or not to display debug messages
local debug = 0

--The scene should only be runned in one instance.
if fibaro:countScenes() >1 then
	if debug ==1 then fibaro:debug("Scene already running, abort this scene.") end
	fibaro:abort();
end


local sourceTrigger = fibaro:getSourceTrigger();
function tempFunc()
	local currentDate = os.date("*t");
	local startSource = fibaro:getSourceTrigger();
	if ((string.format("%02d", currentDate.hour) .. ":" .. string.format("%02d", currentDate.min) == "03:05")) then
      fibaro:debug("Rebooting the Fibaro")
      HomeCenter.SystemService.reboot();
	end

	setTimeout(tempFunc, 60*1000)
end

if (sourceTrigger["type"] == "autostart") then
	tempFunc()
else

local currentDate = os.date("*t");
local startSource = fibaro:getSourceTrigger();
if (startSource["type"] == "other") then
	
end

end
