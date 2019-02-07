# Slack chat plugin for Redmine

This plugin posts updates to issues in your Redmine to a Slack user.

## Installation

From your Redmine plugins directory, clone this repository as `redmine_user_slack` (note
the underscore!):

    git clone https://github.com/ujin77/redmine_user_slack.git redmine_user_slack

You will also need the `httpclient` dependency, which can be installed by running

    bundle install
	bundle exec rake redmine:plugins:migrate NAME=redmine_user_slack RAILS_ENV=production
	touch tmp/restart.txt

from the plugin directory.

Restart Redmine, and you should see the plugin show up in the Plugins page.
Under the configuration options, set the Slack API URL to the URL for an
Incoming WebHook integration in your Slack account.

## Uninstall

	bundle exec rake redmine:plugins:migrate NAME=redmine_user_slack VERSION=0 RAILS_ENV=production
