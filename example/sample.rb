require './lib/unwind'

follower = Unwind::RedirectFollower.new('http://j.mp/xZVND1')
follower.resolve
follower.redirects.each {|url| puts "redirects to #{url}"}
puts follower.original_url
puts follower.final_url


