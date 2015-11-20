module SqsCiRun
  def run_command(project, full_name, commit_ref, command_list)
    command_list.split("&&").each do |command|
      create_status(full_name, commit_ref, 'pending',
                    :description => "Pending at #{Time.now}.",
                    :context => command)
    end
    command_list.split("&&").each do |command|
      create_status(full_name, commit_ref, 'pending',
                    :description => "Starting at #{Time.now}.",
                    :context => command)
      secs = Benchmark.realtime do
        `cd #{project} && #{command} >> log/output.log 2>&1`
      end
      status = $?
      mins = secs.to_i / 60
      secs = '%.0f' % (secs % 60)
      time_str = "#{mins}m#{secs}s"

      # update status
      result = status.success? ? 'success' : 'failure'
      print result[0]

      create_status(full_name, commit_ref,
                    result,
                    :description => "#{result} in #{time_str} at #{Time.now}.",
                    :context => command,
                    :target_url => ("https://s3-#{region}.amazonaws.com/#{s3_bucket}/#{commit_ref}" if s3_bucket))
    end
  end

  def run_commands(project, full_name, commit_ref, commands)
    output = `cd #{project} 2>&1 && git fetch 2>&1 && git checkout #{commit_ref} 2>&1`
    status = $?
    fail "Failed to check out project:\n#{output}" unless status.success?
    `cd #{project} 2>&1 && rm -rf log/*` if delete_logs?
    commands.each do |command|
      Process.fork do
        run_command(project, full_name, commit_ref, command)
        STDOUT.flush
      end
    end
    STDOUT.flush
    Process.waitall
    puts ""
    save_logs(commit_ref, "#{project}/log")
    `git checkout - > /dev/null 2>&1`
  end

  def run
    config
    project = full_name.split("/").last
    run_commands(project, full_name, commit_ref, commands)
  end
end
