import 'package:flutter/material.dart';

import '/services/details_service.dart';
import '/models/doctor_details.dart';
import 'doctor_details_screen.dart';

class DoctorDetailsFormScreen extends StatefulWidget {
  final String token;
  final int userId;

  const DoctorDetailsFormScreen({
    super.key,
    required this.token,
    required this.userId,
  });

  @override
  State<DoctorDetailsFormScreen> createState() =>
      _DoctorDetailsFormScreenState();
}

class _DoctorDetailsFormScreenState extends State<DoctorDetailsFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _specialty = TextEditingController();
  final TextEditingController _experienceYears = TextEditingController();
  final TextEditingController _notes = TextEditingController();

  bool loading = false;

  Future<void> submitDoctorDetails() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => loading = true);

    final request = DoctorDetailsRequest(
      userId: widget.userId,
      specialty: _specialty.text.trim(),
      experienceYears: int.tryParse(_experienceYears.text.trim()) ?? 0,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );

    final response = await DetailsService().createDoctorDetails(request);

    if (!mounted) return;

    setState(() => loading = false);

    if (response.statusCode == 201 || response.statusCode == 200) {
      // حفظ ناجح → نذهب لعرض تفاصيل الطبيب
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (_) => DoctorDetailsScreen(
                token: widget.token,
                userId: widget.userId,
              ),
        ),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed: ${response.body}")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Doctor Details")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _specialty,
                decoration: const InputDecoration(labelText: "Specialty"),
                validator:
                    (v) => v == null || v.isEmpty ? "Required field" : null,
              ),

              const SizedBox(height: 15),

              TextFormField(
                controller: _experienceYears,
                decoration: const InputDecoration(
                  labelText: "Years of Experience",
                ),
                keyboardType: TextInputType.number,
                validator:
                    (v) => v == null || v.isEmpty ? "Required field" : null,
              ),

              const SizedBox(height: 15),

              TextFormField(
                controller: _notes,
                decoration: const InputDecoration(labelText: "Notes"),
                maxLines: 3,
              ),

              const SizedBox(height: 25),

              loading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                    onPressed: submitDoctorDetails,
                    child: const Text("Save"),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
