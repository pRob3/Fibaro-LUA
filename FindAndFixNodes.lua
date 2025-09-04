--[[
%% properties
%% weather
%% events
%% globals
--]]

-- Script to check and fix dead devices on Fibaro HC2
-- This script will identify dead devices and try to reinitialize them
-- Execute this script manually or set it as a scheduled scene

-- Log helper function
function log(text)
    fibaro:debug(text)
end

-- Function to attempt to fix a dead device
function fixDeadDevice(deviceID)
    local deviceName = fibaro:getName(deviceID)
    log("Attempting to fix device ID: " .. deviceID .. " (" .. deviceName .. ")")

    -- Try to turn off, then on, to reinitialize the device
    fibaro:call(deviceID, "turnOff")
    fibaro:sleep(1000)  -- Wait a second
    fibaro:call(deviceID, "turnOn")

    -- Check if the device is still dead
    local isDead = tonumber(fibaro:getValue(deviceID, "dead"))
    if isDead == 1 then
        log("Device ID " .. deviceID .. " (" .. deviceName .. ") is still dead.")
        return false
    else
        log("Device ID " .. deviceID .. " (" .. deviceName .. ") is now active.")
        return true
    end
end

-- Main script logic
function checkAndFixDeadDevices()
    log("Starting dead device check...")

    local allDevices = fibaro:getDevicesId() -- Get all device IDs
    local deadDeviceCount = 0

    for _, deviceID in ipairs(allDevices) do
        local isDead = tonumber(fibaro:getValue(deviceID, "dead"))

        if isDead == 1 then
            local deviceName = fibaro:getName(deviceID)
            log("Found dead device: ID " .. deviceID .. " (" .. deviceName .. ")")

            -- Try to fix the dead device
            local success = fixDeadDevice(deviceID)

            if not success then
                log("Unable to fix device ID " .. deviceID .. " (" .. deviceName .. "). Further inspection needed.")
            end
            deadDeviceCount = deadDeviceCount + 1
        end
    end

    if deadDeviceCount == 0 then
        log("No dead devices found. System is optimized.")
    else
        log("Dead device check completed. " .. deadDeviceCount .. " devices require further attention.")
    end
end

-- Execute the check and fix
checkAndFixDeadDevices()
