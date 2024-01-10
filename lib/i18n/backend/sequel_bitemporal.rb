require 'i18n/backend/base'
require 'active_support/core_ext/hash/keys'

module I18n
  module Backend
    class SequelBitemporal
      autoload :Missing,     'i18n/backend/sequel_bitemporal/missing'
      autoload :StoreProcs,  'i18n/backend/sequel_bitemporal/store_procs'
      autoload :Translation, 'i18n/backend/sequel_bitemporal/translation'

      def self.master_table_name=(table_name)
        @master_table_name = table_name
      end

      def self.master_table_name
        @master_table_name || :i18n_translations
      end

      def self.version_table_name=(table_name)
        @version_table_name = table_name
      end

      def self.version_table_name
        @version_table_name || :i18n_translation_versions
      end

      module Implementation
        using I18n::HashRefinements if defined?(I18n::HashRefinements)
        include Base, Flatten

        def initialize(opts= {})
          @preload_all = opts.fetch(:preload_all, false)
          @translations = {}
          @cache_times = {}
        end

        def available_locales
          begin
            Translation.available_locales
          rescue ::Sequel::Error
            []
          end
        end

        def store_translations(locale, data, options = {})
          escape = options.fetch(:escape, true)
          point_in_time_for_new = options[:point_in_time_for_new]
          valid_from_for_new = options[:valid_from_for_new]
          flatten_translations(locale, data, escape, false).each do |key, value|
            # Invalidate all keys matching current one:
            # key = foo.bar invalidates foo, foo.bar and foo.bar.*
            Translation.locale(locale).lookup(expand_keys(key)).destroy

            unless value.nil?
              # Find existing master for locale/key or create a new one
              translation = Translation.locale(locale).lookup_exactly(expand_keys(key)).limit(1).all.first ||
                            Translation.new(:locale => locale.to_s, :key => key.to_s)
              translation.attributes = {:value => value}
              translation.attributes[:valid_from] = valid_from_for_new if translation.new?
              if point_in_time_for_new && translation.new?
                ::Sequel::Plugins::Bitemporal.as_we_knew_it point_in_time_for_new do
                  translation.save
                end
              else
                translation.save
              end
            end
          end
        end

        def clear(locale=:all, options={})
          if locale==:all
            @translations.keys.each{|loc| clear loc, options }
          else
            last_update = options[:last_update]
            cache_key = cache_key_of locale
            cache_time = @cache_times[cache_key]
            return if last_update && cache_time && last_update < cache_time
            @translations[cache_key] = nil
          end
        end

      protected

        def fetch_all_translations(locale)
          @translations ||= {}
          cache_key = cache_key_of locale
          @translations[cache_key] ||= begin
            @cache_times[cache_key] = Time.now
            Translation.all_for_locale(locale).group_by(&:key)
          end
          @translations[cache_key]
        end

        def lookup(locale, key, scope = [], options = {})
          key = normalize_flat_keys(locale, key, scope, options[:separator])
          result = if @preload_all
            fetch_all_translations(locale)[key] || []
          else
            Translation.locale(locale).lookup(key).all
          end

          if result.empty?
            nil
          elsif result.first.key == key
            result.first.value
          else
            chop_range = (key.size + FLATTEN_SEPARATOR.size)..-1
            result = result.inject({}) do |hash, r|
              hash[r.key.slice(chop_range)] = r.value
              hash
            end
            result.deep_symbolize_keys
          end
        end

        # For a key :'foo.bar.baz' return ['foo', 'foo.bar', 'foo.bar.baz']
        def expand_keys(key)
          key.to_s.split(FLATTEN_SEPARATOR).inject([]) do |keys, key|
            keys << [keys.last, key].compact.join(FLATTEN_SEPARATOR)
          end
        end

        def cache_key_of(locale)
          locale
        end
      end

      include Implementation
    end
  end
end
