require "test_helper"

class ReportsHelperTest < ActionView::TestCase
  test "report money prints TWD without cents and keeps cents for dollars" do
    twd = reports_money(Money.new(1000.4, :twd))
    usd = reports_money(Money.new(1000.4, :usd))

    assert_no_match(/\.\d/, twd)
    assert_match(/1,000/, twd)
    assert_match(/1,000\.40/, usd)
  end

  test "an explicit precision is kept for TWD" do
    assert_match(/\.40/, reports_money(Money.new(1000.4, :twd), precision: 2))
  end
end
