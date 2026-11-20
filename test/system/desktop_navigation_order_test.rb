require "application_system_test_case"

class DesktopNavigationOrderTest < ApplicationSystemTestCase
  test "moving a desktop shortcut persists on reload and can be reset" do
    sign_in users(:family_admin)
    visit root_path
    rail = "nav[data-controller='rail-order']"
    first_link = "#{rail} li:first-child a"
    assert_selector "#{first_link}[href='/']"
    within rail do
      click_button "Reorder"
      find("button[aria-label='Move Transactions up']:enabled").click
    end
    assert_selector "#{first_link}[href='#{transactions_path}']"
    visit transactions_path
    assert_selector "#{first_link}[href='#{transactions_path}'][aria-current='page']"
    within rail do
      click_button "Reorder"
      click_button "Reset"
    end
    visit root_path
    assert_selector "#{first_link}[href='/']"
  end
end
