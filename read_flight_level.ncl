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
function read_flight_level(filename:string,timeunits:string)
begin

;Different agencies have different file formats.
;If the filename contains a "U", this is a USAF flight.
;If the filename contains an "H", this is a NOAA flight.
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
                HH,mm,ss,timeunits,0),3)
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
elseif(char.eq."H")then   ;Read using NOAA ASCII format or netCDF file
   suffix = systemfunc("echo "+filename+" | awk -F'.' '{print $NF}'")
   if(suffix.eq."txt")then
      timestr = systemfunc("sed -e '1,4d' "+filename+" | awk '{print $1}'")  ;Time (HH:MM:SS)
      latstr  = systemfunc("sed -e '1,4d' "+filename+" | awk '{print $2}'") ;Latitude (deg N)
      lonstr  = systemfunc("sed -e '1,4d' "+filename+" | awk '{print $3}'") ;Longitude (deg W)
      altstr  = systemfunc("sed -e '1,4d' "+filename+" | awk '{print $15}'") ;Radar altitude (m)
      flvstr  = systemfunc("sed -e '1,4d' "+filename+" | awk '{print $11}'") ;Flight-level wind u(kt)
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
return([/v,lats,lons,alt,head,pres,sfmrv,time/])

end
