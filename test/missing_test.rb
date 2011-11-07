require File.expand_path('../test_helper', __FILE__)

class I18nSequelBitemporalMissingTest < Test::Unit::TestCase
  class Backend < I18n::Backend::SequelBitemporal
    include I18n::Backend::SequelBitemporal::Missing
  end

  def setup
    I18n.backend.store_translations(:en, :bar => 'Bar', :i18n => { :plural => { :keys => [:zero, :one, :other] } })
    I18n.backend = I18n::Backend::Chain.new(Backend.new, I18n.backend)
    I18n::Backend::SequelBitemporal::Translation.delete
  end

  test "can persist interpolations" do
    translation = I18n::Backend::SequelBitemporal::Translation.new(:key => 'foo', :locale => :en)
    translation.attributes = {:value => 'bar', :interpolations => %w(count name)} 
    translation.save
    assert translation.valid?
  end

  test "lookup persists the key" do
    I18n.t('foo.bar.baz')
    assert_equal 1, I18n::Backend::SequelBitemporal::Translation.count
    assert I18n::Backend::SequelBitemporal::Translation.locale(:en).filter(:key => 'foo.bar.baz').first
  end

  test "lookup does not persist the key twice" do
    2.times { I18n.t('foo.bar.baz') }
    assert_equal 1, I18n::Backend::SequelBitemporal::Translation.count
    assert I18n::Backend::SequelBitemporal::Translation.locale(:en).filter(:key => 'foo.bar.baz').first
  end

  test "lookup persists interpolation keys when looked up directly" do
    I18n.t('foo.bar.baz', :cow => "lucy" )  # creates stub translation.
    translation_stub = I18n::Backend::SequelBitemporal::Translation.locale(:en).lookup('foo.bar.baz').all.first
    assert translation_stub.interpolates?(:cow)
  end

  test "creates one stub per pluralization" do
    I18n.t('foo', :count => 999)
    translations = I18n::Backend::SequelBitemporal::Translation.locale(:en).filter(:key => %w{ foo.zero foo.one foo.other }).all
    assert_equal 3, translations.length
  end

  test "creates no stub for base key in pluralization" do
    I18n.t('foo', :count => 999)
    assert_equal 3, I18n::Backend::SequelBitemporal::Translation.locale(:en).lookup("foo").count
    assert !I18n::Backend::SequelBitemporal::Translation.locale(:en).filter(:key => "foo").first
  end

  test "creates a stub when a custom separator is used" do
    I18n.t('foo|baz', :separator => '|')
    I18n::Backend::SequelBitemporal::Translation.locale(:en).lookup("foo.baz").all.first.update_attributes(:value => 'baz!')
    assert_equal 'baz!', I18n.t('foo|baz', :separator => '|')
  end

  test "creates a stub per pluralization when a custom separator is used" do
    I18n.t('foo|bar', :count => 999, :separator => '|')
    translations = I18n::Backend::SequelBitemporal::Translation.locale(:en).filter(:key => %w{ foo.bar.zero foo.bar.one foo.bar.other }).all
    assert_equal 3, translations.length
  end

  test "creates a stub when a custom separator is used and the key contains the flatten separator (a dot character)" do
    key = 'foo|baz.zab'
    I18n.t(key, :separator => '|')
    I18n::Backend::SequelBitemporal::Translation.locale(:en).lookup("foo.baz\001zab").all.first.update_attributes(:value => 'baz!')
    assert_equal 'baz!', I18n.t(key, :separator => '|')
  end

end if defined?(Sequel)

