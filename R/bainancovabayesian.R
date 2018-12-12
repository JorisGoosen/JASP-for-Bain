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

BainAncovaBayesian	 <- function (jaspResults, dataset, options, state=NULL) {
	# Read in data and check for errors
	readList 								<- .readDataBainAncova(options, dataset)
	dataset                                         <- readList[["dataset"]]
	missingValuesIndicator                          <- readList[["missingValuesIndicator"]]
	# Null state
	if(is.null(state))
	  state 								<- list()
	# Pass the title
	jaspResults$title 						<- "Bain ANCOVA"
	# Create the main results table
	.bainANCOVATable(dataset, options, jaspResults, missingValuesIndicator)
	# Save analysis result in state
	bainResult 								<- jaspResults[["bainResult"]]$object
	# Legend Table
	.bainLegendAncova(dataset, options, jaspResults)
	# Bayes factor matrix
	if (options$BFmatrix)
	{
		if(is.null(jaspResults[["Bainmatrix"]]))
			.BainBFmatrix(dataset, options, jaspResults, bainResult, type = "ancova")
	}
	# Coefficients
	if (options$coefficients)
	{
		if(is.null(jaspResults[["coefficients"]]))
			.bainCoefficients(dataset, options, jaspResults, bainResult)
	}
	# Bayes factor plot
	if(options$BFplot)
    {
        if(is.null(jaspResults[["BFplot"]]))
        {
        	jaspResults[["BFplot"]] 			<- .bainANCOVAPlot(dataset, options, bainResult, "Bayes Factor Comparison")
        	jaspResults[["BFplot"]]				$dependOnOptions(c("dependent", "fixedFactors", "covariates", "BFplot", "model"))
					jaspResults[["BFplot"]]				$position <- 4
		}
	}
	# Descriptives plot
	if(options$plotDescriptives)
	{
		if(is.null(jaspResults[["descriptivesPlot"]])){
			jaspResults[["descriptivesPlot"]] 	<- createJaspPlot(plot= .bainDescriptivesPlot(dataset, bainResult, options, type = "ancova"),
												title="Descriptives Plot", width = options$plotWidth, height = options$plotHeight)
			jaspResults[["descriptivesPlot"]]	$dependOnOptions(c("dependent", "fixedFactors", "plotDescriptives", "covariates"))
			jaspResults[["descriptivesPlot"]] $position <- 5
		}
	}
	# Save the state
	state[["options"]] <- options
	return(state)
}

.bainANCOVATable <- function(dataset, options, jaspResults, missingValuesIndicator){

	if(!is.null(jaspResults[["bainTable"]])) return() #The options for this table didn't change so we don't need to rebuild it

	variables 											<- c(options$dependent, options$fixedFactors, unlist(options$covariates))
	dependent 											<- .v(options$dependent)
	group 													<- .v(options$fixedFactors)
	covariates 											<- .v(options$covariates)
	bainTable                      	<- createJaspTable("Bain ANCOVA Result")
	jaspResults[["bainTable"]]     	<- bainTable

	bainTable$dependOnOptions(c("dependent", "fixedFactors", "covariates", "model"))

	bainTable$addColumnInfo(name="hypotheses", 				type="string", title="")
	bainTable$addColumnInfo(name="BF", 						type="number", format="sf:4;dp:3", title= "BF.c")
	bainTable$addColumnInfo(name="PMP1", 					type="number", format="sf:4;dp:3", title= "PMP a")
	bainTable$addColumnInfo(name="PMP2", 					type="number", format="sf:4;dp:3", title= "PMP b")
	bainTable$position <- 1

	message <-  "BF.c denotes the Bayes factor of the hypothesis in the row versus its complement.
				Posterior model probabilities (a: excluding the unconstrained hypothesis, b: including the unconstrained hypothesis) are based on equal prior model probabilities."
	bainTable$addFootnote(message=message, symbol="<i>Note.</i>")

	if(any(variables %in% missingValuesIndicator)){
		i <- which(variables %in% missingValuesIndicator)
		if(length(i) > 1){
			bainTable$addFootnote(message= paste0("The variables ", paste(variables[i], collapse = ", "), " contain missing values, the rows containing these values are removed in the analysis."), symbol="<b>Warning.</b>")
		} else if (length(i) == 1){
			bainTable$addFootnote(message= paste0("The variable ", variables[i], " contains missing values, the rows containing these values are removed in the analysis."), symbol="<b>Warning.</b>")
		}
	}

	bainTable$addCitation("Gu, X., Mulder, J., and Hoijtink, H. (2017). Approximate adjusted fractional Bayes factors: A general method for testing informative hypotheses. British Journal of Mathematical and Statistical Psychology. DOI:10.1111/bmsp.12110")
	bainTable$addCitation("Hoijtink, H., Mulder, J., van Lissa, C., and Gu, X. (2018). A Tutorial on testing hypotheses using the Bayes factor. Psychological Methods.")
	bainTable$addCitation("Hoijtink, H., Gu, X., and Mulder, J. (2018). Bayesian evaluation of informative hypotheses for multiple populations. Britisch Journal of Mathematical and Statistical Psychology. DOI: 10.1111/bmsp.12145")

	bain.variables <- c(unlist(options$dependent),
						unlist(options$covariates)[1],
						unlist(options$fixedFactors))
	bain.variables <- bain.variables[bain.variables != ""]

 	if(length(bain.variables) > 2){

		groupVars <- options$fixedFactors
		groupVars <- unlist(groupVars)
		groupCol <- dataset[ , .v(groupVars)]
		varLevels <- levels(groupCol)

		if(length(varLevels) > 15){

			message <- "The fixed factor has too many levels for a Bain analysis."
			bainTable$errorMessage <- message
			bainTable$error <- "badData"
			return()

		}

		if(options$model == ""){

			# We have to make a default matrix depending on the levels of the grouping variable...meh
			# The default hypothesis is that all groups are equal (e.g., 3 groups, "p1=p2=p3")
			groupVars <- options$fixedFactors
			groupVars <- unlist(groupVars)

			groupCol <- dataset[ , .v(groupVars)]
			varLevels <- levels(groupCol)

			len <- length(varLevels)

			null.mat <- matrix(0, nrow = (len-1), ncol = (len+1))
			indexes <- row(null.mat) - col(null.mat)
			null.mat[indexes == 0] <- 1
			null.mat[indexes == -1] <- -1

			ERr <- null.mat
		    IRr<-NULL

			p <- try({

				bainResult <- Bain::Bain_ancova(X = dataset, dep_var = dependent, covariates = covariates, group = group, ERr, IRr)
				jaspResults[["bainResult"]] <- createJaspState(bainResult)
				jaspResults[["bainResult"]]$dependOnOptions(c("dependent", "fixedFactors", "covariates", "model"))

			})

		} else {

			jaspResults$startProgressbar(3)
			jaspResults$progressbarTick()

			rest.string <- options$model
			rest.string <- gsub("\n", ";", rest.string)

			jaspResults$progressbarTick()

			inpt <- list()
			names(dataset) <- .unv(names(dataset))
			inpt[[1]] <- dataset
			inpt[[2]] <- .unv(dependent)
			inpt[[3]] <- .unv(covariates)
			inpt[[4]] <- .unv(group)
			inpt[[5]] <- rest.string

			p <- try({

				bainResult <- Bain::Bain_ancova_cm(X = inpt[[1]], dep_var = inpt[[2]], covariates = inpt[[3]], group = inpt[[4]], hyp = inpt[[5]])
				jaspResults[["bainResult"]] <- createJaspState(bainResult)
				jaspResults[["bainResult"]]$dependOnOptions(c("dependent", "fixedFactors", "covariates", "model"))

			})
		}

		if(class(p) == "try-error"){

			message <- "An error occurred in the analysis. Please make sure your hypotheses are formulated correctly."
			bainTable$errorMessage <- message
			bainTable$error <- "badData"
			return()

		} else {

			jaspResults$progressbarTick()

			BF <- bainResult$BF

			for(i in 1:length(BF)){
				row <- list(hypotheses = paste0("H",i), BF = .clean(BF[i]), PMP1 = .clean(bainResult$PMPa[i]), PMP2 = .clean(bainResult$PMPb[i]))
				bainTable$addRows(row)
			}
			row <- list(hypotheses = "Hu", BF = "", PMP1 = "", PMP2 = .clean(1-sum(bainResult$PMPb)))
			bainTable$addRows(row)

		}

	} else {

			row <- list(hypotheses = "H1", BF = ".", PMP1 = ".", PMP2 = ".")
			bainTable$addRows(row)
			row <- list(hypotheses = "Hu", BF = ".", PMP1 = ".", PMP2 = ".")
			bainTable$addRows(row)

		}
}

.BainBFmatrix <- function(dataset, options, jaspResults, bainResult, type){

	if(!is.null(jaspResults[["Bainmatrix"]])) return() #The options for this table didn't change so we don't need to rebuild it

	Bainmatrix                                            <- createJaspTable("Bayes Factor Matrix")
	jaspResults[["Bainmatrix"]]                           <- Bainmatrix

	if(type == "regression")
		Bainmatrix$dependOnOptions(c("dependent", "covariates", "model", "BFmatrix", "standardized"))
	if(type == "ancova")
		Bainmatrix$dependOnOptions(c("dependent", "fixedFactors", "covariates", "model", "BFmatrix"))
		if(type == "anova")
			Bainmatrix$dependOnOptions(c("dependent", "fixedFactors", "model", "BFmatrix"))

	Bainmatrix$position <- 3

	if(is.null(bainResult)){
		return()
	}
	if(!is.null(bainResult)) {

		BFmatrix <- diag(1, length(bainResult$BF))

		for (h1 in 1:length(bainResult$BF)) {
			for (h2 in 1:length(bainResult$BF)) {
				BFmatrix[h1, h2] <- bainResult$fit[h1]/bainResult$fit[h2]/(bainResult$complexity[h1]/bainResult$complexity[h2])
			}
		}

	}

	Bainmatrix$addColumnInfo(name = "hypothesis", title = "", type = "string")
	for(i in 1:nrow(BFmatrix)){
		Bainmatrix$addColumnInfo(name = paste0("H", i), title = paste0("H", i), type = "number", format="sf:4;dp:3")
	}

	if(is.null(bainResult)){
		for(i in 1:nrow(BFmatrix)){
			tmp <- list(hypothesis = paste0("H", i))
			for(j in 1:ncol(BFmatrix)){
				tmp[[paste0("H", j)]] <- "."
			}
			row <- tmp
			Bainmatrix$addRows(row)
		}
	} else {
			for(i in 1:nrow(BFmatrix)){
				tmp <- list(hypothesis = paste0("H", i))
				for(j in 1:ncol(BFmatrix)){
					tmp[[paste0("H", j)]] <- .clean(BFmatrix[i,j])
				}
				row <- tmp
				Bainmatrix$addRows(row)
			}
		}
	}

.bainANCOVAPlot <- function(dataset, options, bainResult, title){
	if(is.null(bainResult))
	  return(createJaspPlot(error="badData", errorMessage="Plotting is not possible: No analysis has been run."))
	png(tempfile())
	p <- .plot.BainA(bainResult)
	dev.off()
	BFplot <- createJaspPlot(plot=p, title=title, width = options$plotWidth, height = options$plotHeight)
	return(BFplot)
}

.bainCoefficients <- function(dataset, options, jaspResults, bainResult){

	if(!is.null(jaspResults[["coefficients"]])) return() #The options for this table didn't change so we don't need to rebuild it

	coefficients                      	<- createJaspTable("Coefficients for Groups plus Covariates")
	jaspResults[["coefficients"]]     	<- coefficients
	coefficients$dependOnOptions(c("dependent", "fixedFactors", "covariates", "coefficients", "model"))

	coefficients$addColumnInfo(name="v",    				title="Covariate",   type="string")
	coefficients$addColumnInfo(name="N",					title = "N", type = "integer")
	coefficients$addColumnInfo(name="mean", 				title="Coefficient", type="number", format="sf:4;dp:3")
	coefficients$addColumnInfo(name = "SE", 				title = "SE", type = "number", format = "sf:4;dp:3")
	coefficients$addColumnInfo(name="CiLower",              title = "lowerCI", type="number", format="sf:4;dp:3", overtitle = "95% Credible Interval")
  coefficients$addColumnInfo(name="CiUpper",              title = "upperCI", type="number", format="sf:4;dp:3", overtitle = "95% Credible Interval")

	coefficients$position <- 2

	if(is.null(bainResult))
		return()

	if(!is.null(bainResult)){

		sum_model <- bainResult$estimate_res
		covcoef <- data.frame(sum_model$coefficients)
		SEs <- summary(sum_model)$coefficients[, 2]

		rownames(covcoef) <- gsub("groupf", "", rownames(covcoef))
		x <- rownames(covcoef)
		x <- sapply(regmatches(x, gregexpr("covars", x)), length)
		x <- sum(x)
		if(x > 1){
		    rownames(covcoef)[(length(rownames(covcoef)) - (x-1)):length(rownames(covcoef))] <- options$covariates
		} else {
		    rownames(covcoef) <- gsub("covars", options$covariates, rownames(covcoef))
		}
		# mucho fixo

		groups <- rownames(covcoef)
		estim <- covcoef[, 1]
		CiLower <- estim - 1.96 * SEs
		CiUpper <- estim + 1.96 * SEs

		groupVars <- options$fixedFactors
		groupVars <- unlist(groupVars)
		groupCol <- dataset[ , .v(groupVars)]
		varLevels <- levels(groupCol)

		N <- NULL

		for(variable in varLevels){

			column <- dataset[ , .v(options$dependent)]
			column <- column[which(groupCol == variable)]

			N <- c(N,length(column))

		}

		covVars <- options$covariates
		covVars <- unlist(covVars)

		for(var in covVars){

			col <- dataset[ , .v(var)]
			col <- na.omit(col)
			N <- c(N, length(col))

		}

		for(i in 1:length(groups)){
			row <- list(v = groups[i], mean = .clean(estim[i]), N = N[i], SE = .clean(SEs[i]), CiLower = .clean(CiLower[i]), CiUpper = .clean(CiUpper[i]))
			coefficients$addRows(row)
		}

	} else {
		row <- list(v = ".", mean = ".", N = ".", SE = ".", CiLower = ".", CiUpper = ".")
		coefficients$addRows(row)
	}
}

.readDataBainAncova <- function(options, dataset){

	numeric.variables 						<- c(unlist(options$dependent),unlist(options$covariates))
	numeric.variables 						<- numeric.variables[numeric.variables != ""]
	factor.variables 						<- unlist(options$fixedFactors)
	factor.variables 						<- factor.variables[factor.variables != ""]
	all.variables							<- c(numeric.variables, factor.variables)

	if (is.null(dataset)) {

		trydata                                 <- .readDataSetToEnd(columns.as.numeric=all.variables)
		missingValuesIndicator                  <- .unv(names(which(apply(trydata, 2, function(x){ any(is.na(x))} ))))

		dataset 							<- .readDataSetToEnd(columns.as.numeric=numeric.variables, columns.as.factor=factor.variables, exclude.na.listwise=all.variables)

	} else {
		dataset 							<- .vdf(dataset, columns.as.numeric=numeric.variables, columns.as.factor=factor.variables)
	}

	.hasErrors(dataset, perform, type=c("infinity", "variance", "observations"),
				all.target=all.variables, message="short", observations.amount="< 3",
				exitAnalysisIfErrors = TRUE)

	readList <- list()
  readList[["dataset"]] <- dataset
  readList[["missingValuesIndicator"]] <- missingValuesIndicator

  return(readList)

}

.bainLegendAncova <- function(dataset, options, jaspResults){

	if(!is.null(jaspResults[["legendTable"]])) return() #The options for this table didn't change so we don't need to rebuild it

	legendTable                      	<- createJaspTable("Hypothesis Legend")
	jaspResults[["legendTable"]]     	<- legendTable

	legendTable$dependOnOptions(c("model", "fixedFactors"))
	legendTable$position <- 0

	legendTable$addColumnInfo(name="number", type="string", title="Abbreviation")
	legendTable$addColumnInfo(name="hypothesis", type="string", title="Hypothesis")

	if(options$model != ""){
		rest.string <- options$model
		rest.string <- gsub("\n", ";", rest.string)
		hyp.vector <- unlist(strsplit(rest.string, "[;]"))
			for(i in 1:length(hyp.vector)){
				row <- list(number = paste0("H",i), hypothesis = hyp.vector[i])
				legendTable$addRows(row)
			}
	} else if (options$fixedFactors != ""){
		factor <- options$fixedFactors
		fact <- dataset[, .v(factor)]
		levels <- levels(fact)
		string <- paste(paste(factor, levels, sep = "."), collapse = " = ")
		row <- list(number = "H1", hypothesis = string)
		legendTable$addRows(row)
	}

}

.plot.BainA <- function (x, y, ...)
{
    PMPa <- x$PMPa
    PMPb <- c(x$PMPb, 1 - sum(x$PMPb))
    numH <- length(x$BF)
    P_lables <- paste("H", 1:numH, sep = "")
    ggdata1 <- data.frame(lab = P_lables, PMP = PMPa)
    ggdata2 <- data.frame(lab = c(P_lables, "Hu"), PMP = PMPb)
    if (numH == 1) {
        p <- ggplot2::ggplot(data = ggdata2, mapping = ggplot2::aes(x = "", y = PMP,
                          	fill = lab)) +
						ggplot2::geom_bar(stat = "identity", width = 1e10, color = "black", size = 1) +
            ggplot2::geom_col()
        pp <- p + ggplot2::coord_polar(theta = "y", direction = -1) +
            			ggplot2::labs(x = "", y = "", title = "PMP") + ggplot2::theme(panel.grid = ggplot2::element_blank(),
                          			legend.position = "none") + ggplot2::scale_y_continuous(
																	breaks = cumsum(rev(PMPb)) - rev(PMPb)/2,
																	labels = rev(c(P_lables, "Hu")))
        pp <- pp + ggplot2::theme(panel.background = ggplot2::element_blank(),
                         axis.text=ggplot2::element_text(size=17, color = "black"),
												 plot.title = ggplot2::element_text(size=18, hjust = .5),
												 axis.ticks.y = ggplot2::element_blank())
				pp <- pp + ggplot2::scale_fill_brewer(palette="Set1")

				return(pp)
    }
    if (numH > 1) {

        p <- ggplot2::ggplot(data = ggdata1, mapping = ggplot2::aes(x = "", y = PMP,
                            fill = lab)) +
						ggplot2::geom_bar(stat = "identity", width = 1e10, color = "black", size = 1) +
            ggplot2::geom_col()
        p1 <- p + ggplot2::coord_polar(theta = "y", direction = -1) +
            			ggplot2::labs(x = "", y = "", title = "PMP excluding Hu", size = 30) +
            			ggplot2::theme(panel.grid = ggplot2::element_blank(), legend.position = "none") +
            			ggplot2::scale_y_continuous(
										breaks = cumsum(rev(PMPa)) - rev(PMPa)/2,
                  	labels = rev(P_lables))
        p1 <- p1 + ggplot2::theme(panel.background = ggplot2::element_blank(),
                         axis.text=ggplot2::element_text(size=17, color = "black"),
												 plot.title = ggplot2::element_text(size=18, hjust = .5),
											 	 axis.ticks.y = ggplot2::element_blank())
				p1 <- p1 + ggplot2::scale_fill_brewer(palette="Set1")

        p <- ggplot2::ggplot(data = ggdata2, mapping = ggplot2::aes(x = "",
																																		y = PMP,
                          																					fill = lab)) +
						ggplot2::geom_bar(stat = "identity", width = 1e10, color = "black", size = 1) +
						ggplot2::geom_col()
        p2 <- p + ggplot2::coord_polar(theta = "y", direction = -1) +
            			ggplot2::labs(x = "", y = "",
																title = "PMP including Hu", size = 30) +
            			ggplot2::theme(panel.grid = ggplot2::element_blank(),
																legend.position = "none") +
            			ggplot2::scale_y_continuous(
											breaks = cumsum(rev(PMPb)) - rev(PMPb)/2,
              				labels = rev(c(P_lables, "Hu")))
        p2 <- p2 + ggplot2::theme(panel.background = ggplot2::element_blank(),
                         					axis.text=ggplot2::element_text(size=17, color = "black"),
												 plot.title = ggplot2::element_text(size=18, hjust = .5),
											 	axis.ticks.y = ggplot2::element_blank())
				p2 <- p2 + ggplot2::scale_fill_brewer(palette="Set1")

        pp <- gridExtra::grid.arrange(gridExtra::arrangeGrob(p1, p2, ncol = 2))

        return(pp)
    }
}