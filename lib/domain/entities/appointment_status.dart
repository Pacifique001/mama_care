// lib/domain/entities/appointment_status.dart (NEW FILE or existing enum location)

import 'package:logger/logger.dart';
import 'package:mama_care/injection.dart'; // For locator

enum AppointmentStatus {
  pending, // Patient requested, Doctor hasn't responded
  confirmed, // Doctor confirmed the time/date
  completed, // The appointment occurred
  cancelled, // Patient cancelled before confirmation/occurrence
  declined, // Doctor declined the request
  scheduled, // Could be used if an admin/system schedules it initially
}

/// Converts an AppointmentStatus enum to its string representation for Firestore.
String appointmentStatusToString(AppointmentStatus status) {
  return status.name; // Uses the enum value name (e.g., 'pending', 'confirmed')
}

/// Converts a string status (from Firestore or filter) to an AppointmentStatus enum.
/// Returns a default (e.g., pending) if the string doesn't match any enum value.
AppointmentStatus appointmentStatusFromString(String? statusString) {
  if (statusString == null) return AppointmentStatus.pending; // Default
  try {
    // Find the enum value matching the string name (case-insensitive safety optional)
    return AppointmentStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == statusString.toLowerCase(),
    );
  } catch (e) {
    // Log the error if an unexpected status string is encountered
    locator<Logger>().w(
      "Could not parse appointment status string: '$statusString'. Defaulting to pending.",
    );
    return AppointmentStatus.pending; // Default on error
  }
}
