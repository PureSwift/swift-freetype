// FreeType headers are included through macros (`#include FT_FREETYPE_H`), which
// Swift's Clang importer can't resolve from a module map directly. This shim does it.
#include <ft2build.h>
#include FT_FREETYPE_H
#include FT_ERRORS_H
#include FT_GLYPH_H
#include FT_OUTLINE_H
#include FT_BITMAP_H
#include FT_MULTIPLE_MASTERS_H
#include FT_ADVANCES_H
#include FT_SFNT_NAMES_H
#include FT_BBOX_H
