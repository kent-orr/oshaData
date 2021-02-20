

.onAttach <- function(libname, pkgname) {
  packageStartupMessage(
    "NOTE TO USERS
The source of the information in the IMIS is the local federal or state office in the geographical area where the activity occurred. Information is entered as events occur in the course of agency activities.
The data should be verified by reference to the case file and confirmed by the appropriate federal or state office."
  )
}

#' Search of the OSHA IMIS system for internal tracking of citations & inspections
#'
#' @param std_query the search query
#' @param sic unsure
#' @param office seems to be a regional OSHA office that the observation was filed in
#' @param p_logger unsure
#' @param p_start pagination start row
#' @param p_finish pagination finish row
#' @param p_show how many results to show per page
#' @param start_date "yyyymmdd" start date to limit results
#' @param end_date "yyyymmdd" end date to limit results. Defaults to last 365 days
#' @param category unsure
#' @param InspNr unsure
#'
#' @return returns a dataframe with date ,location, and details of citations and inspections.
#' @export
#'
osha_search = function(std_query,
                       sic = "",
                       office = "All",
                       p_logger = 1,
                       p_start = 0,
                       p_finish = 0,
                       p_show = 50,
                       start_date = Sys.Date() - 365,
                       end_date = Sys.Date(),
                       category = "",
                       InspNr = "") {

  start_month = stringr::str_pad(lubridate::month(start_date), 2, "left", "0")
  start_day = stringr::str_pad(lubridate::mday(start_date), 2, "left", "0")
  start_year = stringr::str_pad(lubridate::year(start_date), 2, "left", "0")

  end_month = stringr::str_pad(lubridate::month(end_date), 2, "left", "0")
  end_day = stringr::str_pad(lubridate::mday(end_date), 2, "left", "0")
  end_year = stringr::str_pad(lubridate::year(end_date), 2, "left", "0")

  response <-
    httr::GET(
      "https://www.osha.gov/pls/imis/GeneralSearch.search",
      query = list(
        stdquery = std_query,
        p_logger = p_logger,
        p_start = p_start,
        p_finish = p_finish,
        p_show = p_show,
        p_direction = "Next",
        p_sort = "",
        sic = sic,
        Office = office,
        startmonth = start_month,
        startday = start_day,
        startyear = start_year,
        endmonth = end_month,
        endday = end_day,
        endyear = end_year,
        category = category,
        InspNr = InspNr
      )
    )



  response_func <- function() {
    xml2::read_html(httr::content(response, "text")) %>%
    rvest::html_node(xpath = '//*[@id="maincontain"]/div/div[3]/table') %>%
    rvest::html_table()
  }

  tryCatch(response_func(),
           error = function(c) "No Results Found. Try another query or adjust date params?",
           warning = function(c) "Warning: Do us all a favor open a Github issue about this warning.",
           message = function(c) "message"
  )

  names(response) <-
    stringr::str_to_lower(gsub(" ", "_", names(response)))

  # ------------------------------------------------------- investigations -----

  i_url <- function(x) {
    paste0("https://www.osha.gov/pls/imis/establishment.inspection_detail?id=",
           x)
  }

  response$i_url <- i_url(response$inspection)

  inspection_list <- lapply(response$i_url, curl::curl_fetch_memory)

  site_text <-
    lapply(inspection_list, function(x)
      rawToChar(x$content))

  site_tables <-
    lapply(site_text, function(x)
      rvest::html_table(xml2::read_html(htmltools::HTML(trimws(
        x
      ))), fill = TRUE)[[3]][1][c(4, 7, 8), ])

  inspection_df <-
    lapply(site_tables, function(x)
      setNames(
        as.data.frame.list(x),
        c("establishment_name",  "naics", "mailing_address")
      ))

  inspection_df <- do.call(bind_rows, inspection_df)

  return_df <-
    cbind(response, inspection_df[which(names(inspection_df) != 'establishment_name')])

  # ------------------------------------------------------------ citations -----

  c_url <- function(x) {
    paste0(
      'https://www.osha.gov/pls/imis/generalsearch.citation_detail?id=',
      response$inspection[x],
      "&cit_id=",
      response$citation[x]
    )
  }

  response$c_url <-
    paste0(
      'https://www.osha.gov/pls/imis/generalsearch.citation_detail?id=',
      response$inspection,
      "&cit_id=",
      response$citation
    )

  citation_list <- lapply(response$c_url, curl::curl_fetch_memory)

  site_text <-
    lapply(citation_list, function(x)
      rawToChar(x$content))

  site_tables <-
    lapply(site_text, function(x)
      rvest::html_text(
        rvest::html_node(xml2::read_html(htmltools::HTML(trimws(
          x
        ))), xpath =  '//*[@id="maincontain"]/div/div[3]/text()')
      ))

  return_df$description <- as.character(site_tables)

  return_df
}
