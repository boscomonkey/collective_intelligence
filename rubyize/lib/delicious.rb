#!/usr/bin/env ruby

require 'net/http'
require 'rexml/document'
require 'digest/md5'

module Delicious
  
  
  # Returns an array of hashes corresponding to each popular del.icio.us post
  #
  def get_popular(tag='')
    begin
      extract_entries popular_url_stream(tag)
    rescue SocketError
      extract_entries popular_file_stream(tag)
    end
  end
  
  # Get a list of users that posted the url
  #
  def get_urlposts(url)
    begin
      extract_entries urlposts_url_stream(url)
    rescue SocketError
      extract_entries urlposts_url_file(url)
    end
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
  
  # Map Entry field names to element attribute names in the XML stream
  #
  FIELD_NAMES = {
    :href=>"link",
    :hash=>nil,
    :count=>nil,
    :user=>"creator",
    :dt=>"date",
    :extended=>"description",
    :description=>"title",
    :tags=>"subject"
  }
  
  # Structure that holds the fields for a del.icio.us popular post
  #
  Entry = Struct.new *(FIELD_NAMES.keys)
  
  # Reverse map element attribute names in the XML stream to PopularStruc
  # field name
  #
  ATTRIB_NAMES = {}
  FIELD_NAMES.each_pair {|fld, att| ATTRIB_NAMES[att] = fld unless att.nil? }
  
  # Extract an array of Entry objects from a del.icio.us XML stream
  # 
  def extract_entries(stream)
    doc = REXML::Document.new stream
    
    doc.elements.collect('//item') {|item|
      struc = Entry.new
      item.elements.each {|attrib|
        nom = attrib.name
        struc[ATTRIB_NAMES[nom]] = attrib.text if ATTRIB_NAMES.include?(nom)
      }
      struc
    }
  end
  
end
