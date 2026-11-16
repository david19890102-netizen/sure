# Order of the big account groups (cash, investments, credit cards, and the
# other asset and liability types). An empty list means the official
# Accountable::TYPES sequence.
class AccountGroupOrder
  SCOPES = %w[all asset liability].freeze

  def self.keys
    Accountable::TYPES.map(&:underscore)
  end

  # Drops the dragged keys into the slots they already occupy, in their new
  # relative order. Keys the drag did not include stay put, so reordering the
  # asset tab does not move liabilities, and a type with no accounts yet keeps
  # its place.
  def self.merge(stored, incoming, scope:)
    return nil unless incoming.is_a?(Array)

    dragged_keys = incoming.map(&:to_s)
    return nil if dragged_keys.empty? || dragged_keys.uniq.size != dragged_keys.size

    allowed = keys_for(scope)
    return nil if allowed.nil? || dragged_keys.any? { |key| allowed.exclude?(key) }

    queue = dragged_keys.dup
    dragged = dragged_keys.to_set
    normalize(stored).map { |key| dragged.include?(key) ? queue.shift : key }
  end

  def self.sort(groups, order)
    rank = ranks(order)
    groups.sort_by { |group| [ rank.fetch(group.key, rank.length), group.key ] }
  end

  def self.ranks(order)
    normalize(order).each_with_index.to_h
  end

  # Known types missing from a stored list take their official position, so a
  # type added later still shows up where it would have by default.
  def self.normalize(stored)
    ordered = Array(stored).map(&:to_s).select { |key| keys.include?(key) }.uniq
    result = ordered.dup

    keys.each_with_index do |key, index|
      next if result.include?(key)

      later = result.find { |existing| keys.index(existing) > index }
      if later
        result.insert(result.index(later), key)
      else
        result << key
      end
    end

    result
  end

  def self.keys_for(scope)
    case scope.to_s
    when "all"
      keys
    when "asset", "liability"
      keys.select { |key| classification_for(key) == scope.to_s }
    end
  end

  def self.classification_for(key)
    Accountable.from_type(key.camelize)&.classification
  end
  private_class_method :classification_for
end
