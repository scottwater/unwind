require "unwind/version"
require 'faraday'
require 'addressable/uri'

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

    def resolve(current_url=nil, options={})

      ok_to_continue?

      current_url ||= self.original_url
      #adding this header because we really only care about resolving the url
      headers = (options || {}).merge({"accept-encoding" => "none"})
      response = Faraday.get(current_url, {}, headers)

      if is_response_redirect?(response)
        handle_redirect(redirect_url(response), current_url, response, headers)
      elsif meta_uri = meta_refresh?(current_url, response)
        handle_redirect(meta_uri, current_url, response, headers)
      else
        handle_final_response(current_url, response)
      end

      self
    end

    def self.resolve(original_url, limit=5)
      new(original_url, limit).resolve
    end

  private

    def record_redirect(url)
      @redirects << url.to_s
      @redirect_limit -= 1
    end

    def is_response_redirect?(response)
      [301, 302, 303].include?(response.status)
    end

    def handle_redirect(uri_to_redirect, url, response, headers)
      record_redirect url
      resolve(uri_to_redirect.normalize, apply_cookie(response, headers))
    end

    def handle_final_response(current_url, response)
      current_url = current_url.dup.to_s
      if response.status == 200 && canonical = canonical_link?(response)
        @redirects << current_url
        if Addressable::URI.parse(canonical).relative?
          @final_url = make_url_absolute(current_url, Addressable::URI.parse(canonical)).to_s
        else
          @final_url = canonical
        end

      else
        @final_url = current_url
      end
      @response = response
    end

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
        redirect_uri.relative? ? Addressable::URI.parse(response.env[:url]).join(response['location']) : redirect_uri
      end
    end
    
    def meta_refresh?(current_url, response)
      if response.status == 200
        body_match = response.body.match(/<meta http-equiv=\"refresh\" content=\"0; URL=(.*?)\"\s*\/*>/i)
        if body_match
          uri = Addressable::URI.parse(body_match[1])
          make_url_absolute(current_url, uri)
        end
      end
    end

    def canonical_link?(response)
      body_match = response.body.match(/<link rel=[\'\"]canonical[\'\"] href=[\'\"](.*?)[\'\"]/i)
      body_match ? Addressable::URI.parse(body_match[1]).to_s : false
    end
    
    def apply_cookie(response, headers)
      if response.status == 302 && response['set-cookie']
        headers.merge(:cookie => CookieHash.to_cookie_string(response['set-cookie']))
      else 
        #todo: should we delete the cookie at this point if it exists?
        headers
      end
    end

    def make_url_absolute(current_url, relative_url)
      current_uri = Addressable::URI.parse(current_url)
      if (relative_url.relative?)
        url = Addressable::URI.new(
          :scheme => current_uri.scheme,
          :user => current_uri.user,
          :password => current_uri.password,
          :host => current_uri.host,
          :port => current_uri.port,
          :path => relative_url.path,
          :query => relative_url.query,
          :fragment => relative_url.fragment)
      else
        relative_url
      end
    end

  end

  #borrowed (stolen) from HTTParty with minor updates
  #to handle all cookies existing in a single string
  class CookieHash < Hash
    
    CLIENT_COOKIES = %w{path expires domain path secure httponly}
    
    def add_cookies(value)
      case value
      when Hash
        merge!(value)
      when String
        value = value.gsub(/expires=[\w,\s\-\:]+;/i, '')
        value = value.gsub(/httponly[\,\;]*/i, '')
        value.split(/[;,]\s/).each do |cookie|
          array = cookie.split('=')
          self[array[0].strip.to_sym] = array[1]
        end
      else
        raise "add_cookies only takes a Hash or a String"
      end
    end

    def to_cookie_string
      delete_if { |k, v| CLIENT_COOKIES.include?(k.to_s.downcase) }.collect { |k, v| "#{k}=#{v}" }.join("; ")
    end

    def self.to_cookie_string(*cookie_strings)
      h = CookieHash.new
      cookie_strings.each do |cs|
        h.add_cookies(cs)
      end

      h.to_cookie_string
    end
  end


end
