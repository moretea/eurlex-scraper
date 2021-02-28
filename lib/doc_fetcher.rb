module DocFetcher
  DOC_BASE_URI = URI.parse(BASE_URL)

  def self.fetch(potential_doc)
    request_uri = DOC_BASE_URI.request_uri + potential_doc.uri
    http = Net::HTTP.new(DOC_BASE_URI.host, 443)
    http.use_ssl = true
    request = Net::HTTP::Get.new(request_uri)
    response = http.request(request)
    html = response.body.force_encoding("UTF-8")

    case response.code
      when "404" then [:not_found, nil]
      when "200" then [:found, html]
      when "301" then raise ({ tried: request_uri, got: response["location"] }).inspect
      else raise [:unexpected_code, response.code, response].inspect
    end
  end
end
