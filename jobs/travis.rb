require 'json'
require 'time'
require 'dashing'
require 'net/https'
require 'cgi'
require File.expand_path('../../lib/travis_backend', __FILE__)

SCHEDULER.every '1h', :first_in => '1s' do |job|
	backend = TravisBackend.new
	repo_slugs = []
	builds = []
	# Only look at release branches (x.y) and master, not at tags (x.y.z)
	branch_whitelist = /^(\d+\.\d+$|master)/
	repo_slug_replacements = [/(silverstripe-labs\/|silverstripe\/|silverstripe-)/,'']

	if ENV['ORGAS']
		ENV['ORGAS'].split(',').each do |orga|
			repo_slugs = repo_slugs.concat(backend.get_repos_by_orga(orga).collect{|repo|repo['slug']})
		end
	end
	
	if ENV['REPOS']
		repo_slugs.concat(ENV['REPOS'].split(','))
	end

	repo_slugs.sort!

	items = repo_slugs.map do |repo_slug|
		repo_branches = backend.get_branches_by_repo(repo_slug)
		label = repo_slug
		label = repo_slug.gsub(repo_slug_replacements[0],repo_slug_replacements[1]) if repo_slug_replacements
		if repo_branches and repo_branches['branches'].length > 0
			# Latest builds are listed under "branches", but their corresponding branch name
			# is stored through the "commits" association
			items = repo_branches['branches']
				.select do |branch|
					commit = repo_branches['commits'].find{|commit|commit['id'] == branch['commit_id']}
					branch_name = commit['branch']
					branch_whitelist.match(branch_name)
				end
				.map do |branch|
					commit = repo_branches['commits'].find{|commit|commit['id'] == branch['commit_id']}
					branch_name = commit['branch']
					{
						'class'=>(branch['state'] == "passed") ? 'good' : 'bad', # POSIX return code
						'label'=>branch_name,
						'title'=>branch['finished_at'],
						'result'=>branch['state'],
						'url'=> 'https://travis-ci.org/%s/builds/%d' % [repo_slug,branch['id']]
					} 
				end
			{
				'label'=>label,
				'class'=> (items.find{|b|b['result'] != 'passed'}) ? 'bad' : 'good', # POSIX return code
				'url' => items.count ? 'https://travis-ci.org/%s' % repo_slug : '',
				'items' => items
			}
		else
			{
				'label'=>label,
				'class'=> 'none',
				'url' => '',
				'items' => []
			}
		end
	end

	items.sort_by! do|item|
		if item['class'] == 'bad'
			1
		elsif item['class'] == 'good'
			2
		else
			3
		end
	end
	
	send_event('travis', {
		unordered: true,
		items: items
	})
end