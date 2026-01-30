# ==============================================================================
# Step 1: Market Data Acquisition & Stylized Facts Analysis
# ==============================================================================

# 1. Setup Environment
# ------------------------------------------------------------------------------
# Function to install and load packages automatically
install_and_load <- function(packages) {
  for (pkg in packages) {
    if (!require(pkg, character.only = TRUE)) {
      message(paste("Installing package:", pkg))
      install.packages(pkg, dependencies = TRUE)
      library(pkg, character.only = TRUE)
    } else {
      library(pkg, character.only = TRUE)
    }
  }
}

# List of required libraries for this step
# quantmod: For downloading financial data from Yahoo Finance
# PerformanceAnalytics: For financial charts and metrics
# tseries: For statistical tests (Jarque-Bera)
required_packages <- c("quantmod", "PerformanceAnalytics", "tseries")

install_and_load(required_packages)

# 2. Download Data
# ------------------------------------------------------------------------------
# We use the S&P 500 (^GSPC) to analyze market risk.
# You can change ticker to "BTC-USD" for crypto.
ticker <- "^GSPC" 
start_date <- "2018-01-01"

message("Downloading data for ", ticker, "...")
data_env <- new.env()
getSymbols(ticker, src = "yahoo", from = start_date, to = Sys.Date(), env = data_env)

# Extract the Adjusted Close prices
# The getSymbols function creates a variable with the ticker name (e.g., GSPC)
prices <- data_env$GSPC[, 6] # Column 6 is usually Adjusted Close
colnames(prices) <- "Price"

# 3. Calculate Log Returns
# ------------------------------------------------------------------------------
# Log returns are used because they are time-additive and symmetric
log_returns <- CalculateReturns(prices, method = "log")
log_returns <- na.omit(log_returns) # Remove the first NA value (empty row)
colnames(log_returns) <- "LogReturns"

# 4. Visualization & Statistical Tests
# ------------------------------------------------------------------------------

# Plot 1: Time Series of Returns (Volatility Clustering)
# Look for periods where high volatility persists (clusters)
plot(log_returns, main = paste("Daily Log Returns:", ticker), 
     col = "blue", lwd = 0.5)

# Plot 2: Q-Q Plot (The Proof of Heavy Tails)
# We use a 4-panel layout to show different stylized facts
par(mfrow = c(2, 2)) 

# Histogram
hist(log_returns, breaks = 100, main = "Histogram of Returns", 
     col = "lightblue", border = "white", prob = TRUE)
curve(dnorm(x, mean = mean(log_returns), sd = sd(log_returns)), 
      add = TRUE, col = "red", lwd = 2) # Add Normal distribution curve for comparison

# Q-Q Plot
qqnorm(log_returns, main = "Q-Q Plot (Normal Distribution Check)")
qqline(log_returns, col = "red", lwd = 2)

# Reset plot layout
par(mfrow = c(1, 1))

# Statistical Test: Jarque-Bera
# H0 (Null Hypothesis): Data is distributed Normally
# If p-value < 0.05, we reject Normality -> We need EVT.
jb_test <- jarque.bera.test(log_returns)

print("--- Jarque-Bera Test Results ---")
print(jb_test)