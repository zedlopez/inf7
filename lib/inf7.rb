require 'tty-which'

module Inf7
  class Error < StandardError; end
  Appname = 'inf7'
  Downloads = { data: { url: 'https://github.com/ptomato/inform7-ide/raw/dist-6M62/data/Inform_6M62_data.tar.lz',
                  dest: 'i7_6m62_data.tar.xz', },
                cli: { url: 'http://emshort.com/inform-app-archive/6M62/I7_6M62_Linux_all.tar.gz',
                       dest: 'i7_6m62.tar.gz', },
                quixe: { url: 'https://eblong.com/zarf/glulx/quixe/Quixe-220.zip',
                         dest: 'quixe.zip', },
                parchment: { url: 'https://github.com/curiousdannii/parchment/raw/ifcomp/dist/inform7/parchment-for-inform7.zip',
                             dest: 'parchment.zip', },
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

    def executable_name(sym)
      return nil unless sym
      (:cblorb == sym.to_sym) ? 'cBlorb' : sym.to_s
    end
    
    def check_executable(name, candidate: nil) 
	return candidate if candidate
	exec_name = executable_name(name)
	return nil unless exec_name	
	TTY::Which.exist?(executable_name(name)) ? TTY::Which.which(executable_name(name)) : nil
    end

end
require "inf7/version"
require "inf7/conf"
require "inf7/project"
require "inf7/template"
require "inf7/page"
require "inf7/template/layout"
require "inf7/source"
require "inf7/source/extension"
