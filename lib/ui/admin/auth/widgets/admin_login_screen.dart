import 'dart:async' show unawaited;

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/routing/route_paths.dart';
import 'package:moliseis/ui/admin/auth/view_models/admin_auth_view_model.dart';
import 'package:moliseis/ui/core/ui/custom_back_button.dart';
import 'package:moliseis/ui/core/ui/custom_circular_progress_indicator.dart';
import 'package:moliseis/utils/result_command.dart';
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

  late AdminAuthViewModel _observedAuth;
  bool _replacingLogin = false;

  @override
  void initState() {
    super.initState();
    _bindAuth(widget.viewModel);
  }

  @override
  void didUpdateWidget(covariant AdminLoginScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.viewModel, widget.viewModel)) {
      _observedAuth.removeListener(_replacePushedLoginWithDashboard);
      _bindAuth(widget.viewModel);
    }
  }

  void _bindAuth(AdminAuthViewModel owner) {
    _observedAuth = owner;
    _replacingLogin = false;
    owner.addListener(_replacePushedLoginWithDashboard);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!identical(widget.viewModel, owner)) return;
      _replacePushedLoginWithDashboard();
    });
  }

  @override
  void dispose() {
    _observedAuth.removeListener(_replacePushedLoginWithDashboard);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _replacePushedLoginWithDashboard() {
    if (!mounted) return;
    final owner = _observedAuth;
    if (_replacingLogin ||
        owner.isDisposed ||
        !identical(widget.viewModel, owner) ||
        !owner.isAdmin) {
      return;
    }

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
      _replacingLogin = true;
      unawaited(router.pushReplacement(RoutePaths.admin));
    }
  }

  void _login() {
    if (!mounted) return;
    final owner = _observedAuth;
    if (!identical(widget.viewModel, owner)) return;
    if (_formKey.currentState!.validate()) {
      owner.requestLogin((
        email: _emailController.text.trim(),
        password: _passwordController.text,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final owner = widget.viewModel;

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
                    listenable: owner,
                    builder: (_, _) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          FilledButton(
                            onPressed: owner.canLogin ? _login : null,
                            child: owner.isAuthenticating
                                ? const CustomCircularProgressIndicator(
                                    size: 20,
                                  )
                                : const Text('Accedi'),
                          ),
                          if (owner.loginSnapshot.hasFailure)
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
