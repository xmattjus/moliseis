import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

class NoRawStringInLogRule extends AnalysisRule {
  NoRawStringInLogRule()
    : super(
        name: 'no_raw_string_in_log',
        description: 'Do not use raw string literals in log calls.',
      );

  static const LintCode code = LintCode(
    'no_raw_string_in_log',
    'Do not use raw string literals in log calls.',
    correctionMessage: 'Use a Messages constant instead.',
  );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addMethodInvocation(this, _Visitor(this, context));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  static const _logMethods = {
    'error',
    'critical',
    'info',
    'debug',
    'verbose',
    'warning',
  };

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final target = node.realTarget;
    if (target == null) return;
    if (target.staticType?.element?.name != 'Talker') return;
    if (!_logMethods.contains(node.methodName.name)) return;

    final args = node.argumentList.arguments;
    if (args.isEmpty) return;

    final first = args.first;

    // In analyzer 10.x, argumentList.arguments is NodeList<Expression>.
    // Named arguments are wrapped in NamedExpression; unwrap them.
    final Expression expr = first is NamedExpression ? first.expression : first;

    if (_isRawString(expr)) {
      rule.reportAtNode(expr);
    }
  }

  /// Returns true for any expression that resolves to a hardcoded string:
  ///   "hello"                  → SimpleStringLiteral
  ///   'hello'                  → SimpleStringLiteral
  ///   '''hello'''              → SimpleStringLiteral
  ///   "hello $name"            → StringInterpolation   ← also flagged
  ///   "hello" " " "world"      → AdjacentStrings
  bool _isRawString(Expression expr) =>
      expr is SimpleStringLiteral ||
      expr is StringInterpolation ||
      expr is AdjacentStrings;
}
