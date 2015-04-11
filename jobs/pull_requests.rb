require 'json'
require 'time'
require 'dashing'
require File.expand_path('../../lib/helper', __FILE__)


SCHEDULER.every '1h', :first_in => '1s' do |job|
  backend = GithubBackend.new()
  series = [[],[]]
  pulls_by_period = backend.pull_count_by_status(
    :period=>'month',
    :orgas=>(ENV['ORGAS'].split(',') if ENV['ORGAS']),
    :repos=>(ENV['REPOS'].split(',') if ENV['REPOS']),
    :since=>ENV['SINCE'],
  )
  open_pr_count = pulls_by_period.select{|pr| pr.type == "pull_count_opened"}.count
  send_event('open-pr-count', { current: open_pr_count })
end
