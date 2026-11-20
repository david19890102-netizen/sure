require "test_helper"

class Goal::DatedFundingTest < ActiveSupport::TestCase
  test "dated progress and pace subtract the opening close and exclude later investment gains" do
    family = families(:empty)
    today = Date.current
    opening = today - 30.days
    cash = funding_account(family, Depository.new, 1_200, opening - 1.day)
    investment = funding_account(family, Investment.new, 2_800, opening - 1.day)

    record_balance(cash, opening, 1_000)
    record_balance(cash, today, 1_200)
    record_balance(investment, opening, 2_000, market: 300)
    record_balance(investment, opening + 15.days, 2_500, market: 250)
    record_balance(investment, today, 2_800, market: 150)

    goal = family.goals.new(name: "Test savings", currency: "USD", target_amount: 1_200,
      target_date: today + 60.days)
    goal.goal_accounts.build(account: cash)
    goal.goal_accounts.build(account: investment)
    goal.save!

    assert_equal 3_300, goal.current_balance
    assert_equal 0, goal.pace
    goal.update!(start_date: opening)

    assert_equal 200, goal.account_backing(cash).amount
    assert_equal 400, goal.account_backing(investment).amount
    assert_equal 600, goal.current_balance
    assert_equal 600, goal.pace
    assert_equal 300, goal.monthly_target_amount
    series = goal.projection_payload.fetch(:saved_series)
    assert_equal({ date: opening.iso8601, value: 0.0 }, series.first)
    assert_equal({ date: today.iso8601, value: 600.0 }, series.last)

    goal.update!(start_date: nil)
    assert_equal 3_300, goal.current_balance
    assert_equal 0, goal.pace
  end

  test "unknown opening history does not count an existing balance as new money" do
    family = families(:empty)
    cutoff = Date.current - 10.days
    older = funding_account(family, Depository.new, 500, cutoff - 1.day)
    newer = funding_account(family, Depository.new, 300, cutoff + 1.day)
    closed = funding_account(family, Depository.new, 120, cutoff - 2.days)
    record_balance(closed, cutoff - 1.day, 100)

    funding = Goal::DatedFunding.new(accounts: [ older, newer, closed ], start_date: cutoff)
    assert_equal 0, funding.amount_for(older)
    assert_equal 300, funding.amount_for(newer)
    assert_equal 20, funding.amount_for(closed)
  end

  private

    def funding_account(family, accountable, balance, created_at)
      family.accounts.create!(name: "Funding fixture", accountable: accountable, balance: balance,
        currency: "USD", created_at: created_at)
    end

    def record_balance(account, date, amount, market: 0)
      account.balances.create!(date: date, currency: "USD", balance: amount, net_market_flows: market)
    end
end
