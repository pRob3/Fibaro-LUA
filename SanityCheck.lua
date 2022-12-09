  if require then
  -- Load helpers to run offline
  require "json"
  require "LoadFibaroSceneAPI"

  NoHtml=false

  -- Allows me to predefine "devices" for testing.
  if devices == nil then
    devices=false
  end

  -- Allows me to predefine "devices" for testing.
  if rooms == nil then
    rooms=false
  end

  if pcall(require,"CheckGlobalLeakage") then
    print("Checking unauthorized global variable access.")
  else
    print("require does not find \"CheckGlobalLeakage.Lua\". Not checking global variable access.")
  end
end

--[[

  Configuration... See table "local cfg={" below to set options to your liking.

  "SanityCheck" loops over all devices, and applies rules defined in this script,
  to warn about suspect configuraation and suggest fixes.
  
  This script does not SET anything because it takes human judgement to decide what to do.
  
  Originally this script was or private use only.  On june 9, 2019 I "donated" the script to the
  community.
  
  Known issue: does not work on slaves when using a master/slave HomeCenter setup.
  
  Version 1.5.1 - 2020-04-08
    - Script can be run on a PC using "Zerobrane" and is compatible with HCL/HC2/HC3
      See https://forum.fibaro.com/topic/24319-tutorial-zerobrane-usage-lua-coding/
    - Added "FGMS001 ZW5 Motion Sensor, V2 (fw >= 3.3)" = 010F 0801 1002
    - Added "Wall Switch (1 channel)" = "0258 0003 108c"
  
  Version 1.5.0 - 2019-11-23
    - This version was not released to the public because of the announcement of HC3
    - Add option PrintProductInfo to display the "raw" productinfo, can be used in scripts, for example, a
      "set parameters script" can use this to verify exact type of a device and avoid writing
      parameters to the wrong kind of product
      Example of ProductInfo: Danfoss LC13 productinfo: 0,2,0,5,0,4,1,1
    - Fix FGS-223 parameter 54 should have been p 55. Thanks @szmyk.
    - Rename "Neo Coolcam" to "Neo" and add NEO_DS01Z D/W sensor

  
  Version 1.4.3 - 2019-10-09
    - Fix FGT-001 name
    - Add iBlinds

  Version 1.4.2 - 2019-02-13
    - Add devices for Bodyart, Vinisz
    - Pick up some devices from drboss's database.
    - re-enabled battery warning (config option)

  Version 1.4.1 - 2019-02-12
    - Merge several devices added by drboss. Thanks @drboss.

  Version 1.4.0 - 2018-12-28
    - Add Neo Coolcam Z-wave Plus PIR Motion Sensor NAS-PD02Z.
    - Add Heiman Temperature Humidity Sensor HS1HT-Z. Thanks @Bodyart.
    - Fix FGS-223 parameter 54 should have been p 55. Thanks @jakub.jezek.
  
  Version 1.3.0 - 2018-11-23:
    - Posted to group of beta testers.

  Versions before 1.3.0: not released to beta test group

  Author: Peter Gebruers (Fibaro forum: petergebruers).

  Distributed under the Creative Commons CC BY-SA 4.0 license,
  see https://creativecommons.org/licenses/by-sa/4.0/

  Warning! I have had reports that this code makes your scrambled
  eggs taste weird! Use it at your own risk!

--]]

local version="1.5.1"

-- Script to show recommended configuration of devices by @petergebruers

-- TODO hmsToSec: find something nicer. Maybe string based.
local function hmsToSec(h,m,s) return h*3600+(m or 0)*60+(s or 0) end

-- User settings:

local cfg={
  -- Enable / Disable specific checks
  -- Check if polling and zwaveWakeup both exist in interface
  PandW = true,
  -- Check associations. Not working yet, but can display recommended configuration.
  -- Not very useful on Z-Wave Plus devices, lifeline is always 1.
  assoc = false,
  -- Global limits for wake up
  --wul = Wake Up Low limit
  wul = hmsToSec(1,0,0),
  wuh = hmsToSec(8,0,0),
  eventlog = true,
  power=true,
  switchtype=true,
  getLastWorkingRoute=false,
  getParameter=true,
  remoteController=false,
  batteryLowNotification=true,
  hidden=false,
  -- missing "unit" under properties might be an indication of need to "soft reconfigure"
  unit=true,
  -- display the "raw" productinfo, can be useful in scripts.
  PrintProductInfo=false,
}

-- CODE, no user settable parameters below.

--local info = function() end
local info = function(msg) fibaro:debug(msg) end
local verbose = function() end
--local verbose = function(msg) fibaro:debug(msg) end

-- Debug Logging helper code.
-- Special feature: enable/disable HTML logging.
-- Plain text logging looks cleaner on ZeroBrane Studio.

local logInfo, logColor, logError, logDisplay, logLink

do
  local buffer={}

  if NoHtml then
    function logInfo(txt)
      if type(txt) == "table" then
        for _,v in ipairs(txt) do
          logInfo(v)
        end
      else
        buffer[#buffer+1]=txt
        buffer[#buffer+1]="\n"
      end
    end
    logColor=logInfo
    logError=logInfo
    function logLink(id, post, indent)
      if not indent then
        indent=0
      end
      string.rep(" ",indent)
      logInfo(("%s%4d %s"):format(string.rep(" ",indent), id, post or "nil"))
    end
  else
    buffer[1]="<pre>"
    function logColor(txt, color)
      if type(txt) == "table" then
        for _,v in ipairs(txt) do
          logColor(v,color)
        end
      else
        -- substitution is NOT UNICODE SAFE
        if txt == nil then txt = "nil" end
        local s = txt:gsub("([\038\060\062])",
          function(c)
            return "&#"..string.byte(c)..";"
          end)
        buffer[#buffer+1]=("<span style=\"color:%s\">%s</span>"):format(color,s)
        buffer[#buffer+1]="<br>"
      end
    end
    function logInfo(txt)
      logColor(txt,"White")
    end
    function logError(txt)
      logColor(txt,"Red")
    end
    function logLink(id, post, indent)
      if indent then
        buffer[#buffer+1]=string.rep(" ",indent)
      end
      buffer[#buffer+1]=string.format(
        "<a href=\"../devices/configuration.html?id=%u\" target=\"_blank\""..
        "style=\"display:inline;color:Cyan\">%u</a>",
        id, id)
      -- TODO fix number alignment (fixed length field for ID)
      buffer[#buffer+1]=" "
      if post then
        local s = post:gsub("([\038\060\062])",
          function(c)
            return "&#"..string.byte(c)..";"
          end)
        buffer[#buffer+1]=s
      else
        buffer[#buffer+1]="nil"
      end
      buffer[#buffer+1]="<br>"
    end
  end

  function logDisplay()
    if NoHtml then
      if buffer[#buffer]=="\n" then
        buffer[#buffer]=nil
      end
    else
      -- remove last break
      if buffer[#buffer]=="<br>" then
        buffer[#buffer]="</pre>"
      else
        buffer[#buffer+1]="</pre>"
      end
    end
    local t = table.concat(buffer)

    --fibaro:debug("For detecting issues with printing in ZeroBrane: Lenght of output string: "..string.len(t))

    fibaro:debug(t)
  end
end

local ZWDB={}

local ZWDBfun={  
  lookup = function(this, MI, PTI, PI, AV, err) -- returns name, option, warnings
    if err then
      return nil,nil,err
    end
    local m = ZWDB[MI]
    if m == nil then
      return ("Manufacturer: %d, PTI: %d, PI: %d, FW: %s"):format(MI, PTI, PI, AV), nil,
      "Manufacturer ID not found. Hex: "..("%04x %04x %04x"):format(MI,PTI,PI)
    end
    local pti = m[PTI]
    if pti == nil then
      return ("%s, PTI: %d, PI: %d, FW: %s"):format(m.n, PTI, PI, AV), nil,
      "Product Type ID not found. Hex: "..("%04x %04x %04x"):format(MI,PTI,PI)
    end
    local pi = pti[PI]
    if pi == nil then
      return ("%s, %s, PI: %d, FW: %s"):format(m.n, pti.n or ("PTI: %d"):format(PTI), PI, AV), nil,
      "Product ID not found. Hex: "..("%04x %04x %04x"):format(MI,PTI,PI)
    end
    if type(pi) == "table" then
      if pi.n ~= nil then
        if #pi.n>0 then
          if pti.n then
            return ("%s, %s, %s, FW: %s"):format(m.n,pti.n,pi.n,AV), pi.opt or pti.opt, nil
          else
            return ("%s, %s, FW: %s"):format(m.n,pi.n,AV), pi.opt or pti.opt, nil
          end

        else
          return ("%s, %s, FW: %s"):format(m.n,pti.n,AV), pi.opt or pti.opt, nil
        end
      else
        return ("%s, %s, FW: %s"):format(m.n,pi.n or ("PI: %d"):format(PI),AV), pi.opt or pti.opt, nil
      end
    elseif type(pi) == "string" then
      if string.len(pi)>0 then
        if pti.n then
          return ("%s, %s, %s, FW: %s"):format(m.n,pti.n,pi,AV), pti.opt, nil
        else
          return ("%s, %s, FW: %s"):format(m.n,pi,AV), pti.opt, nil
        end
      else
        return ("%s, %s, FW: %s"):format(m.n,pti.n,AV), pti.opt, nil
      end
    else
      return ("%s, %s, FW: %s"):format(m.n,pti.n,AV), pti.opt, nil
    end
  end,

  splitProductInfo = function(_,productInfoString)
    local MIh, MIl, PTIh, PTIl, PIh, PIl, AV, ASV = productInfoString:match("(%d+),(%d+),(%d+),(%d+),(%d+),(%d+),(%d+),(%d+)")
    if MIh and MIl and PTIh and PTIl and PIh and PIl and AV and ASV then
      local fw
      if tonumber(ASV) < 10 then
        fw=("%2d.(0)%d"):format(AV, ASV)
      else
        fw=("%2d.%02d"):format(AV, ASV)
      end

      return MIh*256+ MIl,PTIh*256+ PTIl, PIh*256+ PIl, fw
    else
      -- fibaro:debug("Failed to parse productInfoString: \""..productInfoString.."\"")
      return 0,0,0,0, "Failed to parse productInfoString: "..productInfoString
    end
  end,

  lookupString = function(this,productInfoString)
    return this:lookup(this:splitProductInfo(productInfoString))
  end
}
-- Helper function to sort table on keys
local function pairsByKeys (t, f)
  local a = {}
  for n in pairs(t) do table.insert(a, n) end
  table.sort(a, f)
  local i = 0      -- iterator variable
  local iter = function ()   -- iterator function
    i = i + 1
    if a[i] == nil then return nil
    else return a[i], t[a[i]]
    end
  end
  return iter
end

-- fmtTime displays a time in seconds in a nice way
local function fmtTime(sec)
  if sec < 60 then
    return sec..""
  elseif sec < 3600 then
    return sec.." ("..(math.floor(sec/6)/10)..' m)'
  else
    return sec.." ("..(math.floor(sec/360)/10)..' h)'
  end
end

local function checkAssociations(d, asc)
  -- This was developend on 4.057.
  -- This version does not have properties.associations when
  -- data was obtained globally, i.e. by calling
  -- /api/devices
  -- To get asscociations, you have to call the individual device API
  -- /api/devices/<ID>

  -- To dump table:
  -- printTbl(d,2)
  return "Info: Please manually check if HC2 is in association group: "..
  asc[1]
end

local cSwitchtype={"Momentary Switch","Toggle Switch", "Roller Blind Switch (Up/Down)"}

-- checkDevices loops over all devices
-- TODO NEEDS REFACTORING for readability
local function checkDevices(masters,slaves,roomsById)
  local devicesChecked = 0
  local notInDb = 0

  local indent = '     '
  local indent2 = '          '

  -- outer loop: all masters
  for k,m in pairsByKeys(masters) do
    devicesChecked=devicesChecked+1
    if m.id == 8 then
      local for_debugging = "blah"
    end

    local prodname, opt, err = ZWDBfun:lookupString(m.properties.productInfo)
    local msg = prodname or '---'
    if cfg.PrintProductInfo then
      msg = msg .. ', productInfo: '.. (m.properties.productInfo or '---')
    end

    logLink(m.id, msg)

    if err then
      logInfo(("%s * Device not defined in this script, reason: %s."):format(
          indent, err))
      notInDb=notInDb+1
    end

    local wul = cfg.wul
    local wuh = cfg.wuh

    -- Check if device type has options
    if opt then
      if opt.tbd then
        logInfo(indent .. 'Rules "To Be Defined". Only basic checks on this device!')
      end

      -- wul and wuh == "wake up low" and "wake up high"
      if opt.wul ~= nil and opt.wuh ~= nil then
        wul=opt.wul
        wuh=opt.wuh
      end
      -- pwr means "device needs manual power config"
      -- asc means "Associations" to be checked
      -- firmware 4.056 has associations in the response
      -- to a sinngel device, not all devices.
      --  so need to call /api/devices/ID
      if opt.asc and cfg.assoc then
        logInfo(indent..checkAssociations(m, opt.asc))
      end

      if cfg.switchtype and opt.sw then
        for _,p in pairs(opt.sw) do
          local paramValue
          for _,v in ipairs(m.properties.parameters) do
            if v.id==p then
              paramValue = v.lastReportedValue
              if paramValue == nil then
                -- TODO: warn user he should do "read configuration" on this device
                paramValue = v.value or "nil"
              end
              break
            end
          end
          if paramValue then
            local paramValueType = type(paramValue)
            if paramValueType == "number" then
              logInfo(indent.."Switch type param "..p.." set to: ".. paramValue..
                " = "..cSwitchtype[paramValue+1])
            else
              logInfo(indent.."Switch type param "..p.." set to: ".. paramValue..
                ", paramValueType: " .. paramValueType)
            end
          else
            logInfo(indent.."Switch type param "..p.." is missing.")
          end
        end
      end
      -- Device Parameters
      -- Example opt.param={{p=41,n="Scene Activation",v=1}}
      if opt.param then
        for _,pDef in pairs(opt.param) do
          local p=pDef.p
          local param
          local paramValue
          for k,v in ipairs(m.properties.parameters) do
            if v.id==p then
              param=v
              paramValue = param.lastReportedValue
              if paramValue == nil then
                -- TODO: warn user he should do "read configuration" on this device
                paramValue = param.value
              end
              break
            end
          end

          -- Example: {"value":1,"size":1,"lastSetValue":1,"lastReportedValue":1,"id":41}

          if pDef.v then
            if paramValue then
              if paramValue~=pDef.v then
                logInfo(('%sParameter %d "%s" set to %s, recommend %s. %s'):format(
                    indent, p, pDef.n, paramValue, pDef.v, pDef.r or "."))
              end
            else
              logInfo(('%sDevice does not have Parameter: %d "%s", recommend adding it, and setting it to %s.'):format(
                  indent, p, pDef.n, pDef.v))
            end
          elseif pDef.vg then
            if paramValue then
              if paramValue<pDef.vg then
                logInfo(('%sParameter %d "%s" set to %s, recommend >= %s. %s'):format(
                    indent, p, pDef.n, param.lastReportedValue, pDef.vg, pDef.r or "."))
              end
            else
              logInfo(('%sDevice does not have Parameter: %d "%s", recommend adding it, and setting it to >= %s.'):format(
                  indent, p, pDef.n, pDef.vg))
            end
          elseif pDef.vle then
            if paramValue then
              if paramValue>pDef.vle then
                logInfo(('%sParameter %d "%s" set to %s, recommend <= %s. %s'):format(
                    indent, p, pDef.n, param.lastReportedValue, pDef.vle, pDef.r or "."))
              end
            else
              logInfo(('%sDevice does not have Parameter: %d "%s", recommend adding it, and setting it to <= %s.'):format(
                  indent, p, pDef.n, pDef.vle))
            end
          end
        end
      end
    end

    -- Tests for all MASTER devices

    -- actions

    local getLastWorkingRoute = false
    local getParameter = false
    if m.actions then
      for k,v in pairs(m.actions) do
        if k == 'getLastWorkingRoute' then
          getLastWorkingRoute = true
        elseif k == 'getParameter' then
          getParameter = true
        end
      end

      if cfg.getLastWorkingRoute and getLastWorkingRoute == false then
        logInfo(indent..'getLastWorkingRoute not in "actions", fix: exclude & include')
      end
      -- Some devices, like Danfoss LC13, do not have parameters ,and no action getParameters
      if cfg.getParameter and getParameter == false and #m.properties.parameters>0 then
        logInfo(indent..'getParameter not in "actions", try "soft reconfigure"')
      end
    else
      logInfo(indent..'device does not have "actions", try "soft reconfigure"')
    end

    if m.properties.batteryLowNotification  and 
    tostring(m.properties.batteryLowNotification) == "true" and
    cfg.batteryLowNotification then
      logInfo(indent .. 'Recommend disabling setting \"Notify when battery low via e-mail\" on master.')
    end

    local polling = false
    for k = 1, #m.interfaces do
      if m.interfaces[k] == 'polling' then
        polling = true
        break
      end
    end
    local battery = false
    for k = 1, #m.interfaces do
      if m.interfaces[k] == 'battery' then
        battery = true
        break
      end
    end
    local zwaveWakeup = false
    for k = 1, #m.interfaces do
      if m.interfaces[k] == 'zwaveWakeup' then
        zwaveWakeup = true
        break
      end
    end

    if cfg.PandW and polling and zwaveWakeup then
      logInfo(indent..'polling and zwaveWakeup both in \"interfaces”')
    end

    local maxBatInterval = 86400 -- One day gives battery feedback but
    -- without taxing the battery. I would use this setting for portable
    -- remote controllers and switches with small capacity batteries.

    --local maxBatInterval = 28800 -- 8 hours gives you the opportunity to
    -- change something in the evening and check it in the morning

    if m.properties.wakeUpTime ~=nil then
      local t=m.properties.wakeUpTime
      --Check if wake up should be disabled
      if wul == 0 then      
        if t ~= 0 and t~= maxBatInterval then
          logInfo(indent .. 'Wakeup: '..fmtTime(t)..
            ' - recommend 0 (disable) or '..fmtTime(maxBatInterval))
        end
      else
        if m.properties.wakeUpTime == 0 then
          logInfo(indent .. 'Wakeup 0 (disabled).')
        elseif m.properties.wakeUpTime < wul then
          logInfo(indent .. 'Wakeup: '..fmtTime(t)..
            ' is less than '..fmtTime(wul))
        elseif m.properties.wakeUpTime > wuh then
          logInfo(indent .. 'Wakeup: '..fmtTime(t)..
            ' is more than '..fmtTime(wuh))
        end
      end
    end

    -- TODO check fwh=26,fwl=25 firmware revision. fwr for "reason"?

    -- json library on my Mac does not decode "true" as a boolean
    -- but the HC implemenation does convert.
    -- an a HC I could do: if m.properties.dead then ...
    if tostring(m.properties.dead)=="true" then
      logInfo(indent .. 'Device marked "dead".')
    end


    if tostring(m.properties.markAsDead)=="false" then
      logInfo(indent .. '! Device "Mark if dead" set to "no", please change that to "yes" to avoid network delays!')
    end
    -- inner loop: SLAVES
    local slvs = slaves[m.id]

    if slvs then
      for slvKey, slv in pairs(slvs) do
        local endPointId = tonumber(slv.properties.endPointId) or -1
        local roomID = slv.roomID
        local roomName
        if roomID then
          if roomID == 0 then
            roomName = "unassigned"
          else
            local room = roomsById[roomID]
            if room then
              roomName = room.name
            else
              roomName="room with id "..roomID
            end
          end
        else
          roomName = "---"
        end


        --local txt = ("%s (endpoint %d %s)"):format(slv.name, endPointId,slv.type)
        local txt = ("%s in %s, ep %d"):format(slv.name, roomName, endPointId)

        logLink(slv.id,txt, 5)

        if slv.visible == false and cfg.hidden then
          logInfo(indent2.."Hidden device.")
        end

        if slv.enabled == false and cfg.hidden then
          logInfo(indent2.."Disabled device.")
        end

        if slv.type=="com.fibaro.remoteController" and not cfg.remoteController then
          logInfo(indent2.."Skipping tests on devices of type \"com.fibaro.remoteController\".")
        else
          if slv.properties.batteryLowNotification  and 
          tostring(slv.properties.batteryLowNotification) == "true" and
          cfg.batteryLowNotification then
            logInfo(indent2..' Recommend disabling setting \"Notify when battery low via e-mail\" on slave')
          end

          if opt then 
            local epConfig = opt[endPointId]
            if epConfig then
              --if opt and opt.pwr then
              -- Check powerConsumption
              -- Need slave with endPointId": "0" and endPointId": "2" for FGS-221

              verbose('Check Slave: '..slvKey..' endPointId: '..endPointId)

              if cfg.power then
                if epConfig.pwr and not slv.properties.powerConsumption then
                  logInfo(indent2..'Does not have declared power consumption')
                end
              end

              if epConfig.light then
                local interfaceLight = false
                for _, interf in ipairs(slv.interfaces) do
                  if interf == 'light' then
                    interfaceLight = true
                    break
                  end
                end
                if not interfaceLight then
                  logInfo(indent2..'Controlled device is not set to "Lighting"')
                end
              end
              if cfg.unit and epConfig.unit and slv.properties.unit == nil then
                logInfo(indent2..'"unit" not in "properties", try "soft reconfigure"')
              end
            end -- end "epConfig"

            if cfg.eventlog and opt.evt then
              if tostring(slv.properties.saveLogs)=='true' then
                logInfo(indent2..' Event logging enabled. Recommend: disable.')
              else
                logInfo(indent2..' Event logging disabled.')
              end
            end
          end
        end
      end
    end
  end
  return devicesChecked, notInDb
end  

local function hms(timeSec)
  if timeSec == nil then
    return "nil"
  end
  if timeSec == 0 then
    return "0"
  end
  return string.format('%.2d:%.2d:%.2d', timeSec/(60*60),
    timeSec/60%60, timeSec%60)
end

local function check()
  logInfo("Checking devices for (suspect, missing) configuration. Script version "..
    version.." by Peter Gebruers")
  logInfo("With contributions from drboss, sankotronic, Tony270570, jakub.jezek, 10der.")
  logInfo("Special thanks to all beta testers, especially Bodyart, Vinisz")
  logInfo("Distributed under \"Attribution-ShareAlike 4.0\" license")
  logInfo("https://creativecommons.org/licenses/by-sa/4.0/")
  logInfo("This script does not change anything, because it takes human judgement to decide what to do...")
  logInfo("Click on the (cyan) device number to open the device configuration page.")
  logInfo("Start Time Of Script: "..os.date("%Y-%m-%d %H:%M:%S"))

  --enable injection of devices from parent script (for testing)
  if type(devices) ~= "table" then
    devices = api.get("/devices/?interface=zwave")
  end

  --enable injecting rooms from parent script (for testing)
  if type(rooms) ~= "table" then
    rooms = api.get("/rooms")
  end

  local roomsById={}
  for k, v in pairs(rooms) do
    roomsById[v.id]=v
  end

  local masterById={}
  local slaves={}

  for k, v in pairs(devices) do
    if v.parentId then
      if v.parentId == 1 then
        masterById[#masterById+1]=v
      elseif v.parentId >=4 then
        local parentId = tonumber(v.parentId)
        local root=slaves[parentId]
        if root then
          root[#root+1]=v
        else
          slaves[parentId]={v}
        end
      end
    end
  end

  local devicesChecked, notInDb = checkDevices(masterById,slaves,roomsById)

  logInfo("Total number of devices checked: "..devicesChecked)
  logInfo("Total number of devices not defined in this script: "..notInDb)
  logDisplay()
end

-----------------------------------------
---------------- DATABASE ---------------
-----------------------------------------

-- "n" = name
-- "opt" = options
-- "endp" = endpoints (visible, used, tested)
-- "pwr" chack user defined power
-- 'light' check if "controlled type" = light
-- "wul" "wuh" wake-up limits
-- "asc" chack HC in associaton (list)

ZWDB[2]={n="Danfoss",
  [5]={n="Danfoss Living Connect Thermostat",
    opt={
      wuh=1800,
      wul=300,
      [0]={
        unit=true,
      },
    },
    [3]={n="LC12",
    },
    [4]={n="LC13",
    },
  },
}
ZWDB[89]={n="Horstmann",
  [3]={
    [1]={n="ASR-ZW Thermostat Receiver",
      opt={
        tbd=true,
      },
    },
  },
}
ZWDB[96]={n="Everspring",
  [4]={n="Socket AN157",
    [1]={n="ver UE",
    },
    [2]={n="ver US",
    },
  },
  [11]={n="Flood sensor ST812",
    opt={
      wuh=86400,
      wul=14400,
    },
    [1]={n="ver UE",
    },
    [2]={n="ver US",
    },
  },
}
ZWDB[133]={n="Fakro",
  [2]={
    [17]={n="ZWS12 Chain actuator 12VDC with optional rain sensor",
      opt={
        tbd=false,
      },
    },
  },
  [3]={
    [1]={n="ZWS12 Chain actuator 12VDC",
      opt={
        tbd=true,
      },
    },
  },
}
ZWDB[134]={n="Aeotec (AEON Labs)",
  [1]={
    opt={
      wuh=0,
      wul=0,
    },
    [3]={n="Minimote DSA03202",
    },
    [88]={n="Key fob G5",
    },
  },
  [2]={
    [5]={n="DSB05 MultiSensor",
    },
    [28]={n="DSB28 Home Energy Meter aka HEM (2nd Edition) - watch out for power report spam",
      opt={
        tbd=true,
      },
    },
    [54]={n="DSB54 Recessed Door Sensor",
    },
    [74]={n="ZW074 MultiSensor Gen5",
      opt={
        param={
          {
            p=5,
            n="Motion send 1='CC basic' 2= 'CC sensor'",
            v=2,
            r="Seting 2 enables motion sensor on Home Center",
          },
        },
      },
    },
    [89]={n="ZW089 Recessed Door Sensor Gen5",
    },
    [95]={n="ZW095 Home Energy Meter Gen5 aka HEM Gen5 - watch out for power report spam",
      opt={
        tbd=true,
      },
    },
    [100]={n="ZW100 MultiSensor 6",
      opt={
        param={
          {
            p=42,
            n="Threshold change in humidity to induce an automatic report %-point",
            v=2,
            r="to reduce number humidity reports with only 0.5 change (jitter)",
          },
        },
      },
    },
    [112]={n="ZW112 Door Window Sensor 6",
    },
    [130]={n="WallMote Quad",
    },
  },
  [3]={
    [6]={n="DSC24-ZWEU Smart Switch Gen5 (1st Edition)",
      opt={
        param={
          {
            p=101,
            n="Types of reports sending to group 2",
            v=0,
            r="to reduce number of any periodic reports",
          },
          {
            p=102,
            n="Types of reports sending to group 3",
            vg=600,
            r="to reduce number of any periodic reports",
          },
          {
            p=111,
            n="The time interval of  Report sending to group 1 in seconds",
            vg=600,
            r="to reduce number of periodic reports",
          },
          {
            p=111,
            n="The time interval of  Report sending to group 2 in seconds",
            vg=600,
            r="to reduce number of periodic reports",
          },
          {
            p=113,
            n="The time interval of  Report sending to group 3 in seconds",
            vg=600,
            r="to reduce number of periodic reports",
          },
        },
      },
    },
    [18]={n="DSC18103 Micro Smart Switch (2nd Edition)",
      opt={
        tbd=true,
      },
    },
    [19]={n="DSC19103 Micro Smart Dimmer (2nd Edition)",
      opt={
        tbd=true,
      },
    },
    [75]={n="ZW075 Smart Switch Gen5",
      opt={
        param={
          {
            p=92,
            n="Induce an automatic (power) report %",
            v=100,
            r="to reduce number of small power reports",
          },
          {
            p=111,
            n="The time interval of sending Report group 1 (power) in seconds",
            vg=600,
            r="to reduce number of periodic power reports",
          },
          {
            p=112,
            n="The time interval of sending Report group 1 (power) in seconds",
            vg=600,
            r="to reduce number of energy reports",
          },
        },
      },
    },
    [78]={n="ZW078 Heavy Duty Smart Switch Gen5",
      opt={
        param={
          {
            p=92,
            n="Induce an automatic (power) report %",
            v=100,
            r="to reduce number of small power reports",
          },
          {
            p=111,
            n="The time interval of sending Report group 1 (power) in seconds",
            vg=600,
            r="to reduce number of periodic power reports",
          },
          {
            p=112,
            n="The time interval of sending Report group 1 (power) in seconds",
            vg=600,
            r="to reduce number of energy reports",
          },
        },
      },
    },
    [96]={n="ZW096 Smart Switch 6",
      opt={
        param={
          {
            p=92,
            n="Induce an automatic (power) report %",
            v=100,
            r="to reduce number of small power reports",
          },
          {
            p=111,
            n="The time interval of sending Report group 1 (power) in seconds",
            vg=600,
            r="to reduce number of periodic power reports",
          },
          {
            p=112,
            n="The time interval of sending Report group 1 (power) in seconds",
            vg=600,
            r="to reduce number of energy reports",
          },
        },
      },
    },
  },
  [4]={
    [80]={n="ZW080 Siren Gen5",
      opt={
        tbd=true,
      },
    },
    [117]={n="ZW117 Range Extender Gen6",
      opt={
        tbd=false,
      },
    },
  },
}
ZWDB[138]={n="Benext",
  [5]={
    [257]={n="Alarm Sound",
      opt={
        tbd=true,
      },
    },
  },
}
ZWDB[151]={n="Schlage Link (Wintop)",
  [24881]={
    [17665]={n="Mini Keypad RFID",
      opt={
        tbd=true,
      },
    },
  },
}
ZWDB[153]={n="GreenWave",
  [2]={
    [2]={n="PowerNode 1 port (can spam network, problem not well understood)",
      opt={
      },
    },
  },
  [3]={
    [4]={n="PowerNode 6 port (can spam network, problem not well understood)",
      opt={
      },
    },
  },
}
ZWDB[265]={n="Vision Security (mob.IQ)",
  [8197]={n="ZM1601EU-5 Battery Operated Siren",
    [1288]={n="",
    },
  },
  [8199]={n="Plugin Socket",
    [1798]={n="",
    },
  },
  [8202]={n="ZG8101 Garage Door Detector",
    [2562]={n="",
    },
  },
}
ZWDB[271]={n="Fibaro (Fibar Group)",
  [256]={n="FGD211 Dimmer",
    opt={
      asc={
        1,
      },
      param={
        {
          p=41,
          n="Scene Activation",
          v=1,
          r="to use S2 in scenes",
        },
      },
      sw={
        14,
      },
      [0]={
        light=true,
        pwr=true,
      },
    },
    [263]={n="subrev 1/7",
    },
    [265]={n="subrev 1/9",
    },
    [4106]={n="subrev 10/A",
    },
  },
  [258]={n="FGD212 Dimmer 2",
    opt={
      asc={
        1,
      },
      fwh=26,
      fwl=25,
      param={
        {
          p=50,
          n="Active power reports",
          v=0,
          r="to reduce number of power reports",
        },
      },
      sw={
        20,
      },
      [1]={
        light=true,
      },
    },
    [4096]={n="",
    },
  },
  [512]={n="FGS221 Switch 2x1,5kW",
    opt={
      asc={
        3,
      },
      sw={
        14,
      },
      [0]={
        light=true,
        pwr=true,
      },
      [2]={
        light=true,
        pwr=true,
      },
    },
    [263]={n="subrev 1/7",
    },
    [4106]={n="subrev 10/A",
    },
  },
  [514]={n="FGS222 Switch 2x1,5kW",
    opt={
      asc={
        3,
      },
      sw={
        14,
      },
      [0]={
        light=true,
        pwr=true,
      },
      [2]={
        light=true,
        pwr=true,
      },
    },
    [4098]={n="",
    },
  },
  [515]={n="FGS223 Fibaro Double Switch",
    opt={
      param={
        {
          p=51,
          n="S1 minimal time between power reports (s)",
          vg=60,
          r="to reduce number of power reports",
        },
        {
          p=55,
          n="S2 minimal time between power reports (s)",
          vg=60,
          r="to reduce number of power reports",
        },
      },
      sw={
        20,
      },
      [1]={
        light=true,
      },
      [2]={
        light=true,
      },
    },
    [4096]={n="",
    },
    [8192]={n="",
    },
    [12288]={n="",
    },
  },
  [769]={n="FGRM222 Roller Shutter 2",
    opt={
      tbd=true,
    },
    [4096]={n="subrev 10/0",
    },
    [4097]={n="subrev 10/1",
    },
  },
  [770]={n="FGRM222 Roller Shutter 2",
    opt={
      tbd=true,
    },
    [4096]={n="",
    },
  },
  [771]={n="Roller Shutter 3",
    opt={
      tbd=true,
    },
    [4096]={n="",
    },
  },
  [1024]={n="FGS211 Switch 3kW",
    opt={
      asc={
        3,
      },
      sw={
        14,
      },
      [0]={
        light=true,
        pwr=true,
      },
    },
    [263]={n="subrev 1/7",
    },
    [4106]={n="subrev 10/A",
    },
  },
  [1026]={n="FGS212 Switch 2x1,5kW",
    opt={
      asc={
        3,
      },
      sw={
        14,
      },
      [0]={
        light=true,
        pwr=true,
      },
    },
    [4098]={n="subrev 1",
    },
    [12290]={n="subrev 2",
    },
  },
  [1027]={n="FGS213 Fibaro Single Switch",
    opt={
      param={
        {
          p=51,
          n="First channel - minimal time between power reports (s)",
          vg=60,
          r="to reduce number of power reports",
        },
      },
      sw={
        20,
      },
      [1]={
        light=true,
      },
      [2]={
        light=true,
      },
    },
    [4096]={n="",
    },
    [8192]={n="",
    },
    [16384]={n="",
    },
  },
  [1281]={n="FGBS321 Universal Binary Sensor",
    opt={
      asc={
        3,
      },
    },
    [4098]={n="",
    },
    [12290]={n="",
    },
    [16386]={n="",
    },
  },
  [1536]={n="FGWP101 Wall Plug",
    opt={
      param={
        {
          p=42,
          n="Reporting small changes in power",
          v=100,
          r="to reduce number of power reports",
        },
        {
          p=47,
          n="Power load reporting frequency",
          vg=300,
          r="to reduce number of power reports",
        },
      },
    },
    [4096]={n="",
    },
  },
  [1538]={n="FGWP102 Wall Plug Gen5",
    opt={
      param={
        {
          p=11,
          n="Standard power report",
          v=100,
          r="to reduce number of power reports",
        },
      },
    },
    [4096]={n="subrev 10/0",
    },
    [4097]={n="subrev 10/1",
    },
    [4098]={n="subrev 10/2",
    },
    [4099]={n="subrev 10/3",
    },
  },
  [1792]={n="FGK101 Door/Window Sensor",
    [4096]={n="",
    },
  },
  [1793]={n="FGK101 Door/Window Sensor",
    [4097]={n="",
    },
    [4098]={n="",
    },
  },
  [1794]={n="FGDW-002 D/W Sensor 2nd generation",
    opt={
      tbd=true,
    },
    [4096]={n="",
    },
  },
  [2048]={n="FGMS001 Motion Sensor",
    opt={
      wuh=21600,
      wul=7200,
    },
    [4097]={n="",
    },
  },
  [2049]={n="FGMS001 ZW5 Motion Sensor",
    opt={
      wuh=21600,
      wul=7200,
    },
    [4097]={n="",
    },
    [4098]={n="V2 (fw >= 3.3)",
    }
  },

  [2304]={n="FGRGBW 441M",
    opt={
      param={
        {
          p=44,
          n="Power load reporting frequency",
          vg=300,
          r="to reduce number of power reports",
        },
      },
    },
    [4096]={n="subrev 10/0",
    },
    [4097]={n="subrev 10/1",
    },
  },
  [2816]={n="FGFS101 Flood Sensor",
    [4097]={n="",
    },
  },
  [2817]={n="FGFS101 Flood Sensor Gen5",
    [4097]={n="",
    },
    [4098]={n="",
    },
  },
  [3072]={n="FGSS001 Smoke Sensor",
    [4096]={n="",
    },
  },
  [3074]={n="FGSD002 Smoke Sensor",
    opt={
      wuh=86400,
      wul=14400,
    },
    [4098]={n="",
    },
  },
  [3329]={n="FGGC001 Swipe",
    opt={
      asc={
        1,
      },
    },
    [4096]={n="",
    },
  },
  [3841]={n="Panic Button",
    opt={
      tbd=true,
    },
    [4096]={n="",
    },
  },
  [4097]={n="FGKF-601 Key Fob",
    opt={
      tbd=true,
    },
    [4096]={n="",
    },
  },
  [4609]={n="FGCD-001 CO Sensor",
    opt={
      tbd=true,
    },
    [4096]={n="",
    },
  },
  [4865]={n="FGT-001 Heat Controller",
    opt={
    },
    [4096]={n="",
    },
  },
  [6913]={n="FGWDS221 Walli Double Switch",
    opt={
    },
    [4096]={n="",
    },
  },
  [7169]={n="FGWD111 Walli Dimmer",
    opt={
    },
    [4096]={n="",
    },
  },
  [7425]={n="FGWR111 Walli Roller Shutter",
    opt={
    },
    [4096]={n="",
    },
  },
  [7937]={n="FGWOE/F Walli Outlet",
    opt={
    },
    [4096]={n="",
    },
  },
}
ZWDB[277]={n="Z-Wave.Me",
  [256]={n="WALLC-S",
    opt={
      wuh=0,
      wul=0,
    },
    [257]={n="",
    },
  },
  [272]={n="Z-UNO - this device can have any number and type of slaves",
    opt={
      wuh=0,
      wul=0,
    },
    [1]={n="",
    },
  },
  [4096]={n="zme_05443/06443 Wall Switch",
    opt={
      wuh=0,
      wul=0,
    },
    [4]={n="",
    },
  },
}
ZWDB[278]={n="Chromagic Technologies Corporation",
  [1]={n="HSP02",
    [1]={n="",
    },
  },
}
ZWDB[280]={n="TKB Home",
  [3]={
    [2]={n="TZ68 On/Off Switch Socket",
      opt={
        tbd=true,
      },
    },
  },
  [4]={n="TZ69 ON/OFF Switch with Power Meter",
    opt={
      param={
        {
          p=3,
          n="Watt meter report period (unit: 5s) to group 1",
          vg=720,
          r="5s*720=3600s, to reduce number of power reports",
        },
        {
          p=4,
          n="KWH meter report period (unit: 10min) to group 1",
          vg=6,
          r="10min*6=60min, to reduce number of periodic KWH reports",
        },
      },
      tbd=false,
    },
    [2]={n="EU Type Plug-in (TZ69G)",
    },
  },
  [257]={
    [259]={n="TZ68 On/Off Switch Socket",
      opt={
        tbd=true,
      },
    },
  },
  [258]={
    [4128]={n="TZ66D Dual Wall Switch",
      opt={
        tbd=true,
      },
    },
  },
  [513]={
    [1281]={n="TZ10.36 Wall Thermostat with",
      opt={
        tbd=true,
      },
    },
  },
  [785]={n="TZ69 ON/OFF Switch with Power Meter",
    opt={
      param={
        {
          p=3,
          n="Watt meter report period (unit: 5s) to group 1",
          vg=720,
          r="5s*720=3600s, to reduce number of power reports",
        },
        {
          p=4,
          n="KWH meter report period (unit: 10min) to group 1",
          vg=6,
          r="10min*6=60min, to reduce number of periodic KWH reports",
        },
      },
      tbd=false,
    },
    [259]={n="EU Type Plug-in, French outlet (TZ69F)",
    },
  },
  [2056]={
    [2056]={n="TZ65 Dual Wall Dimmer",
      opt={
        tbd=true,
      },
    },
  },
}
ZWDB[305]={n="Zipato",
  [2]={
    [2]={n="RGBW LED Bulb",
      opt={
        tbd=true,
      },
    },
  },
}
ZWDB[309]={n="ZyXEL",
  [11]={n="Everspring ST812",
    [1]={n="",
    },
  },
}
ZWDB[316]={n="Philio Technology Corporation",
  [1]={
    [18]={n="PAN04-1 Double Relay Switch 2x1.5kW with Power Measurement",
      opt={
        tbd=false,
        param={
          {
            p=1,
            n="Watt meter report period (unit: 5s) to group 1",
            vg=720,
            r="5s*720=3600s, to reduce number of power reports",
          },
          {
            p=2,
            n="KWH meter report period (unit: 10min) to group 1",
            vg=6,
            r="10min*6=60min, to reduce number of periodic KWH reports",
          },
        },
      },
    },
    [19]={n="PAN06-1 Double Relay Switch 2x1.5kW",
    },
  },
  [2]={
    [31]={n="PAT02-A flood multisensor",
      opt={
        tbd=false,
        wuh=86400,
        wul=14400,
        param={
          {
            p=21,
            n="Temperature differential report (step 1F (0,556°C))",
            vg=2,
            r="5s*720=3600s, to reduce number of power reports",
          },
          {
            p=23,
            n="Humidity differential report (humimity %)",
            vg=10,
            r="to reduce number of periodic reports",
          },
          {
            p=10,
            n="Battery period report (unit: min)",
            vg=600,
            r="to reduce number of periodic reports, set to 0 to disable the auto report",
          },
          {
            p=13,
            n="Temperature period report (unit: min)",
            vg=600,
            r="to reduce number of periodic reports, set to 0 to disable the auto report",
          },
          {
            p=14,
            n="Humidity period report (unit: min)",
            vg=600,
            r="to reduce number of periodic reports set to 0 to disable the auto report",
          },
          {
            p=15,
            n="Flood state  period report (unit: min)",
            v=0,
            r="to reduce number of periodic reports, set to 0 to disable the auto report",
          },
          {
            p=30,
            n="Minimum auto reports interval (unit: min)",
            vg=60,
            r="to reduce number of time based reports, 0 disable exept low batery report",
          },
        },
      },
    },
    [32]={n="PH-PAT02-B.eu Multisensor 2in1",
      opt={
        tbd=true,
      },
    },
  },
}
ZWDB[340]={n="Popp",
  [1]={
    [1]={n="123658 Plug-in Switch plus Power Meter",
      opt={
        tbd=true,
      },
    },
  },
}
ZWDB[343]={n="EcoNet Controls",
  [3]={
    [2]={n="EVC200 Z-Wave Valve Controller",
      opt={
        tbd=true,
      },
    },
  },
}
ZWDB[345]={n="Qubino (Goap)",
  [1]={
    [1]={n="ZMNHDA2 Flush Dimmer",
      opt={
        asc={
          4,
        },
        [0]={
          light=true,
        },
      },
    },
    [83]={n="ZMNHVDx Flush Dimmer 0-10V",
      opt={
        tbd=true,
      },
    },
  },
  [2]={
    [1]={n="ZMNHBA2 Flush 2 Relays",
      opt={
        [1]={
          light=true,
        },
        [2]={
          light=true,
        },
      },
    },
    [81]={n="ZMNHBD1 Flush 2 Relays",
      opt={
        param={
          {
            p=120,
            n="Temperature Sensor (if connected) Reporting Threshold [C]",
            vg=10,
            r="(step 0.1C) reports temperature readings based on the threshold defined in this parameter, 0 - disabled",
          },
          {
            p=40,
            n="Watt Power Consumption Reporting Threshold for Q1 Load [%]",
            vg=50,
            r="device report power consumption if changed more than % value, 0 - disabled",
          },
          {
            p=42,
            n="Watt Power Consumption Report Time Threshold for Q1 Load [s]",
            vg=600,
            r="energy consumption will be sent every N seconds",
          },
          {
            p=41,
            n="Watt Power Consumption Reporting Threshold for Q2 Load [%]",
            vg=50,
            r="device report power consumption if changed more than % value, 0 - disabled",
          },
          {
            p=43,
            n="Watt Power Consumption Report Time Threshold for Q1 Load [s]",
            vg=600,
            r="energy consumption will be sent every N seconds",
          },
        },
        [1]={
          light=true,
        },
        [2]={
          light=true,
        },
      },
    },
    [83]={n="ZMNHND1 Flush 1D Relay",
      opt={
        param={
          {
            p=120,
            n="Temperature Sensor (if connected) Reporting Threshold [C]",
            vg=10,
            r="(step 0.1C) reports temperature readings based on the threshold defined in this parameter, 0 - disabled",
          },
        },
        [1]={
          light=true,
        },
      },
    },
  },
  [3]={
    [83]={n="ZMNHOD1 Flush Shutter DC",
      opt={
        tbd=true,
      },
    },
  },
  [5]={
    [1]={n="ZMNHIA2 Flush on/off thermostat",
      opt={
        tbd=true,
      },
    },
    [81]={n="ZMNHID1 Flush on/off thermostat, rev.3",
      opt={
        param={
          {
            p=120,
            n="Temperature Sensor Reporting Threshold [C]",
            vg=10,
            r="(step 0.1C) reports temperature readings based on the threshold defined in this parameter, 0 - disabled",
          },
          {
            p=40,
            n="Watt Power Consumption Reporting Threshold for Q Load [%]",
            vg=50,
            r="device report power consumption if changed more than % value, 0 - disabled",
          },
          {
            p=42,
            n="Watt Power Consumption Report Time Threshold for Q Load [s]",
            vg=600,
            r="energy consumption will be sent every N seconds",
          },
          {
            p=76,
            n="Association group 2, 10 - reporting on time interval [min]",
            v=0,
            r="If not used asscociations with bypass controler set 0 - disabled",
          },
        },
      },
    },
    [82]={n="ZMNHKDx Flush Heat and Cool thermostat",
      opt={
        tbd=true,
      },
    },
  },
  [81]={n="ZMNHBD1 Flush 2 Relays",
    opt={
      param={
        {
          p=120,
          n="Temperature Sensor Reporting Threshold [C]",
          vg=10,
          r="(step 0.1C) reports temperature readings based on the threshold defined in this parameter, 0 - disabled",
        },
        {
          p=40,
          n="Watt Power Consumption Reporting Threshold for Q1 Load [%]",
          vg=50,
          r="device report power consumption if changed more than % value, 0 - disabled",
        },
        {
          p=42,
          n="Watt Power Consumption Report Time Threshold for Q1 Load [s]",
          vg=600,
          r="energy consumption will be sent every N seconds",
        },
        {
          p=41,
          n="Watt Power Consumption Reporting Threshold for Q2 Load [%]",
          vg=50,
          r="device report power consumption if changed more than % value, 0 - disabled",
        },
        {
          p=43,
          n="Watt Power Consumption Report Time Threshold for Q1 Load [s]",
          vg=600,
          r="energy consumption will be sent every N seconds",
        },
      },
      [1]={
        light=true,
      },
      [2]={
        light=true,
      },
    },
  },
  [83]={n="ZMNHND1 Flush 1D Relay",
    opt={
      param={
        {
          p=120,
          n="Temperature Sensor Reporting Threshold [C]",
          vg=10,
          r="(step 0.1C) reports temperature readings based on the threshold defined in this parameter, 0 - disabled",
        },
      },
      [1]={
        light=true,
      },
    },
  },
}
ZWDB[351]={n="MCOHome",
  [2309]={
    [513]={n="MH9-CO2-WD CO2 Monitor",
      opt={
        tbd=true,
      },
    },
  },
}
ZWDB[357]={n="NodOn",
  [2]={
    [1]={n="CRC-3-1-00 Octan Remote",
      opt={
        tbd=true,
      },
    },
    [2]={n="CRC-3-6-0x Soft Remote",
      opt={
        tbd=true,
      },
    },
    [3]={n="CWS-3-1-01 Wall Switch",
      opt={
        tbd=true,
      },
    },
  },
}
ZWDB[358]={n="Swiid (CBCC Domotique SAS)",
  [256]={
    [256]={n="SwiidInter",
      opt={
        tbd=true,
      },
    },
  },
  [8199]={
    [1798]={n="SwiidPlug",
      opt={
        tbd=true,
      },
    },
  },
}
ZWDB[410]={n="Sensative",
  [3]={
    [3]={n="Strips",
      opt={
        tbd=true,
      },
    },
  },
}
ZWDB[526]={n="Horstmann",
  [19522]={
    [12596]={n="Smart LED Retrofit Kit ZE27EU",
      opt={
        tbd=true,
      },
    },
  },
}
ZWDB[600]={n="Neo",
  [3]={
    --4226
    [4226]={n="Z-wave Door/Window Sensor (NAS-DS01Z)",
    },
    [4227]={n="Motion Sensor 1 (NAS-PD01ZE)",
      opt={
        param={
          {
            p=7,
            n="Light Sensor Polling Interval [s]",
            vg=3600,
            r="to reduce number of update of lux level if not changed",
          },
          {
            p=9,
            n="How much Lux must be changed to report [lx]",
            vg=100,
            r="to reduce number of update of lux level if changed",
          },
        },
        wul=14400,
        wuh=86400,
      },
    },
    [4231]={n="nas-wr01z power plug",
      opt={
        param={
          {
            p=6,
            n="Configure power report %",
            v=100,
            r="to reduce number of power reports",
          },
        },
      },
    },
    [4235]={n="Light switch EU, two output",
    },
    [4236]={n="Wall Switch (1 channel)",
    },
    [4237]={n="Motion Sensor 2 with temperature sensor",
      opt={
        param={
          {
            p=7,
            n="Light Sensor Polling Interval [s]",
            vg=3600,
            r="to reduce number of update of lux level if not changed",
          },
          {
            p=9,
            n="How much Lux must be changed to report [lx]",
            vg=100,
            r="to reduce number of update of lux level if changed",
          },
          {
            p=10,
            n="How much temperature must be changed to report [by 0.1C]",
            vg=10,
            r="(0.1*10=1C) to reduce number of update of temperature if changed",
          },
          {
            p=12,
            n="Motion Event Report One Time Enable",
            v=1,
            r="motion detected event will be sent to controller only once until device report motion cleared event",
          },
        },
      },
    },
  },
}
ZWDB[608]={n="Heiman",
  [32775]={
    [4096]={n="Temperature Humidity Sensor HS1HT-Z",
      opt={
        wul=14400,
        wuh=86400,
      },
    },
  },
}
ZWDB[647]={n="iBlinds",
  [3]={
    [13]={n="IB2.0 Window Blind Controller",
      opt={
      },
    },
  },
}
ZWDB[881]={n="Aeon Technologies",
  [2]={
    [3]={n="ZWA003-C NanoMote Quad",
      opt={
        wul=0,
        wuh=0,
      },
    },
  },
}
ZWDB[21076]={n="Remotec",
  [1]={
    [34064]={n="ZRC-90",
    },
  },
  [257]={
    [33655]={n="ZXT-120EU",
    },
  },
}

check()
