require 'redmine'

require_dependency 'redmine_user_slack/listener'

Redmine::Plugin.register :redmine_user_slack do
	name 'Redmine issue Slack notifier'
	author 'Eugene M.'
	url 'https://github.com/ujin77/redmine_user_slack'
	author_url 'https://github.com/ujin77'
	description 'Posts updates to issues in your Redmine to a Slack user'
	version '0.1'

	requires_redmine :version_or_higher => '2.0.0'

	settings \
		:default => {
			'callback_url' => 'http://slack.com/callback/',
			'username' => 'Redmine',
			'display_watchers' => 'yes'
		},
		:partial => 'settings/slack_settings'
end

Rails.application.config.to_prepare do
	require_dependency 'issue'
	unless Issue.included_modules.include? RedmineUserSlack::IssuePatch
		Issue.send(:include, RedmineUserSlack::IssuePatch)
	end
	if UserCustomField.find_by_name("Slack").nil?
		Rails.logger.info "Plugin redmine_user_slack: create UserCustomField Slack" if Rails.logger
		UserCustomField.create(:name => "Slack", :field_format => 'string', :regexp => "^[#@][a-zA-Z0-9_\-]+$") if UserCustomField.find_by_name("Slack").nil?
	end
	Rails.logger.info "Plugin redmine_user_slack: INIT" if Rails.logger
end
