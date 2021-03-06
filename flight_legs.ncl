load "/usr/people/pduran/progs/ncl/harvey/rad_azi.ncl"

;------------------------------------------------
; flight_legs.ncl
; Patrick Duran
; 22 February 2019
;
; Determines the start and ending times of flight
; legs in reconnaissance data using the rate of
; change of the true heading and prints to an
; ascii file the beginning and ending times of
; each leg, along with the flight-level and
; SFMR Vmax and their lats,lons, pressure altitudes.
; 
; ---------
; ARGUMENTS
; ---------
; flfile: File from which original data come (string)
; time_fl: Times for flight-level data (1-D numeric array)
; hdg: True heading (1-D numeric array)
; lat_fl: Aircraft latitude (deg N)
; lon_fl: Aircraft longitude (deg E)
; pres: Pressure at aircraft altitude (hPa)
; alt: Radar altitude of aircraft (m)
; v: Flight-level wind speed
; time_sfmr: Times of SFMR observations
; lat_sfmr: Latitudes of SFMR observations
; lon_sfmr: Longitudes of SFMR observations
; surfv: Surface (SFMR) wind speed
; outdir: Directory in which to output ASCII file
; timeunits: Units of time (string)
; names: Array of best track storm names (1-D strings)
; btlat: Array of best track latitudes (1-D float)
; btlon: Array of best track longitudes (1-D float)
; bttime: Array of best track times (1-D numeric; units of timeunits)
;
; ------
; OUTPUT
; ------
; An ASCII file of format:
;------------------------------------------------

undef("flight_legs")
procedure flight_legs(flfile:string,time_fl:numeric,hdg:numeric,lat_fl:numeric,lon_fl:numeric,\
                      pres:numeric,alt:numeric,v:numeric,time_sfmr:numeric,lat_sfmr:numeric,\
                      lon_sfmr:numeric,surfv:numeric,outdir:string,timeunits:string,\
                      names:string,btlat:float,btlon:float,bttime:numeric)
local i, j
begin

print( "Getting flight legs for "+flfile)

;Compute rate of change of heading
dhdt = abs(center_finite_diff(hdg,time_fl,False,0))

;Define a "turn" as dhdt >= 2 deg/s. Loop
;through dhdt and find turns.
allturnstarttimes = new(1000,"integer")
allturnendtimes   = new(1000,"integer")
j = 0
do i=1,dimsizes(dhdt)-2
   prev = dhdt(i-1)
   cur  = dhdt(i)
   if(.not.ismissing(prev).and..not.ismissing(cur))
      if(prev.lt.2.and.cur.ge.2)then
      allturnstarttimes(j) = time_fl(i)
      end if
      if(prev.ge.2.and.cur.lt.2)then
         allturnendtimes(j) = time_fl(i)
         j = j + 1
      end if
   end if
end do

;Set a minimum leg duration to rule out small-scale
;changes in heading associated with convection avoidance, etc.
minduration = 1000   ;1000 seconds seems like a good cutoff
nturns = dimsizes(allturnstarttimes)
;The start time of each leg is the end time of each turn.
;The end time of each leg is the start time of each turn.
legdurations = allturnendtimes(1:) - allturnstarttimes(:nturns-2)
leginds = ind(legdurations.gt.minduration)
if(all(ismissing(leginds)))then
   print( "NO FLIGHT LEGS MEET THE MINIMUM DISTANCE THRESHOLD...SKIPPING TO NEXT FLIGHT.")
else
   turnstarttimes = allturnstarttimes(ind(legdurations.gt.1000))
   turnendtimes   = allturnendtimes(ind(legdurations.gt.1000))
   
   ;The start time of each leg is the end time of each turn.
   ;The end time of each leg is the start time of each turn.
   if(dimsizes(turnendtimes).eq.1)then
      legstarttimes = turnendtimes(0)
      legendtimes = turnstarttimes(0)
   else
      legstarttimes = turnendtimes(:dimsizes(turnendtimes)-2)
      legendtimes = turnstarttimes(1:)
   end if
   
   ;Compute radius and azimuth of each flight-level observation from storm center.
   print( "Computing distance and azimuth of all observations from storm center.")
   radazi = rad_azi(bttime,btlat,btlon,lat_fl,lon_fl,time_fl)
   radii = radazi[0]
   azis  = radazi[1]
   
   ;Compute minimum distance from storm center for this flight leg
   ;using the storm's best track interpolated to 1-minute intervals.
   ;Loop through the flight legs and get data on all of them.
   nlegs = dimsizes(legstarttimes)
   legstartlats = new(nlegs,"float")
   legstartlons = new(nlegs,"float")
   legendlats = new(nlegs,"float")
   legendlons = new(nlegs,"float")
   vmax_fl       = new(nlegs,"float")
   vmax_sfmr     = new(nlegs,"float")
   vmax_fl_lat   = new(nlegs,"float")
   vmax_fl_lon   = new(nlegs,"float")
   vmax_fl_rad   = new(nlegs,"float")
   vmax_fl_azi   = new(nlegs,"float")
   vmax_fl_time   = new(nlegs,"integer")
   vmax_sfmr_lat  = new(nlegs,"float")
   vmax_sfmr_lon  = new(nlegs,"float")
   vmax_sfmr_rad  = new(nlegs,"float")
   vmax_sfmr_azi  = new(nlegs,"float")
   vmax_sfmr_time = new(nlegs,"integer")
   vmax_pres      = new(nlegs,"float")
   minrad         = new(nlegs,"float")
   do i=0,nlegs-1
      startind = ind(time_fl.eq.legstarttimes(i))
      endind = ind(time_fl.eq.legendtimes(i))
      legstartlats(i) = lat_fl(startind)
      legstartlons(i) = lon_fl(startind)
      legendlats(i) = lat_fl(endind)
      legendlons(i) = lon_fl(endind)
      vmax_fl(i)  = max(v(startind:endind))
      vmax_sfmr(i)= max(surfv(startind:endind))
      if(.not.ismissing(vmax_fl(i)))then
         vmax_fl_lat(i)   = lat_fl (startind+maxind(v(startind:endind)))
         vmax_fl_lon(i)   = lon_fl (startind+maxind(v(startind:endind)))
         vmax_fl_rad(i)   = radii  (startind+maxind(v(startind:endind)))
         vmax_fl_azi(i)   = azis   (startind+maxind(v(startind:endind)))
         vmax_fl_time(i)  = time_fl(startind+maxind(v(startind:endind)))
         vmax_pres(i)     = pres(startind+maxind(v(startind:endind)))
      end if
      if(.not.ismissing(vmax_sfmr(i)))then
         vmax_sfmr_lat(i) = lat_sfmr (startind+maxind(surfv(startind:endind)))
         vmax_sfmr_lon(i) = lon_sfmr (startind+maxind(surfv(startind:endind)))
         vmax_sfmr_rad(i) = radii    (startind+maxind(surfv(startind:endind)))
         vmax_sfmr_azi(i) = azis     (startind+maxind(surfv(startind:endind)))
         vmax_sfmr_time(i)= time_sfmr(startind+maxind(surfv(startind:endind)))
      end if
      minrad(i) = min(radii(startind:endind))
   end do
   ratio = vmax_sfmr/vmax_fl   ;Wind speed ratio
   
   ;Print header for ASCII files
;   head1 = [/"Flight leg data file (space-delimited) containing, from left to right:"/]
;   head2 = [/"Leg Start Time, Leg End Time, Leg Start Lat, Leg Start Lon, Leg End Lat, Leg End Lon, Maximum Flight-Level Wind, Latitude of Maximum Flight-Level Wind, Longitude of Maximum Flight-Level Wind, Time of Maximum Flight-Level Wind, Maximum SFMR Wind, Latitude of Maximum SFMR Wind, Longitude of Maximum SFMR Wind, Time of Maximum SFMR Wind, Pressure at Flight Level when Maximum Flight-Level Wind Observed, Ratio of Maximum SFMR Wind, Maximum Flight-Level Wind (Vsfmr/Vflight), Minimum distance from storm center"/]
   head3 = [/"Time units: "+timeunits/]
   head4 = [/"Wind speed units: m/s"/]
   space = [/" "/]
;   write_table("header.tmp","w",head1,"%s")
;   write_table("header.tmp","a",space,"%s")
;   write_table("header.tmp","a",head2,"%s")
;   write_table("header.tmp","a",space,"%s")
   write_table("header.tmp","w",head3,"%s")
   write_table("header.tmp","a",head4,"%s")
   write_table("header.tmp","a",space,"%s")

   ;Set missing values
   legstarttimes@_FillValue = -9999
   legendtimes@_FillValue = -9999
   legstartlats@_FillValue = -9999.
   legstartlons@_FillValue = -9999.
   legendlats@_FillValue = -9999.
   legendlons@_FillValue = -9999.
   vmax_fl@_FillValue = -9999.
   vmax_fl_lat@_FillValue = -9999.
   vmax_fl_lon@_FillValue = -9999.
   vmax_fl_rad@_FillValue = -9999.
   vmax_fl_azi@_FillValue = -9999.
   vmax_fl_time@_FillValue = -9999
   vmax_sfmr@_FillValue = -9999.
   vmax_sfmr_lat@_FillValue = -9999.
   vmax_sfmr_lon@_FillValue = -9999.
   vmax_sfmr_rad@_FillValue = -9999.
   vmax_sfmr_azi@_FillValue = -9999.
   vmax_sfmr_time@_FillValuw = -9999
   vmax_pres@_FillValue = -9999.
   ratio@_FillValue = -9999.
   minrad@_FillValue = -9999.

   ;Print data to ASCII files
   filename = systemfunc("echo "+flfile+" | awk -F'/' '{print $NF}' | awk -F'.' '{print $1}'")
   outfile = outdir+filename+"-legs.txt"
   outvars = [/legstarttimes,legendtimes,legstartlats,legstartlons,legendlats,legendlons,\
               vmax_fl,vmax_fl_lat,vmax_fl_lon,vmax_fl_rad,vmax_fl_azi,vmax_fl_time,\
               vmax_sfmr,vmax_sfmr_lat,vmax_sfmr_lon,vmax_sfmr_rad,vmax_sfmr_azi,\
               vmax_sfmr_time,vmax_pres,ratio,minrad/]
   format = "%10i %10i %5.2f %6.2f %5.2f %6.2f "+\
            "%5.1f %6.2f %6.2f %6.2f %6.2f %10i "+\ 
            "%5.1f %6.2f %6.2f %6.2f %6.2f "+\
            "%10i %7.2f %5.3f %5.1f"
   write_table("data.tmp","w",outvars,format)
   
   system("cat header.tmp data.tmp > "+outfile)
end if
end
