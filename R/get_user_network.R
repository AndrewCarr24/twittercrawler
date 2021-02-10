# Takes Twitter user information and returns list of data on users in network connections and an edgelist of user's network  
#' @param id Twitter user id.
#' @param degree Number of degrees of user's friends/followers to collect.
#' @param degree Number of "layers" of user's friends/followers to collect.
#' @param token Twitter API token.
#' @param track_progress Determines whether to print progress of data collection (optional).
#' @param filter_col Name of column of user tibble to filter for Twitter user collection (optional).
#; @param filter_val Value to filter on (optional).
#; @param greater When filtering number of friends/followers, determines whether filter is ceiling or floor on number of users (optional).
#' @return List with two elements: user tibble and edgelist tibble.
#' @examples
#' ex_id <- 778619636510326784 # Example Twitter user id
#' ex_degree <- 2 # Collect user's friends and their friends' friends
#' ex_token <- api_token # Returned from api_credentials_to_token function
#' get_user_network(id = ex_id, degree = ex_degree, token = ex_token)                           
#' @export
get_user_network <- function(id = NULL, degree = 1, token = NULL, track_progress = TRUE, filter_col = NULL, filter_val = NULL, greater = TRUE,
                             base_nodes_edges = NULL, layer_count = 0, collected_ids = NULL, steps = 1){
  
  tryCatch({
    
    if(!grepl("^[0-9]+$", id)){stop("User ids can only contain numbers.")} 
    
    if(is.null(token)){ stop("A Twitter API token is needed.") }
    
    # Ids of friends
    id_object <- id_to_id_object(id, token = token)
    
    # Friend data tibble
    user_data <- get_user_data(id_object, token = token, filter_col = filter_col, filter_val = filter_val, greater = greater, degree = layer_count+1) 
    
    # User-friends edgelist (if user has connections)
    user_edgelist <- if(!is.null(user_data)){ tibble(from = id, to = user_data$id) }
    
    # Adding focal user to beginning of user_data (only for first iteration)
    if(layer_count == 0){
      user_data <- bind_rows(get_user_data(id, token = token, degree = 0), user_data)
    }
    
    # Adding to existing network (if one exists)
    if(!is.null(base_nodes_edges) & !is.null(user_data)){
      user_data <- bind_rows(base_nodes_edges[[1]], user_data) %>% filter(!duplicated(screen_name))
      user_edgelist <- bind_rows(base_nodes_edges[[2]], user_edgelist)
    }
    
    # Counter goes down when user data / edgelist added 
    steps <- steps - 1 
    
    if(track_progress & layer_count > 0){
      con_str <- if(steps != 1){"connections"}else{"connection"}
      print(paste0(steps, " remaining ", degree_stringify(layer_count+1), " degree ",  con_str, " to collect."))
    }
    
    # layer_count goes up and steps reset when done with steps in a layer 
    if(steps == 0){
      
      # Set marker to next degree 
      layer_count <- layer_count + 1
      
      # Track Progress (if set to true)
      degree_string <- degree_stringify(layer_count)
      print(paste0("Finished collecting ", degree_string, " degree connections."))
      
      # Only reset steps if there are more layers to collect
      if(layer_count < degree){
        ext_ids <- c(id, collected_ids)
        steps <- nrow(user_data %>% filter(!id %in% ext_ids) %>% filter(!duplicated(screen_name)))
        con_str <- if(steps != 1){"connections"}else{"connection"}
        print(paste0(steps, " remaining ", degree_stringify(layer_count+1), " degree ",  con_str, " to collect."))
      }
      
    }
    
    # Return nodes if steps = 0 and layer_count = degree 
    if( degree == 1 | (layer_count == degree & steps == 0) ){
      
      return(list(nodes = user_data, edges = user_edgelist))
      
      # Reruns function with new values otherwise 
    }else{
      
      collected_ids <- c(collected_ids, id)
      
      # Selecting user id for next iteration
      new_id <- if(!is.null(user_data)){
        user_data %>% filter(!id %in% collected_ids) %>% pull(id) %>% .[1] 
      }else{
        base_nodes_edges[[1]] %>% filter(!id %in% collected_ids) %>% pull(id) %>% .[1]   
      }
      
      # Adding to list of collected data 
      base_nodes_edges <- if(!is.null(user_data)){ list(user_data, user_edgelist) }else{ base_nodes_edges }
      
      # Rerun function with values from this iteration as parameters 
      get_user_network(id = new_id, degree = degree, base_nodes_edges = base_nodes_edges, 
                       layer_count = layer_count, collected_ids = collected_ids, steps = steps, 
                       token = token, track_progress = track_progress, filter_col = filter_col, filter_val = filter_val, greater = greater)
      
    }
    
    
  }, error = function(e){
    
    print(e)
    
    return(list(id = id, degree = degree, base_nodes_edges = base_nodes_edges, layer_count = layer_count, collected_ids = collected_ids, 
                steps = steps))
    
  })
  
}
