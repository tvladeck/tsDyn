VAR.gen <- function(B, n=200, lag=1, include = c("const", "trend","none", "both"),  
                    starting=NULL, innov, exogen=NULL, trendStart=1,
                    show.parMat=FALSE, returnStarting=FALSE){
  
  include<-match.arg(include)
  if(!is.matrix(B)) stop("B should be a matrix")
  ## Create some variables/parameters
  p <- lag
  plast <- if(lag==0) 1 else p
  ninc <- switch(include, "none"=0, "const"=1, "trend"=1, "both"=2)
  k <- nrow(B)
  T <- n   	#Size of start sample
  t <- T-p  #Size of end sample
  y <- matrix(0, ncol=k, nrow=n+p)
  trend<-c(rep(0, p), trendStart+(0:(T-1))) 
  
  ## exogen
  if(!is.null(exogen)){
    if(!is.matrix(exogen)) exogen <- as.matrix(exogen)
    if(nrow(exogen)!=n) 
      stop("Bad specification of 'exogen'. Expected: ", 
           n, " row")
    nExogen <- ncol(exogen)
    exogen <- rbind(matrix(0, ncol=nExogen, nrow=p), exogen)
  } else {
    exogen <- matrix(0, ncol=1, nrow=n+p)
    nExogen <- 0
  }
  

  ## Check inputs
  npar <- p*k+ninc+nExogen
  if(ncol(B)!=npar){
    stop("bad specification of B. Expected: ", 
         ninc, " const/trend, ",
         p, " * ", k, " lags, ", nExogen, " exogens")
  }
  
  if(!is.null(starting)&&!all(dim(as.matrix(starting))==c(p,k))){
    stop("Bad specification of starting values. Expected dim ", p, "*", k)
  }
  
  if(!all(dim(as.matrix(innov))==c(n,k))){
    stop("Bad specification of innovations. Expected dim ", n, "*", k)
  }
  
  
  ## Augment B to include always constant/trend (eventually 0), exogen, lags
  addInc <- switch(include, "none"=1:2, "trend"=1, "const"=2, "both"=NULL)
  Bfull <- myInsertCol(B, c=addInc, 0)
  if(lag==0) Bfull <- cbind(Bfull, matrix(0, ncol=k, nrow=k))
  if(nExogen==0) Bfull <- cbind(Bfull, 0)
  
  
  ## Starting values
  if(!is.null(starting)){
    if(all(dim(as.matrix(starting))==c(p,k)))
      y[seq_len(p),]<- as.matrix(starting)
    else
      stop("Bad specification of starting values. Should have nrow = lag and ncol = number of variables. But is: ", dim(as.matrix(starting)), sep="")
  }

  ## innovations
  resb <- rbind(matrix(0,nrow=p, ncol=k),innov)	

  ## MAIN loop:  
  pstart <- if(lag==0) 0 else 1

  for(i in (p+1):(n+p)){
    Y <- matrix(t(y[i-c(pstart:p),, drop=FALSE]), ncol=1)
    Yexo <-  rbind(Y, t(exogen[i, , drop=FALSE]))
    y[i,]<-rowSums(cbind(Bfull[,1],  # intercept
                         Bfull[,2]*trend[i], #trend
                         Bfull[,-c(1,2)]%*%Yexo, #lags
                         resb[i,])) #residuals
  }
  
  

  
  if(show.parMat) print(Bfull)
  if(!returnStarting && lag!=0) y <- y[-c(1:p),, drop=FALSE] 
  return(y)
}

if(FALSE){
  
  B <- matrix(c(0.3, 0.2, 0.1, 0.3, 0.2, 0.4),nrow=2 )
  n <- 200
  inno <- matrix(rnorm(200*2), ncol=2)
  environment(VAR.gen) <- environment(TVECM)
  VAR.gen(B=B, include="const", lag=1, innov=inno)
  VAR.gen(B=B[,1,drop=FALSE], include="const", lag=0, innov=matrix(0, ncol=2, nrow=200))
  
}


#'@rdname VAR.boot
#'@param B Matrix of coefficients. 
#'@param n Number of observations to simulate
#'@param lag Number of lags of the VAR to simulate
#'@param include Type of deterministic regressors to include in the VAR to simulate 
#'@param starting Starting values (matrix of dimension lag x k) for the VAR to simulate. If not given,
#'set to zero.
#'@param innov Innovations used for in the VAR to simulate. Should be matrix of dim n x k.
#'By default multivariate normal.
#'@param varcov Variance-covariance matrix for the innovations. By default
#'identity matrix.
#'@param show.parMat Logical. Should the parameter matrix be shown? Useful to
#'understand how to give right input
#'@param returnStarting Whether starting values are returned. Default to FALSE
#'@return A matrix with the resampled series.
#'@author Matthieu Stigler
#'@keywords ts bootstrap
#'@export
#'@examples
#'
#'## VAR.sim: simulate VAR as in Enders 2004, p 268
#'B1<-matrix(c(0.7, 0.2, 0.2, 0.7), 2)
#'var1 <- VAR.sim(B=B1, n=100, include="none")
#'ts.plot(var1, type="l", col=c(1,2))
#'
#'
#'B2<-rbind(c(0.5, 0.5, 0.5), c(0, 0.5, 0.5))
#'varcov<-matrix(c(1,0.2, 0.3, 1),2)
#'var2 <- VAR.sim(B=B2, n=100, include="const", varcov=varcov)
#'ts.plot(var2, type="l", col=c(1,2))

VAR.sim <- function(B, n=200, lag=1, include = c("const", "trend","none", "both"),  
                    starting=NULL, innov=rmnorm(n, varcov=varcov), 
                    varcov=diag(1,nrow(B)), 
                    show.parMat=FALSE, returnStarting=FALSE, ...){
  
  VAR.gen(B=B, n=n, lag=lag, include = include,  
          starting=starting, innov=innov, 
          show.parMat=show.parMat, returnStarting=returnStarting, ...)
}



#'
#' Simulate or bootstrap a VAR model
#'
#' Allow to either simulate from scratch (by providing coefficients) or bootstrap from an estimated VAR model, 
#'
#'For the bootstrap, the function resamples data from a given VAR model generated by
#' \code{\link{lineVar}}, returning the resampled data. 
#' A residual recursive bootstrap is used, where one uses either a simple
#' resampling, or the Wild bootstrap, either with a normal distribution (wild1) or
#' inverting the sign randomly (wild2)
#'
#'@param VARobject Object of class \code{ VAR} generated by function
#'\code{\link{lineVar}}
#'@param boot.scheme The bootstrap scheme. See details. 
#'@param seed Optional. Seed for the random resampling function.
#'@param \dots Further arguments passed to the underlying (un-exported)
#'\code{VAR.gen} function
#'@seealso \code{\link{lineVar}} to estimate the VAR.  Similar \code{\link{TVECM.sim}} and \code{\link{TVECM.boot}} for \code{\link{TVECM}}, 
#'\code{\link{TVAR.sim}} and \code{\link{TVAR.boot}} for \code{\link{TVAR}} models. 
#'@keywords ts bootstrap
#'@export
#'@examples
#'
#'## VAR.boot: Bootstrap a VAR 
#'data(zeroyld)
#'mod <- lineVar(data=zeroyld,lag=1)
#'VAR.boot(mod)
#'
#'

VAR.boot <- function(VARobject, boot.scheme=c("resample", "wild1", "wild2", "check"),
                     seed, ...){
  
  boot.scheme <- match.arg(boot.scheme)
  
  B <- coef(VARobject)
  t <- VARobject$t
  k <- VARobject$k
  lags <- VARobject$lag
  startLag <- if(lags==0) 0 else 1
  include <- VARobject$include
  num_exogen <- VARobject$num_exogen 
  
  YX <- VARobject$model
  yorig <- YX[,1:k]
  starts <- yorig[1:lags,, drop=FALSE]
  resids <- residuals(VARobject)

  ## boot it
  if(!missing(seed)) set.seed(seed) 
  innov <- switch(boot.scheme, 
                  "resample"=  resids[sample(seq_len(t), replace=TRUE),], 
                  "wild1"=resids+rnorm(t), 
                  "wild2"=resids+sample(c(-1,1), size = t, replace=TRUE),
                  "check"=  resids)
  
  ## Exogen
  if(num_exogen>0){
    nYX <- ncol(YX)
    exogen <- YX[-c(startLag:lags), -(num_exogen-1):0+nYX]
#     starts <- cbind(starts, matrix(0, nrow=nrow(starts), ncol=num_exogen))
  } else {
    exogen <- NULL
  }
  
  res <- VAR.gen(B=B, n=t, lag=lags, include = include,  
                 starting=starts, innov=innov, exogen=exogen, 
                 show.parMat=FALSE, returnStarting=TRUE, ...)
  colnames(res) <- colnames(yorig)
  res
}




if(FALSE){
  barry_mat <- as.matrix(as.data.frame(barry))
  
  va <- lineVar(barry, lag=1)
  checkBoot <- function(x){
    check <- VAR.boot(x, boot.scheme="check")
    all.equal(check, as.matrix(as.data.frame(barry)), check.attributes = FALSE)
  }
  checkBoot(va)
  checkBoot(lineVar(barry, lag=2))
  
  var_l3_const <-VAR.boot(lineVar(barry, lag=3), boot.scheme="check")
  all.equal(var_l3_const, barry_mat)
  
  var_l2_none <-VAR.boot(lineVar(barry, lag=2, include="none"), boot.scheme="check")
  all.equal(var_l2_none, barry_mat)

  var_l2_trend <-VAR.boot(lineVar(barry, lag=2, include="trend"), boot.scheme="check")
  all.equal(var_l2_trend, barry_mat)
  
  var_l2_exo <-VAR.boot(lineVar(barry[,1:2], lag=2, exogen=barry[-c(1,2),3]), boot.scheme="check")
  all.equal(var_l2_exo, barry_mat[,1:2])

  var_l2_exo2 <-VAR.boot(lineVar(barry[,2:3], lag=1, exogen=barry[-c(1),1]), boot.scheme="check")
  all.equal(var_l2_exo2, barry_mat[,2:3])
  
  var_l2_exo_both <-VAR.boot(lineVar(barry[,1:2], lag=2, exogen=barry[-c(1,2),3], include="both"), boot.scheme="check")
  all.equal(var_l2_exo_both, barry_mat[,1:2])
  
}
