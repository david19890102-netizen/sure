require "test_helper"

class Portfolio::StockAssetsTest < ActiveSupport::TestCase
  setup do
    @user = users(:empty)
    @family = @user.family
    @account = @family.accounts.create!(name: "Test brokerage", balance: 500, currency: @family.currency, accountable: Investment.new, owner: @user)
    @statement = InvestmentStatement.new(@family, user: @user)
    @today = Date.new(2026, 11, 20)
    @stock = Security.create!(ticker: "FAKE", asset_sub_class: "stock")
    @etf = Security.create!(ticker: "ETFTEST", asset_sub_class: "etf")
  end

  test "sums current stocks and ETFs across eligible investment accounts and converts stored rates" do
    holding(@account, @stock, @today, 100)
    other = @family.accounts.create!(name: "Test foreign brokerage", balance: 300, currency: "EUR", accountable: Investment.new, owner: @user)
    ExchangeRate.create!(from_currency: "EUR", to_currency: @family.currency, date: @today, rate: 2)
    holding(other, @stock, @today, 50)
    holding(other, @etf, @today, 10)
    cash = Security.create!(ticker: "ZCASH", kind: "cash")
    holding(@account, cash, @today, 1000)
    crypto = @family.accounts.create!(name: "Test crypto account", balance: 200, currency: @family.currency, accountable: Crypto.new, owner: @user)
    holding(crypto, @stock, @today, 500)

    assert_equal [ [ @stock, 200 ], [ @etf, 20 ] ], card.allocation.map { |row| row.values_at(:security, :amount) }
    assert_equal 220, card.total.amount
  end

  test "compares monthly stock snapshots, including a later cash-only balance" do
    holding(@account, @stock, Date.new(2026, 8, 31), 100)
    holding(@account, @stock, Date.new(2026, 9, 30), 125)
    holding(@account, @etf, Date.new(2026, 10, 30), 75)
    @account.balances.create!(date: @today, currency: @family.currency, balance: 50, cash_balance: 50)

    assert_empty card.allocation
    assert_equal [ [ 25, 25 ], [ -50, -40 ], [ -75, -100 ] ],
      card.monthly_changes.map { |row| row.values_at(:amount, :percent) }
  end

  private

    def card
      Portfolio::StockAssets.new(statement: @statement, as_of: @today, range: "all", mode: "percent")
    end

    def holding(account, security, date, amount)
      account.holdings.create!(security: security, date: date, qty: 1, price: amount, amount: amount, currency: account.currency)
    end
end
