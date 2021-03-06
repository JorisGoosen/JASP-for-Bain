#
# Copyright (C) 2013-2015 University of Amsterdam
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

BainTTestBayesianIndependentSamples <- function(jaspResults, dataset, options, ...) {
		### READY ###
		ready <- length(options[["variables"]][options[["variables"]] != ""] > 0) && options[["groupingVariable"]] != ""

		### READ DATA ###
		readList											<- .readDataBainTwoSample(options, dataset)
		dataset                       <- readList[["dataset"]]
		missingValuesIndicator        <- readList[["missingValuesIndicator"]]

    ### RESULTS ###
    .bainIndependentSamplesResultsTable(dataset, options, jaspResults, missingValuesIndicator, ready)

    ### DESCRIPTIVES ###
		.bainIndependentSamplesDescriptivesTable(dataset, options, jaspResults, ready)

		### BAYES FACTOR PLOTS ###
		.bainOneSampleBayesFactorPlots(dataset, options, jaspResults, ready)

		### DESCRIPTIVES PLOTS ###
		.bainIndependentSamplesDescriptivesPlots(dataset, options, jaspResults, ready)
}

.bainIndependentSamplesResultsTable <- function(dataset, options, jaspResults, missingValuesIndicator, ready) {

  if(!is.null(jaspResults[["bainTable"]])) return() #The options for this table didn't change so we don't need to rebuild it

  bainTable                      <- createJaspTable("Bain Independent Samples Welch's T-Test Result")
  jaspResults[["bainTable"]]     <- bainTable
  bainTable$dependOn(c("variables", "hypothesis", "bayesFactorType", "groupingVariable"))
	bainTable$position <- 1

  bf.type <- options$bayesFactorType
  BFH1H0 <- FALSE
  bf.title <- "BF"

  if(options$hypothesis == "allTypes"){
          bainTable$addColumnInfo(name="Variable", type="string", title="")
          bainTable$addColumnInfo(name = "type[equal]", type = "string", title = "Hypothesis")
          bainTable$addColumnInfo(name="BF[equal]", type="number", format="sf:4;dp:3", title=bf.title)
          bainTable$addColumnInfo(name="pmp[equal]", type="number", format="dp:3", title="Posterior probability")
          bainTable$addColumnInfo(name = "type[greater]", type = "string", title = "Hypothesis")
          bainTable$addColumnInfo(name="BF[greater]", type="number", format="sf:4;dp:3", title="bf.title")
          bainTable$addColumnInfo(name="pmp[greater]", type="number", format="dp:3", title="Posterior probability")
          bainTable$addColumnInfo(name = "type[less]", type = "string", title = "Hypothesis")
          bainTable$addColumnInfo(name = "BF[less]", type = "number", format="sf:4;dp:3", title = bf.title)
          bainTable$addColumnInfo(name="pmp[less]", type="number", format="dp:3", title="Posterior probability")
  } else {
          bainTable$addColumnInfo(name="Variable", type="string", title="")
          bainTable$addColumnInfo(name = "hypothesis[type1]", type = "string", title = "Hypothesis")
          bainTable$addColumnInfo(name="BF[type1]", type="number", format="sf:4;dp:3", title=bf.title)
          bainTable$addColumnInfo(name="pmp[type1]", type="number", format="dp:3", title="Posterior probability")
          bainTable$addColumnInfo(name = "hypothesis[type2]", type = "string", title = "Hypothesis")
          bainTable$addColumnInfo(name="BF[type2]", type="number", format="sf:4;dp:3", title=bf.title)
          bainTable$addColumnInfo(name="pmp[type2]", type="number", format="dp:3", title="Posterior probability")
  }
	
	type <- base::switch(options[["hypothesis"]],
													"groupsNotEqual"		= 1,
													"groupTwoGreater"		= 2,
													"groupOneGreater"		= 3,
													"_4type"						= 4,
													"allTypes"					= 5)
	message <- base::switch(options[["hypothesis"]],
														"groupsNotEqual"		= "The alternative hypothesis H1 specifies that the mean of group 1 is unequal to the mean of group 2. The posterior probabilities are based on equal prior probabilities.",
														"groupTwoGreater"		= "The alternative hypothesis H1 specifies that the mean of group 1 is smaller than the mean of group 2. The posterior probabilities are based on equal prior probabilities.",
														"groupOneGreater"		= "The alternative hypothesis H1 specifies that mean of group 1 is bigger than the mean of group 2. The posterior probabilities are based on equal prior probabilities.",
														"_4type"						= "The hypothesis H1 specifies that the mean of group 1 is bigger than the mean of group 2. The hypothesis H2 specifies that the mean in group 1 is smaller than the mean in group 2. The posterior probabilities are based on equal prior probabilities.",
														"allTypes"					= "The null hypothesis H0 (equal group means) is tested against H1 (first mean larger than second mean) and H2 (first mean smaller than second mean). The posterior probabilities are based on equal prior probabilities.")
  bainTable$addFootnote(message=message, symbol="<i>Note.</i>")

	bainTable$addCitation("Gu, X., Mulder, J., and Hoijtink, H. (2017). Approximate adjusted fractional Bayes factors: A general method for testing informative hypotheses. British Journal of Mathematical and Statistical Psychology. DOI:10.1111/bmsp.12110")
	bainTable$addCitation("Hoijtink, H., Mulder, J., van Lissa, C., and Gu, X. (2018). A Tutorial on testing hypotheses using the Bayes factor. Psychological Methods.")
	bainTable$addCitation("Hoijtink, H., Gu, X., and Mulder, J. (2018). Bayesian evaluation of informative hypotheses for multiple populations. Britisch Journal of Mathematical and Statistical Psychology. DOI: 10.1111/bmsp.12145")

	if(!ready)
		return()

  jaspResults$startProgressbar(length(options[["variables"]]))
  bainResult <- list()
  levels <- base::levels(dataset[[ .v(options[["groupingVariable"]]) ]])
  if (length(levels) != 2) {
	  g1 <- "1"
	  g2 <- "2"
  } else {
	  g1 <- levels[1]
	  g2 <- levels[2]
  }

  for (variable in options[["variables"]]){

		if(variable %in% missingValuesIndicator){
			bainTable$addFootnote(message= paste0("The variable ", variable, " contains missing values, the rows containing these values are removed in the analysis."), symbol="<b>Warning.</b>")
		}

	  subDataSet <- dataset[, c(.v(variable), .v(options[["groupingVariable"]]))]
	  subDataSet <- na.omit(subDataSet)
	  group2 <- subDataSet[subDataSet[[.v(options[["groupingVariable"]])]]== g1,.v(variable)]
	  group1 <- subDataSet[subDataSet[[.v(options[["groupingVariable"]])]]== g2,.v(variable)]

	  p <- try({

      	bainAnalysis <- Bain::Bain_ttestData(group1, group2, type = type)
      	bainResult[[variable]] <- bainAnalysis

	})

	if(class(p) == "try-error"){
		bainTable$setError("An error occurred in the analysis. Please double check your variables.")
		return()
	}

    if(type == 1){
        BF_0u <- bainAnalysis$BF_0u
        PMP_u <- bainAnalysis$PMP_u
        PMP_0 <- bainAnalysis$PMP_0
        if(options$bayesFactorType == "BF10")
          BF_0u <- 1/BF_0u
    }
    if(type == 2){
        BF_01 <- bainAnalysis$BF_01
        PMP_1 <- bainAnalysis$PMP_1
        PMP_0 <- bainAnalysis$PMP_0
        if(options$bayesFactorType == "BF10")
            BF_01 <- 1/BF_01
    }
    if(type == 3){
        BF_01 <- bainAnalysis$BF_01
        PMP_0 <- bainAnalysis$PMP_0
        PMP_1 <- bainAnalysis$PMP_1
        if(options$bayesFactorType == "BF10")
            BF_01 <- 1/BF_01
    }
     if (type == 4){
        BF_01 <- bainAnalysis$BF_12
        PMP_0 <- bainAnalysis$PMP_1
        PMP_1 <- bainAnalysis$PMP_2
        if(options$bayesFactorType == "BF01")
            BF_01 <- 1/BF_01
    }
     if (type == 5){
        BF_01 <- bainAnalysis$BF_01
        BF_02 <- bainAnalysis$BF_02
        BF_12 <- bainAnalysis$BF_12
        PMP_0 <- bainAnalysis$PMP_0
        PMP_1 <- bainAnalysis$PMP_1
        PMP_2 <- bainAnalysis$PMP_2
        if(options$bayesFactorType == "BF10")
        {
            BF_01 <- 1/BF_01
            BF_02 <- 1/BF_02
            BF_12 <- 1/BF_12
        }
    }

    if(options$bayesFactorType == "BF01"){
        if(options$hypothesis == "groupsNotEqual"){
            row <- list(Variable=variable, "hypothesis[type1]" = "H0: Equal","BF[type1]"=.clean(BF_0u), "pmp[type1]" = .clean(PMP_0),
                                "hypothesis[type2]" = "H1: Not equal", "BF[type2]" = "", "pmp[type2]" = .clean(PMP_u))
        } else if(options$hypothesis == "groupOneGreater"){
            row <-list(Variable=variable, "hypothesis[type1]" = "H0: Equal","BF[type1]"=.clean(BF_01), "pmp[type1]" = .clean(PMP_0),
                               "hypothesis[type2]" = "H1: Bigger", "BF[type2]" = "", "pmp[type2]" = .clean(PMP_1))
        } else if(options$hypothesis == "groupTwoGreater"){
            row <-list(Variable=variable, "hypothesis[type1]" = "H0: Equal", "BF[type1]"=.clean(BF_01), "pmp[type1]" = .clean(PMP_0),
                               "hypothesis[type2]" = "H1: Smaller", "BF[type2]" = "", "pmp[type2]" = .clean(PMP_1))
        } else if (options$hypothesis == "_4type"){
            row <-list(Variable=variable, "hypothesis[type1]" = "H1: Bigger", "BF[type1]"=.clean(BF_01), "pmp[type1]" = .clean(PMP_1),
                               "hypothesis[type2]" = "H2: Smaller", "BF[type2]" = "", "pmp[type2]" = .clean(PMP_0))
        } else if (options$hypothesis == "allTypes"){
            row <-list(Variable=variable,
                               "type[equal]" = "H0: Equal",
                               "BF[equal]"= "",
                               "pmp[equal]" = .clean(PMP_0),
                               "type[greater]" = "H1: Bigger",
                               "BF[greater]" = .clean(BF_02),
                               "pmp[greater]" = .clean(PMP_2),
                               "type[less]" = "H2: Smaller",
                               "BF[less]" = .clean(BF_01),
                               "pmp[less]" = .clean(PMP_1))
        }
    } else if (options$bayesFactorType == "BF10"){
        if(options$hypothesis == "groupsNotEqual"){
            row <- list(Variable=variable, "hypothesis[type1]" = "H0: Equal","BF[type1]"="", "pmp[type1]" = .clean(PMP_0),
                                "hypothesis[type2]" = "H1: Not equal", "BF[type2]" = .clean(BF_0u), "pmp[type2]" = PMP_u)
        } else if(options$hypothesis == "groupOneGreater"){
            row <-list(Variable=variable, "hypothesis[type1]" = "H0: Equal","BF[type1]"="", "pmp[type1]" = .clean(PMP_0),
                               "hypothesis[type2]" = "H1: Bigger", "BF[type2]" = .clean(BF_01), "pmp[type2]" = .clean(PMP_1))
        } else if(options$hypothesis == "groupTwoGreater"){
            row <-list(Variable=variable, "hypothesis[type1]" = "H0: Equal", "BF[type1]"="", "pmp[type1]" = .clean(PMP_0),
                               "hypothesis[type2]" = "H1: Smaller", "BF[type2]" = .clean(BF_01), "pmp[type2]" = .clean(PMP_1))
        } else if (options$hypothesis == "_4type"){
            row <-list(Variable=variable, "hypothesis[type1]" = "H1: Bigger", "BF[type1]"= "", "pmp[type1]" = .clean(PMP_1),
                               "hypothesis[type2]" = "H2: Smaller", "BF[type2]" = .clean(BF_01), "pmp[type2]" = .clean(PMP_0))
        } else if (options$hypothesis == "allTypes"){
            row <-list(Variable=variable,
                               "type[equal]" = "H0: Equal",
                               "BF[equal]"= "",
                               "pmp[equal]" = .clean(PMP_0),
                               "type[greater]"= "H1: Bigger",
                               "BF[greater]" = .clean(BF_02),
                               "pmp[greater]" = .clean(PMP_2),
                               "type[less]" = "H2: Smaller",
                               "BF[less]" = .clean(BF_01),
                               "pmp[less]" = .clean(PMP_1))
        }
    }
    bainTable$addRows(row)
	  jaspResults$progressbarTick()
  }
  jaspResults[["bainResult"]] <- createJaspState(bainResult)
  jaspResults[["bainResult"]]$copyDependenciesFromJaspObject(bainTable)
}

.bainIndependentSamplesDescriptivesTable <- function(dataset, options, jaspResults, ready) {

  if(!is.null(jaspResults[["descriptivesTable"]])) return() #The options for this table didn't change so we don't need to rebuild it
		if(options[["descriptives"]]){

	  descriptivesTable                                            <- createJaspTable("Descriptive Statistics")
	  jaspResults[["descriptivesTable"]]                           <- descriptivesTable
	  descriptivesTable$dependOn(c("variables", "descriptives", "descriptivesPlotsCredibleInterval", "groupingVariable"))
		descriptivesTable$position <- 2

	  descriptivesTable$addColumnInfo(name="v",                    title = "", type="string")
		descriptivesTable$addColumnInfo(name="group",                title = "Group", type="string")
	  descriptivesTable$addColumnInfo(name="N",                    title = "N", type="Integer")
	  descriptivesTable$addColumnInfo(name="mean",                 title = "Mean", type="number", format="sf:4;dp:3")
	  descriptivesTable$addColumnInfo(name="sd",                   title = "sd", type="number", format="sf:4;dp:3")
	  descriptivesTable$addColumnInfo(name="se",                   title = "se", type="number", format="sf:4;dp:3")

		interval <- 100 * options[["descriptivesPlotsCredibleInterval"]]
		overTitle <- paste0(interval, "% Credible Interval")
		descriptivesTable$addColumnInfo(name="lowerCI",              title = "lowerCI", type="number", format="sf:4;dp:3", overtitle = overTitle)
	  descriptivesTable$addColumnInfo(name="upperCI",              title = "upperCI", type="number", format="sf:4;dp:3", overtitle = overTitle)

		if(!ready)
			return()

		levels <- base::levels(dataset[[ .v(options$groupingVariable) ]])
		if (length(levels) != 2) {
			g1 <- "1"
			g2 <- "2"
		} else {
			g1 <- levels[1]
			g2 <- levels[2]
		}

	for(variable in options[["variables"]]){
		for (i in 1:2) {

	  	level <- levels[i]
	  	variableData <- dataset[[.v(variable)]]
			groupingData <- dataset[[.v(options$groupingVariable)]]
			groupData <- variableData[groupingData == level]
			groupDataOm <- na.omit(groupData)

			if (class(groupDataOm) != "factor") { # TODO: Fix this...
				posteriorSummary <- .posteriorSummaryGroupMean(variable=groupDataOm, descriptivesPlotsCredibleInterval=options$descriptivesPlotsCredibleInterval)
				ciLower <- .clean(round(posteriorSummary$ciLower,3))
				ciUpper <- .clean(round(posteriorSummary$ciUpper,3))
				n <- .clean(length(groupDataOm))
		  	mean <- .clean(mean(groupDataOm))
		  	std <- .clean(sd(groupDataOm))
		  	sem <- .clean(sd(groupDataOm) / sqrt(length(groupDataOm)))
				if(i == 1)
					row <- data.frame(v = variable, group = level, N = n, mean = mean, sd = std, se = sem, lowerCI = ciLower, upperCI = ciUpper)
				if(i == 2)
					row <- data.frame(v = "", group = level, N = n, mean = mean, sd = std, se = sem, lowerCI = ciLower, upperCI = ciUpper)

				} else {
						n <- .clean(length(groupDataOm))
						row <- data.frame(v = variable, group = "", N = n, mean = "", sd = "", se = "", lowerCI = "", upperCI = "")
				}
				descriptivesTable$addRows(row)
			}	
  	}
	}
}

.bainIndependentSamplesDescriptivesPlots <- function(dataset, options, jaspResults, ready){
	if(options[["descriptivesPlots"]] && ready){
			if(is.null(jaspResults[["descriptivesPlots"]])){
			jaspResults[["descriptivesPlots"]]          <- createJaspContainer("Descriptive Plots")
			jaspResults[["descriptivesPlots"]]          $dependOn(c("variables", "testValue", "descriptivesPlots", "descriptivesPlotsCredibleInterval", "groupingVariable"))
			jaspResults[["descriptivesPlots"]]			    $position <- 4
			}
			for (variable in unlist(options[["variables"]])){
					if(is.null(jaspResults[["descriptivesPlots"]][[variable]]))
					{
						levels <- base::levels(dataset[[ .v(options$groupingVariable) ]])
						if (length(levels) != 2) {
							g1 <- "1"
							g2 <- "2"
						} else {
							g1 <- levels[1]
							g2 <- levels[2]
						}
						subDataSet <- dataset[, c(.v(variable), .v(options$groupingVariable))]
						subDataSet <- na.omit(subDataSet)
						group2 <- subDataSet[subDataSet[[.v(options$groupingVariable)]]== g1,.v(variable)]
						group1 <- subDataSet[subDataSet[[.v(options$groupingVariable)]]== g2,.v(variable)]
					
						ggplotObj <- .plot2GroupMeansBayesIndTtest(v1 = group2, v2 = group1, nameV1 = g1, nameV2 = g2,
									groupingName = options$groupingVariable, dependentName = variable,
									descriptivesPlotsCredibleInterval=options$descriptivesPlotsCredibleInterval)
						jaspResults[["descriptivesPlots"]][[variable]]        <- createJaspPlot(plot=ggplotObj, title = variable)
						jaspResults[["descriptivesPlots"]][[variable]]        $setOptionMustContainDependency("variables", variable)
					}
			}
	} else if(options[["descriptivesPlots"]]){
		errorPlot <- createJaspPlot(plot = NULL, title = "Descriptives Plots")
		errorPlot$setError("Plotting not possible: No analysis has been run.")
		jaspResults[["descriptivesPlots"]] <- errorPlot
		jaspResults[["descriptivesPlots"]]$dependOn(c("variables", "descriptivesPlots","groupingVariable"))
		jaspResults[["descriptivesPlots"]]$position <- 4
	}	
}

.readDataBainTwoSample <- function(options, dataset){

	all.variables 									<- unlist(options$variables)
	grouping   										<- options$groupingVariable
	read.variables 									<- c(all.variables, grouping)
	if (options[["groupingVariable"]] == "")
		grouping <- NULL

	if (is.null(dataset)){
						trydata                	<- .readDataSetToEnd(columns.as.numeric=all.variables)
						missingValuesIndicator 	<- .unv(names(which(apply(trydata, 2, function(x){ any(is.na(x))} ))))
            dataset 								<- .readDataSetToEnd(columns.as.numeric=all.variables, columns.as.factor=grouping, exclude.na.listwise=read.variables)
    }
	.hasErrors(dataset=dataset, perform=perform, type="factorLevels",
			   factorLevels.target=grouping, factorLevels.amount = "!= 2",
			   exitAnalysisIfErrors = TRUE)
	.hasErrors(dataset, perform, type=c("infinity", "variance", "observations"),
				all.target=all.variables, message="short", observations.amount="< 3",
				exitAnalysisIfErrors = TRUE)
	readList <- list()
  readList[["dataset"]] <- dataset
  readList[["missingValuesIndicator"]] <- missingValuesIndicator
	return(readList)
}
