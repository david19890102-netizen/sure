require "test_helper"

class BalanceSheet::PeriodChangeTest < ActiveSupport::TestCase
  test "reports the amount and percentage versus the balance at the start of the period" do
    change = BalanceSheet::PeriodChange.new(series_for([ Money.new(200), Money.new(250) ]))

    assert change.comparable?
    assert_equal Money.new(250), change.current
    assert_equal Money.new(200), change.baseline
    assert_equal Money.new(50), change.trend.value
    assert_equal 25.0, change.trend.percent
  end

  test "a drop versus the opening balance is a negative amount and percentage" do
    change = BalanceSheet::PeriodChange.new(series_for([ Money.new(200), Money.new(150) ]))

    assert_equal Money.new(-50), change.trend.value
    assert_equal(-25.0, change.trend.percent)
    assert_equal "down", change.trend.direction
  end

  test "a zero opening balance is not compared as a percentage" do
    change = BalanceSheet::PeriodChange.new(series_for([ Money.new(0), Money.new(80) ]))

    assert_not change.comparable?
    assert_nil change.trend
    assert_equal Money.new(80), change.current
  end

  test "both ends at zero is a flat change rather than a missing baseline" do
    change = BalanceSheet::PeriodChange.new(series_for([ Money.new(0), Money.new(0) ]))

    assert change.comparable?
    assert change.trend.direction.flat?
  end

  test "an empty series has nothing to compare" do
    series = Series.new(
      start_date: Date.current,
      end_date: Date.current,
      interval: "1 day",
      values: []
    )
    change = BalanceSheet::PeriodChange.new(series)

    assert_nil change.current
    assert_not change.comparable?
    assert_nil change.trend
  end

  private
    def series_for(amounts)
      start_date = Date.current - (amounts.size - 1)
      Series.new(
        start_date: start_date,
        end_date: Date.current,
        interval: "1 day",
        values: amounts.each_with_index.map do |amount, index|
          Series::Value.new(
            date: start_date + index,
            date_formatted: index.to_s,
            value: amount,
            trend: Trend.new(current: amount, previous: amount)
          )
        end
      )
    end
end
