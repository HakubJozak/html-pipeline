require 'pry'

module HTML
  class Pipeline
    # HTML filter that adds a 'name' attribute to all headers
    # in a document, so they can be accessed from a table of contents
    #
    class TableOfContentsFilter < Filter
      def call
        headers = Hash.new(0)
        topics = TOC.new
        stack = [ topics ]

        doc.css('h1, h2, h3, h4, h5, h6').each do |node|
          name = node.text.downcase
          name.gsub!(/[^\w\- ]/, '') # remove punctuation
          name.gsub!(' ', '-') # replace spaces with dash
          name = EscapeUtils.escape_uri(name) # escape extended UTF-8 chars

          uniq = (headers[name] > 0) ? "-#{headers[name]}" : ''
          headers[name] += 1

          if header_content = node.children.first
            reference = "#{name}#{uniq}"
            header_content.add_previous_sibling(%Q{<a name="#{reference}" class="anchor" href="##{reference}"><span class="mini-icon mini-icon-link"></span></a>})

            # list only H1 in the TOCs
            toc = TOC.new(node, reference)

            while stack.last.level >= toc.level do
              stack.pop
            end

            stack.last << toc
            stack.push toc
          end
        end

        unless topics.empty?
          topics.inject_to_html(doc)
        end

        doc
      end
    end

    private

    class TOC < Array
      attr_accessor :level, :title, :reference

      # Table of Contents bound to a concrete HTML node
      # (which is either parent header or document root)
      #
      def initialize(node = nil, reference = nil)
        if node
          raise 'Missing reference' unless reference
          @level = node.name[-1].to_i
          @title = node.children.first
          @reference = reference
        else
          @level = 0
          @title = 'Table of Contents'
          @reference = 'table-of-contents'
        end
      end

      def html_id
        @html_id ||= if level == 0
                       "##{reference}"
                     else
                       "#toc-h#{level+1}-#{reference}"
                     end
      end

      def inject_to_html(doc)
        list_items = self.map do |t|
          t.inject_to_html(doc)
          %Q{<li><a href="##{t.reference}">#{t.title}</a></li>}
        end

        unless doc.css(html_id).empty?
          doc.css(html_id).first << """
            <ul>
              #{list_items.join("\n")}
            </ul>
           """
        end
      end


      def inspect
        "(#{reference}: #{super})"
      end
    end
  end
end
