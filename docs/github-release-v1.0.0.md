# Cursie 1.0.0

Cursie converts Windows cursor packs (`.cur`, `.ani`) into Mousecape-compatible `.cape` files on macOS.

## Highlights

- Import Windows cursor folders and preview mapped cursor roles.
- Adjust individual cursor roles by choosing a replacement `.cur` or `.ani` file.
- Preview both large and actual-size cursor rendering before export.
- Export a `.cape` file for use with Mousecape.
- Support core cursor roles plus official Mousecape supplemental cursor slots.
- Keep supplemental cursor slots empty by default and export them only when manually assigned.
- Show built-in default previews for core cursor roles before a cursor pack is loaded.
- Support drag and drop for cursor folders and single cursor files.
- Wrap keyboard navigation through the cursor list.
- Interface available in multiple languages.

## Notes

- Cursie creates `.cape` files. It does not apply system cursors directly.
- For best results, use a cursor pack folder that contains standard Windows cursor files such as `Normal.cur`, `Text.cur`, `Link.cur`, `Busy.ani`, and related resize cursors.
- Some cursor packs combine multiple roles into one file; Cursie will map those where possible and fall back to similar roles when needed.
- Additional cursor slots stay on the macOS default cursor unless you manually assign them.

## System Requirements

- macOS 26.0 or later

## Known Limitations

- Export targets Mousecape-compatible `.cape` files only.
- Cursor names and role mappings may vary depending on the source pack.
- Some Mousecape supplemental cursor slots are intentionally left empty unless you set them yourself.
