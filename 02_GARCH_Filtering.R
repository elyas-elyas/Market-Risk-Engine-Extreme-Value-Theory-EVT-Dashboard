# ==============================================================================
# Step 2: GARCH Modeling & Volatility Filtering
# ==============================================================================

# 1. Load the GARCH library
# ------------------------------------------------------------------------------
if (!require("rugarch")) install.packages("rugarch")
library(rugarch)

# Ensure we have the data (if you cleared your environment)
if (!exists("log_returns")) {
  stop("Error: 'log_returns' not found. Please run Script 01 first!")
}

# 2. Define the GARCH Model Specification
# ------------------------------------------------------------------------------
# We use a Standard GARCH(1,1) with a Normal distribution for the innovation
# Why Normal? Because we want the GARCH to capture the variance, 
# and let the EVT (later) handle the fat tails of the residuals.
spec <- ugarchspec(
  variance.model = list(model = "sGARCH", garchOrder = c(1, 1)),
  mean.model = list(armaOrder = c(0, 0), include.mean = TRUE),
  distribution.model = "norm"
)

# 3. Fit the Model to the Data
# ------------------------------------------------------------------------------
message("Fitting GARCH(1,1) model... This might take a moment.")
garch_fit <- ugarchfit(spec = spec, data = log_returns)

# Show the robustness of the fit
print(garch_fit)

# 4. Extract Volatility and Residuals
# ------------------------------------------------------------------------------
# Sigma is the estimated conditional volatility (dynamic risk)
volatility <- sigma(garch_fit) 

# Standardized Residuals = Returns / Volatility
# These are the "clean" shocks we need for EVT
std_residuals <- residuals(garch_fit, standardize = TRUE)

# 5. Visualization: Before vs After
# ------------------------------------------------------------------------------
par(mfrow = c(2, 1)) # Split screen vertically

# Plot 1: Estimated Volatility (Risk over time)
# Notice how it spikes during crises (2020, 2022)
plot(volatility, main = "Estimated Conditional Volatility (GARCH)", 
     col = "orange", lwd = 1)

# Plot 2: Standardized Residuals
# These should look like "White Noise" (random, no clusters)
plot(std_residuals, main = "Standardized Residuals (Input for EVT)", 
     col = "darkgreen", lwd = 0.5)

par(mfrow = c(1, 1)) # Reset layout

# 6. Verify "i.i.d." Assumption (ACF Plot)
# ------------------------------------------------------------------------------
# We check Autocorrelation. If bars are within blue lines, data is clean/independent.
chart.ACF(std_residuals^2, main = "ACF of Squared Residuals (Check for Independence)")