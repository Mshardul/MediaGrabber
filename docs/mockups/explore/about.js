// Review controls and the small interactions of the About and Developer prototype.
(() => {
  const SETS = { chosen: [1, 8, 10], suggested: [1, 2, 3, 4, 5, 6, 8, 10], short: [1, 3, 5, 10], all: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10] };
  const $ = (selector) => [...document.querySelectorAll(selector)];

  function showPage(name) {
    $("[data-page]").forEach((page) => (page.hidden = page.dataset.page !== name));
    $("[data-go]").forEach((button) => {
      if (button.dataset.go === name) button.setAttribute("aria-current", "page");
      else button.removeAttribute("aria-current");
    });
  }

  function syncBlocks() {
    const chosen = $("[data-toggle-block]").filter((box) => box.checked).map((box) => Number(box.dataset.toggleBlock));
    $("[data-block]").forEach((block) => (block.hidden = !chosen.includes(Number(block.dataset.block))));
    $("[data-set]").forEach((button) => {
      button.setAttribute("aria-pressed", String(SETS[button.dataset.set].join() === chosen.join()));
    });
  }

  function useSet(name) {
    $("[data-toggle-block]").forEach((box) => (box.checked = SETS[name].includes(Number(box.dataset.toggleBlock))));
    syncBlocks();
  }

  function exclusive(buttons, chosen, attribute) {
    buttons.forEach((button) => button.setAttribute(attribute, String(button === chosen)));
  }

  document.addEventListener("DOMContentLoaded", () => {
    $("[data-go]").forEach((button) => button.addEventListener("click", () => showPage(button.dataset.go)));
    $("[data-toggle-block]").forEach((box) => box.addEventListener("change", syncBlocks));
    $("[data-set]").forEach((button) => button.addEventListener("click", () => useSet(button.dataset.set)));

    const numbers = document.querySelector("#numbers");
    numbers.addEventListener("change", () => document.body.classList.toggle("show-numbers", numbers.checked));

    const layouts = $("[data-dev-layout]");
    layouts.forEach((button) =>
      button.addEventListener("click", () => {
        exclusive(layouts, button, "aria-pressed");
        document.querySelector('[data-page="developer"]').classList.toggle("dev-side", button.dataset.devLayout === "side");
        showPage("developer");
      }),
    );

    const steps = $("[data-step]");
    steps.forEach((button) =>
      button.addEventListener("click", () => {
        exclusive(steps, button, "aria-selected");
        $("[data-stage]").forEach((stage) => (stage.hidden = stage.dataset.stage !== button.dataset.step));
      }),
    );

    const kinds = $("[data-kind]");
    kinds.forEach((button) => button.addEventListener("click", () => exclusive(kinds, button, "aria-checked")));

    const note = document.querySelector(".review-note");
    $("[data-note]").forEach((button) => button.addEventListener("click", () => (note.textContent = button.dataset.note)));

    // The address picks the opening view, so a link can point at one page, set or layout.
    const query = new URLSearchParams(location.search);
    const theme = query.get("theme");
    if (theme === "tapedeck") document.querySelector('[data-set-theme="tapedeck"]').click();
    if (theme === "aurora") document.querySelector('[data-set-theme="aurora"]').click();
    useSet(query.get("set") in SETS ? query.get("set") : "chosen");
    showPage(query.get("page") === "developer" ? "developer" : "about");
    if (query.get("layout") === "side") document.querySelector('[data-dev-layout="side"]').click();
    const scroll = Number(query.get("scroll"));
    if (scroll) {
      const page = document.querySelector('[data-page="about"]');
      page.style.scrollBehavior = "auto";
      page.scrollTop = scroll;
    }
  });
})();
