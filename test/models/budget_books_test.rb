require "test_helper"

class BudgetBooksTest < ActiveSupport::TestCase
  setup do
    @family = families(:empty)
    @account = @family.accounts.create!(name: "Test bank", balance: 100, currency: "USD", accountable: Depository.new)
    @personal = @family.categories.create!(name: "Test personal")
    @family_parent = @family.categories.create!(name: "Test family", budget_book: "family")
    @family_child = @family.categories.create!(name: "Test descendant", parent: @family_parent)
  end

  test "splits income, spending and drilldown by effective category without changing report totals" do
    personal_expense = post_entry(30, @personal)
    family_expense = post_entry(90, @family_child)
    post_entry(10, nil)
    post_entry(-500, @family.categories.create!(name: "Test personal income"))
    family_income = @family.categories.create!(name: "Test family income", budget_book: "family")
    post_entry(-250, family_income)

    personal = budget
    family = budget(book: "family")
    assert_equal "family", @family_child.effective_budget_book
    assert_equal [ 40, 500 ], [ personal.actual_spending, personal.actual_income ]
    assert_equal [ 90, 250 ], [ family.actual_spending, family.actual_income ]
    assert_includes personal.transactions, personal_expense.transaction
    assert_not_includes personal.transactions, family_expense.transaction
    assert_includes family.transactions, family_expense.transaction
    assert_equal [ @family_parent.id, @family_child.id, family_income.id ].sort, family.book_budget_categories.map(&:category_id).sort

    statement = @family.income_statement
    assert_equal 130, statement.expense_totals(period: family.period).total
    assert_equal 750, statement.income_totals(period: family.period).total
  end

  test "switching a parent moves its children and keeps the stored allocations in each book" do
    legacy = budget
    legacy.update!(expected_income: 500, budgeted_spending: 350)
    legacy.budget_categories.find_by!(category: @personal).update!(budgeted_spending: 200)
    @personal.update!(budget_book: "family")
    @family_parent.update!(budget_book: "personal")

    family = budget(book: "family")
    assert_equal "personal", @family_child.reload.effective_budget_book
    assert_equal [ 500, 350 ], [ legacy.reload.expected_income, legacy.budgeted_spending ]
    assert_equal 0, budget.allocated_spending
    assert_equal 0, family.book_budget_categories_scope.find_by!(category: @personal).budgeted_spending
    assert_raises(ArgumentError) { family.copy_from!(legacy) }

    @personal.update!(budget_book: "personal")
    assert_equal 200, budget.allocated_spending
  end

  test "rollover follows the corresponding book across months" do
    prior = budget(book: "family", date: Date.current.prev_month)
    prior.update!(budgeted_spending: 120)
    prior.book_budget_categories_scope.find_by!(category: @family_parent)
      .update!(budgeted_spending: 70, rollover_enabled: true)
    current = budget(book: "family")
    current.update!(budgeted_spending: 140)
    budget(book: "family")

    assert_equal 70, current.book_budget_categories_scope.find_by!(category: @family_parent).rolled_over_amount
    assert_nil budget.most_recent_initialized_budget
  end

  private

    def budget(book: "personal", date: Date.current)
      Budget.find_or_bootstrap(@family, start_date: date, book: book)
    end

    def post_entry(amount, category)
      @account.entries.create!(name: "Budget fixture", amount: amount, currency: "USD",
        date: Date.current, entryable: Transaction.new(category: category))
    end
end
