load "/usr/people/pduran/progs/ncl/harvey/read_sfmr.ncl"
load "/usr/people/pduran/progs/ncl/harvey/read_flight_level.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/contrib/cd_string.ncl"
;--------------------------------------------
; flight-level-to-sfmr.ncl
; Patrick Duran
; 07 February 2019
;
; Reads in a set of flight-level data files
; and a corresponding set of SFMR data files
; and computes the ratio of the flight-level
; wind to the SFMR wind.
;-------------------------------------------

fldir = "/raid1/pduran/jm13/flight-level/harvey/"
sfmrdir = "/raid1/pduran/jm13/sfmr/2017/harvey/"
timeunits = "seconds since 2016-1-1 00:00:00"
imgdir = "/raid1/pduran/figures/harvey/altitude/"

;-----------------------------------------
;IT IS NOT NECESSARY AT THIS TIME TO READ 
;SFMR DATA FILES BECAUSE THE WIND SPEEDS
;AND ERROR FLAGS ARE ALREADY CONTAINED IN
;THE FLIGHT-LEVEL DATA FILES.
;-----------------------------------------
;Read SFMR data files.
;sfmrfiles = systemfunc("ls "+sfmrdir+"*nc")
;nfiles = dimsizes(sfmrfiles)
;sfmrv   = new((/nfiles,1000000/),"float")
;sfmrlat = new((/nfiles,1000000/),"float")
;sfmrlon = new((/nfiles,1000000/),"float")
;sfmrtime= new((/nfiles,1000000/),"integer")
;do i=0,nfiles-1
;   print( "Reading SFMR file "+sfmrfiles(i))
;   filename = sfmrfiles(i)
;   sfmrdata = read_sfmr(filename,timeunits)
;   ntimes = dimsizes(sfmrdata[0])
;   sfmrv   (i,:ntimes-1) = sfmrdata[0]
;   sfmrlat (i,:ntimes-1) = sfmrdata[1]
;   sfmrlon (i,:ntimes-1) = sfmrdata[2]
;   sfmrtime(i,:ntimes-1) = sfmrdata[3]
;end do

;Read flight-level data files
flfiles = systemfunc("ls "+fldir+"*.*")
nfiles = dimsizes(flfiles)
flvbig   = new((/nfiles,1000000/),"float")
fllatbig = new((/nfiles,1000000/),"float")
fllonbig = new((/nfiles,1000000/),"float")
flaltbig = new((/nfiles,1000000/),"float")
flpresbig= new((/nfiles,1000000/),"float")
sfmrvbig = new((/nfiles,1000000/),"float")
fltimebig= new((/nfiles,1000000/),"integer")
flvbig@_FillValue = -9999.
sfmrvbig@_FillValue = -9999.
do i=0,nfiles-1
   print( "Reading flight-level file "+flfiles(i))
   filename = flfiles(i)
   fldata = read_flight_level(filename,timeunits)
   ntimes = dimsizes(fldata[0])
   flvbig   (i,:ntimes-1) = (/fldata[0]/)     
   fllatbig (i,:ntimes-1) = (/fldata[1]/)     
   fllonbig (i,:ntimes-1) = (/fldata[2]/)     
   flaltbig (i,:ntimes-1) = (/fldata[3]/)     
   flpresbig(i,:ntimes-1) = (/fldata[4]/)
   sfmrvbig (i,:ntimes-1) = (/fldata[5]/)
   fltimebig(i,:ntimes-1) = (/fldata[6]/)
end do

;Copy variable metadata
copy_VarAtts(fldata[0],flvbig)
copy_VarAtts(fldata[1],fllatbig)
copy_VarAtts(fldata[2],fllonbig)
copy_VarAtts(fldata[3],flaltbig)
copy_VarAtts(fldata[4],flpresbig)
copy_VarAtts(fldata[5],sfmrvbig)
copy_VarAtts(fldata[6],fltimebig)

;Reduce size of arrays by chopping off trailing missing values.
maxindex = new(nfiles,"integer")
do i=0,nfiles-1
   maxindex(i) = max(ind(.not.ismissing(fltimebig(i,:))))
end do
flv   = new((/nfiles,max(maxindex)+1/),"float")
fllat = new((/nfiles,max(maxindex)+1/),"float")
fllon = new((/nfiles,max(maxindex)+1/),"float")
flalt = new((/nfiles,max(maxindex)+1/),"float")
flpres= new((/nfiles,max(maxindex)+1/),"float")
sfmrv = new((/nfiles,max(maxindex)+1/),"float")
fltime= new((/nfiles,max(maxindex)+1/),"integer")
do i=0,nfiles-1
   flv   (i,0:maxindex(i)) = flvbig   (i,0:maxindex(i))
   fllat (i,0:maxindex(i)) = fllatbig (i,0:maxindex(i))
   fllon (i,0:maxindex(i)) = fllonbig (i,0:maxindex(i))
   flalt (i,0:maxindex(i)) = flaltbig (i,0:maxindex(i))
   flpres(i,0:maxindex(i)) = flpresbig(i,0:maxindex(i))
   sfmrv (i,0:maxindex(i)) = sfmrvbig (i,0:maxindex(i))
   fltime(i,0:maxindex(i)) = fltimebig(i,0:maxindex(i))
end do
flv@_FillValue = -9999.
flalt@_FillValue = -9999.
flpres@_FillValue = -9999.
sfmrv@_FillValue = -9999.

;Replace nans with missing values
replace_ieeenan(flv,flv@_FillValue,0)
replace_ieeenan(flalt,flalt@_FillValue,0)
replace_ieeenan(flpres,flpres@_FillValue,0)
replace_ieeenan(sfmrv,sfmrv@_FillValue,0)

;Subsample time array for plotting. Subsample to 1-h intervals
;to use as horizontal axis labels.
fltimesub = fltime(:,::3600)
copy_VarMeta(fltime,fltimesub)

;Make plots for each flight
wks = new(nfiles,"graphic")
altplot   = new(nfiles,"graphic")
flvplot   = new(nfiles,"graphic")
presplot  = new(nfiles,"graphic")
sfmrvplot = new(nfiles,"graphic")
do i=0,nfiles-1
   unixi = i + 1
   print( "Drawing plot "+unixi+" of "+nfiles+" to "+imgdir+flfiles(i)+".png")
   ;Get time strings for plotting
   timestr := cd_string(fltimesub(i,:),"%H UTC")
   filename_trim = systemfunc("echo "+flfiles(i)+" | awk -F'/' '{print $NF}'")
   wks(i) = gsn_open_wks("png",imgdir+filename_trim)
   res = True
   res@gsnLeftString = "Aircraft Altitude" 
   res@tiXAxisString = "Time"
   res@tiYAxisString = "Altitude [m]"
   res@tmXBMode = "Explicit"
   res@tmXBValues = fltimesub(i,:)
   res@tmXBLabels = timestr
   res@tmXBLabelFontHeightF = .015
   res@tmXBLabelAngleF = 40.
   res@trYMinF = 0
   res@trXMinF = min(fltime(i,:))
   res@trXMaxF = max(fltime(i,:))
   res@tmYROn = False
   res@tmXTOn = False
   res@gsnDraw = False
   res@gsnFrame = False
   altplot(i)  = gsn_csm_xy(wks(i),fltime(i,:),flalt(i,:),res)
   res@gsnLeftString = "Flight-level wind speed"
   res@tiYAxisString = "Wind speed (m s~S~-1~N~)"
   flvplot(i) = gsn_csm_xy(wks(i),fltime(i,:),flv(i,:),res)
   res@gsnLeftString = "Flight-level pressure"
   res@tiYAxisString = "Pressure (hPa)"
   presplot(i) = gsn_csm_xy(wks(i),fltime(i,:),flpres(i,:),res)
   res@gsnLeftString = "SFMR wind speed"
   res@tiYAxisString = "Wind speed (m s~S~-1~N~)"
   sfmrvplot(i) = gsn_csm_xy(wks(i),fltime(i,:),sfmrv(i,:),res)
   panelres = True
   panelres@gsnPanelMainString = filename_trim
   gsn_panel(wks(i),(/altplot(i),flvplot(i),presplot(i),sfmrvplot(i)/),(/2,2/),panelres)
end do
