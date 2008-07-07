require 'delicious'

class DeliciousRec

  def initialize
    @delish = Delicious.new
  end
  
  # Fill an initialized del.icio.us user dictionary with ratings
  #
  def fill_items(user_dict)
    all_items = {}
    
    # find links posted by all users
    user_dict.each_key {|user|
      # allow up to 2 more retries
      1.upto(3) { |i|
        begin
          posts = @delish.get_userposts(user)
          posts.each { |post|
            url = post.href
            user_dict[user][url] = 1.0
            all_items[url] = 1
          }
          
          # success, break out of retry loop for current user
          break
        rescue SocketError
          $stderr.puts "Failed user #{user}, retry ##{i}"
          sleep 4
        end
      }
    }
    
    # fill in missing items with 0.0
    user_dict.each_pair {|user, ratings|
      all_items.each_key {|item| ratings[item] ||= 0.0 }
    }
  end
  
  # Return an initialized del.icio.us user dictionary
  #
  def initialize_user_dict(tag='', count=5)
    user_dict = {}
    
    # get the top "count" popular posts
    @delish.get_popular(tag)[0,count].each { |p1|
      # find all users who posted this
      @delish.get_urlposts(p1.href).each { |p2|
        user = p2.user
        user_dict[user] = Hash.new
      }
    }
    
    user_dict
  end
end
