require 'time'
require 'octokit'
require 'ostruct'
require 'json'
require 'active_support'
require 'active_support/core_ext'
require 'raven'
require_relative 'event'
require_relative 'event_collection'

class GithubBackend
  attr_accessor :logger

  def initialize(args = {})
    @logger = Logger.new(STDOUT)
    @logger.level = Logger::DEBUG unless ENV['RACK_ENV'] == 'production'
  end

  # Returns EventCollection
  def issue_count_by_state_label(opts)
    opts = OpenStruct.new(opts) unless opts.kind_of? OpenStruct
    events = GithubDashing::EventCollection.new

    self.get_repos(opts).each do |repo|
      begin
        milestones = request('list_milestones', [repo, {}])
        current_release = milestones.select{|m| m.state == 'open' && m.due_on.present? }.sort_by{|m| m.due_on}.first.number
        issues = request('issues', [repo, {milestone: current_release, since: opts.since, state: 'all', per_page: 100}])

        issues.reject!{ |issue| issue.milestone.blank?}
        issues.select!{ |issue| issue.milestone.title =~ /36\.2/}
        issues.reject! do |issue|
          issue.pull_request.html_url if issue.pull_request and issue.state == 'open'
        end

        issues.each do |issue|
          state_label = issue.labels.map(&:name).select{|label| label =~ /state/}.first
          state_desc = state_label.present? ? state_label.gsub(/3_state: \d{1,2}/,'').strip.gsub(" ","_") : "no_state"
          events << GithubDashing::Event.new({
            key: issue.state.dup,
            type: "#{state_desc.downcase}",
            state_label: issue.labels.map(&:name),
            repo: repo.gsub('contently/',''),
            milestone: issue.milestone.title,
            value: 1
          })
        end
      rescue Octokit::Error => exception
        Raven.capture_exception(exception)
      end
    end

    return events
  end

  def current_milestone(opts)
    opts = OpenStruct.new(opts) unless opts.kind_of? OpenStruct
    events = GithubDashing::EventCollection.new

    repo = self.get_repos(opts).first

    begin
      milestones = request('list_milestones', [repo, {}])
      current_release = milestones.select{|m| m.state == 'open' && m.due_on.present? }.sort_by{|m| m.due_on}.first
      due_in = (current_release.due_on.beginning_of_day - Time.now.utc.beginning_of_day) / 1.day
      due_at = current_release.due_on.strftime("%A, %e %B %Y")
      event = GithubDashing::Event.new({ title: current_release.title, due_in: due_in, due_at: due_at })
    rescue Octokit::Error => exception
      Raven.capture_exception(exception)
    end

    return event
  end

  # TODO Break up by actual status, currently not looking at closed_at date
  # Returns EventCollection
  def pull_count_by_status(opts)
    opts = OpenStruct.new(opts) unless opts.kind_of? OpenStruct
    events = GithubDashing::EventCollection.new
    self.get_repos(opts).each do |repo|
      begin
        pulls = request('pulls', [repo, {:state => 'all', :since => opts.since}])
        pulls.select! {|pull|pull.created_at.to_datetime > opts.since.to_datetime}
        pulls.each do |pull|
          state_desc = (pull.state == 'open') ? 'opened' : 'closed'
          events << GithubDashing::Event.new({
            type: "pull_count_#{state_desc}",
            datetime: pull.created_at.to_datetime,
            key: pull.state.dup,
            value: 1
          })
        end
      rescue Octokit::Error => exception
        Raven.capture_exception(exception)
      end
    end
    return events
  end

  def user(name)
    request('user', [name])
  end

  def repo_stats(opts)
    # TODO
  end

  def organization_member?(org, user)
    request('organization_member?', [org, user])
  end

  def get_repos(opts)
    opts = OpenStruct.new(opts) unless opts.kind_of? OpenStruct
    repos = []
    if opts.repos != nil
      repos = repos.concat(opts.repos)
    end
    if opts.orgas != nil
      opts.orgas.each do |orga|
        begin
          repos = repos.concat(request('org_repos', [orga, {:type => 'owner'}]).map {|repo|repo.full_name.dup})
        rescue Octokit::Error => exception
          Raven.capture_exception(exception)
        end
      end
    end

    return repos
  end

  # Use a new client for each request, to avoid excessive memory leaks
  # caused by Sawyer middleware (3MB JSON turns into >150MB memory usage)
  def request(method, args)
    client = Octokit::Client.new(
      :login => ENV['GITHUB_LOGIN'],
      :access_token => ENV['GITHUB_OAUTH_TOKEN']
    )
    result = client.send(method, *args) do|request|
      request.options.timeout = 60
      request.options.open_timeout = 60
    end
    client = nil
    GC.start
    Octokit.reset!

    return result
  end

end
