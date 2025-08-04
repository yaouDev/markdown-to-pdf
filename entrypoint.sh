#!/bin/bash

set -euo pipefail
# debug
# set -x

echo "Starting Markdown to PDF conversion..."

# variable default fallbaks
DOCUMENTS_DIR="${DOCUMENTS_DIR:-documents}"
IMAGES_DIR="${IMAGES_DIR:-images}"
UNIFIED_PDF="${UNIFIED_PDF:-true}"
INCLUDE_DATE="${INCLUDE_DATE:-true}"
BASE_FILE_NAME="${BASE_FILE_NAME:-$(basename "${GITHUB_REPOSITORY}")}"
TEMPLATE_TEX="${TEMPLATE_TEX:-default_template}"

mkdir -p "artifacts"
echo "Created artifacts folder"

TEMPLATE_PATH=""
if [[ "${TEMPLATE_TEX}" == "default_template" ]]; then
    echo "Using default LaTeX template."
    # make sure the template is copied in the dockerfile
    TEMPLATE_PATH="/app/template/default.tex"
    if [[ ! -f "${TEMPLATE_PATH}" ]]; then
        echo "Error: Default template not found at ${TEMPLATE_PATH}. Please ensure it's copied into the Docker image."
        exit 1
    fi
else
    echo "Using custom LaTeX template: ${TEMPLATE_TEX}"
    if [[ ! -f "${TEMPLATE_TEX}" ]]; then
        echo "Error: Custom template not found at "${TEMPLATE_TEX}". Please check the path."
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
    # mktemp is fighting back, use unique temp folder
    TEMP_MD_FILE="/tmp/combined_docs_$(date +%s%N)-$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 8).md"
    touch "${TEMP_MD_FILE}"

    for file in "${MD_FILES[@]}"; do
        cat "${file}" >> "${TEMP_MD_FILE}"
        echo -e "\n\n" >> "${TEMP_MD_FILE}" # air
    done

    FINAL_PDF_NAME="${BASE_FILE_NAME}${OUTPUT_FILE_SUFFIX}.pdf"
    OUTPUT_PDF_PATH="artifacts/${FINAL_PDF_NAME}"

    echo "Running Pandoc for unified PDF: ${OUTPUT_PDF_PATH}"
    pandoc \
        -s \
        --from gfm \
        --to pdf \
        --template "${TEMPLATE_PATH}" \
        --resource-path="${DOCUMENTS_DIR}:${IMAGES_DIR}" \
        --pdf-engine-opt=-shell-escape \
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
        OUTPUT_PDF_PATH="artifacts/${FINAL_PDF_NAME}"

        echo "Running Pandoc for ${file} -> ${OUTPUT_PDF_PATH}"
        pandoc \
            -s \
            --from gfm \
            --to pdf \
            --pdf-engine=xelatex \
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


if [ -z "${GITHUB_OUTPUT}" ]; then
    echo "Error: GITHUB_OUTPUT environment variable is not set."
    exit 1
fi
if [ ! -f "${GITHUB_OUTPUT}" ]; then
    echo "Warning: GITHUB_OUTPUT file does not exist. Attempting to create."
    touch "${GITHUB_OUTPUT}" || { echo "Error: Could not create GITHUB_OUTPUT file."; exit 1; }
fi
if [ ! -w "${GITHUB_OUTPUT}" ]; then
    echo "Error: GITHUB_OUTPUT file is not writable. Permissions: $(ls -l "${GITHUB_OUTPUT}")"
    exit 1
fi

echo "pdf-path=${GENERATED_PDF_PATHS}" >> "${GITHUB_OUTPUT}"
echo "Successfully set pdf-path output: ${GENERATED_PDF_PATHS}"

echo "Action completed successfully."
