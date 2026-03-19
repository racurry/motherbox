# Utility Scripts

This directory contains a collection of utility scripts for common file and media operations on macOS. All scripts are located in the `scripts/` directory and include `--help` flags for usage information.

## Video Conversion

### avitomp4

Convert AVI video files to MP4 format using ffmpeg.

```bash
avitomp4 FILE_OR_DIRECTORY
```

- Converts using codec copy (no re-encoding) for fast conversion
- Can process individual files or entire directories
- Preserves original file names with new extension

**Requirements:** ffmpeg

### mkvtomp4

Convert MKV video files to MP4 format using ffmpeg.

```bash
mkvtomp4 FILE_OR_DIRECTORY
```

- Converts using codec copy (no re-encoding) for fast conversion
- Can process individual files or entire directories
- Preserves original file names with new extension

**Requirements:** ffmpeg

### vidmerge

Merge multiple video files into a single MP4.

```bash
vidmerge FILE1 FILE2 ... OUTPUT_NAME
vidmerge DIRECTORY OUTPUT_NAME
vidmerge --delete-originals FILE1 FILE2 ... OUTPUT_NAME
```

- Concatenates videos using ffmpeg
- Can merge specified files or all files in a directory
- Optional `--delete-originals` flag to remove source files after merging
- Files are merged in alphabetical order when using directory mode

**Requirements:** ffmpeg

## Image Processing

### backgroundify

Add solid color backgrounds to transparent images.

```bash
backgroundify SOURCE_DIR TARGET_DIR COLOR
```

- Replaces transparent pixels with specified color
- Color can be name ('white'), hex ('#FFFFFF'), or RGB ('rgb(255,255,255)')
- Processes entire directories
- Uses 25% fuzz tolerance for better edge blending

**Requirements:** ImageMagick (convert)

### iconify

Create macOS .icns icon files from images.

```bash
iconify SOURCE_IMAGE
```

- Generates all required macOS icon sizes (16x16 to 512x512)
- Creates both standard and @2x retina versions
- Outputs icon.icns in current directory
- Automatically creates icon.iconset directory for intermediate files

**Requirements:** ImageMagick (convert), iconutil

### ocrify

Perform OCR (Optical Character Recognition) on images or PDFs.

```bash
ocrify FILE
```

- Converts input to TIFF format at 300 DPI
- Performs OCR using Tesseract
- Outputs searchable PDF named FILENAME-ocred.pdf
- Optimized for English text

**Requirements:** ImageMagick (convert), Tesseract

## File Organization

### folderify

Move each file into its own subdirectory.

```bash
folderify DIRECTORY
```

- Creates subdirectory for each file based on filename (without extension)
- Moves file into its new subdirectory
- Example: `file.txt` becomes `file/file.txt`
- Useful for organizing files that need individual folders

### unfolderify

Flatten directory structure by moving all files to current directory.

```bash
unfolderify
```

- Recursively moves all files from subdirectories to current directory
- Reverse operation of folderify
- Subdirectories remain (but are empty)
- Must be run from the directory you want to flatten

## File Naming

### batch_rename

Rename files with sequential numbering.

```bash
batch_rename DIRECTORY BASE_NAME
```

- Renames all files to BASE_NAME1.ext, BASE_NAME2.ext, etc.
- Preserves file extensions
- Numbers files sequentially starting from 1
- Processes all files in specified directory

### filename_fixer

Clean up and standardize filenames.

```bash
filename_fixer DIRECTORY [OPTIONS]
```

Options:

- `--dedot` - Replace dots with spaces
- `--strip-digits` - Remove all numeric characters

Features:

- Always removes extra whitespace
- Always preserves file extensions
- Can combine multiple options

Example:

```bash
filename_fixer /path/to/dir --dedot --strip-digits
```

### swap_extension

Change file extensions in bulk.

```bash
swap_extension CURRENT_EXT NEW_EXT
```

- Changes all files with CURRENT_EXT to NEW_EXT
- Operates only in current directory
- Extensions should be specified without dots
- Example: `swap_extension txt md`

## Claude Code Development

### ccmcps

Manage Claude MCP (Model Context Protocol) servers.

```bash
ccmcps                      # Show status (default)
ccmcps status              # Show enabled/disabled status
ccmcps list                # List current MCP servers
ccmcps disable [SERVER]    # Disable all or specific server
ccmcps enable [SERVER]     # Enable all or specific server
```

- Helps manage Claude Code CLI context by toggling MCP servers
- Backs up server configurations when disabling
- Restores from backup when enabling
- Useful for saving context window space when not all servers are needed

**Requirements:** Claude CLI (`claude`)

## Getting Help

All scripts support `-h` or `--help` flags to display usage information:

```bash
scriptname --help
```

## Installation

These scripts are automatically added to your PATH when you run `./run/setup.sh` from this repository. They can then be called from anywhere on your system.
