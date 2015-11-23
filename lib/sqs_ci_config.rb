# Configuration module
# - reads the command line options and sets corresponding variables
module SqsCiConfig
  OPTIONS_ARRAY =
    [
      ['-qqueue', '--queue=queue', '**queue from github'],
      ['-bs3_bucket', '--s3-bucket=s3_bucket',
       's3 bucket on aws for the output and artifacts'],
      ['-rregion', '--region=region',
       '**aws region for queue and s3'],
      ['-uuser', '--user=user',
       'only do tests for commits by this github user'],
      ['-ffull_name', '--full-name=full_name',
       '***project full name, like "nroose/sqs_ci".'],
      ['-gcommit_ref', '--commit-ref=commit_ref',
       '***run tests on this commit ref, or ' \
       'branch name.'],
      ['-x', '--clean-logs', 'Delete logs before running.'],
      ['-v', '--verbose', 'full output.']
    ]

  def parse_option_array(opts, options)
    OPTION_ARRAY.each do |o, option, desc|
      opts.on(o, option, desc) do |val|
        options[o[1..1].to_sym] = val
      end
    end
  end

  def parse_commands_option(opts, options)
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
    options = { commands: [] }
    OptionParser.new do |opts|
      opts.banner = 'Usage: sqs_ci [options] (* and ** are required)\n' \
                    '       run_ci [options] (* and *** are required)\n' \
                    'uses sqs messages from github to run tests.'

      parse_option_array(opts, options)
      parse_commands_option(opts, options)
      parse_help_option(opts, options)
    end.parse!
    options
  end

  def check_options
    unless options[:h] ||
           [:q, :region, :commands].all? { |s| options.key? s } ||
           [:full_name, :commit_ref, :commands].all? { |s| options.key? s }
      return
    end
    fail OptionParser::MissingArgument,
         'argument -c and either -f and -g or -q and -r are required. ' \
         '-h for more help.'
  end

  def config
    options = parse_options

    self.q, self.s3_bucket, self.region, self.commands, self.user,
    self.full_name, self.commit_ref, self.delete_logs,
    self.verbose = options.values_at(:q, :s3_bucket, :region, :commands, :user,
                                     :full_name, :commit_ref, :delete_logs,
                                     :verbose)
  end
end
