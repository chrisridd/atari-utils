# What is this?

This is a Swift package containing two command-line tools to convert PNG files to Atari
IMG files, and back again.

## Building

In this directory (containing `README.md` and `Package.swift`) run:

```
$ swift build
$ swift run img2png --help
$ ls .build/arm64-apple-macosx/debug/img2png .build/arm64-apple-macosx/debug/png2img
 .build/arm64-apple-macosx/debug/img2png .build/arm64-apple-macosx/debug/png2img
```

If you open `Package.swift` in Xcode, it will open the entire Swift package.

## Running img2png

To convert an Atari IMG file to a PNG file, run:

```
$ ls example.*
 example.img
$ img2png example.img
$ ls example.*
 example.img example.png
```

There aren’t any options; it either works or it doesn’t and reports an error.

## Running png2img

To convert a PNG file to an Atari IMG file, run:

```
$ ls example.*
 example.png
$ png2img example.png
$ ls example.*
 example.png example.img
```

However there are several other arguments you can use. Firstly you can choose to remap the
colours to a particular palette. You can choose the common "NVDI" palette, or the
traditional "GEM" palette or you can choose a specific Atari palette file. Atari palette
files have a `.pal` extension.

Then you can choose if you want a specific bit depth of image. The default is to produce
an image with the smallest possible bit depth. The smallest possible bit depth is 1-bit,
and the largest is 8-bit. If the PNG has too many colours for your chosen bit depth the
conversion will fail.

In most cases a colour palette will be included in the 'XIMG' format. 1-bit images that
are just black and white will not have a colour palette.
