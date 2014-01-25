# Description

Enables following a series of redirects (shortened urls)

# Prerequisites

Tested on Ruby 1.9.3 & 2.0 (likely still works on 1.8.7, but you are on your own.)

# Example Code
  
	require 'unwind'
	
	follower = Unwind::RedirectFollower.new('http://j.mp/xZVND1')
	follower.resolve
	assert_equal 'http://ow.ly/i/s1O0', follower.final_url 
	assert_equal 'http://j.mp/xZVND1', follower.original_url
	assert_equal 2, follower.redirects.count
	
# Hat tip

Most of the code is based on John Nunemaker's blog post [Following Redirects with Net/HTTP](http://railstips.org/blog/archives/2009/03/04/following-redirects-with-nethttp/).

# License 

Provided under the Do Whatever You Want With This Code License.
