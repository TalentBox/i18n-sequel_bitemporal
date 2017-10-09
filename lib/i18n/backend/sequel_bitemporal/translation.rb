require "sequel"
require "forwardable"

module I18n
  module Backend
    # Sequel model used to store actual translations to the database.
    #
    # This model expects two tables like the following to be already set up in
    # your the database:
    #
    # create_table :i18n_translations do
    #   primary_key :id
    #   String :locale, :null => false
    #   String :key, :null => false
    #   index [:locale, :key], :unique => true
    # end
    #
    # create_table :i18n_translation_versions do
    #   primary_key :id
    #   foreign_key :master_id, :i18n_translations, :on_delete => :cascade
    #   Time        :created_at
    #   Time        :expired_at
    #   Date        :valid_from
    #   Date        :valid_to
    #   String :value, :text => true
    #   String :interpolations, :text => true
    #   TrueClass :is_proc, :null => false, :default => false
    # end
    #
    # This model supports two named scopes :locale and :lookup. The :locale
    # scope simply adds a condition for a given locale:
    #
    #   I18n::Backend::SequelBitemporal::Translation.locale(:en).all
    #   # => all translation records that belong to the :en locale
    #
    # The :lookup scope adds a condition for looking up all translations
    # that either start with the given keys (joined by an optionally given
    # separator or I18n.default_separator) or that exactly have this key.
    #
    #   # with translations present for :"foo.bar" and :"foo.baz"
    #   I18n::Backend::SequelBitemporal::Translation.lookup(:foo)
    #   # => an array with both translation records :"foo.bar" and :"foo.baz"
    #
    #   I18n::Backend::SequelBitemporal::Translation.lookup([:foo, :bar])
    #   I18n::Backend::SequelBitemporal::Translation.lookup(:"foo.bar")
    #   # => an array with the translation record :"foo.bar"
    #
    # When the StoreProcs module was mixed into this model then Procs will
    # be stored to the database as Ruby code and evaluated when :value is
    # called.
    #
    #   Translation = I18n::Backend::SequelBitemporal::Translation
    #   Translation.create \
    #     :locale => 'en'
    #     :key    => 'foo'
    #     :value  => lambda { |key, options| 'FOO' }
    #   Translation.find_by_locale_and_key('en', 'foo').value
    #   # => 'FOO'
    class SequelBitemporal
      class TranslationVersion < ::Sequel::Model(::I18n::Backend::SequelBitemporal.version_table_name)
        plugin :serialization

        TRUTHY_CHAR = "\001"
        FALSY_CHAR = "\002"

        # set_restricted_columns :is_proc, :interpolations
        serialize_attributes :marshal, :value
        serialize_attributes :marshal, :interpolations

        # Sequel do not support default value for serialize_attributes
        def interpolations
          super || []
        end

        def interpolates?(key)
          self.interpolations.include?(key) if self.interpolations
        end

        def value
          value = super
          if is_proc
            Kernel.eval(value)
          elsif value == FALSY_CHAR
            false
          elsif value == TRUTHY_CHAR
            true
          else
            value
          end
        end

        def value=(value)
          if value === false
            value = FALSY_CHAR
          elsif value === true
            value = TRUTHY_CHAR
          end

          super(value)
        end
      end

      class Translation < ::Sequel::Model(::I18n::Backend::SequelBitemporal.master_table_name)
        extend Forwardable
        plugin :bitemporal, version_class: TranslationVersion

        delegate [:value, :interpolations, :interpolates?] => :pending_or_current_version

        def_dataset_method :locale do |locale|
          filter(:locale => locale.to_s)
        end

        def_dataset_method :lookup do |keys, *separator|
          lookup_and_current true, keys, *separator
        end

        def_dataset_method :lookup_any do |keys|
          lookup_and_current false, keys
        end

        def_dataset_method :lookup_exactly do |keys|
          keys = Array(keys).map! { |key| key.to_s }
          eager_graph(:current_version).filter(:key => keys.last)
        end

        def_dataset_method :lookup_and_current do |with_current, keys, *separator|
          keys = Array(keys).map! { |key| key.to_s }

          unless separator.empty?
            warn "[DEPRECATION] Giving a separator to Translation.lookup is deprecated. " <<
              "You can change the internal separator by overwriting FLATTEN_SEPARATOR."
          end

          namespace = "#{keys.last}#{I18n::Backend::Flatten::FLATTEN_SEPARATOR}%"
          set = eager_graph(:current_version).where(Sequel.|({:key => keys}, Sequel.like(:key, namespace)))
          set = set.exclude({Sequel.qualify(:translation_current_version, :id) => nil}) if with_current
          set
        end

        class << self
          def available_locales
            Translation.distinct.select(:locale).map { |t| t.locale.to_sym }
          end

          def all_for_locale(locale)
            self.locale(locale).with_current_version.all
          end
        end
      end
    end
  end
end
