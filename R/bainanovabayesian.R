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

BainAnovaBayesian <- function (jaspResults, dataset, options, ...) {
	### READY ###
	ready <- options[["fixedFactors"]] != "" && options[["dependent"]] != ""

	### READ DATA ###
	readList <- .readDataBainAnova(options, dataset)
	dataset <- readList[["dataset"]]
	missingValuesIndicator <- readList[["missingValuesIndicator"]]
	
	### LEGEND ###
	.bainLegendAncova(dataset, options, jaspResults)
	
	### RESULTS ###
	.bainAnovaResultsTable(dataset, options, jaspResults, missingValuesIndicator, ready)
	
	### BAYES FACTOR MATRIX ###
	.bainBayesFactorMatrix(dataset, options, jaspResults, ready, type = "anova")
	
	### DESCRIPTIVES ###
	.bainAnovaDescriptivesTable(dataset, options, jaspResults, ready)
	
	### BAYES FACTOR PLOT ###
	.bainAnovaBayesFactorPlots(dataset, options, jaspResults, ready)
	
	### DESCRIPTIVES PLOT ###
	.bainAnovaDescriptivesPlot(dataset, options, jaspResults, ready)
}

.bainAnovaResultsTable <- function(dataset, options, jaspResults, missingValuesIndicator, ready){

	if(!is.null(jaspResults[["bainTable"]])) return() #The options for this table didn't change so we don't need to rebuild it

	variables 											<- c(options$dependent, options$fixedFactors)
	bainTable                      	<- createJaspTable("Bain ANOVA Result")
	jaspResults[["bainTable"]]     	<- bainTable
	bainTable$dependOn(c("dependent", "fixedFactors", "model"))
	bainTable$position <- 1

	bainTable$addColumnInfo(name="hypotheses", 				type="string", title="")
	bainTable$addColumnInfo(name="BF", 						type="number", format="sf:4;dp:3", title= "BF.c")
	bainTable$addColumnInfo(name="PMP1", 					type="number", format="sf:4;dp:3", title= "PMP a")
	bainTable$addColumnInfo(name="PMP2", 					type="number", format="sf:4;dp:3", title= "PMP b")

	message <- "BF.c denotes the Bayes factor of the hypothesis in the row versus its complement.
				Posterior model probabilities (a: excluding the unconstrained hypothesis, b: including the unconstrained hypothesis) are based on equal prior model probabilities."
	bainTable$addFootnote(message=message, symbol="<i>Note.</i>")

	bainTable$addCitation("Gu, X., Mulder, J., and Hoijtink, H. (2017). Approximate adjusted fractional Bayes factors: A general method for testing informative hypotheses. British Journal of Mathematical and Statistical Psychology. DOI:10.1111/bmsp.12110")
	bainTable$addCitation("Hoijtink, H., Mulder, J., van Lissa, C., and Gu, X. (2018). A Tutorial on testing hypotheses using the Bayes factor. Psychological Methods.")
	bainTable$addCitation("Hoijtink, H., Gu, X., and Mulder, J. (2018). Bayesian evaluation of informative hypotheses for multiple populations. Britisch Journal of Mathematical and Statistical Psychology. DOI: 10.1111/bmsp.12145")

	if(!ready)
		return()

	if(any(variables %in% missingValuesIndicator)){
		i <- which(variables %in% missingValuesIndicator)
		if(length(i) > 1){
			bainTable$addFootnote(message= paste0("The variables ", variables[1], " and ", variables[2], " contain missing values, the rows containing these values are removed in the analysis."), symbol="<b>Warning.</b>")
		} else if (length(i) == 1){
			bainTable$addFootnote(message= paste0("The variable ", variables[i], " contains missing values, the rows containing these values are removed in the analysis."), symbol="<b>Warning.</b>")
		}
	}

	groupCol <- dataset[ , .v(options[["fixedFactors"]])]
	varLevels <- levels(groupCol)

	if(length(varLevels) > 15){
		bainTable$setError("The fixed factor has too many levels for a Bain analysis.")
		return()
	}

	if(options$model == ""){

		# We have to make a default matrix depending on the levels of the grouping variable...meh
		# The default hypothesis is that all groups are equal (e.g., 3 groups, "p1=p2=p3")
		len <- length(varLevels)

		null.mat <- matrix(0, nrow = (len-1), ncol = (len+1))
		indexes <- row(null.mat) - col(null.mat)
		null.mat[indexes == 0] <- 1
		null.mat[indexes == -1] <- -1

		ERr <- null.mat
	  IRr <- NULL

		p <- try(silent= FALSE, expr= {
			bainResult <- Bain::Bain_anova(X = dataset, dep_var = .v(options[["dependent"]]), group = .v(options[["fixedFactors"]]), ERr, IRr)
			jaspResults[["bainResult"]] <- createJaspState(bainResult)
			jaspResults[["bainResult"]]$dependOn(c("dependent", "fixedFactors", "model"))
		})

	} else {

			print(paste0('model received: "', options$model , '"'))

			jaspResults$startProgressbar(3)
			jaspResults$progressbarTick()

			rest.string <- modelConversion(options$model)

			jaspResults$progressbarTick()

			inpt <- list()
			names(dataset) <- .unv(names(dataset))
			inpt[[1]] <- dataset
			inpt[[2]] <- options[["dependent"]]
			inpt[[3]] <- options[["fixedFactors"]]
			inpt[[4]] <- rest.string

			p <- try(silent= FALSE, expr= {
				bainResult <- Bain::Bain_anova_cm(X = inpt[[1]], dep_var = inpt[[2]], group = inpt[[3]], hyp = inpt[[4]])
				jaspResults[["bainResult"]] <- createJaspState(bainResult)
				jaspResults[["bainResult"]]$dependOn(c("dependent", "fixedFactors", "model"))
			})
		}

		if(class(p) == "try-error"){
			bainTable$setError("An error occurred in the analysis. Please double check your variables.")
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
}

.bainAnovaDescriptivesTable <- function(dataset, options, jaspResults, ready){

	if(!is.null(jaspResults[["descriptivesTable"]])) return() #The options for this table didn't change so we don't need to rebuild it
		if(options[["descriptives"]]){

			descriptivesTable                      	<- createJaspTable("Descriptive Statistics")
			jaspResults[["descriptivesTable"]]     	<- descriptivesTable
			descriptivesTable$dependOn(c("dependent", "fixedFactors", "descriptives", "CredibleInterval"))
			descriptivesTable$position <- 2

			descriptivesTable$addColumnInfo(name="v",    		title="Level",   type="string")
			descriptivesTable$addColumnInfo(name="N",    		title="N",  type="integer")
			descriptivesTable$addColumnInfo(name="mean", 		title="Mean", type="number", format="sf:4;dp:3")
			descriptivesTable$addColumnInfo(name="sd",   		title="sd", type="number",   format="sf:4;dp:3")
			descriptivesTable$addColumnInfo(name="se",   		title="se", type="number",   format="sf:4;dp:3")

			interval <- options$CredibleInterval * 100
			overTitle <- paste0(interval, "% Credible Interval")
			descriptivesTable$addColumnInfo(name="lowerCI",      title = "lowerCI", type="number", format="sf:4;dp:3", overtitle = overTitle)
    	descriptivesTable$addColumnInfo(name="upperCI",      title = "upperCI", type="number", format="sf:4;dp:3", overtitle = overTitle)

			if(!ready)
				return()

			groupCol <- dataset[ , .v(options[["fixedFactors"]])]
			varLevels <- levels(groupCol)

			for(variable in varLevels){

					column <- dataset[ , .v(options$dependent)]
					column <- column[which(groupCol == variable)]

					posteriorSummary <- .posteriorSummaryGroupMean(variable=column, descriptivesPlotsCredibleInterval=options$CredibleInterval/100)
                    ciLower <- .clean(posteriorSummary$ciLower)
                    ciUpper <- .clean(posteriorSummary$ciUpper)

					row <- data.frame(v = variable, N = .clean(length(column)), mean = .clean(mean(column)), sd = .clean(round(sd(column),3)),
													se = .clean(sd(column)/sqrt(length(column))), lowerCI = ciLower, upperCI = ciUpper)
					descriptivesTable$addRows(row)
			}
	}
}

.bainAnovaBayesFactorPlots <- function(dataset, options, jaspResults, ready){
	if(options[["bayesFactorPlot"]] && ready){
	  if(is.null(jaspResults[["bayesFactorPlot"]])){
			bainResult <- jaspResults[["bainResult"]]$object
				png(tempfile())
				p <- .plot.BainA(bainResult)
				dev.off()
	      jaspResults[["bayesFactorPlot"]] <- createJaspPlot(plot = p, title = "Bayes Factor Comparison")
	      jaspResults[["bayesFactorPlot"]]$dependOn(c("bayesFactorPlot", "fixedFactors", "dependent", "model"))
				jaspResults[["bayesFactorPlot"]]$position <- 4
		}
	} else if(options[["bayesFactorPlot"]]){
			errorPlot <- createJaspPlot(plot = NULL, title = "Bayes Factor Comparison")
			errorPlot$setError("Plotting not possible: No analysis has been run.")
			jaspResults[["bayesFactorPlot"]] <- errorPlot
			jaspResults[["bayesFactorPlot"]]$dependOn(c("bayesFactorPlot", "fixedFactors", "dependent", "model"))
			jaspResults[["bayesFactorPlot"]]$position <- 4
	}
}

.bainAnovaDescriptivesPlot <- function(dataset, options, jaspResults, ready, type = "anova") {
	if(options[["descriptivesPlot"]] && ready){
		if(is.null(jaspResults[["descriptivesPlot"]])){
			bainResult <- jaspResults[["bainResult"]]$object
			base_breaks_y <- function(x, plotErrorBars = TRUE){
					ci.pos <- c(x[,"dependent"], x[,"ciLower"], x[,"ciUpper"])
					b <- pretty(ci.pos)
					d <- data.frame(x=-Inf, xend=-Inf, y=min(b), yend=max(b))
					list(ggplot2::geom_segment(data=d, ggplot2::aes(x=x, y=y, xend=xend, yend=yend), inherit.aes=FALSE, size = 1),
						 ggplot2::scale_y_continuous(breaks=c(min(b),max(b))))
					 }
			groupVars <- options$fixedFactors
			groupVars <- unlist(groupVars)

			groupVarsV <- .v(groupVars)
			dependentV <- .v(options$dependent)

			sum_model <- bainResult$estimate_res
			summaryStat <- summary(sum_model)$coefficients

			if(type == "ancova"){
				summaryStat <- summaryStat[-(nrow(summaryStat) - 0:(length(options[["covariates"]])-1)), ] # Remove covars rows
			}

			summaryStat <- cbind(summaryStat, 1:nrow(summaryStat))
			colnames(summaryStat)[length(colnames(summaryStat))] <- "plotHorizontalAxis"
			colnames(summaryStat)[which(colnames(summaryStat) == "Estimate")] <- "dependent"
			summaryStatSubset <- as.data.frame(summaryStat)

			groupCol <- dataset[ , .v(options[["fixedFactors"]])]
			varLevels <- levels(groupCol)
			ciLower <- summaryStatSubset[, 1] - 1.96*summaryStatSubset[, 2]
			ciUpper <- summaryStatSubset[, 1] + 1.96*summaryStatSubset[, 2]
			summaryStatSubset$ciLower <- ciLower
			summaryStatSubset$ciUpper <- ciUpper
			summaryStat <- summaryStatSubset

				p <- ggplot2::ggplot(summaryStatSubset, ggplot2::aes(x=plotHorizontalAxis,
											y=dependent,
											group=1))


				pd <- ggplot2::position_dodge(.2)
				p = p + ggplot2::geom_errorbar(ggplot2::aes(ymin=ciLower,
															ymax=ciUpper),
															colour="black", width=.2, position=pd)


			p <- p + ggplot2::geom_line(position=pd, size = .7) +
				ggplot2::geom_point(position=pd, size=4) +
				ggplot2::scale_fill_manual(values = c(rep(c("white","black"),5),rep("grey",100)), guide=ggplot2::guide_legend(nrow=10)) +
				ggplot2::scale_shape_manual(values = c(rep(c(21:25),each=2),21:25,7:14,33:112), guide=ggplot2::guide_legend(nrow=10)) +
				ggplot2::scale_color_manual(values = rep("black",200),guide=ggplot2::guide_legend(nrow=10)) +
				ggplot2::ylab(options$dependent) +
				ggplot2::xlab(groupVars) +
				base_breaks_y(summaryStat, TRUE)
			p <- JASPgraphs::themeJasp(p)

				jaspResults[["descriptivesPlot"]] <- createJaspPlot(plot = p, title = "Descriptives Plot")
				jaspResults[["descriptivesPlot"]]$dependOn(c("descriptivesPlot", "fixedFactors", "dependent", "model"))
				jaspResults[["descriptivesPlot"]]$position <- 4
		}
	} else if(options[["descriptivesPlot"]]){
			errorPlot <- createJaspPlot(plot = NULL, title = "Descriptives Plot")
			errorPlot$setError("Plotting not possible: No analysis has been run.")
			jaspResults[["descriptivesPlot"]] <- errorPlot
			jaspResults[["descriptivesPlot"]]$dependOn(c("descriptivesPlot", "fixedFactors", "dependent", "model"))
			jaspResults[["descriptivesPlot"]]$position <- 4
	}
}

.readDataBainAnova <- function(options, dataset){
	numeric.variables 							<- c(unlist(options$dependent))
	numeric.variables 							<- numeric.variables[numeric.variables != ""]
	factor.variables 							<- unlist(options$fixedFactors)
	factor.variables 							<- factor.variables[factor.variables != ""]
	all.variables 								<- c(numeric.variables, factor.variables)

	if (is.null(dataset)) {
		trydata                                 <- .readDataSetToEnd(columns.as.numeric=all.variables)
		missingValuesIndicator                  <- .unv(names(which(apply(trydata, 2, function(x){ any(is.na(x))} ))))
		dataset 								<- .readDataSetToEnd(columns.as.numeric=numeric.variables, columns.as.factor=factor.variables, exclude.na.listwise=all.variables)
	} else {
		dataset 								<- .vdf(dataset, columns.as.numeric=numeric.variables, columns.as.factor=factor.variables)
	}

	.hasErrors(dataset, perform, type=c("infinity", "variance", "observations"),
				all.target=all.variables, message="short", observations.amount="< 3",
				exitAnalysisIfErrors = TRUE)
	readList <- list()
  readList[["dataset"]] <- dataset
  readList[["missingValuesIndicator"]] <- missingValuesIndicator
  return(readList)
}
