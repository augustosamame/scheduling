import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dateStep", "detailsStep", "selectedDate", "timeSlots", "nextButton", "selectedTime"]
  static values = {
    organizationSlug: String,
    memberSlug: String,
    eventSlug: String,
    availabilityUrl: String
  }

  connect() {
    this.selectedDateTime = null
    this.selectedSlot = null
  }

  async selectDate(event) {
    const dateButton = event.currentTarget
    const date = dateButton.dataset.date

    // Update UI - mark selected date
    this.element.querySelectorAll('[data-date]').forEach(btn => {
      btn.classList.remove('bg-blue-600', 'text-white')
      btn.classList.add('hover:bg-gray-100')
    })
    dateButton.classList.add('bg-blue-600', 'text-white')
    dateButton.classList.remove('hover:bg-gray-100')

    // Update selected date display
    if (this.hasSelectedDateTarget) {
      this.selectedDateTarget.textContent = this.formatDate(date)
    }

    // Fetch available time slots
    await this.fetchTimeSlots(date)
  }

  async fetchTimeSlots(date) {
    try {
      const url = this.availabilityUrlValue +
        `?date=${date}&event_type_id=${this.eventSlugValue}`

      const response = await fetch(url, {
        headers: {
          'Accept': 'application/json'
        }
      })

      if (!response.ok) throw new Error('Failed to fetch time slots')

      const slots = await response.json()
      this.renderTimeSlots(slots, date)
    } catch (error) {
      console.error('Error fetching time slots:', error)
      this.timeSlotsTarget.innerHTML = `
        <div class="text-red-600 text-sm p-4">
          Error loading available times. Please try again.
        </div>
      `
    }
  }

  renderTimeSlots(slots, date) {
    if (!this.hasTimeSlotsTarget) return

    if (slots.length === 0) {
      this.timeSlotsTarget.innerHTML = `
        <div class="text-gray-500 text-sm p-4 text-center">
          No available times for this date.
        </div>
      `
      return
    }

    const timeSlotsHtml = slots.map(slot => {
      const time = new Date(slot.start_time).toLocaleTimeString('es-PE', {
        hour: '2-digit',
        minute: '2-digit',
        hour12: false
      })

      return `
        <button
          type="button"
          data-action="click->booking#selectTime"
          data-time="${slot.start_time}"
          class="w-full px-4 py-3 text-center border border-gray-300 rounded-md hover:border-blue-500 hover:bg-blue-50 transition-colors text-blue-600 font-medium"
        >
          ${time}
        </button>
      `
    }).join('')

    this.timeSlotsTarget.innerHTML = timeSlotsHtml
    this.timeSlotsTarget.classList.remove('hidden')
  }

  selectTime(event) {
    const timeButton = event.currentTarget
    const time = timeButton.dataset.time

    // Update UI - mark selected time
    this.element.querySelectorAll('[data-time]').forEach(btn => {
      btn.classList.remove('bg-gray-700', 'text-white', 'border-gray-700')
      btn.classList.add('border-gray-300', 'hover:border-blue-500')
    })

    timeButton.classList.add('bg-gray-700', 'text-white', 'border-gray-700')
    timeButton.classList.remove('border-gray-300', 'hover:border-blue-500')

    // Store selected time
    this.selectedDateTime = time

    // Update hidden field if it exists
    if (this.hasSelectedTimeTarget) {
      this.selectedTimeTarget.value = time
    }

    // Show next button
    if (this.hasNextButtonTarget) {
      this.nextButtonTarget.classList.remove('hidden')
    }
  }

  showDetails(event) {
    event.preventDefault()

    if (!this.selectedDateTime) {
      alert('Por favor selecciona una fecha y hora')
      return
    }

    // Hide date selection step
    if (this.hasDateStepTarget) {
      this.dateStepTarget.classList.add('hidden')
    }

    // Show details form step
    if (this.hasDetailsStepTarget) {
      this.detailsStepTarget.classList.remove('hidden')
    }

    // Scroll to top
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }

  goBack(event) {
    event.preventDefault()

    // Show date selection step
    if (this.hasDateStepTarget) {
      this.dateStepTarget.classList.remove('hidden')
    }

    // Hide details form step
    if (this.hasDetailsStepTarget) {
      this.detailsStepTarget.classList.add('hidden')
    }

    // Scroll to top
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }

  formatDate(dateString) {
    const date = new Date(dateString)
    const days = ['domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado']
    const months = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre']

    return `${days[date.getDay()]}, ${date.getDate()} de ${months[date.getMonth()]}`
  }
}
