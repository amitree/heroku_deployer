Gem::Specification.new do |s|
  s.name        = 'heroku_deployer'
  s.version     = '0.1'
  s.date        = '2014-05-23'
  s.summary     = "Heroku Deployer"
  s.description = "Gem that handles automatic deployment of code to Heroku, integrating with Pivotal Tracker and Git"
  s.authors     = ["Nick Wargnier", "Tony Novak"]
  s.email       = 'engineering@amitree.com'
  s.files       = ["lib/amitree/git_client.rb", "lib/amitree/heroku_client.rb", "lib/heroku/new_api.rb"]

  s.homepage    = 'http://rubygems.org/gems/heroku_deployer'
  s.license     = 'MIT'

  s.required_ruby_version = '~> 2.0'
  s.add_development_dependency 'rspec', '2.14.1'
  s.add_runtime_dependency 'octokit', '2.7.1'
  s.add_runtime_dependency 'heroku-api', '0.3.17'
  s.add_runtime_dependency 'rendezvous', '0.0.2'
  s.add_runtime_dependency 'pivotal-tracker', '0.5.12'
end