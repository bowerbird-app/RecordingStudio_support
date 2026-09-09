===============================================================================

RecordingStudioSupport has been installed successfully!

Staff Support forms are mounted at /admin/support.
Public help is at /help. Both use Recording Studio's default layout.
Put Flatpack's rounded theme on html: `<html data-theme="rounded">`.
Old /support bookmarks redirect to /admin.

If you use Tailwind CSS:
1. Run 'bin/rails tailwindcss:build' to rebuild your CSS with RecordingStudioSupport styles

Staff UI:
1. Sign in, switch to the admin root, then visit http://localhost:3000/admin
2. Open Support pages or Support sections. New, Edit, and preview stay under /admin/support
3. Publish a page from the page's Publish screen
4. Enable `section :support` on your admin root
   Change Help words with help_title / public_help_title / admin_help_title
5. Keep Sign out and Root Switchable off Support and Admin Support screens
6. For the body editor, pin Flatpack TipTap packages and register
   controllers/flat_pack/tiptap_controller as flat-pack--tiptap
   (lazy load is not enough on first paint). Pictures go in the body
   through the editor upload. Do not add Trix or Action Text.

Public UI:
1. Open http://localhost:3000/help without signing in
2. Only live, indexable pages appear
3. Drafts stay hidden until you publish them

===============================================================================
