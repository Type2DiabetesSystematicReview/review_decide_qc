# app.R
#
# Minimal Shiny app for reviewing pre-generated trial-level HTML reports
# and saving structured review decisions to a SQLite database.
#
# Expected folder structure:
#
# review_app/
#   app.R
#   items.csv
#   choices.csv
#   reviewer_list.csv
#   decisions.sqlite       # created automatically if missing
#   www/
#     reports/
#       NCT12312412.html
#       NCT234293023.html
#       ...
#
# Files under www/ are served by Shiny directly. Therefore a report stored at:
#
#   www/reports/NCT12312412.html
#
# is displayed in the app using:
#
#   reports/NCT12312412.html


# ---- Packages ----

library(shiny)
library(DBI)
library(RSQLite)


# ---- Input files ----

# items.csv defines the trials available for review.
# Required columns:
#   sponsor
#   trial
#
# Each value in trial must correspond to an HTML file in www/reports/.
# For example, trial NCT12312412 requires:
#   www/reports/NCT12312412.html
items <- read.csv("items.csv")


# choices.csv defines the review form.
# Required columns:
#   field
#   label
#   type
#   choice
#
# Supported values for type:
#   select
#   radio
#   text
#
# The field column becomes a column name in the SQLite decisions table.
choices <- read.csv(
  "choices.csv",
  stringsAsFactors = FALSE,
  na.strings = NULL
)

# Drop any rows where the field is blank.
# This is useful if choices.csv contains blank spacer rows or accidental
# empty lines.
choices <- choices[choices$field != "", ]


# reviewer_list.csv defines the reviewer dropdown.
# Required column:
#   reviewer
reviewers <- read.csv(
  "reviewer_list.csv",
  stringsAsFactors = FALSE
)


# ---- App settings ----

# SQLite database file used to store review decisions.
#
# If this file does not exist, it is created automatically when the app starts.
db_file <- "decisions.sqlite"


# ---- Database helper functions ----

# Create the decisions table if needed, and add columns for any fields
# listed in choices.csv.
#
# The table always contains these base columns:
#   id
#   sponsor
#   trial
#   reviewer
#   time
#
# Additional columns are added from unique values of choices$field.
#
# This means the review form can be changed by editing choices.csv.
# Adding a new field to choices.csv adds a new database column the next
# time the app starts.
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

  # Find existing columns in the decisions table.
  existing <- dbListFields(con, "decisions")

  # Add one text column for each review field if it is not already present.
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


# Return all previous review rows for the currently selected sponsor/trial.
#
# Returns NULL if there are no previous reviews.
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


# Save a single review decision row to the decisions table.
#
# Each save appends a new row.
# Existing rows are not overwritten.
save_decision <- function(con, row) {
  dbWriteTable(
    con,
    "decisions",
    row,
    append = TRUE,
    row.names = FALSE
  )
}


# Get the most recent previous values for the currently selected sponsor/trial.
#
# These values are used to pre-populate select/radio inputs and to provide
# placeholder text for text fields.
#
# If there are no previous reviews, returns a named list with NULL values.
last_vals <- function(con, input) {
  fs <- unique(choices$field)

  ans <- vector("list", length(fs))
  names(ans) <- fs

  d <- prev_rows(con, input)

  if (is.null(d)) return(ans)

  # Keep only the most recent row.
  d <- d[nrow(d), ]

  for (f in fs) {
    if (f %in% names(d)) {
      ans[[f]] <- as.character(d[[f]][1])
    }
  }

  ans
}


# ---- Review form helper functions ----

# Build one Shiny input from choices.csv.
#
# f is a field name from choices$field.
# selected is the most recent previous value, if available.
#
# For select and radio fields:
#   the previous value is selected automatically.
#
# For text fields:
#   the previous value is shown as grey placeholder text;
#   the actual input value is kept blank.
#
# Keeping text fields blank helps avoid accidentally re-saving old notes
# as if they were newly entered.
inp <- function(f, selected = NULL) {
  z <- choices[choices$field == f, ]

  lab <- z$label[1]
  typ <- z$type[1]
  ch <- z$choice
  ch <- ch[!is.na(ch) & ch != ""]

  # If there is no previous value, select the first available choice
  # for select/radio fields. For text fields this becomes an empty string.
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


# Extract the current values of all review-form fields from input.
#
# The returned data frame has one row and one column per field in choices.csv.
# This is combined with sponsor/trial/reviewer/time before saving.
vals <- function(input) {
  fs <- unique(choices$field)
  x <- as.data.frame(as.list(sapply(fs, function(f) input[[f]])))
  names(x) <- fs
  x
}


# ---- User interface ----

ui <- fluidPage(
  titlePanel("Report review"),

  sidebarLayout(
    sidebarPanel(
      # Reviewer dropdown.
      selectInput(
        "reviewer",
        "Reviewer",
        reviewers$reviewer
      ),

      # Sponsor dropdown.
      # The trial dropdown is updated based on this choice.
      selectInput(
        "sponsor",
        "Sponsor",
        unique(items$sponsor)
      ),

      # Trial dropdown, generated dynamically from selected sponsor.
      uiOutput("trial_ui"),

      hr(),

      # Compact summary of previous reviews for selected trial.
      strong("Previous reviews"),
      verbatimTextOutput("prev_text"),

      hr(),

      # Review form, generated dynamically from choices.csv.
      uiOutput("form"),

      # Save appends a new row to SQLite.
      actionButton("save", "Save"),

      # Next moves to the next trial within the selected sponsor.
      actionButton("nxt", "Next")
    ),

    mainPanel(
      # Sponsor and trial title.
      h3(textOutput("title")),

      # Embedded HTML report.
      uiOutput("report"),

      hr(),

      # Full previous-decision table for selected trial.
      h4("Previous decisions"),
      tableOutput("prev")
    )
  )
)


# ---- Server logic ----

server <- function(input, output, session) {

  # Open one SQLite connection per Shiny session.
  con <- dbConnect(SQLite(), db_file)

  # Wait up to 10 seconds if the SQLite database is temporarily locked,
  # for example because another reviewer is saving at the same time.
  dbExecute(con, "PRAGMA busy_timeout = 10000")

  # Create the table and add any missing review-field columns.
  setup_db(con)

  # This reactive counter is incremented after a save.
  #
  # It forces previous-review outputs to refresh immediately after pressing
  # Save, without requiring the reviewer to leave and return to the trial.
  review_version <- reactiveVal(0)

  # Close the database connection when the user's Shiny session ends.
  session$onSessionEnded(function() {
    dbDisconnect(con)
  })


  # Trials available under the selected sponsor.
  rows <- reactive({
    items[items$sponsor == input$sponsor, ]
  })


  # Previous reviews for the selected sponsor/trial.
  #
  # The call to review_version() creates a reactive dependency.
  # The value itself is not used.
  #
  # When review_version is incremented after saving, this reactive expression
  # re-runs and the previous-review outputs update immediately.
  previous_reviews <- reactive({
    review_version()
    prev_rows(con, input)
  })


  # Trial dropdown depends on selected sponsor.
  output$trial_ui <- renderUI({
    selectInput("trial", "Trial", rows()$trial)
  })


  # Dynamic review form built from choices.csv.
  #
  # The form uses the most recent previous values as defaults for select/radio
  # fields and placeholders for text fields.
  #
  # This output is intentionally not dependent on review_version(), because
  # re-rendering the form immediately after saving could reset inputs in a
  # surprising way. The previous-review summary and table are refreshed instead.
  output$form <- renderUI({
    old <- last_vals(con, input)

    lapply(unique(choices$field), function(f) {
      inp(f, old[[f]])
    })
  })


  # Page title for selected sponsor/trial.
  output$title <- renderText({
    paste(input$sponsor, input$trial)
  })


  # Display the HTML report in an iframe.
  #
  # Reports are expected to be in:
  #   www/reports/
  #
  # Shiny serves www/ directly, so the iframe source starts with:
  #   reports/
  output$report <- renderUI({
    tags$iframe(
      src = paste0("reports/", input$trial, ".html"),
      width = "100%",
      height = "800px"
    )
  })


  # Full table of previous decisions for the selected sponsor/trial.
  #
  # This refreshes immediately after Save because it depends on
  # previous_reviews().
  output$prev <- renderTable({
    previous_reviews()
  })


  # Compact previous-review summary shown in the sidebar.
  #
  # Examples:
  #   First review
  #   1 review; last: David McAllister
  #   3 reviews; last: Jane Smith
  #
  # This refreshes immediately after Save because it depends on
  # previous_reviews().
  output$prev_text <- renderText({
    d <- previous_reviews()

    if (is.null(d)) {
      return("First review")
    }

    review_count <- nrow(d)
    last_reviewer <- d$reviewer[[review_count]]

    paste0(
      review_count,
      " review",
      ifelse(review_count == 1, "", "s"),
      "; last: ",
      last_reviewer
    )
  })


  # Save button.
  #
  # Each click appends a new row to SQLite. Existing decisions are not
  # overwritten.
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

    # Trigger previous-review summary and table to refresh immediately.
    review_version(review_version() + 1)

    showNotification("Saved")
  })


  # Next button.
  #
  # Moves to the next trial within the currently selected sponsor.
  # If already at the final trial for that sponsor, show a message.
  observeEvent(input$nxt, {
    x <- rows()$trial
    i <- match(input$trial, x)

    if (!is.na(i) && i < length(x)) {
      updateSelectInput(session, "trial", selected = x[i + 1])
    } else {
      showNotification("No more trials for this sponsor", type = "message")
    }
  })
}


# ---- Run app ----

shinyApp(ui, server)
