## ----include = FALSE----------------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>",
  eval = requireNamespace("RSQLite", quietly = TRUE)
)

## ----eval = FALSE-------------------------------------------------------------
# options(cohortBuilder.db.step_strategy = "lazy")

## ----setup, message = FALSE---------------------------------------------------
library(magrittr)
library(cohortBuilder)
library(cohortBuilder.db)

remote_names <- function(data_object) {
  vapply(
    data_object,
    function(x) {
      name <- dbplyr::remote_name(x)
      if (is.null(name)) "<lazy>" else as.character(name)
    },
    character(1)
  )
}

librarian <- cohortBuilder::librarian
conn <- DBI::dbConnect(RSQLite::SQLite(), dbname = ":memory:")
DBI::dbExecute(conn, paste0("ATTACH '", tempfile(), "' AS cb"))
for (table in c("books", "borrowers", "issues")) {
  dplyr::copy_to(
    conn, librarian[[table]], dbplyr::in_schema("cb", table),
    temporary = FALSE, overwrite = TRUE
  )
}

db_source <- set_source(
  dbtables(tables = c("books", "borrowers", "issues"), schema = "cb", connection = conn),
  binding_keys = bind_keys(
    bind_key(update = data_key("issues", "isbn"), data_key("books", "isbn"))
  )
)

new_cohort <- function() {
  cohort(
    db_source,
    step(
      filter("discrete", id = "author", variable = "author", dataset = "books",
             value = "Dan Brown")
    ),
    step(
      filter("discrete", id = "program", variable = "program", dataset = "borrowers",
             value = "premium")
    )
  )
}

## -----------------------------------------------------------------------------
options(cohortBuilder.db.step_strategy = "lazy")

coh <- new_cohort()
run(coh)

remote_names(coh$get_data(2, state = "post", collect = FALSE))
coh$get_data(2, state = "post", collect = FALSE)$issues %>%
  dplyr::show_query()

## -----------------------------------------------------------------------------
options(cohortBuilder.db.step_strategy = "materialize")

coh <- new_cohort()
run(coh)

dbplyr::remote_name(coh$get_data(1, state = "post", collect = FALSE)$books)
dbplyr::remote_name(coh$get_data(2, state = "post", collect = FALSE)$books)

## -----------------------------------------------------------------------------
coh$get_data(2, state = "post", collect = FALSE)$books %>%
  dplyr::show_query()

## -----------------------------------------------------------------------------
options(cohortBuilder.db.step_strategy = "materialize_selective")

coh <- new_cohort()
run(coh)

remote_names(coh$get_data(1, state = "post", collect = FALSE))
remote_names(coh$get_data(2, state = "post", collect = FALSE))

## ----eval = FALSE-------------------------------------------------------------
# # Redshift-friendly configuration
# options(cohortBuilder.db.step_strategy = "materialize_selective")

## -----------------------------------------------------------------------------
options(cohortBuilder.db.step_strategy = "lazy")
coh <- new_cohort()
run(coh)

options(cohortBuilder.db.step_strategy = "materialize")
run(coh)
dbplyr::remote_name(coh$get_data(2, state = "post", collect = FALSE)$books)

## ----eval = FALSE-------------------------------------------------------------
# withr::with_options(
#   list(cohortBuilder.db.step_strategy = "materialize"),
#   run(coh)
# )

## ----include = FALSE----------------------------------------------------------
options(cohortBuilder.db.step_strategy = NULL)
DBI::dbDisconnect(conn)

