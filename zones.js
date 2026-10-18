// Canonical world-clock picker entries — every zone VERIFIED present in
// /usr/share/zoneinfo on this tzdata build. Plain-var shape (no `export`)
// because the Quickshell V4 engine parses this as a script, not a module
// — same convention as Model.js. Format: region -> tz database city names.
var TZ_REGIONS = {
  "UTC": [
    "UTC"
  ],
  "America": [
    "New_York",
    "Chicago",
    "Denver",
    "Los_Angeles",
    "Anchorage",
    "Phoenix",
    "Mexico_City",
    "Toronto",
    "Vancouver",
    "Sao_Paulo",
    "Buenos_Aires",
    "Lima",
    "Bogota"
  ],
  "Europe": [
    "London",
    "Paris",
    "Berlin",
    "Madrid",
    "Rome",
    "Amsterdam",
    "Zurich",
    "Stockholm",
    "Dublin",
    "Lisbon",
    "Warsaw",
    "Athens",
    "Istanbul",
    "Moscow"
  ],
  "Asia": [
    "Tokyo",
    "Seoul",
    "Shanghai",
    "Hong_Kong",
    "Singapore",
    "Kolkata",
    "Dubai",
    "Bangkok",
    "Jakarta",
    "Tel_Aviv",
    "Karachi"
  ],
  "Africa": [
    "Cairo",
    "Lagos",
    "Nairobi",
    "Johannesburg",
    "Casablanca",
    "Accra"
  ],
  "Australia": [
    "Sydney",
    "Melbourne",
    "Brisbane",
    "Perth",
    "Adelaide"
  ],
  "Pacific": [
    "Auckland",
    "Honolulu",
    "Fiji"
  ]
}

if (typeof module !== "undefined") {
  module.exports = { TZ_REGIONS: TZ_REGIONS }
}
