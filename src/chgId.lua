--[[
        ChgId

      DanielGeA

  License https://www.gnu.org/licenses/gpl-3.0.en.html

  Ported from erskyTx. Thanks to Mike Blanford

  Lua script for radios X7, X9, X-lite and Horus with openTx 2.2 or higher

  Change Frsky sensor Id

]] --

local version = "0.3.3"
local refresh = 0
local lcdChange = true
local state = {
    INIT = {},
    MAINTENANCE_ON = {},
    SENSOR_ID_REQUESTED = {},
    SENSOR_ID_RECEIVED = {},
    SENSOR_ID_SENT = {},
    MAINTENANCE_OFF = {}
}
local readIdState = state["MAINTENANCE_OFF"]
local sendIdState = state["MAINTENANCE_OFF"]
local tsReadId = 0
local tsSendId = 0
local sensorIdTx = 17 -- sensorid 18
local sensor = {
    sensorType = {
        selected = 13,
        elements = 12,
        list = {
            "Vario",
            "FAS-40S",
            "FLVSS",
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
        },
        dataId = {0x100, 0x200, 0x300, 0x500, 0x600, 0x700, 0x800, 0xA00, 0xB00, 0xD00, 0xF103, 0x5100}
    },
    sensorId = {selected = 29, elements = 28}
}
local selection = {selected = 1, state = false, list = {"sensorType", "sensorId"}, elements = 2}

local function getFlags(element)
    if selection.selected ~= element then
        return 0
    end
    if selection.selected == element and selection.state == false then
        return 0 + INVERS
    end
    if selection.selected == element and selection.state == true then
        return 0 + INVERS + BLINK
    end
    return
end

local function increase(data)
    data.selected = data.selected + 1
    if data.selected > data.elements then
        data.selected = 1
    end
end

local function decrease(data)
    data.selected = data.selected - 1
    if data.selected < 1 then
        data.selected = data.elements
    end
end

local function readId()
    if readIdState == state["INIT"] then
        if sportTelemetryPush(sensorIdTx, 0x21, 0xFFFF, 0x80) then
            readIdState = state["MAINTENANCE_ON"]
            tsReadId = getTime()
        end
    elseif readIdState == state["MAINTENANCE_ON"] then
        if sportTelemetryPush(sensorIdTx, 0x30, sensor.sensorType.dataId[sensor.sensorType.selected], 0x01) then
            readIdState = state["SENSOR_ID_REQUESTED"]
        end
    elseif readIdState == state["SENSOR_ID_REQUESTED"] then
        local physicalId, frameId, dataId, value = sportTelemetryPop()
        if frameId == 0x32 and dataId == sensor.sensorType.dataId[sensor.sensorType.selected] then
            if bit32.band(value, 0xFF) == 0x01 then
                sensor.sensorId.selected = bit32.rshift(value, 8) + 1
                readIdState = state["SENSOR_ID_RECEIVED"]
            end
        end 
    elseif readIdState == state["SENSOR_ID_RECEIVED"] then
        if sportTelemetryPush(sensorIdTx, 0x20, 0xFFFF, 0x80) then
            lcdChange = true
            readIdState = state["MAINTENANCE_OFF"]
        end
    end
    if readIdState ~= state["MAINTENANCE_OFF"] and getTime() - tsReadId > 100 then
        if sportTelemetryPush(sensorIdTx, 0x20, 0xFFFF, 0x80) then
            lcdChange = true
            readIdState = state["MAINTENANCE_OFF"]
        end
    end
end

local function sendId()
        if sendIdState == state["INIT"] then
            if sportTelemetryPush(sensorIdTx, 0x21, 0xFFFF, 0x80) then
                tsSendId = getTime()
                sendIdState = state["MAINTENANCE_ON"]
            end
        elseif sendIdState == state["MAINTENANCE_ON"] then
            if sportTelemetryPush(
                sensorIdTx,
                0x31,
                sensor.sensorType.dataId[sensor.sensorType.selected],
                bit32.lshift((sensor.sensorId.selected - 1), 8) + 0x01
            ) then
                sendIdState = state["SENSOR_ID_SENT"]
            end
        elseif sendIdState == state["SENSOR_ID_SENT"] then
            if sportTelemetryPush(sensorIdTx, 0x20, 0xFFFF, 0x80) then
                lcdChange = true
                sendIdState = state["MAINTENANCE_OFF"]
            end
        end
        if sendIdState ~= state["MAINTENANCE_OFF"] and getTime() - tsSendId > 100 then
            if sportTelemetryPush(sensorIdTx, 0x20, 0xFFFF, 0x80) then
                lcdChange = true
                sendIdState = state["MAINTENANCE_OFF"]
            end
        end
end

local function init_func()
end

local function bg_func(event)
    if refresh < 5 then
        refresh = refresh + 1
    end
end

local function refreshHorus()
    lcd.clear()
    lcd.drawRectangle(110, 40, 260, 150)
    lcd.drawText(180, 50, "ChangeId v" .. version, 0 + INVERS)
    lcd.drawText(150, 90, "Sensor", 0)
    lcd.drawText(150, 110, "Sensor Id", 0)
    lcd.drawText(250, 90, sensor.sensorType.list[sensor.sensorType.selected], getFlags(1))
    if sensor.sensorId.selected ~= sensor.sensorId.elements + 1 then
        lcd.drawText(250, 110, sensor.sensorId.selected, getFlags(2))
    else
        lcd.drawText(250, 110, "-", getFlags(2))
    end
    if readIdState ~= state["MAINTENANCE_OFF"] then
        lcd.drawText(150, 130, "Reading Id...", 0 + INVERS)
    end
    if sendIdState ~= state["MAINTENANCE_OFF"] then
        lcd.drawText(150, 130, "Updating Id...", 0 + INVERS)
    end
    lcd.drawText(120, 160, "Long press [ENTER] to update", 0 + INVERS)
end

local function refreshTaranis()
    lcd.clear()
    lcd.drawScreenTitle("ChangeId v" .. version, 1, 1)
    lcd.drawText(1, 11, "Sensor", 0)
    lcd.drawText(1, 21, "Sensor Id", 0)
    lcd.drawText(60, 11, sensor.sensorType.list[sensor.sensorType.selected], getFlags(1))
    if sensor.sensorId.selected ~= sensor.sensorId.elements + 1 then
        lcd.drawText(60, 21, sensor.sensorId.selected, getFlags(2))
    else
        lcd.drawText(60, 21, "-", getFlags(2))
    end
    if readIdState ~= state["MAINTENANCE_OFF"] then
        lcd.drawText(1, 35, "Reading Id...", 0 + INVERS)
    end
    if sendIdState ~= state["MAINTENANCE_OFF"] then
        lcd.drawText(1, 35, "Updating Id...", 0 + INVERS)
    end
    lcd.drawText(1, 46, "Long press [ENTER] or [MENU]", SMLSIZE)
    lcd.drawText(1, 54, "              to update", SMLSIZE)
end

local function run_func(event)
    if refresh == 5 or lcdChange == true or selection.state == true then
        if LCD_W == 480 then
            refreshHorus()
        else
            refreshTaranis()
        end
        lcdChange = false
    end

    -- capture key events (left = up/decrease, right = down/increase)
    if selection.state == false then
        if event == EVT_ROT_LEFT or event == EVT_MINUS_BREAK or event == EVT_DOWN_BREAK then
            decrease(selection)
            lcdChange = true
        end
        if event == EVT_ROT_RIGHT or event == EVT_PLUS_BREAK or event == EVT_UP_BREAK then
            increase(selection)
            lcdChange = true
        end
    end
    if selection.state == true then
        if event == EVT_ROT_LEFT or event == EVT_MINUS_BREAK or event == EVT_DOWN_BREAK then
            if selection.selected == 1 then
                sensor.sensorId.selected = sensor.sensorId.elements + 1
            end
            decrease(sensor[selection.list[selection.selected]])
            if sensor.sensorId.selected - 1 == sensorIdTx then
                decrease(sensor[selection.list[selection.selected]])
            end
            lcdChange = true
        end
        if event == EVT_ROT_RIGHT or event == EVT_PLUS_BREAK or event == EVT_UP_BREAK then
            if selection.selected == 1 then
                sensor.sensorId.selected = sensor.sensorId.elements + 1
            end
            increase(sensor[selection.list[selection.selected]])
            if sensor.sensorId.selected - 1 == sensorIdTx then
                increase(sensor[selection.list[selection.selected]])
            end
            lcdChange = true
        end
    end
    if event == EVT_ENTER_BREAK and sendIdState == state["MAINTENANCE_OFF"] then
        selection.state = not selection.state
        if
            selection.selected == 1 and sensor.sensorId.selected == sensor.sensorId.elements + 1 and
                sensor.sensorType.selected ~= sensor.sensorType.elements + 1 and
                selection.state == false
         then
            readIdState = state["INIT"]
        end
        lcdChange = true
    end
    if event == EVT_EXIT_BREAK then
        if
            selection.selected == 1 and sensor.sensorId.selected == sensor.sensorId.elements + 1 and
                sensor.sensorType.selected ~= sensor.sensorType.elements + 1 and
                selection.state == true
         then
            readIdState = state["INIT"]
        end
        selection.state = false
        lcdChange = true
    end
    if event == EVT_ENTER_LONG or event == EVT_MENU_LONG then
        -- killEvents(EVT_ENTER_LONG) -- not working
        if
            sensor.sensorId.selected ~= sensor.sensorId.elements + 1 and
                sensor.sensorType.selected ~= sensor.sensorType.elements + 1
         then
            sendIdState = state["INIT"]
            lcdChange = true
        end
    end

    if readIdState ~= state["MAINTENANCE_OFF"] then readId() end
    if sendIdState ~= state["MAINTENANCE_OFF"] then sendId() end

    refresh = 0
    return 0
end

return {run = run_func, background = bg_func, init = init_func}
