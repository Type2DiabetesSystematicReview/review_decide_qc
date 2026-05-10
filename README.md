# Trial report review app: team documentation

## 1. Purpose

This Shiny app supports structured review of pre-generated trial-level HTML reports.

It is intended for small review teams working with clinical trial summaries, for example when checking whether trial-level summaries of medical history, drug history, and laboratory abnormalities are sufficiently reliable for downstream analysis.

For each trial, the app lets a reviewer:

- open the corresponding HTML report;
- record structured review decisions;
- record free-text notes;
- see whether the trial has already been reviewed;
- see the most recent previous review values;
- save a new review decision without overwriting previous reviews.

The app is intended for workflows where more than one reviewer may review the same trial.

The first use case is review of:

- medical history counts;
- drug history counts;
- laboratory abnormality counts.

The same app can be reused for later reviews by changing the input files, especially `items.csv` and `choices.csv`.

---

## 2. What the app assumes

The app assumes that:

- there is one HTML report per trial;
- each report is already generated before review begins;
- reports are saved in `www/reports/`;
- each report filename is the trial ID followed by `.html`;
- trials are grouped by sponsor;
- the review form is defined in `choices.csv`;
- reviewer names are defined in `reviewer_list.csv`;
- review decisions are saved in a SQLite database called `decisions.sqlite`.

Example report filename:

```text
www/reports/NCT12312412.html
```

The corresponding trial ID in `items.csv` must be:

```text
NCT12312412
```

Inside the Shiny app, files under `www/` are served directly. Therefore the app refers to that report as:

```text
reports/NCT12312412.html
```

---

## 3. Folder structure

The app folder should look like this:

```text
review_app/
  app.R
  items.csv
  choices.csv
  reviewer_list.csv
  decisions.sqlite       # created automatically if it does not exist
  www/
    reports/
      NCT12312412.html
      NCT234293023.html
      NCT4234325.html
```

`decisions.sqlite` does not need to exist before the first run. The app creates it automatically if it is missing.

---

## 4. Main files

### 4.1 `app.R`

This is the Shiny app itself.

Most reviewers should not need to edit `app.R`.

The app:

1. reads `items.csv`, `choices.csv`, and `reviewer_list.csv`;
2. opens a connection to `decisions.sqlite`;
3. creates the decisions table if needed;
4. adds database columns for any fields listed in `choices.csv`;
5. displays the relevant HTML report;
6. displays the review form;
7. saves each completed review as a new row in SQLite.

### 4.2 `items.csv`

This file defines which reports are available for review.

Required columns:

```text
sponsor
trial
```

Example:

```csv
sponsor,trial
takeda,NCT12312412
takeda,NCT01242445
takeda,NCT05555555
gsk,NCT234293023
gsk,NCT06666666
bi,NCT4234325
```

Each `trial` value must match an HTML file in `www/reports/`.

For example, this row:

```csv
takeda,NCT12312412
```

requires this file:

```text
www/reports/NCT12312412.html
```

### 4.3 `reviewer_list.csv`

This file defines the reviewer names shown in the reviewer dropdown.

Required column:

```text
reviewer
```

Example:

```csv
reviewer
David McAllister
Jane Smith
Alice Brown
```

The names in this file appear in the app under the **Reviewer** dropdown.

### 4.4 `choices.csv`

This file defines the review form.

The app builds the form automatically from this file.

Required columns:

```text
field
label
type
choice
```

Supported values for `type` are:

```text
select
radio
text
```

Example:

```csv
field,label,type,choice
mh_quality,Medical history count quality,select,good
mh_quality,Medical history count quality,select,poor
mh_quality,Medical history count quality,select,absent
mh_quality,Medical history count quality,select,unclear
dh_quality,Drug history count quality,select,good
dh_quality,Drug history count quality,select,poor
dh_quality,Drug history count quality,select,absent
dh_quality,Drug history count quality,select,unclear
lab_quality,Lab abnormality count quality,select,good
lab_quality,Lab abnormality count quality,select,poor
lab_quality,Lab abnormality count quality,select,absent
lab_quality,Lab abnormality count quality,select,unclear
consistency,Consistency across domains,select,consistent
consistency,Consistency across domains,select,partly consistent
consistency,Consistency across domains,select,discordant
consistency,Consistency across domains,select,unclear
decision,Overall decision,radio,include
decision,Overall decision,radio,exclude
decision,Overall decision,radio,unclear
reason,Main reason,select,
reason,Main reason,select,good quality
reason,Main reason,select,poor medical history data
reason,Main reason,select,poor drug history data
reason,Main reason,select,poor laboratory abnormality data
reason,Main reason,select,discordant signals
reason,Main reason,select,sparse counts
reason,Main reason,select,missing denominator
reason,Main reason,select,other
notes,Notes,text,
```

The `field` column becomes the variable name in the SQLite database.

For example:

```csv
mh_quality,Medical history count quality,select,good
```

creates a database column called:

```text
mh_quality
```

The `label` column controls what the reviewer sees in the app.

The `choice` column defines the available options for `select` and `radio` fields.

For text fields, leave `choice` blank:

```csv
notes,Notes,text,
```

---

## 5. How to run the app

1. Open the app folder in RStudio.
2. Open `app.R`.
3. Install required packages if needed:

```r
install.packages(c("shiny", "DBI", "RSQLite"))
```

4. Click **Run App** in RStudio, or run:

```r
shiny::runApp()
```

5. Select your reviewer name.
6. Select a sponsor.
7. Select a trial.
8. Review the HTML report.
9. Complete the review form.
10. Click **Save**.
11. Click **Next** to move to the next trial for that sponsor.

---

## 6. Reviewer workflow

For each trial, the reviewer should:

1. Check the trial report shown in the main panel.
2. Review the medical history count summaries.
3. Review the drug history count summaries.
4. Review the laboratory abnormality count summaries.
5. Decide whether the trial is suitable for downstream analysis.
6. Select the appropriate structured decisions.
7. Add notes if useful.
8. Click **Save**.

Each click on **Save** creates a new row in the database. It does not overwrite previous decisions.

This means a trial can have more than one review.

---

## 7. Previous reviews

When a reviewer selects a trial, the app checks whether there are previous reviews for the same sponsor and trial.
Saved decisions are available immediately. If a reviewer saves a decision, moves to another trial, and then returns to the original trial in the same Shiny session, the app will show the newly saved decision as a previous review. The app does not need to be restarted.

The sidebar shows:

- number of previous reviews;
- most recent reviewer.

The main panel shows the previous decision rows.

For dropdowns and radio buttons, the most recent previous value is selected automatically.

For text fields, the most recent previous text is shown as grey placeholder text rather than inserted into the field.

This is intentional. It prevents a reviewer from accidentally re-saving old notes as if they were newly entered.

---

## 8. SQLite output

The app saves decisions in:

```text
decisions.sqlite
```

The database contains a table called:

```text
decisions
```

The base columns are:

```text
id
sponsor
trial
reviewer
time
```

Additional columns are added automatically from `choices.csv`.

For example, if `choices.csv` contains these fields:

```text
mh_quality
dh_quality
lab_quality
consistency
decision
reason
notes
```

then the `decisions` table will also contain columns with those names.

Each saved review is appended as a new row.

---

## 9. Reading the SQLite database into R for post hoc analysis

Review decisions are saved in a SQLite database called:

```text
decisions.sqlite
```

The main table is called:

```text
decisions
```

Each time a reviewer clicks **Save**, the app appends a new row to this table. Existing rows are not overwritten.

This means the database may contain:

- more than one review per trial;
- more than one reviewer per trial;
- older and newer decisions for the same trial;
- repeated saves by the same reviewer.

For most post hoc analyses, it is important to decide whether to analyse:

1. all saved reviews;
2. only the most recent review per trial;
3. only the most recent review per reviewer per trial.

### 9.1 Load required packages

```r
install.packages(c("DBI", "RSQLite", "dplyr", "readr"))
```

```r
library(DBI)
library(RSQLite)
library(dplyr)
library(readr)
```

### 9.2 Connect to the database

```r
con <- dbConnect(
  SQLite(),
  "decisions.sqlite"
)
```

Check which tables are present:

```r
dbListTables(con)
```

Check the columns in the `decisions` table:

```r
dbListFields(con, "decisions")
```

### 9.3 Read all saved review decisions

```r
decisions <- dbReadTable(con, "decisions")
```

Inspect the data:

```r
glimpse(decisions)
```

```r
head(decisions)
```

When finished, disconnect from the database:

```r
dbDisconnect(con)
```

### 9.4 Recommended pattern: connect, read, disconnect

For routine analysis, use this pattern so that the database connection is not accidentally left open:

```r
con <- dbConnect(SQLite(), "decisions.sqlite")

decisions <- dbReadTable(con, "decisions")

dbDisconnect(con)
```

### 9.5 Convert the time variable

The app saves the review time as text. Convert it to a proper date-time variable before analysis:

```r
decisions <- decisions %>%
  mutate(
    time = as.POSIXct(time)
  )
```

### 9.6 Get the most recent review for each sponsor/trial

This is often the most useful analysis dataset if the final saved decision should be treated as the current decision.

```r
latest_by_trial <- decisions %>%
  arrange(sponsor, trial, id) %>%
  group_by(sponsor, trial) %>%
  slice_tail(n = 1) %>%
  ungroup()
```

Check the result:

```r
latest_by_trial %>%
  count(decision)
```

### 9.7 Get the most recent review by each reviewer for each sponsor/trial

Use this if two reviewers independently review the same trial and you want one row per reviewer per trial.

```r
latest_by_reviewer <- decisions %>%
  arrange(sponsor, trial, reviewer, id) %>%
  group_by(sponsor, trial, reviewer) %>%
  slice_tail(n = 1) %>%
  ungroup()
```

For example, count reviewer decisions:

```r
latest_by_reviewer %>%
  count(reviewer, decision)
```

### 9.8 Identify trials with no saved review

This requires comparing `items.csv` with the saved decisions.

```r
items <- read.csv(
  "items.csv",
  stringsAsFactors = FALSE
)

reviewed_trials <- decisions %>%
  distinct(sponsor, trial)

unreviewed_trials <- items %>%
  anti_join(
    reviewed_trials,
    by = c("sponsor", "trial")
  )
```

View unreviewed trials:

```r
unreviewed_trials
```

### 9.9 Count reviews per trial

This is useful for checking whether each trial has the expected number of reviews.

```r
reviews_per_trial <- decisions %>%
  count(sponsor, trial, name = "n_reviews") %>%
  arrange(sponsor, trial)
```

Trials with fewer than two reviews:

```r
reviews_per_trial %>%
  filter(n_reviews < 2)
```

Trials with more than two reviews:

```r
reviews_per_trial %>%
  filter(n_reviews > 2)
```

### 9.10 Summarise final decisions

Using the latest review per trial:

```r
latest_by_trial %>%
  count(decision)
```

By sponsor:

```r
latest_by_trial %>%
  count(sponsor, decision)
```

Reasons for exclusion:

```r
latest_by_trial %>%
  filter(decision == "exclude") %>%
  count(reason, sort = TRUE)
```

### 9.11 Export analysis datasets

Export all saved reviews:

```r
write_csv(
  decisions,
  "all_review_decisions.csv"
)
```

Export the most recent review per trial:

```r
write_csv(
  latest_by_trial,
  "latest_review_decision_by_trial.csv"
)
```

Export the most recent review per reviewer per trial:

```r
write_csv(
  latest_by_reviewer,
  "latest_review_decision_by_reviewer.csv"
)
```

### 9.12 Optional: read directly using SQL

Instead of reading the full table and filtering in R, you can query SQLite directly.

Read all saved decisions:

```r
con <- dbConnect(SQLite(), "decisions.sqlite")

decisions <- dbGetQuery(
  con,
  "SELECT * FROM decisions"
)

dbDisconnect(con)
```

Read only included trials:

```r
con <- dbConnect(SQLite(), "decisions.sqlite")

included <- dbGetQuery(
  con,
  "SELECT * FROM decisions WHERE decision = 'include'"
)

dbDisconnect(con)
```

Read the most recent decision for each sponsor/trial:

```r
con <- dbConnect(SQLite(), "decisions.sqlite")

latest <- dbGetQuery(
  con,
  "
  SELECT *
  FROM decisions
  WHERE id IN (
    SELECT MAX(id)
    FROM decisions
    GROUP BY sponsor, trial
  )
  "
)

dbDisconnect(con)
```

### 9.13 Suggested post hoc checks

After reading the data into R, check:

- how many reviews have been saved;
- how many unique trials have been reviewed;
- whether any trials have no review;
- whether any trials have fewer reviews than expected;
- whether reviewers disagree on inclusion/exclusion;
- whether exclusion reasons are being used consistently;
- whether notes contain information requiring adjudication.

Example checks:

```r
nrow(decisions)
```

```r
decisions %>%
  summarise(
    n_reviews = n(),
    n_trials = n_distinct(trial),
    n_sponsors = n_distinct(sponsor),
    n_reviewers = n_distinct(reviewer)
  )
```

Identify trials where reviewers may have reached different decisions:

```r
latest_by_reviewer %>%
  count(sponsor, trial, decision) %>%
  count(sponsor, trial, name = "n_distinct_decisions") %>%
  filter(n_distinct_decisions > 1)
```

---

## 10. Setting up a new review

To use the app for a new review, usually only three things need to change:

1. the HTML reports in `www/reports/`;
2. the list of reports in `items.csv`;
3. the review questions and choices in `choices.csv`.

### Step 1: Create the HTML reports

Create one HTML file per trial.

Each file must be named using the trial ID:

```text
NCT12312412.html
```

Save all reports in:

```text
www/reports/
```

### Step 2: Update `items.csv`

Add one row per trial.

Example:

```csv
sponsor,trial
takeda,NCT12312412
gsk,NCT234293023
bi,NCT4234325
```

Make sure every `trial` value has a matching HTML file.

### Step 3: Update `choices.csv`

Decide what review questions are needed.

For each question:

- choose a stable `field` name;
- write a clear reviewer-facing `label`;
- choose the input `type`;
- list the available `choice` values.

Use `select` for dropdowns, `radio` for short mutually exclusive choices, and `text` for notes.

### Step 4: Update `reviewer_list.csv`

Add or remove reviewer names as needed.

Example:

```csv
reviewer
David McAllister
Jane Smith
Alice Brown
```

### Step 5: Decide whether to start a new database

For a completely new review, it is usually best to start with a new `decisions.sqlite` file.

Options:

- rename the old database, for example `decisions_med_history_review.sqlite`;
- move it into an archive folder;
- delete `decisions.sqlite` if it is no longer needed.

When the app starts and `decisions.sqlite` is missing, it creates a new one.

---

## 11. Rules for editing `choices.csv`

The `field` column is important because it becomes the database column name.

Treat field names as permanent variable names.

Recommended practice:

| Change | Safe? | Effect |
|---|---:|---|
| Change a label | Yes | The app shows the new label; database column is unchanged. |
| Add a new field | Yes | A new database column is added next time the app starts. |
| Rename a field | Use caution | This creates a new database column; old data remains under the old field name. |
| Remove a field | Use caution | The field disappears from the app, but the old database column remains. |
| Reorder choices | Yes | Changes display order in the app. |
| Change choice wording | Use caution | New reviews may use different text from old reviews. |

For this reason, it is best to finalise `choices.csv` before review begins.

If the form changes substantially, consider starting a new database or adding a form version variable.

---

## 12. Multiple reviewers

The app is designed for a small number of concurrent users.

Each Shiny session opens its own SQLite connection. The app also sets a SQLite busy timeout, which helps when two people try to save at nearly the same time.

This is intended for small-team use, for example two reviewers using a shared Windows Server remote desktop environment.

Recommended practice:

- keep the app in a shared project folder;
- ask reviewers not to edit `app.R`, `items.csv`, or `choices.csv` while review is in progress;
- avoid moving or renaming report files during review;
- periodically back up `decisions.sqlite`;
- do not open and manually edit the SQLite database while reviewers are using the app.

---

## 13. Quality control checks before review starts

Before asking the team to begin reviewing, the person setting up the review should check:

- every trial in `items.csv` has a matching HTML file in `www/reports/`;
- every HTML file opens correctly in a browser;
- sponsor names are spelled consistently;
- reviewer names are correct;
- `choices.csv` contains the intended fields and choices;
- field names in `choices.csv` are short, stable, and do not contain spaces;
- the app starts successfully;
- a test decision can be saved;
- the saved decision can be read back from `decisions.sqlite`.

A useful R check for missing report files is:

```r
items <- read.csv("items.csv", stringsAsFactors = FALSE)

expected_files <- file.path("www", "reports", paste0(items$trial, ".html"))

missing_files <- expected_files[!file.exists(expected_files)]

missing_files
```

If `missing_files` is empty, every listed trial has a matching report.

---

## 14. Recommended review form for the first review

For the first review of medical history counts, drug history counts, and laboratory abnormality counts, a suitable `choices.csv` is:

```csv
field,label,type,choice
mh_quality,Medical history count quality,select,good
mh_quality,Medical history count quality,select,poor
mh_quality,Medical history count quality,select,absent
mh_quality,Medical history count quality,select,unclear
dh_quality,Drug history count quality,select,good
dh_quality,Drug history count quality,select,poor
dh_quality,Drug history count quality,select,absent
dh_quality,Drug history count quality,select,unclear
lab_quality,Lab abnormality count quality,select,good
lab_quality,Lab abnormality count quality,select,poor
lab_quality,Lab abnormality count quality,select,absent
lab_quality,Lab abnormality count quality,select,unclear
consistency,Consistency across domains,select,consistent
consistency,Consistency across domains,select,partly consistent
consistency,Consistency across domains,select,discordant
consistency,Consistency across domains,select,unclear
decision,Overall decision,radio,include
decision,Overall decision,radio,exclude
decision,Overall decision,radio,unclear
reason,Main reason,select,
reason,Main reason,select,good quality
reason,Main reason,select,poor medical history data
reason,Main reason,select,poor drug history data
reason,Main reason,select,poor laboratory abnormality data
reason,Main reason,select,discordant signals
reason,Main reason,select,sparse counts
reason,Main reason,select,missing denominator
reason,Main reason,select,other
notes,Notes,text,
```

---

## 15. Example minimal HTML report

Each trial report can be as simple or as detailed as needed.

Example file:

```text
www/reports/NCT12312412.html
```

Example contents:

```html
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>NCT12312412</title>
</head>
<body>
  <h1>NCT12312412</h1>

  <h2>Medical history counts</h2>
  <p>Insert medical history tables and plots here.</p>

  <h2>Drug history counts</h2>
  <p>Insert drug history tables and plots here.</p>

  <h2>Abnormal laboratory findings</h2>
  <p>Insert laboratory tables and plots here.</p>
</body>
</html>
```

---

## 16. Known limitations

This is a deliberately minimal app.

Known limitations include:

- no login or password protection;
- no formal audit trail beyond appending saved rows;
- no built-in adjudication workflow;
- no automatic assignment of trials to reviewers;
- no built-in check that every trial has been reviewed by two people;
- no form versioning;
- no protection against someone changing input CSV files during review;
- SQLite is suitable for small-team use, but not for large numbers of concurrent users.

For the intended use case of a small review team working in a shared project environment, these limitations are acceptable if the team follows the setup and backup guidance above.

---

## 17. Suggested future improvements

Possible future improvements include:

- add a `form_version` column;
- add a field for reviewer role, such as first reviewer, second reviewer, or adjudicator;
- add a dashboard showing review progress;
- add checks for missing report files at app startup;
- add export buttons for latest decisions;
- add a rule requiring two independent reviews before final inclusion;
- add adjudication fields for resolving disagreements;
- add password protection if deployed beyond a trusted local environment.

---

## 18. Quick setup checklist

Before review starts:

- [ ] Put all HTML reports in `www/reports/`.
- [ ] Confirm report filenames match trial IDs.
- [ ] Update `items.csv`.
- [ ] Update `choices.csv`.
- [ ] Update `reviewer_list.csv`.
- [ ] Start the app.
- [ ] Save a test review.
- [ ] Read the test review from `decisions.sqlite`.
- [ ] Delete or archive the test database before live review, if appropriate.
- [ ] Tell reviewers not to edit app files during review.
- [ ] Back up `decisions.sqlite` regularly during review.

---

## 19. Short instructions for reviewers

1. Open the app.
2. Select your name.
3. Select a sponsor.
4. Select a trial.
5. Review the report.
6. Complete the decision form.
7. Add notes where useful.
8. Click **Save**.
9. Click **Next** to continue with the next trial.

Do not edit `app.R`, `items.csv`, `choices.csv`, or the HTML report files while reviews are in progress.
