# twittercrawler
The twittercrawler R package provides a way to collect network data through Twitter's standard v1.1 APIs.  To use this package, you will need API credentials.  You can apply for these through Twitter's developer pages (https://developer.twitter.com/en/docs/twitter-api/getting-started/guide). 

The main function of the twittercrawler package is the get_user_network function.  This function takes three required arguments: id, degree, and token.  The id argument takes a Twitter user id.  The degree argument specifies the degrees of separation up to which the function with collect user and network information.  For example, if specify that degree equals 2, the function will collect all friends of a given user and then collect user data from all of those friends' friends.  In other words, the functino will return information for all users that are at most 2 degrees separated from the focal user. Finally, the token argument takes the API token needed to access Twitter's API.  This is an object returned from twittercrawler's api_credentials_to_token function.  Here's a demonstration of how the package works - 

```{r}
api_token <- api_credentials_to_token(app_name, consumer_key, consumer_secret, access_token, access_secret)

get_user_network(id = "778619636510326784", degree = 2, token = api_token)
```
