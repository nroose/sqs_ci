# Module to run test commands
module SqsCiRun
  def run_command(project, full_name, commit_ref, command_array)
    command_array.each_with_index do |command, index|
      start_status(full_name, commit_ref, command)
      secs = Benchmark.realtime do
        pid = Process.pid
        `cd #{project} && echo #{command} > log/output_#{pid}_#{index}.log`
        `cd #{project} && #{command} 2>&1 >> log/output_#{pid}_#{index}.log`
      end
      result = $CHILD_STATUS.success? ? 'success' : 'failure'
      end_status(full_name, commit_ref, result, secs, command)
    end
  end

  def prepare_project(project, commit_ref)
    output =
      `cd #{project} 2>&1 && git fetch 2>&1 && git checkout #{commit_ref} 2>&1`
    fail "Failed to check out project:\n#{output}" unless $CHILD_STATUS.success?
    return unless delete_logs?
    output =
      `cd #{project} 2>&1 && truncate -s 0 log/* 2>&1`
    fail "Failed to truncate logs:\n#{output}" unless $CHILD_STATUS.success?
  end

  def run_commands(project, full_name, commit_ref, commands)
    commands.each do |command|
      Process.fork do
        command_array = command.split('&&')
        set_initial_pending_statuses(command_array, full_name, commit_ref)
        run_command(project, full_name, commit_ref, command_array)
        STDOUT.flush
      end
    end
    Process.waitall
  end

  def run
    config
    project = full_name.split('/').last
    prepare_project(project, commit_ref)
    run_commands(project, full_name, commit_ref, commands)
    save_logs(commit_ref, "#{project}/log")
    `cd #{project} 2>&1 && git checkout - > /dev/null 2>&1`
  end
end
