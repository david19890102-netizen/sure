# Market value of stock and ETF holdings, in the family's currency.
class Portfolio::StockAssets
  PERIODS = %w[six_months year all].freeze
  LISTED_MARKETS = (Security::EXCHANGES.filter_map { |mic, exchange| mic if %w[TW US].include?(exchange["country"]) } +
    Security::TaiwanNames::TWSE_MICS + Security::TaiwanNames::TPEX_MICS).uniq.freeze

  def initialize(statement:, as_of:, range:, mode:)
    @statement = statement
    @as_of = as_of
    @range = PERIODS.include?(range) ? range : PERIODS.first
    @mode = Reports::NetWorthChangeSeries::MODES.include?(mode) ? mode : "percent"
  end

  attr_reader :range, :mode

  def currency
    statement.family.currency
  end

  def allocation
    @allocation ||= begin
      totals = valued(current_positions).group_by { |row| row["security_id"] }.values.map do |rows|
        { security: securities.fetch(rows.first["security_id"]), amount: rows.sum { |row| row["value"] } }
      end
      total_amount = totals.sum { |row| row[:amount] }
      totals.sort_by { |row| [ -row[:amount], row[:security].ticker, row[:security].id ] }.each do |row|
        row[:weight] = row[:amount] * 100 / total_amount
      end
    end
  end

  def total
    Money.new(allocation.sum { |row| row[:amount] }, currency)
  end

  def monthly_changes
    @monthly_changes ||= begin
      previous = nil
      cutoffs.zip(snapshot_values).filter_map do |date, value|
        base, previous = previous, value
        next if base.nil? || value.nil?

        change = value - base
        { date: date, amount: change, percent: (100 * change / base unless base.zero?) }
      end
    end
  end

  def growth_statistics
    key = mode.to_sym
    comparable = monthly_changes.reject { |row| row[key].nil? }
    return if comparable.empty?

    values = comparable.pluck(key)
    {
      scale: values.map(&:abs).max,
      count: values.size,
      rising: values.count(&:positive?),
      average: values.sum / values.size,
      best: comparable.max_by { |row| row[key] },
      worst: comparable.min_by { |row| row[key] }
    }
  end

  def missing_rates?
    current_positions.any? { |row| row["value"].nil? } || historical_positions.any? { |row| row["value"].nil? }
  end

  private
    attr_reader :statement, :as_of

    def securities
      @securities ||= Security.where(id: current_positions.pluck("security_id")).index_by(&:id)
    end

    def accounts
      @accounts ||= statement.investment_accounts.where(accountable_type: "Investment")
    end

    def equity_holdings
      Holding.where(account_id: accounts.select(:id)).joins(:security)
        .where(securities: { kind: "standard" })
        .where(<<~SQL.squish, markets: LISTED_MARKETS)
          (securities.asset_sub_class IN ('stock', 'etf')
          OR (securities.asset_sub_class IS NULL AND (
            securities.asset_class = 'equity'
            OR (securities.asset_class IS NULL AND securities.exchange_operating_mic IN (:markets))
          )))
        SQL
    end

    def first_month
      case range
      when "six_months" then as_of.beginning_of_month << 5
      when "year" then as_of.beginning_of_year
      else equity_holdings.where(date: ..as_of).minimum(:date)&.beginning_of_month
      end
    end

    def cutoffs
      @cutoffs ||= begin
        month = first_month
        dates = []
        if month
          dates << month - 1.day
          while month <= as_of
            dates << [ month.end_of_month, as_of ].min
            month = month.next_month
          end
        end
        dates
      end
    end

    def current_positions
      @current_positions ||= rows_for([ as_of ])
    end

    def historical_positions
      @historical_positions ||= rows_for(cutoffs[0...-1])
    end

    def snapshot_values
      return [] if cutoffs.empty?

      snapshots = (historical_positions + current_positions).group_by { |row| row["snapshot"] }
      cutoffs.map do |date|
        rows = snapshots[date]
        next if rows.blank? || rows.any? { |row| row["value"].nil? }
        rows.sum { |row| row["value"] }
      end
    end

    def valued(rows)
      rows.select { |row| row["value"]&.positive? }
    end

    def rows_for(dates)
      return [] if dates.empty?

      connection = Holding.lease_connection
      dates_sql = dates.map { |date| "(#{connection.quote(date)}::date)" }.join(", ")
      rate = ExchangeRate.rate_sql(from: "positions.currency", to: connection.quote(currency), on: "dates.snapshot")
      connection.select_all(<<~SQL).to_a
        WITH dates(snapshot) AS (VALUES #{dates_sql}),
        equity AS (#{equity_holdings.select("holdings.*").to_sql})
        SELECT dates.snapshot, positions.security_id,
          CASE
            WHEN positions.amount IS NULL THEN 0::numeric
            ELSE positions.amount * (#{rate})
          END AS value
        FROM dates
        CROSS JOIN (#{accounts.select(:id, :currency).to_sql}) AS investment_accounts
        LEFT JOIN LATERAL (
          SELECT holdings.date FROM holdings
          WHERE holdings.account_id = investment_accounts.id AND holdings.date <= dates.snapshot
          ORDER BY holdings.date DESC LIMIT 1
        ) AS last_holdings ON TRUE
        LEFT JOIN LATERAL (
          SELECT balances.date, balances.balance = balances.cash_balance AS cash_only
          FROM balances
          WHERE balances.account_id = investment_accounts.id
            AND balances.currency = investment_accounts.currency
            AND balances.date <= dates.snapshot
          ORDER BY balances.date DESC LIMIT 1
        ) AS last_balance ON TRUE
        LEFT JOIN equity AS positions
          ON positions.account_id = investment_accounts.id
          AND positions.date = last_holdings.date
          AND positions.qty > 0 AND positions.amount > 0
          AND NOT (last_balance.cash_only IS TRUE AND last_balance.date > last_holdings.date)
        WHERE last_holdings.date IS NOT NULL OR last_balance.cash_only IS TRUE
      SQL
    end
end
