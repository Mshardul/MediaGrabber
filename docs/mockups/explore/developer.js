// Review controls and the photo ring of the Developer page prototype.
(() => {
  const reducedMotion = matchMedia("(prefers-reduced-motion: reduce)");

  // Uses the oracle orb's own ring drawing, with the photo standing where its sphere would be.
  function oracleRings(portrait, area) {
    const layers = [portrait.querySelector(".ring-front"), portrait.querySelector(".ring-back")];
    const rings = Object.assign(Object.create(Orb.prototype), { glow: 0, fog: 0, search: 0, swirl: 0 });
    let aim = [0, 0];
    let look = [0, 0];
    area.addEventListener("pointermove", (event) => {
      const box = portrait.getBoundingClientRect();
      const reach = area.getBoundingClientRect().width / 2;
      const lean = (distance) => Math.max(-1, Math.min(1, distance / reach));
      aim = [lean(event.clientX - box.x - box.width / 2), lean(box.y + box.height / 2 - event.clientY)];
    });
    area.addEventListener("pointerleave", () => (aim = [0, 0]));

    function draw(milliseconds) {
      const tape = document.documentElement.dataset.theme === "tapedeck";
      const still = reducedMotion.matches;
      look = look.map((value, index) => value + ((still ? 0 : aim[index]) - value) * 0.07);
      const seconds = still ? 6.4 : tape ? Math.floor((milliseconds / 1000) * 12) / 12 : milliseconds / 1000;
      const yaw = (tape ? 0.42 : 0.2) * seconds - look[0] * 1.25;
      const pitch = 0.28 + look[1] * 0.95;
      const [cy, sy, cp, sp] = [Math.cos(yaw), Math.sin(yaw), Math.cos(pitch), Math.sin(pitch)];
      rings.m = [cy, 0, sy, sp * sy, cp, -sp * cy, -cp * sy, sp, cp * cy];

      const [front, back] = layers.map((canvas) => {
        const size = canvas.clientWidth;
        const density = Math.min(devicePixelRatio, 2);
        const pixels = Math.round(size * density);
        if (canvas.width !== pixels) canvas.width = canvas.height = pixels;
        const context = canvas.getContext("2d");
        context.setTransform(density, 0, 0, density, 0, 0);
        context.clearRect(0, 0, size, size);
        return context;
      });
      const size = layers[0].clientWidth;
      rings.orbit(front, back, seconds, size / 2, portrait.clientWidth / 2, tape);
      requestAnimationFrame(draw);
    }
    requestAnimationFrame(draw);
  }

  document.addEventListener("DOMContentLoaded", () => {
    const area = document.querySelector(".window");
    document.querySelectorAll("[data-note]").forEach((link) =>
      link.addEventListener("click", () => (document.querySelector(".review-note").textContent = link.dataset.note)),
    );

    // The address picks the opening view; only listed values are accepted.
    const query = new URLSearchParams(location.search);
    const theme = query.get("theme");
    if (theme === "aurora" || theme === "tapedeck") document.querySelector(`[data-set-theme="${theme}"]`).click();

    oracleRings(area.querySelector(".portrait"), area);
  });
})();
