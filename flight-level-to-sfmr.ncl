load "/usr/people/pduran/progs/ncl/harvey/read_sfmr.ncl"
load "/usr/people/pduran/progs/ncl/harvey/read_flight_level.ncl"
load "/usr/people/pduran/progs/ncl/harvey/flight_legs.ncl"
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

undef("flight_level_to_sfmr")

function flight_level_to_sfmr(year,stormin)

local i, j

begin

storm = str_lower(stormin)
btfile = "/raid1/pduran/best-tracks/ebtrk_atlc_"+year+".txt_interpolated_1-minute"
fldir = "/raid1/pduran/hrd/flight-level/"+year+"/"+storm+"/"
sfmrdir = "/raid1/pduran/hrd/sfmr/"+year+"/"+storm+"/"
timeunits = "seconds since 1970-1-1 00:00:00"
cal = 0                    ;Set type of calendar to use for date conversions
;cal@calendar = "noleap"
imgdir = "/raid1/pduran/figures/"+year+"/"+storm+"/"
ascdir = "/raid1/pduran/ascii/"+year+"/"+storm+"/"

bindepth = 50  ;Depth (mb) of pressure bins in which to compute wind speed ratios.

;Check if there are data for this storm. If not, return 0.
;If fldir doesn't exist, there are no data for this storm.
print( fldir)
dirtest = systemfunc("test -d "+fldir+" ; echo $?")
if(dirtest.eq.1)then
   return(0)
end if

;Create some output directories, if necessary.
ascyeardir = "/raid1/pduran/ascii/"+year
dirtest = systemfunc("test -d "+ascyeardir+" ; echo $?")
if(dirtest.eq.1)then
   system("mkdir "+ascyeardir)
end if
dirtest = systemfunc("test -d "+ascdir+" ; echo $?")
if(dirtest.eq.1)then
   system("mkdir "+ascdir)
end if
imgyeardir = "/raid1/pduran/figures/"+year
dirtest = systemfunc("test -d "+imgyeardir+" ; echo $?")
if(dirtest.eq.1)then
   system("mkdir "+imgyeardir)
end if
dirtest = systemfunc("test -d "+imgdir+" ; echo $?")
if(dirtest.eq.1)then
   system("mkdir "+imgdir)
end if

;Read 1-minute interpolated best track file for this year
print( "Reading 1-minute interpolated best track file "+btfile)
nlines = toint(systemfunc("wc "+btfile+" | awk '{print $1}'"))
bt = asciiread(btfile,(/nlines,118/),"character")
ids      = str_squeeze(tostring(bt(:,0:5)))
names    = str_squeeze(tostring(bt(:,7:15)))
storminds= ind(names.eq.str_upper(storm))
MM       = toint(tostring(bt(storminds,17:18)))
DD       = toint(tostring(bt(storminds,19:20)))
HH       = toint(tostring(bt(storminds,21:22)))
mm       = toint(tostring(bt(storminds,23:24)))
YYYY     = toint(tostring(bt(storminds,26:29)))
btlat    = tofloat(tostring(bt(storminds,31:35)))
btlon    = tofloat(tostring(bt(storminds,37:43))) * -1.
bttime = cd_inv_calendar(YYYY,MM,DD,HH,mm,conform(mm,0,0),timeunits,cal)

;Read SFMR data files. Files that have been reprocessed
;using the 2015 algorithm all have NOAA or AFRC in their
;names. The SFMR directories have some of the non-
;reprocessed files, so we will exclude these by only
;reading the files with NOAA and AFRC in their names.
NOAAfiles = systemfunc("ls "+sfmrdir+"*NOAA*nc")
AFRCfiles = systemfunc("ls "+sfmrdir+"*AFRC*nc")
if(all(ismissing(NOAAfiles)))then
   sfmrfiles = AFRCfiles
elseif(all(ismissing(AFRCfiles)))then
   sfmrfiles = NOAAfiles
else
   sfmrfiles = array_append_record(NOAAfiles,AFRCfiles,0)
end if
nfiles_sfmr = dimsizes(sfmrfiles)
sfmrv   = new((/nfiles_sfmr,1000000/),"float")
sfmrlat = new((/nfiles_sfmr,1000000/),"float")
sfmrlon = new((/nfiles_sfmr,1000000/),"float")
sfmrtime= new((/nfiles_sfmr,1000000/),"integer")
do i=0,nfiles_sfmr-1
   print( "Reading SFMR file "+sfmrfiles(i))
   filename = sfmrfiles(i)
   sfmrdata = read_sfmr(filename,timeunits,cal)
   ntimes = dimsizes(sfmrdata[0])
   sfmrv   (i,:ntimes-1) = sfmrdata[0]
   sfmrlat (i,:ntimes-1) = sfmrdata[1]
   sfmrlon (i,:ntimes-1) = sfmrdata[2]
   sfmrtime(i,:ntimes-1) = sfmrdata[3]
end do

;Read flight-level data files
if(year.eq.2017)then
   system("ls "+fldir+"*H*1sec.txt > filelist")    ;Gets some NOAA P3 flight-level files
   system("ls "+fldir+"*H*01.txt >> filelist")     ;Gets rest of NOAA P3 flight-level files
   system("ls "+fldir+"*U*01.txt >> filelist")     ;Gets all USAF C130 flight-level files
elseif(year.eq.2016)then
   system("ls "+fldir+"*I*1sec.txt > filelist")    ;Gets some NOAA P3 flight-level files
   system("ls "+fldir+"*I*01.txt >> filelist")     ;Gets rest of NOAA P3 flight-level files
   system("ls "+fldir+"*U*01.txt >> filelist")     ;Gets all USAF C130 flight-level files
elseif(year.eq.2015)then
   system("ls "+fldir+"*I*1sec.txt > filelist")    ;Gets some NOAA P3 flight-level files
   system("ls "+fldir+"*U*01.txt >> filelist")     ;Gets all USAF C130 flight-level files
end if

flfiles = systemfunc("cat filelist")
nfiles_fl = dimsizes(flfiles)
flvbig   = new((/nfiles_fl,1000000/),"float")
fllatbig = new((/nfiles_fl,1000000/),"float")
fllonbig = new((/nfiles_fl,1000000/),"float")
flaltbig = new((/nfiles_fl,1000000/),"float")
flheadbig= new((/nfiles_fl,1000000/),"integer")
flpresbig= new((/nfiles_fl,1000000/),"float")
;sfmrvbig = new((/nfiles_fl,1000000/),"float")
fltimebig= new((/nfiles_fl,1000000/),"integer")
flvbig@_FillValue = -9999.
;sfmrvbig@_FillValue = -9999.
do i=0,nfiles_fl-1
   print( "Reading flight-level file "+flfiles(i))
   filename = flfiles(i)
   fldata = read_flight_level(filename,timeunits,cal)
   ntimes = dimsizes(fldata[0])
   flvbig   (i,:ntimes-1) = (/fldata[0]/)     
   fllatbig (i,:ntimes-1) = (/fldata[1]/)     
   fllonbig (i,:ntimes-1) = (/fldata[2]/)     
   flaltbig (i,:ntimes-1) = (/fldata[3]/)     
   flheadbig(i,:ntimes-1) = (/fldata[4]/)     
   flpresbig(i,:ntimes-1) = (/fldata[5]/)
;   sfmrvbig (i,:ntimes-1) = (/fldata[6]/)
   fltimebig(i,:ntimes-1) = (/fldata[7]/)
end do

;Copy variable metadata
copy_VarAtts(fldata[0],flvbig)
copy_VarAtts(fldata[1],fllatbig)
copy_VarAtts(fldata[2],fllonbig)
copy_VarAtts(fldata[3],flaltbig)
copy_VarAtts(fldata[4],flheadbig)
copy_VarAtts(fldata[5],flpresbig)
;copy_VarAtts(fldata[6],sfmrvbig)
copy_VarAtts(fldata[7],fltimebig)

;Reduce size of arrays by chopping off trailing missing values.
maxindex = new(nfiles_fl,"integer")
do i=0,nfiles_fl-1
   maxindex(i) = max(ind(.not.ismissing(fltimebig(i,:))))
end do
flv   = new((/nfiles_fl,max(maxindex)+1/),"float")
fllat = new((/nfiles_fl,max(maxindex)+1/),"float")
fllon = new((/nfiles_fl,max(maxindex)+1/),"float")
flalt = new((/nfiles_fl,max(maxindex)+1/),"float")
flhead= new((/nfiles_fl,max(maxindex)+1/),"integer")
flpres= new((/nfiles_fl,max(maxindex)+1/),"float")
;sfmrv = new((/nfiles_fl,max(maxindex)+1/),"float")
fltime= new((/nfiles_fl,max(maxindex)+1/),"integer")
do i=0,nfiles_fl-1
   flv   (i,0:maxindex(i)) = flvbig   (i,0:maxindex(i))
   fllat (i,0:maxindex(i)) = fllatbig (i,0:maxindex(i))
   fllon (i,0:maxindex(i)) = fllonbig (i,0:maxindex(i))
   flhead(i,0:maxindex(i)) = flheadbig(i,0:maxindex(i))
   flalt (i,0:maxindex(i)) = flaltbig (i,0:maxindex(i))
   flpres(i,0:maxindex(i)) = flpresbig(i,0:maxindex(i))
;   sfmrv (i,0:maxindex(i)) = sfmrvbig (i,0:maxindex(i))
   fltime(i,0:maxindex(i)) = fltimebig(i,0:maxindex(i))
end do
flv@_FillValue = -9999.
flalt@_FillValue = -9999.
flpres@_FillValue = -9999.
sfmrv@_FillValue = -9999.

;Replace nans with missing values
replace_ieeenan(flv,flv@_FillValue,0)
;replace_ieeenan(flalt,flalt@_FillValue,0)
;replace_ieeenan(flpres,flpres@_FillValue,0)
;replace_ieeenan(sfmrv,sfmrv@_FillValue,0)

;Replace negative headings with missing values (should never have negative headings)
flhead = where(flhead.lt.0,flhead@_FillValue,flhead)

;Determine times of beginning and ending of flight legs and print to ASCII file
do i=0,nfiles_sfmr-1
   if(all(ismissing(sfmrv(i,:))))then
      print( "NO SFMR DATA AVAILABLE FOR THIS FLIGHT")
      continue
   end if
   ;Find the flight-level data file that corresponds to this SFMR file
   sfmrfilename = systemfunc("echo "+sfmrfiles(i)+" | awk -F'/' '{print $NF}'")
   sfmrYYMMDD   = systemfunc("echo "+sfmrfilename+" | cut -c10-17")
   sfmrflightid =  systemfunc("echo "+sfmrfilename+" | cut -c18-19")
   flfilename = systemfunc("ls "+fldir+sfmrYYMMDD+sfmrflightid+".01.txt")
   fileind = ind(flfiles.eq.flfilename)
   if(ismissing(fileind))then
      flfilename = systemfunc("ls "+fldir+sfmrYYMMDD+sfmrflightid+".1sec.txt")
   end if
   fileind = ind(flfiles.eq.flfilename)
   if(ismissing(fileind))then
      print( "NO FLIGHT-LEVEL FILES AVAILABLE FOR THIS SFMR FILE")
      continue
   end if
   if(all(ismissing(flv(fileind,:))))
      print( "NO FLIGHT-LEVEL WIND SPEED DATA AVAILABLE FOR THIS FLIGHT")
      continue
   end if
   flight_legs(flfiles(fileind),fltime(fileind,:),flhead(fileind,:),fllat(fileind,:),\
               fllon(fileind,:),flpres(fileind,:),flalt(fileind,:),flv(fileind,:),\
               sfmrtime(i,:),sfmrlat(i,:),sfmrlon(i,:),sfmrv(i,:),ascdir,timeunits,\
               names,btlat,btlon,bttime)
end do

return(1)
end

;
;;Plot map of flight-level wind speed 
;
;
;
;
;
;
;;Replace all 0 flight-level values with missing values to avoid divide by zero errors
;flv = where(flv.eq.0,flv@_FillValue,flv)
;
;;Loop through pressure bins and compute wind speed ratio for each bin.
;bincenters = ispan(275,1025,bindepth)
;nbins = dimsizes(bincenters)
;halfbin = 0.5*bindepth
;ratios = new((/nfiles,nbins,100000/),"float")
;pressures = new((/nfiles,nbins,100000/),"float")
;nobs = new((/nfiles,nbins/),"integer")
;do i=0,nfiles-1
;   unixi = i + 1
;   print( "Processing flight "+unixi+" of "+nfiles)
;   do j=0,nbins-1
;      binbot = bincenters(j) - halfbin
;      bintop = bincenters(j) + halfbin
;      bininds := ind(flpres(i,:).ge.binbot.and.flpres(i,:).lt.bintop)
;      if(.not.all(ismissing(bininds)))
;         flvbin   := flv(i,bininds)
;         sfmrvbin := sfmrv(i,bininds)
;         nobs(i,j) = dimsizes(flvbin)
;         ratios(i,j,:nobs(i,j)-1) = sfmrvbin/flvbin
;         pressures(i,j,:nobs(i,j)-1) = bincenters(j)
;      end if
;   end do
;end do
;
;ratios_nobin = sfmrv/flv
;
;;Subsample time array for plotting. Subsample to 1-h intervals
;;to use as horizontal axis labels.
;fltimesub = fltime(:,::3600)
;copy_VarMeta(fltime,fltimesub)
;
;;Make plots for each flight
;wks = new(nfiles,"graphic")
;altplot   = new(nfiles,"graphic")
;flvplot   = new(nfiles,"graphic")
;presplot  = new(nfiles,"graphic")
;sfmrvplot = new(nfiles,"graphic")
;do i=0,nfiles-1
;   unixi = i + 1
;   print( "Drawing plot "+unixi+" of "+nfiles+" to "+imgdir+flfiles(i)+".png")
;   ;Get time strings for plotting
;   timestr := cd_string(fltimesub(i,:),"%H UTC")
;   filename_trim = systemfunc("echo "+flfiles(i)+" | awk -F'/' '{print $NF}'")
;   wks(i) = gsn_open_wks("png",imgdir+filename_trim)
;   res = True
;   res@gsnLeftString = "Aircraft Altitude" 
;   res@tiXAxisString = "Time"
;   res@tiYAxisString = "Altitude [m]"
;   res@tmXBMode = "Explicit"
;   res@tmXBValues = fltimesub(i,:)
;   res@tmXBLabels = timestr
;   res@tmXBLabelFontHeightF = .015
;   res@tmXBLabelAngleF = 40.
;   res@trYMinF = 0.
;   res@trXMinF = min(fltime(i,:))
;   res@trXMaxF = max(fltime(i,:))
;   res@tmYROn = False
;   res@tmXTOn = False
;   res@gsnDraw = False
;   res@gsnFrame = False
;   altplot(i)  = gsn_csm_xy(wks(i),fltime(i,:),flalt(i,:),res)
;   res@gsnLeftString = "Flight-level wind speed"
;   res@tiYAxisString = "Wind speed (m s~S~-1~N~)"
;   flvplot(i) = gsn_csm_xy(wks(i),fltime(i,:),flv(i,:),res)
;   res@gsnLeftString = "Flight-level pressure"
;   res@tiYAxisString = "Pressure (hPa)"
;   res@trYMinF = 400.
;   presplot(i) = gsn_csm_xy(wks(i),fltime(i,:),flpres(i,:),res)
;   res@gsnLeftString = "SFMR wind speed"
;   res@tiYAxisString = "Wind speed (m s~S~-1~N~)"
;   res@trYMinF = 0.
;   sfmrvplot(i) = gsn_csm_xy(wks(i),fltime(i,:),sfmrv(i,:),res)
;   panelres = True
;   panelres@gsnPanelMainString = filename_trim
;   gsn_panel(wks(i),(/altplot(i),flvplot(i),presplot(i),sfmrvplot(i)/),(/2,2/),panelres)
;end do
;
;;Draw scatterplot of ratios for all flights
;delete(wks)
;wks = gsn_open_wks("png",imgdir+"ratio-scatter-allflights.png")
;scatres = True
;;scatres@tiYAxisString = "Ratio (Flight-Level Wind Speed / SFMR Wind Speed)"
;scatres@tiYAxisString = "Ratio (SFMR Wind Speed / Flight-Level Wind Speed)"
;scatres@tiXAxisString = "Aircraft flight level (hPa)"
;scatres@tiXAxisFontHeightF = 0.02
;scatres@tiYAxisFontHeightF = 0.02
;scatres@tmXBLabelFontHeightF = .015
;scatres@tmYLLabelFontHeightF = .015
;scatres@xyMarkLineMode = "Markers"
;scatres@tmYROn = False
;scatres@tmXTOn = False
;scatplot = gsn_csm_xy(wks,ndtooned(flpres),ndtooned(ratios_nobin),scatres)
;;Plot number of observations in each flight-level bin
;Xaxislabels = (/"250-300","300-350","350-400","400-450","450-500","500-550","550-600","600-650",\
;                "650-700","700-750","750-800","800-850","850-900","900-950","950-1000","1000-1050"/)
;wks = gsn_open_wks("png",imgdir+"nobs-allflights.png")
;nobres = scatres
;nobres@tiYAxisString = "Number of Observations"
;nobres@xyMarkLineMode = "Lines"
;nobres@xyLineThicknessF = 5.
;;nobres@trXMinF = 400.
;;nobres@trXMaxF = 1000.
;nobres@tmXBMode = "Explicit"
;nobres@tmXBValues = bincenters
;nobres@tmXBLabels = Xaxislabels
;nobres@tmXBLabelAngleF = 40.
;nobres@tmXTOn = True
;plot = gsn_csm_xy(wks,bincenters,toint(dim_sum_n(nobs,0)),nobres)
;
;print( nobs)
