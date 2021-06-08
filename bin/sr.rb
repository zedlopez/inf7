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

#@content = mod_lines.join($/)

html = sr.pp_html(standalone: true).split($/)

def toc(callouts)
  in_action = false
  in_part = false
  in_section = false
  puts '<div class="toc">'
  callouts.each_pair do |line_num,hash|
    hash.each_pair do |k,v|
      if in_action and :action != k
        in_action = false
        puts "</details>"
      end
      case k
      when :part
        puts "</details>" if in_part
        in_part = true
        puts "</ul>" if in_section
        in_section = false
        puts "<details><summary>#{v}</summary>"
        puts %Q{<a href="#line#{line_num}">#{v}</a><br>}
      when :section
        puts "<ul>" unless in_section
        in_section = true
        puts %Q{<li><a href="#line#{line_num}">#{v}</a></li>}
      when :action
        if !in_action
          puts %Q{<details><summary>Actions</summary>}
          in_action = true
        end
        puts %Q{&emsp;&emsp;<a href="#line#{line_num}">#{v}</a><br>}
      end
    end
  end
  puts "</div>"              


                  
end


html.each do |line|
  case line
  when /<!--\s+toc\s+-->/
    puts toc(callouts)
  when /documented\s+at\s+([-_\w]+)/
    ref = $1
    puts line.sub(ref, hash[ref])
  else
    puts line
  end
end
