import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["payButton", "message", "form"]
  static values = {
    amount: Number,
    currency: String,
    description: String,
    publicKey: String,
    bookingUid: String
  }

  connect() {
    console.log("Scheduling Culqi payment controller connected")

    // Find the parent form
    this.formElement = this.element.closest('form')

    this.updatePayButtonState()
  }

  // Enable/disable pay button
  updatePayButtonState() {
    if (this.hasPayButtonTarget) {
      this.payButtonTarget.disabled = false
    }
  }

  // Main entry point for Culqi payment
  pay(event) {
    event.preventDefault()

    // Validate form first
    if (!this.validateForm()) {
      this.showError('Por favor completa todos los campos requeridos')
      return
    }

    console.log('Paying with Culqi:', {
      amount: this.amountValue,
      currency: this.currencyValue,
      description: this.descriptionValue
    })

    // Store the button element for later reset
    this.buttonElement = event.currentTarget

    // Store original content before modifying
    const originalContent = this.buttonElement.innerHTML
    this.buttonElement.dataset.originalContent = originalContent

    // Disable the button to prevent multiple clicks and show loading
    this.buttonElement.disabled = true
    this.buttonElement.classList.add('opacity-75')
    this.buttonElement.innerHTML = '<svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-white inline" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path></svg>Procesando...'

    try {
      // Initialize Culqi
      Culqi.publicKey = this.publicKeyValue

      // Setup Culqi configuration
      Culqi.settings({
        title: 'Pago de Cita',
        currency: this.currencyValue,
        description: this.descriptionValue,
        amount: this.amountValue
      })

      // Define Culqi options
      Culqi.options({
        style: {
          maincolor: '#0ea5e9', // Sky blue
          auxcolor: '#475569', // Slate gray
          maintext: '#1e293b', // Dark slate
          auxtext: '#64748b'   // Gray
        },
        modal: true,
        installments: false,
        paymentMethods: {
          tarjeta: true,
          yape: false,
          billetera: false,
          bancaMovil: false,
          agente: false,
          cuotealo: false
        }
      })

      // Open Culqi checkout
      Culqi.open()

    } catch (error) {
      console.error('Error initializing Culqi:', error)
      this.showError('Error al inicializar el sistema de pagos')
      this.resetButton()
    }

    // Set up global Culqi handlers
    this.setupCulqiHandlers()
  }

  setupCulqiHandlers() {
    // Success handler - called when user completes form successfully
    window.culqi = () => {
      if (Culqi.token) {
        console.log('Culqi token received:', Culqi.token)
        this.processCulqiPayment(Culqi.token.id)
      } else {
        console.error('No token received from Culqi')
        this.showError('No se recibió el token de pago')
        this.resetButton()
      }
    }

    // Close handler - called when user closes the modal
    window.culqi_close = () => {
      console.log('Culqi modal closed by user')
      this.resetButton()
    }

    // Error handler - called when there's an error
    window.culqi_error = (error) => {
      console.error('Culqi error:', error)
      this.showError(error.user_message || 'Error en el procesamiento del pago')
      this.resetButton()
    }
  }

  processCulqiPayment(token) {
    console.log('Processing Culqi payment with token:', token)

    // Add token to form as hidden field
    const tokenInput = document.createElement('input')
    tokenInput.type = 'hidden'
    tokenInput.name = 'token_id'
    tokenInput.value = token
    this.formElement.appendChild(tokenInput)

    // Add payment provider to form
    const providerInput = document.createElement('input')
    providerInput.type = 'hidden'
    providerInput.name = 'payment_provider'
    providerInput.value = 'culqi'
    this.formElement.appendChild(providerInput)

    // Submit the form
    this.showSuccess('Token recibido. Procesando pago...')
    this.formElement.submit()
  }

  validateForm() {
    // Check required fields
    const requiredFields = this.formElement.querySelectorAll('[required]')
    for (const field of requiredFields) {
      if (!field.value || field.value.trim() === '') {
        field.focus()
        return false
      }
    }
    return true
  }

  handle3DSAuthentication(data) {
    console.log('3DS authentication required:', data.three_d_secure_url)

    // Create a modal for 3DS authentication
    const modal = this.create3DSModal(data.three_d_secure_url, data.charge_id)
    document.body.appendChild(modal)

    this.showError('Verificación 3D Secure requerida. Complete la verificación en la nueva ventana.')
    this.resetButton()
  }

  create3DSModal(threeDSUrl, chargeId) {
    const modal = document.createElement('div')
    modal.className = 'fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50'
    modal.innerHTML = `
      <div class="bg-white rounded-lg p-6 max-w-md w-full mx-4">
        <h3 class="text-lg font-semibold mb-4">Verificación de Seguridad</h3>
        <p class="text-gray-600 mb-4">Tu banco requiere verificación adicional para completar el pago.</p>
        <div class="flex space-x-3">
          <button class="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 flex-1" onclick="window.open('${threeDSUrl}', '_blank'); this.closest('.fixed').remove();">
            Verificar Ahora
          </button>
          <button class="px-4 py-2 bg-gray-300 text-gray-700 rounded hover:bg-gray-400" onclick="this.closest('.fixed').remove();">
            Cancelar
          </button>
        </div>
        <p class="text-sm text-gray-500 mt-4">
          Después de completar la verificación, recargue esta página para confirmar el pago.
        </p>
      </div>
    `

    return modal
  }

  resetButton() {
    console.log('Resetting Culqi button...')
    if (this.buttonElement) {
      this.buttonElement.disabled = false
      this.buttonElement.classList.remove('opacity-50', 'opacity-75', 'cursor-not-allowed')

      const originalContent = this.buttonElement.dataset.originalContent
      if (originalContent) {
        this.buttonElement.innerHTML = originalContent
      } else {
        // Fallback to default content
        const amount = this.amountValue / 100
        const currency = this.currencyValue === 'PEN' ? 'S/' : '$'
        this.buttonElement.innerHTML = `
          <svg class="w-5 h-5 mr-2 inline" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 10h18M7 15h1m4 0h1m-7 4h12a3 3 0 003-3V8a3 3 0 00-3-3H6a3 3 0 00-3 3v8a3 3 0 003 3z"></path>
          </svg>
          Pagar ${currency} ${amount.toFixed(2)}
        `
      }

      // Clear the stored original content
      delete this.buttonElement.dataset.originalContent
    }

    // Re-enable button
    this.updatePayButtonState()
  }

  showSuccess(message) {
    this.showNotification(message, 'success')
  }

  showError(message) {
    this.showNotification(message, 'error')
  }

  showNotification(message, type) {
    // Use message target if available
    if (this.hasMessageTarget) {
      const bgColor = type === 'success' ? 'bg-green-50 border-green-200 text-green-800' : 'bg-red-50 border-red-200 text-red-800'
      const icon = type === 'success' ?
        '<svg class="w-5 h-5 mr-3" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"></path></svg>' :
        '<svg class="w-5 h-5 mr-3" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"></path></svg>'

      this.messageTarget.className = `mt-4 p-4 border rounded-lg ${bgColor}`
      this.messageTarget.innerHTML = `
        <div class="flex items-center">
          ${icon}
          <span>${message}</span>
        </div>
      `
      this.messageTarget.classList.remove('hidden')
    } else {
      // Fallback to floating notification
      const notification = document.createElement('div')
      const bgColor = type === 'success' ? 'bg-green-100 border-green-500 text-green-700' : 'bg-red-100 border-red-500 text-red-700'
      const icon = type === 'success' ?
        '<svg class="w-5 h-5 mr-3" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"></path></svg>' :
        '<svg class="w-5 h-5 mr-3" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"></path></svg>'

      notification.className = `fixed top-4 right-4 z-50 p-4 border-l-4 ${bgColor} rounded shadow-lg max-w-md`
      notification.innerHTML = `
        <div class="flex items-center">
          ${icon}
          <span>${message}</span>
          <button class="ml-4 text-xl leading-none" onclick="this.parentElement.parentElement.remove()">×</button>
        </div>
      `

      document.body.appendChild(notification)

      // Auto-remove after 5 seconds
      setTimeout(() => {
        if (notification.parentElement) {
          notification.remove()
        }
      }, 5000)
    }
  }

  // Payment for existing bookings (optional payment on confirmation page)
  payExisting(event) {
    event.preventDefault()

    console.log('Paying for existing booking:', {
      bookingUid: this.bookingUidValue,
      amount: this.amountValue
    })

    // Store the button element
    this.buttonElement = event.currentTarget
    const originalContent = this.buttonElement.innerHTML
    this.buttonElement.dataset.originalContent = originalContent

    // Show loading state
    this.buttonElement.disabled = true
    this.buttonElement.classList.add('opacity-75')
    this.buttonElement.innerHTML = '<svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-white inline" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path></svg>Procesando...'

    try {
      // Initialize Culqi
      Culqi.publicKey = this.publicKeyValue

      // Setup Culqi configuration
      Culqi.settings({
        title: 'Pago de Cita',
        currency: this.currencyValue,
        description: this.descriptionValue,
        amount: this.amountValue
      })

      // Define Culqi options
      Culqi.options({
        style: {
          maincolor: '#0ea5e9',
          auxcolor: '#475569',
          maintext: '#1e293b',
          auxtext: '#64748b'
        },
        modal: true,
        installments: false,
        paymentMethods: {
          tarjeta: true,
          yape: false,
          billetera: false,
          bancaMovil: false,
          agente: false,
          cuotealo: false
        }
      })

      // Open Culqi checkout
      Culqi.open()
    } catch (error) {
      console.error('Error initializing Culqi:', error)
      this.showError('Error al inicializar el sistema de pagos')
      this.resetButton()
    }

    // Set up global Culqi handlers for existing booking
    this.setupCulqiHandlersForExisting()
  }

  setupCulqiHandlersForExisting() {
    // Success handler
    window.culqi = () => {
      if (Culqi.token) {
        console.log('Culqi token received for existing booking:', Culqi.token)
        this.processExistingBookingPayment(Culqi.token.id)
      } else {
        console.error('No token received from Culqi')
        this.showError('No se recibió el token de pago')
        this.resetButton()
      }
    }

    // Close handler
    window.culqi_close = () => {
      console.log('Culqi modal closed by user')
      this.resetButton()
    }

    // Error handler
    window.culqi_error = (error) => {
      console.error('Culqi error:', error)
      this.showError(error.user_message || 'Error en el procesamiento del pago')
      this.resetButton()
    }
  }

  async processExistingBookingPayment(token) {
    try {
      const bookingUid = this.bookingUidValue || this.extractBookingUidFromUrl()

      const response = await fetch(`/book/bookings/${bookingUid}/process_payment`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
          'Accept': 'application/json'
        },
        body: JSON.stringify({
          payment_provider: 'culqi',
          token_id: token
        })
      })

      const data = await response.json()

      if (data.success) {
        this.showSuccess(data.message || 'Pago procesado exitosamente')
        // Reload page after 2 seconds to show updated payment status
        setTimeout(() => {
          window.location.reload()
        }, 2000)
      } else if (data.requires_3ds) {
        this.handle3DSAuthentication(data)
      } else {
        this.showError(data.error || 'Error procesando el pago')
        this.resetButton()
      }
    } catch (error) {
      console.error('Network error:', error)
      this.showError('Error de conexión. Intente nuevamente.')
      this.resetButton()
    }
  }

  extractBookingUidFromUrl() {
    const match = window.location.pathname.match(/bookings\/([^\/]+)/)
    return match ? match[1] : null
  }
}
