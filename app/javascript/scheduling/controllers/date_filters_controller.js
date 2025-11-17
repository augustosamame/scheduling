import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["fromDate", "toDate", "form"]

  setToday(event) {
    event.preventDefault()
    const today = new Date()
    const todayStr = today.toISOString().split('T')[0]

    this.fromDateTarget.value = todayStr
    this.toDateTarget.value = todayStr
    this.submitForm()
  }

  setTomorrow(event) {
    event.preventDefault()
    const today = new Date()
    const tomorrow = new Date(today)
    tomorrow.setDate(today.getDate() + 1)
    const tomorrowStr = tomorrow.toISOString().split('T')[0]

    this.fromDateTarget.value = tomorrowStr
    this.toDateTarget.value = tomorrowStr
    this.submitForm()
  }

  setThisWeek(event) {
    event.preventDefault()
    const today = new Date()
    const monday = new Date(today)
    monday.setDate(today.getDate() - today.getDay() + 1)
    const sunday = new Date(monday)
    sunday.setDate(monday.getDate() + 6)

    this.fromDateTarget.value = monday.toISOString().split('T')[0]
    this.toDateTarget.value = sunday.toISOString().split('T')[0]
    this.submitForm()
  }

  setNextWeek(event) {
    event.preventDefault()
    const today = new Date()
    const nextMonday = new Date(today)
    nextMonday.setDate(today.getDate() - today.getDay() + 8)
    const nextSunday = new Date(nextMonday)
    nextSunday.setDate(nextMonday.getDate() + 6)

    this.fromDateTarget.value = nextMonday.toISOString().split('T')[0]
    this.toDateTarget.value = nextSunday.toISOString().split('T')[0]
    this.submitForm()
  }

  submitForm() {
    if (this.hasFormTarget) {
      this.formTarget.submit()
    }
  }
}
