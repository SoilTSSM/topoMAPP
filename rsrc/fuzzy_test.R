# fuzzy texst
> dat=gridmaps@data
> str(dat)
'data.frame':	6072750 obs. of  4 variables:
 $ asp    : num  NA NA NA NA NA NA NA NA NA NA ...
 $ ele    : num  999 994 991 988 986 984 986 986 989 988 ...
 $ slp    : num  NA NA NA NA NA NA NA NA NA NA ...
 $ surface: num  0 0 0 0 0 0 0 0 0 0 ...
> dat=na.omit(gridmaps@data)
> str(dat)
'data.frame':	6062856 obs. of  4 variables:
 $ asp    : num  345 353 354 350 348 348 353 353 348 343 ...
 $ ele    : num  995 996 996 998 1001 ...
 $ slp    : num  9 17 23 29 33 35 35 35 35 35 ...
 $ surface: num  0 0 0 0 0 0 0 0 0 0 ...
 - attr(*, "na.action")=Class 'omit'  Named int [1:9894] 1 2 3 4 5 6 7 8 9 10 ...
  .. ..- attr(*, "names")= chr [1:9894] "1" "2" "3" "4" ...
> dat = FKM(X=dat,k=50 )
^C^C^C
^C
^C
> 
> Terminated


