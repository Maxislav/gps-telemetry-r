local log_filename = "/LOGS/GPSpositions.txt"
local file_exist = false
local buffer
local coordinates
local linectr = 1
local item = 1
local string_gmatch = string.gmatch
local displayItensLength = 5
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

    for i=1, displayItensLength  do
        local coordinate = coordinates[item-1+i]
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
	lcd.drawText(2,1,"GPS stats viewer v1.2" ,SMLSIZE)	
    lcd.drawLine(0,63,127,63, SOLID, FORCE)	
    lcd.drawFilledRectangle(1,0, 126, 9, GREY_DEFAULT)
	--lcd.drawFilledRectangle(1,0, 126, 9, GREY_DEFAULT)

    local arr = getCurrentElements();
    local y = 12
    for i = 1, #arr do
        local line = splitstring(arr[i])
        lcd.drawText(2,y, line[1] .."," .. line[2]..",".. line[3], SMLSIZE)
        y = y + 10
    end
end


local function Viewer_Init()
	coordinates = {}
    item = 1
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
                local first_comma_index = string.find(line, ",")
                local new_str = tostring(linectr) .. string.sub(line, first_comma_index)
				coordinates[linectr] = new_str	
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
            Viewer_Draw_LCD(item)  
            if event == EVT_VIRTUAL_INC  then  
                
				item = item + 1
			end		
	
			if event == EVT_VIRTUAL_DEC  then      
				item = item - 1				
			end
            if item > linectr - displayItensLength then
                item = linectr - displayItensLength
            end
            if item < 1 then
                item = 1
            end

            
        end
        if event == EVT_VIRTUAL_EXIT then
			return 2
		end

    end
    return 0
end

 return { init=Viewer_Init, run=Viewer_Run }
