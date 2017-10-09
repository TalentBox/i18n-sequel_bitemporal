require "rubygems"
require "test/unit"
require "optparse"

module I18n
  module Tests
    class << self
      def options
        @options ||= { :with => [], :adapter => "sqlite3" }
      end

      def parse_options!
        OptionParser.new do |o|
          o.on("-w", "--with DEPENDENCIES", "Define dependencies") do |dep|
            options[:with] = dep.split(",").map { |group| group.to_sym }
          end
        end.parse!

        options[:adapter] = ENV["ADAPTER"] || "postgres"
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
        opts[:cascade] = true if options[:adapter].to_sym==:postgres
        ::Sequel::Model.db.drop_table? :i18n_translations, opts
        ::Sequel::Model.db.drop_table? :i18n_translation_versions, opts
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
        logger = nil
        if ENV["DEBUG"]
          require "logger"
          logger =  Logger.new STDOUT
        end
        case options[:adapter].to_sym
        when :sqlite3
          if (defined?(RUBY_ENGINE) && RUBY_ENGINE=="jruby") || defined?(JRUBY_VERSION)
            ::Sequel.connect("jdbc:sqlite::memory:", :logger => logger)
          else
            ::Sequel.sqlite(":memory:", :logger => logger)
          end
        when :postgres
          if (defined?(RUBY_ENGINE) && RUBY_ENGINE=="jruby") || defined?(JRUBY_VERSION)
            ::Sequel.connect("jdbc:postgresql://localhost/i18n_sequel_bitemporal", :logger => logger)
          else
            ::Sequel.postgres("i18n_sequel_bitemporal", :logger => logger)
          end
        when :mysql
          # CREATE DATABASE i18n_unittest;
          # CREATE USER "i18n"@"localhost" IDENTIFIED BY "";
          # GRANT ALL PRIVILEGES ON i18n_unittest.* to "i18n"@"localhost";
          if (defined?(RUBY_ENGINE) && RUBY_ENGINE=="jruby") || defined?(JRUBY_VERSION)
            ::Sequel.connect("jdbc:mysql://localhost/i18n_sequel_bitemporal", :logger => logger)
          else
            ::Sequel.mysql(:database => "i18n_unittest", :user => "i18n", :password => "", :host => "localhost", :logger => logger)
          end
        end
      end
    end
  end
end
