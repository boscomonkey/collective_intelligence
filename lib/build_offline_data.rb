#!/usr/bin/env ruby

require 'net/http'
require 'rexml/document'

require 'delicious'

=begin
  Build data files needed for offline work (when no internet
connectivity is available). Retrieves and stores data needed by
get_popular (popular.{tag}.xml) and get_urlposts
(urlposts.{md5digest}.xml).
=end

class OfflineDataBuilder

  def initialize
    @delish = Delicious.new
  end
  
  # Run an OfflineDataBuilder once with an optional popular tag
  #
  def run(tag='')
    # store the popular tag
    xml = @delish.popular_xml_http(tag)
    write_file @delish.popular_fname(tag), xml
    
    # store the corresponding urlposts
    entries = @delish.extract_entries xml
    serialize_urlposts entries
  end
  
  # From an array of del.icio.us popular entries, extract & serialize the
  # posts into offline files.
  #
  def serialize_urlposts(populars)
    populars.each {|entry|
      # download the urlposts XML for each popular entry
      urlposts_xml = @delish.urlposts_xml_http entry.href
      write_file @delish.urlpost_fname(entry.href), urlposts_xml
      
      urlpost_entries = @delish.extract_entries(urlposts_xml)
      urlpost_entries.each { |urlpost|
        user_xml = @delish.userposts_xml_http urlpost.user
        write_file @delish.userposts_fname(urlpost.user), user_xml
      }
    }
  end
  
  # Open "fname" as a file for write and dump "content" into it.
  #
  def write_file(fname, content)
    File.open(fname, 'w') {|file| file << content}
  end
  
end

if __FILE__ == $0
  builder = OfflineDataBuilder.new
  if ARGV.empty?
    builder.run
  else
    ARGV.each {|arg| builder.run(arg)}
  end
end
