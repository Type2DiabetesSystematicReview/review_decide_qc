library(shiny)
library(DBI)
library(RSQLite)

items <- read.csv("items.csv")

choices <- read.csv(
  "choices.csv",
  stringsAsFactors = FALSE,
  na.strings = NULL
)

choices <- choices[choices$field != "", ]

reviewers <- read.csv(
  "reviewer_list.csv",
  stringsAsFactors = FALSE
)

db_file <- "decisions.sqlite"

setup_db <- function(con) {
  dbExecute(con, "
  CREATE TABLE IF NOT EXISTS decisions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    sponsor TEXT,
    trial TEXT,
    reviewer TEXT,
    time TEXT
  )
  ")

  existing <- dbListFields(con, "decisions")

  for (f in unique(choices$field)) {
    if (!f %in% existing) {
      sql <- paste0(
        "ALTER TABLE decisions ADD COLUMN ",
        dbQuoteIdentifier(con, f),
        " TEXT"
      )

      dbExecute(con, sql)
    }
  }
}

prev_rows <- function(con, input) {
  d <- dbGetQuery(
    con,
    "SELECT * FROM decisions
     WHERE sponsor = ? AND trial = ?
     ORDER BY id",
    params = list(input$sponsor, input$trial)
  )

  if (nrow(d) == 0) return(NULL)

  d
}

save_decision <- function(con, row) {
  dbWriteTable(
    con,
    "decisions",
    row,
    append = TRUE,
    row.names = FALSE
  )
}

last_vals <- function(con, input) {
  fs <- unique(choices$field)

  ans <- vector("list", length(fs))
  names(ans) <- fs

  d <- prev_rows(con, input)

  if (is.null(d)) return(ans)

  d <- d[nrow(d), ]

  for (f in fs) {
    if (f %in% names(d)) {
      ans[[f]] <- as.character(d[[f]][1])
    }
  }

  ans
}

inp <- function(f, selected = NULL) {
  z <- choices[choices$field == f, ]

  lab <- z$label[1]
  typ <- z$type[1]
  ch <- z$choice
  ch <- ch[!is.na(ch) & ch != ""]

  if (is.null(selected) || is.na(selected)) {
    selected <- if (length(ch) > 0) ch[1] else ""
  }

  if (typ == "text") {
    textAreaInput(
      f,
      lab,
      value = "",
      placeholder = selected,
      rows = 3
    )
  } else if (typ == "radio") {
    radioButtons(f, lab, ch, selected = selected)
  } else {
    selectInput(f, lab, ch, selected = selected)
  }
}

vals <- function(input) {
  fs <- unique(choices$field)
  x <- as.data.frame(as.list(sapply(fs, function(f) input[[f]])))
  names(x) <- fs
  x
}

ui <- fluidPage(
  titlePanel("Report review"),

  sidebarLayout(
    sidebarPanel(
      selectInput(
        "reviewer",
        "Reviewer",
        reviewers$reviewer
      ),

      selectInput(
        "sponsor",
        "Sponsor",
        unique(items$sponsor)
      ),

      uiOutput("trial_ui"),

      hr(),

      strong("Previous reviews"),
      verbatimTextOutput("review_summary"),

      hr(),

      uiOutput("form"),

      actionButton("save", "Save"),
      actionButton("next", "Next")
    ),

    mainPanel(
      h3(textOutput("title")),
      uiOutput("report"),
      hr(),
      h4("Previous decisions"),
      tableOutput("prev")
    )
  )
)

server <- function(input, output, session) {

  con <- dbConnect(SQLite(), db_file)
  dbExecute(con, "PRAGMA busy_timeout = 10000")
  setup_db(con)

  session$onSessionEnded(function() {
    dbDisconnect(con)
  })

  rows <- reactive({
    items[items$sponsor == input$sponsor, ]
  })

  output$trial_ui <- renderUI({
    selectInput("trial", "Trial", rows()$trial)
  })

  output$form <- renderUI({
    old <- last_vals(con, input)

    lapply(unique(choices$field), function(f) {
      inp(f, old[[f]])
    })
  })

  output$title <- renderText({
    paste(input$sponsor, input$trial)
  })

  output$report <- renderUI({
    tags$iframe(
      src = paste0("reports/", input$trial, ".html"),
      width = "100%",
      height = "800px"
    )
  })

  output$prev <- renderTable({
    prev_rows(con, input)
  })

  output$review_summary <- renderText({
    d <- prev_rows(con, input)

    if (is.null(d)) {
      return("No previous reviews")
    }

    last <- d[nrow(d), ]

    paste0(
      "Number of previous reviews: ", nrow(d),
      "\n",
      "Last reviewer: ", last$reviewer
    )
  })

  observeEvent(input$save, {
    row <- cbind(
      data.frame(
        sponsor = input$sponsor,
        trial = input$trial,
        reviewer = input$reviewer,
        time = as.character(Sys.time()),
        stringsAsFactors = FALSE
      ),
      vals(input)
    )

    save_decision(con, row)

    showNotification("Saved")
  })

  observeEvent(input$next, {
    x <- rows()$trial
    i <- match(input$trial, x)

    if (!is.na(i) && i < length(x)) {
      updateSelectInput(session, "trial", selected = x[i + 1])
    } else {
      showNotification("No more trials for this sponsor", type = "message")
    }
  })
}

shinyApp(ui, server)
