# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"

# Pin FlatPack controllers
if defined?(FlatPack::Engine)
  pin_all_from FlatPack::Engine.root.join("app/javascript/flat_pack/controllers"), under: "controllers/flat_pack", to: "flat_pack/controllers", preload: false
  pin_all_from FlatPack::Engine.root.join("app/javascript/flat_pack/tiptap"), under: "flat_pack/tiptap", to: "flat_pack/tiptap", preload: false
  pin "flat_pack/heroicons", to: "flat_pack/heroicons.js", preload: false
end

# FlatPack TextArea rich_text: true loads these packages. Not a separate editor gem.
TIPTAP_VERSION = FlatPack::Tiptap::VERSION unless defined?(TIPTAP_VERSION)

pin "@tiptap/core", to: "https://esm.sh/@tiptap/core@#{TIPTAP_VERSION}"
pin "@tiptap/starter-kit", to: "https://esm.sh/@tiptap/starter-kit@#{TIPTAP_VERSION}"
pin "@tiptap/extension-bubble-menu", to: "https://esm.sh/@tiptap/extension-bubble-menu@#{TIPTAP_VERSION}"
pin "@tiptap/extension-floating-menu", to: "https://esm.sh/@tiptap/extension-floating-menu@#{TIPTAP_VERSION}"
pin "@tiptap/extension-placeholder", to: "https://esm.sh/@tiptap/extension-placeholder@#{TIPTAP_VERSION}"
pin "@tiptap/extension-character-count", to: "https://esm.sh/@tiptap/extension-character-count@#{TIPTAP_VERSION}"
pin "@tiptap/extension-link", to: "https://esm.sh/@tiptap/extension-link@#{TIPTAP_VERSION}"
pin "@tiptap/extension-underline", to: "https://esm.sh/@tiptap/extension-underline@#{TIPTAP_VERSION}"
pin "@tiptap/extension-text-align", to: "https://esm.sh/@tiptap/extension-text-align@#{TIPTAP_VERSION}"

