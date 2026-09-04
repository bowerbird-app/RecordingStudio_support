// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
// Controllers index registers FlatPack's nested TipTap controller for TextArea rich_text.
import "@hotwired/turbo-rails"
import "controllers"
import * as ActiveStorage from "@rails/activestorage"
ActiveStorage.start()
import "recording_studio_attachable/tiptap/attachment_image_addon"
