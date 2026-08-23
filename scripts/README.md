# Utility Scripts

`scripts/bin/` holds standalone utilities available on `PATH`. chezmoi symlinks
`~/.config/motherbox/bin` to it (`home/dot_config/motherbox/symlink_bin.tmpl`), and the
managed zsh config adds that directory to `PATH`
(`home/dot_config/zsh/exact_zshrc.d/80-path.zsh`).

Every file in `bin/` should be directly executable and support `-h`/`--help`.

## Tools

```bash
256colors                                      # Print terminal color capability output
avitomp4 movie.avi                             # Convert an AVI file to MP4 with ffmpeg
avitomp4 ~/Movies/avi                          # Convert every AVI file in a directory
backgroundify src/ out/ white                  # Add a solid background to transparent images
batch_rename photos Vacation                   # Rename files sequentially with a base name
chezmoi-diff-better                            # Diff files, ignoring JSON object key-order noise
chezmoi-status-better                          # Translate `chezmoi status` codes into plain English
claude-to-agents                               # Converge agent instruction files on one AGENTS.md
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
motherbox-status                               # Check what this repo manages for drift
movtogif clip.mov                              # Convert a video to GIF
nerdglyphs                                     # Browse Nerd Font glyphs
ocr-pdf scan.pdf                               # OCR a PDF
ocrify scan.png                                # OCR an image or PDF into a searchable PDF
splitpdf file.pdf                              # Split a PDF
swap_extension txt md                          # Change matching extensions in the current directory
tcc-sign.sh /path/to/binary                    # Sign ad-hoc binaries so macOS TCC grants persist
tcc-sign.sh refresh                            # Re-sign all previously signed binaries
unfolderify                                    # Flatten folderified directories
unquarantine App.app                           # Remove macOS quarantine attributes
vidmerge clips/ merged                         # Merge videos into one MP4
vidmerge --delete-originals clips/ merged      # Merge videos and remove source files
whats-on-port 3000                             # Show processes listening on a port
whats-on-port 3000 --kill                      # Kill processes listening on a port
```
