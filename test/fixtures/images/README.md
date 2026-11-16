# Codec compatibility fixtures

- `orientation_6.jpg`: opaque 400×300 RGB JPEG with EXIF orientation 6. The
  software codec exposes oriented 300×400 dimensions. Created with the already
  installed image 4.10.1 encoder; contains no source metadata or personal data.
- `animated_1800x2.gif`: two opaque 1800×2 frames (red then blue), each 100ms.
  Tests retain this source above the 1728 request ceiling to expose the current
  engine multiframe resize limitation, rather than silently treating it as a
  bounded-output guarantee. Created with the same encoder.

These tiny committed inputs exercise real codecs; no fixture generator is
required at test runtime and no dependency is added.
