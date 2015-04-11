#!/usr/bin/env ruby
require 'faraday'

servers = [
  {
    name: 'Rza',
    url: 'http://rza-production.elasticbeanstalk.com/stats',
    auth: 'basic',
    user: ENV['RZA_USER'],
    pass: ENV['RZA_PASS']
  },
  {
    name: 'ES Master 1',
    url: 'insights-cluster-master-1.contentlycontrol.com/status',
    auth: 'basic',
    user: ENV['ES_USER'],
    pass: ENV['ES_PASS']
  },
  {
    name: 'ES Master 2',
    url: 'insights-cluster-master-2.contentlycontrol.com/status',
    auth: 'basic',
    user: ENV['ES_USER'],
    pass: ENV['ES_PASS']
  }
]

SCHEDULER.every '300s', :first_in => 0 do |job|
  statuses = Array.new

  # check status for each server
  servers.each do |server|

    conn = Faraday.new(url: server[:url])
    conn.basic_auth(server[:user], server[:pass]) if server[:auth]

    request = conn.get
    binding.remote_pry

    if request.status == 200
      result = 1
    else
      result = 0
    end

    if result == 1
      arrow = "icon-ok-sign"
      color = "green"
    else
      arrow = "icon-warning-sign"
      color = "red"
    end

    statuses.push({label: server[:name], value: result, arrow: arrow, color: color})
  end

  binding.remote_pry
  # print statuses to dashboard
  send_event('uptime-check', {items: statuses})
end
