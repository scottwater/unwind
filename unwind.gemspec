# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "unwind/version"

Gem::Specification.new do |s|
  s.name        = "unwind"
  s.version     = Unwind::VERSION
  s.authors     = ["Scott Watermasysk"]
  s.email       = ["scottwater@gmail.com"]
  s.homepage    = "http://www.scottw.com/unwind"
  s.summary     = %q{Follows a chain redirects.}
  s.description = <<-description
										Follows a chain of redirects and reports back on all the steps.
										Heavily inspired by John Nunemaker's blog post.
										http://railstips.org/blog/archives/2009/03/04/following-redirects-with-nethttp/
									description

  s.rubyforge_project = "unwind"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  s.add_development_dependency "rake"
  s.add_development_dependency "minitest"
  s.add_development_dependency "vcr", "~> 2.0.0"
  s.add_development_dependency "fakeweb"
  s.add_runtime_dependency "faraday", '~> 0.9.0'
  s.add_runtime_dependency "nokogiri"
  s.add_runtime_dependency "addressable", "~> 2.3.6"
end
