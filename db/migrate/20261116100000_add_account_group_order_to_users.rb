class AddAccountGroupOrderToUsers < ActiveRecord::Migration[8.1]
  # Per-user order of the big account groups (depository, investment, …).
  # Empty means the official Accountable::TYPES sequence. Stored on the user,
  # like the manual order of accounts inside a group, so family members can
  # arrange the sidebar independently.
  def change
    add_column :users, :account_group_order, :string, array: true, default: [], null: false
  end
end
