require "application_system_test_case"

# Dark theme values have to reach pseudo-elements as well as elements, which
# only a browser's computed styles can show.
class DarkThemeTest < ApplicationSystemTestCase
  test "pseudo-element variants take the dark theme values" do
    user = users(:family_admin)
    user.update!(theme: "dark")
    sign_in user
    visit transactions_url
    assert_selector "html[data-theme='dark']"

    search = find("#q_search")
    assert_equal element_style(search, "text-secondary", "color"),
      search.evaluate_script("getComputedStyle(this, '::placeholder').color")

    click_on "New transaction"
    dialog = find("dialog[open]")
    assert_equal element_style(dialog, "bg-overlay", "backgroundColor"),
      dialog.evaluate_script("getComputedStyle(this, '::backdrop').backgroundColor")
  end

  private

    # What an element with `class_name` computes for `property`, which the same
    # utility under a pseudo-element variant has to match.
    def element_style(element, class_name, property)
      element.evaluate_script(<<~JS)
        (() => {
          const probe = this.parentElement.appendChild(document.createElement("div"));
          probe.className = #{class_name.to_json};
          const value = getComputedStyle(probe)[#{property.to_json}];
          probe.remove();
          return value;
        })()
      JS
    end
end
