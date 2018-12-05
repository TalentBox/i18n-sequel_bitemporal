[![Build Status](https://travis-ci.org/TalentBox/i18n-sequel_bitemporal.svg?branch=master)](https://travis-ci.org/TalentBox/i18n-sequel_bitemporal)

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

    gem install bundler
    BUNDLE_GEMFILE=ci/Gemfile.rails-5.x bundle
    BUNDLE_GEMFILE=ci/Gemfile.rails-5.x-i18n-0.6 bundle
    BUNDLE_GEMFILE=ci/Gemfile.rails-5.x rake
    BUNDLE_GEMFILE=ci/Gemfile.rails-5.x-i18n-0.6 rake

If you want to see what queries are executed:

    DEBUG=true BUNDLE_GEMFILE=ci/Gemfile.rails-5.x rake
    DEBUG=true BUNDLE_GEMFILE=ci/Gemfile.rails-5.x-i18n-0.6 rake

## Maintainers

  - Jonathan Tron
