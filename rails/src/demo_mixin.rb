#!/usr/bin/env ruby

=begin
Demonstrates how to mixin a Module into a Class so that class
instances get the methods defined in the Module.
=end

module Fixie
  def gears
    [0, 1, 1, 2, 3, 5, 8, 13, 21, 34]
  end
end

class Bicycle
  include Fixie
end

if __FILE__ == $0
  # puts Bicycle.gears
  puts Bicycle.new.gears
end
