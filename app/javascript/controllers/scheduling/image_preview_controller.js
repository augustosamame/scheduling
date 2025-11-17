import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "preview", "previewContainer", "filename"]

  preview() {
    const file = this.inputTarget.files[0]

    if (file && file.type.startsWith('image/')) {
      const reader = new FileReader()

      reader.onload = (e) => {
        this.previewTarget.src = e.target.result
        this.previewContainerTarget.classList.remove('hidden')
        if (this.hasFilenameTarget) {
          this.filenameTarget.textContent = file.name
        }
      }

      reader.readAsDataURL(file)
    } else {
      this.clearPreview()
    }
  }

  clearPreview() {
    // Reset file input
    if (this.hasInputTarget) {
      this.inputTarget.value = ''
    }

    // Hide preview
    if (this.hasPreviewContainerTarget) {
      this.previewContainerTarget.classList.add('hidden')
    }

    // Clear image
    if (this.hasPreviewTarget) {
      this.previewTarget.src = ''
    }

    // Clear filename
    if (this.hasFilenameTarget) {
      this.filenameTarget.textContent = ''
    }
  }
}
