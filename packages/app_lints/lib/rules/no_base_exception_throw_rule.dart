import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

class NoBaseExceptionThrowRule extends AnalysisRule {
  NoBaseExceptionThrowRule()
    : super(
        name: 'no_base_exception_throw',
        description:
            'Do not throw base Exception or Error. Use a domain-specific app exception class instead.',
      );

  static const LintCode code = LintCode(
    'no_base_exception_throw',
    'Do not throw base Exception or Error. Use a domain-specific app exception class instead.',
    correctionMessage:
        'Replace with an AppException subclass (e.g. NetworkException, CacheException).',
  );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addThrowExpression(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final NoBaseExceptionThrowRule rule;

  static const _forbiddenTypes = {'Exception', 'Error'};

  @override
  void visitThrowExpression(ThrowExpression node) {
    final expression = node.expression;

    // Covers: throw Exception('...')
    if (expression is InstanceCreationExpression) {
      final typeName = expression.constructorName.type.name.lexeme;
      if (_forbiddenTypes.contains(typeName)) {
        rule.reportAtNode(node);
      }
      return;
    }

    // Covers: throw someVariable (checks static type)
    final typeName = expression.staticType?.element?.name;
    if (typeName != null && _forbiddenTypes.contains(typeName)) {
      rule.reportAtNode(node);
    }
  }
}
