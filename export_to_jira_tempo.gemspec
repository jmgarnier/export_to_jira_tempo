$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
name = "export_to_jira_tempo"
require "#{name}/version"

Gem::Specification.new name, ExportToJiraTempo::VERSION do |gem|
  gem.summary = "bla"
  gem.authors = ["Jean-Michel Garnier"]
  gem.email = "jean-michel@21croissants.com"
  gem.homepage = "http://github.com/21croissants/#{name}"
  gem.files         = %w(README.md) + Dir.glob("lib/**/*.rb")	
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.license = "MIT"
end
