--[[
%% properties
125 value
%% events
%% globals
--]]

local debug = false -- set to true to show debug logs
local delayMinutes = 15 -- Delay in minutes before turning off the light

-- colorful debug messages
local function debugLog(color, message)
  if debug then
    fibaro:debug(string.format('<%s style="color:%s;">%s', "span", color, message, "span"))
  end
end

if fibaro:countScenes() > 1 then
  debugLog("red", "Timer scene is already running, abort!")
  fibaro:abort()
end

local motionSensorId = 125 -- Replace with your motion sensor device ID
local lamps = {173, 174}  -- IDs for the lamps in an array
local delay = 60 * delayMinutes -- Delay in minutes before turning off the light
local motionDetectedTime = 0
local lampNames = {}

-- Get the names of the lamps and store them in a table
for i, lamp in ipairs(lamps) do
  lampNames[i] = fibaro:getName(lamp)
end

local function turnOnLight()
  for i, lamp in ipairs(lamps) do
    fibaro:call(lamp, "turnOn")
  end
  debugLog('green', "Lamps (" .. table.concat(lampNames, ", ") .. ") are now on.")
end


local function turnOffLight()
  for i, lamp in ipairs(lamps) do
    fibaro:call(lamp, "turnOff")
  end
  debugLog('red', "Lamps (" .. table.concat(lampNames, ", ") .. ") are now off.")
end


local function motionDetected()
  local currentTime = os.time()
  local elapsedTime = currentTime - motionDetectedTime

  if elapsedTime < delay then
    debugLog('yellow', "Motion detected again, resetting the timer")
  else
    debugLog('yellow', "Motion detected, turning on lights (" .. table.concat(lampNames, ", ") .. "). ")
    turnOnLight()
  end

  motionDetectedTime = currentTime

  local timer = delay
  while timer > 0 do
    fibaro:sleep(1000)
    timer = timer - 1
    local motion = tonumber(fibaro:getValue(motionSensorId, "value"))
    if motion == 1 then
      motionDetected()
      return
    end
  end

  debugLog('white', "No motion detected, turning off lights")
  turnOffLight()
end


if debug then
  debugLog('white', "----------- Scene information -----------")
  
  debugLog('pink', "Starting Motion Sensor Light Control...")
  debugLog('pink', "Motion Sensor ID: " .. motionSensorId)
  debugLog('pink', "Light IDs: " .. table.concat(lamps, ", "))
  debugLog('pink', "Lamp Names: " .. table.concat(lampNames, ", "))
  debugLog('pink', "Delay: " .. delay .. " seconds")
  
  debugLog('white', "----------- Scene information END -----------")
end


while true do
  local motion = tonumber(fibaro:getValue(motionSensorId, "value"))
  if motion == 1 then
    motionDetected()
  end
  fibaro:sleep(500)
end
