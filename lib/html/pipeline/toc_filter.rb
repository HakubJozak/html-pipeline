require 'pry'

module HTML
  class Pipeline
    # HTML filter that adds a 'name' attribute to all headers
    # in a document, so they can be accessed from a table of contents
    #
    class TableOfContentsFilter < Filter
      def call
        headers = Hash.new(0)
        topics = TOC.new(doc)
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

        if builder = @context[:toc_builder]
          topics.inject_to_html(builder)
        end

        doc
      end
    end

    private

    class TOC < Array
      attr_accessor :level, :title, :reference
      attr_reader :parent_header, :html_id

      # Table of Contents bound to a concrete HTML node
      # (which is either parent header or document root)
      #
      def initialize(node, reference = nil)
        if reference
          @level = node.name[-1].to_i
          @title = node.children.first
          @reference = reference
        else
          # main table of contents containing all the H1
          @level = 0
          @title = 'Table of Contents'
          @reference = 'table-of-contents'
        end

        @parent_header = node
      end

      # Convenience method returning a classic TOC like:
      #
      # <ul id="#{self.html_id}">
      #   <li><a href='...'>Chapter 1</a></li>
      #   ...
      # </ul>
      #
      def to_html
        list_items = self.map do |t|
          %Q{<li><a href="##{t.reference}">#{t.title}</a></li>}
        end

        """
          <ul id='#{self.html_id}'>
            #{list_items.join("\n")}
          </ul>
        """
      end

      def html_id
        @html_id ||= if level == 0
                       "#{reference}"
                     else
                       "toc-h#{level+1}-#{reference}"
                     end
      end

      def inject_to_html(builder)
        builder.call(self)

        self.each do |t|
          t.inject_to_html(builder)
        end
      end


      def inspect
        "(#{reference}: #{super})"
      end
    end
  end
end
