/* Briefkist site JS — theme toggle + mobile drawer. Vanilla, no deps. */
(function () {
  "use strict";

  function applyTheme(theme) {
    if (theme === "dark") document.documentElement.setAttribute("data-theme", "dark");
    else document.documentElement.removeAttribute("data-theme");
  }

  function toggleTheme() {
    var dark = document.documentElement.getAttribute("data-theme") === "dark";
    var next = dark ? "light" : "dark";
    try { localStorage.setItem("bk-theme", next); } catch (e) { /* private mode */ }
    applyTheme(next);
  }

  document.addEventListener("click", function (ev) {
    var el = ev.target.closest ? ev.target.closest("[data-bk]") : null;
    if (!el) return;
    var action = el.getAttribute("data-bk");
    if (action === "theme") {
      toggleTheme();
    } else if (action === "open-menu" || action === "close-menu") {
      var drawer = document.getElementById("bk-drawer");
      if (drawer) drawer.classList.toggle("open", action === "open-menu");
    } else if (el.getAttribute("aria-disabled") === "true") {
      ev.preventDefault();
    }
  });

  // Links marked coming-soon must not navigate.
  document.addEventListener("click", function (ev) {
    var a = ev.target.closest ? ev.target.closest('a[aria-disabled="true"]') : null;
    if (a) ev.preventDefault();
  });
})();
