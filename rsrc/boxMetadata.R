#====================================================================
# SETUP
#====================================================================
#INFO

#DEPENDENCY
require(raster)
require(ncdf4)

#SOURCE
source('./rsrc/tscale_src.R')
#====================================================================
# PARAMETERS/ARGS
#====================================================================
args = commandArgs(trailingOnly=TRUE)
wd=args[1] #
nbox=as.numeric(args[2])
#gridEle=args[3]
#====================================================================
# PARAMETERS FIXED
#====================================================================

#**********************  SCRIPT BEGIN *******************************


########################################################################################################
#
#			TOPOSCALE SWin
#
########################################################################################################
#===========================================================================
#				SETUP
#===========================================================================
# wd<-getwd()
# root=paste(wd,'/',sep='')
# parfile=paste(root,'/src/TopoAPP/parfile.r', sep='')
# source(parfile) #give nbox and epath packages and functions
# nbox<-nboxSeq
# simindex=formatC(nbox, width=5,flag='0')
# spath=paste(epath,'/result/B',simindex,sep='') #simulation path

# setup=paste(root,'/src/TopoAPP/expSetup1.r', sep='')
# source(setup) #give tFile outRootmet

#===========================================================================
#				COMPUTE POINTS META DATA - eleDiff, gridEle, Lat, Lon 
#===========================================================================
setwd(wd)
file='../eraDat/SURF.nc'
nc=nc_open(file)
mf=read.csv('listpoints.txt')
npoints=length(mf$ele)
eraBoxEle=read.table('../eraEle.txt',sep=',', header=FALSE)[,1]

#=======================================================================================================
#			Get correct NBOX
#=======================================================================================================
ex = raster('../spatial/eraExtent.tif')
rst = raster(file)
values(rst) <- 1:ncell(rst)
n = crop(rst,ex)
vec = getValues(n)
# convert nbox from eraExtent eg 2 to nbox from ERA download
nbox1 = vec[nbox] # nbox position in original downloaded era extent !!nb: OLD LARGER EXTENT!!
nbox2 = nbox # nbox position in new cropped extent !!nb: NEW SMALLER EXTENT!!
#=======================================================================================================


#find ele diff station/gidbox
#eraBoxEle<-getEraEle(dem=eraBoxEleDem, eraFile=tFile) # $masl
gridEle<-rep(eraBoxEle[nbox2],length(mf$ele)) #!!nb: NEW SMALLER EXTENT!!
mf$gridEle<-round(gridEle,2)
eleDiff=mf$ele-mf$gridEle
mf$eleDiff<-round(eleDiff,2)
#get grid coordinates
coordMap=getCoordMap(file)
x<-coordMap$xlab[nbox1] # long cell !!nb: OLD LARGER EXTENT!!
y<-coordMap$ylab[nbox1]# lat cell !!nb: OLD LARGER EXTENT!!

#get long lat centre point of nbox (for solar calcs)
lat=ncvar_get(nc, 'latitude')
lon=ncvar_get(nc, 'longitude')
latn=lat[y]
lonn=lon[x]
mf$boxlat=rep(latn,length(mf$ele))
mf$boxlon=rep(lonn,length(mf$ele))

write.csv(mf, 'listpoints.txt', row.names=FALSE)

