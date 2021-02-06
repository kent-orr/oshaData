library(dplyr)

.onAttach <- function(libname, pkgname) {
  packageStartupMessage("NOTE TO USERS

The source of the information in the IMIS is the local federal or state office in the geographical area where the activity occurred. Information is entered as events occur in the course of agency activities. Until cases are closed, IMIS entries concerning specific OSHA inspections are subject to continuing correction and updating, particularly with regard to citation items, which are subject to modification by amended citations, settlement agreements, or as a result of contest proceedings. THE USER SHOULD ALSO BE AWARE THAT DIFFERENT COMPANIES MAY HAVE SIMILAR NAMES AND CLOSE ATTENTION TO THE ADDRESS MAY BE NECESSARY TO AVOID MISINTERPRETATION.

The data should be verified by reference to the case file and confirmed by the appropriate federal or state office.")
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
#' @param start_month start of query month in "mm" format
#' @param start_day start of query day in "dd" format
#' @param start_year start of query year in "yyyy" format
#' @param end_month end of query month in "mm" format
#' @param end_day end of query day in "dd" format
#' @param end_year end of query year in "yyyy" format
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
                       start_month = stringr::str_pad(lubridate::month(Sys.Date() -
                                                                90), 2, "left", "0"),
                       start_day = stringr::str_pad(lubridate::mday(Sys.Date() -
                                                             90), 2, "left", "0"),
                       start_year = stringr::str_pad(lubridate::year(Sys.Date() -
                                                              90), 2, "left", "0"),
                       end_month = stringr::str_pad(lubridate::month(Sys.Date()), 2, "left", "0"),
                       end_day = stringr::str_pad(lubridate::mday(Sys.Date()), 2, "left", "0"),
                       end_year = stringr::str_pad(lubridate::year(Sys.Date()), 2, "left", "0"),
                       category = "",
                       InspNr = "") {
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

  response <-
    xml2::read_html(httr::content(response, "text")) %>%
    rvest::html_node(xpath = '//*[@id="maincontain"]/div/div[3]/table') %>%
    rvest::html_table()

  names(response) <- stringr::str_to_lower(gsub(" ", "_", names(response)))

  i_url <- function(x) {
    paste0("https://www.osha.gov/pls/imis/establishment.inspection_detail?id=",
           x)
  }

  inspection_list <- lapply(response$inspection, function(x) rvest::html_table(xml2::read_html(httr::content(httr::GET(i_url(x)), "text")),  fill = T))

  inspection_df <- lapply(inspection_list, function(x) as.data.frame.list(x[[3]][1][c(4,5,7,8),]))

  inspection_df <- lapply(inspection_df, function(x) setNames(x, c("establishment_name", "establishment_address", "naics", "mailing_address")))

  inspection_df <- do.call(bind_rows, inspection_df)

  inspection_df$mailing_address <- gsub("Mailing: ", "", inspection_df$mailing_address)

  return_df <- cbind(response, inspection_df[which(names(inspection_df) != 'establishment_name')])


  c_url <- function(x) {
    paste0('https://www.osha.gov/pls/imis/generalsearch.citation_detail?id=', response$inspection[x], "&cit_id=",
           response$citation[x]
           )
  }

  c_url_list <- lapply(seq_along(response[,1]), c_url)

  c_list <-
  lapply(c_url_list, function(x) rvest::html_text(
    rvest::html_node(
      xml2::read_html(
        httr::content(
          httr::GET(x), "text")
        ), xpath =  '//*[@id="maincontain"]/div/div[3]/text()'
      )
    )
  )

  return_df$description <- as.character(c_list)

  return_df$street <- stringr::str_extract(return_df$establishment_address, ".+?(?=,)")
  return_df$state <- trimws(stringr::str_extract(return_df$establishment_address, "(?<=,) \\D{2}"))
  return_df$zip <- trimws(stringr::str_extract(return_df$establishment_address, "(?<=, \\D{2}).+"))

  return_df
}
