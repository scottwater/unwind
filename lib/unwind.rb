require "unwind/version"
require 'faraday'

module Unwind

  class TooManyRedirects < StandardError; end
  class MissingRedirectLocation < StandardError; end

  class RedirectFollower

    attr_reader :final_url,  :original_url, :redirect_limit, :response, :redirects

    def initialize(original_url, limit=5)
     @original_url, @redirect_limit = original_url, limit
     @redirects = []
     
    end

    def redirected? 
      !(self.final_url == self.original_url)
    end

    def resolve(current_url=nil)

      ok_to_continue?

      current_url ||= self.original_url
      response = Faraday.get(current_url, "accept-encoding" => "none")

      if [301, 302, 307].include?(response.status)
        @redirects << current_url.to_s
        @redirect_limit -= 1
        resolve redirect_url(response).normalize
      else
        @final_url = current_url.to_s
        @response = response
        self
      end
    end


    def self.resolve(original_url, limit=5)
      new(original_url, limit).resolve
    end

  private

    def ok_to_continue?
      raise TooManyRedirects if redirect_limit < 0
    end

    def redirect_url(response)
      if response['location'].nil?
        body_match = response.body.match(/<a href=\"([^>]+)\">/i)
        raise MissingRedirectLocation unless body_match
        Addressable::URI.parse(body_match[0])
      else
        redirect_uri = Addressable::URI.parse(response['location'])
        redirect_uri.relative? ? response.env[:url].join(response['location']) : redirect_uri
      end
    end
    

  end

end
