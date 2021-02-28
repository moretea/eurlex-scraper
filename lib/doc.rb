class PotentialDoc < Struct.new(:year, :letter, :number, :retry_at, :attempts)
  def self.from_celex_id(src)
    year = src[1..4].to_i.to_i
    letter = src[5]
    number = src[6..-1].to_i

    PotentialDoc.new(year, letter, number, nil, nil)
  end

  def uri
    "CELEX:" + celex_id
  end

  def celex_id
    "5%d%s%04d" % [year, letter, number]
  end

  def cache_key
    parts = ([letter] + number.to_s.chars).each_slice(3).map(&:join) + [year.to_s]
    parts.reduce { |a,b| File.join(a,b) }
  end
end

class Document < Struct.new(:year, :letter, :number, :title, :has_text, :sentences, :dircodes, :form, :author)
  def celex_id
    "5%d%s%04d" % [year, letter, number]
  end

  def as_csv_line
    raise "THERE ARE MORE THAN 3 DIRCODES!" if dircodes.length > 3

    dircode_1 =  dircodes[0] || "NA"
    dircode_2 =  dircodes[1] || "NA"
    dircode_3 =  dircodes[2] || "NA"

    sentence_1 =  sentences.shift || "NA"
    sentence_2 =  sentences.shift || "NA"
    sentence_3 =  sentences.shift || "NA"
    sentence_rest = sentences.join("@@@@@")

    parts = [celex_id, author, title, has_text, dircode_1, dircode_2, dircode_3, sentence_1, sentence_2, sentence_3, sentence_rest]
    parts.map { |part| '"' + part.to_s.gsub('"', "'") + '"' }.join(",")
  end
end
