require 'aws-sdk'

class SqsCi
  def self.poll(config_file)
    config config_file
    poller.poll do |msg|
      process msg
    end
  end

  def self.poller
    @poller ||= Aws::SQS::QueuePoller.new(q)
  end

  def self.read_config(config_file)
    JSON.parse(File.read(config_file))
  end

  def self.config(config_file)
    case
    when (File.exists?(config_file) rescue nil)
      config = read_config config_file
      q = config['q']
      s3_bucket = config['s3_bucket']
      command = config['command']
    when (ENV['SQS_CI_Q'] && ENV['SQS_CI_S3_BUCKET'])
      q = ENV['SQS_CI_Q']
      s3_bucket = ENV['SQS_CI_S3_BUCKET']
      command = ENV['SQS_CI_COMMAND']
    else
      fail 'config file parameter or env is required.'
    end
    puts "q: #{q}"
    puts "s3_bucket: #{s3_bucket}"
    @q, @s3_bucket, command = q, s3_bucket, command
  end

  def self.q
    @q
  end

  def self.s3_bucket
    @s3_bucket
  end

  def self.command
    @command
  end

  def process(msg)
    body = JSON.parse(msg['body'])
    puts JSON.pretty_generate body

    message = JSON.parse(body['Message'])
    puts JSON.pretty_generate message

    project = message['repository']['name']
    puts "name: #{project}"

    repo = message['repository']['url']
    puts "repository: #{repo}"

    ref = message['ref']
    puts "ref: #{ref}"

    output = `cd #{project} && #{command} #{ref}`

    # set status for each test
    # run the tests

    save_logs(output, "#{dir}/log")
  end

  def save_logs(output, dir)
      s3 = Aws::S3::Resource.new(region:'us-west-2')
      puts s3.inspect

      obj = s3.bucket(s3_bucket).object('test')
      puts obj.inspect

      obj.put(body: 'test')
  end
end

SqsCi.poll(ARGV[0])
