# ==============================================================================
# EVT Risk Engine - Interactive Dashboard (CORRECTED VERSION)
# Author: Elyas Assili
# ==============================================================================

library(shiny)
library(shinydashboard)
library(quantmod)
library(rugarch)
library(evir)
library(ggplot2)
library(PerformanceAnalytics)

# ==============================================================================
# 1. UI (User Interface) - Identique
# ==============================================================================
ui <- dashboardPage(
  skin = "black", 
  
  dashboardHeader(title = "Quant Risk Engine"),
  
  dashboardSidebar(
    sidebarMenu(
      menuItem("Dashboard", tabName = "dashboard", icon = icon("dashboard")),
      menuItem("Model Info", tabName = "info", icon = icon("info-circle"))
    ),
    br(),
    textInput("ticker", "Asset Ticker (Yahoo)", value = "^GSPC"),
    
    dateRangeInput("dates", "Date Range",
                   start = "2018-01-01", end = Sys.Date()),
    
    sliderInput("conf_level", "Confidence Level (VaR)", 
                min = 0.90, max = 0.999, value = 0.99, step = 0.001),
    
    sliderInput("evt_thresh", "EVT Threshold (Quantile)", 
                min = 0.90, max = 0.98, value = 0.90, step = 0.01),
    
    actionButton("run_analysis", "Run Risk Analysis", icon = icon("play"), 
                 style = "color: #fff; background-color: #d9534f; border-color: #d43f3a; width: 85%; margin-left: 15px;")
  ),
  
  dashboardBody(
    tabItems(
      tabItem(tabName = "dashboard",
              fluidRow(
                valueBoxOutput("box_normal_var", width = 4),
                valueBoxOutput("box_evt_var", width = 4),
                valueBoxOutput("box_diff", width = 4)
              ),
              fluidRow(
                box(
                  title = "Backtesting: Normal VaR vs. EVT-GARCH VaR", 
                  status = "primary", solidHeader = TRUE, width = 12,
                  plotOutput("plot_backtest", height = "400px")
                )
              ),
              fluidRow(
                box(
                  title = "Volatility Clustering (GARCH)", 
                  status = "warning", solidHeader = TRUE, width = 6,
                  plotOutput("plot_volatility", height = "300px")
                ),
                box(
                  title = "Tail Risk Analysis (QQ Plot)", 
                  status = "danger", solidHeader = TRUE, width = 6,
                  plotOutput("plot_qq", height = "300px")
                )
              )
      ),
      
      tabItem(tabName = "info",
              h2("Model Methodology"),
              p("This engine uses a hybrid approach to estimate Tail Risk:"),
              tags$ul(
                tags$li("Step 1: GARCH(1,1) filters volatility clustering."),
                tags$li("Step 2: Peaks Over Threshold (POT) models the residuals using Generalized Pareto Distribution (GPD)."),
                tags$li("Step 3: Dynamic VaR is calculated by recombining volatility and tail parameters.")
              )
      )
    )
  )
)

# ==============================================================================
# 2. Server (Backend Logic) - CORRIGÉ
# ==============================================================================
server <- function(input, output) {
  
  data_analysis <- eventReactive(input$run_analysis, {
    
    # --- FIX START: Secure Data Fetching ---
    withProgress(message = 'Downloading Data...', value = 0.2, {
      
      req(input$ticker) 
      
      # We use auto.assign = FALSE to get the data directly into the 'data' variable
      # regardless of the ticker name (avoids the ^GSPC vs GSPC issue)
      tryCatch({
        data_raw <- getSymbols(input$ticker, src = "yahoo", 
                               from = input$dates[1], to = input$dates[2], 
                               auto.assign = FALSE)
      }, error = function(e) {
        showNotification("Error downloading data. Check Ticker.", type = "error")
        return(NULL)
      })
      
      # Select Adjusted Close (Column 6) and keep it as Time Series (drop=FALSE)
      prices <- data_raw[, 6, drop = FALSE]
      colnames(prices) <- "Price"
      
      returns <- CalculateReturns(prices, method = "log")
      returns <- na.omit(returns)
      # --- FIX END ---
      
      # 2. Fit GARCH(1,1)
      incProgress(0.3, detail = "Fitting GARCH Model...")
      spec <- ugarchspec(variance.model = list(model = "sGARCH", garchOrder = c(1, 1)),
                         mean.model = list(armaOrder = c(0, 0), include.mean = TRUE),
                         distribution.model = "norm")
      
      garch_fit <- ugarchfit(spec = spec, data = returns)
      
      # Safety check if GARCH fails
      if(convergence(garch_fit) != 0) {
        showNotification("GARCH model failed to converge.", type = "warning")
      }
      
      volatility <- sigma(garch_fit)
      std_resid <- residuals(garch_fit, standardize = TRUE)
      
      # 3. Fit EVT (GPD)
      incProgress(0.3, detail = "Modeling Tails (EVT)...")
      losses <- -as.numeric(std_resid)
      u_val <- quantile(losses, input$evt_thresh)
      gpd_fit <- evir::gpd(losses, threshold = u_val)
      
      # 4. Calculate Risk Metrics
      xi <- gpd_fit$par.ests["xi"]
      beta <- gpd_fit$par.ests["beta"]
      p <- 1 - input$conf_level
      N <- length(losses)
      Nu <- sum(losses > u_val)
      
      # Formulas
      var_normal_static <- qnorm(input$conf_level)
      
      term1 <- (N / Nu) * p
      term2 <- term1^(-xi) - 1
      var_evt_residual <- u_val + (beta / xi) * term2
      
      VaR_Normal_Series <- volatility * var_normal_static
      VaR_EVT_Series <- volatility * var_evt_residual
      
      last_vol <- tail(volatility, 1)
      val_var_norm <- last_vol * var_normal_static
      val_var_evt <- last_vol * var_evt_residual
      
      list(
        returns = returns,
        volatility = volatility,
        std_resid = std_resid,
        VaR_Normal_Series = VaR_Normal_Series,
        VaR_EVT_Series = VaR_EVT_Series,
        val_var_norm = val_var_norm,
        val_var_evt = val_var_evt,
        gpd_fit = gpd_fit
      )
    })
  })
  
  # --- Outputs ---
  
  output$box_normal_var <- renderValueBox({
    res <- data_analysis()
    req(res) # Ensure data exists
    val <- round(as.numeric(res$val_var_norm) * 100, 2)
    valueBox(
      paste0(val, "%"), "Normal VaR (1-Day)", icon = icon("chart-line"),
      color = "blue"
    )
  })
  
  output$box_evt_var <- renderValueBox({
    res <- data_analysis()
    req(res)
    val <- round(as.numeric(res$val_var_evt) * 100, 2)
    valueBox(
      paste0(val, "%"), "EVT-GARCH VaR (1-Day)", icon = icon("shield-alt"),
      color = "red"
    )
  })
  
  output$box_diff <- renderValueBox({
    res <- data_analysis()
    req(res)
    diff <- (res$val_var_evt - res$val_var_norm) / res$val_var_norm * 100
    valueBox(
      paste0(round(diff, 1), "%"), "Underestimation by Normal Model", 
      icon = icon("exclamation-triangle"),
      color = "orange"
    )
  })
  
  output$plot_backtest <- renderPlot({
    res <- data_analysis()
    req(res)
    dates <- index(res$returns)
    
    df <- data.frame(
      Date = dates,
      Returns = as.numeric(res$returns),
      VaR_N = -as.numeric(res$VaR_Normal_Series),
      VaR_E = -as.numeric(res$VaR_EVT_Series)
    )
    
    ggplot(df, aes(x = Date)) +
      geom_bar(aes(y = Returns), stat = "identity", fill = "gray90", width = 1) +
      geom_line(aes(y = VaR_N, color = "Normal VaR"), linewidth = 0.8, linetype = "dashed") +
      geom_line(aes(y = VaR_E, color = "EVT VaR"), linewidth = 0.8) +
      scale_color_manual(values = c("Normal VaR" = "blue", "EVT VaR" = "red")) +
      labs(y = "Log Returns", x = "") +
      theme_minimal() +
      theme(legend.position = "top", legend.title = element_blank())
  })
  
  output$plot_volatility <- renderPlot({
    res <- data_analysis()
    req(res)
    plot(res$volatility, main = "Conditional Volatility (Sigma)", 
         col = "darkorange", lwd = 1, major.ticks = "years", grid.ticks.on = "years")
  })
  
  output$plot_qq <- renderPlot({
    res <- data_analysis()
    req(res)
    qqnorm(res$std_resid, main = "QQ Plot of Residuals vs Normal")
    qqline(res$std_resid, col = "red", lwd = 2)
  })
}

shinyApp(ui, server)