source "https://rubygems.org"

# Specify your gem"s dependencies in i18n-sequel.gemspec
gemspec

gem "test-unit"
gem "test_declarative"
gem "mocha"
gem "rake"
gem "timecop"

platforms :ruby do
  gem "pg"
  gem "mysql2"
  gem "sqlite3"
end

platforms :jruby do
  gem "jdbc-postgres"
  gem "jdbc-mysql"
  gem "jdbc-sqlite3"
end
