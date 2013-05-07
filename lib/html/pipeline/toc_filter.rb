module HTML
  class Pipeline
    # HTML filter that adds a 'name' attribute to all headers
    # in a document, so they can be accessed from a table of contents
    #
    class TableOfContentsFilter < Filter
      def call
        headers = Hash.new(0)
        topics = []

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
            if (level = node.name[-1].to_i) == 1
              topics << [ header_content, reference ]
            end
          end
        end

        unless topics.empty? or doc.css("#table-of-contents").empty?
          items = topics.map { |name,reference| %Q{<li><a href="##{reference}">#{name}</a></li>} }

          doc.css("#table-of-contents").first << """
            <h1>Table of Contents</h1>
            <ul>
              #{items.join("\n")}
            </ul>
           """
        end

        doc
      end
    end
  end
end
