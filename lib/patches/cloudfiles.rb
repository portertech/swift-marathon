require "net/http"
require "net/https"

class SwiftClient
  def self.http_connection(url, proxy_host=nil, proxy_port=nil)
    parsed = URI::parse(url)
    unless parsed.scheme =~ /^https?$/
      raise ClientException.new("Cannot handle protocol scheme #{parsed.scheme} for #{url} %s")
    end
    conn = Net::HTTP::Proxy(proxy_host, proxy_port).new(parsed.host, parsed.port)
    conn.read_timeout = 1200
    if parsed.scheme == "https"
      conn.use_ssl = true
      conn.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end
    [parsed, conn]
  end
end
