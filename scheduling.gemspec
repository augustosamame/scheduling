require_relative "lib/scheduling/version"

Gem::Specification.new do |spec|
  spec.name        = "scheduling"
  spec.version     = Scheduling::VERSION
  spec.authors     = [ "Augusto Samame" ]
  spec.email       = [ "augustosamame@gmail.com" ]
  spec.homepage    = "https://github.com/augustosamame/scheduling"
  spec.summary     = "Multi-tenant scheduling engine for Rails"
  spec.description = "Complete scheduling solution with organizational hierarchy, payments, and calendar integration"
  spec.license     = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/augustosamame/scheduling"
  spec.metadata["changelog_uri"] = "https://github.com/augustosamame/scheduling/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md", "setup_host_scheduling.rb"]
  end

  spec.add_dependency "rails", ">= 8.0.0"
  spec.add_dependency "pg", "~> 1.5"

  # Multi-currency support
  spec.add_dependency "money-rails", "~> 1.15"

  # Payment processing (optional - install as needed)
  # spec.add_dependency "stripe", "~> 10.0"
  # For Culqi, use direct HTTP client or install culqi gem separately

  # Calendar integration
  spec.add_dependency "google-api-client", ">= 0.53"
  spec.add_dependency "oauth2", "~> 2.0" # For Microsoft Graph and other OAuth integrations

  # Scheduling logic
  spec.add_dependency "ice_cube", "~> 0.16"

  # Background jobs
  spec.add_dependency "solid_queue", ">= 0.1"

  spec.add_development_dependency "rspec-rails", "~> 8.0"
  spec.add_development_dependency "factory_bot_rails", "~> 6.4"
  spec.add_development_dependency "awesome_print", "~> 1.9"
  spec.add_dependency "faker", "~> 3.2"
end
