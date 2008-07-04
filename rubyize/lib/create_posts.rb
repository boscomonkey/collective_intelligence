#!/usr/bin/env ruby

require 'net/http'
require 'rexml/document'

require 'delicious'

# Create XML files corresponding to each item in an array of "popular"
# del.icio.us posts. These files are for offline use when there's no
# internet connection (i.e., airplane).
#
module CreatePosts
  include Delicious

  # Serialize array of popular hashes into files so that the code can work
  # offline.
  #
  def serialize_posts(populars)
    populars.each {|h|
      urlcode = md5_digest h.href
      url = "http://feeds.delicious.com/rss/url/#{urlcode}"
      
      response = Net::HTTP.get_response(URI.parse(url)).body
      File.open(urlpost_offline_fname(urlcode), 'w') {|f| f << response}
    }
  end
  
  # Rename old "urlposts" XML files to the new directory and name format
  #
  def rename_popular_posts_files(populars)
    populars.each {|h|
      urlcode = md5_digest h.href
      File.rename get_old_urlpost_fname(urlcode), urlpost_offline_fname(urlcode)
    }
  end
  
  def get_old_urlpost_fname(urlcode)
    "urlposts#{urlcode}.xml"
  end
  
end

if __FILE__ == $0
  class App
    include CreatePosts
    
    def run(tag='')
      xml = popular_url_stream(tag)
      File.open(popular_offline_fname(tag), 'w') {|f| f << xml}
      
      entries = extract_entries xml
      serialize_posts entries
    end
  end
  
  App.new.run
end

