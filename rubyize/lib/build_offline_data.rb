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
  include Delicious
  
  # Run an OfflineDataBuilder once with an optional popular tag
  #
  def run(tag='')
    # store the popular tag
    xml = popular_url_stream(tag)
    write_file popular_offline_fname(tag), xml
    
    # store the corresponding urlposts
    entries = extract_entries xml
    serialize_urlposts entries
  end
  
  # From an array of del.icio.us popular entries, extract & serialize the
  # posts into offline files.
  #
  def serialize_urlposts(populars)
    populars.each {|entry|
      xml = urlposts_url_stream entry.href
      write_file urlpost_offline_fname(md5_digest(entry.href)), xml
    }
  end
  
  # Open "fname" as a file for write and dump "content" into it.
  #
  def write_file(fname, content)
    File.open(fname, 'w') {|file| file << content}
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
  builder = OfflineDataBuilder.new
  if ARGV.empty?
    builder.run
  else
    ARGV.each {|arg| builder.run(arg)}
  end
end
