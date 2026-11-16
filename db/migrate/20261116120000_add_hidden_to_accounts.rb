class AddHiddenToAccounts < ActiveRecord::Migration[8.1]
  # Family-wide flag (upstream we-promise/sure#5124). A hidden account keeps
  # syncing and still counts in net worth and reports; it is only left out of
  # the sidebar and the account pickers.
  def change
    add_column :accounts, :hidden, :boolean, default: false, null: false
  end
end
