module SqsCiConfig
  def config
    options = {:commands => []}
    OptionParser.new do |opts|
      opts.banner = "Usage: sqs_ci [options] (* and ** are required)\n" +
                    "       run_ci [options] (* and *** are required)\n" +
                    "uses sqs messages from github to run tests."

      opts.on("-qqueue", "--queue=queue", "**queue from github") do |queue|
        options[:q] = queue
      end

      opts.on("-bs3_bucket", "--s3-bucket=s3_bucket", "s3 bucket on aws to which to copy the output and artifacts") do |s3|
        options[:s3_bucket] = s3
      end

      opts.on("-rregion", "--region=region", "**aws region for queue and s3") do |region|
        options[:region] = region
      end

      opts.on("-ccommand", "--command=command",
              "*test command to run (can have multiple parallel commands by using multiple -c options, and each command can be arbirarily complicated - " +
              "if you separate the commands in one -c option with '&&' they will be run sequentially but tracked independently)") do |test_command|
        options[:commands] << test_command
      end

      opts.on("-uuser", "--user=user", "only do tests for commits by this github user") do |user|
        options[:user] = user
      end

      opts.on("-ffull_name", "--full-name=full_name", "***project full name, like 'nroose/sqs_ci'.") do |full_name|
        options[:full_name] = full_name
      end

      opts.on("-gcommit_ref", "--commit-ref=commit_ref", "***run tests on this commit ref, or branch name.") do |commit_ref|
        options[:commit_ref] = commit_ref
      end

      opts.on("-x", "--clean-logs", "Delete logs before running.") do
        options[:delete_logs] = true
      end

      opts.on("-h", "--help", "prints this help") do
        options[:h] = "h"
        puts opts
        exit
      end
    end.parse!

    unless options[:h] || [:q, :region, :commands].all?{|s| options.key? s} || [:full_name, :commit_ref, :commands].all?{|s| options.key? s}
      raise OptionParser::MissingArgument, "argument -c and either -f and -g or -q and -r are required. -h for more help."
    end
    self.q, self.s3_bucket, self.region, self.commands,
    self.user, self.full_name, self.commit_ref, self.delete_logs =
                               options.values_at(:q, :s3_bucket, :region, :commands, :user,
                                                 :full_name, :commit_ref, :delete_logs)
  end
end
