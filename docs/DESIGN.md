# Cloud Club design review

## Direction

Taste skill: Editorial greeting, seed 1131462837. No redraws. The face is a pale blue-grey taken from the sky, with Instrument Sans for the interface and Instrument Serif for the greeting and screen titles. The signature is the cloud photograph as a personal postcard: large in the feed, square in the profile, and immediately previewed in the composer.

The user's diagram sets the destinations: Clouds, Post (+), Profile. On a phone they are a fixed bottom navigation bar. Desktop uses the same three destinations in a 224px sidebar and a white sheet on a pale blue-grey frame.

## Screen questions

- Clouds: What did other people see in the sky? Large photographs lead, with photographer, caption, optional location, and real likes.
- Post: Which piece of my sky do I want to share? A selectable photo preview is followed by caption, location, best-cloud toggle, and one publish action.
- Profile: Which clouds feel most like me? The photo, name, bio, and best-cloud gallery lead; All clouds keeps the complete personal history accessible.

## Data inventory

1. Member identity: persisted account name and editable avatar.
2. Bio: up to 160 characters, persisted per account.
3. Photo: JPEG, PNG, or WebP, up to 5 MB.
4. Caption: required, up to 500 characters.
5. Location: optional text, up to 80 characters; no location permission is requested.
6. Post date: server time, rendered as relative recency.
7. Likes: actual per-member rows, unique per photo/member pair.
8. Best-cloud status: selected by the photographer, not an invented popularity score.
9. Feed: all members, newest first, 12 photos per page.
10. Profile: only the signed-in member's photos; older pages remain accessible.
11. Empty accounts: zero photos and no seeded community posts.
12. Errors, loading, picker cancellation, ownership restrictions, and logout remain visible states.

## Verification

- The original localhost preview was unavailable when the before capture was attempted; no before/after measurement claim is made.
- The taste HTML source linter does not parse Dart.
- The taste DOM inspector ran at 1440, 768, and 390px. Its font/title/void results are not reliable for Flutter's canvas: it reports no DOM text while its screenshots visibly show both bundled typefaces, titles, forms, and photography. The report is retained locally under .taste-skill, not represented as a passing DOM audit.
- Reviewed the actual login screenshots at all three widths, then the signed-in desktop feed, mobile feed/profile/composer, and tablet composer in the browser.
- Real file selection, upload, liking, best-cloud appearance, avatar upload, and bio saving were exercised through the browser using a temporary local review account.
- Flutter layout tests cover 320x480, 640x320, 768x1024, 1440x900, safe areas, and 1.6x text size.
- Backend tests exercise cross-account visibility, persistent photos/profile data, upload validation, idempotent likes, owner-only mutations, cascading like cleanup, and pagination.

## Critique and refinements

The photo answers the feed's question first; navigation stays quiet. Counts come from API rows, and missing profile data has an honest empty state. One photograph in a new gallery stays one photograph rather than being padded with sample posts. Phone controls stay in the bottom navigation, and long forms scroll above it.

The first test round caught oversized toolbars with enlarged text and a Material surface that hid touch feedback. These were corrected and all screen tests passed. The tablet review caught a square upload preview pushing the entire form below the fold; the two-column composer now begins at 640px of available content width.

Final visual assessment: the three destinations follow the drawing, photography has clear priority, the blue-grey frame belongs to the subject, and small screens retain usable controls. The remaining limit is a deliberately empty first community: it needs real uploaded photos, not fabricated members or engagement. This local build also needs production hosting and moderation before a public launch.

## Preview content and credits

A temporary local account named Sky, a sample bio, and one licensed cloud photo were used only for browser checks and screenshots. They are removed after verification. No sample posts are seeded in application code.

Welcome photo: Blue sky background clouds, CC0, via rawpixel: https://www.rawpixel.com/image/6039137/photo-image-background-cloud-public-domain . Its credit is displayed below the empty feed image and recorded in assets/credits.json and README.md. It is a welcome illustration, not a member's post.

Instrument Sans and Instrument Serif are bundled with their SIL Open Font License texts in assets/fonts.
