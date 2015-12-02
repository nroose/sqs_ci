# Module to run test commands
module SqsCiRun
  def sanitize_filename(filename)
    filename.strip.gsub(%r{^.*(\|/)}, '').gsub(/[^0-9A-Za-z.\-]/, '_')
  end

  def fork_status_updater(full_name, commit_ref, command, progress_file)
    Process.fork do
      progress = IO.read(progress_file)
      create_status(full_name, commit_ref, "pending",
                    description: "#{progress.count('.')} passed, " \
                                 "#{progress.count('F')} failed, " \
                                 "#{progress.count('*')} pending, " \
                                 "#{progress.count('U')} undefined, " \
                                 "#{progress.count('-')} skipped so far.",
                    context: command)
    end
  end

  def run_command_detail(project, full_name, commit_ref, command)
    log_suffix = "#{sanitize_filename(command)}_#{Process.pid}.log"
    output_format = { 'cucumber' => 'pretty', 'rspec' => 'd' }
    if command == 'cucumber' || command == 'rspec'
      log = "log/progress_#{log_suffix}"
      extra_opts = " -f progress --out #{log} -f #{output_format[command]}"
      updater_pid = fork_status_updater(full_name, commit_ref, command, log)
    end
    `cd #{project} && #{command} #{extra_opts} 2>&1 >> log/output_#{log_suffix}`
    Process.kill(updater_pid) if updater_pid
  end

  def run_command(project, full_name, commit_ref, command)
    start_status(full_name, commit_ref, command)
    secs = Benchmark.realtime do
      run_command_detail(project, full_name, commit_ref, command)
    end
    result = $CHILD_STATUS.success? ? 'success' : 'failure'
  rescue => e
    puts e
  ensure
    end_status(full_name, commit_ref, result, secs, command)
  end

  def run_command_array(project, full_name, commit_ref, command_array)
    command_array.each do |command|
      run_command(project, full_name, commit_ref, command)
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
        run_command_array(project, full_name, commit_ref, command_array)
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
  rescue => e
    puts e
  ensure
    `cd #{project} 2>&1 && git checkout - > /dev/null 2>&1`
  end
end
