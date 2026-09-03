# Seeds the App Review environment with invented records and a reviewer login.
#
# Every value is fictional. Nothing here is copied from a real Chatwoot server,
# and every address uses an example domain that cannot receive mail.
#
# Unlike the compatibility seed, this creates an agent with a known password,
# because an Apple reviewer needs to sign in to Chatwoot to see the environment
# and to obtain the access token WootDesk asks for.

ACCOUNT_NAME = 'WootDesk Demo Support'.freeze
AGENT_EMAIL = ENV.fetch('REVIEW_AGENT_EMAIL')
AGENT_PASSWORD = ENV.fetch('REVIEW_AGENT_PASSWORD')
AGENT_NAME = 'Demo Agent'.freeze
INBOX_NAME = 'Demo Support Inbox'.freeze

account = Account.find_or_create_by!(name: ACCOUNT_NAME)

agent = User.find_by(email: AGENT_EMAIL)
if agent.nil?
  agent = User.new(name: AGENT_NAME, display_name: AGENT_NAME,
                   email: AGENT_EMAIL, password: AGENT_PASSWORD)
  agent.skip_confirmation!
  agent.save!
else
  agent.password = AGENT_PASSWORD
  agent.save!
end

AccountUser.find_or_create_by!(account: account, user: agent) do |account_user|
  account_user.role = :administrator
end

channel = Channel::Api.find_or_create_by!(account: account, identifier: 'wootdesk-review-api')
inbox = Inbox.find_or_create_by!(account: account, channel: channel) do |new_inbox|
  new_inbox.name = INBOX_NAME
end
InboxMember.find_or_create_by!(inbox: inbox, user: agent)

# Three conversations so a reviewer sees a list rather than a single row, and
# can exercise status filtering.
[
  ['Avery Example', 'avery@example.invalid', 'review-contact-1', :open,
   'The sample export stops before it finishes.',
   'Thanks for the clear report. I am checking the export job now.'],
  ['Blake Sample', 'blake@example.invalid', 'review-contact-2', :open,
   'Could you confirm which plan includes the audit log?',
   'The audit log is included from the Standard plan upwards.'],
  ['Casey Invented', 'casey@example.invalid', 'review-contact-3', :resolved,
   'My invoice address needs updating before the next renewal.',
   'Updated, and the next invoice will show the new address.']
].each do |name, email, source, status, incoming, outgoing|
  contact = Contact.find_or_create_by!(account: account, email: email) { |c| c.name = name }
  contact_inbox = ContactInbox.find_or_create_by!(contact: contact, inbox: inbox, source_id: source)
  conversation = Conversation.find_by(account: account, inbox: inbox, contact: contact)
  if conversation.nil?
    conversation = Conversation.create!(
      account: account, inbox: inbox, contact: contact,
      contact_inbox: contact_inbox, assignee: agent, status: status,
      additional_attributes: {}
    )
  end
  next unless conversation.messages.count.zero?

  Message.create!(account: account, inbox: inbox, conversation: conversation,
                  message_type: :incoming, content: incoming)
  Message.create!(account: account, inbox: inbox, conversation: conversation,
                  message_type: :outgoing, sender: agent, content: outgoing)
  Message.create!(account: account, inbox: inbox, conversation: conversation,
                  message_type: :outgoing, sender: agent, private: true,
                  content: 'Internal note: invented example for App Review only.')
end

%w[billing export engineering].each do |title|
  account.labels.find_or_create_by!(title: title) do |label|
    label.color = '#1F93FF'
    label.show_on_sidebar = true
  end
end

token = agent.access_token&.token || AccessToken.find_by(owner: agent)&.token
File.write('/app/storage/review-token', token.to_s)
File.chmod(0o600, '/app/storage/review-token')

puts "ACCOUNT_ID=#{account.id}"
puts "ACCOUNT_NAME=#{ACCOUNT_NAME}"
puts "AGENT_EMAIL=#{AGENT_EMAIL}"
puts "CONVERSATIONS=#{account.conversations.count}"
