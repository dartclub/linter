// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:linter/src/analyzer.dart';

const _desc = 'Prefer int literals over double literals.';

const _details = '''

**DO** use int literals rather than the corresponding double literal.

**BAD:**
```
const double myDouble = 8.0;
final anotherDouble = myDouble + 7.0e2;
main() {
  someMethod(6.0);
}
```

**GOOD:**
```
const double myDouble = 8;
final anotherDouble = myDouble + 700;
main() {
  someMethod(6);
}
```

''';

class PreferIntLiterals extends LintRule implements NodeLintRule {
  PreferIntLiterals()
      : super(
            name: 'prefer_int_literals',
            description: _desc,
            details: _details,
            group: Group.style);

  @override
  void registerNodeProcessors(NodeLintRegistry registry) {
    registry.addDoubleLiteral(this, new _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  final LintRule rule;

  _Visitor(this.rule);

  @override
  void visitDoubleLiteral(DoubleLiteral node) {
    // Check if the double can be represented as an int
    try {
      double value = node.value;
      if (value == null || value != value.truncate()) {
        return;
      }
      // ignore: avoid_catching_errors
    } on UnsupportedError catch (_) {
      // The double cannot be represented as an int
      return;
    }

    // Ensure that replacing the double would not change the semantics
    if (canReplaceWithIntLiteral(node)) {
      rule.reportLint(node);
    }
  }

  /// Determine if the given literal can be replaced by an int literal.
  bool canReplaceWithIntLiteral(DoubleLiteral literal) {
    // TODO(danrubel): Consider moving this into analyzer
    final AstNode parent = literal.parent;
    if (parent is ArgumentList) {
      return literal.staticParameterElement?.type?.name == 'double';
    } else if (parent is NamedExpression) {
      AstNode argList = parent.parent;
      if (argList is ArgumentList) {
        return parent.staticParameterElement?.type?.name == 'double';
      }
    } else if (parent is ExpressionFunctionBody) {
      return hasDoubleReturnType(parent.parent);
    } else if (parent is ReturnStatement) {
      BlockFunctionBody body =
          parent.getAncestor((a) => a is BlockFunctionBody);
      return hasDoubleReturnType(body.parent);
    } else if (parent is VariableDeclaration) {
      AstNode varList = parent.parent;
      if (varList is VariableDeclarationList) {
        return varList.type?.type?.name == 'double';
      }
    }
    return false;
  }

  bool hasDoubleReturnType(AstNode node) {
    if (node is FunctionExpression) {
      var functDeclaration = node.parent;
      if (functDeclaration is FunctionDeclaration) {
        return functDeclaration.returnType?.type?.name == 'double';
      }
    } else if (node is MethodDeclaration) {
      return node.returnType?.type?.name == 'double';
    }
    return false;
  }
}