# Takes API credentials and returns API token 
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
