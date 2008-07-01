#!/usr/bin/env ruby

require 'net/http'
require 'rexml/document'

# Create XML files corresponding to each item in an array of "popular"
# del.icio.us posts
#
module CreatePosts

  # Convert array of popular hashes into files
  #
  def popular_posts(populars)
    populars.each {|h|
      link = h['link']
      urlcode = Digest::MD5.hexdigest link
      url = "http://feeds.delicious.com/rss/url/#{urlcode}"
      
      response = Net::HTTP.get_response(URI.parse(url)).body
      File.open(get_urlpost_fname(urlcode), 'w') {|f| f << response}
    }
  end
  
  # Rename old "urlposts" XML files to the new directory and name format
  #
  def rename_popular_posts_files(populars)
    populars.each {|h|
      link = h['link']
      urlcode = Digest::MD5.hexdigest link
      File.rename get_old_urlpost_fname(urlcode), get_urlpost_fname(urlcode)
    }
  end
  
  def get_urlpost_fname(urlcode)
  "data/urlposts.#{urlcode}.xml"
  end
  
  def get_old_urlpost_fname(urlcode)
  "urlposts#{urlcode}.xml"
  end
  
end

if __FILE__ == $0
  # TODO Generated stub
end