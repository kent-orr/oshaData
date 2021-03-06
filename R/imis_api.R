

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
#' @param start_date "yyyy-mm-dd" start date to limit results
#' @param end_date "yyyy-mm-dd" end date to limit results. Defaults to last 365 days
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

  response <-
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

  pool <- curl::new_pool()

  inspection_list <- list()

  success <- function(res){
    # cat("Request done! Status:", res$status, "\n")
    inspection_list <<- c(inspection_list, list(
      rvest::html_table(xml2::read_html(htmltools::HTML(trimws(
        rawToChar(res$content)
      ))), fill = TRUE)[[3]][1][c(4, 7, 8), ]
    ))
  }

  failure <- function(msg){
    cat("Oh noes! Request failed!", msg, "\n")
  }


  lapply(seq_along(response$i_url), function(x)
    curl::curl_fetch_multi(response$i_url[x],
                           done = success,
                           fail = failure,
                           pool = pool,
    ))

  curl::multi_run(pool = pool)

  inspection_df <-
    lapply(inspection_list, function(x)
      setNames(
        as.data.frame.list(x),
        c("establishment_name",  "naics", "mailing_address")
      ))

  inspection_df <- do.call(dplyr::bind_rows, inspection_df)

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

  pool <- curl::new_pool()

  citation_list <- list()

  success <- function(res){
    # cat("Request done! Status:", res$status, "\n")
    citation_list <<- c(citation_list, list(
      rvest::html_text(
        rvest::html_node(xml2::read_html(htmltools::HTML(trimws(
          rawToChar(res$content))
        )), xpath =  '//*[@id="maincontain"]/div/div[3]/text()')
      )
    )
    )
  }

  failure <- function(msg){
    cat("Oh noes! Request failed!", msg, "\n")
  }


  lapply(seq_along(response$c_url), function(x)
    curl::curl_fetch_multi(response$c_url[x],
                           done = success,
                           fail = failure,
                           pool = pool,
    ))

  curl::multi_run(pool = pool)

  return_df$description <- as.character(citation_list)

  return_df %>%
    mutate(naics = gsub("NAICS: ", "", naics),
           naics_code = str_extract(naics, "^\\d+"),
           naics_description = str_extract(naics, "(?<=/)\\D+")) %>%
    mutate(mailing_address = gsub("Mailing: ", "", mailing_address)) %>%
    separate(mailing_address, into = c("addr_street", "addr_city", "addr_state"), sep = ", ") %>%
    separate(addr_state, into = c('addr_state', 'addr_zip'), sep = " ") %>%
    separate(description, into = c('violation_code', 'violation_desc'), sep = ": |:")
}
