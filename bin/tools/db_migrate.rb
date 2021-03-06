#!/usr/bin/env ruby

require 'cryptobroker'
require 'pry'

class Migrate < Cryptobroker

  attr_reader :migrations

  def initialize(config_file, migration_dir)
    super config_file
    filename = File.join(migration_dir, '%s.rb')
    @migrations = Dir.glob(filename % '*').sort
    @migrations = @migrations
                      .map { |m| File.basename m, '.rb' }
                      .select { |m| m =~ /\A[0-9]{14}_.+\z/ }
                      .sort
    @migrations.each { |m| require_relative(filename % m) }
    @migrations.map! { |m| m.sub(/\A[0-9]{14}_/, '').camelize.constantize }
  end

  def up
    @migrations.each { |m| m.migrate :up }
  end

  def down
    @migrations.reverse_each { |m| m.migrate :down }
  end

  def init_data
    currencies_array = Model::Currency.create([
                        {code: 'BTC', name: 'Bitcoin', crypto: true},
                        {code: 'GHS', name: 'Gigahash', crypto: true},
                        {code: 'LTC', name: 'Litecoin', crypto: true},
                        {code: 'NMC', name: 'Namecoin', crypto: true},
                        {code: 'USD', name: 'United States dollar', crypto: false},
                        {code: 'EUR', name: 'Euro', crypto: false},
                        {code: 'IXC', name: 'IXC', crypto: true},
                        {code: 'DRK', name: 'DRK', crypto: true},
                        {code: 'DOGE', name: 'DOGE', crypto: true},
                        {code: 'FTC', name: 'FTC', crypto: true},
                        {code: 'AUR', name: 'AUR', crypto: true},
                        {code: 'DVC', name: 'DVC', crypto: true},
                        {code: 'POT', name: 'POT', crypto: true},
                        {code: 'ANC', name: 'ANC', crypto: true},
                        {code: 'MEC', name: 'MEC', crypto: true},
                        {code: 'WDC', name: 'WDC', crypto: true},
                        {code: 'DGB', name: 'DGB', crypto: true},
                        {code: 'USDE', name: 'USDE', crypto: true},
                        {code: 'MYR', name: 'MYR', crypto: true},
                    ])
    # currencies_array = Model::Currency.all
    currencies = {}
    currencies_array.each { |currency| currencies[currency.code] = currency }
    cex = Model::Exchange.create({name: 'cex.io', api_class: 'Cryptobroker::API::Cexio'})
    # cex = Model::Exchange.first
    market = ->(curr1, curr2) { {exchange: cex, base: currencies[curr1], quote: currencies[curr2], traced: true} }
    Model::Market.create([
                      market['BTC', 'USD'],
                      market['GHS', 'USD'],
                      market['LTC', 'USD'],
                      market['BTC', 'EUR'],
                      market['LTC', 'EUR'],
                      market['GHS', 'BTC'],
                      market['LTC', 'BTC'],
                      market['NMC', 'BTC'],
                      market['GHS', 'LTC'],
                  ])
    market = ->(curr1, curr2) { {exchange: cex, base: currencies[curr1], quote: currencies[curr2], traced: false} }
    Model::Market.create([
                      market['DOGE', 'USD'],
                      market['DRK', 'USD'],
                      market['DOGE', 'EUR'],
                      market['DRK', 'EUR'],
                      market['DOGE', 'BTC'],
                      market['DRK', 'BTC'],
                      market['IXC', 'BTC'],
                      market['POT', 'BTC'],
                      market['ANC', 'BTC'],
                      market['MEC', 'BTC'],
                      market['WDC', 'BTC'],
                      market['FTC', 'BTC'],
                      market['DGB', 'BTC'],
                      market['USDE', 'BTC'],
                      market['MYR', 'BTC'],
                      market['AUR', 'BTC'],
                      market['DOGE', 'LTC'],
                      market['DRK', 'LTC'],
                      market['MEC', 'LTC'],
                      market['WDC', 'LTC'],
                      market['ANC', 'LTC'],
                      market['FTC', 'LTC'],
                  ])
  end
end

$migrate = Migrate.new('../../dev-config.yml', '../../db/migrate')
pry $migrate