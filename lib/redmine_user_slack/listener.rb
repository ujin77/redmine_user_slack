require 'httpclient'

class SlackListener < Redmine::Hook::Listener
	def redmine_user_slack_issues_new_after_save(context={})
		issue = context[:issue]

		Rails.logger.info "  SLACK: new issue notify"

		ucf = UserCustomField.find_by_name("Slack")

		return if ucf.nil?

		msg_created = I18n.t("redmine_user_slack_message_created")

		msg = "[<#{object_url issue.project}|#{escape issue.project}>] - #{escape msg_created}: <#{object_url issue}|#{escape issue}> (#{escape issue.author})"

		attachment = {}
		attachment[:text] = escape issue.description if issue.description
		attachment[:fields] = [{
			:title => I18n.t("field_status"),
			:value => escape(issue.status.to_s),
			:short => true
		}, {
			:title => I18n.t("field_priority"),
			:value => escape(issue.priority.to_s),
			:short => true
		}]
		attachment[:fields] << {
			:title => I18n.t("field_assigned_to"),
			:value => escape(issue.assigned_to.to_s),
			:short => true			
		} if not issue.assigned_to.nil?
		attachment[:fields] << {
			:title => I18n.t("field_watcher"),
			:value => escape(issue.watcher_users.join(', ')),
			:short => true
		} if Setting.plugin_redmine_user_slack['display_watchers'] == 'yes' and not issue.watcher_users.empty?

	    users = issue.notified_users | issue.notified_watchers
	    users.each do |user|
    		channel = user.custom_value_for(ucf).value if user.custom_value_for(ucf)
		    if channel=~ %r{^[#@][a-z0-9_\-]+}i
				Rails.logger.info "  SLACK: new issue notify: #{user.login}: #{channel}"
				speak msg, channel, attachment
		    end
	    end
	end

	def redmine_user_slack_issues_edit_after_save(context={})
		issue = context[:issue]
		journal = context[:journal]
		Rails.logger.info "  SLACK: edit issue notify"

		ucf = UserCustomField.find_by_name("Slack")

		return if ucf.nil?

		msg_updated = I18n.t("redmine_user_slack_message_updated")

		msg = "[<#{object_url issue.project}|#{escape issue.project}>] <#{object_url issue}|#{escape issue}> - #{escape msg_updated} (#{escape journal.user.to_s})"
		attachment = {}
		attachment[:text] = escape journal.notes if journal.notes
		attachment[:fields] = journal.details.map { |d| detail_to_field d }

        users  = journal.notified_users | journal.notified_watchers
	    users.select! do |user|
    	  journal.notes? || journal.visible_details(user).any?
    	end
    	users.each do |user|
    		channel = user.custom_value_for(ucf).value if user.custom_value_for(ucf)
		    if channel=~ %r{^[#@][a-z0-9_\-]+}i
				Rails.logger.info "  SLACK: issue edit notify: #{user.login}: #{channel}"
				speak msg, channel, attachment
		    end
    	end
	end

	def speak(msg, channel, attachment=nil)
		url = Setting.plugin_redmine_user_slack['slack_url']
		username = Setting.plugin_redmine_user_slack['username']

		params = {
			:text => msg,
			:link_names => 1,
		}

		params[:username] = username if username
		params[:channel] = channel if channel
		params[:attachments] = [attachment] if attachment

		# Rails.logger.info params.to_json

		begin
			client = HTTPClient.new
			client.ssl_config.cert_store.set_default_paths
			client.ssl_config.ssl_version = :auto
			client.post_async url, {:payload => params.to_json}
		rescue Exception => e
			Rails.logger.warn("cannot connect to #{url}")
			Rails.logger.warn(e)
		end
	end

private
	def escape(msg)
		msg.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
	end

	def object_url(obj)
		if Setting.host_name.to_s =~ /\A(https?\:\/\/)?(.+?)(\:(\d+))?(\/.+)?\z/i
			host, port, prefix = $2, $4, $5
			Rails.application.routes.url_for(obj.event_url({
				:host => host,
				:protocol => Setting.protocol,
				:port => port,
				:script_name => prefix
			}))
		else
			Rails.application.routes.url_for(obj.event_url({
				:host => Setting.host_name,
				:protocol => Setting.protocol
			}))
		end
	end

	def detail_to_field(detail)
		if detail.property == "cf"
			key = CustomField.find(detail.prop_key).name rescue nil
			title = key
		elsif detail.property == "attachment"
			key = "attachment"
			title = I18n.t :label_attachment
		else
			key = detail.prop_key.to_s.sub("_id", "")
			if key == "parent"
				title = I18n.t "field_#{key}_issue"
			else
				title = I18n.t "field_#{key}"
			end
		end

		short = true
		value = escape detail.value.to_s

		case key
		when "title", "subject", "description"
			short = false
		when "tracker"
			tracker = Tracker.find(detail.value) rescue nil
			value = escape tracker.to_s
		when "project"
			project = Project.find(detail.value) rescue nil
			value = escape project.to_s
		when "status"
			status = IssueStatus.find(detail.value) rescue nil
			value = escape status.to_s
		when "priority"
			priority = IssuePriority.find(detail.value) rescue nil
			value = escape priority.to_s
		when "category"
			category = IssueCategory.find(detail.value) rescue nil
			value = escape category.to_s
		when "assigned_to"
			user = User.find(detail.value) rescue nil
			value = escape user.to_s
		when "fixed_version"
			version = Version.find(detail.value) rescue nil
			value = escape version.to_s
		when "attachment"
			attachment = Attachment.find(detail.prop_key) rescue nil
			value = "<#{object_url attachment}|#{escape attachment.filename}>" if attachment
		when "parent"
			issue = Issue.find(detail.value) rescue nil
			value = "<#{object_url issue}|#{escape issue}>" if issue
		end

		value = "-" if value.empty?

		result = { :title => title, :value => value }
		result[:short] = true if short
		result
	end

end
