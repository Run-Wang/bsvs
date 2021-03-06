#' Bayesian Variable Selection (ultra-high, high or low dimensional).
#' @rdname mybsvs
#' @description Perform Bayesian Variable Selection in Gaussian regression models
#' @param X  An \eqn{n x p} matrix. Sparse matrices are supported and every
#' care is taken not to make copies of this (typically) giant matrix.
#' No need to center or scale.
#' @param y  The response vector of length \code{n}.
#' @param w The prior inclusion probability of each variable.
#' @param lam The slab precision parameter.
#' as suggested by the theory of Wang et al. (2019).
#' @param temp.multip The temperature multiple. Default: 3.
#' @param M The number of iteration. Default: 200.

mybsvs <- function(X, y, w, lam, tmax=2, temp.multip=3, Miter=50, threhold=0.5) {
  result <- list()
  k=20

  n <- length(y)
  ncovar <- ncol(X)
  ys = scale(y)
  xbar = colMeans(X)

  stopifnot(class(X) %in% c("dgCMatrix","matrix"))
  if(class(X) == "dgCMatrix") {
    D = 1/sqrt(colMSD_dgc(X,xbar))
  }  else   {
    D = apply(X,2,sd)
    D = 1/D
  }
  Xty = D*as.numeric(crossprod(X,ys))

  logp <- numeric(Miter * (tmax+1))
  size <- integer(Miter * (tmax+1))
  indices <- integer(Miter*100)

  o <- bsvs1(X, ys, Xty, lam, w, k, D, xbar, n, ncovar, Miter)
  #saveRDS(o, file = "./results6/o0.rds")
  logp.best <- o$bestlogp
  r.idx.best <- o$bestidx
  logp[1:Miter] <- o$currlogp
  size[1:Miter] <- o$modelsizes
  ed <- sum(size)
  indices[1:ed] <- o$curridx


  t0 = 1
  for (t in t0:tmax) {
    cat("t =", t, "\n")
    o <- bsvs1_temp(X, ys, Xty, lam, w, k, D, xbar, t, temp.multip, logp.best, r.idx.best, n, ncovar, Miter)
    #saveRDS(o, file = paste0("./results6/o", t, ".rds"))
    logp.best <- o$bestlogp
    r.idx.best <- o$bestidx
    logp[(Miter*t+1):(Miter*(t+1))] <- o$currlogp
    size[(Miter*t+1):(Miter*(t+1))] <- o$modelsizes
    indices[(ed+1):(ed+sum(o$modelsizes))] <- o$curridx
    ed <- ed + sum(o$modelsizes)
  }
  indices <- indices[indices>0]
  cumsize <- cumsum(size)
  modelSparse <- sparseMatrix(i=indices,p = c(0,cumsize),index1 = T,dims = c(ncovar,length(logp)), x = T)

  logp.uniq1 <- unique(logp)
  for (i in 1:(length(logp.uniq1)-1)) {
    for (j in 2:length(logp.uniq1)) {
      if (abs(logp.uniq1[i]-logp.uniq1[j]) < 1e-10) {
        logp.uniq1[j] <- logp.uniq1[i]
      }
    }
  }
  logp.uniq <- unique(logp.uniq1)
  logp.top <- sort(logp.uniq[(logp.best-logp.uniq)<16], decreasing = T)
  cols.top <- unlist(lapply(logp.top, FUN=function(x){which(x==logp)[1]}))
  size.top <- size[cols.top]
  model.top <- modelSparse[, cols.top, drop=F]

  logp.top <- logp.top-logp.best
  weight <- exp(logp.top)/sum(exp(logp.top))

  beta.est <- matrix(0, (ncovar+1), length(cols.top))
  for(i in 1:length(cols.top)){
   if (size.top[i]==0){
     beta <- mean(y)
     beta.est[1, i] <- beta
   } else {
     m_i = model.top[, i]
     x.est <- cbind(rep(1, n), scale(X[, m_i], center = F, scale = 1/D[m_i]))
     beta <- solve(crossprod(x.est) + lam*diag(c(0, rep(1, size.top[i]))), crossprod(x.est, y))
     beta.est[c(T, m_i), i] <- c(beta[1]-xbar*D[m_i], beta[-1] * D[m_i])
   }
  }

  beta.MAP <- beta.est[, 1]
  beta.WAM <- rowSums(beta.est%*%diag(weight, nrow=length(size.top)))

  MIP = rowSums(model.top%*%Diagonal(length(weight), weight))
  model.WAM <- sort(which(MIP >= threhold))
  model.MAP <- sort(r.idx.best)
  MIP.MAP <- MIP[model.MAP]
  MIP.WAM <- MIP[model.WAM]
  models <- list(model.WAM=model.WAM, model.MAP=model.MAP)

  result$models <- models
  result$betaMAP <- beta.MAP
  result$betaWAM <- beta.WAM
  result$WAM$MIP <- MIP.WAM
  result$MAP$MIP <- MIP.MAP
  result$MAP$post.prob <- logp.best
  result$model.explored <- modelSparse
  result$logp_uniq <- logp.uniq
  result$logp_path <- logp

  return(result)
}

mybsvs <- cmpfun(mybsvs)
