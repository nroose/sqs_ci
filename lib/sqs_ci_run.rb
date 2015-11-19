module SqsCiRun
  def run_command(project, full_name, commit_ref, command_list)
    command_list.split("&&").each do |command|
      create_status(full_name, commit_ref, 'pending',
                    :description => "Starting at #{Time.now}.",
                    :context => command)
      output = ''
      secs = Benchmark.realtime do
        output = `cd #{project} && #{command} && git checkout -`
      end
      status = $?
      mins = secs.to_i / 60
      secs = '%.2f' % (secs % 60)
      time_str = "#{mins}m#{secs}s"

      save_logs(commit_ref, output, "#{project}/log")

      # update status
      result = status.success? ? 'success' : 'failure'

      create_status(full_name, commit_ref,
                    result,
                    :description => "#{result} in #{time_str} at #{Time.now}.",
                    :context => command,
                    :target_url => ("https://s3-#{region}.amazonaws.com/#{s3_bucket}/#{commit_ref}" if s3_bucket))
    end
  end

  def run_commands(project, full_name, commit_ref, commands)
    `cd #{project} && git fetch > /dev/null && git checkout #{commit_ref} > /dev/null`
    commands.each do |command|
      Process.fork do
        puts "Starting #{command}"
        run_command(project, full_name, commit_ref, command)
        puts "Finished #{command}"
      end
    end
    Process.wait
    `git checkout - > /dev/null`
  end

  def run
    config
    project = full_name.split("/").last
    run_commands(project, full_name, commit_ref, commands)
  end
end
