;------------------------------------------------
; rad.ncl
; Patrick Duran
; 26 February 2019
;
; Computes radius of a lat,lon
; point from a reference lat,lon point.
; Uses storm center information from an
; interpolated best-track file to find the
; storm center at the time of the observation.
;
; ARGUMENTS
; ---------
; stormtime1min: Storm time from interpolated best-track file
; reflat: Latitude of the storm center (degrees North)
; reflon: Longitude of the storm center (degrees East)
; lats: Latitudes of observations
; lons: Longitudes of observations
; time: Times of the observations
;------------------------------------------------

undef("rad")
function rad(stormtime1min:numeric,reflat:numeric,reflon:numeric,\
             lats:numeric,lons:numeric,times:numeric)
begin

;Loop through all observations and get radius from the
;storm center position at the closest time.
stormtimes = stormtime1min
stormlats = reflat
stormlons = reflon
nobs   = dimsizes(times)       ;Number of observations
Robs   = new(nobs,"float")     ;Radii of obs
Robs@_FillValue = -9999.

do i=0,nobs-1
   ;If this time isn't missing, find nearest best-track time
   if(ismissing(times(i)))then
      continue
   end if
   timeind = minind(abs(stormtimes-times(i)))
   ;Compute distance of this observation from storm center
   Robs(i) = gc_latlon(stormlats(timeind),stormlons(timeind),lats(i),lons(i),2,4)
end do

return(Robs)

end
