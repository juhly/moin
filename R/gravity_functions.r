#' Singly constrained location model
#'
#' A gravity like approach
#' 
#' @param Oi origin values, e.g. measured as purchasing power, money, etc. of location i
#' @param Dj destination values, e.g. measured as attractiveness of location j
#' @param alpha default = 1; scaling factor for the attractiveness
#' @param beta distance decay factor, default = 1
#' @param cij distance/cost etc. matrix
#' @param detfun deterrence function (always negative); default is
#'     "power beta"; further option is "exp" for an expontential
#'     function (--> entropy maximizing approach; NOTE: beta is
#'     overwritten by the estimate 1/mean(cij); this will be changed
#'     as soon as the beta estimating function is implemented.); ..
#' 
#' @return a list with the elements:
#' \itemize{
#' \item flows showing the flows from i to j,  
#' \item si are the sum of the rows, i.e. the sum of i along columns j; this is the factor that can be used to predict, e.g. shopping sales, subject to the constraint of purchasing power/population, etc. (Oi)
#' \item sj are the constraints 
#' }
#'
#' 
#' @examples ## From Wilson & Kirkby 1980, 100f.
#' ei <- c(2,1,1)
#' Pi <- c(50, 1000, 500)
#' Wj <- c(10, 100, 20)
#' cij <- matrix(data = c(1, 5, 5,
#'                       5, 2.585, 5,
#'                       5, 5, 2),
#'               nr = 3,
#'               nc = 3
#' )
#'
#' sc(Oi = ei * Pi, Dj = Wj, cij = cij, detfun = "power")
#'
#' ## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#' # from: Chan, Y., 2011. Location Theory and Decision
#' # Analysis. Springer Berlin Heidelberg, Berlin, Heidelberg.
#' # p. 128f.
#' cij <- matrix(data = c(8,5,10,
#'                        3,10,5),                      
#'               nrow = 2,
#'               byrow = TRUE)
#' Vi <- c(1000, 1400)
#' Vj <- c(1300, 300, 800)
#' 
#' sc(Oi = Vi, Dj = Vj, cij = cij, beta = 2)
#' @export sc
sc <- function(Oi, Dj, cij, alpha = 1, beta = 1, detfun = "power") {
  ## calculation of distance matrix using deterrence function
  if (detfun == "power") {
    fcij <- cij^-beta
  } else if (detfun == "exp") {
    beta <- 1/mean(cij, na.rm = TRUE)
    fcij <- exp(-beta * cij)        
  } else {
    cat("Sorry, I do not know this kind of deterrence function\n")
  }

  Dj <- Dj^alpha

  ## calculation of flows
  Tij <- cij
  
  for( i in 1:length(Oi)) {
    for( j in 1:length(Dj)) {
      Tij[i,j] <- Oi[i] * ((Dj[j] * fcij[i,j]) / sum(Dj * fcij[i,], na.rm = TRUE))
    }
  }

  ## calibration factor/weighting factor/ calibration constant
  ## K <- Oi
  ## for (j in 1:length(Dj)) {
  ##   K[j] <- 1 / sum(Dj * fcij[j,])
  ## }
  
  ## output
  return(list(flows = Tij,
              si = colSums(Tij, na.rm = TRUE),
              sj = rowSums(Tij, na.rm = TRUE)
              )
         )
}


#' Doubly constrained location model
#'
#' A gravity like approach
#' 
#' @param Oi population/workers
#' @param Dj settlement size/jobs
#' @param beta distance decay factor, default = 1
#' @param cij distance/cost etc. matrix
#' @param iterations used to stop calculation after n-iterations when
#'     no convergence is achieved
#' @param detfun deterrence function (always negative); default is
#'     "power beta"; further option is "exp" for an expontential
#'     function; ..
#'
#' @importFrom utils tail
#' @return a list with the elements:
#' \itemize{
#' \item iteration: when was convergence achieved
#' \item beta: beta (repeated for convenience)
#' \item Oi: a data.frame showing input and calculated values of summed rows, i.e. sum over j
#' \item Dj: a data.frame showing input and calculated values of summed columns, i.e. sum over i
#' \item Ratio: ratio of the difference between targeted and calculated values
#' \item error: globar error
#' \item Ai: the last five results for balancing factor Ai; the last value is chosen to calculate Tij
#' \item Bj: the last five results for balancing factor Bj; the last value is chosen to calculate Tij
#' \item Tij: the resulting flow matrix
#' \item sumTij: the overall sum of the flow matrix
#' }
#'
#' @references Wilson, A.G., Kirkby, M.J., 1980. Mathematics for geographers and planners, 2nd ed, Contemporary problems in geography. Clarendon Pr., Oxford.
#' Thomas, R.W., Huggett, R.J., 1980. Modelling in Geography: A Mathematical Approach. Rowman & Littlefield.
#' Ortúzar S., J. de D., Willumsen, L.G., 2011. Modelling Transport, Fourth edition. ed. John Wiley & Sons, Chichester, West Sussex, United Kingdom.
#' 
#' @examples
#' ## From Thomas & Huggett 1980, 150
#' ## --------------------------------------------------
#' Oi <- c(4,6,2)
#' Dj <- c(3,8,1)
#' cij <- matrix(data = c(1,2,2,
#'                        2,1,2,
#'                        2,2,1
#'                        ),
#'                nr = 3,
#'                nc = 3
#'                )
#' beta <- 1
#'
#' dc(Oi = Oi, Dj = Dj, cij = cij, iterations = 5)
#'
#' ## From Ortúzar & Willumsen 2011, 184-189
#' ## --------------------------------------------------
#' cost_mat <- matrix(data = c(3, 12, 15.5, 24,
#'                            11, 3, 13, 18,
#'                            18, 12, 5, 8,
#'                            22, 19, 7, 5
#'                            ),
#'                   nrow = 4,
#'                   ncol = 4
#'                   )
#' Oi_target <- c(400, 460, 400, 702)
#' Dj_target <- c(260, 400, 500, 802)
#'
#' dc(Oi_target, Dj_target, cij = cost_mat, beta = .1, detfun = "exp")
#' @export dc
dc <- function(Oi, Dj, beta = 1, cij, iterations = 1000, detfun = "power") {
  ## calculation of distance matrix using deterrence function
  if (detfun == "power") {
    fcij <- cij^-beta
  } else if (detfun == "exp") {
    if(missing(beta)) {
      beta <- beta_est <- 1/mean(cij)
    }   
    fcij <- exp(-beta * cij)        
  } else {
    cat("Sorry, I do not know this kind of deterrence function\n")
  }
  
  Ai <- rep(1, length(Oi))
  Bj <- rep(1, length(Dj))
  ai_conv <- bj_conv <- data.frame(rbind(rep(0,length(Oi))))
  
  ind <- 1
  while(ind < iterations) {
    ai_conv[ind,] <- Ai
    for (i in 1:length(Ai)) {
      Ai[i] <- 1 / sum(Bj * Dj * fcij[i,])
    }
    
    bj_conv[ind,] <- Bj
    for (j in 1:length(Bj)) {
      Bj[j] <- 1 / sum(Ai * Oi * fcij[,j])
    }
    
    if (ind > 1 &
          abs(sum(Ai-ai_conv[ind,])) < 0.001 &
          abs(sum(Bj-bj_conv[ind,])) < 0.001
        ) {
      conv <- ind
      ind <- iterations
    }
    else {
      ind <- ind+1
    }
  }

  Tij <- cij

  ## Wordy loop
  for (i in 1:length(Oi)) {
    for (j in 1:length(Dj)) {
      Tij[i,j] <- Ai[i] * Bj[j] * Oi[i] * Dj[j] * fcij[i,j]
    }
  }

  ## concise loop
  ## for (i in 1:length(Oi)) {
  ##     Tij[i,] <- Ai[i] * Bj * Oi[i] * Dj * cij[i,]^-beta
  ## }
  
  return(list(iteration = conv+1,
              beta = beta,
              Oi = data.frame(Target = Oi,
                              sj = rowSums(Tij)
                              ),
              Dj = data.frame(Target = Dj,
                              si = colSums(Tij)
                              ),
              Ratio = data.frame(rj = (Oi / rowSums(Tij)),
                                 ri = (Dj / rowSums(Tij))
                                 ),
              error = sum(abs(Oi - rowSums(Tij))) + sum(abs(Dj - colSums(Tij))),
              Ai = rbind(tail(ai_conv, 4), Ai),
              Bj = rbind(tail(bj_conv, 4), Bj),                                        
              Tij = Tij,
              sumTij = sum(Tij)
              #Tij_check = impedance * Ai * Bj
              )
         )
  
}



#' Doubly constrained location model (Furness method version)
#'
#' A gravity like approach; the code should be much faster than the dc version; it is based on the Furness method as presented in Ortúzar & Willumsen 2011 184--189
#' 
#' @param Oi population/workers
#' @param Dj settlement size/jobs
#' @param beta distance decay factor, default = 1
#' @param cij distance/cost etc. matrix
#' @param iterations used to stop calculation after n-iterations when
#'     no convergence is achieved
#' @param detfun deterrence function (always negative); default is
#'     "power beta"; further option is "exp" for an expontential
#'     function; ..
#'
#' @return a list with the elements:
#' \itemize{
#' \item iteration: when was convergence achieved
#' \item beta: beta (repeated for convenience)
#' \item Oi: a data.frame showing input and calculated values of summed rows, i.e. sum over j
#' \item Dj: a data.frame showing input and calculated values of summed columns, i.e. sum over i
#' \item Ratio: ratio of the difference between targeted and calculated values
#' \item error: globar error
#' \item Tij: the resulting flow matrix
#' \item sumTij: the overall sum of the flow matrix
#' }
#'
#' @references Wilson, A.G., Kirkby, M.J., 1980. Mathematics for geographers and planners, 2nd ed, Contemporary problems in geography. Clarendon Pr., Oxford.
#' Ortúzar S., J. de D., Willumsen, L.G., 2011. Modelling Transport, Fourth edition. ed. John Wiley & Sons, Chichester, West Sussex, United Kingdom.
#' Thomas, R.W., Huggett, R.J., 1980. Modelling in Geography: A Mathematical Approach. Rowman & Littlefield.
#' 
#' @examples
#' ## From Thomas & Huggett 1980, 150
#' ## --------------------------------------------------
#' Oi <- c(4,6,2)
#' Dj <- c(3,8,1)
#' cij <- matrix(data = c(1,2,2,
#'                        2,1,2,
#'                        2,2,1
#'                        ),
#'                nr = 3,
#'                nc = 3
#'                )
#' beta <- 1
#'
#' dc2(Oi = Oi, Dj = Dj, cij = cij, iterations = 5)
#'
#' ## From Ortúzar & Willumsen 2011, 184-189
#' ## --------------------------------------------------
#' cost_mat <- matrix(data = c(3, 12, 15.5, 24,
#'                            11, 3, 13, 18,
#'                            18, 12, 5, 8,
#'                            22, 19, 7, 5
#'                            ),
#'                   nrow = 4,
#'                   ncol = 4
#'                   )
#' Oi_target <- c(400, 460, 400, 702)
#' Dj_target <- c(260, 400, 500, 802)
#'
#' dc2(Oi_target, Dj_target, cij = cost_mat, beta = 0.1, detfun = "exp")
#' @export dc2
dc2 <- function(Oi, Dj, cij, beta = 1, iterations = 100, detfun = "exp") {
  if (detfun == "power") {
    fcij <- cij^-beta
  } else if (detfun == "exp") {
    if(missing(beta)) {
      beta <- beta_est <- 1/mean(cij)
    }        
    fcij <- exp(-beta * cij)        
  } else {
    cat("Sorry, I do not know this kind of deterrence function\n")
  }
  
  Tij <- cij

  ef <- sum(Oi)/sum(fcij) # expansion factor
  Tij <- fcij * ef
  
  ind <- 0
  while (ind < iterations) {
    ai <- (Oi / rowSums(Tij))
    Tij <- Tij * ai
    bj <- (Dj / colSums(Tij))
    Tij <- t(t(Tij) * bj)
    
    if ((sum(abs(Dj - colSums(Tij))) < 0.01) & (sum(abs(Oi - rowSums(Tij))) < 0.01)
        ) {
      return(list(iteration = ind,
                  Oi = data.frame(Target = Oi,
                                  sj = rowSums(Tij)
                                  ),
                  Dj = data.frame(Target = Dj,
                                  si = colSums(Tij)
                                  ),
                  Ratio = data.frame(rj = (Oi / rowSums(Tij)),
                                     ri = (Dj / rowSums(Tij))
                                     ),
                  ExpansionFactor = ef,
                  error = sum(abs(Oi - rowSums(Tij))) + sum(abs(Dj - colSums(Tij))),
                  Tij = Tij,
                  sumTij = sum(Tij)
                  #Tij_check = impedance * Ai * Bj
                  )
             )
      stop
    }
    else {
      ind <- ind+1
    }
  }
}
