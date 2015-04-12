#!/usr/bin/env ruby
require 'faraday'

servers = [
  {
    name: 'Rza',
    url: 'http://rza-production.elasticbeanstalk.com/stats',
    path: '/stats',
    auth: 'basic',
    user: ENV['RZA_USER'],
    pass: ENV['RZA_PASS']
  },
  {
    name: 'ES Master 1',
    url: 'http://insights-cluster-master-1.contentlycontrol.com:8080',
    path: '/_status',
    auth: 'basic',
    user: ENV['ES_USER'],
    pass: ENV['ES_PASS']
  },
  {
    name: 'ES Master 2',
    url: 'http://insights-cluster-master-2.contentlycontrol.com:8080',
    path: '/_status',
    auth: 'basic',
    user: ENV['ES_USER'],
    pass: ENV['ES_PASS']
  },
  {
    name: 'Contently.com',
    url: 'https://contently.com',
    path: '/'
  },
  {
    name: 'Platform Signin',
    url: 'https://contently.com',
    path: '/signin'
  }
]

SCHEDULER.every '2m', first_in: '0s' do |job|
  statuses = []

  servers.each do |server|
    begin
      conn = Faraday.new(url: server[:url])
      conn.basic_auth(server[:user], server[:pass]) if server[:auth] == 'basic'
      request = conn.get server[:path]
      result = (request.status == 200) ? 1 : 0
    rescue => e

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
  send_event('server-status', {items: statuses})
end
