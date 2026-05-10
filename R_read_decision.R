## For reading decisions in R, not part of shiny app
library(DBI)
library(RSQLite)

con <- dbConnect(SQLite(), "decisions.sqlite")

decisions <- dbReadTable(con, "decisions")

dbDisconnect(con)
