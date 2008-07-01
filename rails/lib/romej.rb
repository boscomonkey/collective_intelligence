# ----------------------------------------------------------------------
# 
# Ruby adaptations of the Python code found in Toby Segaran's
# Programming Collective Intelligence book.
# 
# steven.romej @ gmail (4 may 08)
# ----------------------------------------------------------------------


class Recommendations
  # -------------------------------------------------
  # Euclidean distance 
  # -------------------------------------------------

  # Returns a distance-based similarity score for person1 and person2
  def sim_distance( prefs , person1 , person2 )
    # Get the list of shared_items
    si = {}
    for item in prefs[person1].keys
      if prefs[person2].include? item
        si[item] = 1
      end
    end

    # if they have no ratings in common, return 0
    return 0 if si.length == 0

    squares = []
    for item in prefs[person1].keys
      if prefs[person2].include? item
        squares << (prefs[person1][item] - prefs[person2][item]) ** 2
      end
    end

    sum_of_squares = squares.inject { |sum,value| sum += value }
    return 1/(1 + sum_of_squares)
  end

  # -------------------------------------------------
  # Pearson score
  # -------------------------------------------------

  # Returns the Pearson correlation coefficient for p1 and p2
  def sim_pearson( prefs, p1, p2)
    # Get the list of mutually rated items
    si = {}
    for item in prefs[p1].keys
      si[item] = 1 if prefs[p2].include? item
    end

    # Find the number of elements
    n = si.length
    # If there are no ratings in common, return 0
    return 0 if n == 0

    # Add up all the preferences
    sum1 = si.keys.inject(0) { |sum,value| sum += prefs[p1][value] }
    sum2 = si.keys.inject(0) { |sum,value| sum += prefs[p2][value] }

    # Sum up the squares
    sum1Sq = si.keys.inject(0) { |sum,value| sum += prefs[p1][value] ** 2 }
    sum2Sq = si.keys.inject(0) { |sum,value| sum += prefs[p2][value] ** 2 }

    # Sum up the products
    pSum = si.keys.inject(0) { |sum,value| sum += (prefs[p1][value] * prefs[p2][value])}

    # Calculate the Pearson score
    num = pSum - (sum1*sum2/n)
    den = Math.sqrt((sum1Sq - (sum1 ** 2)/n) * (sum2Sq - (sum2 ** 2)/n))

    return 0 if den == 0
    r = num / den
  end

  # Ranking the critics
  # TODO lacks the score-function-as-parameter aspect of original
  def topMatches( prefs, person, n=5, scorefunc = :sim_pearson )
    scores = []
    for other in prefs.keys
      if scorefunc == :sim_pearson
        scores << [ sim_pearson(prefs,person,other), other] if other != person
      else
        scores << [ sim_distance(prefs,person,other), other] if other != person
      end
    end
    return scores.sort.reverse.slice(0,n)
  end

  # Gets recommendations for a person by using a weighted average
  # of every other user's rankings
  # TODO just uses sim_pearson and not a function as parameter
  def getRecommendations(prefs, person, scorefunc = :sim_pearson )
    totals = {}
    simSums = {}
    for other in prefs.keys
      # don't compare me to myself
      next if other == person

      if scorefunc == :sim_pearson
        sim = sim_pearson( prefs, person, other)
      else
        sim = sim_distance( prefs, person, other)
      end

      # ignore scores of zero or lower
      next if sim <= 0

      for item in prefs[other].keys
        # only score movies I haven't seen yet
        if !prefs[person].include? item or prefs[person][item] == 0
          # similarity * score
          totals.default = 0
          totals[item] += prefs[other][item] * sim
          # sum of similarities
          simSums.default = 0
          simSums[item] += sim
        end
      end
    end

    # Create a normalized list
    rankings = []
    totals.each do |item,total|
      rankings << [total/simSums[item], item]
    end

    # Return the sorted list
    return rankings.sort.reverse
  end


  def transformPrefs( prefs )
    result = {}
    for person in prefs.keys
      for item in prefs[person].keys
        result[item] = {} if result[item] == nil
        # Flip item and person
        result[item][person] = prefs[person][item]
      end
    end
    return result
  end

  def calculateSimilarItems( prefs, n = 10 )
    # Create a dictionary of items showing which other items they are most similar to
    result = {}

    # Invert the preference matrix to be item-centric
    itemPrefs = transformPrefs(prefs)

    c = 0
    for item in itemPrefs.keys
      # Status updates for large datasets
      c += 1
      puts "#{c}/#{itemPrefs.length}" if c % 100 == 0
      # Find the most similar items to this one
      scores = topMatches(itemPrefs, item, n, :sim_distance)
      result[item] = scores
    end
    return result
  end


  def getRecommendedItems( prefs, itemMatch, user)
    userRatings = prefs[user]
    scores = {}
    totalSim = {}

    # Loop over items rated by this user
    userRatings.each do |item,rating|
      itemMatch[item].each do |similarity,item2|
        # Ignore if this user has already rated this item
        next if userRatings.include? item2

        # Weighted sum of rating times similarity
        scores[item2] = 0 if scores[item2] == nil
        scores[item2] += similarity * rating

        # Sum of all the similarities
        totalSim[item2] = 0 if totalSim[item2] == nil
        totalSim[item2] += similarity
      end
    end

    # Divide each total score by total weighting to get an average
    rankings = []
    scores.each do |item,score|
      rankings << [score/totalSim[item], item]
    end

    return rankings.sort.reverse
  end


  def loadMovieLens( path = "ml-data" )
    movies = {}
    File.open(path + "/u.item") do |file|
      while !file.eof?
        (id,title) = file.readline.split("|")[0,2]
        movies[id] = title
      end
    end

    prefs = {}
    File.open(path + "/u.data") do |file|
      while !file.eof?
        (user,movieid,rating,ts) = file.readline.split("\t")
        prefs[user] = {} if prefs[user] == nil
        prefs[user][movies[movieid]] = rating.to_f
      end
    end 
    return prefs
  end

end


# ----------------------------------------------------------------------
# A simple class that implements the necessary pydelicious functions
# Sleeps 1 second after each request to prevent 503 errors
# ----------------------------------------------------------------------
require 'net/http'
require 'rexml/document'
require 'digest/md5'

module Delicious

  # Get a list of popular urls (title and link)
  def get_popular( tag = "" )
    popular = []
    url = "http://del.icio.us/rss/popular/#{tag}"

    response = Net::HTTP.get_response(URI.parse(url)).body
    doc = REXML::Document.new(response)

    doc.elements.each("//item") do |item|
      popular << { "title" => item.elements["title"].text , "href" => item.elements["link"].text }
    end
    sleep 1
    return popular
  end

  # Get a list of users that posted the url
  def get_urlposts( url )
    urlposts = []
    urlcode = Digest::MD5.hexdigest(url)
    url = "http://feeds.delicious.com/rss/url/#{urlcode}"

    response = Net::HTTP.get_response(URI.parse(url)).body
    doc = REXML::Document.new(response)

    doc.elements.each("//item") do |item|
      urlposts << { "user" => item.elements["dc:creator"].text }
    end

    sleep 1
    return urlposts
  end

  # Get a list of urls by username
  def get_userposts( user )
    posts = []
    url = "http://feeds.delicious.com/rss/#{user}"

    response = Net::HTTP.get_response(URI.parse(url)).body
    doc = REXML::Document.new(response)

    doc.elements.each("//item") do |item|
      posts << { "href" => item.elements["link"].text }
    end

    sleep 1
    return posts
  end
end

# ----------------------------------------------------------------------
# A del.icio.us link recommendation engine
# ----------------------------------------------------------------------
class DeliciousRec
  include Delicious

  # returns a dictionary of users, each pointing to empty hash
  def initializeUserDict( tag, count = 1 )
    user_dict = {}
    # get the top 'count' popular posts
    for p1 in get_popular(tag)[0,count]
      # find all users who posted this
      for p2 in get_urlposts(p1["href"])
        user = p2["user"]
        user_dict[user] = {}
      end
    end
    return user_dict
  end

  def fillItems( user_dict )
    all_items = {}
    # Find links posted by all users
    for user in user_dict.keys
      for attempt in 1..3
        begin
          puts "fetching for #{user}"
          posts = get_userposts(user)
          puts "fetched posts for #{user}"
          sleep 2
          break
        rescue
          puts "Failed user #{user}, retrying"
          sleep 4
        end
      end

      for post in posts
        url = post["href"]
        user_dict[user][url] = 1
        all_items[url] = 1
      end
    end

    # Fill in missing items with 0
    for ratings in user_dict.values
      for item in all_items.keys
        ratings[item] = 0 if !ratings.include? item
      end
    end
  end
end


class App

  def run
    # A dictionary of movie critics and their ratings of a small
    # set of movies
    critics = {'Lisa Rose'=> {'Lady in the Water'=> 2.5, 'Snakes on a Plane'=> 3.5,
 'Just My Luck'=> 3.0, 'Superman Returns'=> 3.5, 'You, Me and Dupree'=> 2.5, 
 'The Night Listener'=> 3.0},
 'Gene Seymour'=> {'Lady in the Water'=> 3.0, 'Snakes on a Plane'=> 3.5, 
 'Just My Luck'=> 1.5, 'Superman Returns'=> 5.0, 'The Night Listener'=> 3.0, 
 'You, Me and Dupree'=> 3.5}, 
 'Michael Phillips'=> {'Lady in the Water'=> 2.5, 'Snakes on a Plane'=> 3.0,
 'Superman Returns'=> 3.5, 'The Night Listener'=> 4.0},
 'Claudia Puig'=> {'Snakes on a Plane'=> 3.5, 'Just My Luck'=> 3.0,
 'The Night Listener'=> 4.5, 'Superman Returns'=> 4.0, 
 'You, Me and Dupree'=> 2.5},
 'Mick LaSalle'=> {'Lady in the Water'=> 3.0, 'Snakes on a Plane'=> 4.0, 
 'Just My Luck'=> 2.0, 'Superman Returns'=> 3.0, 'The Night Listener'=> 3.0,
 'You, Me and Dupree'=> 2.0}, 
 'Jack Matthews'=> {'Lady in the Water'=> 3.0, 'Snakes on a Plane'=> 4.0,
 'The Night Listener'=> 3.0, 'Superman Returns'=> 5.0, 'You, Me and Dupree'=> 3.5},
 'Toby'=> {'Snakes on a Plane'=>4.5,'You, Me and Dupree'=>1.0,'Superman Returns'=>4.0}
    }


    recommendations = Recommendations.new

    # Test the Euclidean score code 
    puts "The Euclidean distance score is #{recommendations.sim_distance( critics , "Lisa Rose", "Gene Seymour")}"
    # Test the Pearson score
    puts "The Pearson score is #{recommendations.sim_pearson( critics , "Lisa Rose" , "Gene Seymour" )}"
    # Test the topMatches
    puts recommendations.topMatches(critics,"Toby", 3)
    # Try getting recommendations
    puts recommendations.getRecommendations(critics,"Toby")
    # Transform the preferences, get recommendation
    movies = recommendations.transformPrefs( critics )
    puts recommendations.topMatches( movies , "Superman Returns")

    itemsim = recommendations.calculateSimilarItems(critics)
    puts itemsim
    puts recommendations.getRecommendedItems(critics, itemsim, "Toby")

    # -------------------------------------------------------------------
    # del.icio.us examples
    delicious = DeliciousRec.new
    delusers = delicious.initializeUserDict("programming")
    delicious.fillItems(delusers)
    # pick a user at random
    user = delusers.keys[rand(delusers.length - 1)]
    puts "user is #{user}"
    puts recommendations.topMatches(delusers,user)
    puts recommendations.getRecommendations(delusers,user)[0,10]
    url = recommendations.getRecommendations(delusers,user)[0][1]
    puts "the url is #{url}"
    puts recommendations.topMatches(recommendations.transformPrefs(delusers),url)

    # --------------------------------------------------------------------
    # Movie Lens examples
    ##prefs = recommendations.loadMovieLens()
    #puts prefs["87"]
    #puts recommendations.getRecommendations(prefs, "87")[0,30]
    ##itemsim = recommendations.calculateSimilarItems(prefs, n=50)
    ##puts recommendations.getRecommendedItems(prefs, itemsim, "87")[0,30]
  end
end

app = App.new
app.run

