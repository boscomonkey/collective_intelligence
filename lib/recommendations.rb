# Recommendation module to control namespace for Ruby equivalent of
# chapter 2 of "Programming Collective Intelligence".

require 'set'

unless defined? CRITICS
  # A dictionary of movie critics and their ratings of a small set of
  # movies
  CRITICS = {
    'Lisa Rose' => {'Lady in the Water' => 2.5, 'Snakes on a Plane' => 3.5, 
      'Just My Luck' => 3.0, 'Superman Returns' => 3.5, 'You, Me and Dupree' => 2.5, 
      'The Night Listener' => 3.0}, 
    'Gene Seymour' => {'Lady in the Water' => 3.0, 'Snakes on a Plane' => 3.5, 
      'Just My Luck' => 1.5, 'Superman Returns' => 5.0, 'The Night Listener' => 3.0, 
      'You, Me and Dupree' => 3.5}, 
    'Michael Phillips' => {'Lady in the Water' => 2.5, 'Snakes on a Plane' => 3.0, 
      'Superman Returns' => 3.5, 'The Night Listener' => 4.0}, 
    'Claudia Puig' => {'Snakes on a Plane' => 3.5, 'Just My Luck' => 3.0, 
      'The Night Listener' => 4.5, 'Superman Returns' => 4.0, 
      'You, Me and Dupree' => 2.5}, 
    'Mick LaSalle' => {'Lady in the Water' => 3.0, 'Snakes on a Plane' => 4.0, 
      'Just My Luck' => 2.0, 'Superman Returns' => 3.0, 'The Night Listener' => 3.0, 
      'You, Me and Dupree' => 2.0}, 
    'Jack Matthews' => {'Lady in the Water' => 3.0, 'Snakes on a Plane' => 4.0, 
      'The Night Listener' => 3.0, 'Superman Returns' => 5.0, 'You, Me and Dupree' => 3.5}, 
    'Toby' => {'Snakes on a Plane' => 4.5,'You, Me and Dupree' => 1.0,'Superman Returns' => 4.0}
  }
end

# A point in 2-D Euclidean space
#
Point = Struct.new(:x, :y) unless defined? Point

# Returns the distance between two 2-D points
#
def dist_2d(p0, p1)
  Math.sqrt(sqr(p0.x - p1.x) + sqr(p0.y - p1.y))
end

# Ranks two points regarding how similar they are
#
def rank_2d(p0, p1)
  normalize_rank dist_2d(p0, p1)
end

# Normalizes a similarity score so that it increases to 1.
#
def normalize_rank(n)
  1/(1 + n)
end

# Returns argument times itself. Override this method if square should
# be defined another way - i.e., n**2
#
def sqr(n)
  n * n
end

# Returns a distance-based similarity core for person1 and person2
#
def sim_distance(prefs, person1, person2)
  # build list of shared items
  si = Set.new
  prefs[person1].each_key {|item| si.add(item) if prefs[person2].key?(item)}
  
  # if they have no ratings in common, return 0
  return 0 if si.length.zero?
  
  # add up the squares of all the differences between shared items
  sum_of_squares = si.collect {|item| sqr(prefs[person1][item] - prefs[person2][item]) }.sum
  
  normalize_rank sum_of_squares
end

# Returns the Pearson correlation coefficient for p1 and p2
#
def sim_pearson(prefs, p1, p2)
  # get list of mutually rated items
  si = Set.new
  prefs[p1].each_key {|item| si.add(item) if prefs[p2].key?(item)}
  
  # find the number of elements
  n = si.length
  
  # if they have no ratings in common, return 0
  return 0 if n.zero?
  
  # add up all the preferences
  sum1 = si.collect {|it| prefs[p1][it]}.sum
  sum2 = si.collect {|it| prefs[p2][it]}.sum
  
  # sum up the squares
  sum1Sq = si.collect {|it| sqr prefs[p1][it]}.sum
  sum2Sq = si.collect {|it| sqr prefs[p2][it]}.sum
  
  # sum up the products
  pSum = si.collect {|it| prefs[p1][it] * prefs[p2][it]}.sum
  
  # calculate Pearson score
  den = Math.sqrt((sum1Sq - sqr(sum1)/n) * (sum2Sq - sqr(sum2)/n))
  return 0 if den.zero?
  
  num = pSum - (sum1 * sum2 / n)
  num/den
end

# Metric class whose "similarity" method returns the Euclidean
# distance between two persons in a preferences dictionary.
#
class EuclideanDistance
  def similarity(prefs, person1, person2)
    sim_distance(prefs, person1, person2)
  end
end

# Metric class whose "similarity" method returns the Pearson
# Correlation between two persons in a preferences dictionary.
#
class PearsonCorrelation
  def similarity(prefs, person1, person2)
    sim_pearson(prefs, person1, person2)
  end
end

# Returns the best matches for person from the preferences
# dictionary. Number of results and metric object are optional params.
#
def top_matches(prefs, person, n=5, metric=PearsonCorrelation.new)
  scores = prefs.keys.collect { |other|
    [metric.similarity(prefs, person, other), other] if other != person
  }.compact
  
  # sort the list so the highest scores appear at the top
  scores.sort.reverse[0,n]
end

# Gets recommendations for a person by using a weighted average of
# every other user's rankings
#
def get_recommendations(prefs, person, metric=PearsonCorrelation.new)
  totals = Hash.new 0
  simSums = Hash.new 0
  prefs.each_key { |other|
    # don't compare me to myself
    next if other == person
    sim = metric.similarity prefs, person, other
    
    # ignore scores of zero or lower
    next if sim <= 0
    prefs[other].each_key { |item|
      
      # only score items person hasn't seen yet
      if not prefs[person].key?(item) or prefs[person][item].zero?
        # similarity * score
        totals[item] += prefs[other][item] * sim
        
        # sum of similarities
        simSums[item] += sim
      end
    }
  }
  
  # create the normalized list
  rankings = totals.collect {|item, total| [total/simSums[item], item]}
  
  # return the sorted list
  rankings.sort.reverse
end

# Transforms a preferences dictionary from person-based to item-based.
#
def transform_prefs(prefs)
  result = Hash.new
  prefs.each_key {|person|
    prefs[person].each_key {|item|
      result[item] ||= Hash.new
      result[item][person] = prefs[person][item]
    }
  }
  result
end


