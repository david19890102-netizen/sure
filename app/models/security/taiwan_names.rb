# Chinese short names for Taiwan listings (TWSE and TPEx).
#
# Price providers store an English legal name on `securities.name` and overwrite
# it whenever they refresh metadata. The short name shown in a Chinese UI is
# kept on `name_zh_tw` and is only written from the exchanges' open data, so a
# provider refresh cannot replace 台積電 with the English legal name.
#
# The catalogs are the latest-day quote files. They carry every listed code,
# including ETFs, and they do not require an account. A failed fetch leaves
# whatever name is already stored, and the UI falls back to `name`.
class Security::TaiwanNames
  extend SslConfigurable

  TWSE_URL = "https://openapi.twse.com.tw/v1/exchangeReport/STOCK_DAY_ALL"
  TPEX_URL = "https://www.tpex.org.tw/openapi/v1/tpex_mainboard_daily_close_quotes"

  # ISO MICs plus the vendor codes providers persist (Yahoo/EODHD use TAI and TWO).
  TWSE_MICS = %w[TAI TW TWSE XTAI].freeze
  TPEX_MICS = %w[ROCO TPEX TWO].freeze

  CACHE_KEY = "security/taiwan_names/v1"
  CACHE_TTL = 12.hours
  OPEN_TIMEOUT = 4
  READ_TIMEOUT = 15

  def self.taiwan?(security)
    market_for(security).present?
  end

  def self.market_for(security)
    return nil if security.nil?

    mic = security.exchange_operating_mic.to_s.upcase
    return :twse if TWSE_MICS.include?(mic)
    return :tpex if TPEX_MICS.include?(mic)

    ticker = security.ticker.to_s.upcase
    return :tpex if ticker.end_with?(".TWO")
    return :twse if ticker.end_with?(".TW")

    nil
  end

  # "00631L.TW" and "00631L.TWO" both become the exchange code "00631L".
  def self.listing_code(ticker)
    ticker.to_s.upcase.sub(/\.TWO\z/, "").sub(/\.TW\z/, "")
  end

  # Writes the catalog name when one is found. Never clears a name we already
  # stored: an empty catalog (offline, holiday payload, unknown code) keeps
  # the previous short name, and the UI keeps using it.
  def self.apply!(security)
    return false unless taiwan?(security)

    name = lookup(security)
    return false if name.blank?
    return true if security.name_zh_tw == name

    security.update!(name_zh_tw: name)
    true
  rescue ActiveRecord::ActiveRecordError => e
    Rails.logger.warn("Taiwan short name not saved for #{security.ticker}: #{e.class}: #{e.message}")
    false
  end

  def self.lookup(security)
    market = market_for(security)
    return nil unless market

    code = listing_code(security.ticker)
    return nil if code.blank?

    catalogs.dig(market, code).presence
  end

  def self.refresh_all!
    taiwan_scope.find_each { |security| apply!(security) }
  end

  def self.catalogs
    cached = Rails.cache.read(CACHE_KEY)
    return cached if usable_catalog?(cached)

    fetched = fetch_catalogs
    Rails.cache.write(CACHE_KEY, fetched, expires_in: CACHE_TTL) if usable_catalog?(fetched)
    fetched
  end

  def self.taiwan_scope
    Security.where(
      "UPPER(COALESCE(exchange_operating_mic, '')) IN (:mics) OR UPPER(ticker) LIKE :tw OR UPPER(ticker) LIKE :two",
      mics: TWSE_MICS + TPEX_MICS,
      tw: "%.TW",
      two: "%.TWO"
    )
  end

  def self.usable_catalog?(catalog)
    catalog.is_a?(Hash) && (catalog[:twse].present? || catalog[:tpex].present?)
  end
  private_class_method :usable_catalog?

  def self.fetch_catalogs
    {
      twse: index_rows(fetch_json(TWSE_URL), "Code", "Name"),
      tpex: index_rows(fetch_json(TPEX_URL), "SecuritiesCompanyCode", "CompanyName")
    }
  end

  def self.index_rows(rows, code_key, name_key)
    Array(rows).each_with_object({}) do |row, names|
      next unless row.is_a?(Hash)

      code = row[code_key].to_s.strip.upcase
      name = row[name_key].to_s.strip
      next if code.blank? || name.blank?

      names[code] ||= name
    end
  end
  private_class_method :index_rows

  def self.fetch_json(url)
    response = client.get(url)
    return [] unless response.success?

    body = response.body
    parsed = body.is_a?(String) ? JSON.parse(body) : body
    parsed.is_a?(Array) ? parsed : []
  rescue StandardError => e
    Rails.logger.warn("Taiwan name catalog unavailable (#{url}): #{e.class}: #{e.message}")
    []
  end
  private_class_method :fetch_json

  def self.client
    Faraday.new(ssl: faraday_ssl_options) do |faraday|
      faraday.options.open_timeout = OPEN_TIMEOUT
      faraday.options.timeout = READ_TIMEOUT
      faraday.headers["Accept"] = "application/json"
      faraday.headers["User-Agent"] = "Sure/taiwan-names"
    end
  end
  private_class_method :client
end
