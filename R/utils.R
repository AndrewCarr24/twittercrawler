#' @importFrom magrittr %>%
#' @import httr
#' @import dplyr
#' @import purrr
## Utility functions for get_user_network -

globalVariables(c("id_str", "api_token", "filter_values", "."))

# Takes id // Returns ids object (ids of friends)
id_to_id_object <- function(id, cursor_str = "-1", friends = TRUE, id_lst = NULL, token = NULL){

  if(is.null(id_lst)){
    id_lst <- list()
  }

  if(friends){
    group_type <- "friends"
  }else{
    group_type <- "followers"
  }

  url_string <- paste0("https://api.twitter.com/1.1/", group_type, "/ids.json?user_id=", id, "&stringify_ids=true",
                       "&cursor=", cursor_str)

  api_data <- rt_lim_GET(url_string, token)

  id_object <- httr::content(api_data) %>% .$ids %>% chunk_ids()
  cursor_str <- httr::content(api_data) %>% .$next_cursor_str

  id_lst[[length(id_lst)+1]] <- id_object

  # Deals with protected accounts
  if(is.null(cursor_str)){
    return("")
  }

  if(cursor_str == "0"){
    return(id_lst %>% unlist)
  }else{
    return(id_to_id_object(id, cursor_str = cursor_str, friends = friends, id_lst = id_lst, token = api_token))
  }

}



# Wrapper for httr's GET function that handles Twitter rate limiting
rt_lim_GET <- function(url_string, token){

  data <- tryCatch({httr::GET(url_string, token)}, error = function(e){
    message(e)
    print("Retrying in 10 seconds.")
    Sys.sleep(10)
    return(rt_lim_GET(url_string, token))
  })

  if(data$status_code == 429){

    wait_func(data, token)
    Sys.sleep(5)
    return(rt_lim_GET(url_string, token))

  }else{

    if(data$status_code == 401){
      print("401 error.")
    }

    # Returns response for 200 or 401 status
    return(data)

  }

}


# Wait function for exceeding API usage limits
wait_func <- function(user_objects_data, token){

  rl_output <- GET("https://api.twitter.com/1.1/application/rate_limit_status.json?", api_token)
  wait_time <- content(rl_output)$resources$friends$`/friends/ids`$reset
  wait_time <- round(as.numeric(difftime(.POSIXct(wait_time), Sys.time(), units = "mins")), 2)

  wait_time_str <- wait_time_to_str(wait_time)

  print(paste0('There are 0 uses of the friends ids endpoint remaining in the current time window. Waiting about ', wait_time_str, '.'))
  Sys.sleep(60*wait_time)

}

# Helper - takes wait time and returns string with minutes and seconds
wait_time_to_str <- function(wait_time){

  min <- floor(wait_time)
  secs <- round((wait_time - min)*60)
  if(min == 1){min_word <- "minute"}else{min_word <- "minutes"}
  if(secs == 1){sec_word <- "second"}else{sec_word <- "seconds"}

  return(paste0(min, " ", min_word, " and ", secs, " ", sec_word))

}

# Takes vector of ids / Returns vectors of comma-separated 'chunks' of ids -- each element has <=100 ids
chunk_ids <- function(ids_vec){

  if(length(ids_vec) > 100){

    starts <- seq(1, length(ids_vec), 100)
    ends <- c(starts[2:length(starts)]-1, length(ids_vec))

    purrr::map2(starts, ends, function(start,end){
      return(paste(ids_vec[start:end], collapse=','))
    }) %>% unlist
  }else{
    return(paste(ids_vec, collapse=','))
  }

}


# Takes id_object // id, screenname, # friends, # followers, description, picture, location
get_user_data <- function(id_object, token = token, cursor_str = "-1", filter_col = NULL, filter_val = NULL, filter_logic = NULL,
                          degree = NULL, greater = greater){

  # Users with no connections return NULL
  if(id_object[1] == ""){ return(NULL) }

  purrr::map(id_object, function(ids){

    url_string <- paste0("https://api.twitter.com/1.1/users/lookup.json?user_id=", ids, "&tweet_mode=extended", "&cursor=", cursor_str)

    api_data <- rt_lim_GET(url_string, token)

    user_data_to_tbl(api_data, filter_col = filter_col, filter_val = filter_val, filter_logic = filter_logic, greater = greater)

  }) %>% do.call("rbind", .) %>% tibble::add_column(degree = degree)

}


# Takes user_data and returns tibble of relevant info
user_data_to_tbl <- function(user_data, filter_col = NULL, filter_val = NULL, filter_logic = NULL, greater = greater){

  tbl_fin <- purrr::map(httr::content(user_data), function(user){

    user %>% .[c("id_str", "screen_name", "name", "friends_count", "followers_count", "location", "description",
                 "url", "profile_image_url")] %>% purrr::modify_if(is.null, ~ NA) %>% dplyr::as_tibble() %>%
      mutate_at(c("id_str", "screen_name", "name", "location", "description", "url", "profile_image_url"), as.character) %>%
      mutate_at(c("friends_count", "followers_count"), as.integer) %>%
      dplyr::rename(id = id_str)

  }) %>% do.call("rbind", .)

  if(!is.null(filter_col) & !is.null(filter_val)){

    return( filter_apply(tbl_fin, filter_col, filter_val, filter_logic, greater = greater) )

  }else{

    return(tbl_fin)

  }

}

# Takes number and returns numeric string
degree_stringify <- function(deg){

  num_ords <- c("st", "nd", "rd", "th")

  if(deg < 4){

    return(paste0(deg, num_ords[deg]))

  }else{

    return(paste0(deg, num_ords[4]))
  }

}



# Function that handles filter commands
filter_apply <- function(user_tbl, filter_col, filter_val, filter_logic, greater = TRUE){

  if(length(filter_col) == 1){
    filter_col <- as.list(rep(list(filter_col), length(filter_values)))
  }

  tbl_results <- map2(filter_col, filter_val, function(col, val){

    # Only include users whose description, name, location field contain some search term
    if(col %in% c("description", "name", "location")){

      return(user_tbl %>% dplyr::filter(grepl(tolower(val), tolower(!!rlang::sym(col)))))

    }else if(col %in% c("friends", "followers")){

      col <- paste0(col, "_count")

      if(greater){
        return(user_tbl %>% dplyr::filter(!!rlang::sym(col) >= val))
      }else{
        return(user_tbl %>% dplyr::filter(!!rlang::sym(col) <= val))
      }

    }

  })

  if(filter_logic == "any"){

    return( do.call("rbind", tbl_results) )

  }else if(filter_logic == "all"){

    return( Reduce(intersect, tbl_results) )

  }

}

