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
      puts msg.inspect

      s3 = Aws::S3::Resource.new(region:'us-west-2')
      obj = s3.bucket(s3_bucket).object('test')

      obj.put(body: 'test')
    end
  end
end

SqsCi.poll(ARGV[0])
