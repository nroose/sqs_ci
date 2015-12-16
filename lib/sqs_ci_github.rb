# Module for sending status updates to github
module SqsCiGithub
  def github_client
    @github_client ||=
      Octokit::Client.new(access_token: ENV['GITHUB_ACCESS_TOKEN'])
  end

  def create_status(repo, sha, state, *optional_params)
    puts [repo, sha, state, *optional_params].inspect if verbose
    github_client.create_status(repo, sha, state, *optional_params)
  end

  def initial_pending_statuses(command_array)
    command_array.each do |command|
      create_status(full_name, commit_ref, 'pending',
                    description: "Waiting at #{Time.now.strftime('%l:%M %P %Z')}.",
                    context: command)
    end
  end

  def start_status(command)
    create_status(full_name, commit_ref, 'pending',
                  description: "Starting at #{Time.now.strftime('%l:%M %P %Z')}.",
                  context: command)
  end

  def time_str(secs)
    mins = secs.to_i / 60
    secs = (secs.to_i % 60).round
    "#{mins}m#{secs}s"
  end

  def log_status(command, result, description)
    if verbose
      puts "#{command}: #{result}\n  #{description}"
    else
      print result[0]
    end
  end

  def end_status(result, secs, command, result_summary)
    description = "#{time_str(secs)} at #{Time.now.strftime('%l:%M %P %Z')}#{result_summary}"
    result ||= 'error'
    log_status(command, result, description)
    create_status(full_name, commit_ref, result,
                  description: description,
                  context: command,
                  target_url: ("https://s3-#{region}.amazonaws.com/" \
                               "#{s3_bucket}/#{commit_ref}" if s3_bucket))
  end

  def set_status
    config
    commands.each do |command|
      create_status(full_name, commit_ref, github_state,
                    description: github_description,
                    context: command)
    end
  end

  def create_progress_status(results, command)
    create_status(results[:failed].to_i > 0 ? 'failure' : 'pending',
                  description: "#{results.inspect} so far at #{Time.now.strftime('%l:%M %P %Z')}.",
                  context: command)
  end

  def status_updater(command)
    loop do
      begin
        results = progress_summary(command)
        create_progress_status(results, command)
        sleep 60
      rescue SignalException
        break
      end
    end
  end

  def fork_status_updater(command)
    Process.fork do
      status_updater(project, full_name, commit_ref, command)
    end
  end
end
