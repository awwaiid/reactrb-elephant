
require 'bundler'

ENV['RACK_ENV'] ||= 'development'
Bundler.require :default, ENV['RACK_ENV'].to_sym

require 'open-uri'
require 'sass/plugin/rack'

# Opal::Processor.source_map_enabled = true

$opal = Opal::Server.new {|s|
  s.append_path './client'
  s.main = 'main'
  s.debug = true
  # s.source_map = true
}

# map opal.source_maps.prefix do
#   run opal.source_maps
# end
map '/assets' do
  run $opal.sprockets
end

# Sass::Plugin.options[:style] = :compressed
use Sass::Plugin::Rack

require File.expand_path('server/main', File.dirname(__FILE__))

run Main

