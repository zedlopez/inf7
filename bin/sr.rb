#!/usr/bin/env ruby

require 'inf7'
require 'pp'
sr = Inf7::Extension.new(ARGV.shift)

hash = {}

hierarch = {}
cur_part = nil
cur_sect = nil
cur_sub_sect = nil
sr.lines.dup.each.with_index(1) do |line, i|
  case line
  when /\ADocument\s+(.*)\s+at\s+(\S+)\s+"([^"]+)"\s+"([^"]+)"\.\Z/
    doc, ch_sect, ch_sect_w_name = $2, $3, $4
    refs = $1.split(/\s+/)
    ch, sect = ch_sect.split(/\./)
    refs.each {|r| hash[r] = %Q{<a href="http://inform7.com/book/WI_#{ch}_#{sect}.html">#{r}</a>}}
  when /\A(Part)/
    hierarch[ line.chomp ] = { line: i, sections: {}}
    cur_part = line.chomp 
  when /\ASection(?:[^\/]+)\/(\S+)\s+\-\s+(.*)\Z/
    raw_sect = $1
    name = $2
    if raw_sect.match(/(\d+)\/(\d+)/)
      cur_sect = $1
      sub_sect = $2
      cur_sub_sect = sub_sect
      name.match(/\A(.*?)\s+-\s+(.*)/)
      cur_sect_name = $1
      sub_sect_name = $2
      hierarch[cur_part][:sections][cur_sect] ||= { subsections: {}, line: i, name: cur_sect_name }
      hierarch[cur_part][:sections][cur_sect][:subsections][cur_sub_sect] = { name: sub_sect_name, actions: {}, line: i }
    else
      cur_sect = raw_sect
      hierarch[cur_part][:sections][cur_sect] = { name: name, actions: {}, line: i}
    end
      
  when /\A(.*?)\s+is an action (?:applying|out of world)/
    if cur_sub_sect
      hierarch[cur_part][:sections][cur_sect][:subsections][cur_sub_sect][:actions][$1] = { line: i }
    else
      hierarch[cur_part][:sections][cur_sect][:actions][$1] = i
    end
  end
end

html = sr.pp_html(standalone: true).split($/)

def toc(hierarch)
  puts %Q{<h1 style="text-align: center;">Standard Rules by Graham Nelson</h1>}
  puts %Q{<h2 style="text-align: center;">Version 3/120430 for Inform 7 6M62</h2>}
  puts %Q{<div>The Standard Rules are &copy; Graham Nelson and published under the <a href="https://github.com/zedlopez/standard_rules/blob/main/LICENSE.md">Artistic License 2.0</a>.</div>}
  puts %Q{<div class="toc" style="margin: 3rem;">}
  hierarch.each_pair do |part, part_hash|
    puts "<details><summary><strong>#{part}</strong></summary><ul>"
    part_hash[:sections].each_pair do |section, sect_hash|
      unless sect_hash.key?(:subsections)
        puts %Q{<li>#{section}. <a href="#line#{sect_hash[:line]}">#{sect_hash[:name]}</a></li>}
        unless sect_hash[:actions].empty?
          puts "<details><summary>Actions</summary><ul>"
          sect_hash[:actions].each_pair do |action, line|
            puts %Q{<li><a href="#line#{line}">#{action}</a></li>}
          end
          puts "</ul></details>"
        end
      else
        puts %Q{<details><summary>#{section}. #{sect_hash[:name]}</summary><ul>}
        sect_hash[:subsections].each_pair do |sub_sect, sub_sect_hash|
          puts %Q{<li><a href="#line#{sub_sect_hash[:line]}">#{sub_sect} #{sub_sect_hash[:name]}</a></li>}
        end
        puts "</ul></details>"
      end
    end
    puts "</ul></details>"
  end
  puts "</div>"
end

html.each do |line|
  case line
  when /<!--\s+toc\s+-->/
    puts toc(hierarch)
  when /documented\s+at\s+([-_\w]+)/
    ref = $1
    puts line.sub(ref, hash[ref])
  else
    puts line
  end
end
