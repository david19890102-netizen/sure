class AddBudgetBooks < ActiveRecord::Migration[8.1]
  def up
    add_column :categories, :budget_book, :string, default: "personal", null: false
    add_column :budgets, :book, :string, default: "personal", null: false
    add_check_constraint :categories, "budget_book IN ('personal', 'family')", name: "categories_budget_book_check"
    add_check_constraint :budgets, "book IN ('personal', 'family')", name: "budgets_book_check"

    remove_period_indexes
    add_period_indexes(:book)
  end

  def down
    if select_value("SELECT EXISTS (SELECT 1 FROM budgets WHERE book = 'family')")
      raise ActiveRecord::IrreversibleMigration, "另存家人預算及其分類金額後，才能還原單本預算的結構。"
    end

    remove_period_indexes
    add_period_indexes
    remove_check_constraint :budgets, name: "budgets_book_check"
    remove_check_constraint :categories, name: "categories_budget_book_check"
    remove_column :budgets, :book
    remove_column :categories, :budget_book
  end

  private
    def remove_period_indexes
      remove_index :budgets, name: "index_budgets_personal_unique"
      remove_index :budgets, name: "index_budgets_shared_unique"
    end

    def add_period_indexes(*partition)
      period = [ :family_id, :start_date, :end_date, *partition ]
      add_index :budgets, [ *period, :user_id ], name: "index_budgets_personal_unique", unique: true, where: "user_id IS NOT NULL"
      add_index :budgets, period, name: "index_budgets_shared_unique", unique: true, where: "user_id IS NULL"
    end
end
