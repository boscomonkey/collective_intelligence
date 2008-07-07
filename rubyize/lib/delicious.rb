#!/usr/bin/env ruby

require 'net/http'
require 'rexml/document'
require 'digest/md5'

class Delicious
  # Directory where offline files are stored
  OFFLINE_DIR = 'offline'
  
  # Throw this exception when del.icio.us is throttling us
  #
  class ThrottlingException < RuntimeError
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
  
  def initialize
    @timestamp = 0.0
  end
  
  # Returns an array of Entry objects corresponding to each popular
  # del.icio.us post
  #
  def get_popular(tag='')
    begin
      extract_entries popular_xml_http(tag)
    rescue SocketError
      extract_entries popular_xml_file(tag)
    end
  end
  
  # Get a list of users that posted the url
  #
  def get_urlposts(url)
    begin
      extract_entries urlposts_xml_http(url)
    rescue SocketError
      extract_entries urlposts_xml_file(url)
    end
  end
  
  # Get array of posts for a del.icio.us user
  #
  def get_userposts(user)
    begin
      extract_entries userposts_xml_http(user)
    rescue SocketError
      extract_entries userposts_xml_file(user)
    end
  end
  
  
  # Returns an XML stream from a file specified by the tag
  #
  def popular_xml_file(tag)
    fname = popular_fname(tag)
    File.open fname
  end
  
  # Returns an XML stream from a URL specified by the tag
  #
  def popular_xml_http(tag)
    url = "http://del.icio.us/rss/popular/#{tag}"
    http_response_body url
  end
  
  # Return the filename containing the XML stream corresponding to popular
  # del.icio.us posts tagged with 'tag'.
  #
  def popular_fname(tag)
    File.join OFFLINE_DIR, "popular.#{tag}.xml"
  end
  
  
  # Return, from file system, the XML stream associated with an URL
  #
  def urlposts_xml_file(url)
    fname = urlpost_fname url
    File.open fname
  end
  
  # Return, from querying del.icio.us, the XML stream associated with an URL
  #
  def urlposts_xml_http(url)
    urlcode = md5_digest url
    urlhash = "http://feeds.delicious.com/rss/url/#{urlcode}"
    http_response_body urlhash
  end
  
  # Return the MD5 digest of "str"
  #
  def md5_digest str
    Digest::MD5.hexdigest str
  end
  
  # Return the filename containing the XML stream corresponding to an URL.
  #
  def urlpost_fname(url)
    urlcode = md5_digest url
    File.join OFFLINE_DIR, "urlposts.#{urlcode}.xml"
  end
  
  
  # Retrieve XML stream of a del.icio.us user's posts from offline store
  #
  def userposts_xml_file(user)
    File.open userposts_fname(user)
  end
  
  # Retrieve XML stream of posts for a user from HTTP
  #
  def userposts_xml_http(user)
    url = "http://feeds.delicious.com/rss/#{user}"
    http_response_body url
  end
  
  # Return the filename where a del.icio.us user's posts are stored
  #
  def userposts_fname(user)
    File.join OFFLINE_DIR, "userposts.#{user}.xml"
  end
  
  # Return the HTTP response body for an URL
  #
  def http_response_body(url)
    # http://del.icio.us/help/api/
    # - wait at least 1 second between requests
    # - watch for 503 errors & back off
    now = Time.now
    if (@timestamp != 0.0) && (now - @timestamp < 1.0)
      sleep @timestamp + 1.0 - now
    end
    
    body = ''
    uri = URI.parse url
    retries = 0
    begin
      # following code from http://snippets.dzone.com/posts/show/2431
      Net::HTTP.new(uri.host, uri.port).start { |http|
        path_query = uri.path + (blank?(uri.query) ? '' : '?' + uri.query)
        req = Net::HTTP::Get.new(path_query,
                                 {'User-Agent' => "#{__FILE__} (alpha 0.01)"})
        response = http.request(req)
        body = response.body
        
        raise ThrottlingException if body.include?('<title>Yahoo! - 503')
      }
    rescue Net::HTTPFatalError, ThrottlingException, Timeout::Error
      log retries
      sleep 2**retries
      
      retries += 1
      retry
    end
    
    log '.'
    @timestamp = Time.now
    
    body
  end
  
  def blank?(obj)
    obj.nil? || (not obj) || obj.empty?
  end
  
  def log(msg)
    if defined? DEBUG
      $stderr.print msg
      $stderr.flush
    end
  end
  
end
