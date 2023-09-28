## Question 1 : `count_hits` method is slow
## Problem

# The major problem with the `count_hits` is that the hits table is queried for all the user's hit in the current month, this results in a slow  query
# especially for users with a multitude of hits monthly.

## Possible Solutions
# There are a number of possible solutions that can be used to refactor the `count_hits` method.
# 1. Caching
# 2. Optimize query
# 3. Use fast_count gem 
# will be to cache the results, this way the db is not queried each time a request is sent, instead the Cache is checked first, if no cached value is found,
# then the DB is queried.
# Memcache can be used to implement this.

## 1. Caching
# If implemented, the db is not queried each time a request is sent, instead the Cache is checked first, if no cached value is found,
# then the DB is queried and the data is cached for `n` minutes, n can be any positive number.
# Memcache can be used to implement this.

  def count_hits
    num_of_hits ||= Rails.cache.fetch("user_hits_count:#{current_user.id}", expires_in: 5.minute) do
      hits.where('created_at > ?', Time.now.beginning_of_month).count
    end
    num_of_hits
  end

## 2. Optimize Query
# The query in the `count_hits` method can be further optimized, by adding the user_id, the query will only count the rows where user_id and created_at columns meet the 
# set conditions
	def count_hits
		start = Time.now.beginning_of_month
    hits.where('created_at > ? and user_id = ?', start, user_id).count
  end

## 3. Use fast_count gem 
# This gem provides methods to query large DBs at a very high speed, it was inspired by the famous `quick_count` gem which is no longer maintained
# https://github.com/fatkodima/fast_count
# https://github.com/TwilightCoders/quick_count # Last update was 4 years ago
  #

  ## Question 2: Over quota issue for users in Australia (Apparently a different timezone)
  ## Problem
  # This is happening because of the timezone difference, it's safe to say the API server uses UTC timezone but users in several timezones are not
  # taken into consideration. There is a timezone mismatch between users time and the server's time.
  
  ## Solution
  # Ensure the user's timezone is used to check for quota limit, this can be done by first converting the UTC timezone to the user's localtime before the 
  # quota check is done.
  # The gem `localtime` can be used on the view of a rails app to set user's localtime, else the user's timezone can be stored on the users table `user_timezone` 
  # and used to do the quota check.

  ## Question 3: Requests over the monthly limit
  ## Problem
  # It is possible for some users to make requests beyond the monthly limit because they are probably using automated tools to send multiple requests at time,
  # or there is a loop hole in the API(maybe users are properly authenticated before the request is processed)
  #
  ## Solution.
  # Rate limting: this is implemented by restricting the number of requests a particular IP can send to an endpoint, within a set period of time,
  # an example would be to limit each hit to 50 every 10 seconds, this will return a `rate limit exceeded error message` if the requests within 10 seconds 
  # is greater then 50. `total_requests_in_last_10_seconds > 50 ?` There are multiple gems to achieve this but the most popular appears to be `rack-attack`
  # https://github.com/rack/rack-attack. 
  # The gem allows IP blacklisting, IP specific rate limiting, IP whitelisiting 
  # Sample code block
  Rack::Attack.throttle("requests by ip", limit: 50, period: 10) do |request|
    request.ip
  end

## 4 Refactor Code
  # Ideally, the count_hits method should be in PORO, preferably a service object(UserHitsService), this makes it easier to test and also implements the single responsibiity principle.
  # the `before_filter` call in the application controller can be changed to `before_action` to meet with rails best practices, the `count_hits` method is renamed to monthly_hits, 
  # see the refactored code below.

  class UserHitsService
    def monthly_hits
      num_of_hits ||= Rails.cache.fetch("user_hits_count:#{current_user.id}", expires_in: 5.minutes) do
        hits.where('created_at > ? and user_id = ?', Time.now.beginning_of_month, current_user.id).count
      end
      num_of_hits
    end
  end

  class ApplicationController < ActionController::API
    before_action :check_quota

    def check_quota
      render json: { error: 'over quota' } if current_user.monthly_hits >= 10000
    end
  end
