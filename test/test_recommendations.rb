#!/usr/bin/env ruby

=begin
Test driver for recommendations.rb
=end

# recommendations.rb is in the sibling directory ../lib
$:.unshift File.join(File.dirname(__FILE__), "..", "lib")

require 'recommendations.rb'
require 'test/unit'

# Adds 'sum' method to Enumerable module as it's needed by
# recommendations.rb
#
module Enumerable
  def sum
    total = first
    slice(1..-1).each {|i| total += i}
    total
  end
end

# Amount of "slop" that floating numbers are allowed to be off from
# each other.
#
Delta = 1.0e-12

Gene = 'Gene Seymour'
Lisa = 'Lisa Rose'
Toby = 'Toby'

class TestRecommendations < Test::Unit::TestCase
  def test_euclidean
    expected_float = 0.148148148148148
    
    sd1 = sim_distance CRITICS, Lisa, Gene
    assert_in_delta expected_float, sd1, Delta
    
    sd2 = sim_distance CRITICS, Gene, Lisa
    assert_in_delta expected_float, sd2, Delta
  end
  
  def test_pearson
    expected_float = 0.396059017191
    
    pc1 = sim_pearson CRITICS, Lisa, Gene
    assert_in_delta expected_float, pc1, Delta
    
    pc2 = sim_pearson CRITICS, Gene, Lisa
    assert_in_delta expected_float, pc2, Delta
  end
  
  def test_top_matches
    tm = top_matches CRITICS, Toby
    assert_equal 5, tm.size
    assert_duples [0.99124070716192991,
                    0.92447345164190486,
                    0.89340514744156474,
                    0.66284898035987,
                    0.381246425831512], tm
  end
  
  def test_top_matches_explicit_length
    tm = top_matches CRITICS, Toby, 3
    assert_equal 3, tm.size
    assert_duples [0.99124070716192991, 0.92447345164190486, 0.89340514744156474], tm
  end
  
  def test_get_recommendations
    duples = get_recommendations CRITICS, Toby
    
    assert_duples [3.3477895267131013, 2.8325499182641614, 2.5309807037655645], duples
  end

  def test_get_recommendations_euclidean
    duples = get_recommendations CRITICS, Toby, EuclideanDistance.new
    
    assert_duples [3.5002478401415877, 2.7561242939959363, 2.4619884860743739], duples
  end
  
  def test_transform_prefs
    items = Set.new
    CRITICS.each_value {|item_hash| item_hash.each_key {|it| items.add it}}

    movies = transform_prefs CRITICS
    assert_equal items.size, movies.keys.size
    movies.each_key {|k| assert items.include?(k), "'#{k}' is not an item." }
    
    # should equal to original after 2 tranformations
    t2 = transform_prefs(movies)
    assert_equal CRITICS, t2
    
    # compare against book's matches
    matches = top_matches(movies, 'Superman Returns')
    expected = [[0.657, "You, Me and Dupree"],
                [0.487, "Lady in the Water"],
                [0.111, "Snakes on a Plane"],
                [-0.179, "The Night Listener"],
                [-0.422, "Just My Luck"]]
    assert_pairs expected, matches, 1.0e-3
    
    # compare against book's recommendations
    recs = get_recommendations(movies, 'Just My Luck')
    expected_recs = [[4.0, 'Michael Phillips'], [3.0, 'Jack Matthews']]
    assert_pairs expected_recs, recs, Delta
  end

  private
  
  def assert_duples(expected_floats, f_str_duples)
    expected_floats.each_with_index {
      |f, i| assert_in_delta f, f_str_duples[i].first, Delta
    }
  end
  
  def assert_pairs(expected_pairs, test_pairs, delta)
    expected_pairs.each_with_index {|pair, i|
      assert_in_delta(pair.first, test_pairs[i].first, delta)
      assert_equal pair.last, test_pairs[i].last
    }
  end
end
