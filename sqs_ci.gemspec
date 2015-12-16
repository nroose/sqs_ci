Gem::Specification.new do |s|
  s.name        = 'sqs_ci'
  s.version     = '0.0.17'
  s.date        = '2015-12-14'
  s.summary     = 'Github sns hook-based ci system.'
  s.description = 'Takes github messages from sqs to run tests.'
  s.authors     = ['Nick Roosevelt']
  s.email       = 'nroose@gmail.com'
  s.files       = ['lib/sqs_ci.rb', 'lib/sqs_ci_config.rb',
                   'lib/sqs_ci_github.rb', 'lib/sqs_ci_run.rb',
                   'lib/sqs_ci_s3.rb']
  s.executables << 'sqs_ci'
  s.executables << 'run_ci'
  s.homepage    =
    'http://github.com/nroose/sqs_ci'
  s.license = 'GPL'
  s.add_runtime_dependency 'aws-sdk', ['>= 2']
  s.add_runtime_dependency 'octokit', ['>= 4']
end
