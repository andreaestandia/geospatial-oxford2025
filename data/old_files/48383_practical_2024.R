# ============================================
#        Species Distribution Modelling
# ============================================

# A practical guide to modeling species distributions using R
# Originally by Tim Barraclough (tim.barraclough@biology.ox.ac.uk)
# Modified by Nilo M. Recalde (nilo.recalde@biology.ox.ac.uk)
# Based on tutorials from: https://rspatial.org/raster/sdm/

# This script demonstrates how to:
# 1. Download and process world map data
# 2. Obtain species locality data from GBIF (Global Biodiversity Information Facility)
# 3. Access climate data from WorldClim
# 4. Model species distributions based on climate variables
# 5. Predict future distributions under climate change scenarios

# The approach used here employs basic linear modeling to identify which climate variables 
# best predict current species distributions, project how distributions might shift with 
# future climate change, and isualize results using maps. Note that while this script uses 
# simple linear models, many other approaches exist for species distribution modeling (SDM).

# Load the libraries providing functions for spatial data handling and mapping.
# If you haven't installed these packages yet, see the setup script.
library(here)
library(dismo)
library(rworldmap)
library(sf)
library(geodata)

# Now let'sreate a simple project structure if it doesn't exist:
sapply(c("data/raw", "data/processed", "output"), function(dir) {
    dir_path <- here(dir)
    if (!dir.exists(dir_path)) dir.create(dir_path, recursive = TRUE)
})

# ==============================
# 1) Load world map and plot it
# ==============================

wrld_simpl <- getMap(resolution = "coarse")
plot(wrld_simpl) # yay, a map!


# ===========================================================
# 2) Download locality data for a species from GBIF and trim
# ===========================================================

# Access records from GBIF (Global Biodiversity Information Facility) for a species using the dismo package.
# I am looking at Coffea arabica, the coffee species used for arabica coffee production.
# The function gbif() downloads data for a species, and the geo argument specifies that we want only records 
# with geographic coordinates.

species.gbif_file <- here("data", "raw", "species.gbif.rds")
if (!file.exists(species.gbif_file)) {
    species.gbif <- gbif("coffea", "arabica", geo = TRUE)
    saveRDS(species.gbif, species.gbif_file)
} else {
    species.gbif <- readRDS(species.gbif_file)
}

# Pull out the lat and lon columns. There is a lot more info in the `species.gbif` dataframe (>200 variables!) 
# if you want it, but we don't need it here. Let's also delete rows with missing spatial coordinates.
species.coords <- cbind(species.gbif$lon, species.gbif$lat)
species.coords <- na.omit(species.coords)
species.coords <- data.frame(species.coords)
colnames(species.coords) <- c("lon", "lat")

# Plot on world country map, setting the xlim and ylim to span the range of longitudes and latitudes
plot(wrld_simpl, xlim = range(species.coords$lon), ylim = range(species.coords$lat), axes = TRUE, col = "light yellow")
# Add points for this species
points(species.coords, col = "red", cex = 0.75)

# This includes the whole world: let's trim down to the data for Africa, to make it easier to work with.
# A bit of digging online suggests latitudes +40 to -40 and longitudes -20 to +55.

# First, here is a function to pull out just the data within a lat and lon range. Note how we have documented it: 
# this is good practice for your own functions, and will help you remember what they do later on.

#' Trim coordinates based on bounding box
#' 
#' This function filters a spatial data frame to keep only points within specified
#' latitude and longitude boundaries.
#'
#' @param x A data frame containing latitude and longitude columns named 'lat' and 'lon'
#' @param latmin Minimum latitude (southern boundary)
#' @param latmax Maximum latitude (northern boundary)
#' @param lonmin Minimum longitude (western boundary)
#' @param lonmax Maximum longitude (eastern boundary)
#'
#' @return A filtered data frame containing only points within the specified boundaries
#' 
#' @examples
#' df <- data.frame(lat = c(30, 35, 40), lon = c(-120, -115, -110))
#' trim.coords(df, 32, 38, -118, -112)
trim.coords <- function(x, latmin, latmax, lonmin, lonmax) {
    x[x$lon >= lonmin & x$lon <= lonmax & x$lat >= latmin & x$lat <= latmax, ]
}

# Then use the function to make a new table of coordinates, just within the ranges specified
species.coords.trim <- trim.coords(species.coords, latmin = -40, latmax = 40, lonmin = -20, lonmax = 55)

# Plot world map again now using the trimmed data:
plot(wrld_simpl, xlim = range(species.coords.trim$lon), ylim = range(species.coords.trim$lat), axes = TRUE, col = "light yellow")
# And add points for this species
points(species.coords.trim, col = "red", cex = 0.75)

# If it looks OK, let's use the trimmed version as our new coordinates
species.coords <- species.coords.trim

# We only want to consider the continental land area, so let's to remove the ocean areas from the map.
# We can use the ocean shapefile from the Natural Earth dataset to do this.

# Download ocean data
ocean_data_dir <- here("data", "raw", "ocean")
if (!dir.exists(ocean_data_dir)) dir.create(ocean_data_dir)
URL <- "https://naturalearth.s3.amazonaws.com/110m_physical/ne_110m_ocean.zip"
zip_file <- file.path(ocean_data_dir, basename(URL))
if (!file.exists(zip_file)) {
    download.file(URL, zip_file)
}

# Unzip to ocean data directory and read shapefile
files <- unzip(zip_file, exdir = ocean_data_dir)
oceans <- read_sf(grep("shp$", files, value = TRUE))

# Convert coordinates to a spatial features (sf) object for GIS operations
species.coords <- st_as_sf(species.coords, coords = c("lon", "lat"))
# Set the coordinate reference system (CRS) to match the oceans data
st_crs(species.coords) <- st_crs(oceans)
sf_use_s2(FALSE)  # Disable spherical geometry

# Find where out points intersect with the ocean
tmp <- sapply(st_intersects(species.coords, oceans), function(z) if (length(z) == 0) NA_integer_ else z[1])

# Remove points that intersect with the ocean and convert back to table of coordinates
if (sum(!is.na(tmp)) > 0) {
    species.coords <- data.frame(st_coordinates(species.coords[is.na(tmp), ]))
} else {
    species.coords <- data.frame(st_coordinates(species.coords))
}
colnames(species.coords) <- c("lon", "lat")

# Now plot again to check
plot(wrld_simpl, xlim = range(species.coords$lon), ylim = range(species.coords$lat), axes = TRUE, col = "light yellow")
points(species.coords, col = "red", cex = 0.75)



# ======================================================================
# 3) Extract climatic values for the localities occupied by the species
# ======================================================================

# Download bioclimatic data from the worldclim database and convert to Raster format
bio.data <- worldclim_global(var = "bio", res = 10, path = here("data", "raw"))
names(bio.data) <- paste0("bio", 1:19)

# The bio.data object contains 19 bioclimatic variables from WorldClim
# Each variable represents different aspects of temperature and precipitation
# See full descriptions at: https://www.worldclim.org/data/bioclim.html
# 
# Examples:
# BIO1 = Annual Mean Temperature
# BIO2 = Mean Diurnal Range (Mean of monthly (max temp - min temp))
# BIO3 = Isothermality (BIO2/BIO7) (×100)
# ...
#
# The data is stored as a RasterStack, where each layer is one bioclimatic variable, 
# each pixel represents a 10 arc-minute (~18.5km) grid cell, and the pixel values 
# contain the climate data

# Let's visualize the first two variables:
plot(bio.data, 1, main="Annual Mean Temperature")
plot(bio.data, 2, main="Mean Diurnal Range")

# You can extract bioclimatic data for the focal localities in Africa where your species is found
bio.values <- extract(bio.data, species.coords)[, -1]
rownames(bio.values) <- rownames(species.coords)

# And plot them to see the range of environmental values the species lives in
plot(bio.values[, 1], bio.values[, 2])

# Or look at how different variables correlate; here focusing on the first five:
pairs(bio.values[, 1:5])

# Append to lat long, remove rows with missing data, and save to file for future use
species.data <- cbind(species.coords, bio.values)
write.csv(species.data, file = here("data", "processed", "species_data.csv"), row.names = FALSE)

# Extract mean values, min and max, as a sanity check for the data
rbind(
    mean = colMeans(species.data),
    min = apply(species.data, 2, min),
    max = apply(species.data, 2, max)
)

# =========================================================================
# 4) Model the species current distribution based on bioclimatic variables
# =========================================================================

# We will build a model to predict species presence (1) or absence (0) using bioclimatic variables (X). 
# However, we don’t have true absence data—locations where we are certain the species is not present. 
# Without absence data, the model cannot distinguish between areas where the species might be absent 
# and areas we simply haven’t surveyed. To address this, we generate "pseudo-absence" data by sampling 
# random background points from the region, assuming these locations represent areas where the species 
# is unlikely to occur. Pseudo-absence is essential because it provides a contrast to presence data, 
# allowing the model to learn patterns associated with species occurrence.

# Question 1: What are the limitations of this approach?

# 4.1) Generate random background points for comparison

# Define study extent based on species occurrence data (with some buffer around it)
e <- extent(
    min(species.coords$lon) - 5,
    max(species.coords$lon) + 5,
    min(species.coords$lat) - 5,
    max(species.coords$lat) + 5
)

# Create a mask from the world map for the study region
mask <- rasterize(wrld_simpl, raster(e, res=0.5))

# Generate 500 random background points within the study region
bg <- randomPoints(mask, 500, ext=e)
colnames(bg) <- c("lon", "lat")

# Visualize the results
plot(crop(wrld_simpl, e), col="grey90", legend=FALSE, border = NA, 
    main="Species occurrences and background points")
points(bg, col="black", pch=20, cex=0.7)
points(species.coords, col="red", pch=20, cex=0.7)

# Question 2: Why is it better not to have too large a region for your background?
# Question 3: Do you think C. arabica is really absent from all the
# localities selected as background points? Will it matter?

# Now we are settled on our area of extent, we can crop the bio.data to just keep values for this region
# It isn't essential but speeds up some later steps
bio.data <- crop(bio.data, e)


# 4.2 Next step: combine the presence data and the background data in one data frame

train <- rbind(species.coords, bg)
# Create a vector of 1s and 0s to indicate presence/absence
pb_train <- c(rep(1, nrow(species.coords)), rep(0, nrow(bg)))
# Extract the bioclimatic data for the presence and background points
envtrain <- extract(bio.data, train)
envtrain <- data.frame(cbind(pa = pb_train, envtrain))
# And for each set separately
testpres <- data.frame(extract(bio.data, species.coords))
testbackg <- data.frame(extract(bio.data, bg))


# 4.3 Now we are ready to fit a logistic regression to predict presence/absence.
# We use a general linear model assuming binomial errors, which is appropriate
# for modelling a binary Y variable of 0s and 1s.
# More on this in Year 2 lecture Analysis of associations Part III: Non-Linear Regression Bonsall, Michael, and in Year 4!

# To start with I am including the first 5 bioclim variables as predictors, but you could include 1,2, or more.
gm1 <- glm(pa ~ bio1 + bio2 + bio3 + bio4 + bio5,
    family = binomial(link = "logit"), data = envtrain
)

# Look at a summary of the results
summary(gm1)

# Question 4: Which variables contribute significantly to explaining presence/absence?

# 4.4 Predict species distribution from the model and plot it
# Based on the model, we can predict the probability of occurrence of the species
# across the whole of the area being considered
pg <- predict(bio.data, gm1, ext = e, type = "response")
pg <- crop(pg, e)

# pg is a raster layer, like for our bioclim variables, but now representing the
# probability of occurrence from our linear model, for or area of extent e.

# Plot this
plot(pg, main = "GLM probability of occurrence")
# Add country boundaries
plot(wrld_simpl, add = TRUE, border = "dark grey")
# Add our observed locality data
points(species.coords, col="red", pch=20, cex=1.5)

# Question 5: How well do you think the model has predicted the distribution?

# If you want to show a single map of distribution instead, can convert the
# probabilities by selecting a threshold that gives the best match between predicted
# and observed localities.

# First, we evaluate how well the model predicts presence/absence at each point
ge <- evaluate(testpres, testbackg, gm1)
print(ge)

# The output gives several metrics such as:
# Area Under the Curve: AUC, and correlation coefficient between observed and predicted.
# Higher values of both metrics = better match between model predictions and observed
# presence/absences.

# Then we use this evaluation to pick a threshold probability for defining presence/absence
# using the model that gives the most accurate match to observed presence/absence
tr <- threshold(ge, "prevalence")
plot(pg > tr, main = "presence/absence")
plot(wrld_simpl, add = TRUE, border = "dark grey")
points(species.coords, col="red", pch=20, cex=1.5)

# 4.5 You can construct and compare different models

# This model uses next 5 climatic variables instead
gm2 <- glm(pa ~ bio6 + bio7 + bio8 + bio9 + bio10, family = binomial(link = "logit"), data = envtrain)
summary(gm2)

# You can compare two models, even with different predictor variables, using the Akaike Information Criterion
AIC(gm1, gm2)

# AIC helps compare model fit vs complexity (lower = more parsimonious)
# While differences >2 units suggest meaningful differences between models,
# model selection should be guided by theory and research questions,
# not just by AIC or p-values. Consider multiple evaluation metrics and
# use cross-validation when possible, and give enough thought to what your aims are: do you want to 
# predict well, or understand the underlying biology?

# You can try fitting different models with different predictor variables, but
# remember that the more variables you test, the more likely you are to overfit the observed data, which can 
# lead to poor predictions on new data.

# You can also compare metrics of how well the model predicts the data
evaluate(testpres, testbackg, gm1)
evaluate(testpres, testbackg, gm2)

# Question 6: Which bioclimatic variables do you expect to be most important for the species?
# Does a model including these variables predict distribution better than alternatives?


# =========================================================================
# 5) Predict future distributions under climate change scenarios
# =========================================================================


# Step 1: Download future climate projections
# We'll use CMIP5 (Coupled Model Intercomparison Project Phase 5) data, specifically for the time 
# period: 2061-2080, using one selected climate model (from many available), and with one set of parameters.
# Note that while CMIP5 contains many models and scenarios, we're using just one
# combination to demonstrate the methods

future.bio.data <- cmip6_world(
    model = "CanESM5",
    var = "bio", 
    ssp = "245",
    res = 10,
    time = "2061-2080",
    path = here("data", "raw")
)
names(future.bio.data) <- names(bio.data)

# Crop future climate data to region of interest for efficiency
future.bio.data <- crop(future.bio.data, e)

# Fit model with present data
gm1 <- glm(pa ~ bio1 + bio2 + bio3 + bio4 + bio5,
    family = binomial(link = "logit"), data = envtrain
)

# Calculate predictions for present and future
pg <- predict(bio.data, gm1, ext = e, type = "response")
pg <- crop(pg, e)
pg.future <- predict(future.bio.data, gm1, ext = e, type = "response")
pg.future <- crop(pg.future, e)

# Plot results side by side
par(mfrow = c(1, 2))

# Present distribution
plot(pg, main = "A) GLM present")
plot(wrld_simpl, add = TRUE, border = "dark grey")
points(species.coords, col = "black", pch = 4, cex = 0.5)

# Future distribution
plot(pg.future, main = "B) GLM, 2060-2081")
plot(wrld_simpl, add = TRUE, border = "dark grey")
points(species.coords, col = "black", pch = 4, cex = 0.5)

# Question 7: How is the distribution of the species expected to change in the future?

# Extract counts for range changes
# First, get predictions for present and future at all localities
predict.localities.now <- extract(pg >= tr, species.coords)[, -1]
predict.localities.future <- extract(pg.future >= tr, species.coords)[, -1]

# We can extract some numbers about how the range will change, for example:
present_range <- sum(predict.localities.now)
future_range <- sum(predict.localities.future, na.rm = TRUE)
range_expansion <- sum((predict.localities.now == 0) & (predict.localities.future == 1), na.rm = TRUE)
range_contraction <- sum((predict.localities.now == 1) & (predict.localities.future == 0), na.rm = TRUE)

# Print results in a clear format
print("Range change metrics:")
print(paste("Current suitable localities:", present_range))
print(paste("Future suitable localities:", future_range))
print(paste("Number of new suitable localities (expansion):", range_expansion))
print(paste("Number of lost suitable localities (contraction):", range_contraction))


# Question 8: Use these numbers to calculate the percentage contraction or expansion in the range.

# A final plot that can be useful to understand causes of changes is one showing how climate will change

# Work out the change in bioclim variables from now to the future
change.bio.data <- future.bio.data - bio.data

# plot present, future and change in climate for bioclim 1 variable, mean annual temperature.
par(mfrow = c(1, 3))
plot(bio.data[[1]], ext = e, main = "Present Day")
plot(future.bio.data[[1]], ext = e, main = "2061-2080")
plot(change.bio.data[[1]], ext = e, main = "Projected Change") 
