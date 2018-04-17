library(tidyverse)
library(data.table)


getData_1 <- function() {
  "
  ### Read in as DT
  "
  #Skip 2 for codec
  DT <- fread("../data/raw_survey3/survey3_no25rule.csv", skip=2)
  
  
  
  
  "
  ### Reverse (1-7 Likert) target responses
  "
  #--Select target columns
  #Personality: 1_24 2_135
  targetColIndex <- grep("^Person[A-Za-z]{2,4}-((1_[24])|(2_[135]))$", names(DT), value=TRUE)
  
  
  #--Reverse 1-7 likert
  reversed <- 8 - DT[, targetColIndex, with=FALSE]
  
  
  #--Assign back to DT
  #Use parenthesis since the synax does not allow with=FALSE here
  DT[, (targetColIndex) := reversed]
  
  
  
  
  "
  ### Combine sub-items
  "
  #--personalities (5 constructs; 2 items each)
  #Computation
  subColIndex_1 <- grep("^Person[A-Za-z]{2,4}-1_\\d$", names(DT))
  subColIndex_2 <- grep("^Person[A-Za-z]{2,4}-2_\\d$", names(DT))
  personalities <- (DT[, subColIndex_1, with=FALSE] + DT[, subColIndex_2, with=FALSE]) / 2
  
  #Substitution
  newColName <- gsub("1_", "", grep("^Person[A-Za-z]{2,4}-1_\\d$", names(DT), value=TRUE))
  DT[, (newColName) := personalities]
  
  
  
  
  "
  ### Compute gaps and sums
  "
  #--Personality
  colIndex_Hb <- grep("^PersonHb-\\d$", names(DT))
  colIndex_Lch <- grep("^PersonLch-\\d$", names(DT))
  colIndex_OutS <- grep("^PersonOutS-\\d$", names(DT))
  colIndex_IdS <- grep("^PersonIdS-\\d$", names(DT))
  
  #Hb - OutS (original and absolute)
  HbOutS <- DT[, colIndex_Hb, with=FALSE] - DT[, colIndex_OutS, with=FALSE]
  newColName <- gsub("IdS", "HbOutS", grep("^PersonIdS-\\d$", names(DT), value=TRUE))
  DT[, (newColName) := HbOutS]
  newColName <- gsub("(\\d)", "ab\\1", newColName)
  DT[, (newColName) := abs(HbOutS)]
  
  #Lch - OutS (original and absolute)
  LchOutS <- DT[, colIndex_Lch, with=FALSE] - DT[, colIndex_OutS, with=FALSE]
  newColName <- gsub("IdS", "LchOutS", grep("^PersonIdS-\\d$", names(DT), value=TRUE))
  DT[, (newColName) := LchOutS]
  newColName <- gsub("(\\d)", "ab\\1", newColName)
  DT[, (newColName) := abs(LchOutS)]
  
  #IdS - OutS (original and absolute)
  IdSOutS <- DT[, colIndex_IdS, with=FALSE] - DT[, colIndex_OutS, with=FALSE]
  newColName <- gsub("IdS", "IdSOutS", grep("^PersonIdS-\\d$", names(DT), value=TRUE))
  DT[, (newColName) := IdSOutS]
  newColName <- gsub("(\\d)", "ab\\1", newColName)
  DT[, (newColName) := abs(IdSOutS)]
  
  #IdS - Hb (original and absolute)
  IdSHb <- DT[, colIndex_IdS, with=FALSE] - DT[, colIndex_Hb, with=FALSE]
  newColName <- gsub("IdS", "IdSHb", grep("^PersonIdS-\\d$", names(DT), value=TRUE))
  DT[, (newColName) := IdSHb]
  newColName <- gsub("(\\d)", "ab\\1", newColName)
  DT[, (newColName) := abs(IdSHb)]
  
  #Gap sum
  DT[, "PersonHbOutS-sum" := rowSums(.SD), .SDcols=grep("^PersonHbOutS-\\d$", names(DT))]
  DT[, "PersonLchSOutS-sum" := rowSums(.SD), .SDcols=grep("^PersonLchOutS-\\d$", names(DT))]
  DT[, "PersonIdSOutS-sum" := rowSums(.SD), .SDcols=grep("^PersonIdSOutS-\\d$", names(DT))]
  DT[, "PersonIdSHb-sum" := rowSums(.SD), .SDcols=grep("^PersonIdSHb-\\d$", names(DT))]
  
  #Gap absolute sum
  DT[, "PersonHbOutS-absum" := rowSums(.SD), .SDcols=grep("^PersonHbOutS-ab\\d$", names(DT))]
  DT[, "PersonLchSOutS-absum" := rowSums(.SD), .SDcols=grep("^PersonLchOutS-ab\\d$", names(DT))]
  DT[, "PersonIdSOutS-absum" := rowSums(.SD), .SDcols=grep("^PersonIdSOutS-ab\\d$", names(DT))]
  DT[, "PersonIdSHb-absum" := rowSums(.SD), .SDcols=grep("^PersonIdSHb-ab\\d$", names(DT))]
  
  #Hb, Lch, IdS, OutS sum
  DT[, "PersonHb-sum" := rowSums(.SD), .SDcols=grep("^PersonHb-\\d$", names(DT))]
  DT[, "PersonOutS-sum" := rowSums(.SD), .SDcols=grep("^PersonOutS-\\d$", names(DT))]
  DT[, "PersonIdS-sum" := rowSums(.SD), .SDcols=grep("^PersonIdS-\\d$", names(DT))]
  DT[, "PersonLch-sum" := rowSums(.SD), .SDcols=grep("^PersonLch-\\d$", names(DT))]
  
  #Proportional gap -- capped on ideal = 1, real = 0
  PersonHbOutS_capped <- pmax(DT[, `PersonHbOutS-sum`], 0)
  PersonIdSHb_capped <- pmax(DT[, `PersonIdSHb-sum`], 0)
  DT[, "PersonProgapS-capsum" := PersonHbOutS_capped / (PersonHbOutS_capped + PersonIdSHb_capped)]
  DT[`PersonOutS-sum` > `PersonIdS-sum`, "PersonProgapS-capsum" := NA] #Ideal must > real
  DT[!is.finite(`PersonProgapS-capsum`), "PersonProgapS-capsum" := NA]
  
  #Proportional gap -- no cap
  DT[, "PersonProgapS-sum" := `PersonHbOutS-sum` / `PersonIdSOutS-sum`]
  DT[`PersonOutS-sum` > `PersonIdS-sum`, "PersonProgapS-sum" := NA]
  DT[!is.finite(`PersonProgapS-sum`), "PersonProgapS-sum" := NA]
  
  
  
  
  "
  ### Return data 1
  "
  return(DT)
}








getData_2 <- function() {
  "
  ### Read in as DT
  "
  DT <- read_csv("../data/raw_survey/processed/survey.csv", col_names=TRUE) %>%
    mutate(race = factor(race),
           sex = factor(sex),
           core_id = factor(core_id)) %>%
    select(-id)
  
  
  
  
  "
  ### Compute preference
  "
  DT <- DT %>%
    rowwise() %>% #Rowwise to make the ordinary functions work
    mutate(preference = mean(c(preference_3))) %>%
    ungroup() #Ungroup to cancel rowwise
  
  
  
  
  "
  ### Compute personality gap
  "
  DT <- mutate(DT,
                gap_extraversion = game_extraversion - real_extraversion,
                gap_agreeableness = game_agreeableness - real_agreeableness,
                gap_conscientiousness = game_conscientiousness - real_conscientiousness,
                gap_emotionstability = game_emotionstability - real_emotionstability,
                gap_openness = game_openness - real_openness,
                gap_sum = gap_extraversion + gap_agreeableness + gap_conscientiousness + gap_emotionstability + gap_openness,
                gap_sum_abs = abs(gap_extraversion) + abs(gap_agreeableness) + abs(gap_conscientiousness) + abs(gap_emotionstability) + abs(gap_openness),
                game_sum = game_extraversion + game_agreeableness + game_conscientiousness + game_emotionstability + game_openness,
                real_sum = real_extraversion + real_agreeableness + real_conscientiousness + real_emotionstability + real_openness,
                dissatis_sum = dissatis_autonomy + dissatis_relatedness + dissatis_competence,
                satis_sum = satis_autonomy + satis_relatedness + satis_competence,
                combined_sum = combined_autonomy + combined_relatedness + combined_competence
  )
  
  
  
  
  "
  ### Acquire distinguished player DT
  "
  #Key = player
  DT_player <- distinct(DT, respondent, .keep_all=TRUE)
  
  
  
  
  "
  ### Return data 2
  "
  return(list(DT, DT_player))
}








getData_3 <- function() {
  "
  ### Read in as DT
  "
  #Read in as DT
  #Skip 2 for codec
  DT <- fread("../data/raw_survey2/survey2.csv", skip=2)[
    MTurkCode != "", ,] #Filter
  
  
  
  
  "
  ### Reverse (1-7 Likert) target responses
  "
  #--Select target columns
  #Personality: 1_24 2_135; SDT: 1_246 2_246; Preference: -2
  targetColIndex <- grep("(^Person.+((1_[24])|(2_[135]))$)|(^SDT.+_[246]$)|(^Pref.-2)", names(DT), value=TRUE)
  
  
  #--Reverse 1-7 likert
  reversed <- 8 - DT[, targetColIndex, with=FALSE]
  
  
  #--Assign back to DT
  #Use parenthesis since the synax does not allow with=FALSE here
  DT[, (targetColIndex) := reversed]
  
  
  
  
  "
  ### Combine sub-items
  "
  #--personalities (5 constructs; 2 items each)
  #Computation
  subColIndex_1 <- grep("^Person.+1_\\d$", names(DT))
  subColIndex_2 <- grep("^Person.+2_\\d$", names(DT))
  personalities <- (DT[, subColIndex_1, with=FALSE] + DT[, subColIndex_2, with=FALSE]) / 2
  
  #Substitution
  newColName <- gsub("1_", "", grep("^Person.+1_\\d$", names(DT), value=TRUE))
  DT[, (newColName) := personalities]
  
  
  #--SDT (3 constructs; 4 items each)
  #Computation
  subColIndex_1 <- grep("^SDT.+1_[135]$", names(DT))
  subColIndex_2 <- grep("^SDT.+1_[246]$", names(DT))
  subColIndex_3 <- grep("^SDT.+2_[135]$", names(DT))
  subColIndex_4 <- grep("^SDT.+2_[246]$", names(DT))
  SDTs <- (DT[, subColIndex_1, with=FALSE] + DT[, subColIndex_2, with=FALSE] + DT[, subColIndex_3, with=FALSE] + DT[, subColIndex_4, with=FALSE]) / 4
  
  #Substitution
  newColName <- gsub("1_", "", grep("^SDT.+1_[123]$", names(DT), value=TRUE))
  DT[, (newColName) := SDTs]
  
  
  #--Preference (5 items)
  DT[, "PrefS-a1" := rowMeans(.SD), .SDcols=grep("^PrefS-\\d$", names(DT))] #All 5 measures
  DT[, "PrefS-a2" := rowMeans(.SD), .SDcols=grep("^PrefS-[1234]$", names(DT))] #Except play frequency
  DT[, "PrefF-a1" := rowMeans(.SD), .SDcols=grep("^PrefF-\\d$", names(DT))]
  DT[, "PrefF-a2" := rowMeans(.SD), .SDcols=grep("^PrefF-[1234]$", names(DT))]

  
  #--Gamer (5 items)
  DT[, "GProfile-a1" := rowMeans(.SD), .SDcols=grep("^GProfile-((3_1)|[12345])$", names(DT))] #All 5 measures
  DT[, "GProfile-a2" := rowMeans(.SD), .SDcols=grep("^GProfile-[24]$", names(DT))] #Pure like
  DT[, "GProfile-a3" := rowMeans(.SD), .SDcols=grep("^GProfile-[245]$", names(DT))] #Pure like + play frequency
  
  
  
  
  "
  ### Compute gaps and sums
  "
  #--Personality
  colIndex_InF <- grep("^PersonInF-\\d$", names(DT))
  colIndex_OutF <- grep("^PersonOutF-\\d$", names(DT))
  colIndex_InS <- grep("^PersonInS-\\d$", names(DT))
  colIndex_OutS <- grep("^PersonOutS-\\d$", names(DT))
  colIndex_IdS <- grep("^PersonIdS-\\d$", names(DT))
  colIndex_SteS <- grep("^PersonSteS-\\d$", names(DT))
  
  #InF - OutF (original and absolute)
  InFOutF <- DT[, colIndex_InF, with=FALSE] - DT[, colIndex_OutF, with=FALSE]
  newColName <- gsub("InF", "InFOutF", grep("^PersonInF-\\d$", names(DT), value=TRUE))
  DT[, (newColName) := InFOutF]
  newColName <- gsub("(\\d)", "ab\\1", newColName)
  DT[, (newColName) := abs(InFOutF)]
  
  #InS - OutS (original and absolute)
  InSOutS <- DT[, colIndex_InS, with=FALSE] - DT[, colIndex_OutS, with=FALSE]
  newColName <- gsub("InS", "InSOutS", grep("^PersonInS-\\d$", names(DT), value=TRUE))
  DT[, (newColName) := InSOutS]
  newColName <- gsub("(\\d)", "ab\\1", newColName)
  DT[, (newColName) := abs(InSOutS)]
  
  #IdS - InS (original and absolute)
  IdSInS <- DT[, colIndex_IdS, with=FALSE] - DT[, colIndex_InS, with=FALSE]
  newColName <- gsub("InS", "IdSInS", grep("^PersonInS-\\d$", names(DT), value=TRUE))
  DT[, (newColName) := IdSInS]
  newColName <- gsub("(\\d)", "ab\\1", newColName)
  DT[, (newColName) := abs(IdSInS)]
  
  #IdS - OutS (original and absolute)
  IdSOutS <- DT[, colIndex_IdS, with=FALSE] - DT[, colIndex_OutS, with=FALSE]
  newColName <- gsub("InS", "IdSOutS", grep("^PersonInS-\\d$", names(DT), value=TRUE))
  DT[, (newColName) := IdSOutS]
  newColName <- gsub("(\\d)", "ab\\1", newColName)
  DT[, (newColName) := abs(IdSOutS)]
  
  #InS - SteS (original and absolute)
  InSSteS <- DT[, colIndex_InS, with=FALSE] - DT[, colIndex_SteS, with=FALSE]
  newColName <- gsub("InS", "InSSteS", grep("^PersonInS-\\d$", names(DT), value=TRUE))
  DT[, (newColName) := InSSteS]
  newColName <- gsub("(\\d)", "ab\\1", newColName)
  DT[, (newColName) := abs(InSSteS)]
  
  #OutS - SteS (original and absolute)
  OutSSteS <- DT[, colIndex_OutS, with=FALSE] - DT[, colIndex_SteS, with=FALSE]
  newColName <- gsub("InS", "OutSSteS", grep("^PersonInS-\\d$", names(DT), value=TRUE))
  DT[, (newColName) := OutSSteS]
  newColName <- gsub("(\\d)", "ab\\1", newColName)
  DT[, (newColName) := abs(OutSSteS)]
  
  #Gap sum
  DT[, "PersonInFOutF-sum" := rowSums(.SD), .SDcols=grep("^PersonInFOutF-\\d$", names(DT))]
  DT[, "PersonInSOutS-sum" := rowSums(.SD), .SDcols=grep("^PersonInSOutS-\\d$", names(DT))]
  DT[, "PersonIdSInS-sum" := rowSums(.SD), .SDcols=grep("^PersonIdSInS-\\d$", names(DT))]
  DT[, "PersonIdSOutS-sum" := rowSums(.SD), .SDcols=grep("^PersonIdSOutS-\\d$", names(DT))]
  DT[, "PersonInSSteS-sum" := rowSums(.SD), .SDcols=grep("^PersonInSSteS-\\d$", names(DT))]
  DT[, "PersonOutSSteS-sum" := rowSums(.SD), .SDcols=grep("^PersonOutSSteS-\\d$", names(DT))]
  
  #Gap absolute sum
  DT[, "PersonInFOutF-absum" := rowSums(.SD), .SDcols=grep("^PersonInFOutF-ab\\d$", names(DT))]
  DT[, "PersonInSOutS-absum" := rowSums(.SD), .SDcols=grep("^PersonInSOutS-ab\\d$", names(DT))]
  DT[, "PersonIdSInS-absum" := rowSums(.SD), .SDcols=grep("^PersonIdSInS-ab\\d$", names(DT))]
  DT[, "PersonIdSOutS-absum" := rowSums(.SD), .SDcols=grep("^PersonIdSOutS-ab\\d$", names(DT))]
  DT[, "PersonInSSteS-absum" := rowSums(.SD), .SDcols=grep("^PersonInSSteS-ab\\d$", names(DT))]
  DT[, "PersonOutSSteS-absum" := rowSums(.SD), .SDcols=grep("^PersonOutSSteS-ab\\d$", names(DT))]
  
  #InS, OutS, IdS, SteS sum
  DT[, "PersonInF-sum" := rowSums(.SD), .SDcols=grep("^PersonInF-\\d$", names(DT))]
  DT[, "PersonOutF-sum" := rowSums(.SD), .SDcols=grep("^PersonOutF-\\d$", names(DT))]
  DT[, "PersonInS-sum" := rowSums(.SD), .SDcols=grep("^PersonInS-\\d$", names(DT))]
  DT[, "PersonOutS-sum" := rowSums(.SD), .SDcols=grep("^PersonOutS-\\d$", names(DT))]
  DT[, "PersonIdS-sum" := rowSums(.SD), .SDcols=grep("^PersonIdS-\\d$", names(DT))]
  DT[, "PersonSteS-sum" := rowSums(.SD), .SDcols=grep("^PersonSteS-\\d$", names(DT))]
  
  #Proportional gap -- capped on ideal = 1, real = 0
  PersonInSOutS_capped <- pmax(DT[, `PersonInSOutS-sum`], 0)
  PersonIdSInS_capped <- pmax(DT[, `PersonIdSInS-sum`], 0)
  DT[, "PersonProgapS-capsum" := PersonInSOutS_capped / (PersonInSOutS_capped + PersonIdSInS_capped)]
  DT[`PersonOutS-sum` > `PersonIdS-sum`, "PersonProgapS-capsum" := NA] #Ideal must > real
  DT[!is.finite(`PersonProgapS-capsum`), "PersonProgapS-capsum" := NA]
  
  #Proportional gap -- no cap
  DT[, "PersonProgapS-sum" := `PersonInSOutS-sum` / `PersonIdSOutS-sum`]
  DT[`PersonOutS-sum` > `PersonIdS-sum`, "PersonProgapS-sum" := NA]
  DT[!is.finite(`PersonProgapS-sum`), "PersonProgapS-sum" := NA]
  
  
  #--SDT
  colIndex_In <- grep("^SDTIn-\\d$", names(DT))
  colIndex_Out <- grep("^SDTOut-\\d$", names(DT))
  colIndex_Id <- grep("^SDTId-\\d$", names(DT))
  
  #In - Out (original and absolute)
  InOut <- DT[, colIndex_In, with=FALSE] - DT[, colIndex_Out, with=FALSE]
  newColName <- gsub("In", "InOut", grep("^SDTIn-\\d$", names(DT), value=TRUE))
  DT[, (newColName) := InOut]
  newColName <- gsub("(\\d)", "ab\\1", newColName)
  DT[, (newColName) := abs(InOut)]
  
  #Id - In (original and absolute)
  IdIn <- DT[, colIndex_Id, with=FALSE] - DT[, colIndex_In, with=FALSE]
  newColName <- gsub("In", "IdIn", grep("^SDTIn-\\d$", names(DT), value=TRUE))
  DT[, (newColName) := IdIn]
  newColName <- gsub("(\\d)", "ab\\1", newColName)
  DT[, (newColName) := abs(IdIn)]
  
  #Id - Out (original and absolute)
  IdOut <- DT[, colIndex_Id, with=FALSE] - DT[, colIndex_Out, with=FALSE]
  newColName <- gsub("In", "IdOut", grep("^SDTIn-\\d$", names(DT), value=TRUE))
  DT[, (newColName) := IdOut]
  newColName <- gsub("(\\d)", "ab\\1", newColName)
  DT[, (newColName) := abs(IdOut)]
  
  #Gap sum
  DT[, "SDTInOut-sum" := rowSums(.SD), .SDcols=grep("^SDTInOut-\\d$", names(DT))]
  DT[, "SDTIdIn-sum" := rowSums(.SD), .SDcols=grep("^SDTIdIn-\\d$", names(DT))]
  DT[, "SDTIdOut-sum" := rowSums(.SD), .SDcols=grep("^SDTIdOut-\\d$", names(DT))]
  
  #Gap absolute sum
  DT[, "SDTInOut-absum" := rowSums(.SD), .SDcols=grep("^SDTInOut-ab\\d$", names(DT))]
  DT[, "SDTIdIn-absum" := rowSums(.SD), .SDcols=grep("^SDTIdIn-ab\\d$", names(DT))]
  DT[, "SDTIdOut-absum" := rowSums(.SD), .SDcols=grep("^SDTIdOut-ab\\d$", names(DT))]
  
  #In, Out, Id sum
  DT[, "SDTIn-sum" := rowSums(.SD), .SDcols=grep("^SDTIn-\\d$", names(DT))]
  DT[, "SDTOut-sum" := rowSums(.SD), .SDcols=grep("^SDTOut-\\d$", names(DT))]
  DT[, "SDTId-sum" := rowSums(.SD), .SDcols=grep("^SDTId-\\d$", names(DT))]
  
  
  
  
  "
  ### Return data 3
  "
  return(DT)
}