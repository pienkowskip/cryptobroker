#!/usr/bin/env ruby

require 'shellwords'
require 'cryptobroker'
require 'cryptobroker/config'

dbconf = Cryptobroker::Config.new(ARGV.fetch(0, 'config.yml')).database

env = {'PGPASSWORD' => dbconf[:password]}
cmd = ['pg_dump', '-h', dbconf[:host], '-U', dbconf[:username], dbconf[:database]]
filename = 'db_dump_' << Time.now.strftime('%FT%T%:z') << '.sql.bz2'

File.umask(0077)
exec(env, Shellwords.join(cmd) + ' | bzip2 -z9 > ' + Shellwords.escape(filename))