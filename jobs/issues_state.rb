require 'json'
require 'time'
require 'dashing'
require 'active_support'
require 'active_support/core_ext'
require File.expand_path('../../lib/helper', __FILE__)

SCHEDULER.every '5m', :first_in => '1s' do |job|
  backend = GithubBackend.new()
  issues = backend.issue_count_by_state_label(
    :orgas=>(ENV['ORGAS'].split(',') if ENV['ORGAS']),
    :repos=>(ENV['REPOS'].split(',') if ENV['REPOS']),
    :since=>ENV['SINCE']
  )

  states = ["no_state", "needs_spec", "needs_design", "ready_for_development", "under_development", "qa"]
  state_counts = {}
  states.each do |state|
    state_counts[state] = issues.select{|issue| issue.type == state}.count
  end
  state_counts["done"] = issues.select{|t| t.key == "closed"}.count
  state_counts["open-issue"] = issues.select{|t| t.key != "closed"}.count

  state_counts.each do |state, count|
    send_event("#{state.gsub('_','-')}-count", { current: count, last: count })
  end

  send_event('progress', { value: ((state_counts["done"].to_f/issues.count.to_f)*100).round(0) })
end
