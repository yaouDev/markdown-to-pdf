#!/bin/bash

set -euo pipefail

echo "Starting Markdown to PDF conversion..."

DOCUMENTS_DIR=${INPUT_DOCUMENTS_DIR:-documents}
IMAGES_DIR=${INPUT_IMAGES_DIR:-images}
ARTIFACTS_DIR=${INPUT_ARTIFACTS_DIR:-artifacts}
PUSH_TO_REPOSITORY=${INPUT_PUSH_TO_REPOSITORY:-false}
UNIFIED_PDF=${INPUT_UNIFIED_PDF:-true}
INCLUDE_DATE=${INPUT_INCLUDE_DATE:-true}
SAVE_VERSION=${INPUT_SAVE_VERSION:-true}
BASE_FILE_NAME=${INPUT_BASE_FILE_NAME:-$(basename "${GITHUB_REPOSITORY}")}
TEMPLATE_TEX=${INPUT_TEMPLATE_TEX:-default_template}

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
    TEMP_MD_FILE=$(mktemp -t combined_docs_XXXX.md)
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
    git config --global user.name "github-actions[bot]"
    git config --global user.email "github-actions[bot]@users.noreply.github.com"

    git add "${ARTIFACTS_DIR}"

    if ! git diff --staged --quiet; then
        git commit -m "chore(action): Generate PDF artifact(s) for ${BASE_FILE_NAME} on ${CURRENT_DATE}"
        git push
        echo "Artifacts pushed to repository."
    else
        echo "No changes to commit in artifacts directory."
    fi
else
    echo "Skipping push to repository as 'push-to-repository' is false."
fi

echo "pdf-path=${GENERATED_PDF_PATHS}" >> "$GITHUB_OUTPUT"
echo "Action completed successfully."