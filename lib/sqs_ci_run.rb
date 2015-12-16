# Module to run test commands
module SqsCiRun
  STATUS_CHARACTERS = { passed: '.', failed: 'F', pending: '*', undefined: 'U',
                        skipped: '-' }

  def sanitize_filename(filename)
    filename.strip.gsub(%r{^.*(\|/)}, '').gsub(/[^0-9A-Za-z.]/, '_')
  end

  def log_suffix(command)
    "#{sanitize_filename(command)}.log"
  end

  def log_name(command)
    "log/output_#{log_suffix(command)}"
  end

  def progress_log(command)
    "log/progress_#{log_suffix(command)}"
  end

  def progress_file(command)
    "#{project}/log/progress_#{log_suffix(command)}"
  end

  def progress_summary(command)
    file = progress_file(command)
    progress = File.exist?(file) ? IO.read(file) : ''
    Hash[STATUS_CHARACTERS.map { |r, c| [r, progress.count(c)] }]
      .delete_if { |_r, c| c == 0 }
  end

  def enhance_command(command)
    type = command[/(cucumber|rspec)/]
    if type
      output_format = { 'cucumber' => 'pretty', 'rspec' => 'd' }
      extra_opts = " -f progress --out #{progress_log(command)} -f #{output_format[type]}"
      enhanced_command = command.sub(/(cucumber|rspec)/, '\1 ' + extra_opts)
      updater_pid = fork_status_updater(command)
    end
    [enhanced_command, updater_pid]
  end

  def run_command_detail(command)
    enhanced_command, updater_pid = enhance_command(command)
    shell_command = "cd #{project} && #{enhanced_command} 2>&1 >> #{log_name(command)}"
    puts shell_command if verbose
    `#{shell_command}`
    Process.kill('INT', updater_pid) if updater_pid
    progress_summary(command)
  end

  def run_command(command)
    start_status(command)
    secs = Benchmark.realtime do
      run_command_detail(command)
    end
    result = $CHILD_STATUS.success? ? 'success' : 'failure'
  rescue => e
    puts e
    puts e.backtrace.join "\n" if verbose
  ensure
    end_status(result, secs, command, progress_summary(command))
  end

  def run_command_array(command_array)
    command_array.each do |command|
      run_command(command)
    end
  end

  def prepare_project
    output =
      `cd #{project} 2>&1 && git fetch 2>&1 && git checkout #{commit_ref} 2>&1`
    fail "Failed to check out project:\n#{output}" unless $CHILD_STATUS.success?
    return unless delete_logs?
    output =
      `cd #{project} 2>&1 && truncate -s 0 log/* 2>&1`
    fail "Failed to truncate logs:\n#{output}" unless $CHILD_STATUS.success?
  end

  def run_commands
    commands.each do |command|
      Process.fork do
        command_array = command.split('&&')
        initial_pending_statuses(command_array)
        run_command_array(command_array)
        STDOUT.flush
      end
    end
    Process.waitall
  end

  def run
    config
    prepare_project
    run_commands
    save_logs
  rescue => e
    puts e
    puts e.backtrace.join "\n" if verbose
  ensure
    `cd #{project} 2>&1 && git checkout - > /dev/null 2>&1`
  end
end
