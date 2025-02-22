#' Find interpolated points between two succeeding GPS datapoints
#' 
#' Method to find interpolated points between two succeeding Tacsat / GPS
#' datapoints. Two different methods can be applied: the cubic Hermite spline
#' method as developed in Hintzen et al. 2010 or an interpolation of a straight
#' line (on a x-y plane, not a sphere)
#' 
#' Interval: In most Tacsat datasets the succeeding datapoint can be found 1 or
#' 2 hours appart. This interval time should be specified here. Interval can
#' also be specified as e.g. 15 minutes if the Tacsat / GPS dataset allows
#' this. Margin: Hardly ever, the interval time is precise. To allow some
#' deviation from the 1 or 2 hour interval the margin can be adjusted.
#' 
#' The 'res' value defines the number of points to use to construct the
#' interpolation. Default = 100 which results in a high resolution
#' interpolation.
#' 
#' Params can be obtained from analyses (see Hintzen et al. 2010) or can be
#' varied to explore the differences. To interpolate only first value needs to
#' be specified and the speedtreshold needs to be given.
#' 
#' headingAdjustment can either be 0 or 1 in case the heading at the endpoint
#' does not represent the heading of the arriving vessel to that point but the
#' departing vessel. This is only of use when heading needs to be calculated
#' outside the GPS dataset where heading is calculated at the bearing between
#' two points. For the startpoint, the bearing is correct, for the endpoint
#' however, the heading is incorrect.
#' 
#' The object returned is a list. Each list item contains in the first row the
#' index of the succeeding Tacsat pionts interpolated. The second till last row
#' contain the x (first column) and y (second column) interpolated values. The
#' length of the list indicates the number of interpolations created.
#' 
#' @param tacsat Tacsat dataset with GPS points that need to be interpolated
#' @param interval Time in minutes between the succeeding datapoints
#' @param margin Deviation from specified interval to find succeeding
#' datapoints
#' @param res Number of points to use to create interpolation (including start
#' and end point), default = 100
#' @param method "cHs" for cubic Hermite spline or "SL" for Straight Line
#' interpolation, default = 0.2,20,0.2
#' @param params Params needed for cHs method, including the speed thresholds
#' used
#' @param headingAdjustment Parameter to adjust the choice of heading depending
#' on its own or previous point
#' @param fast If your machine holds enough RAM (4gig or more) than the fast
#' version runs 7x faster
#' @author Niels T. Hintzen
#' @seealso \code{\link{findEndTacsat}}, \code{\link{distance}},
#' \code{\link{lonLatRatio}}, \code{\link{plotInterpolation}},
#' \code{\link{sortTacsat}}, \code{\link{filterTacsat}}
#' @references Hintzen et al. 2010 Improved estimation of trawling tracks using
#' cubic Hermite spline interpolation of position registration data, EU lot 2
#' project
#' @examples
#' 
#'   #Load the Tacsat data
#' data(tacsat)
#' 
#'   #Sort the VMS data
#' tacsat     <- sortTacsat(tacsat)
#' tacsat     <- tacsat[1:1000,]
#' 
#'   #Filter the Tacsat data
#' tacsat     <- filterTacsat(tacsat,st=c(2,6),hd=NULL)
#' 
#'   #Interpolate the VMS data
#' interpolation <- interpolateTacsat(tacsat,interval=120,margin=10,res=100,
#'                                    method="cHs",params=list(fm=0.5,distscale=20,
#'                                    sigline=0.2,st=c(2,6)),headingAdjustment=0)
#' 
#' @export interpolateTacsat
`interpolateTacsat` <-
function(tacsat                          #VMS datapoints
                              ,interval=120             #Specify in minutes, NULL means use all points
                              ,margin=12                #Specify the margin in minutes that the interval might deviate in a search for the next point
                              ,res=100                  #Resolution of interpolation method (default = 100)
                              ,method="cHs"             #Specify the method to be used: Straight line (SL) of cubic Hermite spline (cHs)
                              ,params=list(fm=0.5,distscale=20,sigline=0.2,st=c(2,6))  #Specify the three parameters: fm, distscale, sigline, speedthreshold
                              ,headingAdjustment=0
                              ,fast=FALSE){

if(!"SI_DATIM" %in% colnames(tacsat)) tacsat$SI_DATIM     <- as.POSIXct(paste(tacsat$SI_DATE,  tacsat$SI_TIME,   sep=" "), tz="GMT", format="%d/%m/%Y  %H:%M")
tacsat$sort.int <- 1:nrow(tacsat)
tacsat    <- sortTacsat(tacsat)
if(any(diff(tacsat$sort.int)!=1)) stop("Sort tacsat first using 'sortTacsat'")
  #Start interpolating the data
if(!method %in% c("cHs","SL"))  stop("method selected that does not exist")

#-------------------------------------------------------------------------------
#Fast method or not
#-------------------------------------------------------------------------------
if(fast){
  #Interpolation only by vessel, so split tacsat up
  tacsat$ID <- 1:nrow(tacsat)
  splitTa   <- split(tacsat,tacsat$VE_REF)
  spltTaCon <- lapply(splitTa,function(spltx){
                  #Calculate time different between every record
                  dftimex <- outer(spltx$SI_DATIM,spltx$SI_DATIM,difftime,units="mins")
                  iStep   <- 1
                  connect <- list()
                  counter <- 1
                  #Loop over all possible combinations and store if a connection can be made
                  while(iStep <= nrow(spltx)){
                    endp <- which(dftimex[,iStep] >= (interval - margin) & dftimex[,iStep] <= (interval + margin))
                    if(length(endp)>0){
                      if(length(endp)>1) endp <- endp[which.min(abs(interval - dftimex[endp,iStep]))][1]
                      connect[[counter]]    <- c(iStep,endp)
                      counter               <- counter + 1
                      iStep                 <- endp
                    } else { iStep          <- iStep + 1}
                  }
                  #Return matrix of conenctions
                  return(do.call(rbind,connect))})

  if(method=="cHs") returnInterpolations <- unlist(lapply(as.list(names(unlist(lapply(spltTaCon,nrow)))),function(y){
                                              return(interCubicHermiteSpline(spltx=splitTa[[y]],spltCon=spltTaCon[[y]],res,params,headingAdjustment))}),recursive=FALSE)
  if(method=="SL")  returnInterpolations <- unlist(lapply(as.list(names(unlist(lapply(spltTaCon,nrow)))),function(y){
                                              return(interStraightLine(splitTa[[y]],spltTaCon[[y]],res))}),recursive=FALSE)

} else {
  

    #Initiate returning result object
  returnInterpolations <- list()

  #Make vectors out of tacsat data to speed up interpolation
  VE_REF          <- tacsat$VE_REF
  SI_LATI         <- tacsat$SI_LATI
  SI_LONG         <- tacsat$SI_LONG
  SI_SP           <- tacsat$SI_SP
  SI_HE           <- tacsat$SI_HE
  SI_DATIM        <- tacsat$SI_DATIM

    #Start iterating over succeeding points
  for(iStep in 1:(dim(tacsat)[1]-1)){
  #for(iStep in 1:(4558)){
    #print(iStep)
    if(iStep == 1){
      iSuccess    <- 0
      endDataSet  <- 0
      startVMS    <- 1
      ship        <- VE_REF[startVMS]
    } else {
        if(is.na(endVMS)==TRUE) endVMS <- startVMS + 1
        startVMS <- endVMS
        ship      <- VE_REF[startVMS]
        if(endDataSet == 1 & (rev(unique(VE_REF))[1] == ship | startVMS > length(VE_REF))) endDataSet <- 2 #Final end of dataset
      }

    #if end of dataset is not reached, try to find succeeding point
    if(endDataSet != 2){
      idx         <- which(VE_REF == VE_REF[startVMS])
      startidx    <- which(idx == startVMS)
      result      <- findEndTacsat(SI_DATIM[idx],startVMS=startidx,interval,margin)
      endVMS      <- result[1]+idx[startidx]
      endDataSet  <- result[2]

      if(startVMS == dim(tacsat)[1] | (startVMS+1 == dim(tacsat)[1] & VE_REF[startVMS] != VE_REF[startVMS+1])){
        endDataSet <- 1
        endVMS <- NA
      }

      if(is.na(endVMS)==TRUE) int <- 0  #No interpolation possible
      if(is.na(endVMS)==FALSE) int <- 1  #Interpolation possible
        #Interpolate according to the Cubic Hermite Spline method
      if(method == "cHs" & int == 1){

          #Define the cHs formula
        F00 <- numeric()
        F10 <- numeric()
        F01 <- numeric()
        F11 <- numeric()
        i   <- 0
        t   <- seq(0,1,length.out=res)
        F00 <- 2*t^3 -3*t^2 + 1
        F10 <- t^3-2*t^2+t
        F01 <- -2*t^3+3*t^2
        F11 <- t^3-t^2

        if (is.na(SI_HE[startVMS])=="TRUE") SI_HE[startVMS] <- 0
        if (is.na(SI_HE[endVMS])=="TRUE")   SI_HE[endVMS]   <- 0

          #Heading at begin point in degrees
        Hx0 <- sin(SI_HE[startVMS]/(180/pi))
        Hy0 <- cos(SI_HE[startVMS]/(180/pi))
          #Heading at end point in degrees
        Hx1 <- sin(SI_HE[endVMS-headingAdjustment]/(180/pi))
        Hy1 <- cos(SI_HE[endVMS-headingAdjustment]/(180/pi))

        Mx0 <- SI_LONG[startVMS]
        Mx1 <- SI_LONG[endVMS]
        My0 <- SI_LATI[startVMS]
        My1 <- SI_LATI[endVMS]

          #Corrected for longitude lattitude effect
        Hx0 <- Hx0 * params$fm * SI_SP[startVMS] /((params$st[2]-params$st[1])/2+params$st[1])
        Hx1 <- Hx1 * params$fm * SI_SP[endVMS]   /((params$st[2]-params$st[1])/2+params$st[1])
        Hy0 <- Hy0 * params$fm * lonLatRatio(SI_LONG[c(startVMS,endVMS)],SI_LATI[c(startVMS,endVMS)])[1] * SI_SP[startVMS]/((params$st[2]-params$st[1])/2+params$st[1])
        Hy1 <- Hy1 * params$fm * lonLatRatio(SI_LONG[c(startVMS,endVMS)],SI_LATI[c(startVMS,endVMS)])[2] * SI_SP[endVMS]/((params$st[2]-params$st[1])  /2+params$st[1])

          #Finalizing the interpolation based on cHs
        fx <- numeric()
        fy <- numeric()
        fx <- F00*Mx0+F10*Hx0+F01*Mx1+F11*Hx1
        fy <- F00*My0+F10*Hy0+F01*My1+F11*Hy1

          #Add one to list of successful interpolations
        iSuccess <- iSuccess + 1
        returnInterpolations[[iSuccess]] <- matrix(rbind(c(startVMS,endVMS),cbind(fx,fy)),ncol=2,dimnames=list(c("startendVMS",seq(1,res,1)),c("x","y")))
      }

        #Interpolate according to a straight line
      if(method == "SL" & int == 1){
        fx <- seq(SI_LONG[startVMS],SI_LONG[endVMS],length.out=res)
        fy <- seq(SI_LATI[startVMS],SI_LATI[endVMS],length.out=res)

          #Add one to list of successful interpolations
        iSuccess <- iSuccess + 1
        returnInterpolations[[iSuccess]] <- matrix(rbind(c(startVMS,endVMS),cbind(fx,fy)),ncol=2,dimnames=list(c("startendVMS",seq(1,res,1)),c("x","y")))
      }
    }
  }
}
  
return(returnInterpolations)}

