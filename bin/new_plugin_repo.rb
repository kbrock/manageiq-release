#!/usr/bin/env ruby

require "bundler/inline"
gemfile do
  source "https://rubygems.org"
  gem "multi_repo", require: "multi_repo/cli", path: File.expand_path("~/dev/multi_repo")
end

opts = Optimist.options do
  opt :plugin, "Whether or not this is a ManageIQ plugin", :type => :boolean, :required => true

  MultiRepo::CLI.common_options(self, :except => :repo_set)
end

repo_name = opts[:repo].first
repo = MultiRepo::CLI.repo_for(repo_name)

has_repo = !opts[:plugin] || MultiRepo::RepoSet.config["master"].include?(repo_name)
has_labels = MultiRepo::Labels.config["repos"][repo.name]
unless has_repo && has_labels
  STDERR.puts "ERROR: First update config/repos.yml and config/labels.yml with the new repo"
  exit 1
end

puts "\n** Updating Repo Settings"
MultiRepo::Helper::UpdateRepoSettings.new(repo.name, **opts).run
puts "\n** Updating Branch Protection"
MultiRepo::Helper::UpdateBranchProtection.new(repo.name, **opts.merge(:branch => "master")).run
puts "\n** Updating Labels"
MultiRepo::Helper::UpdateLabels.new(repo.name, **opts).run
puts "\n** Reserve rubygems entry"
if opts[:plugin]
  MultiRepo::Helper::RubygemsStub.new(repo.name, **opts).run
end

puts "\n** Preparing Pull Request"
MultiRepo::Helper::PullRequestBlasterOuter.new(repo, **opts.merge(
  :base    => "master",
  :head    => "new_plugin_repo",
  :script  => "scripts/pull_request_blaster_outer/new_plugin_repo.rb",
  :message => "Prepare new repository"
)).blast

puts
puts "******* MANUAL THINGS *******"
puts "- Add repo to repos.sets.yml if this is a new core or provider plugin"
puts "- Add repo to mirror settings"
puts "- https://codeclimate.com/github/#{repo.name} => Repo Settings => GitHub => Pull Request Status Updates => Install"
puts "  - Ensure that CC_TEST_REPORTER_ID is set in the repo settings"
puts "- https://gitter.im/ManageIQ#createroom and create a new room linked to the repository"
puts "- Add repo to the bot"
puts "  - Also add repo to the bot settings"
