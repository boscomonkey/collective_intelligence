#!/usr/bin/env ruby

require 'net/http'
require 'rexml/document'
require 'digest/md5'

module Delicious
  include CreatePosts
  
  
  # Returns an array of hashes corresponding to each popular del.icio.us post
  #
  def get_popular(tag='')
    begin
      parse_popular popular_url_stream(tag)
    rescue SocketError
      parse_popular popular_file_stream(tag)
    end
  end
  
  # Get a list of users that posted the url
  #
  def get_urlposts(url)
    begin
      response = urlposts_url_stream url
    rescue SocketError
      response = urlposts_url_file url
    end
    
    urlposts = []
    doc = REXML::Document.new(response)
    doc.elements.each("//item") { |item|
      urlposts << item.elements["dc:creator"].text
    }
    urlposts
  end
  
  # Parse a list of users from an urlposts XML stream
  #
  def urlposts_parse_users(response)
    doc = REXML::Document.new(response)
    doc.elements.collect("//item") { |item|
      item.elements["dc:creator"].text
    }
  end
  
  # Return, from file system, all the info associated with an URL
  #
  def urlposts_url_file(url)
    urlcode = md5_digest url
    fname = urlpost_offline_fname urlcode
    File.open fname
  end
  
  # Return, from querying del.icio.us, all the info associated with an URL
  #
  def urlposts_url_stream(url)
    urlcode = md5_digest url
    urlhash = "http://feeds.delicious.com/rss/url/#{urlcode}"
    Net::HTTP.get_response(URI.parse(urlhash)).body
  end
  
  # Return the MD5 digest of "str"
  #
  def md5_digest str
    Digest::MD5.hexdigest str
  end
  
  # Return the filename containing the XML stream corresponding to "urlcode".
  # Where "urlcode" is the result of calling md5_digest on an URL.
  #
  def urlpost_offline_fname(urlcode)
    "offline/urlposts.#{urlcode}.xml"
  end
  
  # Returns an XML stream from a file specified by the tag
  #
  def popular_file_stream(tag)
    fname = "offline/popular.#{tag}.xml"
    File.open fname
  end
  
  # Returns an XML stream from a URL specified by the tag
  #
  def popular_url_stream(tag)
    url = "http://del.icio.us/rss/popular/#{tag}"
    Net::HTTP.get_response(URI.parse(url)).body
  end
  
  # Parses a del.icio.us popular stream into an array of hashes where
  # the keys of each hash are "creator", "title", "date", "subject",
  # "link"
  # 
  def parse_popular(stream)
    doc = REXML::Document.new stream
    
    doc.elements.collect('//item') {|item|
      tbl = Hash.new
      item.elements.each {|e| tbl[e.name] = e.text }
      tbl
    }
  end
  
end
