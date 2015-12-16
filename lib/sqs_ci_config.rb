# Configuration module
# - reads the command line options and sets corresponding variables
module SqsCiConfig
  OPTION_ARRAY =
    [
      ['-qqueue', '--queue=queue', '** Queue from github'],
      ['-bs3_bucket', '--s3-bucket=s3_bucket',
       'S3 bucket on aws for the output and artifacts'],
      ['-rregion', '--region=region',
       '** AWS region for queue and s3'],
      ['-uuser', '--user=user',
       'Only do tests for commits by this github user'],
      ['-ffull_name', '--full-name=full_name',
       'Project full name, like "nroose/sqs_ci" (default will be origin)'],
      ['-gcommit_ref', '--commit-ref=commit_ref',
       'Run tests on this commit ref (default will be current ref)'],
      ['-ystate', '--github-state=state',
       '**** The state to set for set_github_status - Can be one of ' \
       'pending, success, error, or failure.'],
      ['-zdescription', '--github-description=description',
       '**** The description to use for set_github_status.'],
      ['-x', '--clean-logs', 'Delete logs before running.'],
      ['-v', '--verbose', 'Full output.']
    ]

  def parse_option_array(opts, options)
    OPTION_ARRAY.each do |o, option, desc|
      opts.on(o, option, desc) do |val|
        options[o[1..1].to_sym] = val
      end
    end
  end

  def parse_commands_option(opts, options)
    options[commands] ||= []
    opts.on('-ccommand', '--command=command',
            '*test command to run (can have multiple parallel commands by ' \
            'using multiple -c options, and each command can be arbirarily ' \
            'complicated - if you separate the commands in one -c option ' \
            'with "&&" they will be run sequentially but tracked ' \
            'independently)') do |test_command|
      options[:commands] << test_command
    end
  end

  def parse_help_option(opts, options)
    opts.on('-h', '--help', 'prints this help') do
      options[:h] = 'h'
      puts opts
      exit
    end
  end

  def parse_options
    OptionParser.new do |opts|
      opts.banner = "Usage: sqs_ci [options] (* and ** are required)\n" \
                    "       run_ci [options] (* and *** are required)\n" \
                    " set_github_status [options] (* and **** are required)\n" \
                    'uses sqs messages from github to run tests.'

      parse_option_array(opts, options)
      parse_commands_option(opts, options)
      parse_help_option(opts, options)
    end.parse!
    options
  end

  def check_options(options)
    case
    when options[:h]
    when [:q, :r, :commands].all? { |s| options.key? s }
    when [:g, :commands].all? { |s| options.key? s }
    else
      fail OptionParser::MissingArgument,
           'argument -c and either -f and -g or -q and -r are required. ' \
           "'-h for more help. options: #{options.inspect}"
    end
  end

  def set_defaults
    if full_name
      self.project = full_name.split('/').last
    else
      fetch = `git remote show origin -n`.lines.find do |line|
        /^\s*Fetch.*/.match(line)
      end
      self.full_name = /^\s*Fetch.*github.com:(.*).git/.match(fetch)[1]
      self.project = '.'
    end
  end

  def options_to_vars(options)
    self.q, self.s3_bucket, self.region, self.commands, self.user,
      self.full_name, self.commit_ref, self.delete_logs, self.verbose,
      self.github_state, self.github_description =
        options.values_at(:q, :s, :r, :commands, :u, :f, :g, :x, :v, :y, :z)
  end

  def config
    options = parse_options
    check_options(options)
    options_to_vars(options)
    set_defaults
  end
end
