# Cursie 1.0.1

Cursie 1.0.1 improves Mousecape compatibility for long animated cursor files.

## Highlights

- Fixed an issue where some exported `.cape` files could show a red dot after being applied in Mousecape.
- Improved export handling for animated cursor files with more than 24 frames.
- Long animations are now downsampled more naturally instead of cutting off the tail.
- Exported animations keep the overall motion and duration more closely while staying within a safer frame count.
- Animated cursors that exceed 24 frames are exported as balanced 24-frame versions for better compatibility when applying a theme.

## Notes

- This release is especially relevant for cursor packs that include long animated `.ani` files.
- Existing `.cur` import and preview behavior is unchanged.
- If a source animated cursor has more than 24 frames, Cursie now exports a balanced 24-frame version that preserves the overall duration as closely as possible.
