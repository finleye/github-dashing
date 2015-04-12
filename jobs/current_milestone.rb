require 'json'
require 'time'
require 'dashing'
require 'active_support'
require 'active_support/core_ext'
require File.expand_path('../../lib/helper', __FILE__)

SCHEDULER.every '4h', first_in: '1s' do |job|
  backend = GithubBackend.new
  current_milestone = backend.current_milestone(
    orgas: (ENV['ORGAS'].split(',') if ENV['ORGAS']),
    repos: (ENV['REPOS'].split(',') if ENV['REPOS']),
    since: ENV['SINCE']
  )

  header_text = "#{current_milestone.title} due in #{current_milestone.due_in.to_i} day#{'s' if current_milestone.due_in.to_i > 1}"
  due_date = "Due on #{current_milestone.due_at}"
  send_event('header', text: header_text, moreinfo: due_date)
end
