import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["fromDate", "toDate", "form"]

  connect() {
    console.log("🎯 DateFilters controller connected!")
    console.log("Form target:", this.formTarget)
    console.log("FromDate target:", this.fromDateTarget)
    console.log("ToDate target:", this.toDateTarget)
  }

  setToday(event) {
    console.log("📅 setToday clicked!")
    event.preventDefault()
    const today = new Date()
    const todayStr = today.toISOString().split('T')[0]
    console.log("Setting dates to:", todayStr)

    this.fromDateTarget.value = todayStr
    this.toDateTarget.value = todayStr
    this.submitForm()
  }

  setTomorrow(event) {
    console.log("📅 setTomorrow clicked!")
    event.preventDefault()
    const today = new Date()
    const tomorrow = new Date(today)
    tomorrow.setDate(today.getDate() + 1)
    const tomorrowStr = tomorrow.toISOString().split('T')[0]
    console.log("Setting dates to:", tomorrowStr)

    this.fromDateTarget.value = tomorrowStr
    this.toDateTarget.value = tomorrowStr
    this.submitForm()
  }

  setThisWeek(event) {
    console.log("📅 setThisWeek clicked!")
    event.preventDefault()
    const today = new Date()
    const monday = new Date(today)
    monday.setDate(today.getDate() - today.getDay() + 1)
    const sunday = new Date(monday)
    sunday.setDate(monday.getDate() + 6)
    console.log("Setting dates from:", monday.toISOString().split('T')[0], "to:", sunday.toISOString().split('T')[0])

    this.fromDateTarget.value = monday.toISOString().split('T')[0]
    this.toDateTarget.value = sunday.toISOString().split('T')[0]
    this.submitForm()
  }

  setNextWeek(event) {
    console.log("📅 setNextWeek clicked!")
    event.preventDefault()
    const today = new Date()
    const nextMonday = new Date(today)
    nextMonday.setDate(today.getDate() - today.getDay() + 8)
    const nextSunday = new Date(nextMonday)
    nextSunday.setDate(nextMonday.getDate() + 6)
    console.log("Setting dates from:", nextMonday.toISOString().split('T')[0], "to:", nextSunday.toISOString().split('T')[0])

    this.fromDateTarget.value = nextMonday.toISOString().split('T')[0]
    this.toDateTarget.value = nextSunday.toISOString().split('T')[0]
    this.submitForm()
  }

  submitForm() {
    console.log("📤 Submitting form...")
    if (this.hasFormTarget) {
      console.log("✅ Form target found, submitting...")
      this.formTarget.submit()
    } else {
      console.error("❌ No form target found!")
    }
  }
}
