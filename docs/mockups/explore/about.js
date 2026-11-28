// Small interactions of the About prototype.
document.addEventListener("DOMContentLoaded", () => {
  const note = document.querySelector(".review-note");
  document.querySelectorAll("[data-note]").forEach((link) => link.addEventListener("click", () => (note.textContent = link.dataset.note)));

  // The address can pick the theme; only listed values are accepted.
  const theme = new URLSearchParams(location.search).get("theme");
  if (theme === "tapedeck" || theme === "aurora") document.querySelector(`[data-set-theme="${theme}"]`).click();
});
