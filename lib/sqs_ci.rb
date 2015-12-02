require 'aws-sdk'
require 'optparse'
require 'octokit'
require 'benchmark'
require 'English'
require_relative './sqs_ci_config'
require_relative './sqs_ci_github'
require_relative './sqs_ci_run'
require_relative './sqs_ci_s3'

# Main class for the sqs_ci project
class SqsCi
  extend SqsCiConfig
  extend SqsCiGithub
  extend SqsCiRun
  extend SqsCiS3

  class << self
    attr_accessor(:q, :s3_bucket, :region, :commands, :user, :project,
                  :full_name, :commit_ref, :delete_logs, :verbose,
                  :github_state, :github_description)
  end

  def self.delete_logs?
    delete_logs
  end

  def self.poll
    config
    poller.poll do |msg|
      message = JSON.parse(msg['body'])
      message = JSON.parse(message['Message']) if message.key?('Message')
      process message
    end
  end

  def self.poller
    ENV['AWS_REGION'] = region
    @poller ||= Aws::SQS::QueuePoller.new(q)
  end

  def parse_message(message)
    message_user = message['head_commit']['author']['name']
    project = message['repository']['name']
    commit_ref = message['head_commit']['id']
    full_name = message['repository']['full_name']
    [project, full_name, commit_ref, message_user]
  end

  def self.process(message)
    project, full_name, commit_ref, message_user = parse_message(message)
    if user && user != message_user
      fail "user #{message['head_commit']['author']['name']} != #{user}"
    end
    run_commands(project, full_name, commit_ref, commands)
  rescue => e
    puts "Message not processed. #{e}"
  else
    puts 'Message processed.'
  end
end
