module DocFetcher
  DOC_BASE_URI = URI.parse(BASE_URL)

  def self.fetch(potential_doc)
    request_uri = DOC_BASE_URI.request_uri + potential_doc.uri
    http = Net::HTTP.new(DOC_BASE_URI.host, DOC_BASE_URI.port)
    request = Net::HTTP::Get.new(request_uri)
    response = http.request(request)
    html = response.body.force_encoding("UTF-8")

    case response.code
      when "404" then [:not_found, nil]
      when "200" then [:found, html]
    end
  end
end
