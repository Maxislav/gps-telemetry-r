local log_filename = "/LOGS/GPSpositions.txt"
local file_exist = false
local buffer
local coordinates
local linectr = 1
local scrollIndex = 1
local string_gmatch = string.gmatch
local displayItemsLength = 5
-- 128x64 


local function splitstring(text)

	if text ~= nil then
		local text_split = {}
		local i=1
		--split by "," and store into array/table
		for word in string_gmatch(text, "([^,]+)") do
			text_split[i] = word
			i = i + 1
		end

		return text_split
	end
end

local function getCurrentElements()
    local arr = {}

    for i=1, displayItemsLength do
        local coordinate = coordinates[scrollIndex -1+i]
        if coordinate ~= nil then
            arr[i] = coordinate
        end
    end
    return arr
end

local function Viewer_Draw_LCD(i)

    lcd.clear()
	lcd.drawLine(0,0,0,64, SOLID, FORCE)
	lcd.drawLine(127,0,127,64, SOLID, FORCE)
	lcd.drawText(2,1,"GPS stats viewer R" ,SMLSIZE)	
    lcd.drawLine(0,63,127,63, SOLID, FORCE)	
    lcd.drawFilledRectangle(1,0, 126, 9, GREY_DEFAULT)
	--lcd.drawFilledRectangle(1,0, 126, 9, GREY_DEFAULT)

    local arr = getCurrentElements();
    local y = 12
    for i = 1, #arr do
        local line = splitstring(arr[i])
        lcd.drawText(2,y, line[1] .."," .. line[2]..",".. line[3].. ","..line[5], SMLSIZE)
        y = y + 10
    end
end


local function Viewer_Init()
	coordinates = {}
    scrollIndex = 1
	lcd.clear()
	local f2 = io.open(log_filename, "r")
	linectr = 1
	--check if file exists
	if f2 ~= nil then

		file_exist = true
		buffer = io.read(f2, 4096)
		io.close(f2)

		--read file contents into array/table
		for line in string_gmatch(buffer, "([^\n]+)\n") do
			if not string.find(line, "Number")  then --exclude logfile headline
				coordinates[linectr] = line	
				linectr = linectr + 1	
			end
		end

		--draw inital screen
		Viewer_Draw_LCD(1)

	else
		file_exist = false
	end
 end



-- Main
local function Viewer_Run(event)

    if event == nil then
		error("Cannot be run as a model script!")
		return 2
	else

        if file_exist == true then
            Viewer_Draw_LCD(scrollIndex)
            if event == EVT_VIRTUAL_INC  then
                scrollIndex = scrollIndex + 1
			end

			if event == EVT_VIRTUAL_DEC  then
				scrollIndex = scrollIndex - 1

			end
            if scrollIndex > linectr - displayItemsLength then
                scrollIndex = linectr - displayItemsLength
            end
            if scrollIndex < 1 then
                scrollIndex = 1
            end
        end
        if event == EVT_VIRTUAL_EXIT then
			return 2
		end

    end
    return 0
end

 return { init=Viewer_Init, run=Viewer_Run }
