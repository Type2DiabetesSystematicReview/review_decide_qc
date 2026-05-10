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
