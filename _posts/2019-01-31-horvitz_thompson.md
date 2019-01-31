---
title: "Forest Sampling: Application of Horvitz-Thompson estimators in a double sampling context"
author: "Henry Rodman"
categories: ["R"]
tags: ["statistics", "sampling", "forestry", "biometrics"]

output:
  md_document:
    variant: markdown_github
    fig_width: 7
    preserve_yaml: true
---

Introduction
------------

Though you may not notice it, forest management is a part of your life. The air we breath, water we drink, and our homes are all in some way composed of forest resources. To secure an adequate and sustainable supply of these resources, we manage forests. Humans have been managing forests with varying degrees of success throughout our entire history and the science of forestry has been developed to help us manage forests better than those who came before us. The application of statistical survey sampling techniques to the assessment of forest resources (aka forest inventory) has been elemental to improvements in forest management practices across the globe. In any context, bad management decisions are often a product of bad information or poorly calibrated expectations for the future. The same is true in forestry and is the reason why forest inventory is so important. Efficient and unbiased sampling techniques have long been a focus in statistics, and forest managers use these methods every day to obtain the information required to make intelligent management decisions. This post is meant to outline the application of two-stage sampling to forest inventory, which is one of the most commonly applied statistical methods in resource assessment.

Objectives
----------

I am a forest manager that needs an estimate of the volume of standing trees in a tract of forest land. I want to obtain an accurate estimate for the lowest price possible. I am willing to pay more for a more precise estimate, but do not need an estimate that is more precise than +/- 10% at 90% confidence. In statistical terms, I would like the half-width of the 90% confidence inveral to be roughly 10% of the estimate of the total volume.

``` r
library(tidyverse)
```

Simulate the population
-----------------------

The forest is composed of 100 stands of forest that vary in size, most of the stands are Douglas-fir plantations. In general, we expect that older stands have greater volume stocking than young stands. We will randomly assign an age, size in acres, coefficient of variation of volume within the stand, then assign the mean cubic feet per acre for the stand.

``` r
# simulate a population of stands
stands <- tibble(id = 1:100) %>%
  mutate(
    acres = runif(n = 100, min = 10, max = 200),
    age = runif(n = 100, min = 10, max = 150),
    cv = runif(n = 100, min = 10, max = 70)
  ) %>%
  mutate(
    cuftPerAc = 3000 * 1 / (1 + exp(-(age - 40) / 15)) +
      rnorm(n = 100, mean = 0, sd = 400)
  ) %>%
  mutate(
    cuftPerAc = case_when(
      cuftPerAc < 0 ~ 0,
      cuftPerAc > 0 ~ cuftPerAc
    )
  )

totalAcres <- sum(stands$acres)
totalCuft <- sum(stands$cuftPerAc * stands$acres)

meanCuft <- totalCuft / totalAcres

truth <- tibble(
  source = "truth",
  totalCuft = totalCuft,
  meanCuft = meanCuft
)
```

The true population mean stocking is 2182 cubic feet per acre, the population total is 2.339133710^{7} cubic feet!

Designing a sample
------------------

There are many ways to obtain an estimate of the total volume for the forest. The most expensive way would be to visit every tree in the forest, measuring several dimensions and estimating volume for every single tree. This would provide us with an accurate and precise estimate but would be time consuming and prohibitively expensive. We could also just guess the total based on what we know about the property. This would be very cheap today, but our estimate is likely to be inaccurate and will probably result in significant costs related to bad information down the road. Our best bet is to take a sample from the population. A simple random sample of 1/15 acre circular plots distributed across the property would be a fine way to sample the property, but we also want information about individual stands for planning purposes so we should do something else.

A double sample is an appealing option because we can obtain an accurate estimate of the population total while simultaneously obtaining useful stand-level estimates. We can also be more efficient in our sampling efforts by controlling the total number of stands that we must visit.

### Select stands

The population of stands can be sampled randomly, but since we are trying to obtain an estimate of total volume for the property, we need to make sure that we sample the stands that a) contribute the most to the total volume, and b) contribute the most variance to the population. We can sample the stands however we want so long as we know the probability of each stand being included in the sample! In this case, we are going to weight our sample on age x acres since we believe the oldest stands are going to have the greatest stocking, and that the largest stands have the greatest total volume. We have decided that we are going to sample 20 stands and install either one plot per 7 acres or 30 plots per stand, whichever is fewer.

``` r
nSamp <- 20

sampStands <- stands %>%
  mutate(prop = sqrt(age * acres) / sum(sqrt(age * acres))) %>%
  sample_n(nSamp, weight = prop) %>%
  group_by(id) %>%
  mutate(nPlots = min(ceiling(acres / 7), 30)) %>%
  mutate(pi_i = nSamp * prop)
```

### Select plots

In each sample stand we are installing a systematic random sample of 1/15 acre circular plots. On each plot we are estimating the cubic foot volume of the living trees.

``` r
# stage 2: generate a sample of plots for each stand
plotTab <- sampStands %>%
  group_by(id) %>%
  mutate(
    cuftObs = list(
      rnorm(
        n = nPlots,
        mean = cuftPerAc,
        sd = (cv / 100) * cuftPerAc
      )
    )
  ) %>%
  select(id, cuftObs) %>%
  unnest() %>%
  mutate(cuftObs = ifelse(cuftObs < 0, 0, cuftObs)) %>%
  ungroup()
```

Analysis
--------

Once we are done cruising it's time to crunch the numbers!

### Stand-level estimates

We can start by summarizing the stand-level estimates. For each stand we will estimate the total volume using the mean volume per acre from the sample and the total acres of each stand. We will also compute the sample variance and estimate the total variance for each stand.

``` r
standDat <- plotTab %>%
  left_join(sampStands %>% select(id, acres), by = "id") %>%
  group_by(id, acres) %>%
  summarize(
    meanObs = mean(cuftObs),
    tHat = mean(cuftObs * acres),
    varTHat = var(cuftObs * acres),
    sdObs = sd(cuftObs),
    nPlots = n()
  )
```

### Population-level estimate

We can now combine the estimates from the primary sampling units to obtain an estimate of the population. To do this we will use the inclusion and selection probabilities to weight each sampled stand's contribution to the population total.

``` r
# this is the component of the Horvitz-Thompson variance estimator that
# requires the joint probability of inclusion of each cluster:
# pi_i = probability of inclusion = n * p
# p = selection probability (stand acres / total acres)
sub_var <- function(row, data, y, pi_i, p) {
  a <- data[row, ]
  b <- data[-row, ]
  n <- nrow(data)

  x <- list()
  for (l in 1:nrow(b)) {
    c <- b[l, ]

    jointProb <- a[[pi_i]] + c[[pi_i]] - (1 - (1 - a[[p]] - c[[p]])^n)

    x[[l]] <- (jointProb - a[[pi_i]] * c[[pi_i]]) / (a[[pi_i]] * c[[pi_i]]) *
      (a[[y]] * c[[y]] / jointProb)
  }

  sum(unlist(x))
}

sampleSummary <- standDat %>%
  left_join(sampStands %>% select(id, pi_i, prop), by = "id") %>%
  ungroup() %>%
  mutate(
    subVar = unlist(
      lapply(
        1:nrow(.),
        sub_var,
        data = .,
        y = "tHat",
        pi_i = "pi_i",
        p = "prop"
      )
    )
  ) %>%
  ungroup() %>%
  summarize(
    totalCuft = sum(tHat / pi_i),
    varTot = sum(((1 - pi_i) / pi_i^2) * tHat^2) +
      sum(subVar) + sum(varTHat / pi_i),
    nObs = n()
  ) %>%
  mutate(
    seTot = sqrt(varTot / nObs),
    ci90Tot = qt(1 - 0.1 / 2, df = nObs - 1) * seTot,
    meanCuft = totalCuft / totalAcres,
    seMeanCuft = seTot / totalAcres,
    ci90MeanCuft = ci90Tot / totalAcres,
    source = "estimate"
  ) %>%
  select(
    source, totalCuft, seTot, ci90Tot,
    meanCuft, seMeanCuft, ci90MeanCuft, nObs
  )
  
results <- bind_rows(sampleSummary, truth)

results %>%
  ggplot(aes(x = source, y = meanCuft, color = source)) +
  geom_point() +
  geom_errorbar(
    aes(ymax = meanCuft + ci90MeanCuft, ymin = meanCuft - ci90MeanCuft)
  ) +
  ylim(0, max(standDat$meanObs)) +
  theme_bw()
## Warning: Removed 1 rows containing missing values (geom_errorbar).
```

![](/assets/images/2019-01-31-horvitz_thompson_populationStats-1.png)

``` r
simulate_HT <- function(i, stands, nStands, acresPerPlot) {
  sampStands <- stands %>%
    mutate(
      prop = sqrt(age * acres) / sum(sqrt(age * acres)),
      pi_i = nStands * prop
    ) %>%
    sample_n(nStands, weight = prop) %>%
    mutate(nPlots = ceiling(acres / acresPerPlot))

  # stage 2: generate a sample of plots for each stand
  plotTab <- sampStands %>%
    group_by(id) %>%
    mutate(
      cuftObs = list(
        rnorm(
          n = nPlots,
          mean = cuftPerAc,
          sd = (cv / 100) * cuftPerAc
        )
      )
    ) %>%
    select(id, cuftObs) %>%
    unnest() %>%
    mutate(cuftObs = ifelse(cuftObs < 0, 0, cuftObs)) %>%
    ungroup()

  standDat <- plotTab %>%
    left_join(sampStands %>% select(id, acres), by = "id") %>%
    group_by(id, acres) %>%
    summarize(
      meanObs = mean(cuftObs),
      tHat = mean(cuftObs * acres),
      varTHat = var(cuftObs * acres),
      sdObs = sd(cuftObs),
      nPlots = n()
    )

  # ggplot(data = standDat, aes(x = cuftPerAc, y = meanObs)) +
  #   geom_point() +
  #   theme_bw() +
  #   geom_abline()
  sampleSummary <- standDat %>%
    left_join(sampStands %>% select(id, pi_i, prop), by = "id") %>%
    ungroup() %>%
    mutate(
      subVar = unlist(
        lapply(
          1:nrow(.),
          sub_var,
          data = .,
          y = "tHat",
          pi_i = "pi_i",
          p = "prop"
        )
      )
    ) %>%
    ungroup() %>%
    summarize(
      totalCuft = sum(tHat / pi_i),
      varTot = sum(((1 - pi_i) / pi_i^2) * tHat^2) +
        sum(subVar) + sum(varTHat / pi_i),
      nObs = n()
    ) %>%
    mutate(
      seTot = sqrt(varTot / nObs),
      ci90Tot = qt(1 - 0.1 / 2, df = nObs - 1) * seTot,
      meanCuft = totalCuft / totalAcres,
      seMeanCuft = seTot / totalAcres,
      ci90MeanCuft = ci90Tot / totalAcres,
      source = "estimate"
    ) %>%
    select(
      source, totalCuft, seTot, ci90Tot,
      meanCuft, seMeanCuft, ci90MeanCuft, nObs
    )

  sampleSummary
}

sim10 <- bind_rows(
  lapply(
    1:100, simulate_HT,
    stands = stands,
    nStands = 10, acresPerPlot = 10
  )
)
sim20 <- bind_rows(
  lapply(
    1:100, simulate_HT,
    stands = stands,
    nStands = 20, acresPerPlot = 10
  )
)
sim30 <- bind_rows(
  lapply(
    1:100, simulate_HT,
    stands = stands,
    nStands = 30, acresPerPlot = 10
  )
)
sim40 <- bind_rows(
  lapply(
    1:100, simulate_HT,
    stands = stands,
    nStands = 40, acresPerPlot = 10
  )
)

simFrame <- bind_rows(sim10, sim20, sim30, sim40)

simStats <- simFrame %>%
  mutate(
    meanInCI = ifelse(
      truth$meanCuft <= meanCuft + ci90MeanCuft & truth$meanCuft >= meanCuft - ci90MeanCuft,
      TRUE,
      FALSE
    )
  ) %>%
  group_by(nObs) %>%
  summarize(
    simMean = mean(meanCuft),
    propMatchCI = mean(meanInCI)
  )
  
ggplot(data = simFrame, aes(x = meanCuft)) +
  geom_histogram() +
  theme_bw() +
  facet_wrap(~nObs) +
  xlim(0, max(simFrame$meanCuft)) +
  geom_vline(xintercept = truth$meanCuft, color = "blue") +
  geom_vline(
    data = simStats,
    aes(xintercept = simMean),
    color = "red"
  )
## `stat_bin()` using `bins = 30`. Pick better value with `binwidth`.
## Warning: Removed 8 rows containing missing values (geom_bar).
```

![](/assets/images/2019-01-31-horvitz_thompson_simulate-1.png)
