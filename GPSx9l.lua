--[[#############################################################################
GPS Telemetry Screen 
################################################################################]]

log_filename = "/LOGS/GPSpositions.txt"
log_filename_1 = "/LOGS/GPSpositions-1.txt"
local gpsLAT = 0
local gpsLON = 0
local gpsLAT_H = 0
local gpsLON_H = 0
local gpsPrevLAT = 0
local gpsPrevLON = 0
local gpsSATS = 0
local gpsALT = 0
local gpsSpeed = 0
local gpssatId = 0
local gpsspeedId = 0
local gpsaltId = 0
local gpsFIX = 0
local gpsDtH = 0
local gpsTotalDist = 0
local log_write_wait_time = 500
local log_write_dist = 10
local old_time_write = 0
local update = true
local reset = false
local now = 0
local ctr = 0
local coordinates_prev = 0
local coordinates_current = 0


local e_log = {}
local e_dist_wait = 10
local e_gpsPrevLAT = 0
local e_gpsPrevLON = 0	

local e_log_write_wait_time = 25
local e_old_time_write = 0

local function rnd(v,d)
	if d then
		return math.floor((v*10^d)+0.5)/(10^d)
	else
		return math.floor(v+0.5)
	end
end

local function SecondsToClock(seconds)
  local seconds = tonumber(seconds)

  if seconds <= 0 then
    return "00:00:00";
  else
    hours = string.format("%02.f", math.floor(seconds/3600));
    mins = string.format("%02.f", math.floor(seconds/60 - (hours*60)));
    secs = string.format("%02.f", math.floor(seconds - hours*3600 - mins *60));    
	return hours..":"..mins..":"..secs
  end
end


--[	####################################################################
--[	calculate distance in km
--[	####################################################################
local function calc_Distance(LatPos, LonPos, LatHome, LonHome, r)
	local d2r = math.pi/180
	local d_lon = (LonPos - LonHome) * d2r 
	local d_lat = (LatPos - LatHome) * d2r 
	local a = math.pow(math.sin(d_lat/2.0), 2) + math.cos(LatHome*d2r) * math.cos(LatPos*d2r) * math.pow(math.sin(d_lon/2.0), 2)
	local c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
	local dist = (6371000 * c) / 1000	
	return rnd(dist,r)
end

local function fill_emegrency_log(value)
	local i = #e_log+1
	e_log[i] = value
	if 10<#e_log then
		for index = 1, #e_log - 1 do
			e_log[index] = e_log[index + 1]
		end
		
		e_log[#e_log] = nil
	end

end

local function concatenate_array(arr)
	local result_string = ""
	for i = 1, #arr do
		result_string = result_string ..string.format("%02d",i)..", ".. arr[i]
	end
	return result_string
end

local function write_e_log(str)
	file = io.open(log_filename, "w")   
	io.write(file, str)	
	io.close(file)
end

local function reset_e_log()
	file = io.open(log_filename, "w") 
	-- local str = "Number,LAT,LON,radio_time,satellites,GPSalt,GPSspeed\r\n"
	-- e_log = {"Number,LAT,LON,radio_time,satellites,GPSalt,GPSspeed\r\n"}
	e_log = {"00.000000, 00.000000, 00:00:00, 0, 0, 0\r\n"}
	

	io.write(file, concatenate_array(e_log))		
	io.close(file)
end


local function reset_l_log()
	file = io.open(log_filename_1, "w") 
	io.write(file, "Number,LAT,LON,radio_time,satellites,GPSalt,GPSspeed", "\r\n")		
	io.close(file)
end

local function write_l_log(str)
	file = io.open(log_filename_1, "a") 
	io.write(file, str)
	io.close(file)
end

local function write_log()

	now = getTime()    
	time_power_on = SecondsToClock(getGlobalTimer()["session"])

	local dist = calc_Distance(gpsLAT,gpsLON, e_gpsPrevLAT, e_gpsPrevLON, 6)*1000 --distance in metr
	if (dist > e_dist_wait) and (e_old_time_write + e_log_write_wait_time< now) then
		e_gpsPrevLAT = gpsLAT
		e_gpsPrevLON = gpsLON
		-- 
		fill_emegrency_log( gpsLAT..", " .. gpsLON ..",".. time_power_on ..", "..  gpsSATS..", ".. gpsALT ..", ".. gpsSpeed.."\r\n")
		write_e_log(concatenate_array(e_log))
		e_old_time_write = now

	end
	
    if old_time_write + log_write_wait_time < now then
	
		ctr = ctr + 1	
		local str = coordinates_current ..",".. time_power_on ..", "..  gpsSATS..", ".. gpsALT ..", ".. gpsSpeed .. "\r\n"
		write_l_log(str)	

		if ctr >= 500 then
			ctr = 0		
			reset_l_log()
				
		end	
		old_time_write = now
	end	
end


local function getTelemetryId(name)    
	field = getFieldInfo(name)
	if field then
		return field.id
	else
		return-1
	end
end

local function init()  		
	emergencyLog = {}		
	gpsId = getTelemetryId("GPS")
	--number of satellites crossfire
	gpssatId = getTelemetryId("Sats")

	--get IDs GPS Speed and GPS altitude
	gpsspeedId = getTelemetryId("GSpd") --GPS ground speed m/s
	gpsaltId = getTelemetryId("Alt") --GPS altitude m
		
	--if "ALT" can't be read, try to read "GAlt"
	if (gpsaltId == -1) then gpsaltId = getTelemetryId("GAlt") end	
		
	--if Stats can't be read, try to read Tmp2 (number of satellites SBUS/FRSKY)
	if (gpssatId == -1) then gpssatId = getTelemetryId("Tmp2") end	
end

local function background()	

	--####################################################################
	--get Latitude, Longitude, Speed and Altitude
	--####################################################################	
	gpsLatLon = getValue(gpsId)
		
	if (type(gpsLatLon) == "table") then 			
		gpsLAT = rnd(gpsLatLon["lat"],6)
		gpsLON = rnd(gpsLatLon["lon"],6)		
		gpsSpeed = rnd(getValue(gpsspeedId) * 1.852,1)
		gpsALT = rnd(getValue(gpsaltId),0)		
				
		--set home postion only if more than 5 sats available
		if (tonumber(gpsSATS) > 5) and (reset == true) then
			--gpsLAT_H = rnd(gpsLatLon["pilot-lat"],6)
			--gpsLON_H = rnd(gpsLatLon["pilot-lon"],6)	
			gpsLAT_H = rnd(gpsLatLon["lat"],6)
			gpsLON_H = rnd(gpsLatLon["lon"],6)	
			reset = false
		end		

		update = true	
	else
		update = false
	end
	
	--####################################################################
	--get number of satellites and GPS fix type
	--####################################################################	
	gpsSATS = getValue(gpssatId)
	
	if string.len(gpsSATS) > 2 then		
		-- SBUS Example 1013: -> 1= GPS fix 0=lowest accuracy 13=13 active satellites
		--[	Sats / Tmp2 : GPS lock status, accuracy, home reset trigger, and number of satellites. Number is sent as ABCD detailed below. Typical minimum 
		--[	A : 1 = GPS fix, 2 = GPS home fix, 4 = home reset (numbers are additive)
		--[	B : GPS accuracy based on HDOP (0 = lowest to 9 = highest accuracy)
		--[	C : number of satellites locked (digit C & D are the number of locked satellites)
		--[ D : number of satellites locked (if 14 satellites are locked, C = 1 & D = 4)		
		gpsSATS = string.sub (gpsSATS, 3,6)		
	else
		--CROSSFIRE stores only the active GPS satellite
		gpsSATS = string.sub (gpsSATS, 0,3)		
	end	
	
	--status message "guess"
	-- 2D Mode - A 2D (two dimensional) position fix that includes only horizontal coordinates. It requires a minimum of three visible satellites.)
	-- 3D Mode - A 3D (three dimensional) position fix that includes horizontal coordinates plus altitude. It requires a minimum of four visible satellites.
	if (tonumber(gpsSATS) < 2) then gpsFIX = "no GPS fix" end
	if (tonumber(gpsSATS) >= 3) and (tonumber(gpsSATS) <= 4)  then gpsFIX = "GPS 2D fix" end
	if (tonumber(gpsSATS) >= 5) then gpsFIX = "GPS 3D fix" end
	
	
	--####################################################################
	--get calculate distance from home and write log
	--####################################################################			
	if (tonumber(gpsSATS) >= 5) then

		local dist =calc_Distance(gpsLAT,gpsLON, gpsPrevLAT, gpsPrevLON, 6)*1000 
		
		if log_write_dist<dist then				
			
			if (gpsLAT_H ~= 0) and  (gpsLON_H ~= 0) then 
			
				--distance to home
				gpsDtH = rnd(calc_Distance(gpsLAT, gpsLON, gpsLAT_H, gpsLON_H, 2),2)			
				gpsDtH = string.format("%.2f",gpsDtH)		
				
				--total distance traveled					
				if (gpsPrevLAT ~= 0) and  (gpsPrevLON ~= 0) and (gpsLAT ~= 0) and  (gpsLON ~= 0)then	
					--print("GPS_Debug_Prev", gpsPrevLAT,gpsPrevLON)	
					--print("GPS_Debug_curr", gpsLAT,gpsLON)	
					
					gpsTotalDist =  rnd(tonumber(gpsTotalDist) + calc_Distance(gpsLAT,gpsLON,gpsPrevLAT,gpsPrevLON, 2),2)			
					gpsTotalDist = string.format("%.2f",gpsTotalDist)					
				end
			end

			--data for displaying the 
			coordinates_prev = string.format("%02d",ctr) ..", ".. gpsPrevLAT..", " .. gpsPrevLON
			coordinates_current = string.format("%02d",ctr+1) ..", ".. gpsLAT..", " .. gpsLON 
											
			gpsPrevLAT = gpsLAT
			gpsPrevLON = gpsLON	
			
			write_log()
		end 
	end			
	
	
end

local function fileExists(filepath)
	local file = io.open(filepath, "r")
	if file then
		io.close(file)
	  	return true
	end
		return false
end

local function createFiles()
	for i = 1, 10, 1 do
		local fileName = "/LOGS/GPSpositions-"..i..".txt"
		if not fileExists(fileName) then
			local file = io.open(fileName, "w") 
			io.write(file, "Number,LAT,LON,radio_time,satellites,GPSalt,GPSspeed", "\r\n")		
			io.close(file)
		end
	end
end

local function shiftContent()
	local readFileName
	local writeFileName
	local buffer
	local file
	for i = 9, 1, -1 do
		readFileName = "/LOGS/GPSpositions-"..i..".txt"
		writeFileName = "/LOGS/GPSpositions-"..(i+1)..".txt"
		file = io.open(readFileName, "r")	
			buffer = io.read(file, 20480)
		io.close(file)
		file = io.open(writeFileName, "w")
			io.write(file, buffer)
		io.close(file)
			buffer = nil	
	end
	buffer = nil
	
end
 
--main function 
local function run(event)  
	createFiles()	
	lcd.clear()  
	background() 
	

	--reset telemetry data / total distance on "long press enter"
	if event == EVT_ENTER_LONG then
		shiftContent()
		reset_l_log()
		reset_e_log()
		gpsDtH = 0
		gpsTotalDist = 0
		gpsLAT_H = 0
		gpsLON_H = 0
		reset = true
		-- 

		
	end 	
	
	-- create screen
	lcd.drawLine(0,0,0,64, SOLID, FORCE)	
	lcd.drawLine(127,0,127,64, SOLID, FORCE)	
	
	lcd.drawText(2,1,"State: " ,SMLSIZE)		
	lcd.drawFilledRectangle(1,0, 126, 8, GREY_DEFAULT)
	
	lcd.drawPixmap(2,10, "/SCRIPTS/TELEMETRY/BMP/Sat16.bmp")		
	lcd.drawLine(42,8, 42, 27, SOLID, FORCE)		
	lcd.drawPixmap(44,9, "/SCRIPTS/TELEMETRY/BMP/distance16.bmp")		
	lcd.drawLine(84,8, 84, 27, SOLID, FORCE)	
	lcd.drawPixmap(86,9, "/SCRIPTS/TELEMETRY/BMP/total_distance16.bmp")		
			
	lcd.drawLine(0,27, 128, 27, SOLID, FORCE)
				
	lcd.drawPixmap(2,28, "/SCRIPTS/TELEMETRY/BMP/home16.bmp")		
	lcd.drawLine(0,44, 128, 44, SOLID, FORCE)
			
	lcd.drawPixmap(2,47, "/SCRIPTS/TELEMETRY/BMP/drone16.bmp")
	lcd.drawLine(0,63,127,63, SOLID, FORCE)		
	
	--update screen data
	if update == true then
						
		lcd.drawText(32,1,gpsFIX ,SMLSIZE + INVERS)			
		lcd.drawText(22,14, gpsSATS, SMLSIZE)		
		lcd.drawText(60,10, gpsDtH, SMLSIZE)
		lcd.drawText(73,20, "km"  , SMLSIZE)
		lcd.drawText(103,10, gpsTotalDist, SMLSIZE)
		lcd.drawText(116,20, "km"  , SMLSIZE)
		
		if (gpsLAT_H ~= 0) and  (gpsLON_H ~= 0) then
			lcd.drawText(20,33, gpsLAT_H .. ", " .. gpsLON_H, SMLSIZE)
		else
			lcd.drawText(20,29, "home not set. reset", SMLSIZE + INVERS + BLINK)
			lcd.drawText(20,37, "telem. after GPS FIX!", SMLSIZE + INVERS + BLINK)
		end
				
		lcd.drawText(20,47, coordinates_prev,SMLSIZE)
		lcd.drawText(20,56, coordinates_current,SMLSIZE)
		e_reset = true
		
	--blink if telemetry stops
	elseif update == false then
		
		lcd.drawText(32,1,"no GPS data available" ,SMLSIZE + INVERS)
		lcd.drawText(22,14, gpsSATS, SMLSIZE + INVERS + BLINK )		
		lcd.drawText(60,10, gpsDtH , SMLSIZE + INVERS + BLINK)
		lcd.drawText(73,20, "km"  , SMLSIZE)
		lcd.drawText(103,10, gpsTotalDist , SMLSIZE)
		lcd.drawText(116,20, "km"  , SMLSIZE)		
		
		lcd.drawText(20,33, gpsLAT_H .. ", " .. gpsLON_H, SMLSIZE)
				
		lcd.drawText(20,47, coordinates_prev, SMLSIZE + INVERS + BLINK)
		lcd.drawText(20,56, coordinates_current, SMLSIZE + INVERS + BLINK)	
		
		-- write_e_log()
	end	
	
end
 
return {init=init, run=run, background=background}
