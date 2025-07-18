# Markdown to PDF GitHub Action

[![Workflow Status](https://github.com/yaouDev/markdown-to-pdf/actions/workflows/test.yml/badge.svg)](https://github.com/yaouDev/markdown-to-pdf/actions/workflows/test.yml)

This GitHub Action converts Markdown documents into professional-looking PDFs using Pandoc and a LaTeX engine. It's designed to be flexible, allowing you to generate a single unified PDF from multiple Markdown files or individual PDFs for each file.

## Contribute

## ✨ Features

* **Unified PDF Generation:** Combine multiple Markdown files into a single PDF document.

* **Separate PDF Generation:** Create a distinct PDF for each Markdown file.

* **Image Inclusion:** Supports images referenced in your Markdown files.

* **Date Inclusion:** Optionally includes the current date in the generated PDF filename.

* **Version Saving:** Can save dated versions of your PDFs for historical tracking.

* **Custom LaTeX Templates:** Use the default built-in LaTeX template or provide your own for full customization.

* **GitHub Artifact Upload:** Designed to work seamlessly with `actions/upload-artifact` to make your generated PDFs easily accessible from your workflow runs.

## 🚀 How to Use

To use this action, create a `.yml` file (e.g., `generate-docs.yml`) in your repository's `.github/workflows/` directory.

### Example Workflow (`.github/workflows/generate-docs.yml`)

This example demonstrates how to use the action to generate a unified PDF and then upload it as a workflow artifact.

```yaml
# .github/workflows/generate-docs.yml
name: Generate Documentation PDF

on:
  push:
    branches:
      - main
    paths:
      - 'documents/**' # Trigger when markdown documents change
      - 'images/**'    # Trigger when images change
  workflow_dispatch: # Allows manual triggering

jobs:
  build_pdf:
    runs-on: ubuntu-latest
    permissions:
      contents: write # IMPORTANT: Required for actions/upload-artifact

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 0 # Good practice

      - name: Generate PDF from Markdown
        # Replace '@latest' with the version you want to use (e.g, v1.0.0, main, etc.)
        uses: yaouDev/markdown-to-pdf@latest
        id: pdf_generation # Give it an ID to access outputs
        with:
          documents-dir: documents  # Path to your markdown files (e.g., 'documents/')
          images-dir: images        # Path to your images (e.g., 'images/')
          unified-pdf: true         # Set to 'true' for one PDF, 'false' for one PDF per markdown file
          include-date: true        # Set to 'true' to include date in filename (e.g., 'MyDocument-2025-07-18.pdf')
          base-file-name: ProjectDocumentation # Custom base name for the PDF (e.g., 'ProjectDocumentation.pdf')
          template-tex: default_template # Use 'default_template' or a path to your custom .tex file

      - name: Upload Generated PDF as Workflow Artifact
        # This step uploads the PDF as a GitHub Action artifact, making it downloadable from the workflow run summary
        uses: actions/upload-artifact@v4
        with:
          name: generated-documentation-pdf # Name of the artifact
          path: ${{ steps.pdf_generation.outputs.pdf-path }} # Use the output from your action
          retention-days: 7 # How many days to keep the artifact

```

## ⚙️ Inputs

| Input Name | Description | Required | Default Value |
| :----------------- | :------------------------------------------------------------------------------------------------------- | :------- | :----------------------------------------------- |
| `documents-dir` | Directory containing the Markdown files to convert. | `false` | `documents` |
| `images-dir` | Directory containing images referenced in Markdown files. | `false` | `images` |
| `unified-pdf` | If `true`, compiles all documents into a single PDF; otherwise, generates one PDF per Markdown file. | `false` | `true` |
| `include-date` | If `true`, includes the current date (YYYY-MM-DD) in the PDF document name. | `false` | `true` |
| `base-file-name` | The base name for the generated PDF (e.g., "MyDocument"). Defaults to the repository name. | `false` | `github.event.repository.name` |
| `template-tex` | File path to a custom LaTeX template (`.tex`) file. Use `"default_template"` to use the action's built-in template. | `false` | `default_template` |

## 📦 Outputs

| Output Name | Description |
| :---------- | :----------------------------------------- |
| `pdf-path` | The path to the generated PDF file(s) within the workspace. If `unified-pdf` is `false`, this will be a space-separated list of paths. |

## 💡 Best Practices

* **Permissions:** Ensure your workflow has `permissions: contents: write` if you are using `actions/upload-artifact`.

* **Action Reference:** Use `uses: yaouDev/markdown-to-pdf@latest`. 

* **`artifacts`:** The `artifacts` folder is where you actual file ends up and what the output will point to. The action will create this directory on the runner if it doesn't exist and place the generated PDF in it.

* **Custom Templates:** If providing a custom `template-tex`, ensure its path is correct relative to your repository's root.

* **Markdown Structure:** For unified PDFs, ensure your Markdown files are ordered correctly (e.g., `01-intro.md`, `02-chapter.md`) as the action sorts them alphabetically by filename.

* **Debugging:** If you encounter issues, temporarily uncomment `set -x` at the top of `entrypoint.sh` in your action's repository to get very verbose debug output in the workflow logs. Remember to remove it after debugging!

## 🤝 Compatible Workflows

This action is compatible with any GitHub Actions workflow running on `ubuntu-latest`. It integrates seamlessly with other standard actions, particularly `actions/checkout` and `actions/upload-artifact`. You are also able to configure the GitHub bot to push the artifact/PDF to your repository.

## 🤝 Contributing

We welcome and encourage contributions to improve this GitHub Action! Whether it's bug fixes, new features, or documentation improvements, your help is greatly appreciated.

To contribute:

1.  **Fork** this repository.
2.  **Create a new branch** for your feature or bug fix (e.g., `feature/new-template` or `fix/image-paths`).
3.  **Make your changes** and test them thoroughly.
4.  **Commit your changes** with clear and descriptive commit messages.
5.  **Push your branch** to your forked repository.
6.  **Open a Pull Request** to the `main` branch of this repository, describing your changes and why they are beneficial.

Thank you for helping make this action better!

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](https://www.google.com/search?q=LICENSE) file for details.
