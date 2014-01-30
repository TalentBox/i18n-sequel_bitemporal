# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "i18n/sequel_bitemporal/version"

Gem::Specification.new do |s|
  s.name        = "i18n-sequel_bitemporal"
  s.version     = I18n::SequelBitemporal::VERSION
  s.authors     = ["Jonathan Tron"]
  s.email       = ["jonathan.tron@thetalentbox.com"]
  s.homepage    = "http://github.com/TalentBox/i18n-sequel_bitemporal"
  s.summary      = "I18n Bitemporal Sequel backend"
  s.description  = "I18n Bitemporal Sequel backend. Allows to store translations in a database using Sequel using a bitemporal approach, e.g. for providing a web-interface for managing translations."
  s.rubyforge_project = "[none]"

  s.platform     = Gem::Platform::RUBY

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency "i18n", ">= 0.5", "< 0.7.0"
  s.add_dependency "sequel_bitemporal", "~> 0.7.0"

  s.add_development_dependency "test_declarative"
  s.add_development_dependency "mocha"
  s.add_development_dependency "rake"
  s.add_development_dependency "timecop"
end
