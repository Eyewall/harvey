;------------------------------------------------
; read_flight_level.ncl
; Patrick Duran
; 07 February 2019
;
; Reads and returns wind speed, lat/lon locations,
; and time from a NOAA or USAF aircraft recon
; flight-level data file.
; 
; ---------
; ARGUMENTS
; ---------
; filename: The full path to the netCDF SFMR file.
; timeunits: The units of time to use.
;
; -------
; RETURNS
; -------
; v: Wind speed (m/s)
; lats: Latitudes (deg N)
; lons: Longotudes (deg E)
; time: Times (timeunits [e.g. "XXXXX" since "YYYYY"]) 
;------------------------------------------------

undef("read_flight-level")
function read_flight_level(filename:string,timeunits:string,cal)
begin

;Different agencies have different file formats.
;If the filename contains a "U", this is a USAF flight.
;If the filename contains an "H" or "I", this is a NOAA flight.
char = systemfunc("echo "+filename+" | awk -F'/' '{print $NF}' | cut -c9")
if(char.eq."U")then   ;Read using USAF format
   ;Details of this format here: http://www.aoml.noaa.gov/hrd/format/usaf.html
   ;Get date and time from header
   datestr = systemfunc("head -1 "+filename+" | awk '{print $11}'")
   datestr_split = str_split(datestr,"/")
   YYYY = toint(datestr_split(2))
   MM   = toint(datestr_split(0))
   DD   = toint(datestr_split(1))
   ;Get columns of data
   timestr = systemfunc("sed -e '1,6d' "+filename+" | awk '{print $1}'")  ;Time (HH:MM:SS)
   latstr  = systemfunc("sed -e '1,6d' "+filename+" | awk '{print $13}'") ;Latitude (deg N)
   lonstr  = systemfunc("sed -e '1,6d' "+filename+" | awk '{print $14}'") ;Longitude (deg E)
   altstr  = systemfunc("sed -e '1,6d' "+filename+" | awk '{print $19}'") ;Radar altitude (m)
   presstr = systemfunc("sed -e '1,6d' "+filename+" | awk '{print $18}'") ;Barometric pressure (hPa)
   headstr = systemfunc("sed -e '1,6d' "+filename+" | awk '{print $24}'") ;True heading (deg)
   flvstr  = systemfunc("sed -e '1,6d' "+filename+" | awk '{print $31}'") ;Flight-level wind speed (kt)
   sfmrvstr= systemfunc("sed -e '1,6d' "+filename+" | awk '{print $34}'") ;SFMR wind speed (kt)
   flagstr = systemfunc("sed -e '1,6d' "+filename+" | awk '{print $42}'") ;QC flags (binary)
   ;Convert time to timeunits
   timesplit = str_split_csv(timestr,":",3)
   HH = toint(timesplit(:,0))
   mm = toint(timesplit(:,1))
   ss = toint(timesplit(:,2))
   time = round(cd_inv_calendar(conform(HH,YYYY,0),conform(HH,MM,0),conform(HH,DD,0),\
                HH,mm,ss,timeunits,cal),3)
   ;Need to check for a change of day mid-file. This index and all subsequent
   ;indices will need to have 86400 seconds added to their final time.
   if(any(timestr.eq."00:00:00"))then
      midnight = ind(timestr.eq."00:00:00")
      time(midnight:) = time(midnight:) + 86400
   end if
   ;Convert strings to numeric
   lats = tofloat(latstr)
   lons = tofloat(lonstr)
   alt  = tofloat(altstr)
   pres = tofloat(presstr)
   head = toint(headstr)
   v    = tofloat(flvstr)
   sfmrv= tofloat(sfmrvstr)
   v@_FillValue = -9999.
   sfmrv@_FillValue = -9999.
   ;Replace flagged observations with missing values
   sfmrvflags = toint(systemfunc("sed -e '1,6d' "+filename+" | awk '{print $42}' | cut -c 33"))
   vflags     = toint(systemfunc("sed -e '1,6d' "+filename+" | awk '{print $42}' | cut -c 40"))
   sfmrv = where(sfmrvflags.eq.0,sfmrv@_FillValue,sfmrv)
   v     = where(vflags.eq.0,v@_FillValue,v)
   ;Convert kt to m/s
   v = v*0.514444
   sfmrv = sfmrv*0.514444
elseif(char.eq."H".or.char.eq."I")then   ;Read using NOAA ASCII format or netCDF file
   suffix = systemfunc("echo "+filename+" | awk -F'.' '{print $NF}'")
   if(suffix.eq."txt")then
      timestr = systemfunc("sed -e '1,4d' "+filename+" | awk '{print $1}'")  ;Time (HH:MM:SS)
      latstr  = systemfunc("sed -e '1,4d' "+filename+" | awk '{print $2}'")  ;Latitude (deg N)
      lonstr  = systemfunc("sed -e '1,4d' "+filename+" | awk '{print $3}'")  ;Longitude (deg W)
      headstr = systemfunc("sed -e '1,4d' "+filename+" | awk '{print $4}'")  ;Heading (deg)
      presstr = systemfunc("sed -e '1,4d' "+filename+" | awk '{print $9}'")  ;Longitude (deg W)
      altstr  = systemfunc("sed -e '1,4d' "+filename+" | awk '{print $15}'") ;Radar altitude (m)
      flvstr  = systemfunc("sed -e '1,4d' "+filename+" | awk '{print $11}'") ;Flight-level wind u(kt)
      ;Get date of beginning of flight
      YYYYMMDD = tochar(systemfunc("head -1 "+filename+" | awk '{print $NF}' | cut -c 1-8"))
      YYYY = toint(tostring(YYYYMMDD(0:3)))
      MM = toint(tostring(YYYYMMDD(4:5)))
      DD = toint(tostring(YYYYMMDD(6:7)))
      ;Get time strings for every data record
      timestr_split = str_split_by_length(timestr,2)
      HH = toint(timestr_split(:,0))
      mm = toint(timestr_split(:,1))
      ss = toint(timestr_split(:,2))
      ;In this format, if the data roll over into a new day, hours becomes larger than 23.
      ;Where this is the case, replace hours with (HH-24) and subsequently add 86400 to time.
      nextdayinds = ind(HH.gt.23)
      if(.not.all(ismissing(nextdayinds)))then
         HH(nextdayinds) = HH(nextdayinds) - 24
      end if
      ;Compute times in timeunits and add 86400 wherever necessary
      time = round(cd_inv_calendar(conform(ss,YYYY,0),conform(ss,MM,0),conform(ss,DD,0),HH,mm,ss,timeunits,cal),3)
      if(.not.all(ismissing(nextdayinds)))then
         time(nextdayinds) = time(nextdayinds) + 86400
      end if
      ;Convert lats, lons, alt, head, pres, v, and sfmrv to correct types
      lats = tofloat(latstr)
      lons = tofloat(lonstr) * -1.0  ;In this format, lons are in Deg W, so convert to Deg E
      head = round(tofloat(headstr),3)
      pres = tofloat(presstr)
      alt  = tofloat(altstr)
      v    = tofloat(flvstr)
      sfmrv= conform(v,-9999.,0)
   elseif(suffix.eq."nc")then
      f = addfile(filename,"r")
      timein  = f->Time
      lats    = f->LATref
      lons    = f->LONref
      alt     = f->ALTref
      head    = toint(f->THDGref)
      pres    = f->$"PS.c"$
      v       = f->$"WS.d"$
      sfmrv   = f->$"SfmrWS.1"$
      sfmrflag= f->$"SfmrDV.1"$
      ;If time array is float, set missing value and convert to int
      if(typeof(timein).eq."float")then
         temp = toint(timein)
         copy_VarMeta(timein,temp)
         timein := temp
         delete(temp)
      end if
      ;Convert times to timeunits. Some files have incomplete time units,
      ;so need to check for this and correct it first.
      if(timein@units.eq."seconds since flight start time")then
         flightdate_split = str_split(f@FlightDate,"/")
         flighttime_split = str_split(f@TimeInterval,"-")
         YYYY = flightdate_split(2)
         MM = flightdate_split(0)
         DD = flightdate_split(1)
         flighttime = flighttime_split(0)
         timein@units = "seconds since "+YYYY+"-"+MM+"-"+DD+" "+flighttime
      end if
      time = round(cd_convert(timein,timeunits),3)
      ;Set all questionable SFMR observations to missing.
      sfmrv = where(sfmrflag.ne.0,sfmrv@_FillValue,sfmrv)
   end if
else
   print( "ERROR: Unknown flight-level data format. Exiting.")
   exit
end if

time@units = timeunits

;Output data
sfmrv@_FillValue = -9999.
return([/v,lats,lons,alt,head,pres,sfmrv,time/])

end
