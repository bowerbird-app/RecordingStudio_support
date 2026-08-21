===============================================================================

RecordingStudioSupport has been installed successfully!

Authenticated help screens are mounted at /support.
Public help is at /help. Public and staff help use Recording Studio's default layout.

If you use Tailwind CSS:
1. Run 'bin/rails tailwindcss:build' to rebuild your CSS with RecordingStudioSupport styles

Staff UI:
1. Sign in, then visit http://localhost:3000/support
2. Search the list with a full-width ?q= box (authenticated only)
3. Publish a page from the page's Publish screen
4. Enable `section :support` on your admin root and open /admin
   Change Help words with pages_title / pages_subtitle / admin_section_title
5. Keep Sign out and Root Switchable off Support screens
6. For the body editor, pin Flatpack TipTap packages and register
   controllers/flat_pack/tiptap_controller as flat-pack--tiptap
   (lazy load is not enough on first paint). Do not add Trix or Action Text.

Public UI:
1. Open http://localhost:3000/help without signing in
2. Only live, indexable pages appear
3. Drafts stay hidden until you publish them

===============================================================================
