require "unwind/version"
require 'net/http'

module Unwind

	class TooManyRedirects < StandardError; end

	class RedirectFollower

		attr_reader :final_url,  :original_url, :redirect_limit, :response, :redirects

		def initialize(original_url, limit=5)
		 @original_url, @redirect_limit = original_url, limit
		 @redirects = []
		end

		def resolve(current_url=nil)

			ok_to_continue?

			current_url ||= self.original_url

			response = Net::HTTP.get_response(URI.parse(current_url))

			if response.kind_of?(Net::HTTPRedirection)
				@redirects << current_url
				@redirect_limit -= 1
				resolve(redirect_url(response))
			else
				@final_url = current_url
				@response = response
				self
			end
		end

	private

		def ok_to_continue?
			raise TooManyRedirects if redirect_limit < 0
		end

		def redirect_url(response)
			if response['location'].nil?
				response.body.match(/<a href=\"([^>]+)\">/i)[1]
			else
				response['location']
			end
		end
		

	end

end
