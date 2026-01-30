# ==============================================================================
# Step 4: Risk Metrics Calculation (VaR & ES)
# ==============================================================================

# 1. Setup Parameters
# ------------------------------------------------------------------------------
# We want to estimate risk at 99% confidence level (standard for banks)
confidence_level <- 0.99
# The probability in the tail we are looking at (1 - 0.99 = 0.01)
p <- 1 - confidence_level 

# Retrieve latest data from previous steps
# volatility: The most recent conditional volatility from GARCH
# u: The threshold we used for EVT
# xi, beta: The parameters from the GPD fit
current_volatility <- as.numeric(tail(volatility, 1))
xi <- gpd_fit$par.ests["xi"]
beta <- gpd_fit$par.ests["beta"]

# Total number of observations and number of exceedances (Nu)
N <- length(losses)
Nu <- sum(losses > u)

# 2. Calculate VaR (Value at Risk)
# ------------------------------------------------------------------------------

# A. Normal VaR (The "Naive" approach)
# Formula: Mean + Z-score * Volatility
# qnorm(0.99) is approx 2.33
var_normal <- qnorm(confidence_level) * current_volatility

# B. EVT VaR (The "Expert" approach)
# Formula: Volatility * ( Threshold + (Beta/Xi) * ( ((N/Nu) * p)^(-xi) - 1 ) )
# This formula scales the tail risk by the current market volatility
term1 <- (N / Nu) * p
term2 <- term1^(-xi) - 1
var_evt_residual <- u + (beta / xi) * term2
var_evt <- var_evt_residual * current_volatility

# 3. Calculate Expected Shortfall (ES)
# ------------------------------------------------------------------------------
# ES is the average loss IF the VaR is breached.
# For EVT, the formula is:
es_evt_residual <- (var_evt_residual + beta - xi * u) / (1 - xi)
es_evt <- es_evt_residual * current_volatility

# 4. Display Results
# ------------------------------------------------------------------------------
message("--- RISK REPORT (1-Day Horizon) ---")
message(paste("Confidence Level:", confidence_level * 100, "%"))
message("-------------------------------------")
message(paste("Normal VaR:      ", round(var_normal * 100, 4), "%"))
message(paste("EVT-GARCH VaR:   ", round(var_evt * 100, 4), "%"))
message(paste("EVT-GARCH ES:    ", round(es_evt * 100, 4), "%"))
message("-------------------------------------")

# Interpretation Helper
diff_pct <- (var_evt - var_normal) / var_normal * 100
if(diff_pct > 0) {
  message(paste("Conclusion: The Normal model UNDERESTIMATES risk by", round(diff_pct, 2), "%"))
} else {
  message(paste("Conclusion: The Normal model OVERESTIMATES risk by", round(abs(diff_pct), 2), "%"))
}