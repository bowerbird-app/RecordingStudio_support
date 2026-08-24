===============================================================================

RecordingStudioSupport has been installed successfully!

Authenticated help screens are mounted at /support.

If you use Tailwind CSS:
1. Run 'bin/rails tailwindcss:build' to rebuild your CSS with RecordingStudioSupport styles

Staff UI:
1. Sign in, then visit http://localhost:3000/support
2. Search the list with a full-width ?q= box (authenticated only)
3. Enable `section :support` on your admin root and open /admin
   Change Help words with pages_title / pages_subtitle / admin_section_title
4. Keep Sign out and Root Switchable off Support screens
4. For the body editor, pin Flatpack TipTap packages and register
   controllers/flat_pack/tiptap_controller as flat-pack--tiptap
   (lazy load is not enough on first paint). Do not add Trix or Action Text.

===============================================================================
