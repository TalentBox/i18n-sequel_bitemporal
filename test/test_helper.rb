$:.unshift File.expand_path(".", File.dirname(__FILE__))

require 'test_setup'

I18n::Tests.parse_options!
require 'bundler/setup'
$:.unshift File.expand_path("../lib", File.dirname(__FILE__))
require 'i18n/sequel_bitemporal'
require 'i18n/tests'
require 'mocha/test_unit'
require 'test_declarative'
require 'timecop'
I18n::Tests.setup_sequel

Sequel::Deprecation.output = false

class I18nBitemporalTest < Test::Unit::TestCase
  def self.with_mocha
    yield if Object.respond_to?(:expects)
  end

  def setup
    super
    I18n.enforce_available_locales = false
  end

  def teardown
    I18n.locale = nil
    I18n.default_locale = nil
    I18n.load_path = nil
    I18n.available_locales = nil
    I18n.backend = nil
    I18n.default_separator = nil
    I18n.enforce_available_locales = true
    super
  end

  def translations
    I18n.backend.instance_variable_get(:@translations)
  end

  def store_translations(*args)
    data   = args.pop
    locale = args.pop || :en
    I18n.backend.store_translations(locale, data)
  end

  def locales_dir
    File.dirname(__FILE__) + '/test_data/locales'
  end
end

Object.class_eval do
  def meta_class
    class << self; self; end
  end
end unless Object.method_defined?(:meta_class)
