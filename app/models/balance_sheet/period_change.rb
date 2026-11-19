# The net-worth move from the opening of the selected period to its end.
#
# The chart's series already starts on the period's start date, so the first
# plotted value is the balance then and the last is the balance now. A zero
# opening balance (nothing was tracked yet) cannot support a percentage, and
# showing the whole net worth as the "change" would be misleading.
class BalanceSheet::PeriodChange
  def initialize(series)
    @series = series
  end

  def current
    opening_trend&.current
  end

  def baseline
    opening_trend&.previous
  end

  # Both ends at zero is a real flat period. An opening of zero against a
  # later balance is a missing baseline, not an infinite percentage.
  def comparable?
    return false if current.nil? || baseline.nil?
    return false if zero?(baseline) && !zero?(current)

    true
  end

  def trend
    comparable? ? opening_trend : nil
  end

  private
    attr_reader :series

    def opening_trend
      return @opening_trend if defined?(@opening_trend)

      @opening_trend = series.nil? || series.values.blank? ? nil : series.trend
    end

    def zero?(amount)
      amount.respond_to?(:zero?) && amount.zero?
    end
end
