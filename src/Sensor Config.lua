--[[

                      ConfigSensor

                       DanielGeA

  License https://www.gnu.org/licenses/gpl-3.0.en.html

        Ported from erskyTx. Thanks to Mike Blanford



  Lua script for radios X7, X9, X-lite and Horus with openTx 2.2 or higher

  Change Frsky sensor config: Id, data rate

]] --

local version = "0.4"
local readState = {state = "MAINTENANCE_OFF", timeStampInit = 0, timeStamp = 0, receivedId = false, receivedRate = false,  receivedVersion = false}
local writeState = {state = "MAINTENANCE_OFF", timeStamp = 0, received = false}
local sensorIdTx = 17 -- sensorid 18
local menu = {
    selected = 1,
    state = 1,     -- 1 selection, 2 change selected
    item = {
        {name = "sensorType", pos = 0, type = "list", item = {
            "Vario",
            "FAS-40S",
            "FLVSS/MLVSS",
            "RPM",
            "Fuel",
            "Accel",
            "GPS",
            "Air speed",
            "R Bus",
            "Gas suit",
            "X8R2ANA",
            "MSRC",
            "-"
        }},
        {name = "physicalId", pos = 0, type = "range", min = 1, max = 28},
        {name = "dataRate", pos = 0, type = "range", min = 1, max = 100}
    }
}
local dataIdList = {0x100, 0x200, 0x300, 0x500, 0x600, 0x700, 0x800, 0xA00, 0xB00, 0xD00, 0xF103, 0x5100}

local sensorVersion = ""

local function len(array)
    local count = 0
    for _,_ in pairs(array) do
        count = count + 1
    end
    return count
end

local function update_menu(menu, event)
    -- key events (left = up/decrease right = down/increase)
    if menu.state == 1 then
        if event == EVT_ROT_LEFT or event == EVT_MINUS_BREAK or event == EVT_DOWN_BREAK then
            if menu.selected > 1 then
                menu.selected = menu.selected - 1
                return "SELECTION"
            end
        elseif event == EVT_ROT_RIGHT or event == EVT_PLUS_BREAK or event == EVT_UP_BREAK then
            if menu.selected < len(menu.item) then
                menu.selected = menu.selected + 1
                return "SELECTION"
            end
        elseif event == EVT_ENTER_BREAK then
            if menu.item[menu.selected].type == "button" then
                return menu.item[menu.selected].name
            else
                menu.state = 2
                return "STATE"
            end
        end
    elseif menu.state == 2 then
        if event == EVT_ROT_LEFT or event == EVT_MINUS_BREAK or event == EVT_DOWN_BREAK then
            if menu.item[menu.selected].type == "list" and menu.item[menu.selected].pos > 1 then
                menu.item[menu.selected].pos = menu.item[menu.selected].pos - 1
                return "ITEM"
            elseif menu.item[menu.selected].type == "range" and menu.item[menu.selected].pos > menu.item[menu.selected].min then
                menu.item[menu.selected].pos = menu.item[menu.selected].pos - 1
                return "ITEM"
            end
        elseif event == EVT_ROT_RIGHT or event == EVT_PLUS_BREAK or event == EVT_UP_BREAK then
            if menu.item[menu.selected].type == "list" and menu.item[menu.selected].pos < len(menu.item[menu.selected].item) then
                menu.item[menu.selected].pos = menu.item[menu.selected].pos + 1
                return "ITEM"
            elseif menu.item[menu.selected].type == "range" and menu.item[menu.selected].pos < menu.item[menu.selected].max then
                menu.item[menu.selected].pos = menu.item[menu.selected].pos + 1
                return "ITEM"
            end
        elseif event == EVT_ENTER_BREAK or event == EVT_EXIT_BREAK then
            menu.state = 1
            return "STATE"
        end
    end
end

local function get_id(menu, field_name)
    for id, elem in pairs(menu.item) do
        if field_name == elem.name then
            return id
        end
    end 
end

local function get_flags(menu, field_name)
    if get_id(menu, field_name) == menu.selected and menu.state == 1 then
        return INVERS
    elseif get_id(menu, field_name) == menu.selected and menu.state == 2 then
        return INVERS + BLINK
    end
    return 0
end

local function get_value(menu, field_name)
    if menu.item[get_id(menu, field_name)].type == "range" then
        if menu.item[get_id(menu, field_name)].pos >= menu.item[get_id(menu, field_name)].min and menu.item[get_id(menu, field_name)].pos <= menu.item[get_id(menu, field_name)].max then
            return menu.item[get_id(menu, field_name)].pos
        else
            return "-"
        end
    elseif menu.item[get_id(menu, field_name)].type == "list" then
        return menu.item[get_id(menu, field_name)].item[menu.item[get_id(menu, field_name)].pos] or "-"
    elseif menu.item[get_id(menu, field_name)].type == "button" then
        return menu.item[get_id(menu, field_name)].label     
    end
    return ""
end

local function read()
    if readState.state == "INIT" then
        if sportTelemetryPush(sensorIdTx, 0x21, 0xFFFF, 0x80) then
            readState.state = "MAINTENANCE_ON"
            readState.timeStamp = getTime()
        end
    elseif readState.state == "MAINTENANCE_ON" and getTime() - readState.timeStamp > 20 then
        if sportTelemetryPush(sensorIdTx, 0x30, dataIdList[menu.item[get_id(menu, "sensorType")].pos], 0x01) then
            readState.state = "SENSOR_ID_REQUESTED"
            readState.timeStamp = getTime()
        end
    elseif readState.state == "SENSOR_ID_REQUESTED" then
        local physicalId, frameId, dataId, value = sportTelemetryPop()
        if frameId == 0x32 and dataId == dataIdList[menu.item[get_id(menu, "sensorType")].pos] then
            if bit32.band(value, 0xFF) == 0x01 then
                menu.item[get_id(menu, "physicalId")].pos = bit32.rshift(value, 8) + 1
                readState.receivedId = true
                readState.state = "SENSOR_ID_RECEIVED"
            end
        end 
    elseif readState.state == "SENSOR_ID_RECEIVED" then
        if sportTelemetryPush(sensorIdTx, 0x30, dataIdList[menu.item[get_id(menu, "sensorType")].pos], 0x22) then
            readState.state = "SENSOR_RATE_REQUESTED"
            readState.timeStamp = getTime()
        end
    elseif readState.state == "SENSOR_RATE_REQUESTED" then
        local physicalId, frameId, dataId, value = sportTelemetryPop()
        if frameId == 0x32 and dataId == dataIdList[menu.item[get_id(menu, "sensorType")].pos] then
            if bit32.band(value, 0xFF) == 0x22 then
                menu.item[get_id(menu, "dataRate")].pos = bit32.rshift(value, 8)
                readState.receivedRate = true
                readState.state = "SENSOR_RATE_RECEIVED"
            end
        end
    elseif readState.state == "SENSOR_RATE_RECEIVED" then
        if sportTelemetryPush(sensorIdTx, 0x30, dataIdList[menu.item[get_id(menu, "sensorType")].pos], 0x0C) then
            readState.state = "SENSOR_VERSION_REQUESTED"
            readState.timeStamp = getTime()
        end
    elseif readState.state == "SENSOR_VERSION_REQUESTED" then
        local physicalId, frameId, dataId, value = sportTelemetryPop()
        if frameId == 0x32 and dataId == dataIdList[menu.item[get_id(menu, "sensorType")].pos] then
            if bit32.band(value, 0xFF) == 0x0C then
                value = bit32.rshift(value, 8)
                sensorVersion = string.char(value/16%16 + 48).."."..string.char(value%16 + 48)
                readState.receivedVersion = true
                readState.state = "SENSOR_VERSION_RECEIVED"
            end
        end
    elseif readState.state == "SENSOR_VERSION_RECEIVED" then
        if sportTelemetryPush(sensorIdTx, 0x20, 0xFFFF, 0x80) then
            readState.state = "MAINTENANCE_OFF"
        end
    end
    if readState.state == "SENSOR_ID_REQUESTED" and getTime() - readState.timeStamp > 80 then
        readState.state = "INIT"
        readState.timeStamp = getTime()
    elseif readState.state == "SENSOR_RATE_REQUESTED" and getTime() - readState.timeStamp > 80 then
        readState.state = "SENSOR_ID_RECEIVED"
        readState.timeStamp = getTime()
    elseif readState.state == "SENSOR_VERSION_REQUESTED" and getTime() - readState.timeStamp > 80 then
        readState.state = "SENSOR_RATE_RECEIVED"
        readState.timeStamp = getTime()
    end
    if readState.state ~= "MAINTENANCE_OFF" and getTime() - readState.timeStampInit > 1000 then
        readState.state = "MAINTENANCE_OFF"
    end
end

local function write()
    if writeState.state == "INIT" then
        if sportTelemetryPush(sensorIdTx, 0x21, 0xFFFF, 0x80) then
            writeState.timeStamp = getTime()
            writeState.state = "MAINTENANCE_ON"
        end
    elseif writeState.state == "MAINTENANCE_ON" and getTime() - writeState.timeStamp > 50 then
        if menu.item[get_id(menu, "physicalId")].pos > menu.item[get_id(menu, "physicalId")].min then
            if sportTelemetryPush(
                sensorIdTx,
                0x31,
                dataIdList[menu.item[get_id(menu, "sensorType")].pos],
                bit32.lshift((menu.item[get_id(menu, "physicalId")].pos - 1), 8) + 0x01
            ) then
                writeState.timeStamp = getTime()
                writeState.state = "SENSOR_ID_SENT0"
            end
        else
            writeState.timeStamp = getTime()
            writeState.state = "SENSOR_ID_SENT0"
        end 
    elseif writeState.state == "SENSOR_ID_SENT0" and getTime() - writeState.timeStamp > 50 then
        if menu.item[get_id(menu, "physicalId")].pos > menu.item[get_id(menu, "physicalId")].min then
            if sportTelemetryPush(
                sensorIdTx,
                0x31,
                dataIdList[menu.item[get_id(menu, "sensorType")].pos],
                bit32.lshift((menu.item[get_id(menu, "physicalId")].pos - 1), 8) + 0x01
            ) then
                writeState.timeStamp = getTime()
                writeState.state = "SENSOR_ID_SENT"
            end
        else
            writeState.timeStamp = getTime()
            writeState.state = "SENSOR_ID_SENT"
        end 
    elseif writeState.state == "SENSOR_ID_SENT" and getTime() - writeState.timeStamp > 50 then
        if menu.item[get_id(menu, "dataRate")].pos > menu.item[get_id(menu, "dataRate")].min then
            if sportTelemetryPush(
                sensorIdTx,
                0x31,
                dataIdList[menu.item[get_id(menu, "sensorType")].pos],
                bit32.lshift(menu.item[get_id(menu, "dataRate")].pos, 8) + 0x22
            ) then
                writeState.timeStamp = getTime()
                writeState.state = "SENSOR_RATE_SENT"
            end
        else
            writeState.timeStamp = getTime()
            writeState.state = "SENSOR_RATE_SENT"
        end 
    elseif writeState.state == "SENSOR_RATE_SENT" and getTime() - writeState.timeStamp > 50 then
        if sportTelemetryPush(sensorIdTx, 0x20, 0xFFFF, 0x80) then
            writeState.timeStamp = getTime()
            writeState.state = "MAINTENANCE_OFF"
        end
    end
    if writeState.state ~= "MAINTENANCE_OFF" and getTime() - writeState.timeStamp > 500 then
        if sportTelemetryPush(sensorIdTx, 0x20, 0xFFFF, 0x80) then
            writeState.state = "MAINTENANCE_OFF"
        end
    end
end

local function refreshHorus()
    lcd.clear()
    lcd.drawRectangle(100, 40, 280, 155)
    lcd.drawText(165, 50, "Sensor Config v" .. version, 0 + INVERS)
    lcd.drawText(110, 90, "Type", 0)
    lcd.drawText(110, 110, "Physical Id", 0)
    lcd.drawText(110, 130, "Data rate (ms)", 0)
    lcd.drawText(110, 150, "Firmware version", 0)
    lcd.drawText(250, 90, get_value(menu, "sensorType"), get_flags(menu, "sensorType"))
    lcd.drawText(250, 110, get_value(menu, "physicalId"), get_flags(menu, "physicalId"))
    if get_value(menu, "dataRate") ~= "-" then 
        lcd.drawText(250, 130, get_value(menu, "dataRate") * 100, 0 + get_flags(menu, "dataRate"))
    else
        lcd.drawText(250, 130, "-", 0 + get_flags(menu, "dataRate"))
    end
    lcd.drawText(250, 130, get_value(menu, "dataRate"), get_flags(menu, "dataRate"))
    lcd.drawText(250, 150, sensorVersion, 0)
    if readState.state ~= "MAINTENANCE_OFF" then
        lcd.drawText(110, 170, "Reading...", 0 + INVERS + BLINK)
    end
    if writeState.state ~= "MAINTENANCE_OFF" then
        lcd.drawText(110, 170, "Updating...", 0 + INVERS + BLINK)
    end
    lcd.drawText(120, 200, "Long press [ENTER] to update", 0 + INVERS)
end

local function refreshTaranis()
    lcd.clear()
    lcd.drawScreenTitle("Sensor Config v" .. version, 1, 1)
    lcd.drawText(1, 10, "Type", 0)
    lcd.drawText(1, 19, "Physical Id", 0)
    lcd.drawText(1, 28, "Data rate (ms)", 0)
    lcd.drawText(1, 37, "Firm version", 0)
    lcd.drawText(60, 10, get_value(menu, "sensorType"), 0 + get_flags(menu, "sensorType"))
    lcd.drawText(80, 19, get_value(menu, "physicalId"), 0 + get_flags(menu, "physicalId"))
    if get_value(menu, "dataRate") ~= "-" then 
        lcd.drawText(80, 28, get_value(menu, "dataRate") * 100, 0 + get_flags(menu, "dataRate"))
    else
        lcd.drawText(80, 28, "-", 0 + get_flags(menu, "dataRate"))
    end
    lcd.drawText(80, 37, sensorVersion, 0)
    if readState.state ~= "MAINTENANCE_OFF" then
        lcd.drawText(1, 46, "Reading...", 0 + INVERS + BLINK)
    end
    if writeState.state ~= "MAINTENANCE_OFF" then
        lcd.drawText(1, 46, "Updating...", 0 + INVERS + BLINK)
    end
    lcd.drawText(1, 56, "Long press [ENTER] to update", SMLSIZE)
end

local function run(event)
    if readState.state == "MAINTENANCE_OFF" and writeState.state == "MAINTENANCE_OFF" then
        if update_menu(menu, event) == "STATE" and menu.selected == get_id(menu, "sensorType") and menu.state == 1 then
            menu.item[get_id(menu, "physicalId")].pos = 0
            menu.item[get_id(menu, "dataRate")].pos = 0
            sensorVersion = ""
            readState.receivedId = false
            readState.receivedRate = false
            readState.receivedVersion = false
            readState.state = "INIT"
            readState.timeStampInit = getTime()
        end
    end
    if event == EVT_ENTER_LONG then
        -- killEvents(EVT_ENTER_LONG) -- not working
        if readState.receivedId == true then
            writeState.state = "INIT"
            writeState.timeStamp = getTime()
        end
    end
    if readState.state ~= "MAINTENANCE_OFF" then read() end
    if writeState.state ~= "MAINTENANCE_OFF" then write() end
    if LCD_W == 480 then
        refreshHorus()
    else
        refreshTaranis()
    end
    return 0
end

return {run = run}
