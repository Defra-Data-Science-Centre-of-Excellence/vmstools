#########################################
# Build the table with the main species #
#########################################



#' Useful functions for the multivariate analysis of logbooks data for
#' identifying metiers.
#' 
#' This function contains several functions needed for the multivariate
#' analysis of logbooks data for identifying metiers.
#' 
#' 
#' @param transformation_proportion Transform quantities to percentage values
#' (between 0 and 100) of each species in the logevent total catch.
#' @param table_variables Transpose the dataset (change variables into
#' individuals)
#' @param scree Implementation of "scree-test"
#' @param select_species Remove the cluster with the smallest mean of capture
#' @param building_tab_pca Build the table with the main species
#' @param test.values Compute the test-value for each species by cluster
#' @param targetspecies Determine the species with a test-value > 1.96 by
#' cluster
#' @param withinVar Calculate the cluster's within-variance
#' @note A number of libraries are initially called for the whole metier
#' analyses and must be installed :
#' (FactoMineR),(cluster),(SOAR),(amap),(MASS),(mda)
#' @author Nicolas Deporte, Sebastien Demaneche, Stephanie Mahevas (IFREMER,
#' France), Clara Ulrich, Francois Bastardie (DTU Aqua, Denmark)
#' @references Development of tools for logbook and VMS data analysis. Studies
#' for carrying out the common fisheries policy No MARE/2008/10 Lot 2
#' @export building_tab_pca
building_tab_pca=function(data,especes){
  p=ncol(data)
  noms=colnames(data)
  ind_princ=which(is.element(noms,especes))
  princ=data[,ind_princ]
  return(princ)
}
