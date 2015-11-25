# Module for sending status updates to github
module SqsCiGithub
  def github_client
    @github_client ||=
      Octokit::Client.new(access_token: ENV['GITHUB_ACCESS_TOKEN'])
  end

  def create_status(repo, sha, state, *optional_params)
    github_client.create_status(repo, sha, state, *optional_params)
  end

  def set_initial_pending_statuses(commands, full_name, commit_ref)
    commands.each do |command|
      create_status(full_name, commit_ref, 'pending',
                    description: "Pending at #{Time.now}.",
                    context: command)
    end
  end

  def start_status(full_name, commit_ref, command)
    create_status(full_name, commit_ref, 'pending',
                  description: "Starting at #{Time.now}.",
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

  def end_status(full_name, commit_ref, result, secs, command)
    description = "#{time_str(secs)} at #{Time.now}"
    result ||= 'error'
    log_status(command, result, description)
    create_status(full_name, commit_ref, result,
                  description: description,
                  context: command,
                  target_url: ("https://s3-#{region}.amazonaws.com/" \
                               "#{s3_bucket}/#{commit_ref}" if s3_bucket))
  end
end
