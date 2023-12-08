#!/bin/bash -e

# Function to print usage instructions
print_usage() {
  echo "Usage: $0 [dry-run|exec]"
  echo "  dry-run: List old kernels and modules without removing them (default)"
  echo "  exec: Remove the listed old kernels and modules (requires root privileges)"
}

# Function to compare kernel version numbers
# Returns 1 if version1 is greater than version2, 0 if equal, and -1 if lesser
compare_versions() {
  local version1=(${1//./ })
  local version2=(${2//./ })

  for i in {0..2}; do
    if [[ ${version1[i]} -gt ${version2[i]} ]]; then
      return 1
    elif [[ ${version1[i]} -lt ${version2[i]} ]]; then
      return -1
    fi
  done

  return 0
}

# Check for valid input arguments
if [[ $# -gt 1 ]] || { [[ $# -eq 1 ]] && [[ "$1" != "dry-run" ]] && [[ "$1" != "exec" ]]; }; then
  print_usage
  exit 1
fi

# Display current running kernel
uname -a
IN_USE=$(uname -a | awk '{ print $3 }')
echo "Your in-use kernel is $IN_USE"

# Find old kernels
OLD_KERNELS=$(
  dpkg --get-selections |
  grep -v "linux-headers-generic" |
  grep -v "linux-image-generic" |
  grep -Ei 'linux-image|linux-headers|linux-modules' |
  awk '{ print $1 }' |
  grep -v "${IN_USE}"
)

# Filter out newer kernels
FILTERED_KERNELS=""
for kernel in $OLD_KERNELS; do
  kernel_version=$(echo "$kernel" | grep -oP '(?<=linux-image-|linux-headers-|linux-modules-)[0-9]+(\.[0-9]+){0,2}' || true)
  if [[ ! -z "$kernel_version" ]]; then
    compare_versions "$kernel_version" "$IN_USE"
    if [[ $? -eq -1 ]]; then
      FILTERED_KERNELS+="$kernel"$'\n'
    fi
  else
    FILTERED_KERNELS+="$kernel"$'\n'
  fi
done
OLD_KERNELS="$FILTERED_KERNELS"

# Find old modules
OLD_MODULES=$(
  ls /lib/modules |
  grep -v "${IN_USE}" |
  while read -r module; do
    module_version=$(echo "$module" | grep -oP '[0-9]+(\.[0-9]+){0,2}' || true)
    if [[ ! -z "$module_version" ]]; then
      compare_versions "$module_version" "$IN_USE"
      if [[ $? -eq -1 ]]; then
        echo "$module"
      fi
    else
      echo "$module"
    fi
  done
)

# Display old kernels and modules
echo "Old Kernels to be removed:"
echo "$OLD_KERNELS"
echo "Old Modules to be removed:"
echo "$OLD_MODULES"

# Remove old kernels and modules if "exec" argument is passed
if [ "$1" == "exec" ]; then
  # Check for root privileges
  if [ "$(id -u)" != "0" ]; then
    echo "Error:This operation requires root privileges. Please run the script as root or use 'sudo'."
    exit 1
  fi
  # Remove Old Kernel
  apt-get purge $OLD_KERNELS
  # Remove Old Modules
  for module in $OLD_MODULES ; do
    rm -rf /lib/modules/$module/
  done
fi
