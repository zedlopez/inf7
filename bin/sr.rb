#!/usr/bin/env ruby

require 'inf7'
require 'pp'
sr = Inf7::Extension.new('/home/zed/.local/share/inf7/Internal/Extensions/Graham Nelson/Standard Rules.i7x')

#mod_lines = []
hash = {}

parts = Hash.new {|h,k| h[k] = {} }
current_part = nil

callouts = {}
sr.lines.dup.each.with_index(1) do |line, i|
  case line
  when /\ADocument\s+(.*)\s+at\s+(\S+)\s+"([^"]+)"\s+"([^"]+)"\.\Z/
    doc, ch_sect, ch_sect_w_name = $2, $3, $4
    refs = $1.split(/\s+/)
    ch, sect = ch_sect.split(/\./)
    refs.each {|r| hash[r] = %Q{<a href="http://inform7.com/book/WI_#{ch}_#{sect}.html">#{r}</a>}}
  when /\A(Part)/
    current_part = parts[line.chomp]
    callouts[i] = { part: line.chomp }
  when /\ASection(?:[^\/]+)\/(\S+)\s+\-\s+(.*)\Z/
    current_part[$1] = [ $2, i ]
    callouts[i] = { section: "#{$1} #{$2}" }
  when /\A(.*?)\s+is an action (?:applying|out of world)/
    callouts[i] = { action: $1 }
  end
end

pp callouts

#@content = mod_lines.join($/)

html = sr.pp_html.split($/)

html.each do |line|
  if line.match(/documented\s+at\s+([-_\w]+)/)
    ref = $1
puts line.sub(ref, hash[ref])
  else
    puts line
  end
end
