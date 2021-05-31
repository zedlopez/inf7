#!/usr/bin/env ruby

require 'rouge'
require './inform7.rb'

filename = ARGV.shift

source = File.read(filename).gsub(/\r/,'')
lexer = (filename.end_with?('.ni') ? Rouge::Lexers::Inform7::Story : Rouge::Lexers::Inform7::Extension).new

lexer.lex(source).each do |token, value|
  puts
  print "#{token} |#{value.gsub(/\n/,'\\n')}|"

  puts "\n" * $1.length if value.match(/(\n+)\Z/)
  
  
  # value.each_char do |c|
  #   case c
  #   when /\n+/
  #     print "\\n\n"
  #   when "\t"
  #     print "TAB"
  #   when " "
  #     print "|#{
  #   else
  #     print c
  #   end
  # end
end
