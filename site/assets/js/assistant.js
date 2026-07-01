(function () {
  "use strict";

  var API_ENDPOINT = "https://api.ronaldoauguste.com/chat";
  var MAX_LENGTH = 500;
  var SUGGESTIONS = [
    "Tell me about Ronaldo's AWS experience",
    "What projects has he built?",
    "What certifications does he have?",
    "Explain the Cloud Resume Challenge",
    "What technologies has he used?"
  ];

  function el(tag, className, text) {
    var e = document.createElement(tag);
    if (className) e.className = className;
    if (text) e.textContent = text;
    return e;
  }

  function init() {
    var root = el("div", "resume-assistant");

    var toggle = el("button", "resume-assistant__toggle", "Ask Ronaldo");
    toggle.type = "button";
    toggle.setAttribute("aria-label", "Open resume assistant");

    var panel = el("div", "resume-assistant__panel");
    panel.hidden = true;

    var header = el("div", "resume-assistant__header");
    header.appendChild(el("span", "resume-assistant__title", "Ask about Ronaldo"));
    var closeBtn = el("button", "resume-assistant__close", "×");
    closeBtn.type = "button";
    closeBtn.setAttribute("aria-label", "Close assistant");
    header.appendChild(closeBtn);

    var messages = el("div", "resume-assistant__messages");

    var suggestions = el("div", "resume-assistant__suggestions");
    SUGGESTIONS.forEach(function (q) {
      var chip = el("button", "resume-assistant__chip", q);
      chip.type = "button";
      chip.addEventListener("click", function () {
        sendMessage(q);
      });
      suggestions.appendChild(chip);
    });
    messages.appendChild(suggestions);

    var inputRow = el("div", "resume-assistant__input-row");
    var input = el("input", "resume-assistant__input");
    input.type = "text";
    input.maxLength = MAX_LENGTH;
    input.placeholder = "Ask a question…";
    var sendBtn = el("button", "resume-assistant__send", "Send");
    sendBtn.type = "button";

    inputRow.appendChild(input);
    inputRow.appendChild(sendBtn);

    panel.appendChild(header);
    panel.appendChild(messages);
    panel.appendChild(inputRow);

    root.appendChild(panel);
    root.appendChild(toggle);
    document.body.appendChild(root);

    toggle.addEventListener("click", function () {
      panel.hidden = !panel.hidden;
      if (!panel.hidden) input.focus();
    });
    closeBtn.addEventListener("click", function () {
      panel.hidden = true;
    });

    function addBubble(text, who) {
      var bubble = el("div", "resume-assistant__bubble resume-assistant__bubble--" + who, text);
      messages.appendChild(bubble);
      messages.scrollTop = messages.scrollHeight;
      return bubble;
    }

    var sending = false;

    function sendMessage(text) {
      var trimmed = (text || "").trim();
      if (!trimmed || sending) return;

      sending = true;
      sendBtn.disabled = true;
      input.value = "";

      addBubble(trimmed, "user");
      var pending = addBubble("Thinking…", "assistant pending");

      fetch(API_ENDPOINT, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ message: trimmed })
      })
        .then(function (res) {
          return res
            .json()
            .catch(function () {
              return {};
            })
            .then(function (data) {
              if (res.status === 429) {
                pending.textContent = "I'm getting a lot of questions right now — try again in a bit.";
              } else if (!res.ok) {
                pending.textContent = data.error || "Something went wrong. Please try again.";
              } else {
                pending.textContent = data.reply || "I'm not sure how to answer that.";
              }
            });
        })
        .catch(function () {
          pending.textContent = "Couldn't reach the assistant. Check your connection and try again.";
        })
        .finally(function () {
          pending.classList.remove("resume-assistant__bubble--pending");
          sending = false;
          sendBtn.disabled = false;
        });
    }

    sendBtn.addEventListener("click", function () {
      sendMessage(input.value);
    });
    input.addEventListener("keydown", function (e) {
      if (e.key === "Enter") sendMessage(input.value);
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
