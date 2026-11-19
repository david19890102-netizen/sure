require "test_helper"

class Security::TaiwanNamesTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    Rails.cache.clear
  end

  test "a Chinese UI shows the stored short name and an English UI shows the provider name" do
    security = Security.create!(
      ticker: "9999.TW",
      exchange_operating_mic: "TAI",
      name: "Example Semiconductor Limited",
      name_zh_tw: "測試甲"
    )

    I18n.with_locale(:"zh-TW") { assert_equal "測試甲", security.display_name }
    I18n.with_locale(:"zh-CN") { assert_equal "測試甲", security.display_name }
    I18n.with_locale(:en) { assert_equal "Example Semiconductor Limited", security.display_name }
  end

  test "display falls back to the provider name, then the ticker, when no short name is stored" do
    named = Security.create!(ticker: "9998.TW", exchange_operating_mic: "TAI", name: "Example Fund")
    unnamed = Security.create!(ticker: "9997.TW", exchange_operating_mic: "XTAI", name: nil)

    I18n.with_locale(:"zh-TW") do
      assert_equal "Example Fund", named.display_name
      assert_equal "9997.TW", unnamed.display_name
    end
  end

  test "a provider rewriting name leaves the Chinese short name in place" do
    security = Security.create!(
      ticker: "9996.TW",
      exchange_operating_mic: "TAI",
      name: "Old English Name",
      name_zh_tw: "測試乙"
    )

    security.update!(name: "New English Legal Name From Provider")

    assert_equal "New English Legal Name From Provider", security.reload.name
    assert_equal "測試乙", security.name_zh_tw
    I18n.with_locale(:"zh-TW") { assert_equal "測試乙", security.display_name }
  end

  test "recognizes TWSE and TPEx by MIC and by ticker suffix" do
    assert Security::TaiwanNames.taiwan?(Security.new(ticker: "9999.TW", exchange_operating_mic: "TAI"))
    assert Security::TaiwanNames.taiwan?(Security.new(ticker: "9999", exchange_operating_mic: "XTAI"))
    assert Security::TaiwanNames.taiwan?(Security.new(ticker: "9999.TWO", exchange_operating_mic: "TWO"))
    assert Security::TaiwanNames.taiwan?(Security.new(ticker: "9999", exchange_operating_mic: "ROCO"))
    assert Security::TaiwanNames.taiwan?(Security.new(ticker: "9999.TW"))
    assert_not Security::TaiwanNames.taiwan?(Security.new(ticker: "AAPL", exchange_operating_mic: "XNAS"))
    assert_equal "9999L", Security::TaiwanNames.listing_code("9999L.TWO")
  end

  test "stores the short name from the matching exchange and does not touch the provider name" do
    stub_catalogs

    twse = Security.create!(ticker: "9999.TW", exchange_operating_mic: "TAI", name: "English Alpha")
    tpex = Security.create!(ticker: "8888.TWO", exchange_operating_mic: "TWO", name: "English Beta")

    assert Security::TaiwanNames.apply!(twse)
    assert Security::TaiwanNames.apply!(tpex)

    assert_equal "測試甲", twse.reload.name_zh_tw
    assert_equal "English Alpha", twse.name
    assert_equal "測試丙", tpex.reload.name_zh_tw
    assert_equal "English Beta", tpex.name
  end

  test "an offline catalog leaves the stored short name and falls back to the provider name" do
    stub_request(:get, Security::TaiwanNames::TWSE_URL).to_timeout
    stub_request(:get, Security::TaiwanNames::TPEX_URL).to_raise(Faraday::ConnectionFailed.new("offline"))

    stored = Security.create!(
      ticker: "9999.TW",
      exchange_operating_mic: "TAI",
      name: "English Alpha",
      name_zh_tw: "既有簡稱"
    )
    missing = Security.create!(ticker: "7777.TW", exchange_operating_mic: "TAI", name: "English Gamma")

    assert_not Security::TaiwanNames.apply!(stored)
    assert_not Security::TaiwanNames.apply!(missing)

    assert_equal "既有簡稱", stored.reload.name_zh_tw
    assert_nil missing.reload.name_zh_tw
    I18n.with_locale(:"zh-TW") do
      assert_equal "既有簡稱", stored.display_name
      assert_equal "English Gamma", missing.display_name
    end
  end

  test "a catalog that does not list the code does not clear a short name already stored" do
    stub_catalogs
    security = Security.create!(
      ticker: "1111.TW",
      exchange_operating_mic: "TAI",
      name: "English Delta",
      name_zh_tw: "保留簡稱"
    )

    assert_not Security::TaiwanNames.apply!(security)
    assert_equal "保留簡稱", security.reload.name_zh_tw
  end

  test "creating a Taiwan security enqueues a refresh and another market does not" do
    assert_enqueued_with(job: Security::RefreshTaiwanNamesJob) do
      Security.create!(ticker: "9999.TW", exchange_operating_mic: "TAI", name: "English Alpha")
    end

    assert_no_enqueued_jobs only: Security::RefreshTaiwanNamesJob do
      Security.create!(ticker: "ZZZZ", exchange_operating_mic: "XNAS", name: "Not Taiwan")
    end
  end

  test "the refresh job writes the short name and a failed fetch does not" do
    security = Security.create!(ticker: "9999.TW", exchange_operating_mic: "TAI", name: "English Alpha")
    stub_catalogs

    Security::RefreshTaiwanNamesJob.perform_now(security.id)

    assert_equal "測試甲", security.reload.name_zh_tw
  end

  test "holdings and the combobox use the Chinese short name in a Chinese UI" do
    security = Security.create!(
      ticker: "9999.TW",
      exchange_operating_mic: "TAI",
      name: "English Alpha",
      name_zh_tw: "測試甲"
    )
    account = accounts(:investment)
    holding = account.holdings.create!(
      security: security,
      date: Date.current,
      qty: 1,
      price: 10,
      amount: 10,
      currency: "USD"
    )

    I18n.with_locale(:"zh-TW") do
      assert_equal "測試甲", holding.name
      assert_equal "測試甲", security.to_combobox_option.name
    end
    I18n.with_locale(:en) do
      assert_equal "English Alpha", holding.name
    end
  end

  private
    def stub_catalogs
      stub_request(:get, Security::TaiwanNames::TWSE_URL).to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: [ { "Code" => "9999", "Name" => "測試甲" }, { "Code" => "8888", "Name" => "上市重複" } ].to_json
      )
      stub_request(:get, Security::TaiwanNames::TPEX_URL).to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: [ { "SecuritiesCompanyCode" => "8888", "CompanyName" => "測試丙" } ].to_json
      )
    end
end
