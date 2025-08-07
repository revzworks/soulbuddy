source "https://rubygems.org"

# Fastlane for iOS automation
gem "fastlane", "~> 2.217"

# Additional plugins and tools
gem "cocoapods", "~> 1.15"

# GitHub Actions specific
gem "bundler", "~> 2.4"

# Development tools
group :development do
  gem "rubocop", "~> 1.60"
end

# Fastlane plugins
plugins_path = File.join(File.dirname(__FILE__), 'fastlane', 'Pluginfile')
eval_gemfile(plugins_path) if File.exist?(plugins_path) 