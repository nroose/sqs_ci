require 'aws-sdk'

class SqsCi
  def self.poll(config_file)
    case
    when (File.exists?(config_file) rescue nil)
      config = JSON.parse(File.read(config_file))
      q = config['q']
      s3_bucket = config['s3_bucket']
    when (ENV['SQS_CI_Q'] && ENV['SQS_CI_S3_BUCKET'])
      q = ENV['SQS_CI_Q']
      s3_bucket = ENV['SQS_CI_S3_BUCKET']
    else
      fail 'config file parameter or env is required.'
    end
    puts "q: #{q}"
    puts "s3_bucket: #{s3_bucket}"

    poller = Aws::SQS::QueuePoller.new(q)

    poller.poll do |msg|
      body = JSON.parse(msg['body'])
      puts JSON.pretty_generate body

      message = JSON.parse(body['Message'])
      puts JSON.pretty_generate message

      puts "name: #{message['repository']['name']}"
      puts "repository: #{message['repository']['url']}"
      puts "ref: #{message['ref']}"

      s3 = Aws::S3::Resource.new(region:'us-west-2')
      puts s3.inspect

      obj = s3.bucket(s3_bucket).object('test')
      puts obj.inspect

      obj.put(body: 'test')

      
    end
  end
end

SqsCi.poll(ARGV[0])
