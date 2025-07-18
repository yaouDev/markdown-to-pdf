#!/bin/bash

set -euo pipefail
set -x # verbose debug

echo "Starting Markdown to PDF conversion..."

# fallback incase action.yml mapping fails
DOCUMENTS_DIR="${DOCUMENTS_DIR:-documents}"
IMAGES_DIR="${IMAGES_DIR:-images}"
ARTIFACTS_DIR="${ARTIFACTS_DIR:-artifacts}"
PUSH_TO_REPOSITORY="${PUSH_TO_REPOSITORY:-false}"
UNIFIED_PDF="${UNIFIED_PDF:-true}"
INCLUDE_DATE="${INCLUDE_DATE:-true}"
SAVE_VERSION="${SAVE_VERSION:-true}"
BASE_FILE_NAME="${BASE_FILE_NAME:-$(basename "${GITHUB_REPOSITORY}")}"
TEMPLATE_TEX="${TEMPLATE_TEX:-default_template}"

echo "Inputs received:"
echo "  DOCUMENTS_DIR: ${DOCUMENTS_DIR}"
echo "  IMAGES_DIR: ${IMAGES_DIR}"
echo "  ARTIFACTS_DIR: ${ARTIFACTS_DIR}"
echo "  PUSH_TO_REPOSITORY: ${PUSH_TO_REPOSITORY}"
echo "  UNIFIED_PDF: ${UNIFIED_PDF}"
echo "  INCLUDE_DATE: ${INCLUDE_DATE}"
echo "  SAVE_VERSION: ${SAVE_VERSION}"
echo "  BASE_FILE_NAME: ${BASE_FILE_NAME}"
echo "  TEMPLATE_TEX: ${TEMPLATE_TEX}"

mkdir -p "${ARTIFACTS_DIR}/versions"
echo "Created artifact directories: ${ARTIFACTS_DIR} and ${ARTIFACTS_DIR}/versions"

TEMPLATE_PATH=""
if [[ "${TEMPLATE_TEX}" == "default_template" ]]; then
    echo "Using default LaTeX template."
    TEMPLATE_PATH="/app/template/default.tex" # make sure it's copied into the Dockerfile
    if [[ ! -f "${TEMPLATE_PATH}" ]]; then
        echo "Error: Default template not found at ${TEMPLATE_PATH}. Please ensure it's copied into the Docker image."
        exit 1
    fi
else
    echo "Using custom LaTeX template: ${TEMPLATE_TEX}"
    if [[ ! -f "${TEMPLATE_TEX}" ]]; then
        echo "Error: Custom template not found at ${TEMPLATE_TEX}. Please check the path."
        exit 1
    fi
    TEMPLATE_PATH="${TEMPLATE_TEX}"
fi
echo "Final template path: ${TEMPLATE_PATH}"

CURRENT_DATE=$(date +%Y-%m-%d)
OUTPUT_FILE_SUFFIX=""
if [[ "${INCLUDE_DATE}" == "true" ]]; then
    OUTPUT_FILE_SUFFIX="-${CURRENT_DATE}"
fi

readarray -t -d '' MD_FILES < <(find "${DOCUMENTS_DIR}" -name "*.md" -print0 | sort -z)

if [ ${#MD_FILES[@]} -eq 0 ]; then
    echo "No markdown files found in ${DOCUMENTS_DIR}. Exiting."
    exit 0
fi

echo "Found markdown files (sorted):"
for file in "${MD_FILES[@]}"; do
    echo "  - ${file}"
done

GENERATED_PDF_PATHS=""

if [[ "${UNIFIED_PDF}" == "true" ]]; then
    echo "Compiling all documents into a unified PDF."
    # mktemp is acting up, so ill just make my own
    TEMP_MD_FILE="/tmp/combined_docs_$(date +%s%N)-$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 8).md"
    for file in "${MD_FILES[@]}"; do
        cat "${file}" >> "${TEMP_MD_FILE}"
        echo -e "\n\n" >> "${TEMP_MD_FILE}" # Add some separation between files - do we want this?
    done

    FINAL_PDF_NAME="${BASE_FILE_NAME}${OUTPUT_FILE_SUFFIX}.pdf"
    OUTPUT_PDF_PATH="${ARTIFACTS_DIR}/${FINAL_PDF_NAME}"

    echo "Running Pandoc for unified PDF: ${OUTPUT_PDF_PATH}"
    pandoc \
        -s \
        --from gfm \
        --to pdf \
        --template "${TEMPLATE_PATH}" \
        --resource-path="${DOCUMENTS_DIR}:${IMAGES_DIR}" \
        -o "${OUTPUT_PDF_PATH}" \
        "${TEMP_MD_FILE}"

    if [ $? -eq 0 ]; then
        echo "Unified PDF generated successfully: ${OUTPUT_PDF_PATH}"
        GENERATED_PDF_PATHS="${OUTPUT_PDF_PATH}"
    else
        echo "Error generating unified PDF."
        exit 1
    fi
    rm "${TEMP_MD_FILE}"

else
    echo "Compiling each document into a separate PDF."
    for file in "${MD_FILES[@]}"; do
        BASENAME=$(basename "${file%.*}")
        FINAL_PDF_NAME="${BASENAME}${OUTPUT_FILE_SUFFIX}.pdf"
        OUTPUT_PDF_PATH="${ARTIFACTS_DIR}/${FINAL_PDF_NAME}"

        echo "Running Pandoc for ${file} -> ${OUTPUT_PDF_PATH}"
        pandoc \
            -s \
            --from gfm \
            --to pdf \
            --template "${TEMPLATE_PATH}" \
            --resource-path="${DOCUMENTS_DIR}:${IMAGES_DIR}" \
            -o "${OUTPUT_PDF_PATH}" \
            "${file}"

        if [ $? -eq 0 ]; then
            echo "PDF generated successfully: ${OUTPUT_PDF_PATH}"
            GENERATED_PDF_PATHS="${GENERATED_PDF_PATHS} ${OUTPUT_PDF_PATH}"
        else
            echo "Error generating PDF for ${file}."
        fi
    done
fi

if [[ "${SAVE_VERSION}" == "true" ]]; then
    echo "Saving versioned PDFs..."
    for pdf_path in ${GENERATED_PDF_PATHS}; do
        BASENAME=$(basename "${pdf_path%.*}")
        VERSIONED_PDF_NAME="${BASENAME}-${CURRENT_DATE}-$(date +%H%M%S).pdf"
        cp "${pdf_path}" "${ARTIFACTS_DIR}/versions/${VERSIONED_PDF_NAME}"
        echo "Saved version: ${ARTIFACTS_DIR}/versions/${VERSIONED_PDF_NAME}"
    done
fi

if [[ "${PUSH_TO_REPOSITORY}" == "true" ]]; then
    echo "Configuring Git and pushing artifacts to repository..."
    git config --global --add safe.directory /github/workspace

    git config --global user.name "github-actions[bot]"
    git config --global user.email "github-actions[bot]@users.noreply.github.com"

    ls -lR "${ARTIFACTS_DIR}" || true # List contents, allow failure if dir not there
    git add "${ARTIFACTS_DIR}"

    if ! git diff --staged --quiet; then
        echo "No changes detected in artifacts directory to commit."
    else
        git commit -m "chore(action): Generate PDF artifact(s) for ${BASE_FILE_NAME} on ${CURRENT_DATE}"
        echo "--- Debugging Git Log after commit ---"
        git log -1
        REMOTE_URL="https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"
        git push "${REMOTE_URL}" HEAD:"${GITHUB_REF}"
        echo "Artifacts pushed to repository."
    fi
else
    echo "Skipping push to repository as 'push-to-repository' is false."
fi

echo "pdf-path=${GENERATED_PDF_PATHS}" >> "$GITHUB_OUTPUT"
echo "Action completed successfully."