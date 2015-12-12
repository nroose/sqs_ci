# Module to run test commands
module SqsCiRun
  STATUS_CHARACTERS = { passed: '.', failed: 'F', pending: '*', undefined: 'U',
                        skipped: '-' }

  def sanitize_filename(filename)
    filename.strip.gsub(%r{^.*(\|/)}, '').gsub(/[^0-9A-Za-z.]/, '_')
  end

  def create_progress_status(full_name, commit_ref, results, command)
    create_status(full_name, commit_ref,
                  results[:failed].to_i > 0 ? 'failure' : 'pending',
                  description: "#{results.inspect} so far at #{Time.now.strftime('%l:%M %P %Z')}.",
                  context: command)
  end

  def progress_summary(progress)
    Hash[STATUS_CHARACTERS.map { |r, c| [r, progress.count(c)] }]
      .delete_if { |_r, c| c == 0 }
  end

  def status_updater(full_name, commit_ref, command, progress_file)
    loop do
      begin
        progress = File.exist?(progress_file) ? IO.read(progress_file) : ''
        results = progress_summary(progress)
        create_progress_status(full_name, commit_ref, results, command)
        sleep 60
      rescue SignalException
        break
      end
    end
  end

  def fork_status_updater(full_name, commit_ref, command, progress_file)
    project = full_name.split('/').last
    progress_file = "#{project}/#{progress_file}"
    Process.fork do
      status_updater(full_name, commit_ref, command, progress_file)
    end
  end

  def enhance_command(command, log_suffix, full_name, commit_ref)
    type = command[/(cucumber|rspec)/]
    if type
      log = "log/progress_#{log_suffix}"
      output_format = { 'cucumber' => 'pretty', 'rspec' => 'd' }
      extra_opts = " -f progress --out #{log} -f #{output_format[type]}"
      command.sub!(/(cucumber|rspec)/, '\1 ' + extra_opts)
      updater_pid = fork_status_updater(full_name, commit_ref, command, log)
    end
    [command, updater_pid]
  end

  def run_command_detail(project, full_name, commit_ref, command)
    log_suffix = "#{sanitize_filename(command)}_#{Process.pid}.log"
    enhanced_command, updater_pid = enhance_command(command, log_suffix, full_name,
                                                    commit_ref)
    `cd #{project} && #{enhanced_command} 2>&1 >> log/output_#{log_suffix}`
    Process.kill('INT', updater_pid) if updater_pid
  end

  def run_command(project, full_name, commit_ref, command)
    start_status(full_name, commit_ref, command)
    secs = Benchmark.realtime do
      run_command_detail(project, full_name, commit_ref, command)
    end
    result = $CHILD_STATUS.success? ? 'success' : 'failure'
  rescue => e
    puts e
    puts e.backtrace.join "\n" if verbose
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
