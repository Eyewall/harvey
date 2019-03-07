load "/usr/people/pduran/progs/ncl/harvey/flight-level-to-sfmr.ncl"
;--------------------------------------------
; call-flight-level-to-sfmr.ncl
; Patrick Duran
; 05 March 2019
;-------------------------------------------

;years = (/2017,2016,2015,2014,2013,2012,2011,2010,2009,2008,2007,2006,2005,2004,2003,2002,2001,2000,1999,1998/)
;years = (/2017,2016,2015/)
;
;nyears = dimsizes(years)
;do i=0,nyears-1
;   btfile = "/raid1/pduran/best-tracks/ebtrk_atlc_"+years(i)+".txt_interpolated_1-minute"
;   storms := systemfunc("awk '{print $2}' "+btfile+" | uniq")
;   nstorms = dimsizes(storms)
;   do j=0,nstorms-1
;      dum = flight_level_to_sfmr(years(i),storms(j))
;   end do
;end do
dum = flight_level_to_sfmr(2017,"maria")
