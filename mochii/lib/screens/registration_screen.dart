import 'package:flutter/material.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({
    required this.onSubmit,
    this.isSubmitting = false,
    this.errorMessage,
    super.key,
  });

  final Future<void> Function(String moniker) onSubmit;
  final bool isSubmitting;
  final String? errorMessage;

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final TextEditingController _monikerController = TextEditingController();

  @override
  void dispose() {
    _monikerController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final String moniker = _monikerController.text.trim();
    if (moniker.isEmpty) {
      return;
    }

    await widget.onSubmit(moniker);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registration')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'Choose your moniker',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _monikerController,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _handleSubmit(),
              decoration: const InputDecoration(
                hintText: 'Moniker',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: widget.isSubmitting ? null : _handleSubmit,
              child: widget.isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Register'),
            ),
            if (widget.errorMessage != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                widget.errorMessage!,
                style: const TextStyle(color: Colors.redAccent),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
