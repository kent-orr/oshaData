# library(curl)
#
#
# anus <- lapply(response$url, curl_fetch_memory)
# site_text <- lapply(anus, function(x) rawToChar(x$content))
# site_tables <- lapply(site_text, function(x) rvest::html_table(xml2::read_html(htmltools::HTML(trimws(x))), fill = TRUE)[[3]][1][c(4,7,8),])
#
# inspection_df <- lapply(site_tables, function(x) setNames(as.data.frame.list(x), c("establishment_name",  "naics", "mailing_address")))
#
# inspection_df <- do.call(bind_rows, inspection_df)
#
#
# play_site <- site_text[[1]]
#
# library(xml2)
# library(rvest)
#
#
# xml2::read_html(htmltools::htmlEscape(play_site))
#
# anus <- rvest::html_table(xml2::read_html(htmltools::HTML(trimws(play_site))), fill = TRUE)
#
# as.data.frame.list(anus[[3]][1][c(4,7,8),])

