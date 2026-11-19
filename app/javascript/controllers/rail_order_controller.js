import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["item", "status", "toggle"];
  static values = { account: String };

  connect() {
    this.close();
    const defaults = this.itemTargets.sort(
      (a, b) => Number(a.dataset.position) - Number(b.dataset.position),
    );
    let order = [];
    try {
      const saved = JSON.parse(localStorage.getItem(this.storageKey));
      if (Array.isArray(saved)) order = saved.filter((id) => typeof id === "string");
    } catch {
      // Storage may be disabled or contain an older, unreadable value.
    }
    this.order = [...new Set([...order, ...defaults.map((row) => row.dataset.key)])];
    this.renderOrder();
  }

  get storageKey() {
    return `sure:desktop-nav:${this.accountValue}`;
  }

  renderOrder() {
    const rows = new Map(this.itemTargets.map((row) => [row.dataset.key, row]));
    for (const id of this.order) {
      const row = rows.get(id);
      if (row) row.parentElement.appendChild(row);
    }
    const visible = this.itemTargets;
    visible.forEach((row, i) => {
      row.querySelector("[data-direction=up]").disabled = i === 0;
      row.querySelector("[data-direction=down]").disabled = i === visible.length - 1;
    });
  }

  close() {
    this.element.dataset.editing = "false";
    this.toggleTarget.setAttribute("aria-pressed", "false");
  }

  toggle() {
    const editing = this.element.dataset.editing !== "true";
    this.element.dataset.editing = String(editing);
    this.toggleTarget.setAttribute("aria-pressed", String(editing));
  }

  move(event) {
    const button = event.currentTarget;
    const row = button.closest("li");
    const offset = button.dataset.direction === "up" ? -1 : 1;
    const adjacent = this.itemTargets[this.itemTargets.indexOf(row) + offset];
    if (!adjacent) return;

    const from = this.order.indexOf(row.dataset.key);
    const to = this.order.indexOf(adjacent.dataset.key);
    [this.order[from], this.order[to]] = [this.order[to], this.order[from]];
    this.persist();
    this.renderOrder();
    (button.disabled ? row.querySelector("button:not(:disabled)") : button)?.focus();
  }

  reset() {
    this.order = this.itemTargets
      .sort((a, b) => Number(a.dataset.position) - Number(b.dataset.position))
      .map((row) => row.dataset.key);
    this.persist(true);
    this.renderOrder();
  }

  persist(reset = false) {
    try {
      if (reset) localStorage.removeItem(this.storageKey);
      else localStorage.setItem(this.storageKey, JSON.stringify(this.order));
    } catch {
      this.statusTarget.textContent = this.statusTarget.dataset.error;
    }
  }
}
