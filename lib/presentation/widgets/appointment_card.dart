// lib/presentation/widgets/appointment_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:mama_care/domain/entities/appointment.dart';
import 'package:mama_care/presentation/viewmodel/doctor_dashboard_viewmodel.dart';

class AppointmentCard extends StatelessWidget {
  final Appointment appointment;

  const AppointmentCard({super.key, required this.appointment, required Null Function() onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(appointment.reason),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Requested: ${DateFormat.yMd().format(appointment.requestedTime)}'),
            if (appointment.scheduledTime != null)
              Text('Scheduled: ${DateFormat.yMd().add_jm().format(appointment.scheduledTime!)}'),
            Text('Status: ${appointment.status.name}'),
          ],
        ),
        trailing: _buildActionButtons(context),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    if (appointment.status == AppointmentStatus.pending) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () => _handleStatusUpdate(context, AppointmentStatus.confirmed),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => _handleStatusUpdate(context, AppointmentStatus.cancelled),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  void _handleStatusUpdate(BuildContext context, AppointmentStatus status) {
    context.read<DoctorDashboardViewModel>().updateAppointmentStatus(appointment.id, status);
  }
}