module PortfoliosHelper
  STOCK_SEGMENT_COLORS = %w[info success warning destructive link].freeze

  def stock_segment_color(index)
    "var(--color-#{STOCK_SEGMENT_COLORS[index % STOCK_SEGMENT_COLORS.size]})"
  end

  def stock_change_label(value, mode, currency)
    return t("portfolios.stock_assets.unavailable") if value.nil?

    sign = value.positive? ? "+" : ""
    if mode == "percent"
      "#{sign}#{number_to_percentage(value, precision: 2, strip_insignificant_zeros: true)}"
    else
      "#{sign}#{format_money(Money.new(value, currency))}"
    end
  end
end
