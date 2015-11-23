# Module to run test commands
module SqsCiRun
  def run_command(project, full_name, commit_ref, command_list)
    commands = command_list.split('&&')
    set_initial_pending_statuses(commands, full_name, commit_ref)

    commands.each do |command|
      start_status(full_name, commit_ref, command)
      secs = Benchmark.realtime do
        `cd #{project} && #{command} 2>&1 log/output.log`
      end
      description = "#{result} in #{time_str(secs)} at #{Time.now}."
      end_status(full_name, commit_ref, $CHILD_STATUS, description)
    end
  end

  def prepare_project(project, commit_ref)
    output =
      `cd #{project} 2>&1 && git fetch 2>&1 && git checkout #{commit_ref} 2>&1`
    status = $CHILD_STATUS
    fail "Failed to check out project:\n#{output}" unless status.success?
    `cd #{project} 2>&1 && rm -rf log/*` if delete_logs?
  end

  def run_commands(project, full_name, commit_ref, commands)
    prepare_project(project, commit_ref)
    commands.each do |command|
      Process.fork do
        run_command(project, full_name, commit_ref, command)
        STDOUT.flush
      end
    end
    Process.waitall
    save_logs(commit_ref, "#{project}/log")
    `git checkout - > /dev/null 2>&1`
  end

  def run
    config
    project = full_name.split('/').last
    run_commands(project, full_name, commit_ref, commands)
  end
end
