require "unwind/version"
require 'addressable/uri'
require 'nokogiri'
require 'faraday'

module Unwind

  class TooManyRedirects < StandardError; end
  class MissingRedirectLocation < StandardError; end
  class TimeoutError < StandardError; end

  class RedirectFollower

    attr_reader :final_url,  :original_url, :redirect_limit, :response, :redirects

    def initialize(original_url, limit=5)
     @original_url, @redirect_limit = original_url, limit
     @redirects = []
     
    end

    def redirected? 
      !(self.final_url == self.original_url)
    end

    def not_found?
      @response.status == 404
    end

    def resolve(current_url=nil, options={}, &block)

      ok_to_continue?

      current_url ||= self.original_url
      #adding this header because we really only care about resolving the url
      headers = (options || {}).merge({"accept-encoding" => "none"})

      begin
        response = Faraday.get(current_url, nil, headers)
        yield response if block_given?
      rescue Faraday::Error::TimeoutError => e
        raise Unwind::TimeoutError, $!
      end

      if is_response_redirect?(response)
        resolve(*handle_redirect(redirect_url(response), current_url, response, headers), &block)
      elsif meta_uri = meta_refresh?(response)
        resolve(*handle_redirect(meta_uri, current_url, response, headers), &block)
      else
        handle_final_response(current_url, response)
      end

      self
    end

    def self.resolve(original_url, limit=5, &block)
      new(original_url, limit).resolve(&block)
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
      return uri_to_redirect.normalize, apply_cookie(response, headers)
    end

    def handle_final_response(current_url, response)
      current_url = current_url.dup.to_s
      if response.status == 200 &&  canonical = canonical_link?(response)
        @redirects << current_url
        @final_url = canonical.to_s
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
        redirect_uri.relative? ? Addressable::URI.join(response.env[:url].to_s, response['location']) : redirect_uri
      end
    end
    
    def meta_refresh?(response)
      if response.status == 200
        body_match = response.body.match(/<meta http-equiv=\"refresh\" content=\"0; URL=(.*)\">/i)
        Addressable::URI.parse(body_match[1]) if body_match
      end
    end

    def canonical_link?(response)
      doc = Nokogiri::HTML(response.body)

      if canonical = doc.at('link[rel=canonical]')
        href = Addressable::URI.parse(canonical["href"])
        return unless href
        return Addressable::URI.join(response.env[:url].to_s, href) if href.relative?
        return href
      end

      false
    end

    def apply_cookie(response, headers)
      if headers[:cookie] || response['set-cookie']
        cookies = CookieHash.new

        cookies.add_cookies(headers[:cookie]) if headers[:cookie]
        cookies.add_cookies(response['set-cookie']) if response['set-cookie']

        headers.merge(:cookie => cookies.to_cookie_string)
      else
        #todo: should we delete the cookie at this point if it exists?
        headers
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
