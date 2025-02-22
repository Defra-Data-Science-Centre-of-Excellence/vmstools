#' Find tacsat records close to observation data records
#' 
#' Find the tacsat records that are close in distance or on a defined grid to
#' the observation data positions in both time and space
#' 
#' Returned is a list with the first element being the observation dataset with
#' an GR_ID identifier that matches the GR_ID from the matching tacsat records.
#' The second element is the tacsat records with the same GR_IDs.
#' 
#' @param tacsat Dataframe of vessel VMS in tacsat format
#' @param obs Dataframe also in tacsat format, but with observation data (GPS
#' and Date+Time)
#' @param method 'Grid' or 'Euclidian'. Match tacsat records in same gridcell
#' (method = "grid") or only x km from observed datapoint (method =
#' "euclidean")
#' @param control.grid If method = "grid", control.grid is a list with
#' specification of the grid (of class "sf") or the
#' resolution in x and y values where the outermargins can be given by the
#' tacsat dataset (gridBox="tacsat") or the observation dataset
#' (gridBox="obs").
#' 
#' Example: control.grid=list(spatGrid = NULL, resx = c(0.5,1), resy = NULL,
#' gridBbox = "obs")
#' @param control.euclidean If method = "euclidean" then a maximum distance the
#' tacsat position may deviate from the observed datapoint needs to be given
#' (in km).
#' @param temporalRange The range in which tacsat records may deviate from the
#' observation time stamp (in minutes)
#' @param all.t If you want to return all tacsat records, all.t=T (return =
#' list, first element = observation set, second = matching tacsat), else F
#' second = all tacsat
#' @param rowSize To speed up calculations, define maximum rowSize (default =
#' 1000)
#' @author Niels T. Hintzen
#' @references EU Lot 2 project
#' @examples
#' 
#' data(tacsat)
#' tacsat        <- sortTacsat(tacsat)
#' 
#' obs           <- tacsat[round(seq(1,nrow(tacsat),length.out=30)),]
#' obs           <- obs[,c(1,2,3,4,5,6)]
#' obs$OB_TYP    <- "Benthos"
#' colnames(obs) <- c("OB_COU","OB_REF","SI_LATI","SI_LONG","SI_DATE","SI_TIME","OB_TYP")
#' newTime       <- obs$SI_DATIM - runif(30,-60*20,60*20)
#' obs$SI_LATI   <- jitter(obs$SI_LATI,factor=0.25)
#' obs$SI_LONG   <- jitter(obs$SI_LONG,factor=0.5)
#' 
#' 
#' a <- clipObs2Tacsat(tacsat,obs,method="grid",control.grid=list(resx=0.1,resy=0.05,
#'                     gridBbox="obs"),temporalRange=c(-30,120),all.t=FALSE)
#' a <- clipObs2Tacsat(tacsat,obs,method="euclidean",control.euclidean=list(threshold=1),
#'                     temporalRange=c(-1e10,-1) ,all.t=FALSE)
#' 
#' @export clipObs2Tacsat
clipObs2Tacsat <- function(tacsat,        #The tacsat dataset
                           obs,           #The observation dataset
                           method="grid", #The method used, on 'grid' or 'euclidean' distance
                           control.grid=list(spatGrid=NULL,resx=NULL,resy=NULL,gridBbox="obs"), #gridBbox: whether bounding box should come from tacsat or observations
                           control.euclidean=list(threshold=NULL), #all.t = all.tacsat
                           temporalRange=NULL,#The range in which tacsat records may deviate from the observation time stamp
                           all.t=FALSE,
                           rowSize=1000
                           ){
require(sf)
tacsat      <- sortTacsat(tacsat)
obs         <- sortTacsat(obs)

#- If you want to get the full tacsat dataset back, make a copy of it first
if(all.t){
  tacsat$ID   <- 1:nrow(tacsat)
  tacsatOrig  <- tacsat
}

if(!"SI_DATIM" %in% colnames(tacsat)) tacsat$SI_DATIM   <- as.POSIXct(paste(tacsat$SI_DATE, tacsat$SI_TIME, sep=" "), tz="GMT", format="%d/%m/%Y  %H:%M")
if(!"SI_DATIM" %in% colnames(obs))    obs$SI_DATIM      <- as.POSIXct(paste(obs$SI_DATE,    obs$SI_TIME,    sep=" "), tz="GMT", format="%d/%m/%Y  %H:%M")

#- Subset tacsat that can never have match with obs because of temporal or space ranges
if(method == "euclidean" & is.null(control.euclidean$threshold)==FALSE){
  rix         <- km2Degree(range(obs$SI_LONG,na.rm=TRUE)[1],range(obs$SI_LATI,na.rm=TRUE)[1],control.euclidean$threshold)
  minXobs     <- range(obs$SI_LONG,na.rm=TRUE)[1] - rix
  raiy        <- control.euclidean$threshold/111.1949
  minYobs     <- range(obs$SI_LATI,na.rm=TRUE)[1] - raiy
  rax         <- km2Degree(range(obs$SI_LONG,na.rm=TRUE)[2],range(obs$SI_LATI,na.rm=TRUE)[2],control.euclidean$threshold)
  maxXobs     <- range(obs$SI_LONG,na.rm=TRUE)[2] + rax
  maxYobs     <- range(obs$SI_LATI,na.rm=TRUE)[2] + raiy
  tacsat      <- subset(tacsat,SI_LONG >= minXobs & SI_LONG <= maxXobs & SI_LATI >= minYobs & SI_LATI <= maxYobs)
}
if(method == "grid"){
  minXobs     <- range(obs$SI_LONG,na.rm=TRUE)[1] - control.grid$resx
  maxXobs     <- range(obs$SI_LONG,na.rm=TRUE)[2] + control.grid$resx
  minYobs     <- range(obs$SI_LATI,na.rm=TRUE)[1] - control.grid$resy
  maxYobs     <- range(obs$SI_LATI,na.rm=TRUE)[2] + control.grid$resy
  tacsat      <- subset(tacsat,SI_LONG >= minXobs & SI_LONG <= maxXobs & SI_LATI >= minYobs & SI_LATI <= maxYobs)
}

if(is.null(temporalRange)==FALSE){
  minTobs     <- range(obs$SI_DATIM,na.rm=TRUE)[1] + temporalRange[1]*60
  maxTobs     <- range(obs$SI_DATIM,na.rm=TRUE)[2] + temporalRange[2]*60
  tacsat      <- subset(tacsat,SI_DATIM >= minTobs & SI_DATIM <= maxTobs)
}
if(nrow(tacsat)==0) stop("Number of tacsat records that are within reach of obs dataset is zero")


#- Gridcell wanted, but not given yet, so create one
if(method == "grid" & is.null(control.grid$spatGrid) == TRUE){
  if(is.null(control.grid$resx) == TRUE | is.null(control.grid$resy) == TRUE) stop("Method selected needs resx and resy statements")

  xrangeO      <- range(obs$SI_LONG,na.rm=TRUE); xrangeT <- range(tacsat$SI_LONG,na.rm=TRUE)
  yrangeO      <- range(obs$SI_LATI,na.rm=TRUE); yrangeT <- range(tacsat$SI_LATI,na.rm=TRUE)
  
  if(control.grid$gridBbox == "obs")     spatGrid    <- createGrid(xrangeO,yrangeO,control.grid$resx,control.grid$resx)
  if(control.grid$gridBbox == "tacsat")  spatGrid    <- createGrid(xrangeT,yrangeT,control.grid$resy,control.grid$resy)
  control.grid$spatGrid                              <- spatGrid
}

#- Perform calculations on gridcell
if(method == "grid" & is.null(control.grid$spatGrid) == FALSE){

  sPDFObs     <- st_as_sf(obs,coords=c("SI_LONG","SI_LATI"))
  sPDFTac     <- st_as_sf(tacsat,coords=c("SI_LONG","SI_LATI"))
   

  resObs      <- sapply(st_intersects(sPDFObs,spatGrid), function(z) if (length(z)==0) NA_integer_ else z[1])
  resTac      <- sapply(st_intersects(sPDFTac,spatGrid), function(z) if (length(z)==0) NA_integer_ else z[1]) 
  

  idxObs      <- st_coordinates(st_centroid(spatGrid))[resObs,]
  idxTac      <- st_coordinates(st_centroid(spatGrid))[resTac,]  
  
  obs$GR_LONG     <- idxObs[,1];  obs$GR_LATI     <- idxObs[,2]
  tacsat$GR_LONG  <- idxTac[,1];  tacsat$GR_LATI  <- idxTac[,2]

  tacsat$GR_ID<- resTac;
  obs$GR_ID   <- resObs;

  
  if(is.null(temporalRange)==FALSE){

    res       <- do.call(c,lapply(as.list(1:nrow(obs)),function(x){     res        <- which(resTac == resObs[x]);
                                                                        restime    <- difftime(tacsat$SI_DATIM[res],obs$SI_DATIM[x],units="mins");
                                                                        #retrn      <- ifelse(restime <= temporalRange[2] & restime >=temporalRange[1],resObs[x],NA)
                                                                        retrn      <- which(restime <= temporalRange[2] & restime >= temporalRange[1])
                                                       return(res[retrn])}))


    retrn       <- list(obs,tacsat[res,])
  } else {
      retrn       <- list(obs,tacsat)
    }
}

#- Perform calculation by Euclidian distance
if(method == "euclidean"){

  obs$GR_ID   <- 1:nrow(obs)

  #- Create storage of tacsat records to save
  totRes      <- cbind(numeric(), numeric())

  obsLon      <- obs$SI_LONG
  obsLat      <- obs$SI_LATI
  tacLon      <- tacsat$SI_LONG
  tacLat      <- tacsat$SI_LATI

  #- Chop it up into pieces to speed up the calculations
  nChunkObs   <- ceiling(nrow(obs)    /rowSize)
  nChunkTac   <- ceiling(nrow(tacsat) /rowSize)
  for(iNO in 1:nChunkObs){
    if(iNO == nChunkObs){
      ox <- obsLon[(iNO*rowSize - rowSize + 1):length(obsLon)]
      oy <- obsLat[(iNO*rowSize - rowSize + 1):length(obsLat)]
    } else {
        ox <- obsLon[(iNO*rowSize - rowSize + 1):(iNO*rowSize)]
        oy <- obsLat[(iNO*rowSize - rowSize + 1):(iNO*rowSize)]
      }
    for(iNT in 1:nChunkTac){
      if(iNT == nChunkTac){
        tx <- tacLon[(iNT*rowSize - rowSize + 1):length(tacLon)]
        ty <- tacLat[(iNT*rowSize - rowSize + 1):length(tacLat)]
      } else {
          tx <- tacLon[(iNT*rowSize - rowSize + 1):(iNT*rowSize)]
          ty <- tacLat[(iNT*rowSize - rowSize + 1):(iNT*rowSize)]
        }

      minXobs     <- range(ox,na.rm=TRUE)[1] - rix
      minYobs     <- range(oy,na.rm=TRUE)[1] - raiy
      maxXobs     <- range(ox,na.rm=TRUE)[2] + rax
      maxYobs     <- range(oy,na.rm=TRUE)[2] + raiy
      cont        <- ifelse(length(which(tx >= minXobs & tx <= maxXobs & ty >= minYobs & ty <= maxYobs))>0,TRUE,FALSE)

      if(cont){

      #- Check if the length of both sets are equal or not
      if(iNO == nChunkObs | iNT == nChunkTac){

        #- Get both the minimum distance, but also the index of the tacsat record associated
        res                                                   <- do.call(rbind,
                                                                         lapply(as.list(1:length((iNO*rowSize - rowSize +1):ifelse(iNO == nChunkObs,length(obsLon),(iNO*rowSize)))),
                                                                                function(x){
                                                                                    #- Get the row numbers of the full observation and tacsat set used here
                                                                                    obsRows     <- (iNO*rowSize - rowSize +1):ifelse(iNO == nChunkObs,length(obsLon),(iNO*rowSize))
                                                                                    if(length(tx)<rowSize){  tacRows <- ((iNT*rowSize - rowSize + 1):(length(tacLon))) } else { tacRows <- ((iNT*rowSize - rowSize + 1):(iNT*rowSize))}

                                                                                    #- Calculate the distance between the observation and tacsat dataset
                                                                                    distObsTac  <- distance(ox[x],oy[x],tx,ty);
                                                                                    if(is.null(control.euclidean$threshold)==FALSE){ idx <- which(distObsTac <= control.euclidean$threshold)} else { idx <- 1:length(distObsTac) }

                                                                                    restime     <- difftime(tacsat$SI_DATIM[tacRows[idx]],obs$SI_DATIM[obsRows[x]],units="mins")
                                                                                    if(is.null(temporalRange)==FALSE){ retrn       <- which(restime <= temporalRange[2] & restime >= temporalRange[1])
                                                                                    } else { retrn <- 1:length(restime) }
                                                                                    if(length(tacRows[idx[retrn]])>0){ toReturn <- cbind(tacRows[idx[retrn]],obs$GR_ID[obsRows[x]])
                                                                                    } else { toReturn <- cbind(NA,NA) }

                                                                                return(toReturn)}))



        totRes  <- rbind(totRes,na.omit(res))
      }
      if(iNO != nChunkObs & iNT != nChunkTac){

       obsRows            <- ((iNO*rowSize - rowSize +1):(iNO*rowSize))
       tacRows            <- (((iNT*rowSize - rowSize + 1):(iNT*rowSize)))
       res                <- outer(1:rowSize,1:rowSize,FUN=
                                   function(x,y){
                                      distObsTac  <- distance(ox[x],oy[x],tx[y],ty[y])
                                   return(distObsTac)})

       idx              <- apply(res,2,function(x){return(x <= control.euclidean$threshold)})
       idx              <- which(idx == TRUE,arr.ind=TRUE)
       restime          <- difftime(tacsat$SI_DATIM[tacRows[idx[,2]]],obs$SI_DATIM[obsRows[idx[,1]]],units="mins")

       if(is.null(temporalRange)==FALSE){ retrn       <- which(restime <= temporalRange[2] & restime >= temporalRange[1])
       } else { retrn <- 1:length(restime) }
       if(length(retrn)>0){
         res              <- cbind(tacRows[idx[retrn,2]],obs$GR_ID[obsRows[idx[retrn,1]]])
         totRes           <- rbind(totRes,na.omit(res))
       }
      }
    }
      
    }#End iNT loop
  }#End iNO loop
  tacsat$GR_ID    <- NA
  dubTacsat       <- tacsat[totRes[,1],]
  dubTacsat$GR_ID <- totRes[,2]


  retrn   <- list(obs,dubTacsat)
}#End method euclidean

if(all.t) retrn[[2]] <- merge(retrn[[2]],tacsatOrig,by=colnames(tacsatOrig),all=TRUE)

return(retrn)}
