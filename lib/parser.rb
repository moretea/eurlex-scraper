module Parser
  FIND_COMITTEE = /committee/i
  FIND_OPINION = /opinion/i
  SPLIT_DIRCODES = /(\d{2}\.\d{2}\.\d{2}.\d{2}\D+)/

  def self.parse_output(potential_doc, html)
    doc = Document.new
    doc.year = potential_doc.year
    doc.letter = potential_doc.letter
    doc.number = potential_doc.number

    html_doc = Oga.parse_html html

    info_from_div_boxes = {}

    html_doc.css("div.box").map do |node|
      title = node.css("div.boxTitle").text.strip
      content = {}
      node.css("div.tabContent li").map do |node|
        key, value = node.text.split(":",2).map { |t| t.gsub(/\s+/," ") }.map(&:strip)
        content[key] = value
      end

      if content == {}
        content = node.css("div.tabContent").text
      end

      info_from_div_boxes[title] = content
    end

    doc.title = info_from_div_boxes["Title and reference"].gsub(/\s+/," ").strip
    doc.author = info_from_div_boxes["Miscellaneous information"]["Author"]
    doc.dircodes = (SPLIT_DIRCODES.match(info_from_div_boxes["Classifications"]["Directory code"]) || []).to_a
    doc.form = info_from_div_boxes["Miscellaneous information"]["Form"]

    text = (info_from_div_boxes["Text"] ||"").gsub(/\s+/," ")
    doc.has_text = text != ""
    text_sentences = text.split(".")

    found_sentences = text_sentences.select { |text| FIND_COMITTEE.match(text) && FIND_OPINION.match(text) }
    doc.sentences = found_sentences.map(&:strip).uniq

    doc
  end
end
