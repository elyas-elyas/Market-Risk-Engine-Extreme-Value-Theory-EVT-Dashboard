# ==============================================================================
# Step 3: Extreme Value Theory (EVT) - Peaks Over Threshold (POT)
# ==============================================================================

# 1. Load EVT Library
# ------------------------------------------------------------------------------
# 'evir' is a standard package for Extreme Value Analysis in R
if (!require("evir")) install.packages("evir")
library(evir)

if (!exists("std_residuals")) {
  stop("Error: 'std_residuals' not found. Please run Script 02 first!")
}

# 2. Focus on Losses (Negative Returns)
# ------------------------------------------------------------------------------
# EVT is usually applied to losses. Since our returns are pos/neg, 
# we invert the sign so that "Losses" become positive numbers for the model.
# We focus on the "Left Tail" (Downside Risk).
losses <- -as.numeric(std_residuals)

# 3. Threshold Selection (The Art of EVT)
# ------------------------------------------------------------------------------
# We need to decide where the "Tail" begins.
# A common standard is the 90th or 95th percentile.
threshold_quantile <- 0.90
u <- quantile(losses, threshold_quantile)

message(paste("Selected Threshold (u):", round(u, 4)))
message(paste("Number of exceedances:", sum(losses > u)))

# Visual Tool: Mean Excess Plot
# Look for the point where the graph becomes linear (a straight line).
# That confirms a Pareto behavior.
meplot(losses, main = "Mean Excess Plot (Look for Linearity)")
abline(v = u, col = "red", lty = 2) # Mark our chosen threshold

# 4. Fit the GPD (Generalized Pareto Distribution)
# ------------------------------------------------------------------------------
# We fit the model only on data points > u
gpd_fit <- gpd(losses, threshold = u)

# 5. Analyze the Results
# ------------------------------------------------------------------------------
# xi (shape parameter):
#   If xi > 0 : Heavy tail (The most dangerous type, typical for finance)
#   If xi = 0 : Light tail (Normal-like)
#   If xi < 0 : Finite tail (No risk of infinite loss)
print(gpd_fit$par.ests) # Estimated parameters (xi, beta)
print(gpd_fit$par.ses)  # Standard Errors (precision of the estimate)

# Visual check of the fit
# This will produce 4 plots.
# - Tail Plot: Shows how well the model (curve) fits the extreme data (dots).
par(mfrow = c(2, 2))
plot(gpd_fit) 
par(mfrow = c(1, 1))

# Save the model for the next step
saveRDS(gpd_fit, file = "gpd_model.rds")