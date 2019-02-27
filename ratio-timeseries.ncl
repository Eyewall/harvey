load "/usr/people/pduran/progs/ncl/harvey/read_sfmr.ncl"
load "/usr/people/pduran/progs/ncl/harvey/read_flight_level.ncl"
load "/usr/people/pduran/progs/ncl/harvey/flight_legs.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/contrib/cd_string.ncl"
;--------------------------------------------
; ratio-timeseries.ncl
; Patrick Duran
; 26 February 2019
;
; Reads in all ASCII files containing wind
; speed ratios and plots time series of the
; ratios for each storm.
;-------------------------------------------

year = 2017
storm = "bret"
imgdir = "/raid1/pduran/figures/ratios/"
ascdir = "/raid1/pduran/ascii/"+year+"/"+storm+"/"
maxdist = 15.  ;Aircraft must pass within this distance of storm center
               ;for the ratios from this leg to be used (km)
layertop = (/600,700,800/) ;Tops and bottoms of layers to stratify
layerbot = (/700,800,900/) ;the observations by.

system("mkdir "+imgdir)
system("mkdir "+imgdir+"/"+year)

;Read ASCII files
filenames = systemfunc("ls "+ascdir+"*txt")
nfiles = dimsizes(filenames)
time   = new((/nfiles,30/),integer)
pres   = new((/nfiles,30/),float)
ratio  = new((/nfiles,30/),float)
radius = new((/nfiles,30/),float)
do i=0,nfiles-1
   data := readAsciiTable(filenames(i),17,"float",7)
   data@_FillValue = -9999.
   datadims = dimsizes(data)
   ;We will use the time of the maximum surface wind observation
   ;as the time of the ratio for our purposes here.
   time  (i,0:datadims(0)-1) = toint(data(:,13))
   pres  (i,0:datadims(0)-1) = data(:,14)
   ratio (i,0:datadims(0)-1) = data(:,15)
   radius(i,0:datadims(0)-1) = data(:,16)
end do
timeunits = systemfunc("grep -i 'Time Units' "+filenames(0)+" | awk -F': ' '{print $NF}'")
time@units = timeunits

;Replace all ratios and times at which radius > maxdist with missing values
;time  = where(radius.gt.maxdist,time@_FillValue,time)
ratio = where(radius.gt.maxdist,ratio@_FillValue,ratio)

;Convert arrays to 1-D so we can do pressure stratification
times_1d = ndtooned(time)
pres_1d  = ndtooned(pres)
ratio_1d = ndtooned(ratio)
radius_1d= ndtooned(radius)

;Stratify by pressure level
times  = new((/dimsizes(layerbot),dimsizes(times_1d)/),"float")
ratios = new((/dimsizes(layerbot),dimsizes(ratio_1d)/),"float")
nvals  = new(dimsizes(layerbot),"integer")
times_all = new(dimsizes(times_1d),"float")
do i=0,dimsizes(layerbot)-1
   times(i,:)  = where(pres_1d.ge.layertop(i).and.pres_1d.lt.layerbot(i),times_1d,times_1d@_FillValue)
   ratios(i,:) = where(pres_1d.ge.layertop(i).and.pres_1d.lt.layerbot(i),ratio_1d,ratio_1d@_FillValue)
   nvals(i) = dimsizes(ind(.not.ismissing(ratios(i,:))))
   nonmissinginds := ind(.not.ismissing(times(i,:)))
   if(.not.all(ismissing(nonmissinginds)))then
      times_all(ind(.not.ismissing(times(i,:)))) = times(i,ind(.not.ismissing(times(i,:))))
   end if
end do 

;Subsample time array for plotting. Subsample to every 10th leg for storms
;that have a lot of samples and get nicely formatted time strings for X Axis
if(dimsizes(ind(.not.(ismissing(times_all)))).gt.20)then
   times_all_sub = times_all(::10)
else
   times_all_sub = times_all
end if
times_all_sub@units = timeunits
timestr = cd_string(times_all_sub,"%H UTC %D %c")

;Wind speed ratio scatterplot
filename = imgdir+"/"+year+"/"+storm+"-ratio-timeseries"
wks = gsn_open_wks("png",filename)
res = True
res@gsnLeftString = "Wind Speed Ratios for "+str_capital(storm)+" ("+year+")"
res@tiXAxisString = "Date/Time (UTC)"
res@tiYAxisString = "Wind Speed Ratio (SFMR / flight)"
res@tiXAxisFontHeightF = 0.02
res@tiYAxisFontHeightF = 0.02
res@xyMarkerThicknessF = 5.
res@xyMarkerSizeF = 10.
res@xyMarkerColors = (/"blue","orange","red"/)
res@xyMarkLineMode = "Markers"
res@pmLegendDisplayMode = "Always"
res@pmLegendSide = "Top"
res@pmLegendWidthF = 0.07
res@pmLegendHeightF = 0.07
res@lgLabelFontHeightF = 0.015
res@pmLegendParallelPosF = 0.82
res@pmLegendOrthogonalPosF = -0.05
res@xyExplicitLegendLabels = tostring(layertop)+"-"+tostring(layerbot)+" mb"
res@tmXBMode = "Explicit"
res@tmXBValues = times_all_sub
res@tmXBLabels = timestr
res@tmXBLabelFontHeightF = 0.01
res@tmYLLabelFontHeightF = 0.01
res@tmXBLabelAngleF = 45.
res@trXMinF = min(times)
res@trXMaxF = max(times)
res@trYMinF = 0
res@trYMaxF = max((/2,max(ratios)/))
res@tmXTOn = False
res@tmYROn = False
res@gsnDraw = False
res@gsnFrame = False
plot = gsn_csm_xy(wks,times,ratios,res)
lnres = True
lnres@gsLineColor = "black"
lnres@gsLineThicknessF = 6.
gsn_polyline(wks,plot,(/res@trXMinF,res@trXMaxF/),(/1,1/),lnres)
draw(plot)
frame(wks)

