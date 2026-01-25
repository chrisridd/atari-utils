A couple of utilities for looking at Atari ST files, in particular:

* GDOS bitmap font files
* IMG bitmap image files
* Generate a proportional version of the system font

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

```
$ sunnyvale
```

Will produce `FMSV10.FNT`, `FMSV09.FNT` and `FMSV08.FNT` files from the fonts in emutos,
which remove the amount of padding around various characters, effectively making a
proportional version of the system font. Sadly XaAES does not work very well with
proportional fonts, but apps like QED work fine. It was an interesting experiment. The
fonts are called "Sunnyvale" as a nod to Atari's address in California.