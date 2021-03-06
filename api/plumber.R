#* @apiTitle Stock Information API
#* @apiVersion 1.0.0
#* @apiDescription This Plumber API surfaces the ability to programmatically request price history or a number representing the relative volatility of a stock ticker

#library(tidyquant)
#library(tidyverse)
library(glue)
library(RSQLite)
library(dplyr)
library(pool)

valid_tickers <- c(
  Apple = "AAPL",
  Amazon = "AMZN",
  Facebook = "FB",
  Google = "GOOG",
  Intel = "INTC",
  Microsoft = "MSFT"
)

cfg <- config::get("db", file = "config.yml")
con <- do.call(pool::dbPool, cfg)


# in an online environment,
# replace with 
# tidyquant::tq_get(ticker, from = "2010-01-01")
# to pull data directly from Yahoo
# (note to remove the valid_tickers checks)
get_price_data <- function(ticker = "AMZN", from = "2010-01-01", con) {
  ticker <- glue::single_quote(ticker)
  from <- as.integer(as.Date(from))
  dbGetQuery(
    con, 
    glue::glue(
      "SELECT *
      FROM stock_data
      WHERE ticker = {ticker}
      and date >= {from};"
    )
  )
}

#* Protect against an invalid ticker
#* @filter checkTicker
function(req, res) {
  if (!is.null(req$args$ticker) && !req$args$ticker %in% valid_tickers) {
    res$status <- 400
    return(
      list(
        error = paste(
          "Invalid ticker. Please use one of",
          paste("'", valid_tickers, "'",
                sep = "", collapse = ", ")
        )
        )
      )
  } else {
    plumber::forward()
  }
}

#* @get /price
#* @param ticker:character ticker symbol (MSFT; AMZN; AAPL; FB; GOOG)
#* @response 200 Returns price for ticker
#* @response 400 Bad ticker
#* @response 500 Bad ticker
#* @response default Returns price for ticker
price <- function(ticker = "AMZN") {
  get_price_data(ticker = ticker, from = "2010-01-01", con = con)
}

#* @get /volatility
#* @param ticker:character ticker symbol (MSFT: AMZN; AAPL; FB; GOOG)
#* @response 200 Returns volatility for ticker
#* @response 400 Bad ticker
#* @response 500 Bad ticker
#* @response default Returns volatility for ticker
volatility <- function(ticker = "AMZN"){
  price <- get_price_data(ticker, from = "2010-01-01", con = con) %>% 
    select(date, adjusted) %>% 
    mutate(returns = (log(adjusted) - log(lag(adjusted)))) %>%
    na.omit() %>% 
    summarize(volatility = var(returns))
  
  price$volatility
}
