% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/rbindTacsat.r
\name{rbindTacsat}
\alias{rbindTacsat}
\title{Row bind two tacsat sets together}
\usage{
rbindTacsat(set1, set2)
}
\arguments{
\item{set1}{Tacsat set 1}

\item{set2}{Tacsat set 2}
}
\description{
Row binds two tacsat sets together while taking differences in column names
into account
}
\examples{

data(tacsat)
set1 <- tacsat
set2 <- tacsat[seq(1,100,5),]

combined <- rbindTacsat(set1,set2)


}
\references{
EU Lot 2 project
}
\seealso{
\code{\link{rbindEflalo}}, \code{\link{do.call}}
}
\author{
Niels T. Hintzen
}
