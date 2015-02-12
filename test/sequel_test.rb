require File.expand_path('../test_helper', __FILE__)

class I18nBackendSequelBitemporalTest < Test::Unit::TestCase
  def clear_all
    I18n::Backend::SequelBitemporal::Translation.dataset.delete
  end

  def setup
    super
    I18n::Backend::SequelBitemporal::Translation.unstub(:available_locales)
    I18n.backend = I18n::Backend::SequelBitemporal.new
    store_translations(:en, :foo => { :bar => 'bar', :baz => 'baz' })
  end

  def teardown
    super
    clear_all
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

  test "expand keys" do
    assert_equal %w(foo foo.bar foo.bar.baz), I18n.backend.send(:expand_keys, :'foo.bar.baz')
  end

  test "allows to override the table names" do
    ::Sequel::Model.db.transaction :rollback => :always do
      begin
        ::Sequel.migration do
          change do
            create_table :another_i18n_translations do
              primary_key :id
              String :locale, :null => false
              String :key, :null => false
              index [:locale, :key], :unique => true
            end

            create_table :another_i18n_translation_versions do
              primary_key :id
              foreign_key :master_id, :another_i18n_translations, :on_delete => :cascade
              Time        :created_at
              Time        :expired_at
              Date        :valid_from
              Date        :valid_to
              String :value, :text => true
              String :interpolations, :text => true
              TrueClass :is_proc, :null => false, :default => false
            end
          end
        end.apply(::Sequel::Model.db, :up)
        change_table_names(
          :another_i18n_translations,
          :another_i18n_translation_versions
        )

        assert_equal(
          ::I18n::Backend::SequelBitemporal::Translation.table_name,
          :another_i18n_translations
        )
        assert_equal(
          ::I18n::Backend::SequelBitemporal::TranslationVersion.table_name,
          :another_i18n_translation_versions
        )
      ensure
        change_table_names nil, nil
      end
    end
  end

  def change_table_names(master_name, version_name)
    ::I18n::Backend::SequelBitemporal.master_table_name = master_name
    ::I18n::Backend::SequelBitemporal.version_table_name = version_name
    ::I18n::Backend::SequelBitemporal.send :remove_const, :Translation
    ::I18n::Backend::SequelBitemporal.send :remove_const, :TranslationVersion
    load File.expand_path(
      "../../lib/i18n/backend/sequel_bitemporal/translation.rb",
      __FILE__
    )
  end

end if defined?(Sequel)
