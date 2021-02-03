
# Takes Twitter user id and a "degree" parm that indicates how many layers of the user's Twitter network to collect 
# // Returns list of data on user's in network connections and an edgelist of user's network  
get_user_network <- function(id = NULL, degree = 1, base_nodes_edges = NULL, layer_count = 0, collected_ids = NULL, 
                             steps = 1, token = NULL, track_progress = FALSE, filter_col = NULL, filter_val = NULL){
  
  if(is.null(token)){ stop("A Twitter API token is needed.") }
  
  # Ids of friends
  id_object <- id_to_id_object(id, token = token)
  
  # Friend data tibble
  user_data <- get_user_data(id_object, filter_col = filter_col, filter_val = filter_val)
  
  # User-friends edgelist
  user_edgelist <- tibble(from = id, to = user_data$id)
  
  # Adding to existing network (if one exists)
  if(!is.null(base_nodes_edges)){
    user_data <- bind_rows(base_nodes_edges[[1]], user_data) %>% distinct()
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
    
    # Only reset steps if there are more layers to collect
    if(layer_count < degree){
      steps <- nrow(user_data %>% filter(!id %in% collected_ids))
    }
    
    # Track Progress (if set to true)
    degree_string <- degree_stringify(layer_count)
    print(paste0("Finished collecting ", degree_string, " degree connections."))
    
  }
  
  if( degree == 1 | (layer_count == degree & steps == 0) ){
    
    return(list(nodes = user_data, edges = user_edgelist))
    
  }else{
    
    collected_ids <- c(collected_ids, id)
    new_id <- user_data %>% filter(!id %in% collected_ids) %>% pull(id) %>% .[1]
    base_nodes_edges <- list(user_data, user_edgelist)
    
    # Rerun function with values from this iteration as parameters 
    get_user_network(id = new_id, degree = degree, base_nodes_edges = base_nodes_edges, 
                     layer_count = layer_count, collected_ids = collected_ids, steps = steps, 
                     token = token, track_progress = track_progress, filter_col = filter_col, filter_val = filter_val)
    
  }
  
}