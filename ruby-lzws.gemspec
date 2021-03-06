# Ruby bindings for lzws library.
# Copyright (c) 2019 AUTHORS, MIT License.

require "date"

require_relative "lib/lzws/version"

GEMSPEC = Gem::Specification.new do |gem|
  gem.name     = "ruby-lzws"
  gem.summary  = "Ruby bindings for lzws library."
  gem.homepage = "https://github.com/andrew-aladev/ruby-lzws"
  gem.license  = "MIT"
  gem.authors  = File.read("AUTHORS").split("\n").reject(&:empty?)
  gem.email    = "aladjev.andrew@gmail.com"
  gem.version  = LZWS::VERSION
  gem.date     = Date.today.to_s

  gem.add_development_dependency "codecov"
  gem.add_development_dependency "minitar", "~> 0.9"
  gem.add_development_dependency "minitest", "~> 5.12"
  gem.add_development_dependency "ocg", "~> 1.1"
  gem.add_development_dependency "rake"
  gem.add_development_dependency "rake-compiler"
  gem.add_development_dependency "rubocop", "~> 0.75"
  gem.add_development_dependency "rubocop-performance", "~> 1.5"
  gem.add_development_dependency "rubocop-rails", "~> 2.3"
  gem.add_development_dependency "simplecov"

  gem.files =
    `git ls-files -z --directory {ext,lib}`.split("\x0") +
    %w[AUTHORS LICENSE README.md]
  gem.require_paths = %w[lib]
  gem.extensions    = %w[ext/extconf.rb]
end
