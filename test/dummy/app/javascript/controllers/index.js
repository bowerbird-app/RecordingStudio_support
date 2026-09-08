import { application } from "controllers/application"
import TiptapController from "controllers/flat_pack/tiptap_controller"

// Eager load all controllers defined in the import map under controllers/**/*_controller
import { eagerLoadControllersFrom, lazyLoadControllersFrom } from "@hotwired/stimulus-loading"
eagerLoadControllersFrom("controllers", application)

// Rich-text TextArea relies on the engine's nested TipTap controller being
// available on first paint. Lazy load maps the identifier, but the editor
// surface stays empty until this nested controller is registered.
application.register("flat-pack--tiptap", TiptapController)

// Lazy load FlatPack controllers on first use.
// FlatPack identifiers are namespaced (e.g. flat-pack--icon),
// so lazy loading must start at "controllers" to avoid duplicate path segments.
lazyLoadControllersFrom("controllers", application)
eagerLoadControllersFrom("controllers/recording_studio_attachable", application)
