
#!/bin/bash

# checker.sh: Check installed npm package versions against versions listed in CSV file
# Usage:
#   ./checker.sh <path-to-npm-project>
#   ./checker.sh -r <base-path>  # recursively check all npm projects under base-path

if [ $# -lt 1 ]; then
  echo "Usage: $0 <path-to-npm-project>"
  echo "   or: $0 -r <base-path>  # recursively check all npm projects under base-path"
  exit 1
fi

# Check bash version to use associative arrays or fallback
bash_version_major=$(bash --version | head -n1 | sed -E 's/.*version ([0-9]+).*/\1/')
if [ "$bash_version_major" -ge 4 ]; then
  USE_ASSOC_ARRAY=1
else
  USE_ASSOC_ARRAY=0
fi

# Load CSV into arrays for POSIX compatibility
CSV_FILE="shai-hulud-2-packages.csv"

if [ ! -f "$CSV_FILE" ]; then
  echo "CSV file $CSV_FILE not found!"
  exit 1
fi

impacted_packages=()
impacted_versions=()
while IFS=, read -r package version
do
  # Skip header
  if [ "$package" = "Package" ]; then
    continue
  fi
  impacted_packages+=("$package")
  impacted_versions+=("$version")
done < "$CSV_FILE"

# Function to check a single npm project path
check_project_path() {
  local PROJECT_PATH="$1"

  if [ ! -f "$PROJECT_PATH/package.json" ]; then
    echo "Skipping $PROJECT_PATH (no package.json found)"
    return
  fi

  npm_list_json=$(npm list --json --prefix "$PROJECT_PATH" 2>/dev/null)
  if [ -z "$npm_list_json" ] || echo "$npm_list_json" | grep -q '"dependencies":null'; then
    echo "npm list failed or no dependencies found in $PROJECT_PATH"
    return
  fi

  if command -v jq > /dev/null; then
    echo "$npm_list_json" | jq -r '.dependencies | to_entries[] | "\(.key) \(.value.version)"' > /tmp/installed_packages.txt
  else
    npm list --prefix "$PROJECT_PATH" > /tmp/npm_list.txt 2>/dev/null
    grep -E '^[├└]── ' /tmp/npm_list.txt | awk -F' ' '{print $2}' | sed 's/@/ /' > /tmp/installed_packages.txt
  fi

  echo "Checking packages installed in $PROJECT_PATH against compromised packages..."

  packages_with_issue_count=0
  packages_with_issue_list=()
  packages_with_potential_issue_count=0
  packages_with_potential_issue_list=()

  total_installed_packages=0

  while read -r pkg ver; do
    total_installed_packages=$((total_installed_packages + 1))

    found_idx=-1
    for i in "${!impacted_packages[@]}"; do
      if [ "${impacted_packages[i]}" = "$pkg" ]; then
        found_idx=$i
        break
      fi
    done

    if [ "$found_idx" -ge 0 ]; then
      impacted="${impacted_versions[$found_idx]}"
      impacted_clean=$(echo "$impacted" | sed 's/= //g')
      IFS='||' read -r -a impacted_array <<< "$impacted_clean"

      matched=0
      for av in "${impacted_array[@]}"; do
        trimmed_av=$(echo "$av" | xargs)
        if [ "$ver" = "$trimmed_av" ]; then
          matched=1
          break
        fi
      done

      if [ $matched -eq 1 ]; then
        packages_with_issue_count=$((packages_with_issue_count+1))
        packages_with_issue_list+=("$pkg@$ver")
      else
        packages_with_potential_issue_count=$((packages_with_potential_issue_count+1))
        packages_with_potential_issue_list+=("$pkg@$ver (impacted: $impacted_clean)")
      fi
    fi
  done < /tmp/installed_packages.txt

  echo ""
  echo "🗒️  SUMMARY for $PROJECT_PATH"
  echo ""
  echo "Total installed packages analyzed: $total_installed_packages"
  echo "Total packages with issue: $packages_with_potential_issue_count"
  echo "Total packages to fix: $packages_with_issue_count"

  if [ $packages_with_potential_issue_count -gt 0 ]; then
    echo ""
    echo "⚠️  ${packages_with_potential_issue_count} packages concerned by the issue"
    for p in "${packages_with_potential_issue_list[@]}"; do
      echo "  - $p"
    done
    echo ""
    echo "You should verify these packages for potential issues."
  fi

  if [ $packages_with_issue_count -gt 0 ]; then
    echo ""
    echo "🚨  ${packages_with_issue_count} issues found:"
    for p in "${packages_with_issue_list[@]}"; do
      echo "  - $p"
    done
    echo ""
    echo "You should fix the version of these packages."
  fi

  if [ $packages_with_potential_issue_count -eq 0 ] && [ $packages_with_issue_count -eq 0 ]; then
    echo ""
    echo "✅  No issues found with installed packages."
  fi
}

# Main logic to handle arguments
if [ "$1" = "-r" ]; then
  if [ $# -ne 2 ]; then
    echo "Usage: $0 -r <base-path>"
    exit 1
  fi
  BASE_PATH="$2"

  if [ ! -d "$BASE_PATH" ]; then
    echo "Base path $BASE_PATH is not a directory"
    exit 1
  fi

  echo "Recursively checking npm projects under $BASE_PATH"

  # Replace recursive find with immediate subdirectory scan for package.json existence
  npm_dirs=()
  for dir in "$BASE_PATH"/*/; do
    if [ -f "${dir}package.json" ]; then
      npm_dirs+=("$dir")
    fi
  done

  if [ ${#npm_dirs[@]} -eq 0 ]; then
    echo "No npm projects found under $BASE_PATH"
    exit 0
  fi

  for dir in "${npm_dirs[@]}"; do
    check_project_path "$dir"
  done
else
  # Single project mode
  check_project_path "$1"
fi

exit 0
