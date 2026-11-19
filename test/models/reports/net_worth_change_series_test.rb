require "test_helper"

class Reports::NetWorthChangeSeriesTest < ActiveSupport::TestCase
  test "percent mode is the change from the opening balance" do
    change = Reports::NetWorthChangeSeries.new(series_for([ 200, 220, 180 ]), mode: "percent", currency: "USD")
    chart = change.chart

    assert_equal [ 0.0, 10.0, -10.0 ], chart[:values].map { |point| point[:value][:amount] }
    assert_equal "+10.0%", chart[:values][1][:value][:formatted]
    assert_equal "-10.0%", chart[:values][2][:value][:formatted]
  end

  test "amount mode is the currency change from the opening balance" do
    change = Reports::NetWorthChangeSeries.new(series_for([ 200, 250 ]), mode: "amount", currency: "USD")
    chart = change.chart

    assert_equal [ 0, 50 ], chart[:values].map { |point| point[:value][:amount] }
    assert_includes chart[:values].last[:value][:formatted], "50"
  end

  test "a zero opening balance has no percentage curve" do
    change = Reports::NetWorthChangeSeries.new(series_for([ 0, 80 ]), mode: "percent", currency: "USD")

    assert change.baseline_missing?
    assert_nil change.chart
  end

  test "a zero opening balance still has an amount curve" do
    change = Reports::NetWorthChangeSeries.new(series_for([ 0, 80 ]), mode: "amount", currency: "TWD")
    chart = change.chart

    assert_not change.baseline_missing?
    assert_equal [ 0, 80 ], chart[:values].map { |point| point[:value][:amount] }
    assert_not_includes chart[:values].last[:value][:formatted], ".00"
  end

  test "an unknown mode falls back to percent" do
    change = Reports::NetWorthChangeSeries.new(series_for([ 100, 110 ]), mode: "nope", currency: "USD")

    assert change.percent?
    assert_equal 10.0, change.chart[:values].last[:value][:amount]
  end

  private
    def series_for(amounts)
      start_date = Date.new(2026, 1, 1)
      Series.new(
        start_date: start_date,
        end_date: start_date + amounts.size - 1,
        interval: "1 day",
        values: amounts.each_with_index.map do |amount, index|
          money = Money.new(amount, "USD")
          Series::Value.new(
            date: start_date + index,
            date_formatted: (start_date + index).to_s,
            value: money,
            trend: Trend.new(current: money, previous: money)
          )
        end
      )
    end
end
