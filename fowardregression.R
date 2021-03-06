#' Bayesian Iterated Screening (ultra-high, high or low dimensional).
#' @rdname bis
#' @description Perform Bayesian iterated screening in Gaussian regression models
#' @param X  An \eqn{n x p} matrix. Sparse matrices are supported and every
#' care is taken not to make copies of this (typically) giant matrix.
#' No need to center or scale.
#' @param y  The response vector of length \code{n}.
#' @param lam The slab precision parameter. Default: \code{n/p^2}.
#' @param w The prior inclusion probability of each variable. Default: \code{sqrt(n)/p}
#' as suggested by the theory of Wang et al. (2019).
#' @param criteria The stopping criteria. Could be "PP" for
#' posterior probability stopping rule, or "eBIC" for extended BIC stopping rule,
#' or "both" (default). Note that for "eBIC" the value of \code{w} is not used.
#'
#' @return A list with components
#' \item{model.pp}{An integer vector of screened model under posterior probability stopping rule.
#'  This will be null if only "eBIC" stopping criterion was used.}
#' \item{mdoel.ebic}{An integer vector of screened model under eBIC criterion. This will be NULL if
#'  only "PP" stopping criterion was used.}
#' \item{postprobs}{The sequence of posterior probabilities until the last included variable.
#'  This will be null if only "eBIC" stopping criterion was used. Here the last included variable
#'  is the last one included by either "PP" or "eBIC" if criteria="both" was selected}
#' \item{ebics}{The sequence of eBIC values until the last included variable.
#'  This will be null if only "PP" stopping criterion was used.  Here the last included variable
#'  is the last one included by either "PP" or "eBIC" if criteria="both" was selected}
#' @export

fr <- function(X,y,lam=0, max.var = n-1)
{
  lam = 0
  p = ncol(X)
  n = nrow(X)
  ys = scale(y)
  
  xbar = colMeans(X)
  
  stopifnot(class(X) %in% c("dgCMatrix","matrix"))
  
  if(class(X) == "dgCMatrix") {
    D = 1/sqrt(bsvs:::colMSD_dgc(X,xbar))
  }  else   {
    D = apply(X,2,sd)
    D = 1/D
  }
  
  xty = D*as.numeric(crossprod(X,ys))
  
  
  yty <- n - 1
  xtx <- n - 1
  
  
  #max.var = n-10; # Intially allocate for maximum of n variables.
  
  model = integer(max.var)
  postprob = numeric(max.var+1)
  
  
  
  R = matrix(NA,max.var,max.var)
  sumv2 = 0
  logdetR = 0;
  z = numeric(p)
  u   = numeric(p)
  v = numeric(max.var)
  
  
  postprob[1] = -0.5*(n-1)*log(yty) # The posterior probability of the null model
  cat("\n Including: ")
  # cat(postprob[1],", ")
  
  # First variable
  b0 = sqrt(xtx + lam)
  logdetR = log(b0)
  #logp <- 0.5*log(lam)-logdetR - 0.5*(n-1)*log(yty - (xty/b0)^2) #+ logw
  logp <- -0.5*(n-1)*log(yty - (xty/b0)^2) #+ logw
  
  j = which.max(as.numeric(logp))
  cat(j)
  model[1] = j;
  postprob[2] = logp[j]
  # cat(" ,",logp[j],"\n")
  # Need to do the second variable by hand
  if(max.var >= 2)
  {
    R[1,1] = b0;
    xjc = (X[,j] - xbar[j])*D[j]
    v[1] = xty[j]/b0
    sumv2 = v[1]^2
    
    S = D*crossprod(X,xjc)/b0
    z = S^2
    
    w1 = sqrt(xtx+lam - z)
    u = {xty - v[1]*S}/w1;
    
    RSS = yty - sumv2 - u^2
    RSS[j] = Inf
    #logp = 0.5*2*log(lam) - logdetR - log(w1) - 0.5*{n-1}*log(RSS) #+ 2*logw
    logp = - 0.5*{n-1}*log(RSS) #+ 2*logw
    
    j = which.max(as.numeric(logp))
    cat(", ",j)
    model[2] = j
    postprob[3] = logp[j]
    # cat(" ,",logp[j],"\n")
  }
  
  
  
  if(max.var >= 3)
  {
    for(ii in 3:max.var)
    {
      
      model.prev = model[1:{ii-2}]
      
      
      xjc = (X[,j] - xbar[j])*D[j]
      
      
      X1 = X[,model.prev,drop=FALSE]
      D1 = D[model.prev]
      Xbar1 = xbar[model.prev]
      a1 = backsolve(R,D1*crossprod(X1,xjc),k = ii-2,transpose = T)
      # print(a1)
      b1 = w1[j]
      logdetR = logdetR + log(b1)
      
      v[ii-1] = u[j];
      sumv2 = sumv2 + u[j]^2
      
      
      temp1 = D1*backsolve(R,a1,transpose = FALSE,k = ii-2)
      temp2 = xjc - X1 %*% temp1;
      temp2 = temp2 - mean(temp2)
      
      eta = D*crossprod(X,temp2)
      eta = eta/b1
      
      
      z = z + eta^2
      
      temp3  = xtx + lam - z;
      temp3[model[1:{ii-1}]] = 1;
      w2 = sqrt(temp3)
      u = {u*w1 - u[j]*eta}/w2;
      
      
      RSS = yty - sumv2 - u^2
      RSS[model[1:{ii-1}]] = Inf
      #logp = 0.5*ii*log(lam) - logdetR - log(w2) - 0.5*{n-1}*log(RSS) #+ ii*logw
      logp = - 0.5*{n-1}*log(RSS) #+ ii*logw
      # print(anyNA(logp))
      j = which.max(as.numeric(logp))
      
      cat(", ",j)
      # cat(" ,",logp[j],"\n")
      postprob[ii+1] <- logp[j]
      model[ii] = j
      
      w1 = w2;
      if(ii <= max.var)
      {
        R[1:{ii-2},ii-1] = a1;
        R[ii-1,ii-1] = b1;      
        # print(R[1:{ii-1},1:{ii-1}])
      }
      
    }
  }
  cat(" Done.\n")
  
  return(list(model.pp = model, postprobs=postprob,lam=lam))
}

PX <- function(X,y) crossprod(y,X)%*%ginv(crossprod(X))%*%crossprod(X,y)

bic <- function(X,y,gamma){
  p = dim(X)[2]
  n = dim(X)[1]
  #R <- solve(chol(crossprod(X)))
  X = scale(as.matrix(X[,gamma,drop = F]))
  y = scale(y)
  yty <- crossprod(y)
  xty <- crossprod(X,y)
  temp = 0
  temp2 = log(yty)
  for(i in 1:p){
    temp = PX(X[,1:i],y)
    temp3 <- log((yty - temp)) + i * (log(n) + 2 * log(p)) / n
    if (as.numeric(temp3)>as.numeric(temp2)){
      #return(i-1)
      if(i == 1){
        return (integer(0))
      }
      else{
        return (gamma[1:(i-1)])
      }
    }
    else{
      temp2 = temp3
    }
  }
  return(gamma)
}

bic_2 <- function(X,y,gamma){
  p = dim(X)[2]
  n = dim(X)[1]
  #R <- solve(chol(crossprod(X)))
  X = scale(as.matrix(X[,gamma,drop = F]))
  y = scale(y)
  yty <- crossprod(y)
  xty <- crossprod(X,y)
  temp = 0
  temp2 = log(yty)
  result = 0
  for(i in 1:50){
    temp = PX(X[,1:i],y)
    temp3 <- log((yty - temp)) + i * (log(n) + 2 * log(p)) / n
    if (as.numeric(temp3)<as.numeric(temp2)){
      temp2 = temp3
      result = i
    }
  }
  if(result == 0){
    return(integer(0))
  }
  return(gamma[1:result])
}


MSPE <- function(xtrain, xtest, ytrain, ytest,gamma){
  if(length(gamma) == 0){
    ybar = mean(ytrain)
    return(list(mspe = as.numeric(mean(ytest-ybar)^2),r = 0))
  }
  
  xtrain1 = cbind(1,xtrain[,gamma,drop=FALSE])
  
  beta = solve(crossprod(xtrain1),crossprod(xtrain1,ytrain))
  yhat = as.numeric(xtest[,gamma,drop=FALSE] %*% beta[-1] + beta[1])
  res <- as.numeric(mean((ytest - yhat)^2))
  return(list(mspe = res, r = cor(ytest,yhat)))
}



MSPE_B <- function(xtrain, xtest, ytrain, ytest,gamma,lam){
  if(length(gamma) == 0){
    ybar = mean(ytrain)
    return(list(mspe = as.numeric(mean(ytest-ybar)^2),r = 0))
  }
  
  xtrain = xtrain[,gamma,drop = FALSE]
  
  xbar = colMeans(xtrain)
  if(class(xtrain) == "dgCMatrix") {
    D = 1/sqrt(bsvs:::colMSD_dgc(xtrain,xbar))
  }  else   {
    D = apply(xtrain,2,sd)
    D = 1/D
  }
  
  xbar_mat = matrix(rep(xbar, each = dim(xtrain)[1]), dim(xtrain)[1])
  XD = cbind(rep(1, nrow(xtrain)),(xtrain - xbar_mat) %*% Diagonal(length(D),D))
  lam_mat = lam * Diagonal(length(gamma)+1)
  lam_mat[1,1] = 0
  XX = crossprod(XD) + lam_mat
  beta = solve(XX, crossprod(XD,ytrain))
  
  beta[1] = beta[1] - sum((D * xbar) * beta[-1])
  beta[-1] = D * beta[-1]
  
  yhat = as.numeric(xtest[,gamma,drop=FALSE] %*% beta[-1] + beta[1])
  res <- as.numeric(mean((ytest - yhat)^2))
  return(list(mspe = res, r = cor(ytest,yhat)))
}


logpp_true <- function(X, y, trueidx, lam, w){
  X = scale(as.matrix(X[,trueidx,drop = F]))
  y = scale(y)
  yty <- crossprod(y)
  n <- nrow(X)
  p <- ncol(X)
  xty <- crossprod(X,y)
  
  gamma <- length(trueidx)
  
  res <- gamma/2*log(lam) - 1/2 * logdet(crossprod(X)+lam*diag(p)) - (n-1)/2 * log(yty - t(xty) %*% solve(crossprod(X)+lam*diag(p), xty)) + gamma * log(w/(1-w))
  return(res)
}









# bis <- function(X,y,lam=nrow(X)/ncol(X)^2,w = sqrt(nrow(X))/ncol(X),criteria="PP")
# {
#   p = ncol(X)
#   n = nrow(X)
#   ys = scale(y)
#   
#   xbar = colMeans(X)
#   
#   stopifnot(class(X) %in% c("dgCMatrix","matrix"))
#   
#   if(class(X) == "dgCMatrix") {
#     D = 1/sqrt(colMSD_dgc(X,xbar))
#   }  else   {
#     D = apply(X,2,sd)
#     D = 1/D
#   }
#   Xty = D*as.numeric(crossprod(X,ys))
#   
#   
#   max.var = n; # Intially allocate for maximum of n variables.
#   
#   model = integer(0L)
#   postprob = numeric(max.var+1)
#   R0 = NULL
#   v0 = NULL
#   
#   postprob[1] = -0.5*(n-1)*log(n) # The posterior probability of the null model
#   cat("\n Including: ")
#   for(ii in 1:n)
#   {
#     this <- addvar(model = model,x = X, ys = ys, xty = Xty, lam = lam, w = w,
#                    R0 = R0, v0 = v0,D = D,xbar = xbar)
#     j = this$which.max
#     if(this$logp[j] < postprob[ii])      break;
#     cat(j,", ",sep = "")
#     postprob[ii+1] <- this$logp[j]
#     model = c(model,j)
#     R0 = this$R
#     v0 = this$v
#   }
#   cat(" Done.\n")
#   
#   return(list(model.pp = model, postprobs=postprob[1:ii]))
# }




