--[[
%% autostart
%% properties
8 power
%% globals
--]]

-- The scene should only be runned in one instance.
if fibaro:countScenes() > 1 then
    --fibaro:debug("Scenen körs redan, avslutar denna scen.")
    fibaro:abort()
end

-- Whether or not to display debug messages
local debug = 1

-- The wall plug that's connected to the washer
-- !! Don't forget to change the id in the head above!!
local power_socket = 8

local powerlive = fibaro:getValue(power_socket, "power") -- monitored unit
if debug == 1 then
    fibaro:debug("Förbrukning = " .. powerlive .. " Watt.")
    fibaro:debug("Tvättmaskinen är avstängd (kontakten är inkopplad)")
end

-- Variables needed below
local run = 0 -- is the machine running
local currentDate = os.date("*t") -- The time
local power = fibaro:getValue(power_socket, "power") -- the power the machine is using
local minutesRunning = 0 -- minutes the machine has been running
local totalEnergy = 0 -- Total energy consumption in kWh

-- Cost per kWh (100 öre per kWh)
local costPerKWh = 0.115

-- Check if the machine is running or not
if (tonumber(fibaro:getValue(power_socket, "power")) > 35) and run == 0 then
    local start = os.time()
    fibaro:debug("Tvättmaskin är upptagen")
    fibaro:debug("Förbrukning = " .. power .. " Watt")
    run = 1
end

-- Check power as long as it is running
while run == 1 do
    local currentPower = tonumber(fibaro:getValue(power_socket, "power"))
    if currentPower < 6 then
        minutesRunning = minutesRunning + 1
        totalEnergy = totalEnergy + (currentPower / 1000) * (1 / 3600) -- Calculate kWh

        if debug == 1 then
            fibaro:debug('counter = ' .. minutesRunning .. " : " .. currentPower .. " Watt")
        end
    end

    if currentPower > 6 then
        minutesRunning = 0
    end

    -- The laundry is done
    if currentPower < 6 and minutesRunning > 60 then
        if debug == 1 then
            fibaro:debug("Tvätten är klar.")
        end

        local power3 = fibaro:getValue(power_socket, "power")

        if debug == 1 then
            fibaro:debug("Förbrukning 3 = " .. power3 .. " Watt")
        end

        -- Calculate total cost
        local totalCost = totalEnergy * costPerKWh

        if debug == 1 then
            fibaro:debug("Skickar push meddelande")
        end

        local pushMessage = "Tvätten blev klar: " .. string.format("%02d", currentDate.hour) .. ":" .. string.format("%02d", currentDate.min)
        pushMessage = pushMessage .. "\nTotal kWh-förbrukning: " .. string.format("%.2f", totalEnergy) .. " kWh"
        pushMessage = pushMessage .. "\nTotal kostnad: " .. string.format("%.2f", totalCost) .. " kr"

        fibaro:call(78, "sendPush", pushMessage)
        fibaro:call(79, "sendPush", pushMessage)

        run = 0
    end

    fibaro:sleep(1 * 1000)
end
