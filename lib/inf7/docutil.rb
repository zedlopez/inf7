module Inf7::DocUtil

  def anchorify(*list)
    list.map(&:to_s).map(&:downcase).join(' ').strip.gsub(/[^-\.\w]/,'-').gsub(/-+/,'-')
  end

  def unite_code(orig)
    node = Inf7::Doc::Doc.create_element('div')
    orig.xpath('.//comment()').remove #each { |comment| comment.remove }
    %w{ p blockquote }.each do |nodename|
      orig.xpath(%Q{.//#{nodename}[not(*) and not(text()[normalize-space()])]}).each do |n|
        n.remove
      end
    end

    newdiv = nil
    incode = false      
    orig.children.each do |child|
      next if incode and child.text? and !child.inner_text.match(/\S/)
      old_incode = incode
      incode = ((child.name == 'blockquote' and child[:class] and child[:class] == 'code') or (child.name == 'table' and child[:class] and child[:class] == 'codetable'))
      if incode
        if !old_incode
          newdiv = Inf7::Doc::Doc.create_element('div', class: 'code')
          if child.name == 'table'
            newdiv << child
          else
            child.children.each { |grandchild| newdiv << grandchild }
          end
          node << newdiv
          next
        end
        if child.name == 'table'
          newdiv << child
        else
          child.children.each { |grandchild| newdiv << grandchild }
        end
        next
      end
      node << child  
    end
    node
  end
end

