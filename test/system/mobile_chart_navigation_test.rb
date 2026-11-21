require "application_system_test_case"

class MobileChartNavigationTest < ApplicationSystemTestCase
  setup do
    sign_in users(:family_admin)
  end

  test "chart guideline does not intercept the next pointer movement" do
    overlay = find("#netWorthChart .overlay", visible: :all)
    page.execute_script(<<~JS, overlay)
      const surface = arguments[0];
      const bounds = surface.getBoundingClientRect();
      surface.dispatchEvent(new PointerEvent("pointerdown", {
        bubbles: true, cancelable: true, pointerType: "touch", isPrimary: true,
        clientX: bounds.left + bounds.width / 2, clientY: bounds.top + 30
      }));
    JS

    guideline = find("#netWorthChart .guideline", visible: :all)
    assert_equal "none", guideline["pointer-events"]

    page.execute_script(<<~JS, overlay)
      const surface = arguments[0];
      const bounds = surface.getBoundingClientRect();
      surface.dispatchEvent(new PointerEvent("pointermove", {
        bubbles: true, pointerType: "touch", isPrimary: true,
        clientX: bounds.right - 1, clientY: bounds.top + 30
      }));
    JS

    expected = page.evaluate_script(<<~JS)
      const chart = document.querySelector("#netWorthChart");
      const line = chart.querySelector(".guideline");
      const circles = chart.querySelectorAll(".data-point-circle");
      Number(line.getAttribute("x1")) === Number(circles[0].getAttribute("cx"));
    JS
    assert expected
  end

  test "a delayed revisit does not expose an interactive preview that is later replaced" do
    page.execute_script("Turbo.visit('/reports')")
    assert_current_path reports_path
    assert_selector "section[data-section-key]"
    page.execute_script("Turbo.visit('/')")
    assert_current_path root_path
    assert_selector "#netWorthChart"

    page.execute_script(<<~JS)
      window.originalNavigationFetch = window.fetch;
      window.fetch = function(input, options) {
        if (String(input).includes("/reports")) {
          return new Promise(resolve => setTimeout(resolve, 600))
            .then(() => window.originalNavigationFetch(input, options));
        }
        return window.originalNavigationFetch(input, options);
      };
      window.navigationPreviews = 0;
      document.addEventListener("turbo:render", () => {
        if (document.documentElement.hasAttribute("data-turbo-preview")) window.navigationPreviews++;
      });
      Turbo.visit('/reports');
    JS
    assert_current_path reports_path
    assert_selector "section[data-section-key]"
    assert_equal 0, page.evaluate_script("window.navigationPreviews")
  end
end
