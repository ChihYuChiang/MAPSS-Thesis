"
### Distribution comparison
"
...DistComparison <- function() {}

#Function for distribution comparison
dist_compare <- function(construct, types, item, gap=0) {
  #A map for construct and item code and str pairs
  strCodec <- list(
    "Person"=list(
      item=c("1"="Extraversion", "2"="Agreeableness", "3"="Conscientiousness", "4"="Emotion stability", "5"="Openness", "sum"="Summation",
             "ab1"="Extraversion (absolute)", "ab2"="Agreeableness (absolute)", "ab3"="Conscientiousness (absolute)", "ab4"="Emotion stability (absolute)", "ab5"="Openness (absolute)", "absum"="Summation (absolute)"),
      type=c("InS"="In-game (self)", "OutS"="Real (self)", "IdS"="Ideal (self)", "InF"="In-game (fellow)", "OutF"="Real (fellow)", "SteS"="Stereotype (self)",
             "InSOutS"="In-game - real (self)", "InFOutF"="In-game - real (fellow)", "IdSInS"="Ideal - in-game (self)", "IdSOutS"="Ideal - real (self)", "InSSteS"="In-game - Stereo (self)", "OutSSteS"="Real - stereo (self)")
    ),
    "SDT"=list(
      item=c("1"="Autonomy", "2"="Relatedness", "3"="Competence", "sum"="Summation",
             "ab1"="Autonomy (absolute)", "ab2"="Relatedness (absolute)", "ab3"="Competence (absolute)", "absum"="Summation (absolute)"),
      type=c("In"="In-game", "Out"="Real", "Id"="Ideal",
             "InOut"="In-game - real", "IdIn"="Ideal - in-game", "IdOut"="Ideal - real")
    )
  )
  
  #Decide scales according to item and gap
  #Complication is bad!!!!!
  itemNo <- c("Person"=5, "SDT"=3)[construct]
  scales <- list(
    binwidth=if (item == "sum" | item == "absum") 0.5 * itemNo else 0.5,
    limits=if (gap == 1) {
      if (item == "sum" | item == "absum") c(-6 * itemNo - 0.5 * itemNo, 6 * itemNo + 0.5 * itemNo) else c(-6.5, 6.5)
    } else if (gap == 0) {
      if (item == "sum") c(1 * itemNo - 0.5 * itemNo, 7 * itemNo + 0.5 * itemNo) else c(0.5, 7.5)
    },
    breaks=if (gap == 1) {
      if (item == "sum" | item == "absum") seq(-6 * itemNo, 6 * itemNo, itemNo) else seq(-6, 6)
    } else if (gap == 0) {
      if (item == "sum") seq(1 * itemNo, 7 * itemNo, itemNo) else seq(1, 7)
    }
  )
  
  #Make individual hist
  make_hist <- function(type) {
    geom_histogram(mapping=aes_(x=as.name(sprintf("%s%s-%s", construct, type, item)), fill=toString(which(types == type))),
                   binwidth=scales$binwidth, alpha=0.6)
  }
  
  #Make hist list of all items
  geom_hists <- lapply(types, make_hist)
  
  #Use the list to add ggplot components
  ggplot(data=DT) +
    geom_hists +
    scale_x_continuous(breaks=scales$breaks, minor_breaks=NULL, labels=scales$breaks, limits=scales$limits) +
    labs(x="score", title=strCodec[[construct]]$item[toString(item)]) +
    scale_fill_manual(values=diverge_hcl(length(types)), name="Item", labels=unname(strCodec[[construct]]$type[unlist(types)])) + #labels does not accept names vector
    theme_minimal()
}


#--Function for dist
dist_gen <- function(targetColName) {
  ggplot(data=DT[, targetColName, with=FALSE]) +
    geom_histogram(mapping=aes_(x=as.name(targetColName)),
                   bins=15, alpha=0.65) +
    labs(title=targetColName) +
    theme_minimal()
}




"
### T-test
"
...TTest <- function() {}

tTest <- function(construct, types, item) {
  col1 <- sprintf("%s%s-%s", construct, types[1], item)
  col2 <- sprintf("%s%s-%s", construct, types[2], item)
  
  #DT does not accept as.name (symbol); it requires object
  testOutput <- t.test(DT[, get(col1)], DT[, get(col2)], paired=TRUE)
  
  #Rename the caption of output table
  testOutput$data.name <- paste(col1, "and", col2, sep=" ")
  
  #Use pander_return to preserve the string in rmd format
  testOutput <- pander_return(testOutput, style="rmarkdown")
  
  #Transform rmd into html and add class for proper display
  testOutput <- sub("<table>", '<table class="table" style="width: 80%">', markdownToHTML(text=testOutput, fragment.only=TRUE))
  
  return(testOutput)
}




"
### Double Lasso selection
"
...DLS <- function() {}

#--Function for updating lambda used in selection
#n = number of observation; p = number of independent variables; se = standard error of residual or dependent variable
updateLambda <- function(n, p, se) {se * (1.1 / sqrt(n)) * qnorm(1 - (.1 / log(n)) / (2 * p))}


#--Function for acquiring the indices of the selected variables in df_x
#df_x = matrix with only variables to be tested; y = dependent variable or treatment variables; lambda = the initial lambda computed in advance 
acquireBetaIndices <- function(df_x, y, lambda, n, p) {
  #glmnet accept only matrix not df
  df_x <- as.matrix(df_x)
  
  #Update lambda k times, k is selected based on literature
  k <- 1
  while(k < 15) {
    model_las <- glmnet(x=df_x, y=y, alpha=1, lambda=lambda, standardize=TRUE)
    beta <- coef(model_las)
    residual.se <- sd(y - predict(model_las, df_x))
    lambda <- updateLambda(n=n, p=p, se=residual.se)
    k <- k + 1
  }
  
  #Return the variable indices with absolute value of beta > 0
  return(which(abs(beta) > 0))
}


#--Function to perform double lasso selection
#output = a new df with variables selected
lassoSelect <- function(df, ytreatment, test, outcome) {
  #--Setting up
  df_ytreatment <- df[, ..ytreatment]
  df_test <- df[, ..test]
  c_outcome <- df[[outcome]]
  
  #The number of observations
  n <- nrow(df_test)
  
  #The number of variables to be tested
  p <- ncol(df_test)
  
  
  #--Select vars that predict outcome
  #Lambda is initialized as the se of residuals of a simple linear using only treatments predicting dependent variable
  #If the treatment var is NULL, use the se pf dependent var to initiate
  residual.se <- if(ncol(df_ytreatment) == 1) {sd(c_outcome)} else {sd(residuals(lm(as.formula(sprintf("`%s` ~ .", outcome)), data=df_ytreatment)))}
  lambda <- updateLambda(n=n, p=p, se=residual.se)
  
  #by Lasso model: dependent variable ~ test variables
  betaIndices <- acquireBetaIndices(df_x=df_test, y=c_outcome, lambda=lambda, n=n, p=p)
  
  
  #--Select vars that predict treatments
  #Each column of the treatment variables as the y in the Lasso selection
  #Starting from 2 because 1 is the dependent variable
  if(ncol(df_ytreatment) != 1) { #Run only when treatment vars not NULL
    for(i in seq(2, ncol(df_ytreatment))) {
      #Acquire target treatment variable
      c_treatment <- df_ytreatment[[i]]
      
      #Lambda is initialized as the se of the target treatment variable
      c_treatment.se <- sd(c_treatment)
      lambda <- updateLambda(n=n, p=p, se=c_treatment.se)
      
      #Acquire the indices and union the result indices of each treatment variable
      betaIndices <- union(betaIndices, acquireBetaIndices(df_x=df_test, y=c_treatment, lambda=lambda, n=n, p=p))
    }
  }
  
  
  #Process the result indices to remove the first term (the intercept term)
  betaIndices <- setdiff((betaIndices - 1), 0)
  
  #Bind the selected variables with dependent and treatment variables
  df_selected <- if(nrow(df_test[, ..betaIndices]) == 0) df_ytreatment else cbind(df_ytreatment, df_test[, ..betaIndices])
  
  #Return a new df with variables selected
  return(df_selected)
}


#--Identify vars to be processed
#Function to make obj expression of a string vector
objstr <- function(ss) {
  ss_obj <- character()
  for(s in ss) ss_obj <- c(ss_obj, sub(":", "`:`", sprintf("`%s`", s)))
  return(ss_obj)
}

#Function to remove obj expression of a df
deobjdf <- function(df) {
  ss_deobj <- character()
  for(s in names(df)) ss_deobj <- c(ss_deobj, gsub("`", "", x=s))
  names(df) <- ss_deobj
  return(df)
}

#Function to produce expanded dts
expandDt <- function(outcome, treatment, test) {
  output <- sprintf("~%s", paste(c(treatment %>% objstr, test %>% objstr), collapse="+")) %>%
    as.formula %>%
    model.matrix(data=DT) %>%
    as.data.table %>%
    deobjdf %>%
    cbind(DT[, outcome, with=FALSE])
  output[, -1] #-1 to remove the intersection term created by matrix
}


#--Multiple set var wrappers
#lassoSelect
lassoSelect_multi <- function(df, treatment, test, outcome) {
  output <- list()
  for(i in 1:length(df)) {
    ytreatment <- union(treatment[[i]], outcome[[i]])
    output[[i]] <- lassoSelect(df=df[[i]], ytreatment=ytreatment, test=test[[i]], outcome=outcome[[i]])
  }
  return(output)
}

#expandDt
expandDt_multi <- function(outcome, treatment, test) {
  output <- list()
  for(i in 1:length(outcome)) output[[i]] <- expandDt(na.omit(outcome[[i]]), na.omit(treatment[[i]]), na.omit(test[[i]]))
  return(output)
}

#lm
lm_multi <- function(outcome, data) {
  output <- list()
  for(i in 1:length(outcome)) output[[i]] <- lm(as.formula(sprintf("`%s` ~ .", outcome[[i]])), data=data[[i]])
  return(output)
}


#--Function save selected value
updateDlsVar <- function(id, cur) {
  #Get var from server.R frame
  input <- get("input", parent.frame())
  session <- get("session", parent.frame())
  
  #Save selected value
  selectedVar <- c(input$var_dls_1, input$var_dls_2, input$var_dls_3, input$var_dls_4, input$var_dls_5, input$var_dls_6) %>%
    na.omit()
  
  #Check input
  switch(id,
         "1"={if(length(selectedVar) > 1) {shinyjs::alert(DLS$PH1); return(cur)}},
         "3"={if(length(selectedVar) > 0 & length(selectedVar) < 2) {shinyjs::alert(DLS$PH3); return(cur)}}
  )
  
  #Clean selection
  map(c("var_dls_1", "var_dls_2", "var_dls_3", "var_dls_4", "var_dls_5", "var_dls_6"),
      ~ updateCheckboxGroupInput(session, inputId=., selected=character(0)))
  
  return(unlist(selectedVar))
}




"
### General
"
...General <- function() {}

#--Function produces dynamic codec for non-codec section
produceCodec <- function(targetColName) {
  #Hide table when nothing is selected and rv has no values
  if(length(targetColName) == 0) return(NULL)
  
  #Acquire description of specific vars
  filter <- codec$Variable %in% targetColName
  
  #When no match, additionally show the synthetic ones
  syn <- sum(!(targetColName %in% codec$Variable))
  subCodec <- if(syn) rbind(codec[filter], tail(codec, 6)) else codec[filter]
  
  return(subCodec)
}


#--Multiple plot function (Modify from Cookbook for R)
# ggplot objects can be passed in ..., or to plotlist (as a list of ggplot objects)
# - cols:   Number of columns in layout
# - layout: A matrix specifying the layout. If present, 'cols' is ignored.
#
# If the layout is something like matrix(c(1,2,3,3), nrow=2, byrow=TRUE),
# then plot 1 will go in the upper left, 2 will go in the upper right, and
# 3 will go all the way across the bottom.

multiplot <- function(..., plotlist=NULL, file, cols=1) {
  library(grid)
  
  # Make a list from the ... arguments and plotlist
  plots <- c(list(...), plotlist)
  
  numPlots = length(plots)
  
  # Make the panel
  # ncol: Number of columns of plots
  # nrow: Number of rows needed, calculated from # of cols
  layout <- matrix(seq(1, cols * ceiling(numPlots/cols)),
                   ncol = cols, nrow = ceiling(numPlots/cols))
  
  # Set up the page
  grid.newpage()
  pushViewport(viewport(layout = grid.layout(nrow(layout), ncol(layout))))
  
  # Make each plot, in the correct location
  for (i in 1:numPlots) {
    # Get the i,j matrix positions of the regions that contain this subplot
    matchidx <- as.data.frame(which(layout == i, arr.ind = TRUE))
    
    print(plots[[i]], vp = viewport(layout.pos.row = matchidx$row,
                                    layout.pos.col = matchidx$col))
  }
}