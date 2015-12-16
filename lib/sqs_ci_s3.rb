# Module to send files to s3.
module SqsCiS3
  def save_logs
    STDOUT.flush
    puts ''
    return unless s3_bucket
    s3 = Aws::S3::Resource.new(region: 'us-west-2')
    obj = s3.bucket(s3_bucket).object(commit_ref)
    files = Dir.new "#{project}/log"
    upload_files(files, obj)
  end

  def upload_files(files, obj)
    files.each do |file|
      begin
        obj.upload_file(file)
      rescue
        puts "Could not upload #{file}"
      end
    end
  end
end
