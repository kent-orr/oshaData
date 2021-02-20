# pool <- curl::new_pool()
#
# inspection_list <- list()
#
# success <- function(res){
#   # cat("Request done! Status:", res$status, "\n")
#   inspection_list <<- c(inspection_list, list(
#     rvest::html_table(xml2::read_html(htmltools::HTML(trimws(
#       rawToChar(res$content)
#     ))), fill = TRUE)[[3]][1][c(4, 7, 8), ]
#       ))
# }
#
# failure <- function(msg){
#   cat("Oh noes! Request failed!", msg, "\n")
# }
#
#
# lapply(seq_along(response$i_url), function(x)
#   curl::curl_fetch_multi(response$i_url[x],
#                          done = success,
#                          fail = failure,
#                          pool = pool,
#                          ))
#
# curl::multi_run(pool = pool)
#
# #================================================================================
#
# inspection_list <- lapply(response$i_url, curl::curl_fetch_memory)
#
# site_text <-
#   lapply(inspection_list, function(x)
#     rawToChar(x$content))
#
# site_tables <-
#   lapply(site_text, function(x)
#     rvest::html_table(xml2::read_html(htmltools::HTML(trimws(
#       x
#     ))), fill = TRUE)[[3]][1][c(4, 7, 8), ])
