
# Computing Assignment: Geo-data and Methods in R

**Contact:** 
andrea.estandia@biology.ox.ac.uk & nilo.recalde@biology.ox.ac.uk.
<br>**Date:** 5th November 2025

## Assignment

Choose two species that you think interact in some way, either as competitors, predator-prey, mutualists or host-parasite. You should choose species that have locality data available on GBIF. If your species don't have data, pick another pair that do. Then complete the following tasks. For each task, provide a brief legend (no more than 150 words) summarising the analysis used to generate each the plot(s) and describing what the results show.

### 1. Species 1 Distribution Modelling
Run linear models to predict the present-day distribution of species 1 using climate variables and use them to present a map of its current distribution. Which set of climatic variables best explain the current distribution of the species?

### 2. Species 2 Distribution Modelling
Run linear models to predict the present-day distribution of species 2 using climate variables and use them to present maps of its current distribution. Which set of climatic variables best explain the current distribution of the species?

### 3. Distribution overlap
Plot the overlap in distribution of the two species. Devise and calculate a metric for the degree of overlap between their ranges, explaining how you calculated it.

### 4. Interspecies distribution dependence
Use a linear model to test whether the distribution of species 1 at the present time depends on the distribution of species 2, while also taking account of the effects of climatic variables.

### 5. Future distribution prediction
Predict the future distribution of each species using CMIP6 data for future climate and predict how the degree of overlap in ranges change will change in that time. Do you expect the two species to co-occur more often or less often than at the present?

## Submission requirements

- Write your report using Quarto
- Submit both your `.Qmd` file containing the code and the `.html` produced by knitting the document
- Anyone unsure about how to produce a report using Quarto should run through the material on canvas and ask demonstrators. See: MT 60784; reproducible research documents with R and Quarto ([https://canvas.ox.ac.uk/courses/273641](https://canvas.ox.ac.uk/courses/273641/modules#module_452046))

**Coding Guidelines:**
- Aim to write your code so that it would run for a new pair of species simply by changing the input data at the start, i.e. using general rather than specific coding
- Use reproducible research principles where possible (e.g. use of functions, comments, clear variable names, reproducible environments using renv).
- See general feedback on MT computer assignments

**Important notes:**
- Do not collaborate on assignments
- Examiners will check code for evidence of plagiarism

## Marking scheme

The marking scheme for computer assignments is on page 32 of the conventions. It is weighted equally between how well your code runs and the quality of the presentation of the report.

More information on computer skills assignments: https://canvas.ox.ac.uk/courses/273637/pages/computer-skills-assignments?module_item_id=2667596
Examination Conventions: [https://canvas.ox.ac.uk/courses/281159/pages/mbiol-exam-conventions?module_item_id=2751673](https://canvas.ox.ac.uk/courses/281159/pages/mbiol-exam-conventions?module_item_id=2751673)