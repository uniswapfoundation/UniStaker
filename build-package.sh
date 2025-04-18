#!/usr/bin/env bash
#
# Builds a package containing both artifacts and source code.
#
# Example package structure:
#
#   my-package/
#     artifacts/
#       ... (output from yarn hardhat compile)
#     sources/
#       contracts/
#         ... (source code)
#       ... (other dependencies)
#     build-info/
#
# Usage:
#
#   ./build-package.sh <output-dir>

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
usage="Usage: $0 <output-dir>"

set -o errexit
set -o nounset
set -o pipefail

# Ensure the output directory is provided using parameter expansion.
output_dir="${1:?Please provide an output directory. ${usage}}"
mkdir -p "${output_dir}/artifacts"

# Copy the ${script_dir}/artifacts/ directory into the output directory.
cp -r "${script_dir}/out" "${output_dir}/artifacts/contracts"

# Move the build-info directory up a level.
mv "${output_dir}/artifacts/contracts/build-info" "${output_dir}/artifacts/build-info"

# Flatten all .sol files in the contracts/ directory.
"${script_dir}/flatten-all.sh"

# Copy the ${script_dir}/flattened/ directory into the sources directory.
sources_dir="${output_dir}/sources"
mkdir -p "${sources_dir}"
cp -r "${script_dir}/flattened" "${sources_dir}"
