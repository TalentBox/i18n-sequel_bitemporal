require "rubygems"
require "test/unit"
require "optparse"

module I18n
  module Tests
    class << self
      def parse_options!
        options[:adapter] = ENV.fetch "TEST_ADAPTER", "sqlite"
        options[:database] = ENV.fetch "TEST_DATABASE", ":memory:"
        options[:host] = ENV.fetch "TEST_DATABASE_HOST", nil
        options[:port] = ENV.fetch "TEST_DATABASE_PORT", nil
        options[:user] = ENV.fetch "TEST_USERNAME", nil
        options[:password] = ENV.fetch "TEST_PASSWORD", nil
        options[:encoding] = ENV.fetch "TEST_ENCODING", nil
      end

      def setup_sequel
        begin
          require "sequel"
          ::Sequel::Model.db
          true
        rescue LoadError => e
          puts "can't use Sequel backend because: #{e.message}"
        rescue ::Sequel::Error
          connect_sequel
          require "i18n/backend/sequel_bitemporal"
          require "i18n/backend/sequel_bitemporal/store_procs"
          true
        end
      end

      def connect_sequel
        connect_adapter
        ::Sequel.extension :migration
        opts = {}
        opts[:cascade] = true if postgresql?
        ::Sequel::Model.db.drop_table? :another_i18n_translation_versions, opts
        ::Sequel::Model.db.drop_table? :another_i18n_translations, opts
        ::Sequel::Model.db.drop_table? :i18n_translation_versions, opts
        ::Sequel::Model.db.drop_table? :i18n_translations, opts
        ::Sequel.migration do
          change do
            create_table :i18n_translations do
              primary_key :id
              String :locale, :null => false
              String :key, :null => false
              index [:locale, :key], :unique => true
            end

            create_table :i18n_translation_versions do
              primary_key :id
              foreign_key :master_id, :i18n_translations, :on_delete => :cascade
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
      end

      def connect_adapter
        connect_options = options.dup
        if ENV["DEBUG"]
          require "logger"
          connect_options = options.merge! :logger => Logger.new(STDOUT)
        end
        ::Sequel.connect(connect_options.merge(:adapter => adapter))
      end

      private

      def options
        @options ||= {}
      end

      def jruby?
        (defined?(RUBY_ENGINE) && RUBY_ENGINE=="jruby") || defined?(JRUBY_VERSION)
      end

      def postgresql?
        options[:adapter] == "postgresql"
      end

      def sqlite?
        options[:adapter] == "sqlite"
      end

      def mysql?
        options[:adapter] == "mysql2"
      end

      def adapter
        case options[:adapter]
        when "sqlite", "sqlite3"
          jruby? ? "jdbc:sqlite:" : "sqlite"
        when "postgresql", "postgres"
          jruby? ? "jdbc:postgresql" : "postgresql"
        when "mysql", "mysql2"
          jruby? ? "jdbc:mysql" : "mysql2"
        end
      end
    end
  end
end
