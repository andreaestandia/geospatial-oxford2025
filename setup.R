# ===== Package Installation Instructions =====
# IMPORTANT: Run these commands only ONCE to install required packages.
# If you've already installed these packages before, you can skip this step.

# These packages are required for spatial data handling and mapping:
# Run once to install packages
install.packages(c(
  "dplyr",
  "ggplot2",
  "sysfonts", 
  "showtext",
  "here", 
  "terra", 
  "geodata", 
  "rnaturalearth", 
  "rnaturalearthdata",
  "dismo", 
  "tidyverse", 
  "rgbif", 
  "raster" 
))

# After installation, you'll need to load these packages using library()
# See the next script (practical.qmd
).