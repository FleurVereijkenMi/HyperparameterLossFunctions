library(dplyr)

outcomeId <- 1758 # CCA
cdmDatabaseSchema <- "cdm"
cohortsDatabaseSchema <- "results"
workDatabaseSchema <- cohortsDatabaseSchema
cdmDatabaseName <- "IPCI"
cohortTable <- "cohort"

splitSettings <- createDefaultSplitSetting(splitSeed = 64975L)
sampleSettings <- createSampleSettings(type = 'none')
featureEngineeringSettings <- createFeatureEngineeringSettings(type = 'none')
preprocessSettings <- createPreprocessSettings()

executeSettings <- createExecuteSettings(
  runSplitData = TRUE,
  runSampleData = TRUE,
  runfeatureEngineering = TRUE,
  runPreprocessData = TRUE,
  runModelDevelopment = TRUE,
  runCovariateSummary = TRUE
)

covariateSettings <- FeatureExtraction::createCovariateSettings(
  useDemographicsAge = TRUE,
  useDemographicsGender = TRUE,
  useConditionOccurrenceAnyTimePrior = TRUE
)

populationSettings <- createStudyPopulationSettings(
  firstExposureOnly = FALSE,
  washoutPeriod = 0,
  removeSubjectsWithPriorOutcome = FALSE,
  priorOutcomeLookback = 99999,
  requireTimeAtRisk = TRUE,
  minTimeAtRisk = 1,
  riskWindowStart = 0,
  startAnchor = 'cohort start',
  riskWindowEnd = 365,
  endAnchor = 'cohort end'
)

# Load data once
plpData_small <- loadPlpData(file = "/fvereijken/Documents/StudyEvalMetrics/Data/CCA/")

# Define evaluation metrics and folder names
eval_metrics <- c(
  computeAuc = "AUC",
  averagePrecision = "AvgP",
  accuracyScore = "Accuracy",
  precisionScore = "Precision",
  recallScore = "Recall",
  f1Scores = "f1",
  logLossScore = "LogLoss",
  specificityScore = "Specificity",
  mccScore = "MCC",
  balancedAccuracyScore = "BalancedAccuracy",
  gMeanScore = "GMean",
  kappaScore = "Kappa",
  f2Score = "f2",
  rmseScore = "RMSE",
  maeScore = "MAE"
)

# Helper function to run models for all eval metrics
run_all_metrics <- function(analysisId, modelSettings, basePath) {
  for (metric in names(eval_metrics)) {
    saveDir <- file.path(basePath, eval_metrics[[metric]])
    
    runPlp(
      plpData = plpData_small,
      outcomeId = outcomeId,
      analysisId = analysisId,
      populationSettings = populationSettings,
      splitSettings = splitSettings,
      sampleSettings = sampleSettings,
      featureEngineeringSettings = featureEngineeringSettings,
      preprocessSettings = preprocessSettings,
      modelSettings = modelSettings,
      evalmetric = metric,
      executeSettings = executeSettings,
      saveDirectory = saveDir
    )
  }
}

# Model settings
modelsettingsDT <- setDecisionTree(
  seed = 333L,
  criterion = list('gini', 'entropy'),
  splitter = list('best', 'random'),
  maxDepth = list(as.integer(4), as.integer(10), as.integer(20), NULL),
  minSamplesSplit = list(2, 5, 10),
  minSamplesLeaf = list(10, 50),
  maxFeatures = list('log2', 'sqrt', 100, NULL),
  minImpurityDecrease = list(1e-7, 1e-4)
)

modelsettingsAda <- setAdaBoost(
  seed = 333L,
  nEstimators = list(5, 10, 20, 50, 75, 100, 200, 300),
  learningRate = list(1, 0.5, 0.1, 0.01, 0.001)
)

modelsettingsGBM <- setGradientBoostingMachine(
  seed = 333L,
  ntrees = c(100, 300, 500),
  nthread = 20,
  earlyStopRound = 25,
  maxDepth = c(4, 6, 8, 10),
  minChildWeight = c(1, 3, 5),
  learnRate = c(0.01, 0.05, 0.1, 0.3),
  scalePosWeight = c(1, 10),
  lambda = c(0, 0.1, 1, 5, 10),
  alpha = c(0, 0.1, 0.5, 1, 5)
)

modelsettingsLGBM <- setLightGBM(
  seed = 333L,
  nthread = 20,
  earlyStopRound = 25,
  numIterations = c(100, 300, 500),
  numLeaves = c(31, 63, 127),
  maxDepth = c(5, 10, 15, -1),
  minDataInLeaf = c(20, 50, 100),
  learningRate = c(0.01, 0.05, 0.1, 0.3),
  lambdaL1 = c(0, 0.5, 1),
  lambdaL2 = c(0, 0.5, 1),
  scalePosWeight = c(1, 10),
  isUnbalance = c(FALSE)
)

# Run all models
run_all_metrics("DecisionTree", modelsettingsDT, "/fvereijken/Documents/StudyEvalMetrics/Models/CCA/DecisionTree")
run_all_metrics("AdaBoost", modelsettingsAda, "/fvereijken/Documents/StudyEvalMetrics/Models/CCA/Adaboost")
run_all_metrics("GBM", modelsettingsGBM, "/fvereijken/Documents/StudyEvalMetrics/Models/CCA/GBM")
run_all_metrics("LGBM", modelsettingsLGBM, "/fvereijken/Documents/StudyEvalMetrics/Models/CCA/LGBM")
