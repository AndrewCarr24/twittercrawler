#' Takes Twitter API credentials and returns API token.
#' @param app_name Twitter app name.
#' @param consumer_key Twitter consumer key.
#' @param consumer_secret Twitter consumer secret.
#' @param access_token Twitter access token.
#' @param access_secret Twitter access secret.
#' @return Twitter API token.
#' @examples
#' ex_app_name = ####
#' ex_consumer_key = ####
#' ex_consumer_secret = ####
#' ex_access_token = ####
#' ex_access_secret = ####
#' api_credentials_to_token(app_name = ex_app_name, consumer_key = ex_consumer_key, 
#'                          consumer_secret = ex_consumer_secret, access_token = ex_access_token, 
#'                          access_secret = ex_access_secret)
#' @export
api_credentials_to_token <- function(app_name, consumer_key, consumer_secret, access_token, access_secret){
  
  # Get app data 
  app <- httr::oauth_app(
    appname = app_name,
    key = consumer_key,
    secret = consumer_secret
  )
  
  # Get access token and secret 
  credentials <- list(oauth_token = access_token,
                      oauth_token_secret = access_secret)
  params <- list(as_header = TRUE)
  
  # Put together token 
  token <- httr::Token1.0$new(app = app, endpoint = httr::oauth_endpoints("twitter"),
                              params = params, credentials = credentials, cache = FALSE)
  
  return(token)
  
}
