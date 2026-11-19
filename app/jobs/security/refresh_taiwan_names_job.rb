# frozen_string_literal: true

# Fills `securities.name_zh_tw` from the TWSE and TPEx open data.
#
# A security id refreshes that listing (enqueued when a Taiwan security is
# created or its ticker/venue changes). No id refreshes every Taiwan listing,
# which is what the daily market-data import enqueues so names survive even
# when the provider skips a metadata refetch.
class Security::RefreshTaiwanNamesJob < ApplicationJob
  queue_as :low_priority

  def perform(security_id = nil)
    if security_id
      security = Security.find_by(id: security_id)
      Security::TaiwanNames.apply!(security) if security
    else
      Security::TaiwanNames.refresh_all!
    end
  end
end
