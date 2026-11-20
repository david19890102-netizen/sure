# Balance changes measured from a closing balance. Market movement after
# that close is removed from investment and crypto accounts.
class Goal::DatedFunding
  def initialize(accounts:, start_date:, today: Date.current)
    @accounts = accounts.index_by(&:id)
    @start_date = start_date
    @today = today
  end

  def amount_for(account)
    return 0 if start_date >= today

    amount_since(account, start_date)
  end

  def pace_days
    [ (today - pace_start).to_i, 0 ].max
  end

  def pace_amount_for(account)
    return 0 if pace_days.zero? || opening_amount(account, start_date).nil?

    amount_since(account, pace_start)
  end

  def historical_amounts
    return {} if start_date >= today

    balances = closing_balances(pace_start).dup
    gains = market_flows(start_date, through: pace_start).dup
    points = { pace_start => amounts_at(balances, gains) }
    snapshots.where(date: (pace_start + 1.day)...today).order(:date)
      .pluck(:date, :account_id, :balance, :net_market_flows)
      .chunk { |date, *| date }
      .each do |date, rows|
        rows.each do |_, account_id, balance, market_flow|
          balances[account_id] = balance
          gains[account_id] = gains.fetch(account_id, 0) + market_flow.to_d
        end
        points[date] = amounts_at(balances, gains)
      end
    points
  end

  private

    attr_reader :accounts, :start_date, :today

    def pace_start
      [ start_date, today - 90.days ].max
    end

    def snapshots
      Balance.joins(:account).where(account_id: accounts.keys)
        .where("balances.currency = accounts.currency")
    end

    def closing_balances(date)
      @closing_balances ||= {}
      @closing_balances[date] ||= snapshots.where(date: ..date)
        .order(:account_id, date: :desc)
        .pluck(Arel.sql("DISTINCT ON (balances.account_id) balances.account_id"), :balance).to_h
    end

    def market_flows(from, through: today)
      @market_flows ||= {}
      @market_flows[[ from, through ]] ||= snapshots.where(date: (from + 1.day)..through)
        .group(:account_id).sum(:net_market_flows)
    end

    def opening_amount(account, date)
      return 0 if account.created_at.to_date > date && !closing_balances(date).key?(account.id)

      closing_balances(date)[account.id]
    end

    def amount_since(account, date)
      opening = opening_amount(account, date)
      return 0 if opening.nil?

      account.balance.to_d - opening - market_adjustment(account, market_flows(date))
    end

    def amounts_at(balances, gains)
      accounts.transform_values do |account|
        opening = opening_amount(account, start_date)
        closing = balances[account.id]
        if opening && closing
          closing - opening - market_adjustment(account, gains)
        else
          0
        end
      end
    end

    def market_adjustment(account, flows)
      account.accountable_type.in?(%w[Investment Crypto]) ? flows.fetch(account.id, 0) : 0
    end
end
