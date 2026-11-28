(() => {
  const KEY = "mg-mockups-look";
  const root = document.documentElement;

  const buttons = () => document.querySelectorAll("[data-set-palette]");

  function read() {
    try {
      return JSON.parse(localStorage.getItem(KEY));
    } catch (error) {
      console.warn("Saved theme choice could not be read", error);
      return null;
    }
  }

  function apply(theme, palette) {
    root.dataset.theme = theme;
    root.dataset.palette = palette;
    buttons().forEach((button) => {
      const on = button.dataset.setTheme === theme && button.dataset.setPalette === palette;
      button.setAttribute("aria-pressed", String(on));
    });
  }

  function choose(theme, palette) {
    apply(theme, palette);
    try {
      localStorage.setItem(KEY, JSON.stringify({ theme, palette }));
    } catch (error) {
      console.warn("Theme choice could not be saved", error);
    }
  }

  // Applied before the body is parsed, so a page never flashes the default look.
  const saved = read();
  if (saved?.theme && saved?.palette) apply(saved.theme, saved.palette);

  document.addEventListener("DOMContentLoaded", () => {
    buttons().forEach((button) => {
      button.addEventListener("click", () => {
        choose(button.dataset.setTheme, button.dataset.setPalette);
      });
    });
    apply(root.dataset.theme, root.dataset.palette);
  });
})();
