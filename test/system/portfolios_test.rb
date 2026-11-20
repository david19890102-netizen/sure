require "application_system_test_case"

class PortfoliosTest < ApplicationSystemTestCase
  setup do
    @user = users(:family_admin)
    @user.update!(preferences: (@user.preferences || {}).merge("preview_features_enabled" => true))
    sign_in @user
  end

  test "stock assets show the allocation and switch growth period and unit on mobile" do
    accounts(:investment).update!(exclude_from_reports: true)
    account = @user.family.accounts.create!(name: "Test brokerage", balance: 125, currency: "USD", accountable: Investment.new, owner: @user)
    security = Security.create!(ticker: "TESTSTOCK", asset_sub_class: "stock", name_zh_tw: "測試股票")
    account.holdings.create!(security: security, date: Date.current.prev_month.end_of_month,
      qty: 1, price: 100, amount: 100, currency: account.currency)
    account.holdings.create!(security: security, date: Date.current,
      qty: 1, price: 125, amount: 125, currency: account.currency)
    page.current_window.resize_to(390, 850)

    visit portfolio_path(locale: "zh-TW")

    within "#portfolio-stock-assets" do
      assert_selector "svg path.visible-path"
      assert_selector "[data-stock-ticker='TESTSTOCK']", text: "測試股票"
      assert_selector "[data-testid='stock-growth-bars']", text: "+25%"
      assert_selector "a[aria-current='true']", text: "近 6 月"
      click_link "金額"
      assert_selector "a[aria-current='true']", text: "金額"
      assert_selector "[data-testid='stock-growth-bars']", text: /\+.*25/
      click_link "今年"
      assert_selector "a[aria-current='true']", text: "今年"
      find("summary", text: "明細").click
      assert_no_selector "[data-stock-ticker='TESTSTOCK']"
    end
  end

  # The collapse state is saved with the page's CSRF token and nothing is
  # saved without one, and the test environment renders none unless forgery
  # protection is on.
  test "collapsing a section saves it under the portfolio keys, not the Reports ones" do
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    visit portfolio_path
    record_saved_section_order

    find("section[data-section-key='accounts'] summary").click

    assert_selector "section[data-section-key='accounts'] details:not([open])"
    assert_selector "html[data-order-saved='200']"
    assert_equal true, @user.reload.preferences.dig("portfolio_collapsed_sections", "accounts")
    assert_nil @user.preferences["reports_collapsed_sections"]
  ensure
    ActionController::Base.allow_forgery_protection = original
  end
end
