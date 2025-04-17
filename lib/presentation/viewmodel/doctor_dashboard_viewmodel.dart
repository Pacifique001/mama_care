// lib/presentation/viewmodels/doctor_dashboard_viewmodel.dart
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:mama_care/domain/entities/appointment.dart';
import 'package:mama_care/data/repositories/appointment_repository.dart';
import 'package:mama_care/domain/entities/nurse_assignment.dart';


@injectable
class DoctorDashboardViewModel extends ChangeNotifier {
  final AppointmentRepository _repository;
  List<Appointment> _appointments = [];
  List<NurseAssignment> _nurseAssignments = [];
  AppointmentStatus _filterStatus = AppointmentStatus.pending;
  AppointmentStatus? get selectedFilterStatus => _filterStatus; // Getter for current filter
  List<Appointment> get appointments => List.unmodifiable(_appointments); // Getter for the full list
  bool get hasAnyAppointments => _appointments.isNotEmpty; // Helper getter
  DoctorDashboardViewModel(this._repository);

  List<Appointment> get filteredAppointments => _appointments
      .where((a) => a.status == _filterStatus)
      .toList();

  List<NurseAssignment> get nurseAssignments => _nurseAssignments;

  void loadData(String doctorId) {
    _repository.getDoctorAppointments(doctorId).listen((appointments) {
      _appointments = appointments;
      notifyListeners();
    });
    
    _repository.getNurseAssignments(doctorId).listen((assignments) {
      _nurseAssignments = assignments;
      notifyListeners();
    });
  }

  Future<void> updateAppointmentStatus(String appointmentId, AppointmentStatus status) async {
    await _repository.updateAppointmentStatus(appointmentId, status);
  }

  Future<void> rescheduleAppointment(String appointmentId, DateTime newTime) async {
    await _repository.rescheduleAppointment(appointmentId, newTime);
  }

  Future<void> assignNurse(String appointmentId, String nurseId) async {
    await _repository.assignNurseToAppointment(appointmentId, nurseId);
  }

  void setFilterStatus(AppointmentStatus status) {
    _filterStatus = status;
    notifyListeners();
  }
}