import 'package:flutter/material.dart';

import 'semester_screen.dart';

/// The required Management screen manages the semester entity. Activating a
/// semester writes the mobile-facing registration projection, so this is the
/// real administrative entity rather than a separate mock Events screen.
class ManagementScreen extends StatelessWidget {
  const ManagementScreen({super.key});

  @override
  Widget build(BuildContext context) => const SemesterScreen();
}
