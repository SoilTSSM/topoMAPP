# dependency
source("./rsrc/PBS.R")
require(foreach)
require(doParallel)
require(raster)

args = commandArgs(trailingOnly = TRUE)
wd = args[1]
priorwd = args[2]
grid = as.numeric(args[3])
nens = as.numeric(args[4])
Nclust = as.numeric(args[5])
sdThresh = as.numeric(args[6])
R = as.numeric(args[7])
cores = as.numeric(args[8])
DSTART = as.numeric(args[9])
DEND = as.numeric(args[10])
year = as.numeric(args[11])
startdaLong = args[12]
enddaLong = args[13]
startSim = args[14]
endSim = args[15]
valshp=args[16]
valMode=args[17]
# ======== code ===================

print( paste0("valMode:", valMode) )

# setup logs
sink(paste0(wd, "/da_logfile"), append = TRUE)

# rstack and ensembRes are both now cut to the hydro year in the 'year' loop
print(paste0("Running PBSpixel from ", startdaLong, " to ", enddaLong))

# readin data
landform = raster(paste0(priorwd, "/grid", grid, "/landform.tif"))

# project to utm
landform_utm=projectRaster(from=landform, crs=crs(rstack))

rstack = brick(paste0(priorwd, "/fsca_stack.tif"))
obsTS = read.csv(paste0(priorwd, "/fsca_dates.csv"))

# remove HH:mm part of timestamp (yyyy-mm-dd HH:mm)-> datestamp (yyy-mm-dd)
startda <- substr(startdaLong, 1, 10)
endda <- substr(enddaLong, 1, 10)

fscacrop = paste0(wd, "/fsca_crop",grid,year,".tif")
if (!file.exists(fscacrop)) {

    # cut temporal length of dates vector to startda/endda
    #startda.index <- which(obsTS$x == startda)
    #endda.index <- which(obsTS$x == endda)

    # subset rstack temporally
    #print(paste0("subset rstack temporally:", startda," to ",endda))
    #rstack = rstack[[startda.index:endda.index]]

    # subset dates vector to current year
    #obsTScut <- obsTS$x[startda.index:endda.index]
    #write.csv(obsTScut, paste0(wd, "/fsca_dates_",year,".csv"), row.names = FALSE)


    # crop rstack to landform as landform represent individual grid and rstack the
    # entire domain - these are not necessarily the same

    print(paste0("crop fsca_stack.tif (",nlayers(rstack)," layers) with landform.tif"))
    rstack = crop(rstack, landform_utm)
    writeRaster(rstack, fscacrop, overwrite = TRUE)
    print("crop done")
} else {
    print(paste0(fscacrop, " already exists."))
    rstack <- stack(fscacrop)
}

# get pixel ids of val data
if (valMode == "TRUE"){
    print("Running in val mode")
    shp=shapefile(valshp)
    rtest <- rstack[[1]]
    values(rtest) <- 1: ncell(rtest)
    npix = sort(na.omit(extract(rtest, shp)))
    print(paste0("Validation data exists at pixels: ", npix))
} else{
    print("Running in normal (non-val) mode")
    # total number of MODIS pixels
    npix = ncell(rstack)
    print(paste0("Modis pixels in domain = ", npix))

    # make a vector
    npix <- 1:npix
}

# read and cut and write dates here
#dates <- read.csv(paste0(wd, "/fsca_dates.csv"))
#write.csv(dates, paste0(wd, "/fsca_dates.csv"), row.names = FALSE)

# output
outfile1 = paste0("wmat_", grid, year, ".rd")  #'wmat_trunc20.rd' 'HX.rd'#
outfile2 = paste0("HX_", grid, year, ".rd")

pixTS = paste0(wd, "/pixTS_", grid)
if (!file.exists(pixTS)) {

    # pixel based timeseries
    print("extract pixel based timeseries from rstack")
    t1 = Sys.time()
    pixTS = extract(rstack, 1:ncell(rstack))
    t2 = Sys.time() - t1
    print(t2)
    save(pixTS, file = paste0(wd, "/pixTS_", grid))

} else {
    print(paste0(pixTS, " already exists."))
    load(paste0(wd, "/pixTS_", grid))
}






# readin ensemble results matrix
load(paste0(wd, "/ensembRes_", grid, ".rd"))

# subset temporally
totalTS <- seq(as.Date(startSim), as.Date(endSim), 1)
start.index <- which(totalTS == startda)
end.index <- which(totalTS == endda)
ensembRes <- ensembRes[start.index:end.index, , ]
print(paste0("ensembRes cut to: ", startda, " to ", endda))

# convert swe to sca
ensembRes[ensembRes <= sdThresh] <- 0
ensembRes[ensembRes > sdThresh] <- 1
# ===============================================================================
# Compute melt period for year n by elevation
# ===============================================================================
t1 = Sys.time()
df = paste0(wd, "/df_", grid)

# subset rstack temporally

if (!file.exists(df)) {
    resol = 5
    print(paste0("Computing ", resol, " melt period elevation bands"))

    # resample dem to rstack res (MODIS)
    dem = raster(paste0(priorwd, "/predictors/ele.tif"))
    dem_utm=projectRaster(from=dem, crs=crs(rstack))
    elegrid = crop(dem_utm, landform_utm)
    r = aggregate(elegrid, res(rstack)/res(elegrid))
    rstack_ele <- resample(r, rstack)

    minZ = cellStats(elegrid, "min") - 1  #add buffer to allow use of 'greaterthan' on lower bound and not risk excluding a point at lowest ele.
    maxZ = cellStats(elegrid, "max")
    range = maxZ - minZ
    deltaZ = range/resol

    # meltList <- list()
    meltPeriod = c()
    for (i in 1:resol) {
        print(paste0("compute band: ", i))
        mStart = minZ + (deltaZ * (i - 1))
        mEnd = mStart + deltaZ

        pix = which(getValues(rstack_ele) > mStart & getValues(rstack_ele) <= mEnd)
        x = rstack[pix]  # mega slow function
        meanMelt = apply(x, FUN = "mean", MARGIN = 2, na.rm = T)

        vec <- meanMelt
        rvec = rev(vec)
        lastdata = which(rvec > 0)[1]  # last non-zero value
        lastdataindex = length(vec) - lastdata + 1
        firstnodata = lastdataindex
        lastdateover95 = length(vec) - which(rvec > (max(rvec, na.rm = TRUE) * 0.95))[1]  # last date over 95% of max value accounts for max below 100%
        start = NA
        end = NA
        mp = c(mStart, mEnd, start, end)
        meltPeriod = rbind(meltPeriod, mp)
    }
    df = data.frame(meltPeriod)
    names(df) <- c("ele1", "ele2", "start", "end")
    save(df, file = paste0(wd, "/df_", grid))

} else {

    print(paste0(df, " already exists."))
    load(paste0(wd, "/df_", grid))

    # resample dem to rstack res (MODIS)
    dem = raster(paste0(priorwd, "/predictors/ele.tif"))
    elegrid = crop(dem, landform)
    r = aggregate(elegrid, res(rstack)/res(elegrid))
    rstack_ele <- resample(r, rstack)
}



# pixel based timeseries
pixEle = getValues(rstack_ele)

t2 = Sys.time() - t1
print("Ele band computation done in: ")
print(t2)
# ===============================================================================
# Run pixel calcs in parallel - get WMAT need to combine wmat and HX calcs
# ===============================================================================

if (!file.exists(paste0(wd,"/",outfile1))) {

     system(paste0('rm ',wd, '/dopar.log'))
    t1 = Sys.time()
    cl <- makeCluster(cores, outfile=paste0(wd, '/dopar.log'))  # create a cluster with 2 cores
    registerDoParallel(cl)  # register the cluster


    #writeLines(c(""), "dopar.log")

    wmat = foreach(i = npix, .combine = "rbind", .packages = "raster") %dopar% {

        #print(i)
        ele = pixEle[i]
        lb = which(df$ele1 < ele)
        ub = which(df$ele2 >= ele)
        class = which(lb %in% ub)
        meltp = df[class, ]
        start = meltp$start
        end = meltp$end

        # Extract pixel based timesries of MODIS obs and scale
        obs = pixTS[i, ]/100

        # get melt period vec=pixTS[i,] rvec=rev(vec) lastdata = which(rvec>0)[1] # last
        # non-zero value lastdataindex = length(vec) - lastdata+1 firstnodata =
        # lastdataindex+1 lastdateover95 = length(vec) - which (rvec >(max(rvec,
        # na.rm=TRUE)*0.95))[1] # last date over 95% of max value accounts for max below
        # 100% start=lastdateover95 end=firstnodata

        if (!is.na(start) & !is.na(end) & start >= end) {

        }

        if (is.na(start)) {
            start = DSTART  #lastdateover95
        }

        if (is.na(end)) {
            end = DEND  #firstnodata
        }

        # set default here TRIAL start = DSTART end = DEND

        # identify missing dates and reset start end index
        obsind = which(!is.na(obs) == TRUE)

        # cut to start end points (melt season )
        obsind <- obsind[obsind >= start & obsind <= end]

        # if less than two obs are present then PBS fails, this function steps forward
        # though pixels already processed until at least 2 obs are found
        n = 1
        while (length(obsind) < 2) {

            obs <- pixTS[i + n, ]/100
            obsind <- which(!is.na(obs) == TRUE)
            obsind <- obsind[obsind >= start & obsind <= end]
            n <- n + 1
            #print(n)
            #print(i + n)
            if (n > 20) {
                start = DSTART  #lastdateover95
                end = DEND  #firstnodata
                next
            }

            # if algorithm, reaches last pixel search then goes backwards
            if ((i + n) == npix) {

                n = 1
                while (length(obsind) < 2) {

                    obs <- pixTS[i - n, ]/100
                    obsind <- which(!is.na(obs) == T)
                    obsind <- obsind[obsind >= start & obsind <= end]
                    n <- n + 1
                    #print(n)
                    #print(i - n)

                }
            }
        }

        # MODIS pixel,i mask
        singlecell = rasterFromCells(rstack[[1]], i, values = TRUE)

        # extract smallpix using mask
        smlPix = crop(landform, singlecell)

        # compute sample IDs that occur in MODIS pixel,i, this is ragged and varies
        # tri+-modally (sample of 4609) between eg.289, 272,256 (based on an experiment)
        sampids = values(smlPix)


        # ensemble loop init HX
        HX = c()
        for (j in 1:nens) {

            #print(j)
            # number of smallpix in MODIS pixel nsmlpix <- length(sampids)
            nsmlpix <- length(which(!is.na(sampids) == TRUE))


            # get unique sim ids
            simindexs <- unique(sampids[!is.na(sampids)])

            # number of unique samples in pixel
            nSamp <- length(simindexs)

            # number of NA's in pixel
            nNA = length(which(is.na(sampids) == TRUE))

            if (valMode == "TRUE"){
                simindexs = order(sort(simindexs))
                sampids = sort(sampids)
            }

            # extract vector of each sample sca that occurs in pixel
            mat <- ensembRes[, simindexs, j]

            # mat <- mat[1:length(obs),] # this has to be replaced by correct date matching

            # count occurance of each in sample
            tab <- as.data.frame(table(sampids))
            tabmat <- t(mat) * tab$Freq

            # fSCA for pixel i and ensemble j
            fsca = colSums(tabmat)/nsmlpix

            # append to ensemble matrix
            HX = cbind(HX, fsca)

        }

        # wmat = cbind(wmat,w) y=as.vector(HX) 
        # sink("dopar.log", append=TRUE)
        # cat(paste("% complete:", (i/npix) * 100,"  -  Starting wmat iteration", i, "\n"))
        print(paste("% complete WMAT:", (i/npix[length(npix)] * 100)))
        # sink()

        w = PBS(HX[obsind, ], obs[obsind], R)

    }

    t2 = Sys.time() - t1

    stopCluster(cl)  # shut down the cluster

    # write.csv(result, paste0(wd,'wmat.csv'))
    save(wmat, file = paste0(wd, outfile1))

    print(paste0("wmat calc took: ", t2, " to process ", npix[length(npix)], " MODIS pixels"))
} else {
    print(paste0(outfile1, " already exists."))

}
# ===============================================================================
# Run pixel calcs in parallel - get HX
# ===============================================================================
if (!file.exists(paste0(wd,"/",outfile2))) {
    t1 = Sys.time()
    cl <- makeCluster(cores,  outfile=paste0(wd, '/dopar.log'))  # create a cluster with 2 cores
    registerDoParallel(cl)  # register the cluster



    HX = foreach(i = npix, .combine = "rbind", .packages = "raster") %dopar% {

        #print(i)
        ele = pixEle[i]
        lb = which(df$ele1 < ele)
        ub = which(df$ele2 >= ele)
        class = which(lb %in% ub)
        meltp = df[class, ]
        start = meltp$start
        end = meltp$end
        # Extract pixel based timesries of MODIS obs and scale
        obs = pixTS[i, ]/100

        # get melt period vec=pixTS[i,] rvec=rev(vec) lastdata = which(rvec>0)[1] # last
        # non-zero value lastdataindex = length(vec) - lastdata+1 firstnodata =
        # lastdataindex+1 lastdateover95 = length(vec) - which (rvec >(max(rvec,
        # na.rm=TRUE)*0.95))[1] # last date over 95% of max value accounts for max below
        # 100% start=lastdateover95 end=firstnodata

        if (!is.na(start) & !is.na(end) & start >= end) {
            # start=DSTART#lastdateover95 end=DEND#firstnodata
        }

        if (is.na(start)) {
            start = DSTART  #lastdateover95
        }

        if (is.na(end)) {
            end = DEND  #firstnodata
        }

        # identify missing dates and reset start end index
        obsind = which(!is.na(obs) == TRUE)

        # cut to start end points (melt season )
        obsind <- obsind[obsind >= start & obsind <= end]

        # if less than two obs are present then PBS fails, this function steps forward
        # though pixels already processed until at least 2 obs are found
        n = 1
        while (length(obsind) < 2) {

            obs <- pixTS[i + n, ]/100
            obsind <- which(!is.na(obs) == TRUE)
            obsind <- obsind[obsind >= start & obsind <= end]
            n <- n + 1
            #print(n)
            #print(i + n)
            if (n > 20) {
                start = DSTART  #lastdateover95
                end = DEND  #firstnodata
                next
            }

            # if algorithm, reaches last pixel search then goes backwards
            if ((i + n) == npix) {

                n = 1
                while (length(obsind) < 2) {

                    obs <- pixTS[i - n, ]/100
                    obsind <- which(!is.na(obs) == T)
                    obsind <- obsind[obsind >= start & obsind <= end]
                    n <- n + 1
                    print(n)
                    print(i - n)

                }
            }
        }

        # MODIS pixel,i mask
        singlecell = rasterFromCells(rstack[[1]], i, values = TRUE)

        # extract smallpix using mask
        smlPix = crop(landform, singlecell)

        # compute sample IDs that occur in MODIS pixel,i, this is ragged and varies
        # tri+-modally (sample of 4609) between eg.289, 272,256 (based on an experiment)
        sampids = values(smlPix)


        # ensemble loop init HX
        HX = c()
        for (j in 1:nens) {

            #print(j)
            # number of smallpix in MODIS pixel nsmlpix <- length(sampids)
            nsmlpix <- length(which(!is.na(sampids) == TRUE))


            # get unique sim ids
            simindexs <- unique(sampids[!is.na(sampids)])

            # number of unique samples in pixel
            nSamp <- length(simindexs)

            # number of NA's in pixel
            nNA = length(which(is.na(sampids) == TRUE))

            if (valMode == "TRUE"){
            simindexs = order(sort(simindexs))
            sampids = sort(sampids)
            }
            # extract vector of each sample sca that occurs in pixel
            mat <- ensembRes[, simindexs, j]

            # mat <- mat[1:length(obs),] # this has to be replaced by correct date matching

            # count occurance of each in sample
            tab <- as.data.frame(table(sampids))
            tabmat <- t(mat) * tab$Freq

            # fSCA for pixel i and ensemble j
            fsca = colSums(tabmat)/nsmlpix

            # append to ensemble matrix
            HX = cbind(HX, fsca)

        }

        print(paste("% HX complete:", (i/npix[length(npix)]  * 100)))
        y = as.vector(HX)

        # sink('doparlog2.txt', append=TRUE)
        # cat(paste("Starting wmat iteration", i, "\n"))
        # cat(paste("% complete:", (i/npix) * 100, "\n"))
        # sink()

    }

    t2 = Sys.time() - t1

    stopCluster(cl)  # shut down the cluster


# write.csv(result, paste0(wd,'wmat.csv'))
save(HX, file = paste0(wd, outfile2))
} else {
    print(paste0(outfile2, " already exists."))
}
print(paste0("HX calc took: ", t2, " to process ", npix[length(npix)], " MODIS pixels"))

sink()
