% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/bis.r
\name{bis}
\alias{bis}
\title{Bayesian Iterated Screening (ultra-high, high or low dimensional).}
\usage{
bis(X, y, lam = nrow(X)/ncol(X)^2, w = sqrt(nrow(X))/ncol(X),
  criteria = "PP")
}
\arguments{
\item{X}{An \eqn{n x p} matrix. Sparse matrices are supported and every
care is taken not to make copies of this (typically) giant matrix.
No need to center or scale.}

\item{y}{The response vector of length \code{n}.}

\item{lam}{The slab precision parameter. Default: \code{n/p^2}.}

\item{w}{The prior inclusion probability of each variable. Default: \code{sqrt(n)/p}
as suggested by the theory of Wang et al. (2019).}

\item{criteria}{The stopping criteria. Could be "PP" for
posterior probability stopping rule, or "eBIC" for extended BIC stopping rule,
or "both" (default). Note that for "eBIC" the value of \code{w} is not used.}
}
\value{
A list with components
\item{model.pp}{An integer vector of screened model under posterior probability stopping rule.
 This will be null if only "eBIC" stopping criterion was used.}
\item{mdoel.ebic}{An integer vector of screened model under eBIC criterion. This will be NULL if
 only "PP" stopping criterion was used.}
\item{postprobs}{The sequence of posterior probabilities until the last included variable.
 This will be null if only "eBIC" stopping criterion was used. Here the last included variable
 is the last one included by either "PP" or "eBIC" if criteria="both" was selected}
\item{ebics}{The sequence of eBIC values until the last included variable.
 This will be null if only "PP" stopping criterion was used.  Here the last included variable
 is the last one included by either "PP" or "eBIC" if criteria="both" was selected}
}
\description{
Perform Bayesian iterated screening in Gaussian regression models
}
