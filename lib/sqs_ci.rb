require 'aws-sdk'
require 'optparse'
require "octokit"
require "benchmark"
require_relative "./sqs_ci_config"
require_relative "./sqs_ci_github"
require_relative "./sqs_ci_run"
require_relative "./sqs_ci_s3"

class SqsCi
  extend SqsCiConfig
  extend SqsCiGithub
  extend SqsCiRun
  extend SqsCiS3

  class << self
    attr_accessor(:q, :s3_bucket, :region, :commands, :user, :project, :full_name, :commit_ref, :delete_logs)
  end

  def self.delete_logs?
    delete_logs
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

  def self.process(msg)
    body = JSON.parse(msg['body'])
    message = JSON.parse(body['Message'])
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
    puts "commit_ref: #{commit_ref}"
    full_name = message['repository']['full_name']
    puts "full_name: #{full_name}"

    run_commands(project, full_name, commit_ref, commands)
  rescue => e
    puts "Message not processed. #{e}"
  else
    puts "Message processed."
  end
end
