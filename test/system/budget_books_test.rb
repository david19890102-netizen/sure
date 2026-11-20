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
end
