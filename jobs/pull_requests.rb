require 'json'
require 'time'
require 'dashing'
require File.expand_path('../../lib/helper', __FILE__)


SCHEDULER.every '10m', first_in: '1s' do |job|
  backend = GithubBackend.new()
  series = [[],[]]
  open_pulls = backend.pull_count_by_status(
    :period=>'month',
    :orgas=>(ENV['ORGAS'].split(',') if ENV['ORGAS']),
    :repos=>(ENV['REPOS'].split(',') if ENV['REPOS']),
    :since=>ENV['SINCE'],
  )
  send_event('open-pr-count', { current: open_pulls.count })

  title_limit = 24
  list_items = open_pulls.map do |pr|
    title = pr.title
    title = "#{title[0..title_limit]}…" if title.length > title_limit

    {label: title, value: pr.key}
  end
  send_event('open-prs', { items: list_items[0..8], moreinfo: "#{list_items.count} open pull request#{'s' if list_items.count > 1}"})
end
