require 'minitest/autorun'
require 'vcr'
require './lib/unwind'

VCR.config do |c|
	c.stub_with :fakeweb
	c.cassette_library_dir = 'vcr_cassettes' 
end

describe 'Tests :)' do 

	it 'should resolve the url' do 
		VCR.use_cassette('xZVND1') do 
			follower = Unwind::RedirectFollower.new('http://j.mp/xZVND1')
			follower.resolve
			assert_equal 'http://ow.ly/i/s1O0', follower.final_url 
			assert_equal 'http://j.mp/xZVND1', follower.original_url
			assert_equal 2, follower.redirects.count
			assert follower.redirected?
		end
	end

	it 'should not be redirected' do 
		VCR.use_cassette('no redirect') do 
			follower  = Unwind::RedirectFollower.new('http://www.scottw.com').resolve
			assert !follower.redirected?
		end	
	end

	it 'should raise TooManyRedirects' do 
		VCR.use_cassette('xZVND1') do 
			follower = Unwind::RedirectFollower.new('http://j.mp/xZVND1', 1)
			too_many_redirects = lambda {follower.resolve}
			too_many_redirects.must_raise Unwind::TooManyRedirects
		end
	end

end
