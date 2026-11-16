require "test_helper"

class AccountGroupOrderTest < ActiveSupport::TestCase
  test "an empty order sorts groups in the official sequence" do
    groups = [ group("credit_card"), group("depository"), group("investment") ]

    assert_equal %w[depository investment credit_card], AccountGroupOrder.sort(groups, []).map(&:key)
  end

  test "a saved order can place a liability group ahead of assets" do
    groups = [ group("depository"), group("investment"), group("credit_card") ]
    order = AccountGroupOrder.merge([], %w[credit_card depository investment crypto property vehicle other_asset loan other_liability], scope: "all")

    assert_equal %w[credit_card depository investment], AccountGroupOrder.sort(groups, order).map(&:key)
  end

  test "merging an asset drag keeps liability positions" do
    stored = AccountGroupOrder.merge([], %w[credit_card depository investment crypto property vehicle other_asset loan other_liability], scope: "all")

    merged = AccountGroupOrder.merge(stored, %w[investment depository crypto property vehicle other_asset], scope: "asset")

    assert_equal "credit_card", merged.first
    assert merged.index("investment") < merged.index("depository")
    assert merged.index("loan") < merged.index("other_liability")
    assert_equal AccountGroupOrder.keys.sort, merged.sort
  end

  test "merging from an empty order keeps types the drag did not include" do
    merged = AccountGroupOrder.merge([], %w[crypto depository investment], scope: "asset")

    assert_equal %w[crypto depository investment property vehicle other_asset credit_card loan other_liability], merged
  end

  test "merge rejects unknown keys, duplicates, the wrong tab, and non-lists" do
    assert_nil AccountGroupOrder.merge([], %w[not_a_type], scope: "all")
    assert_nil AccountGroupOrder.merge([], %w[depository depository], scope: "all")
    assert_nil AccountGroupOrder.merge([], %w[credit_card], scope: "asset")
    assert_nil AccountGroupOrder.merge([], %w[depository], scope: "nope")
    assert_nil AccountGroupOrder.merge([], { "0" => "depository" }, scope: "all")
    assert_nil AccountGroupOrder.merge([], [], scope: "all")
  end

  private
    def group(key)
      Struct.new(:key).new(key)
    end
end
