#!/usr/bin/env ruby

require 'cryptobroker'

app = Cryptobroker.new ARGV.fetch(0, 'config.yml')

at_exit do
  exc = $!
  if exc.nil?
    app.logger.fatal { 'Unexpected application exit.' }
  else
    if exc.is_a? SystemExit
      app.terminate
    else
      begin
        app.investors.each { |investor| investor.abort rescue nil }
      ensure
        app.logger.fatal { "Uncaught exception: #{exc.message} (#{exc.class})." }
      end
    end
  end
end

app.invest
app.trace

['INT', 'TERM'].each do |signal|
  Signal.trap(signal) do
    exit
  end
end

sleep
