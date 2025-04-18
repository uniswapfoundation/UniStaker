#!/usr/bin/env bash
#
# Run `forge flatten` on all .sol files recursively in the contracts/ directory and deps
# and store the output in the flattened/ directory. Also create all parent directories
# before writing the output if they don't exist.

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
usage="Usage: $0"

set -o errexit

# Ensure the contracts/ directory exists.
outputs_dir="${script_dir}/out"
if [ ! -d "${outputs_dir}" ]; then
  echo "The out/ directory does not exist. ${usage}"
  exit 1
fi

# Ensure the flattened/ directory exists.
flattened_dir="${script_dir}/flattened"
mkdir -p "${flattened_dir}"

# Flatten all .sol files in the contracts/ directory.
find "${outputs_dir}" -type f -path "*.sol/*.json" -print0 | while IFS= read -r -d $'\0' file; do
  # Read the compilation target from the json file
  compilation_target=$(jq -r '.metadata.settings.compilationTarget | keys | .[0]' "${file}")
  # Get the filename component of the compilation target path
  output_name=$(basename "${compilation_target}")
  # Generate sources for the compilation target using forge flatten
  forge flatten "${script_dir}/${compilation_target}" > "${flattened_dir}/${output_name}"
done
