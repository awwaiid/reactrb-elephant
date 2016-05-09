
require 'opal'
require 'browser/interval'
require 'jquery'
require 'opal-jquery'
require "json"
require 'reactive-ruby'
require 'opal-parser' # gives me 'eval', for hot-loading code

# You need something like this server-side:
#
#     get '/code.rb' do
#       open("app/example.rb").read
#     end

# This will only load one time!
if !$loader_loaded
  # Fix re-defining callbacks
  module React
    module Callbacks
      module ClassMethods
        def define_callback(callback_name)
          attribute_name = "_#{callback_name}_callbacks"
          class_attribute(attribute_name)
          self.send("#{attribute_name}=", [])
          define_singleton_method(callback_name) do |*args, &block|
            # puts "calling new and improved callbacks"
            callbacks = []
            callbacks.concat(args)
            callbacks.push(block) if block_given?
            self.send("#{attribute_name}=", callbacks)
          end
        end
      end
    end
  end

  module React
    module Callbacks

      alias_method :original_run_callback, :run_callback

      def run_callback(name, *args)
        # monkey patch run callback because its easiest place to hook
        # into all components lifecycles.
        React::Component.add_to_global_component_list self if name == :before_mount
        original_run_callback name, *args
        React::Component.remove_from_global_component_list self if name == :before_unmount
      end

    end

    module Component

      def self.add_to_global_component_list instance
        # puts "Adding #{instance} to component list"
        (@global_component_list ||= Set.new).add instance
      end

      def self.remove_from_global_component_list instance
        # puts "Removing #{instance} from component list"
        @global_component_list.delete instance
      end

      def self.force_update!
        # puts "Forcing global update"
        @global_component_list && @global_component_list.each(&:force_update!)
      end

    end
  end

  @code_fetcher = every(0.5) do
    HTTP.get('/code.rb') do |response|
      if response.ok?
        @old_code ||= " "
        new_code = response.body
        if new_code != @old_code
          puts "LIVE LOADER: Updating code..."
          eval(response.body)
          @old_code = new_code
          React::Component.force_update!
        end
      else
        puts "LIVE LOADER: failed with status #{response.status_code}"
      end
    end
  end

  puts "***** LIVE LOADER LOADED *****"
  $loader_loaded = true
else
  puts "***** LIVE LOADER ALREADY LOADED *****"
end
