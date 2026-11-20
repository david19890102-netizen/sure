require "application_system_test_case"

class ReportBooksTest < ApplicationSystemTestCase
  test "keeps the selected report book in the URL and across period changes" do
    user = users(:family_admin)
    user.update!(locale: "zh-TW")
    account = user.family.accounts.create!(name: "示範帳戶", owner: user, currency: "USD",
      balance: 200, accountable: Depository.new, exclude_from_reports: true)
    parent = user.family.categories.create!(name: "示範支出")
    child = user.family.categories.create!(name: "示範家人分類", parent: parent, budget_book: "family")
    account.entries.create!(date: Date.current, name: "示範交易", amount: 73, currency: "USD",
      entryable: Transaction.new(category: child))
    sign_in user
    visit reports_path

    book_switch = "[role=group][aria-label='報表帳本']"
    within book_switch do
      assert_selector "a[aria-current=true]", text: "全部"
      click_link "家人"
    end
    assert_selector "#{book_switch} a[aria-current=true]", text: "家人"
    assert_current_path reports_path(book: "family")
    assert_text child.name
    assert_selector "[data-section-key=cash_flow] svg .sankey-link"

    refresh
    assert_selector "#{book_switch} a[aria-current=true]", text: "家人"
    click_link I18n.t("reports.index.periods.ytd", locale: "zh-TW")
    assert_current_path reports_path(book: "family", period_type: "ytd")
    within(book_switch) { click_link "個人" }
    assert_selector "#{book_switch} a[aria-current=true]", text: "個人"
    assert_no_text child.name
  end
end
