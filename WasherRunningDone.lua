--[[
%% autostart
%% properties
120 power
%% globals
--]]


-- whether or not to display debug messages
local debug = 1

--The scene should only be runned in one instance.
if fibaro:countScenes() >1 then
	if debug ==1 then fibaro:debug("Scenen körs redan, avslutar denna scen.") end
	fibaro:abort();
end

-- The wall plug that's connected to the washer
-- !! Don't forget to change the id in the head above!!
local power_socket = 120

local powerlive = fibaro:getValue(power_socket, "power") -- monitored unit
  if debug ==1 then    
  	fibaro:debug("Förbrukning = "..powerlive.." Watt");
  	fibaro:debug("Tvättmaskinen är avstängd (kontakten är inkopplad)");    
  end

-- varibles needed below
local run = 0 -- is the machine running
local currentDate = os.date("*t"); -- The time
local power = fibaro:getValue(power_socket, "power") -- the power the machine is using
local minutesRunning = 0 -- minutes the machine has been running

-- check if the machine is running or not
if ( tonumber(fibaro:getValue(power_socket, "power")) > 35 ) and run == 0 then
  local start = (os.time())
  fibaro:debug("Tvättmaskin är upptagen")
  fibaro:debug("Förbrukning = "..power.." Watt")
run = 1
end

-- check power as long as it is running
while run == 1 do

  if ( tonumber(fibaro:getValue(power_socket, "power")) < 6) then
    minutesRunning = minutesRunning + 1
    
    local power2 = fibaro:getValue(power_socket, "power")
    if debug ==1 then fibaro:debug('counter = ' ..minutesRunning.. " : "..power2.."Watt") end
  end
  
  if ( tonumber(fibaro:getValue(power_socket, "power")) > 6) then
    minutesRunning = 0
  end
  
  -- The laundry is done
  if ( tonumber(fibaro:getValue(power_socket, "power")) < 6) and minutesRunning > 60 then
    
    if debug ==1 then fibaro:debug("Tvätten är klar.") end
    local power3 =  fibaro:getValue(power_socket, "power")
    
    if debug ==1 then fibaro:debug("Förbrukning 3 = "..power3.." Watt") end
    
    --[=====[
    TODO:
    -----------------------------------
    Send stats to my usage at:
    https://slaf.se/api
    To save average washing time
    
	SEND push notifications:
    -----------------------------------
    You find mobile list at:
    Settings > Configuration > Access Control > Mobile Devices list
    Right click the mobile user and html inspect the html code:
    <div class="checkbox1" id="div_push_installer_192" in this case id is: 192
    
    Id can also be found if you go to the NC API at: 
    http://YOUR-FIBARO-IP/api/devices
    search for the name of the phone(s) there
    --]=====]
    if debug == 1 then fibaro:debug("Skickar push meddelande") end
    fibaro:call(192, "sendPush", "Tvätten blev klar: " .. string.format("%02d", currentDate.hour) .. ":" .. string.format("%02d", currentDate.min)); 
    fibaro:call(69, "sendPush", "Tvätten blev klar: " .. string.format("%02d", currentDate.hour) .. ":" .. string.format("%02d", currentDate.min));
    
    run = 0
  end
 
  fibaro:sleep(1*1000)
end
