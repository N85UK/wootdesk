# Seeds the compatibility server with invented records only.
#
# Run through: script/compat_env.sh seed
#
# Every value here is fictional. No record is copied from a real Chatwoot
# server, and every address uses an example domain that cannot receive mail.
# Re-running is safe: existing records are reused rather than duplicated.

ACCOUNT_NAME = 'WootDesk Compatibility'.freeze
AGENT_EMAIL = 'compatibility.agent@example.invalid'.freeze
AGENT_NAME = 'Compatibility Agent'.freeze
CONTACT_NAME = 'Avery Example'.freeze
CONTACT_EMAIL = 'avery@example.invalid'.freeze
INBOX_NAME = 'Compatibility Inbox'.freeze
TOKEN_OUTPUT = '/app/storage/wootdesk-compat-token'.freeze

account = Account.find_or_create_by!(name: ACCOUNT_NAME)

agent = User.find_by(email: AGENT_EMAIL)
if agent.nil?
  agent = User.new(
    name: AGENT_NAME,
    display_name: AGENT_NAME,
    email: AGENT_EMAIL,
    password: SecureRandom.hex(24)
  )
  agent.skip_confirmation!
  agent.save!
end

AccountUser.find_or_create_by!(account: account, user: agent) do |account_user|
  # Administrator so the compatibility run can read the account agent and team
  # lists that conversation assignment depends on.
  account_user.role = :administrator
end

channel = Channel::Api.find_or_create_by!(account: account, identifier: 'wootdesk-compat-api') do |api_channel|
  api_channel.webhook_url = nil
end
inbox = Inbox.find_or_create_by!(account: account, channel: channel) do |new_inbox|
  new_inbox.name = INBOX_NAME
end
InboxMember.find_or_create_by!(inbox: inbox, user: agent)

contact = Contact.find_or_create_by!(account: account, email: CONTACT_EMAIL) do |new_contact|
  new_contact.name = CONTACT_NAME
end
contact_inbox = ContactInbox.find_or_create_by!(
  contact: contact,
  inbox: inbox,
  source_id: 'wootdesk-compat-contact-1'
)

conversation = Conversation.find_by(account: account, inbox: inbox, contact: contact)
if conversation.nil?
  conversation = Conversation.create!(
    account: account,
    inbox: inbox,
    contact: contact,
    contact_inbox: contact_inbox,
    assignee: agent,
    status: :open,
    additional_attributes: {}
  )
end

if conversation.messages.count.zero?
  Message.create!(
    account: account, inbox: inbox, conversation: conversation,
    message_type: :incoming, content: 'The sample export stops before it finishes.'
  )
  Message.create!(
    account: account, inbox: inbox, conversation: conversation,
    message_type: :outgoing, sender: agent,
    content: 'Thanks for the clear report. I am checking the sample export job now.'
  )
  Message.create!(
    account: account, inbox: inbox, conversation: conversation,
    message_type: :outgoing, sender: agent, private: true,
    content: 'Internal check: compare the worker timeout with the sample job size.'
  )
  Message.create!(
    account: account, inbox: inbox, conversation: conversation,
    message_type: :incoming,
    content: 'The export still times out when I select the full date range.'
  )
end

# Labels the triage compatibility check adds to and removes from.
%w[billing export engineering].each do |title|
  account.labels.find_or_create_by!(title: title) do |label|
    label.color = '#1F93FF'
    label.show_on_sidebar = true
  end
end
conversation.update_labels(%w[billing]) if conversation.label_list.empty?

token = agent.access_token&.token || AccessToken.find_by(owner: agent)&.token
File.write(TOKEN_OUTPUT, token.to_s)
File.chmod(0o600, TOKEN_OUTPUT)

puts "ACCOUNT_ID=#{account.id}"
puts "CONVERSATION_ID=#{conversation.display_id}"
puts "AGENT_EMAIL=#{AGENT_EMAIL}"
puts "TOKEN_WRITTEN_TO=#{TOKEN_OUTPUT}"
