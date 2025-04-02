import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mama_care/domain/entities/user_model.dart';
import 'package:mama_care/presentation/screen/edit_profile_screen.dart';
import 'package:mama_care/presentation/view/dashboard_view.dart';
import 'package:mama_care/presentation/viewmodel/dashboard_viewmodel.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EditProfileScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage: user.profileImageUrl != null
                ? NetworkImage(user.profileImageUrl!)
                : const AssetImage('assets/images/default_user.png') as ImageProvider,
          ),
          Text('Name: ${user.name}'),
          Text('Email: ${user.email}'),
          Text('Phone: ${user.phoneNumber ?? 'Not provided'}'),
        ],
      ),
    );
  }
}