###############
## RootTreeToR.R
##
##  S4 Classes for a RootChain

setClass("RootChain", 
         representation(tree="character",
                        files="character",
                        manager="externalptr")
         )

## The specific initialization method
setMethod("initialize",
          "RootChain",
          function(.Object, tree, files, verbose=T, trace=F) {
            .Object@tree = tree
            .Object@files = files
            
            ## Make the RootChainManager rootChain
            .Object@manager = .Call(newRootChainManager, tree,
              files, verbose, trace)
            
            if ( is.null(.Object@manager ) ) stop("Could not make RootChainManager")
            
            .Object
          }
          )

## Do not need anything specific for deletion since the manager 
## is registered to delete itself


#################################
## Create a new root chain
openRootChain <- function(tree, files, verbose=T, trace=F) {
  new("RootChain", tree, files, verbose, trace)
}

#################################
## Set the verbose flag
setVerbose <- function(rootChain, verbose=T) {
  
  .assertClass(rootChain, "RootChain")
  
  if ( ! is.logical(verbose) ) stop("verbose must be a logical")
  
  .Call("setVerbose", rootChain@manager, verbose, PACKAGE="RootTreeToR")
  
  invisible()
}

#################################  
## Get the verbose flag
getVerbose <- function(rootChain) {
  
  .assertClass(rootChain, "RootChain")
  
  .Call("getVerbose", rootChain@manager, PACKAGE="RootTreeToR")
}

## Set the trace flag
setTrace <- function(rootChain, trace=T) {
  
  .assertClass(rootChain, "RootChain")
  
  if ( ! is.logical(trace) ) stop("trace must be a logical")
  
  .Call("setTrace", rootChain@manager, trace, PACKAGE="RootTreeToR")
  
  invisible()
}

#################################  
## Get the trace flag
getTrace <- function(rootChain) {
  
  .assertClass(rootChain, "RootChain")
  
  .Call("getTrace", rootChain@manager, PACKAGE="RootTreeToR")
}

#################################
## nEntries
setMethod("nEntries", "RootChain",
          function(object, selection="") {  
            
            .Call("nEntries", object@manager, selection, PACKAGE="RootTreeToR")
          }
          )

#################################
## getNames
getNames <- function(rootChain, raw=F) { 
  
  .assertClass(rootChain, "RootChain")
  
  n = .Call("names", rootChain@manager, PACKAGE="RootTreeToR")
  
  ## Unless the user wants the raw titles, parse them
  if ( ! raw ) {
    f <- function(x) {
      varDesc = strsplit(x, ":")[[1]]  # Split by :
      varSplit = strsplit(varDesc, "/")  # Split name and type
      sapply(varSplit, function(x) x[1]) # Extract just the name [1]
    }
    
    n = lapply(n, f)
  }
  
  n
}

################################
## makeEventList
makeEventList <- function(rootChain, name, selection, append=F, 
  nEntries=100, firstEntry=0, entryList=F) {
  
  .assertClass(rootChain, "RootChain")
  
  ## Create the "columns" name for TChain::Draw
  if ( append ) col = paste(">>+", name, sep="")
  else col = paste(">>", name, sep="")
  
  .Call("makeEventList", rootChain@manager,
        col, selection, as.integer(nEntries),
        as.integer(firstEntry), as.logical(entryList), PACKAGE="RootTreeToR")
  
  ## Find this event/entry list
  if (entryList)
    getEntryList(name, T)
  else
    getEventList(name, T)
}

################################
## narrowWithEventList
narrowWithEventList <- function(rootChain, eventList) {
  .assertClass(rootChain, "RootChain")
  .assertClass(eventList, "EventList")
  
  .Call("applyEventList", rootChain@manager, eventList@ptr, PACKAGE="RootTreeToR")
  
  invisible()
}

################################
## narrowWithEntryList
narrowWithEntryList <- function(rootChain, entryList) {
  .assertClass(rootChain, "RootChain")
  .assertClass(entryList, "EntryList")
  
  .Call("applyEntryList", rootChain@manager, entryList@ptr, PACKAGE="RootTreeToR")
  
  invisible()
}

######################
## getEventListName
getEventListName = function(rootChain) {
  .assertClass(rootChain, "RootChain")
  
  .Call("getEventListName", rootChain@manager, PACKAGE="RootTreeToR")
}

#############################
## clearEventList
clearEventList = function(rootChain) {
  .assertClass(rootChain, "RootChain")
  .Call("clearEventList", rootChain@manager, PACKAGE="RootTreeToR")
  
  invisible()
}       

#############################
## clearEntryList
clearEntryList = function(rootChain) {
  .assertClass(rootChain, "RootChain")
  .Call("clearEntryList", rootChain@manager, PACKAGE="RootTreeToR")
  
  invisible()
}       

#################################
## processToRResult
##   Process the toR result to get the data frame returned
processToRResult = function(ans, isVerbose) {
  
  if (isVerbose) print("Processing results")
  
  data = ans[[1]]
  
  if ( length(data) == 0 ) stop ("Nothing returned")
  
  ## Do we need to resize?
  if ( ans[[3]] != length( data[[1]] ) ) {
    
    if ( isVerbose ) print("Shrinking vectors")
    
    ## Resize
    f = function(x) { length(x) = ans[[3]] ; x }
    
    data = lapply(data, f)
  }
  
  if (isVerbose) print("Setting row names")
  attr(data, "row.names") = 1:ans[[3]]
  
  class(data) = "data.frame"
  
  data
}


#################################
## toR
toR = function(rootChain, columns, selection="", nEntries=100, firstEntry=0,
  initialSize=1000, maxSize=0, growthFactor=1.7, prefix="", activate=character(0),
  doEntryColumns=F, doArrays=F) { 
  
  .assertClass(rootChain, "RootChain")
  
  ## There had better be columns to choose
  if ( length(columns) == 0 ) stop("You must supply a list of tree variables")
  
  if ( any(nchar(columns) == 0) ) stop("You must supply a nonblank list of tree variables")
  
  if ( initialSize <= 0 ) stop ("initialSize must be > 0")

  maxSize <- max(maxSize, 0)
  
  if ( nEntries <= 0 ) nEntries = 90999999
  
  ## Growth factor had better be greater than 1.5 
  if ( growthFactor < 1.5) stop ("growthFactor must be >= 1.5")
  
  if ( ! is.character(columns) ) stop("columns must be a string or a vector of strings")
  
  if ( ! is.character(selection) ) stop("selection must be a string")
  if ( length(selection) > 1 ) stop("selection must have only one element")

  if ( ! is.character(activate) ) stop("activate must be a character vector")
  
  if ( ! is.logical(doEntryColumns) ) stop("doEntryColumns must be a logical vector")
  
  ## Handle the columns
  ## If there is a ':' in the columns, then they must be split up
  ##  Use of ":" is the raw root syntax
  if (length(columns) == 1 && length(grep(":", columns)) ) {
    columns = strsplit(columns, ":")[[1]] # Split the columns
  }
  
  ## Add the prefix if necessary
  if ( ! missing(prefix) ) {
    columns = paste(prefix, columns, sep=".")

    if ( ! missing(activate) ) {
      stop("You cannot set both prefix and activate options simultaneously")
    }

    activate <- prefix
  }

  if ( ! missing(activate) ) {
    activate <- paste(activate, "*", sep="")
  }
  
  ## Get the data from Root
  ans = .Call("toR", rootChain@manager, 
    columns, selection,
    as.integer(nEntries), 
    as.integer(firstEntry),
    as.integer(initialSize),
    as.integer(maxSize),
    as.numeric(growthFactor),
    activate,
    doEntryColumns,
    doArrays,
    PACKAGE="RootTreeToR")
  
  isVerbose = getVerbose(rootChain)
  
  processToRResult(ans, isVerbose)                                                         
}

##################################
## toRUser -- run a user installed function
toRUser <- function(rootChain, userFunction, 
  nEntries=100, firstEntry=0, initialSize=1000,
  growthFactor=1.7, args=NULL) {
  
  .assertClass(rootChain, "RootChain")
  
        if ( initialSize <= 0 ) stop ("initialSize must be > 0")

  ## Growth factor had better be greater than 1.5
  if ( growthFactor < 1.5) stop ("growthFactor must be >= 1.5")
                
        if ( nEntries <= 0 ) nEntries = 99999099

  ## Check that C++ symbol is loaded
  if ( ! is.loaded( symbol.C(userFunction) ) ) stop("User function not loaded")
  
  ## Get the data from Root
  ans = .Call(symbol.C(userFunction), 
    rootChain@manager, 
    as.integer(nEntries), 
    as.integer(firstEntry),
    as.integer(initialSize),
    as.numeric(growthFactor), 
    args 
    )
  
  isVerbose = getVerbose(rootChain)
  
  processToRResult(ans, isVerbose)                                                                              
}

                                                                         

#################################
## Show
setMethod("show", "RootChain", 
          function(object) {
            cat("RootChain", object@tree, "with", length(object@files), "files", "\n")
            
            eventListName = getEventListName(object)
            if (! is.null(eventListName) )
              cat("  Chain is narrowed by event list", eventListName, "\n")
            
            if ( getVerbose(object) ) cat("  Verbosity is on\n")
            if ( getTrace(object) ) cat("  Trace is on\n")
            
          }
          )
