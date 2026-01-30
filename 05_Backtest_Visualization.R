# ==============================================================================
# Step 5: Dynamic VaR Visualization (Backtesting View)
# ==============================================================================

# 1. Calculate Dynamic VaR for the whole history
# ------------------------------------------------------------------------------
# We calculated the "Risk Quantile" for the residuals in Step 4.
# EVT Quantile (Constant for residuals):
q_evt_residual <- (var_evt_residual) # From previous step
# Normal Quantile (Constant):
q_normal <- qnorm(0.99)

# Now we scale this by the dynamic volatility (Sigma_t) over time
# This creates a "Time-Varying VaR"
VaR_EVT_Series <- volatility * q_evt_residual
VaR_Normal_Series <- volatility * q_normal

# 2. Create a Data Frame for Plotting
# ------------------------------------------------------------------------------
# We combine dates, returns, and both VaR estimates
plot_data <- data.frame(
  Date = index(log_returns),
  Returns = as.numeric(log_returns),
  VaR_Normal = -as.numeric(VaR_Normal_Series), # Negative because VaR is a loss
  VaR_EVT = -as.numeric(VaR_EVT_Series)
)

# 3. Visualization using ggplot2
# ------------------------------------------------------------------------------
library(ggplot2)

ggplot(plot_data, aes(x = Date)) +
  # A. Plot Returns (Grey Bars)
  geom_bar(aes(y = Returns), stat = "identity", fill = "gray80", color = "gray80", width = 1) +
  
  # B. Plot Normal VaR (Blue Dashed Line)
  geom_line(aes(y = VaR_Normal, color = "Normal VaR (99%)"), size = 0.8, linetype = "dashed") +
  
  # C. Plot EVT VaR (Red Solid Line)
  geom_line(aes(y = VaR_EVT, color = "EVT-GARCH VaR (99%)"), size = 0.8) +
  
  # D. Highlight "Breaches" (Where Returns were WORSE than EVT VaR)
  # These are the true Black Swans that even EVT couldn't catch (should be rare)
  geom_point(data = subset(plot_data, Returns < VaR_EVT),
             aes(y = Returns), color = "red", size = 2, shape = 4) +
  
  # E. Styling
  scale_color_manual(values = c("EVT-GARCH VaR (99%)" = "red", "Normal VaR (99%)" = "blue")) +
  labs(
    title = "Backtesting: Normal vs EVT Risk Models",
    subtitle = paste("The EVT model captures tail risk better. Normal model underestimates risk by ~", round(diff_pct, 1), "%."),
    y = "Daily Log Returns",
    x = "Date",
    color = "Risk Model"
  ) +
  theme_minimal() +
  theme(legend.position = "bottom")