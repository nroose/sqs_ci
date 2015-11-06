require 'aws-sdk'
require 'optparse'

class SqsCi
  class << self
    attr_accessor(:q, :s3_bucket, :region, :command, :user)
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
    options = {}
    OptionParser.new do |opts|
      opts.banner = "Usage: [ruby] sqs_ci.rb [options] (*required)\n" +
                    "       sqs_ci [options] (*required)\n" +
                    "Uses sqs messages from GitHub to run tests."

      opts.on("-qQUEUE", "--queue=QUEUE", "*Queue from GitHub") do |queue|
        options[:q] = queue
      end

      opts.on("-bS3_BUCKET", "--s3-bucket=S3_BUCKET", "*S3 Bucket on AWS to which to copy the output and artifacts") do |s3|
        options[:s3_bucket] = s3
      end

      opts.on("-rREGION", "--region=REGION", "*AWS Region for queue and s3") do |region|
        options[:region] = region
      end

      opts.on("-cCOMMAND", "--command=COMMAND", "*Test Command to run") do |test_command|
        options[:command] = test_command
      end

      opts.on("-uUSER", "--user=USER", "Only do tests for commits by this GitHub user") do |user|
        options[:user] = user
      end

      opts.on("-h", "--help", "Prints this help") do
        options[:h] = "h"
        puts opts
        exit
      end
    end.parse!

    unless options[:h] || [:q, :s3_bucket, :region, :command].all? {|s| options.key? s}
      raise OptionParser::MissingArgument, "Arguments -q, -s, -r, and -c are required. -h for help."
    end
    self.q, self.s3_bucket, self.region, self.command, self.user = options.values_at(:q, :s3_bucket, :region, :command, :user)
  end

  def self.process(msg)
    body = JSON.parse(msg['body'])
    puts JSON.pretty_generate body

    message = JSON.parse(body['Message'])
    puts JSON.pretty_generate message

    if user && user != message["head_commit"]["author"]["name"]
      raise "user #{message["head_commit"]["author"]["name"]} does not match #{user}"
    end

    project = message['repository']['name']
    puts "name: #{project}"

    repo = message['repository']['url']
    puts "repository: #{repo}"

    ref = message['ref']
    puts "ref: #{ref}"

    commit_ref = message['head_commit']['id']

    output = `cd #{project} && git pull && git checkout #{commit_ref} && #{command}`
    puts output

    # set status for each test
    # run the tests

    save_logs(project, commit_ref, output, "#{project}/log")
  rescue => e
    puts "Message not processed. #{e}"
  end

  def self.save_logs(project, commit_ref, output, dir)
    s3 = Aws::S3::Resource.new(region:'us-west-2')
    obj = s3.bucket(s3_bucket).object(commit_ref)
    obj.put(body: output)
    files = Dir.new dir
    files.each do |file|
      obj.upload_file(file)
    end
  end
end

SqsCi.poll
