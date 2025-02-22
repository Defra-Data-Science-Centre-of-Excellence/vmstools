# assign an identifier in'HL_ID' to each of the fishing sequences
# (based on SI_STATE, assuming the "h", "f", "s" coding)
# (useful to count them in a grid...)


#' Labelling fishing operations
#' 
#' Labelling fishing sequences from the SI_STATE coding with an unique
#' identifier
#' 
#' 
#' @param tacsat a tacsat format with the SI_STATE coding informed for "h", "f"
#' and "s"
#' @return add a new column to the tacsat data.frame named HL_ID
#' @author F. Bastardie
#' @seealso \code{\link{activityTacsat}}
#' @examples
#' 
#' data(tacsat)
#' tacsat$SI_STATE <- 0
#' tacsat$SI_SP    <- replace(tacsat$SI_SP, is.na(tacsat$SI_SP), 0)
#' tacsat[tacsat$SI_SP >= 1.5 & tacsat$SI_SP <= 7.5,'SI_STATE']      <- 'f'
#' tacsat[tacsat$SI_SP < 1.5,'SI_STATE']                              <- 'h'
#' tacsat[tacsat$SI_SP > 7.5,'SI_STATE']                              <- 's'
#' labellingHauls(tacsat)
#' 
#' @export labellingHauls
labellingHauls <- function(tacsat){
            tacsat$SI_STATE2                             <- tacsat$SI_STATE
            tacsat$SI_STATE                              <- as.character(tacsat$SI_STATE)
            tacsat[is.na(tacsat$SI_STATE), 'SI_STATE']   <- '1' # assign steaming
            tacsat[tacsat$SI_STATE!='f', 'SI_STATE']     <- '1' # assign steaming
            tacsat[tacsat$SI_STATE=='f', 'SI_STATE']     <- '2' # assign fishing
            tacsat$SI_STATE                              <- as.numeric(tacsat$SI_STATE)
            tacsat$HL_ID                              <- c(0, diff(tacsat$SI_STATE))   # init
            tacsat$HL_ID                              <- cumsum(tacsat$HL_ID) # fishing sequences detected.
            tacsat$SS_ID                              <- 1- tacsat$HL_ID  # steaming sequences detected.
            tacsat$HL_ID                              <- cumsum(tacsat$SS_ID ) # fishing sequences labelled.
            tacsat[tacsat$SI_STATE==1, 'HL_ID']       <- 0 # correct label 0 for steaming
            tacsat$HL_ID                              <- factor(tacsat$HL_ID)
            levels(tacsat$HL_ID) <- 0: (length(levels(tacsat$HL_ID))-1) # rename the id for increasing numbers from 0
            tacsat$HL_ID                             <- as.character(tacsat$HL_ID)
            # then assign a unique id
            idx <- tacsat$HL_ID!=0
            tacsat[idx, "HL_ID"] <- paste(
                                    tacsat$VE_REF[idx], "_",
                                    tacsat$LE_GEAR[idx], "_",
                                    tacsat$HL_ID[idx],
                                    sep="")
           tacsat$SI_STATE                             <- tacsat$SI_STATE2
           tacsat <- tacsat[, !colnames(tacsat) %in% c('SS_ID', 'SI_STATE2')] # remove useless column
          return(tacsat)
       }

# label fishing sequecnes with a unique identifier (method based on SI_STATE)
#tacsat <- labellingHauls(tacsat)



