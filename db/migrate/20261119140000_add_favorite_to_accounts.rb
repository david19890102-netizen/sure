class AddFavoriteToAccounts < ActiveRecord::Migration[8.1]
  # Family-wide flag, like `hidden`. A favorite stays in its group and still
  # follows the saved group order; the sidebar and accounts page also list it
  # in a quick view. Existing rows default to not favorite.
  def change
    add_column :accounts, :favorite, :boolean, default: false, null: false
  end
end
