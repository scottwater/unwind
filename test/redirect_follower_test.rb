require 'minitest/autorun'
require 'fakeweb'
require 'vcr'
require './lib/unwind'

VCR.configure do |c|
  c.hook_into :fakeweb
  c.cassette_library_dir = 'vcr_cassettes'
  c.allow_http_connections_when_no_cassette = true
end

describe Unwind::RedirectFollower do 

  # needs to be regenerated to properly test...need to stop that :(
  it 'should handle url with cookie requirement' do 
    VCR.use_cassette('with cookie') do 
      follower = Unwind::RedirectFollower.resolve('http://ow.ly/1hf37P')
      assert_equal 200,  follower.response.status 
      assert follower.redirected?
    end
  end

  it 'should resolve the url' do 
    VCR.use_cassette('xZVND1') do 
      follower = Unwind::RedirectFollower.resolve('http://j.mp/xZVND1')
      assert_equal 'http://ow.ly/i/s1O0', follower.final_url 
      assert_equal 'http://j.mp/xZVND1', follower.original_url
      assert_equal 2, follower.redirects.count
      assert follower.redirected?
    end
  end

  it 'should handle relative redirects' do 
    VCR.use_cassette('relative stackoverflow') do 
      follower = Unwind::RedirectFollower.resolve('http://stackoverflow.com/q/9277007/871617?stw=1')
      assert follower.redirected?
      assert_equal 'http://stackoverflow.com/questions/9277007/gitlabhq-w-denied-for-rails', follower.final_url
    end
  end

  it 'should still handine relative redirects' do 
    # http://bit.ly/A4H3a2
    VCR.use_cassette('relative stackoverflow 2') do 
      follower = Unwind::RedirectFollower.resolve('http://bit.ly/A4H3a2')
      assert follower.redirected?
    end
  end

  it 'should handle redirects to pdfs' do 
    VCR.use_cassette('pdf') do 
      follower = Unwind::RedirectFollower.resolve('http://binged.it/wVSFs5')
      assert follower.redirected? 
      assert_equal 'https://microsoft.promo.eprize.com/bingtwitter/public/fulfillment/rules.pdf', follower.final_url
    end
  end

  it 'should handle the lame amazon spaces' do 
    VCR.use_cassette('amazon') do 
      follower = Unwind::RedirectFollower.resolve('http://amzn.to/xrHQWS')
      assert follower.redirected? 
    end
  end

  #http://amzn.to/xrHQWS

  it 'should handle a https redirect' do 
    VCR.use_cassette('ssl tpope') do 
      follower = Unwind::RedirectFollower.resolve('http://github.com/tpope/vim-rails')
      assert follower.redirected?
      assert_equal 'https://github.com/tpope/vim-rails', follower.final_url
    end
  end

  it 'should not be redirected' do 
    VCR.use_cassette('no redirect') do 
      follower  = Unwind::RedirectFollower.resolve('http://www.scottw.com')
      assert !follower.redirected?
    end 
  end

  it 'should set the final url as being the canonical url and treat it as s redirect' do 
    VCR.use_cassette('canonical url', :preserve_exact_body_bytes => true) do 
      follower  = Unwind::RedirectFollower.resolve('http://www.scottw.com?test=abc')
      assert  follower.redirected?
      assert 'http://www.scottw.com', follower.final_url
      assert 'http://www.scottw?test=abc', follower.redirects[0]
    end 
  end

  it 'should raise TooManyRedirects' do 
    VCR.use_cassette('xZVND1') do 
      follower = Unwind::RedirectFollower.new('http://j.mp/xZVND1', 1)
      too_many_redirects = lambda {follower.resolve}
      too_many_redirects.must_raise Unwind::TooManyRedirects
    end
  end

  it 'should raise MissingRedirectLocation' do 
    VCR.use_cassette('missing redirect') do 
      follower = Unwind::RedirectFollower.new('http://tinyurl.com/6oqzkff')
      missing_redirect_location = lambda{follower.resolve}
      missing_redirect_location.must_raise Unwind::MissingRedirectLocation
    end
  end
  
  it 'should handle a meta-refresh' do
    VCR.use_cassette('meta refresh') do
      follower = Unwind::RedirectFollower.resolve('http://www.nullrefer.com/?www.google.com')
      assert follower.redirected?
      assert_equal 'http://www.google.com/', follower.final_url
    end
  end

  describe 'handling 404s' do
    it "should set not_found?" do
      FakeWeb.register_uri :get, 'http://nope.com', status: 404
      follower = Unwind::RedirectFollower.resolve('http://nope.com/')
      assert follower.not_found?
    end
  end

  describe 'preserving cookies' do
    it "should preserve cookies to redirected domains" do
      FakeWeb.register_uri :get, 'http://foo.com', status: 302,
        "set-cookies" => "sid=3EBE6B02-E226-017F-541D-B1D03209F38B; Path=/; Domain=.foo.com",
        "location" => "http://bar.com"

      FakeWeb.register_uri :get, 'http://bar.com', status: 302,
        "location" => "http://foo.com/content"

      FakeWeb.register_uri :get, 'http://foo.com/content', status: 200

      follower = Unwind::RedirectFollower.resolve('http://foo.com/')

      assert !FakeWeb.last_request["cookie"].nil?
    end
  end

end
