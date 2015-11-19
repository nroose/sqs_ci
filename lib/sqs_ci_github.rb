module SqsCiGithub
  def github_client
    @github_client ||= Octokit::Client.new(:access_token => ENV["GITHUB_ACCESS_TOKEN"])
  end

  def create_status(repo, sha, state, *optional_params)
    github_client.create_status(repo, sha, state, *optional_params)
  end
end
