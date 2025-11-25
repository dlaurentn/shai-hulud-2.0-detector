#!/bin/bash

# checker.sh: Check installed npm package versions against versions listed in CSV file

if [ $# -ne 1 ]; then
  echo "Usage: $0 <path-to-npm-project>"
  exit 1
fi

PROJECT_PATH="$1"
CSV_FILE="shai-hulud-2-packages.csv"

if [ ! -f "$CSV_FILE" ]; then
  echo "CSV file $CSV_FILE not found!"
  exit 1
fi

# Check bash version to use associative arrays or fallback
bash_version_major=$(bash --version | head -n1 | sed -E 's/.*version ([0-9]+).*/\1/')
if [ "$bash_version_major" -ge 4 ]; then
  USE_ASSOC_ARRAY=1
else
  USE_ASSOC_ARRAY=0
fi

impacted_packages=()
impacted_versions=()

# Load CSV into arrays for POSIX compatibility
while IFS=, read -r package version
do
  # Skip header
  if [ "$package" = "Package" ]; then
    continue
  fi
  impacted_packages+=("$package")
  impacted_versions+=("$version")
done < "$CSV_FILE"

# Run npm list in the given project path, ignore errors for extraneous or peer deps
npm_list_json=$(npm list --json --prefix "$PROJECT_PATH" 2>/dev/null)

if [ -z "$npm_list_json" ] || echo "$npm_list_json" | grep -q '"dependencies":null'; then
  echo "npm list failed or no dependencies found in $PROJECT_PATH"
  exit 1
fi

# Parse npm list output from JSON using jq if available, else fallback to text parsing
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

# Count total installed packages
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
    # Remove "= " prefix and split by || to array
    impacted_clean=$(echo "$impacted" | sed 's/= //g')
    IFS='||' read -r -a impacted_array <<< "$impacted_clean"

    matched=0
    for av in "${impacted_array[@]}"; do
      trimmed_av=$(echo "$av" | xargs) # trim spaces
      if [ "$ver" = "$trimmed_av" ]; then
        matched=1
        break
      fi
    done

    if [ $matched -eq 1 ]; then
      # Only report matched packages here if you want to report issues differently
      packages_with_issue_count=$((packages_with_issue_count+1))
      packages_with_issue_list+=("$pkg@$ver")
    else
      packages_with_potential_issue_count=$((packages_with_potential_issue_count+1))
      packages_with_potential_issue_list+=("$pkg@$ver (impacted: $impacted_clean)")
    fi
  fi
done < /tmp/installed_packages.txt

echo ""
echo "🗒️  SUMMARY"
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

exit 0
