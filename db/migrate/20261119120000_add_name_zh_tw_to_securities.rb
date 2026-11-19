class AddNameZhTwToSecurities < ActiveRecord::Migration[8.1]
  # Chinese short name for a Taiwan listing. Nullable and separate from `name`,
  # which price providers overwrite with the English legal name. Existing rows
  # stay null until the open-data catalog fills them.
  def change
    add_column :securities, :name_zh_tw, :string
  end
end
