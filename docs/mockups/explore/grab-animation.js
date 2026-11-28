// Trial only: plays each choice of animation between pressing Grab and pasting the next link.
(() => {
  const view = document.querySelector(".window");
  const orb = view.querySelector(".orb");
  const empty = view.querySelector('[data-state="empty"]');
  const resolved = view.querySelector('[data-state="resolved"]');
  const logo = view.querySelector(".titlebar .logo");
  const downloading = [...view.querySelectorAll(".rail li")].find(
    (row) => row.textContent.trim() === "Downloading",
  );
  const reduced = matchMedia("(prefers-reduced-motion: reduce)");
  let variant = "a";
  let grabbed = 0;
  let run = 0;

  const speed = () => (document.getElementById("slow").checked ? 4 : 1);
  const still = () => reduced.matches || document.getElementById("still").checked;

  function centre(element) {
    const box = element.getBoundingClientRect();
    const frame = view.getBoundingClientRect();
    return {
      x: box.left + box.width / 2 - frame.left - view.clientLeft,
      y: box.top + box.height / 2 - frame.top - view.clientTop,
    };
  }

  function play(element, frames, duration, easing = "cubic-bezier(.5,0,.2,1)") {
    return element.animate(frames, { duration: duration * speed(), easing, fill: "forwards" })
      .finished;
  }

  // A copy of the cards shrinks into the target, so the real field is free at once.
  async function fold(copy, from, target, duration) {
    const to = centre(target);
    await play(
      copy,
      [
        { transform: "translate(0,0) scale(1)", opacity: 1 },
        {
          transform: `translate(${to.x - from.x}px,${to.y - from.y}px) scale(.04)`,
          opacity: 0.2,
        },
      ],
      duration,
    );
    copy.remove();
  }

  function snapshot() {
    const box = resolved.getBoundingClientRect();
    const frame = view.getBoundingClientRect();
    const copy = resolved.cloneNode(true);
    copy.removeAttribute("data-state");
    copy.classList.add("flyer");
    copy.style.left = `${box.left - frame.left - view.clientLeft}px`;
    copy.style.top = `${box.top - frame.top - view.clientTop}px`;
    copy.style.width = `${box.width}px`;
    return { copy, from: centre(resolved) };
  }

  function showEmpty() {
    resolved.hidden = true;
    empty.hidden = false;
    orb.hidden = false;
    orb.dataset.mood = "waiting";
  }

  function showResolved() {
    run += 1;
    view.querySelectorAll(".flyer,.spark").forEach((node) => node.remove());
    orb.hidden = true;
    empty.hidden = true;
    resolved.hidden = false;
  }

  function startRing() {
    if (!logo.querySelector(".logo-ring")) {
      const ring = document.createElement("span");
      ring.className = "logo-ring";
      logo.prepend(ring);
      logo.classList.add("downloading");
    }
    logo.style.setProperty("--progress", `${Math.min(8 + grabbed * 9, 90)}%`);
  }

  function bump(element, size, duration) {
    return play(
      element,
      [{ transform: "scale(1)" }, { transform: `scale(${size})` }, { transform: "scale(1)" }],
      duration,
      "ease-out",
    );
  }

  async function light(from, to, duration) {
    const spark = document.createElement("span");
    spark.className = "spark";
    spark.style.left = `${from.x}px`;
    spark.style.top = `${from.y}px`;
    view.append(spark);
    const dx = to.x - from.x;
    const dy = to.y - from.y;
    await play(
      spark,
      [
        { transform: "translate(0,0) scale(1)" },
        { transform: `translate(${dx * 0.5}px,${dy * 0.5 - 60}px) scale(1.15)` },
        { transform: `translate(${dx}px,${dy}px) scale(.5)` },
      ],
      duration,
    );
    spark.remove();
  }

  function arrive() {
    downloading.classList.add("arrived");
    setTimeout(() => downloading.classList.remove("arrived"), 600 * speed());
  }

  async function grab() {
    grabbed += 1;
    document.getElementById("count").textContent = `Added so far: ${grabbed}.`;
    const mine = ++run;
    const current = () => mine === run;
    if (still() || variant === "d") {
      showEmpty();
      startRing();
      return;
    }
    const { copy, from } = snapshot();
    showEmpty();
    view.append(copy);
    if (variant === "c") {
      await fold(copy, from, logo, 520);
      startRing();
      bump(logo, 1.5, 260);
      return;
    }
    await fold(copy, from, orb, 380);
    if (!current()) return;
    orb.dataset.mood = "drag";
    await bump(orb, 1.08, 240);
    if (!current()) return;
    orb.dataset.mood = "waiting";
    startRing();
    if (variant === "a") {
      await light(centre(orb), centre(downloading), 320);
      if (current()) arrive();
    }
  }

  view.querySelector(".grab .btn").addEventListener("click", grab);
  empty.addEventListener("click", showResolved);
  view.querySelector(".link-row .btn").addEventListener("click", showEmpty);
  document.querySelectorAll("[data-variant]").forEach((button) => {
    button.addEventListener("click", () => {
      variant = button.dataset.variant;
      document.querySelectorAll("[data-variant]").forEach((other) => {
        other.setAttribute("aria-pressed", String(other === button));
      });
      showResolved();
    });
  });
})();
