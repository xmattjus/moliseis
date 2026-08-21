import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:moliseis/routing/route_paths.dart';
import 'package:moliseis/ui/admin/auth/view_models/admin_auth_view_model.dart';
import 'package:moliseis/ui/core/ui/custom_back_button.dart';
import 'package:moliseis/ui/core/ui/custom_circular_progress_indicator.dart';
import 'package:moliseis/utils/string_validator.dart';

/// Staff sign-in form for the protected editorial area.
///
/// A router refresh redirects declaratively reached login routes. An
/// imperatively pushed login route retains its underlying Settings route in
/// GoRouter, so it replaces itself with the dashboard after authentication.
class AdminLoginScreen extends StatefulWidget {
  /// Creates the login form backed by the global staff auth [viewModel].
  const AdminLoginScreen({required this.viewModel, super.key});

  /// Authentication state and sign-in command shared with the router.
  final AdminAuthViewModel viewModel;

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.viewModel.addListener(_replacePushedLoginWithDashboard);
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_replacePushedLoginWithDashboard);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _replacePushedLoginWithDashboard() {
    if (!mounted || !widget.viewModel.isAdmin) return;

    final router = GoRouter.maybeOf(context);
    if (router == null ||
        router.state.uri.path != RoutePaths.adminLoginLocation) {
      return;
    }

    // GoRouter refreshes preserve imperative routes but re-run redirects only
    // for their declarative base location. Replace the pushed login route to
    // preserve the Settings route below it.
    if (router.routerDelegate.currentConfiguration.uri.path !=
        RoutePaths.adminLoginLocation) {
      unawaited(router.pushReplacement(RoutePaths.admin));
    }
  }

  void _login() {
    if (_formKey.currentState!.validate()) {
      unawaited(
        widget.viewModel.login.execute(
          (
            email: _emailController.text.trim(),
            password: _passwordController.text,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final login = widget.viewModel.login;

    return Scaffold(
      appBar: AppBar(
        leading: const CustomBackButton(),
        title: const Text('Area redazione'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16,
                children: <Widget>[
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'E-mail'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (StringValidator.isValidEmail(value?.trim())) {
                        return null;
                      }
                      return 'Inserisci un indirizzo e-mail valido';
                    },
                  ),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    validator: (value) {
                      if (value?.isNotEmpty ?? false) return null;
                      return 'Inserisci la password';
                    },
                  ),
                  ListenableBuilder(
                    listenable: login,
                    builder: (_, _) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          FilledButton(
                            onPressed: login.running ? null : _login,
                            child: login.running
                                ? const CustomCircularProgressIndicator(
                                    size: 20,
                                  )
                                : const Text('Accedi'),
                          ),
                          if (login.error)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                'Accesso non riuscito. Verifica le '
                                'credenziali e riprova.',
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
