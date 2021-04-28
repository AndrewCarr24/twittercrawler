#' Get Twitter user network data
#'
#' get_user_network() takes a Twitter profile name or id number and returns data on this user's network connections, including an edgelist of the user's network.
#' @param screen_name Twitter user screen name.
#' @param id Twitter user id.
#' @param degree Number of degrees of user's friends/followers to collect.
#' @param token Twitter API token.
#' @param filter_col Name of column of user tibble to filter for Twitter user collection (optional).
#' @param filter_val Value to filter on (optional).
#' @param filter_logic For multiple filters, determines whether to filter based on "any" or "all" criteria (optional).
#' @param greater When filtering number of friends/followers, determines whether filter is ceiling or floor on number of users (optional).
#' @param ... Additional arguments used for recursive function call within function.
#' @return List with two elements: user tibble and edgelist tibble.
#' @examples
#' \dontrun{
#'
#' # Collect all connections 2 degrees from Twitter user Andrew_Carr24
#' # ex_token is the api token returned from api_credentials_to_token.
#'
#' get_user_network(screen_name = "Andrew_Carr24", degree = 2, token = ex_token)
#' }
#'@export
#' @importFrom magrittr %>%
get_user_network <- function(screen_name = NULL, id = NULL, degree = 1, token = NULL,
                             filter_col = NULL, filter_val = NULL, filter_logic = "any", greater = TRUE, ...){

  # Converting screen_name to id (if screen name is provided and id is not)
  if(is.null(id)){
    url_string <- paste0("https://api.twitter.com/1.1/users/show.json?screen_name=", screen_name)
    api_data <- rt_lim_GET(url_string, api_token)
    id <- content(api_data)$id_str
  }

  if(!exists("base_nodes_edges")){
    base_nodes_edges <- NULL
    layer_count <- 0
    collected_ids <- NULL
    steps <- 1
    }

  tryCatch({

    while(steps != 0){

      if(!grepl("^[0-9]+$", id)){ stop("User ids can only contain numbers.") }

      if(is.null(token)){ stop("A Twitter API token is needed.") }

      # Ids of friends
      id_object <- id_to_id_object(id, token = token)

      # Friend data tibble
      user_data <- get_user_data(id_object, degree = layer_count+1, token = token,
                                 filter_col = filter_col, filter_val = filter_val, filter_logic = filter_logic, greater = greater)

      # User-friends edgelist (if user has connections)
      user_edgelist <- if(!is.null(user_data)){ dplyr::tibble(from = id, to = user_data$id) }

      # Adding focal user to beginning of user_data (only for first iteration)
      if(layer_count == 0){
        user_data <- dplyr::bind_rows(get_user_data(id, token = token, degree = 0), user_data)
      }

      # Adding to existing network (if one exists)
      if(!is.null(base_nodes_edges) & !is.null(user_data)){
        user_data <- dplyr::bind_rows(base_nodes_edges[[1]], user_data) %>% dplyr::filter(!duplicated(screen_name))
        user_edgelist <- dplyr::bind_rows(base_nodes_edges[[2]], user_edgelist)
      }

      # Counter goes down when user data / edgelist added
      steps <- steps - 1

      if(layer_count > 0){
        con_str <- if(steps != 1){"connections"}else{"connection"}
        print(paste0(steps, " remaining ", degree_stringify(layer_count+1), " degree ",  con_str, " to collect."))
      }

      # layer_count goes up and steps reset when done with steps in a layer
      if(steps == 0){

        # Set marker to next degree
        layer_count <- layer_count + 1

        # Track Progress
        degree_string <- degree_stringify(layer_count)
        print(paste0("Finished collecting ", degree_string, " degree connections."))

        # Only reset steps if there are more layers to collect
        if(layer_count < degree){
          ext_ids <- c(id, collected_ids)
          steps <- nrow(user_data %>% dplyr::filter(!id %in% ext_ids) %>% dplyr::filter(!duplicated(screen_name)))
          con_str <- if(steps != 1){"connections"}else{"connection"}
          print(paste0(steps, " remaining ", degree_stringify(layer_count+1), " degree ",  con_str, " to collect."))
        }

      }

      # Adding to vector of collected ids
      collected_ids <- c(collected_ids, id)

      # Selecting user id for next iteration
      new_id <- if(!is.null(user_data)){
        user_data %>% dplyr::filter(!id %in% collected_ids) %>% dplyr::pull(id) %>% .[1]
      }else{
        base_nodes_edges[[1]] %>% dplyr::filter(!id %in% collected_ids) %>% dplyr::pull(id) %>% .[1]
      }

      # Adding to list of collected data
      base_nodes_edges <- if(!is.null(user_data)){ list(user_data, user_edgelist) }else{ base_nodes_edges }

      # Rerun function with values from this iteration as parameters
      id <- new_id

    }

    return(list(nodes = user_data, edges = user_edgelist))

  }, error = function(e){

    print(paste0(e, ". Returning data that has already been collected."))

    return(list(id = id, degree = degree, filter_col = filter_col, filter_val = filter_val, filter_logic = filter_logic, greater = greater,
                base_nodes_edges = base_nodes_edges, layer_count = layer_count, collected_ids = collected_ids, steps = steps))

  })


}
