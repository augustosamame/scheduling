module Scheduling
  class Engine < ::Rails::Engine
    isolate_namespace Scheduling

    config.to_prepare do
      # Automatically extend User model with scheduling callbacks
      # This runs after all initializers, so User model is loaded
      if defined?(User) && Scheduling.configuration.auto_create_members
        User.include(Scheduling::UserExtensions) unless User.included_modules.include?(Scheduling::UserExtensions)
      end
    end
  end
end
