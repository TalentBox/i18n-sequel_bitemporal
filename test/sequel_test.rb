require File.expand_path('../test_helper', __FILE__)

class I18nBackendSequelBitemporalTest < Test::Unit::TestCase
  def clear_all
    I18n::Backend::SequelBitemporal::Translation.delete
  end

  def setup
    I18n.backend = I18n::Backend::SequelBitemporal.new
    store_translations(:en, :foo => { :bar => 'bar', :baz => 'baz' })
  end

  def teardown
    clear_all
    super
  end
  
  test "store_translations does not allow ambiguous keys (1)" do
    clear_all
    I18n.backend.store_translations(:en, :foo => 'foo')
    I18n.backend.store_translations(:en, :foo => { :bar => 'bar' })
    I18n.backend.store_translations(:en, :foo => { :baz => 'baz' })

    translations = I18n::Backend::SequelBitemporal::Translation.locale(:en).lookup('foo').all
    assert_equal %w(bar baz), translations.map(&:value)

    assert_equal({ :bar => 'bar', :baz => 'baz' }, I18n.t(:foo))
  end

  test "store_translations does not allow ambiguous keys (2)" do
    clear_all
    I18n.backend.store_translations(:en, :foo => { :bar => 'bar' })
    I18n.backend.store_translations(:en, :foo => { :baz => 'baz' })
    I18n.backend.store_translations(:en, :foo => 'foo')

    translations = I18n::Backend::SequelBitemporal::Translation.locale(:en).lookup('foo').all
    assert_equal %w(foo), translations.map(&:value)

    assert_equal 'foo', I18n.t(:foo)
  end

  test "can store translations with keys that are translations containing special chars" do
    I18n.backend.store_translations(:es, :"Pagina's" => "Pagina's" )
    assert_equal "Pagina's", I18n.t(:"Pagina's", :locale => :es)
  end

  test "remove translations with nil as value" do
    I18n.backend.store_translations(:es, :"Pagina's" => nil )
    translations = I18n::Backend::SequelBitemporal::Translation.locale(:es).lookup("Pagina's").all
    assert_equal [], translations.map(&:value)
  end

  with_mocha do
    test "missing translations table does not cause an error in #available_locales" do
      I18n::Backend::SequelBitemporal::Translation.expects(:available_locales).raises(::Sequel::Error)
      assert_equal [], I18n.backend.available_locales
    end
  end

  def test_expand_keys
    assert_equal %w(foo foo.bar foo.bar.baz), I18n.backend.send(:expand_keys, :'foo.bar.baz')
  end
end if defined?(Sequel)