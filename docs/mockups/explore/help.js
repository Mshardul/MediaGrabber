// Small interactions of the Help prototype.
(() => {
  const $ = (selector) => [...document.querySelectorAll(selector)];

  function exclusive(buttons, chosen, attribute) {
    buttons.forEach((button) => button.setAttribute(attribute, String(button === chosen)));
  }

  // One sidebar item is one page, as in Preferences.
  function show(id) {
    $("[data-section]").forEach((section) => (section.hidden = section.id !== id));
    $("[data-jump]").forEach((button) => {
      if (button.dataset.jump === id) button.setAttribute("aria-current", "page");
      else button.removeAttribute("aria-current");
    });
    document.querySelector(".page").scrollTop = 0;
  }

  document.addEventListener("DOMContentLoaded", () => {
    $("[data-jump]").forEach((button) => button.addEventListener("click", () => show(button.dataset.jump)));

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

    const query = new URLSearchParams(location.search);
    const theme = query.get("theme");
    if (theme === "tapedeck" || theme === "aurora") document.querySelector(`[data-set-theme="${theme}"]`).click();
    const ids = $("[data-section]").map((section) => section.id);
    show(ids.includes(query.get("section")) ? query.get("section") : ids[0]);
  });
})();
