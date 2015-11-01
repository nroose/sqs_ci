Gem::Specification.new do |s|
  s.name        = 'sqs_ci'
  s.version     = '0.0.5'
  s.date        = '2015-10-31'
  s.summary     = "Github sns hook-based ci system."
  s.description = "Takes github messages from sqs to run tests on rails projects."
  s.authors     = ["Nick Roosevelt"]
  s.email       = 'nroose@gmail.com'
  s.files       = ["lib/sqs_ci.rb"]
  s.executables << 'sqs_ci'
  s.homepage    =
    'http://github.com/nroose/sqs_ci'
  s.license       = 'GPL'
  s.add_runtime_dependency 'aws-sdk', [">= 2"]
end
