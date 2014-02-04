require File.expand_path('../test_helper', __FILE__)

class I18nBackendSequelBitemporalCacheTest < Test::Unit::TestCase
  def clear_all
    I18n::Backend::SequelBitemporal::Translation.dataset.delete
  end

  def setup
    super
    I18n::Backend::SequelBitemporal::Translation.unstub(:all_for_locale)
    I18n.backend = I18n::Backend::SequelBitemporal.new :preload_all => true
    store_translations(:en, :foo => { :bar => 'bar', :baz => 'baz' })
    store_translations(:fr, :foo => { :bar => 'bar', :baz => 'baz' })
  end

  def teardown
    super
    clear_all
  end

  with_mocha do
    test "cache all translation for current locales" do
      translations_en = I18n::Backend::SequelBitemporal::Translation.locale(:en).lookup('foo').all
      translations_fr = I18n::Backend::SequelBitemporal::Translation.locale(:fr).lookup('foo').all
      I18n::Backend::SequelBitemporal::Translation.expects(:all_for_locale).
        with(:en).
        returns(translations_en)
      I18n.t(:foo)
      I18n.t(:foo)

      I18n::Backend::SequelBitemporal::Translation.expects(:all_for_locale).
        with(:fr).
        returns(translations_fr)
      I18n.with_locale :fr do
        I18n.t(:foo)
        I18n.t(:foo)
      end
    end

    test "clear all locales" do
      translations_en = translations_for :en
      translations_fr = translations_for :fr

      I18n.t(:foo)
      I18n.with_locale(:fr) { I18n.t(:foo) }

      I18n.backend.clear

      I18n::Backend::SequelBitemporal::Translation.expects(:all_for_locale).
        with(:en).
        returns(translations_en)
      I18n.t(:foo) # load from db

      I18n.with_locale :fr do
        I18n::Backend::SequelBitemporal::Translation.expects(:all_for_locale).
          with(:fr).
          returns(translations_fr)
        I18n.t(:foo) # load from db
      end
    end

    test "clear specified locale only" do
      translations_en = translations_for :en
      translations_fr = translations_for :fr

      I18n::Backend::SequelBitemporal::Translation.expects(:all_for_locale).
        with(:en).returns(translations_en)
      I18n::Backend::SequelBitemporal::Translation.expects(:all_for_locale).
        with(:fr).returns(translations_fr)
      I18n.t(:foo)
      I18n.with_locale(:fr) { I18n.t(:foo) }

      I18n.backend.clear :en
      I18n::Backend::SequelBitemporal::Translation.expects(:all_for_locale).
        with(:en).returns(translations_en)
      I18n.t(:foo)
      I18n.with_locale(:fr) { I18n.t(:foo) }
    end

    test "clear all locales with stale cache" do
      translations_en = translations_for :en
      translations_fr = translations_for :fr

      last_update = Time.now
      en_cache_time = last_update-60
      fr_cache_time = last_update-10

      I18n::Backend::SequelBitemporal::Translation.expects(:all_for_locale).
        with(:en).returns(translations_en)
      I18n::Backend::SequelBitemporal::Translation.expects(:all_for_locale).
        with(:fr).returns(translations_fr)

      Timecop.freeze(en_cache_time){ I18n.t(:foo) }
      Timecop.freeze(fr_cache_time) do
        I18n.with_locale(:fr) { I18n.t(:foo) }
      end

      I18n.backend.clear :all, :last_update => last_update-65
      I18n.t(:foo)
      I18n.with_locale(:fr) { I18n.t(:foo) }

      I18n.backend.clear :all, :last_update => last_update-15
      I18n::Backend::SequelBitemporal::Translation.expects(:all_for_locale).
        with(:en).returns(translations_en)
      I18n.t(:foo)
      I18n.with_locale(:fr) { I18n.t(:foo) }
    end

    test "clear specific locale with stale cache" do
      translations_en = translations_for :en
      translations_fr = translations_for :fr

      last_update = Time.now
      en_cache_time = last_update-60
      fr_cache_time = last_update-10

      I18n::Backend::SequelBitemporal::Translation.expects(:all_for_locale).
        with(:en).returns(translations_en)
      I18n::Backend::SequelBitemporal::Translation.expects(:all_for_locale).
        with(:fr).returns(translations_fr)

      Timecop.freeze(en_cache_time){ I18n.t(:foo) }
      Timecop.freeze(fr_cache_time) do
        I18n.with_locale(:fr) { I18n.t(:foo) }
      end

      I18n.backend.clear :fr, :last_update => last_update-65
      I18n.t(:foo)
      I18n.with_locale(:fr) { I18n.t(:foo) }

      I18n.backend.clear :fr, :last_update => last_update
      I18n::Backend::SequelBitemporal::Translation.expects(:all_for_locale).
        with(:fr).returns(translations_en)
      I18n.t(:foo)
      I18n.with_locale(:fr) { I18n.t(:foo) }
    end
  end

  def translations_for(locale)
    I18n::Backend::SequelBitemporal::Translation.locale(:locale).all
  end

end if defined?(Sequel)
