lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'wikidata/people-searcher/version'

Gem::Specification.new do |spec|
  spec.name          = 'wikidata-people-searcher'
  spec.version       = Wikidata::PeopleSearcher::VERSION
  spec.authors       = ['Jez Nicholson']
  spec.email         = ['jez.nicholson@gmail.com']
  spec.summary       = 'Quick and easy search for famous people on Wikidata'
  spec.description   = 'A search using name and dates for a famous person to give a single, accurate result'
  spec.homepage      = 'http://github.com/jnicho02/wikidata-people-searcher'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_runtime_dependency     'open-uri'
  spec.add_runtime_dependency     'ostruct'
  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake', '>= 12.3.3'
  spec.add_development_dependency 'rspec'
end
