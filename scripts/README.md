# Utility Scripts

Standalone utilities symlinked to `~/.config/motherbox/scripts` by
`./run/sync.sh`. That directory is added to `PATH` by the managed zsh config.

Every file here should be directly executable and support `-h`/`--help` when it
has a CLI surface.

## Tools

```bash
256colors                                      # Print terminal color capability output
asdf-uninstall                                 # Disable an old asdf install after migration
avitomp4 movie.avi                             # Convert an AVI file to MP4 with ffmpeg
avitomp4 ~/Movies/avi                          # Convert every AVI file in a directory
backgroundify src/ out/ white                  # Add a solid background to transparent images
batch_rename photos Vacation                   # Rename files sequentially with a base name
chezmoi-diff-ignore-json-key-order             # Diff JSON files without object key-order noise
filename_fixer downloads --dedot               # Normalize names and replace dots with spaces
filename_fixer downloads --strip-digits        # Normalize names and remove digits
folderify ~/Downloads/items                    # Move each file into its own folder
folderpaint set --folder ~/Docs --color "#34C759" # Set a colored macOS folder icon
folderpaint clear --folder ~/Docs              # Remove a custom folder icon
gh-pr                                          # Show open GitHub PR status
gh-pr --update                                 # Rebase PRs that are behind their base branch
granola-sync sync                              # Sync Granola notes to local files and Obsidian
granola-sync fetch                             # Fetch raw Granola notes only
gwt feature-branch                             # Create an isolated reference clone for a branch
gwt -e main                                    # Create a clone tracking an existing branch
gwt list                                       # List reference clones
gwt remove feature-branch                      # Remove a reference clone
iconify icon.png                               # Create icon.icns from an image
mkvtomp4 movie.mkv                             # Convert an MKV file to MP4 with ffmpeg
mkvtomp4 ~/Movies/mkv                          # Convert every MKV file in a directory
movtogif clip.mov                              # Convert a video to GIF
nerdglyphs                                     # Browse Nerd Font glyphs
ocr-pdf scan.pdf                               # OCR a PDF
ocrify scan.png                                # OCR an image or PDF into a searchable PDF
splitpdf file.pdf                              # Split a PDF
swap_extension txt md                          # Change matching extensions in the current directory
unfolderify                                    # Flatten folderified directories
unquarantine App.app                           # Remove macOS quarantine attributes
vidmerge clips/ merged                         # Merge videos into one MP4
vidmerge --delete-originals clips/ merged      # Merge videos and remove source files
whats-on-port 3000                             # Show processes listening on a port
whats-on-port 3000 --kill                      # Kill processes listening on a port
```

## Installation

Run:

```bash
./run/sync.sh
```

`./run/setup.sh` also calls this automatically.
