module Inf7
  class Error < StandardError; end
  Appname = 'inf7'
  Downloads = { data: { url: 'https://github.com/ptomato/gnome-inform7/raw/master/data/Inform_6M62_data.tar.lz',
                  dest: 'i7_6m62_data.tar.xz', },
                cli: { url: 'http://inform7.com/apps/6M62/I7_6M62_Linux_all.tar.gz',
                  dest: 'i7_6m62.tar.gz', }
              }
  I7_version = "6M62"
  
  FormatStuff = { 'glulx' => { suffix: 'ulx',
                               i6flag: 'G',
                               i7format: 'ulx',
                               zcode_version: '256',
                               blorb: 'gblorb',
                             },
                  'zcode' => { suffix: 'z8',
                               i6flag: 'v8',
                               i7format: 'v8',
                               zcode_version: '8',
                               blorb: 'zblorb',
                             }
                }

  Zcode_to_format = FormatStuff.transform_values {|v| v[:zcode_version] }.invert.transform_values(&:to_s) # 256 => glulx, 8 => zcode

end
require "inf7/version"
require "inf7/conf"
require "inf7/project"
require "inf7/template"
