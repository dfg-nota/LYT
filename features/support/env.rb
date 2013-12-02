require 'debugger'
begin require 'rspec/expectations'; rescue LoadError; require 'spec/expectations'; end
require 'capybara'
require 'capybara/dsl'
require 'capybara/cucumber'

Capybara.configure do |config|
  config.run_server = false
  config.default_driver = :selenium
  target_dir = ENV['LYT_DESTINATION_DIR'] || ENV['USER']
  config.app_host = "http://#{ENV['LYT_HOST']}/#{target_dir}"
  config.default_wait_time = 2 # Default = 2
end

case ENV['LYT_BROWSER']
when "chrome", "firefox"
  Capybara.register_driver :selenium do |app|
    Capybara::Selenium::Driver.new(app, :browser => ENV['LYT_BROWSER'].to_sym)
  end
else
  raise "Uknown browser '#{ENV['LYT_BROWSER']}', please set LYT_BROWSER environmentvariable."
end
