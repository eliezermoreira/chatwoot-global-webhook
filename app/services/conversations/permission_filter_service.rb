class Conversations::PermissionFilterService
  attr_reader :conversations, :user, :account
  
  def initialize(conversations, user, account)
    @conversations = conversations
    @user = user
    @account = account
  end
  
  def perform
    return conversations if user_role == 'administrator'
    accessible_conversations
  end
  
  private
  
  def accessible_conversations
    filtered = conversations.where(inbox: user.inboxes.where(account_id: account.id))
    
    # Agent só vê conversas atribuídas a ele
    if user_role == 'agent'
      filtered = filtered.where(assignee_id: user.id)
    end
    
    filtered
  end
  
  def account_user
    AccountUser.find_by(account_id: account.id, user_id: user.id)
  end
  
  def user_role
    account_user&.role
  end
end

Conversations::PermissionFilterService.prepend_mod_with('Conversations::PermissionFilterService')
