require "application_system_test_case"

class BudgetBooksSystemTest < ApplicationSystemTestCase
  test "chooses a category book and switches between independent monthly budgets" do
    user = users(:family_admin)
    category = user.family.categories.create!(name: "Test family expenses")
    sign_in user

    visit edit_category_path(category)
    within "form[action='#{category_path(category)}']" do
      select "Family", from: "category_budget_book"
      find("[type=submit]").click
    end
    assert_no_selector "form[action='#{category_path(category)}']"

    visit budgets_path
    within "[role=group][aria-label='Budget book']" do
      assert_selector "a[aria-current=true]", text: "Personal"
      click_link "Family"
      assert_selector "a[aria-current=true]", text: "Family"
    end
    assert_selector "#main", text: category.name
    assert_equal "family", category.reload.budget_book
    within "[role=group][aria-label='Budget book']" do
      click_link "Personal"
      assert_selector "a[aria-current=true]", text: "Personal"
    end
    assert_no_text category.name
  end

  test "moves a child to the family book and shows spending from a report-hidden account" do
    user = users(:family_admin)
    family = user.family
    parent = family.categories.create!(name: "Test shared parent", budget_book: "personal")
    child = family.categories.create!(name: "Test independent child", parent: parent)
    account = family.accounts.create!(name: "Test private bank", owner: user, balance: 100, currency: "USD",
      exclude_from_reports: true, accountable: Depository.new)
    account.entries.create!(name: "Test private purchase", date: Date.current, amount: 73, currency: "USD",
      entryable: Transaction.new(category: child))
    sign_in user

    visit edit_category_path(child)
    within "form[action='#{category_path(child)}']" do
      assert_equal "", find_field("category_budget_book").value
      select "Family", from: "category_budget_book"
      find("[type=submit]").click
    end
    assert_no_selector "form[action='#{category_path(child)}']"

    visit budgets_path(book: "family")
    assert_text "$73.00"
    find("a", text: child.name).click
    assert_text "Test private purchase"

    visit budgets_path
    assert_no_text child.name
    assert_no_text "$73.00"
  end
end
