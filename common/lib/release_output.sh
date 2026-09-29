#!/usr/bin/env bash
# Puts a finished build into <project>/Release/ under a versioned name. Source this file.

# Replaces older files named <replace prefix>*.<extension> in the output folder with <artifact>, prints the new path.
# The folder is $RELEASE_OUTPUT_DIR, else <project>/Release; the name is <name>.<extension>. No prefix = every file.
# Usage: result="$(publish_release_file <project root> <artifact> <name> <extension> [replace prefix])"
publish_release_file() {
  local root="$1" artifact="$2" name="$3" extension="$4" replace_prefix="${5:-}"
  local output_dir="${RELEASE_OUTPUT_DIR:-$root/Release}"
  if [ ! -f "$artifact" ]; then
    echo "Build output not found: $artifact" >&2
    exit 1
  fi
  mkdir -p "$output_dir"
  # Release/ keeps only the latest file per prefix and extension, so dev and prod builds do not replace each other.
  find "$output_dir" -maxdepth 1 -type f -name "$replace_prefix*.$extension" -print -delete | sed 's/^/Removed old build: /' >&2
  cp "$artifact" "$output_dir/$name.$extension"
  printf '%s\n' "$output_dir/$name.$extension"
}

# Prints the path, size and SHA-256 of a published file.
print_release_summary() {
  echo
  echo "Output:  $1"
  echo "Size:    $(du -h "$1" | cut -f1)"
  echo "SHA-256: $(shasum -a 256 "$1" | cut -d' ' -f1)"
}
