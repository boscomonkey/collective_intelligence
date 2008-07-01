#!/usr/bin/env ruby

require 'net/http'
require 'rexml/document'

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
  
  # Return, from file system, all the info associated with an URL
  #
  def urlposts_url_file(url)
    urlcode = Digest::MD5.hexdigest url
    fname = get_urlpost_fname urlcode
    File.open fname
  end
  
  # Return, from querying del.icio.us, all the info associated with an URL
  #
  def urlposts_url_stream(url)
    urlcode = Digest::MD5.hexdigest url
    urlhash = "http://feeds.delicious.com/rss/url/#{urlcode}"
    Net::HTTP.get_response(URI.parse(urlhash)).body
  end
  
  # Returns an XML stream from a file specified by the tag
  #
  def popular_file_stream(tag)
    fname = "data/popular.#{tag}.xml"
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
