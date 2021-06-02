# -*- coding: utf-8 -*- #
# frozen_string_literal: true




# \b - Matches word boundaries when outside brackets; backspace (0x08) when inside brackets

# \B - Matches non-word boundaries

# (?=pat) - Positive lookahead assertion: ensures that the following characters match pat, but doesn't include those characters in the matched text

# (?!pat) - Negative lookahead assertion: ensures that the following characters do not match pat, but doesn't include those characters in the matched text

# (?<=pat) - Positive lookbehind assertion: ensures that the preceding characters match pat, but doesn't include those characters in the matched text

# (?<!pat) - Negative lookbehind assertion: ensures that the preceding characters do not match pat, but doesn't include those characters in the matched text



require 'pp'

def recur(*args)
#  regexps = []
  pp args
#  puts args.class
#  args.each do |arg|
#    regexps << arg.respond_to?(:to_a) ? "(?:#{builder(*arg)})?" : "(#{arg.keys.first})"
  #  end
  args.map {|arg| (!arg.respond_to?(:keys)) ? "(?:#{builder(*arg)})?" : "(#{arg.keys.first})" }.join
end

  
def builder(*args)
  puts 'entering builder'
  regexp = %r{#{recur(*args)}}
  flat = args.flatten
  tokens = flat.map {|i| pp i; i.values.first }
  return regexp, tokens
end

module Rouge
  module Lexers
    class Inform7 < RegexLexer


      NL = Text::Whitespace.make_token(:newline, :nl)
      WS = Text::Whitespace
      
      Tab = Rouge::Token.make_token(:tab, :tb)
      Inform6 = Rouge::Token.make_token(:inform6, :i6)
      Heading = Rouge::Token.make_token(:heading, :hdg)
      TableHead = Rouge::Token.make_token(:table_head, :tblhead)
      TableBegin  = Rouge::Token.make_token(:table_begin, :tbl_begin)
      TableEnd  = Rouge::Token.make_token(:table_end, :tbl_end)
      TableColumn = Rouge::Token.make_token(:table_column, :tblcol)
      BlockHead = Rouge::Token.make_token(:block_head, :blk_hd)

      title 'Inform 7'
      desc "Inform 7, a design system for interactive fiction"
      tag 'i7'
      mimetypes 'application/inform7'

      state :string do
#        puts "\n*string*\n"
        rule /\[/, Str::Interpol
        rule /[^\\"]+/, Str::Double 
        rule /"/, Str::Double, :pop!
               end

               state :textsub do
                 rule /[^\]]+/, Str::Interpol
                 rule /\]/, Str::Interpol, :pop!
               end               

               state :nested_comment do
#                 puts 'nested_comment'
                 rule /[^\[\]]+/, Comment
                 rule(/\[/) { token Comment; push :nested_comment }
                 rule /\]/, Comment, :pop!
               end

               state :generic do
                 rule /[_\w]+/, Generic
                 rule /[^_\w]/, Generic, :pop!
               end

               state :tab do
                 rule /\t/, Tab, :pop!
               end

               state :heading do
                 rule /\n/, NL, :pop!
                 rule /[^\n]+/, Heading
               end

               state :table_row do
                 rule /[^\t\n]+/, TableColumn
                 rule /\t+/, Tab
                 rule /\n/, NL, :pop!
               end

               state :table do
                 rule /with\s+\d+\s+blank\s+rows?/, TableEnd, :pop!
                 rule /\n/, NL, :pop!
                 rule(//) { push :table_row }
               end

               state :table_begin do
                 rule /[A-Za-z][- \w]+[-\w]/, Str::Symbol
                 rule(/\n/) { token NL ; pop! ; push :table }
               end

               state :table_head do
                 rule /[\ ]+/, Text::Whitespace, :table_begin
                 rule(//) { pop! }
               end
               
               state :bol do
#        puts "\n*bol*\n"
                 rule /(Volume|Book|Part|Chapter|Section)/i, Heading, :heading
                 rule /----\s+documentation\s+----\n/i, Comment::Multiline, :documentation
                 rule /Table\s+of/, Keyword, :table_head
                 rule //, NL, :pop! 
               end
               state :documentation do
                 rule //, Comment::Multiline
               end

               state :inform6 do
                 rule /-\)/, Inform6, :pop!
                 rule /./, Inform6
               end

               state :blockhead do
                 # look for condition
               end

               state :phrase do
                 rule /[ ]+/, Text::Whitespace
               end

               state :phrase_preamble do
                 rule /(\s+)([^:\(]+?)(:)/ do
                   [             Text::Whitespace,
                                 Str::Symbol, # spring the trap | say xyzzy
                                 Operator,
                   ].each.with_index(1) do |tok, i|
                     token tok, m[i] if m[i]
                   end
                   pop!
                   push :phrase
                 end
                 rule /[ ]+/, Text::Whitespace
               end

               state :rule_preamble do

               end

               # <rule> ::=
               #     Definition : A/an <kind> is <new adjectival name> if/unless <definition>
               #     | <preamble> : <phrases>
               #     | <preamble> , <phrase> (* only allowed for a few cases: see below)

               # <definition> ::=
               #     <condition>
               #     | its/his/her/their <value property name> is/are <value> or less/more
               #     | : <phrases>

               # <preamble> ::=
               #     To <phrase template>
               #     | To decide if/whether <phrase template>
               #     | To decide which/what <kind of value> is <phrase template>
               #     | This is the <rule name>
               #     | [[A] Rule for] <circumstances> [(this is the <rule name>)]

               # <circumstances> ::=
               #     At <time>
               #     | When <event name>
               #     | [<placement>] <rulebook reference> [while/when <condition>] [during <scene name>]

               # <rulebook reference> ::=
               #     <rulebook name> [about/for/of/on/rule] [<action pattern>]
               #     | <object-based-rulebook name> [about/for/of/on/rule] [<description>]

               # <placement> ::=
               #     a/an
               #     | [the] first
               #     | [the] last

               # <phrases> ::=
               #     <phrase>
               #     | <phrases> ; <phrase>

               # The following examples show how Inform breaks down some typical rules using the system above:

               # <rule> = At 2:09 PM: increase the score by 2; say "Progress!"
               #     <preamble> = At 2:09 PM
               #         <circumstances> = At 2:09 PM
               #             At
               #             <time> = 2:09 PM
               #     :
               #     <phrases> = increase the score by 2; say "Progress!"
               #         <phrase> = increase the score by 2
               #         ;
               #         <phrase> = say "Progress"

               # <rule> = Instead of eating the ostrich during Formal Dinner (this is the cuisine rule), say "It's greasy!"
               #     <preamble> = Instead of eating the ostrich during Formal Dinner (this is the cuisine rule)
               #         <circumstances> = Instead of eating the ostrich during Formal Dinner
               #             <rulebook reference> = Instead of eating the ostrich
               #                 <rulebook name> = Instead
               #                 of
               #                 <action pattern> = eating the ostrich
               #             during
               #             <scene name> = Formal Dinner
               #         (
               #         this
               #         is
               #         the
               #         <rule name> = cuisine rule
               #         )
               #     ,
               #     <phrases> = say "It's greasy!"
               #         <phrase> = say "It's greasy!"

               # <rule> = After printing the name of a container: say "!"
               #     <preamble> = After printing the name of a container
               #         <circumstances> = After printing the name of a container
               #             <rulebook reference> = After printing the name of a container
               #                 <object-based-rulebook name> = After printing the name
               #                 of
               #                 <description> = a container
               #     :
               #     <phrases> = say "!"
               #         <phrase> = say "!"

               # (*) The colon dividing a rule preamble from its definition can be replaced by a comma only if the preamble begins with the words "Instead of", "Before", "After", "Every turn" or "When", and if the definition consists only of a single phrase.

               
               #       [only before, instead, after rules can take a ',' instead of a ':' ]

               # TODO internal spaces on parenthetical ?


               
ws = { /[ ]+/ => WS }
defn_list = [ ws,
{ /.+?(?!(?:\s+(?:is|\()))/ => Keyword }, # a supporter

[ ws,
  { /\(/ => Operator }, # (
  { /called/ => Keyword }, # called
ws,
{ /[^\)]+/ => Str::Symbol }, # T
{ /\)/ => Operator } ], #)
ws,
{ /is/ => Keyword }, # is
ws,
{ /.+?(?!(?:rather|if|unless))/ => Str::Symbol }, # hefty
[ ws, { /rather\s+than/ => Keyword }, ws, { /.+?/ => Str::Symbol } ], # rather than light
ws,
{ /if|unless/ => Keyword },
ws,
{ /[^.]+/ => Keyword },
{ /\./ => Operator } ]

state :defn_preamble do
  defn_regexp, defn_tokens = builder(*defn_list)
  puts defn_regexp
rule(defn_regexp) do |m|
  churn(m, *defn_tokens)
pop!
end
rule(//) { pop! }
end

def churn(m, *args)
  args.each.with_index(1) do |tok, i|
    token tok, m[i] if m[i]
  end
end

state :phrase do
  rule(/([^.]+)(\.)/) do |m|
    token Keyword, m[1];
    token Punctuation, m[2];
    pop!
    push :main
  end
end

state :defn_adj do
#  puts "\nin defn_adj"
  rule(/(\s+)(rather\s+than)(\s+)/) do |m|
#    puts "\nin rather than"
    token WS, m[1];
    token Keyword, m[2];
    token WS, m[3];
  end
  rule(/(\s+)(if|unless)(\s+)/) do |m|
#    puts "\nin if/unless"
    token WS, m[1];
    token Keyword, m[2];
    token WS, m[3];
    pop!
    push :phrase
  end
#  rule /.+(?!(?:rather\s+than|if|unless))/, Str::Symbol
  #  rule /.+(?:(?!if))/, Str::Symbol
  rule /./, Str::Symbol
end

state :definition_preamble do
#  puts "\nin definition_preamble"
  rule(/(\s+)(is)(\s+)/) do |m|
    token WS, m[1];
    token Keyword, m[2];
    token WS, m[3];
    push :defn_adj
  end
  rule(/(\s+)(\()(\s+)?(called)(\s+)([^\)]+)(\s+)?(\))(\s+)/) do |m|
    token WS, m[1];
    token Operator, m[2];
    token WS, m[3] if m[3];
    token Keyword, m[4];
    token WS, m[5];
    token Str::Symbol, m[6];
    token WS, m[7] if m[7];
    token Operator, m[8];
    token WS, m[9];
    push :defn_adj
  end
  rule /./, Str::Symbol
end

               state :main do
#        puts "\n*main*\n"
               rule %r/\n/, NL, :bol
               rule /\t/, Tab # , :tab
               rule /\(-/, Inform6, :inform6
               rule /[:;]\s*/, Operator
               rule /\[/, Comment, :nested_comment
        rule /[ ]+/, Text::Whitespace
               #        rule /To/i, Keyword, :phrase_preamble
               #        rule /At/i, Keyword, :at_time_preamble
               rule(/(Definition:)(\s+)/i) do |m|
                 token Keyword, m[1];
                 token WS, m[2];
                 push :definition_preamble # :defn_preamble #
               end
               rule /[_\w]/, Generic, :generic
               
               
               #        rule /(?:if|repeat|while)/, BlockHead, :block_head
               end

               # state :terminating_comment do
               #   rule /[^\[\]]+/, Comment
               #   rule(/\]/) { token Comment; push :main }
               # end
               state :root_base do
                 rule %r/\s+/, Text::Whitespace
                 rule /\[/, Comment, :nested_comment
      end
      
      state :root do
        rule /\[/, Comment, :nested_comment
      end

    class Extension < Inform7
      filenames '*.i7x'

      
      state :desc do
      mixin :root_base
#        rule(/"[^\\"]+"/) { token Str::Double ; pop! ; push :main }
        rule /"[^\\"]+"/, Str::Double, :main
                rule(//) { pop! ; push :main }
                end

                state :root do
                  mixin :root_base
                  # perversely, titles can have embedded newlines, but I'll pretend they can't
                  rule(/(?:(Version)(\s+)(\d+(?:\/\d{6})?)(\s+)(of)(\s+))?([^(]+?)(?:(\s+)(\()(for)(\s+)([-\w]+)(?:(\s+)(version)(\s+)(\d))?(\s+)(only)(\)))?(\s+)(by)(\s+)(.+?)(\s+)(begins\s+here)(\.)/) do |m|

                    [ Keyword, # Version
                      Text::Whitespace,
                      Num, # 3 or 3/20210501
                      Text::Whitespace,
                      Keyword, # of 
                      Text::Whitespace,
                      Str::Symbol, # ext_name
                      Text::Whitespace,
                      Operator, # (
                      Keyword, # for
                      Text::Whitespace,
                      Str::Symbol, # glulx|z-machine
                      Text::Whitespace,
                      Keyword, # version
                      Text::Whitespace,
                      Num, # 8
                      Text::Whitespace,
                      Keyword, # only
                      Operator, # )
                      Text::Whitespace,
                      Keyword, # by
                      Text::Whitespace,
                      Str::Symbol, # author
                      Text::Whitespace,
                      Keyword, # begins here
                      Punctuation, # '.'
                    ].each.with_index(1) do |tok, i|
                      token tok, m[i] if m[i]
                    end
                    push :desc
                  end
                end
                end





                class Story < Inform7
                  filenames '*.ni'
                  #TitleName = Rouge::Token.make_token(:titlename, :tin)
                  Title = Rouge::Token.make_token(:title, :ti)


                  # state :author do
                  #   rule(/(.+?)(\s+)(begins\s+here)(\s*)(\.)/) do |m|
                  #     token Str::Symbol, m[1]
                  #     token Text::Whitespace, m[2]
                  #     token Keyword, m[3]
                  #     token Text::Whitespace, m[4] if m[4]
                  #     token Operator, m[5]
                  #   end
                  #         rule(/\n/) { token NL; :pop! ; push :main }
                  #       end             

                  # perversely, author names can have embedded newlines and be terminated by a comment or a blank line but I'll pretend they can't



                  # state :title do
                  #   rule %r/[ ]+/, Text::Whitespace
                  #   rule(/(by)(\s+)/) do |m|  token Keyword::Pseudo, m[1]; token Str, m[2]; push :author ; end
                  #   rule(//) { pop!; push :main }
                  # end

                  state :root do
                    mixin :root_base
                    # perversely, titles can have embedded newlines, but I'll pretend they can't
                    rule(/("[^\\"]+")([ ]+)(?:(by)([ ]+)([^\n]+))?/) do |m|
                      churn(m,
                        Str::Double, # title
                        Text::Whitespace,
                        Keyword, # by
                        Text::Whitespace,
                        Str::Symbol # author
                      )
                      push :main
                    end
                  end

                end




                end


                end

                end
