;------------------------------------------------
; read_sfmr.ncl
; Patrick Duran
; 07 February 2019
;
; Reads and returns wind speed, lat/lon locations,
; and time from an SFMR NetCDF file.
; Filters out all observations where FLAG!=0 (i.e.
; only returns valid obs that aren't questionable.
; 
; ---------
; ARGUMENTS
; ---------
; filename: The full path to the netCDF SFMR file.
; timeunits: The units of time to use.
;------------------------------------------------

undef("read_sfmr")
function read_sfmr(filename:string,timeunits:string)
begin

f = addfile(filename,"r")
dates := f->DATE
times := f->TIME
lats  := tofloat(f->LAT)
lons  := tofloat(f->LON)
v     := tofloat(f->SWS)
flags := f->FLAG

;Set all questionable observations to missing.
v = where(flags.ne.0,v@_FillValue,v)

;Get only those observations that fall within the time constraints
;Time is stored as an integer, so need to prepend
;zeroes depending on how small the number is.
timestr := tostring(times)
timestr := where(times.eq.0,"0",timestr)
timestr := where(times.lt.10,"0"+timestr,timestr)
timestr := where(times.lt.100,"0"+timestr,timestr)
timestr := where(times.lt.1000,"0"+timestr,timestr)
timestr := where(times.lt.10000,"0"+timestr,timestr)
timestr := where(times.lt.100000,"0"+timestr,timestr)

;Split time and date strings and convert to integer
timesplit = str_split_by_length(timestr,2)
sfmrhour = toint(timesplit(:,0))
sfmrminu = toint(timesplit(:,1))
sfmrsec  = toint(timesplit(:,2))
datesplit = str_split_by_length(tostring(dates),(/4,2,2/))
sfmryear = toint(datesplit(:,0))
sfmrmon  = toint(datesplit(:,1))
sfmrday  = toint(datesplit(:,2))

;Convert SFMR dates and times to timeunits
time = round(cd_inv_calendar(sfmryear,sfmrmon,sfmrday,sfmrhour,sfmrminu,sfmrsec,timeunits,0),3)
time@units = timeunits

;Output data
return([/v,lats,lons,time/])

end
