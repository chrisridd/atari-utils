A couple of utilities for looking at Atari ST files, in particular:

* GDOS bitmap font files
* IMG bitmap image files

## Usage

```
$ fntinfo ATTR24.FNT
$ fntinfo -bitmap ATTR24.FNT > attr.txt
```

The `-bitmap` flag will output a (very wide) image of the font as text.

```
$ imginfo EXAMPLE.IMG
$ imginfo -png EXAMPLE.IMG
```

The `-png` flag only works for 1, 4, and 8-bit images for now, and will write a file
with the same name except with a '.png' extension. There's a wide variety of IMG files
with either no colour palette, or one stored in an unusual way. This **tries** to do
the right thing, but no doubt fails on edge cases.
