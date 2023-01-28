--[[
%% properties
164 value
%% events
%% globals
--]]

local debug = true

-- Function to turn off a device
local function turnOffDevice(deviceId)
  if fibaro:getValue(deviceId, "value") == "0" then
    if debug then fibaro:debug("Device ".. deviceId .." is already off.") end
    return
  end
  if debug then fibaro:debug("Turning off device ".. deviceId ..".") end
  fibaro:call(deviceId, "turnOff")
end

-- Check if another scene is running
if fibaro:countScenes() > 1 then
  if debug then fibaro:debug("Another scene is already running, exiting.") end
  fibaro:abort()
end

-- Get the device ID and the time delay
local deviceId = 164
-- create global variable named: towelHeaterDelay with milliseconds value
local timeDelay = fibaro:getGlobalValue("towelHeaterDelay") or 3600000
timeDelay = tonumber(timeDelay)

-- Get the trigger source
local trigger = fibaro:getSourceTrigger()

-- Check if the device value is greater than 0 or if the trigger type is "other"
if (tonumber(fibaro:getValue(deviceId, "value")) > 0 or trigger["type"] == "other") then
  if debug then fibaro:debug("Device ".. deviceId .." is on or trigger type is 'other', turning off after ".. (timeDelay/1000) .." seconds.") end  
  setTimeout(function() turnOffDevice(deviceId) end, timeDelay)
else
  if debug then fibaro:debug("Device ".. deviceId .." is off or trigger type is not 'other', no action required.") end
end
