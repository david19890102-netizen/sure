# Cumulative net-worth change across a balance series, measured from the
# first point. Percent is that change divided by the opening balance.
# Amount is the same change in the family's currency.
class Reports::NetWorthChangeSeries
  MODES = %w[percent amount].freeze

  def initialize(series, mode:, currency:)
    @series = series
    @mode = MODES.include?(mode) ? mode : "percent"
    @currency = currency
  end

  attr_reader :mode

  def percent?
    mode == "percent"
  end

  # A percent has no base when the period opens at zero. The amount curve
  # still has a meaning: it is the balance itself.
  def baseline_missing?
    percent? && baseline_amount.zero?
  end

  def chart
    return nil if series.nil? || series.values.size < 2
    return nil if baseline_missing?

    points = change_points
    {
      start_date: series.start_date,
      end_date: series.end_date,
      interval: series.interval,
      trend: point_trend(points.last[:raw], points.first[:raw]),
      values: points.map { |point| point.except(:raw) }
    }
  end

  private
    attr_reader :series, :currency

    def baseline_amount
      numeric(series&.values&.first&.value)
    end

    def numeric(value)
      return BigDecimal(0) if value.nil?
      value.is_a?(Money) ? value.amount : BigDecimal(value.to_s)
    end

    def change_points
      base = baseline_amount
      previous = 0.to_d
      series.values.map do |point|
        delta = numeric(point.value) - base
        raw = percent? ? percent_of(delta, base) : delta
        point_hash = {
          raw: raw,
          date: point.date,
          date_formatted: point.date_formatted,
          value: display_value(raw),
          trend: point_trend(raw, previous)
        }
        previous = raw
        point_hash
      end
    end

    def percent_of(delta, base)
      return 0.to_d if base.zero?

      (delta / base.abs * 100).round(1)
    end

    def display_value(raw)
      if percent?
        { amount: raw.to_f, formatted: format_percent(raw) }
      else
        money = Money.new(raw, currency)
        { amount: money.amount, currency: money.currency.iso_code, formatted: format_amount(money) }
      end
    end

    def format_percent(raw)
      sign = raw.positive? ? "+" : ""
      "#{sign}#{raw.to_s("F")}%"
    end

    def format_amount(money)
      options = { signify_positive: true }
      options[:precision] = 0 if money.currency.iso_code == "TWD"
      money.format(options)
    end

    def point_trend(current, previous)
      difference = current - previous
      color = if difference.zero?
        "var(--color-gray)"
      elsif difference.positive?
        "var(--color-success)"
      else
        "var(--color-destructive)"
      end

      {
        value: display_value(difference),
        percent: nil,
        percent_formatted: "",
        current: display_value(current),
        previous: display_value(previous),
        color: color,
        icon: difference.zero? ? "minus" : (difference.positive? ? "arrow-up" : "arrow-down")
      }
    end
end
