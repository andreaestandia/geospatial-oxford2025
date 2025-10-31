# ===== Package Installation Instructions =====
# IMPORTANT: Run these commands only ONCE to install required packages.
# If you've already installed these packages before, you can skip this step.

# These packages are required for spatial data handling and mapping:

install.packages("dismo")      # Species distribution modeling
install.packages("rworldmap")  # For creating world maps
install.packages("sf")         # Spatial data handling
install.packages("geodata")    # Geographic data access
install.packages("here")       # File path management
install.packages("tibble")     # Enhanced data frames (required by sf)

# After installation, you'll need to load these packages using library()
# See the next script (practical.R).
