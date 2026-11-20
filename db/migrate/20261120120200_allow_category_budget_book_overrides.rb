class AllowCategoryBudgetBookOverrides < ActiveRecord::Migration[8.1]
  def up
    change_column_null :categories, :budget_book, true
    change_column_default :categories, :budget_book, from: "personal", to: nil
    execute "UPDATE categories SET budget_book = NULL WHERE parent_id IS NOT NULL"
  end

  def down
    change_column_default :categories, :budget_book, from: nil, to: "personal"
    change_column_null :categories, :budget_book, false, "personal"
  end
end
