-- Repository: mk-bluebird/Prometheus-Praxis
-- Filename: lua/eco_restoration/assistive_panel_multimodal_theme.lua
-- Destination: lua/eco_restoration/

local Theme = {}

Theme.css = [[
:root {
  --assistive-panel-surface: #f5fbf7;
  --assistive-panel-surface-strong: #e2f2e7;
  --assistive-panel-text: #10281a;
  --assistive-panel-muted-text: #3b5946;
  --assistive-panel-primary: #176b3a;
  --assistive-panel-primary-strong: #0d4d28;
  --assistive-panel-focus: #0b5fff;
  --assistive-panel-warning: #8a4b00;
  --assistive-panel-border: #8db59a;
  --assistive-panel-selected: #d8f0df;
  --assistive-panel-danger: #9b1c1c;
  --assistive-panel-radius: 0.875rem;
  --assistive-panel-spacing: 1rem;
  --assistive-panel-font-size: 1.125rem;
  --assistive-panel-line-height: 1.6;
}

.assistive-panel {
  box-sizing: border-box;
  max-width: 56rem;
  margin: 0 auto;
  padding: calc(var(--assistive-panel-spacing) * 1.5);
  color: var(--assistive-panel-text);
  background: var(--assistive-panel-surface);
  border: 0.125rem solid var(--assistive-panel-border);
  border-radius: var(--assistive-panel-radius);
  font-family: system-ui, sans-serif;
  font-size: var(--assistive-panel-font-size);
  line-height: var(--assistive-panel-line-height);
}

.assistive-panel *,
.assistive-panel *::before,
.assistive-panel *::after {
  box-sizing: border-box;
}

.assistive-panel__title {
  margin: 0 0 var(--assistive-panel-spacing);
  color: var(--assistive-panel-primary-strong);
  font-size: clamp(1.5rem, 3vw, 2.25rem);
  line-height: 1.2;
}

.assistive-panel__status {
  margin: 0 0 var(--assistive-panel-spacing);
  padding: 0.75rem 1rem;
  color: var(--assistive-panel-muted-text);
  background: var(--assistive-panel-surface-strong);
  border-left: 0.375rem solid var(--assistive-panel-primary);
  border-radius: 0.25rem;
}

.assistive-panel__status[data-state="attention"] {
  color: #4d2900;
  border-left-color: var(--assistive-panel-warning);
}

.assistive-panel__status[data-state="error"] {
  color: #5f1010;
  border-left-color: var(--assistive-panel-danger);
}

.assistive-panel__list {
  display: grid;
  gap: 0.75rem;
  margin: 0;
  padding: 0;
  list-style: none;
}

.assistive-panel__item {
  margin: 0;
}

.assistive-panel__action {
  display: flex;
  width: 100%;
  min-height: 3.5rem;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  padding: 0.875rem 1rem;
  color: var(--assistive-panel-text);
  background: #ffffff;
  border: 0.125rem solid var(--assistive-panel-border);
  border-radius: var(--assistive-panel-radius);
  cursor: pointer;
  font: inherit;
  font-weight: 650;
  text-align: left;
  touch-action: manipulation;
}

.assistive-panel__action:hover {
  background: var(--assistive-panel-surface-strong);
  border-color: var(--assistive-panel-primary);
}

.assistive-panel__action:focus-visible {
  outline: 0.25rem solid var(--assistive-panel-focus);
  outline-offset: 0.25rem;
}

.assistive-panel__action[aria-current="true"],
.assistive-panel__action[data-selected="true"] {
  color: #082415;
  background: var(--assistive-panel-selected);
  border-color: var(--assistive-panel-primary-strong);
  box-shadow: inset 0 0 0 0.125rem var(--assistive-panel-primary-strong);
}

.assistive-panel__shortcut {
  flex: 0 0 auto;
  padding: 0.125rem 0.5rem;
  color: var(--assistive-panel-primary-strong);
  background: var(--assistive-panel-surface-strong);
  border: 0.0625rem solid var(--assistive-panel-border);
  border-radius: 0.375rem;
  font-size: 0.9em;
  font-weight: 700;
}

.assistive-panel__feedback {
  min-height: 2rem;
  margin-top: var(--assistive-panel-spacing);
  padding: 0.75rem 1rem;
  color: var(--assistive-panel-muted-text);
  background: #ffffff;
  border: 0.0625rem solid var(--assistive-panel-border);
  border-radius: 0.5rem;
}

.assistive-panel[data-simplified="true"] {
  max-width: 42rem;
  font-size: 1.25rem;
  line-height: 1.75;
}

.assistive-panel[data-simplified="true"] .assistive-panel__action {
  min-height: 4.5rem;
  padding: 1.125rem 1.25rem;
  font-size: 1.2em;
}

.assistive-panel[data-cognitive-load="high"] {
  --assistive-panel-surface: #fffdf5;
  --assistive-panel-surface-strong: #fff4d6;
  --assistive-panel-border: #b99346;
}

@media (prefers-contrast: more) {
  :root {
    --assistive-panel-surface: #ffffff;
    --assistive-panel-surface-strong: #ffffff;
    --assistive-panel-text: #000000;
    --assistive-panel-muted-text: #000000;
    --assistive-panel-primary: #003d1c;
    --assistive-panel-primary-strong: #000000;
    --assistive-panel-border: #000000;
    --assistive-panel-selected: #ffff00;
  }

  .assistive-panel__action {
    border-width: 0.1875rem;
  }
}

@media (prefers-reduced-motion: reduce) {
  .assistive-panel *,
  .assistive-panel *::before,
  .assistive-panel *::after {
    scroll-behavior: auto !important;
    transition-duration: 0.01ms !important;
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
  }
}

@media (max-width: 40rem) {
  .assistive-panel {
    width: 100%;
    padding: 1rem;
    border-radius: 0.5rem;
  }

  .assistive-panel__action {
    min-height: 4rem;
  }
}
]]

function Theme.write_css(path)
    assert(type(path) == "string" and path:match("%S"),
        "path must be a non-empty string")

    local file, error_message = io.open(path, "wb")
    assert(file, error_message)

    local ok, write_error = file:write(Theme.css)
    file:close()

    assert(ok, write_error)
    return true
end

return Theme
