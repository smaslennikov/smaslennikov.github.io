(function () {
  "use strict";

  /* Theme toggle: flips away from whatever is currently showing, then remembers. */
  var root = document.documentElement;
  var toggle = document.querySelector(".theme-toggle");

  function currentTheme() {
    var explicit = root.getAttribute("data-theme");
    if (explicit) return explicit;
    return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
  }

  if (toggle) {
    toggle.addEventListener("click", function () {
      var next = currentTheme() === "dark" ? "light" : "dark";
      root.setAttribute("data-theme", next);
      try {
        localStorage.setItem("theme", next);
      } catch (e) {}
    });
  }

  /* markdown-toc fences its output in <!-- toc --> / <!-- tocstop --> comments,
     which survive into the HTML. Wrap what's between them so the contents list
     reads as a sidebar-ish aside rather than a wall of links. */
  var content = document.getElementById("content");
  if (content) {
    var walker = document.createTreeWalker(content, NodeFilter.SHOW_COMMENT, null, false);
    var start = null;
    var node;
    while ((node = walker.nextNode())) {
      if (node.nodeValue.trim() === "toc") {
        start = node;
        break;
      }
    }
    if (start) {
      var nav = document.createElement("nav");
      nav.className = "toc";
      nav.setAttribute("aria-label", "Contents");
      var heading = document.createElement("p");
      heading.className = "toc__label";
      heading.textContent = "Contents";
      nav.appendChild(heading);
      start.parentNode.insertBefore(nav, start);

      var cursor = nav.nextSibling;
      while (cursor) {
        var next = cursor.nextSibling;
        var done = cursor.nodeType === 8 && cursor.nodeValue.trim() === "tocstop";
        if (cursor !== start && !done) nav.appendChild(cursor);
        if (done) break;
        cursor = next;
      }
    }
  }

  /* Markdown emits bare <table>s; give the wide ones their own scroll context
     so the page body never scrolls sideways. */
  var tables = document.querySelectorAll(".content table");
  for (var i = 0; i < tables.length; i++) {
    var table = tables[i];
    if (table.parentNode.classList.contains("table-scroll")) continue;
    var wrap = document.createElement("div");
    wrap.className = "table-scroll";
    table.parentNode.insertBefore(wrap, table);
    wrap.appendChild(table);
  }
})();
