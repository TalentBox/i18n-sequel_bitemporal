$KCODE = 'u' if RUBY_VERSION <= '1.9'

require 'rubygems'
require 'test/unit'
require 'optparse'

# Do not load the i18n gem from libraries like active_support.
#
# This is required for testing against Rails 2.3 because active_support/vendor.rb#24 tries
# to load I18n using the gem method. Instead, we want to test the local library of course.
alias :gem_for_ruby_19 :gem # for 1.9. gives a super ugly seg fault otherwise
def gem(gem_name, *version_requirements)
  puts("skipping loading the i18n gem ...") && return if gem_name =='i18n'
  super(gem_name, *version_requirements)
end

module I18n
  module Tests
    class << self
      def options
        @options ||= { :with => [], :adapter => 'sqlite3' }
      end

      def parse_options!
        OptionParser.new do |o|
          o.on('-w', '--with DEPENDENCIES', 'Define dependencies') do |dep|
            options[:with] = dep.split(',').map { |group| group.to_sym }
          end
        end.parse!
        
        options[:with].each do |dep|
          case dep
          when :sqlite3, :mysql, :postgres
            @options[:adapter] = dep
          when :r23, :'rails-2.3.x'
            ENV['BUNDLE_GEMFILE'] = 'ci/Gemfile.rails-2.3.x'
          when :r3, :'rails-3.0.x'
            ENV['BUNDLE_GEMFILE'] = 'ci/Gemfile.rails-3.x'
          when :'no-rails'
            ENV['BUNDLE_GEMFILE'] = 'ci/Gemfile.no-rails'
          end
        end

        ENV['BUNDLE_GEMFILE'] ||= 'ci/Gemfile.all'
      end

      def setup_sequel
        begin
          require 'sequel'
          ::Sequel::Model.db
          true
        rescue LoadError => e
          puts "can't use Sequel backend because: #{e.message}"
        rescue ::Sequel::Error
          connect_sequel
          require 'i18n/backend/sequel_bitemporal'
          require 'i18n/backend/sequel_bitemporal/store_procs'
          true
        end
      end

      def connect_sequel
        connect_adapter
        ::Sequel.extension :migration
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
          ::Sequel.sqlite(":memory:", :logger => logger)
        when :mysql
          # CREATE DATABASE i18n_unittest;
          # CREATE USER 'i18n'@'localhost' IDENTIFIED BY '';
          # GRANT ALL PRIVILEGES ON i18n_unittest.* to 'i18n'@'localhost';
          ::Sequel.mysql(:database => "i18n_unittest", :user => "i18n", :password => "", :host => "localhost", :logger => logger)
        end
      end
    end
  end
end