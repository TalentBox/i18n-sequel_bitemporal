source :rubygems

gemspec :path => "../"

gem "i18n", "~> 0.5.0"

platforms :ruby do
  gem "pg"
  gem "mysql"
  gem "sqlite3"
end

platforms :jruby do
  gem "jdbc-postgres"
  gem "jdbc-mysql"
  gem "jdbc-sqlite3"
end
