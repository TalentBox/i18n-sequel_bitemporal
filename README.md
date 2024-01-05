[![Build Status](https://github.com/TalentBox/i18n-sequel_bitemporal/workflows/CI/badge.svg)](https://github.com/TalentBox/i18n-sequel_bitemporal/actions)

# I18n::Backend::SequelBitemporal

This repository contains an [I18n](http://github.com/svenfuchs/i18n)
Sequel
backend storing translations using a bitemporal approach. This allows
you go back in time
in your translations and schedule new translations to appears in the
future without
needing any cron task to run.

Most of the code is a port of the [ActiveRecord
backend](http://github.com/svenfuchs/i18n-activerecord) from SvenFuchs.

It’s compatible with I18n \>= 1.0.0 (Rails 5.x)

## Installation

For Bundler put the following in your Gemfile:

```
  gem 'i18n-sequel_bitemporal', :require => 'i18n/sequel_bitemporal'
```

or to track master’s HEAD:

```
  gem 'i18n-sequel_bitemporal',
      :github => 'TalentBox/i18n-sequel_bitemporal',
      :require => 'i18n/sequel_bitemporal'
```

Next create a sequel migration with the Rails Generator (if you’re using
rails-sequel).
Your migration should look like this:

```
  class CreateI18nTranslationsMigration < Sequel::Migration

    def up
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

    def down
      drop_table :i18n_translation_versions
      drop_table :i18n_translations
    end

  end
```

With these translation tables you will be able to manage your
translation, and add new translations or languages.

To load `I18n::Backend::SequelBitemporal` into your Rails application,
create a new file in **config/initializers** named **locale.rb**.

A simple configuration for your locale.rb could look like this:

```
  require 'i18n/backend/sequel_bitemporal'
  I18n.backend = I18n::Backend::SequelBitemporal.new
```

A more advanced example (Thanks Moritz), which uses YAML files and
ActiveRecord for lookups:

Memoization is highly recommended if you use a DB as your backend.

```
  require 'i18n/backend/sequel_bitemporal'
  I18n.backend = I18n::Backend::SequelBitemporal.new

  I18n::Backend::SequelBitemporal.send(:include, I18n::Backend::Memoize)
  I18n::Backend::SequelBitemporal.send(:include, I18n::Backend::Flatten)
  I18n::Backend::Simple.send(:include, I18n::Backend::Memoize)
  I18n::Backend::Simple.send(:include, I18n::Backend::Pluralization)

  I18n.backend = I18n::Backend::Chain.new(I18n::Backend::Simple.new, I18n.backend)
```

You can also customize table names for the backing models:

```
  require 'i18n/backend/sequel_bitemporal'
  I18n::Backend::SequelBitemporal.master_table_name = :my_translations
  I18n::Backend::SequelBitemporal.version_table_name = :my_translation_versions
```

Please note names can be anything you can use in
\`Sequel::Model\#set\_dataset\`.
For example you want your translations table to be in a specific schema:

```
  require 'i18n/backend/sequel_bitemporal'
  I18n::Backend::SequelBitemporal.master_table_name = Sequel.qualify(:translations, :i18n_translations)
  I18n::Backend::SequelBitemporal.version_table_name = Sequel.qualify(:translations, :i18n_translation_versions)
```

## Usage

You can now use `I18n.t('Your String')` to lookup translations in the
database.

## Runnning tests

```shell
# Create db for mysql tests
mysql -e 'create database i18n_sequel_bitemporal;' --host 127.0.0.1
# Create db for postgresql tests
createdb i18n_sequel_bitemporal

##
# Run tests for a specific Rails version
##
BUNDLE_GEMFILE="ci/Gemfile.rails-6.1" bundle install
# MySQL
BUNDLE_GEMFILE="ci/Gemfile.rails-6.1" TEST_ADAPTER=mysql2 TEST_DATABASE=i18n_sequel_bitemporal TEST_ENCODING="utf8" bundle exec rake test
# PG
BUNDLE_GEMFILE="ci/Gemfile.rails-6.1" TEST_ADAPTER=postgresql TEST_DATABASE=i18n_sequel_bitemporal bundle exec rake test
# Sqlite
BUNDLE_GEMFILE="ci/Gemfile.rails-6.1" TEST_ADAPTER=sqlite3 TEST_DATABASE=test/database.sqlite3 bundle exec rake test

##
# Run tests for a specific Rails version, logging all queries to stdout
##
BUNDLE_GEMFILE="ci/Gemfile.rails-6.1" bundle install
# MySQL
DEBUG=1 BUNDLE_GEMFILE="ci/Gemfile.rails-6.1" TEST_ADAPTER=mysql2 TEST_DATABASE=i18n_sequel_bitemporal TEST_ENCODING="utf8" bundle exec rake test
# PG
DEBUG=1 BUNDLE_GEMFILE="ci/Gemfile.rails-6.1" TEST_ADAPTER=postgresql TEST_DATABASE=i18n_sequel_bitemporal bundle exec rake test
# Sqlite
DEBUG=1 BUNDLE_GEMFILE="ci/Gemfile.rails-6.1" TEST_ADAPTER=sqlite3 TEST_DATABASE=test/database.sqlite3 bundle exec rake test

##
# Example to run tests for every supported Rails version.
# !! Some Rails versions are not compatible with all Ruby versions !!
##
for gemfile in (ls ci/Gemfile.rails-* | grep -v lock);
  echo $gemfile
  BUNDLE_GEMFILE=$gemfile bundle install

  # MySQL
  BUNDLE_GEMFILE=$gemfile TEST_ADAPTER=mysql2 TEST_DATABASE=i18n_sequel_bitemporal TEST_ENCODING="utf8" bundle exec rake test

  # PG
  BUNDLE_GEMFILE=$gemfile TEST_ADAPTER=postgresql TEST_DATABASE=i18n_sequel_bitemporal bundle exec rake test

  # Sqlite
  BUNDLE_GEMFILE=$gemfile TEST_ADAPTER=sqlite3 TEST_DATABASE=test/database.sqlite3 bundle exec rake test
end
```

## Maintainers

  - Jonathan Tron
