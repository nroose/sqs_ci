require 'aws-sdk'
require 'optparse'
require 'octokit'
require 'benchmark'

##
# This class implements the ci test utility to run ci from the sqs Github hook.

class SqsCi
  class << self
    attr_accessor(:q, :s3_bucket, :region, :commands, :user)
  end

  def self.github_client
    @github_client ||= Octokit::Client.new(access_token:
                                             ENV['GITHUB_ACCESS_TOKEN'])
  end

  def self.create_status(repo, sha, state, *optional_params)
    github_client.create_status(repo, sha, state, *optional_params)
  end

  def self.poll
    config
    poller.poll do |msg|
      process msg
    end
  end

  def self.poller
    ENV['AWS_REGION'] = region
    @poller ||= Aws::SQS::QueuePoller.new(q)
  end

  def self.config
    options = { commands: [] }
    OptionParser.new do |opts|
      opts.banner = "Usage: [ruby] sqs_ci.rb [options] (*required)\n" \
                    "       sqs_ci [options] (*required)\n" \
                    'Uses sqs messages from GitHub to run tests.'

      opts.on('-qQUEUE', '--queue=QUEUE', '*Queue from GitHub') do |queue|
        options[:q] = queue
      end

      opts.on('-bS3_BUCKET', '--s3-bucket=S3_BUCKET',
              'S3 Bucket on AWS to which to send the log files') do |s3|
        options[:s3_bucket] = s3
      end

      opts.on('-rREGION', '--region=REGION',
              '*AWS Region for queue and s3') do |region|
        options[:region] = region
      end

      opts.on('-cCOMMAND', '--command=COMMAND',
              '*Test Command to run (can have multiple parallel commands, and' \
              ' each command can be arbirariloy complicated)') do |test_command|
        options[:commands] << test_command
      end

      opts.on('-uUSER', '--user=USER',
              'Only run tests for commits by this GitHub user') do |user|
        options[:user] = user
      end

      opts.on('-h', '--help', 'Prints this help') do
        options[:h] = 'h'
        puts opts
        exit
      end
    end.parse!

    unless options[:h] || [:q, :region, :commands].all? { |s| options.key? s }
      fail OptionParser::MissingArgument,
           'Arguments -q, -r, and -c are required. -h for help.'
    end
    self.q, self.s3_bucket, self.region, self.commands, self.user = options.values_at(:q, :s3_bucket, :region, :commands, :user)
  end

  def self.process(msg)
    body = JSON.parse(msg['body'])
    message = JSON.parse(body['Message'])
    if user && user != message['head_commit']['author']['name']
      fail "user #{message['head_commit']['author']['name']} " \
           "does not match #{user}"
    end
    project = message['repository']['name']
    puts "name: #{project}"
    full_name = message['repository']['full_name']
    repo = message['repository']['url']
    puts "repository: #{repo}"
    ref = message['ref']
    puts "ref: #{ref}"
    commit_ref = message['head_commit']['id']
    puts "commit_ref: #{commit_ref}"

    commands.each do |command|
      Process.fork do
        puts "Starting #{command}"
        run_command(project, full_name, commit_ref, command)
        puts "Finished #{command}"
      end
    end
    Process.wait
    save_logs(commit_ref, "#{project}/log")

  rescue => e
    puts "Message not processed. #{e}"
  else
    puts 'Message processed.'
  end

  def self.run_command(project, full_name, commit_ref, command)
    # set status
    create_status(full_name, commit_ref, 'pending',
                  description: "Starting at #{Time.now}.",
                  context: command)
    secs = Benchmark.realtime do
      `cd #{project} && git pull && git checkout #{commit_ref} &> /dev/null && #{command} >> log/output#{Process.pid}.log`
    end
    status = $CHILD_STATUS
    mins = secs.to_i / 60
    secs = '%.2f' % (secs % 60)
    time_str = "#{mins}m#{secs}s"

    # update status
    result = status.success? ? 'success' : 'failure'
    description = "#{result} in #{time_str} at #{Time.now}."

    url = 'https://console.aws.amazon.com/s3/home?region=' \
          "#{region}#&bucket=#{s3_bucket}&prefix=#{commit_ref}/"

    create_status(full_name, commit_ref,
                  result,
                  description: description,
                  context: command,
                  target_url: (url if s3_bucket && url))

    puts "#{command}: #{description}"
  end

  def self.save_logs(commit_ref, dir)
    return unless s3_bucket
    s3 = Aws::S3::Resource.new(region: region)
    files = Dir.new dir
    dir += '/' if dir[-1] != '/'
    files.each do |file|
      full_file_name = "#{dir}#{file}"
      next unless File.file?(full_file_name)
      begin
                obj = s3.bucket(s3_bucket).object("#{commit_ref}/#{file}")
                obj.upload_file(full_file_name)
              rescue => e
                puts "Could not upload #{full_file_name} (#{e})."
      else
        puts "Uploaded #{full_file_name}."
              end
    end
  end
end

SqsCi.poll
