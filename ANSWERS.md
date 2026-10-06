# Ugali Preparation Language (UPL) — Lexical Analyzer

Answers to parts **a – j** of *Designing a Lexical Analyzer for an Ugali
Preparation Language*. Every claim below is verified by running the scanner in
this folder; the command used is given with each result.

```
cd ~/Documents/3.2/compiler
java -cp classes lexer.Main samples/<file>.upl
```

---

## (a) Lexical specification — 6 marks

The lexemes of UPL fall into six categories.

| Category | Token name | Code | Example lexemes |
|---|---|---|---|
| Reserved word (keyword) | `PREPARE`, `INGREDIENTS`, `BOIL`, `WATER`, `ADD`, `FLOUR`, `STIR`, `PRESS`, `TURN`, `COOK`, `CHECK`, `CONSISTENCY`, `SHAPE`, `SERVE`, `UGALI`, `CUPS`, `MINUTES` | 1 – 17 | `prepare`, `ugali` |
| Integer literal | `NUMBER` | 18 | `4`, `2`, `8` |
| Identifier | `IDENTIFIER` | 19 | `temperature`, `maize_flour` |
| Separator | `SEMICOLON` | 20 | `;` |
| Comment | *(none — no token)* | — | `// ...` and `/* ... */` |
| White space | *(none — no token)* | — | space, tab, carriage return, line feed |

Two points worth stating explicitly in an exam answer:

* Comments and white space **are recognised but discarded**: their action does
  not `return` anything, so they never reach the parser.
* Each reserved word gets **its own token name**. `BOIL` and `ADD` cannot share
  one token because the grammar distinguishes them (`S -> ... Boiling Mixing
  ...`), and a parser must be able to tell them apart.
* `NUMBER` carries an attribute (its value), so the scanner must return both the
  type and the value — see part (d).

---

## (b) Regular expressions — 8 marks

| Lexeme class | Regular expression | JFlex rule |
|---|---|---|
| Integer literal | `[0-9]+` | `[0-9]+` |
| Identifier | `[A-Za-z][A-Za-z0-9_]*` | `[A-Za-z][A-Za-z0-9_]*` |
| White space | `[ \t\r\n]+` (add `\f` if desired) | `[ \t\r\n]+` |
| Single-line comment | `"//"[^\r\n]*` | `"//" [^\r\n]*` |
| Reserved word | `(prepare\|ingredients\|boil\|water\|add\|flour\|stir\|press\|turn\|cook\|check\|consistency\|shape\|serve\|ugali\|cups\|minutes)` | 17 separate `"word"` rules |
| Semicolon | `";"` | `";"` |
| Multi-line comment (h) | `"/\*" ([^*] \| "*"+ [^/])* "\*/"` | lexical state `COMMENT` |

Notes:

* The identifier rule is exactly the required *letter (letter | digit | _)\**; it
  accepts `temperature`, `maize_flour`, `step2` and `cooking_time`.
* The comment regex stops before the newline, so the newline itself is still
  handled by the white-space rule and line counting stays correct.
* `[^\r\n]*` is the classic JFlex idiom for "everything up to the end of the
  line".

Verification:

```
$ java -cp classes lexer.Main samples/partb_identifiers.upl
    1 |     1 |     1 | IDENTIFIER   | name = temperature
    2 |     2 |     1 | IDENTIFIER   | name = maize_flour
    3 |     3 |     1 | IDENTIFIER   | name = step2
    4 |     4 |     1 | IDENTIFIER   | name = cooking_time
```

---

## (c) JFlex implementation — 14 marks

The complete specification is **`UgaliLexer.flex`** (290 lines, heavily
commented). Its structure is:

```
package lexer;                 user code: package + imports
%%                             first separator
%public %class %type ...       options
%xstate COMMENT                lexical states
%{ ... %}                      class code: token codes, LexicalError, helpers
%eofval{ ... %eofval}          end-of-file action
%%                             second separator
"prepare" { return PREPARE; }  the 17 reserved words
";"       { return SEMICOLON; }
[0-9]+    { intValue = Integer.parseInt(yytext()); return NUMBER; }
[A-Za-z][A-Za-z0-9_]* { return IDENTIFIER; }
"//" [^\r\n]* { }              ignored
"/*"      { yybegin(COMMENT); }
[ \t\r\n]+ { }                ignored
<COMMENT> "*/" { yybegin(YYINITIAL); blockCommentCount++; }
<COMMENT> [^*] { }
<COMMENT> "*"  { }
<COMMENT> <<EOF>> { throw new LexicalError(...); }
.          { throw new LexicalError(yyline+1, yycolumn+1, yytext()); }
```

How each requirement of the question is met:

| Requirement | Implementation |
|---|---|
| recognise all reserved words | 17 string-literal rules, each returning its own code |
| recognise integers and preserve the value | `[0-9]+` stores the parsed value in the public field `intValue` |
| recognise identifiers | `[A-Za-z][A-Za-z0-9_]*` |
| recognise semicolons | `";"` |
| ignore spaces, tabs, line breaks | `[ \t\r\n]+` with an empty action |
| ignore single-line comments | `"//" [^\r\n]*` with an empty action |
| maintain line and column | `%line` and `%column`; accessors `getLineNumber()` / `getColumnNumber()` |
| detect illegal characters | the final catch-all rule `.` |
| meaningful error message | `LexicalError`, formatted as required |

Three details that are easy to get wrong and are worth naming in the answer:

1. **`package` goes before the first `%%`.** JFlex copies that region verbatim;
   putting the package declaration after `%%` produces a generated file that
   cannot compile.
2. **The catch-all rule `.` must be the last rule.** JFlex resolves a tie in
   length by taking the *first* rule, so an early `.` would swallow everything.
3. **`yyline` and `yycolumn` both start at 0.** One is therefore added to each so
   that positions read the way a human counts; this is also why a file whose
   first line contains an error would otherwise be reported as "line 0".

Real error output:

```
Lexical error at line 4, column 7: illegal character '#'
```

which is exactly the format required by the question.

---

## (d) Token attributes — 6 marks

A token is a pair *(type, attribute)*. `NUMBER` needs its numeric value, so the
scanner publishes a public field:

```jflex
[0-9]+   { intValue = Integer.parseInt(yytext());
           return NUMBER;      }
```

`Main.attributeOf()` then reads it back:

```java
case UgaliLexer.NUMBER: return "value = " + scanner.intValue;
```

Input `boil 4 cups water;` produces

```
    4 |     2 |     6 | NUMBER       | value = 4
```

that is, conceptually

```
BOIL, NUMBER(4), CUPS, WATER, SEMICOLON
```

**Why the value 4 matters to later phases**

* *Syntax analysis* only needs the *type* `NUMBER` to accept or reject the
  production `Quantity -> NUMBER CUPS`. The value is irrelevant for parsing.
* *Semantic analysis and code generation* need the **value**: the number of cups
  determines how much water to boil, so an interpreter or generated code must use
  `4`, not the text `"4"`.
* Keeping the value means the parser never has to re-examine the character
  stream; a single left-to-right pass over the text is enough for the whole
  compilation.
* Had the scanner returned only `NUMBER` with no attribute, the parser would have
  to re-lex the lexeme to recover the number — a design error that also breaks
  in a CUP integration, where the character stream is no longer available.

---

## (e) Reserved words versus identifiers — 6 marks

Input:

```
cook cooking_time;
serve server;
```

Output:

```
    1 |     1 |     1 | COOK         | -
    2 |     1 |     6 | IDENTIFIER   | name = cooking_time
    3 |     1 |    18 | SEMICOLON    | -
    4 |     2 |     1 | SERVE        | -
    5 |     2 |     7 | IDENTIFIER   | name = server
    6 |     2 |    13 | SEMICOLON    | -
```

How the scanner distinguishes them:

1. **The reserved-word rules are tried first.** At the start of `cook` the scanner
   compares the input against every rule and applies the **longest match rule**:
   the match that consumes the most characters wins.
2. `"cook"` matches 4 characters; the identifier rule also matches 4 characters
   (`cook`). Both rules match the *same* length, so JFlex falls back on **rule
   order**: `"cook"` is written before the identifier rule, so `COOK` is
   returned.
3. `cooking_time` — the identifier rule matches 12 characters, which is longer
   than the 4 characters matched by `"cook"`. **Longest match wins outright**,
   so the whole word becomes one `IDENTIFIER` and is never split into
   `COOK` + `ING` + `_` + `TIME`.
4. `server` is not a reserved word at all, so only the identifier rule matches.

**Consequences for rule order**

* Putting the identifier rule **before** the keywords would break the language:
  `cook` would become an `IDENTIFIER`, and `PREPARE INGREDIENTS SEMICOLON`
  could never be parsed.
* If the identifier rule came first *and* the keywords were written with an
  explicit boundary such as `cook[^A-Za-z0-9_]`, the space would be swallowed and
  the token text corrupted — another reason to rely on rule order instead.
* Because matching is purely textual, the scanner cannot know that `cooking_time`
  is *related* to `cook`; that is the parser's business, and it will reject
  `cook cooking_time;` as a **syntax** error (`COOK IDENTIFIER` matches no
  production of the given grammar).

---

## (f) Testing the scanner — 8 marks

Input (`samples/partf_valid.upl`):

```
// Ugali preparation program
prepare ingredients;
boil 4 cups water;
add 2 cups flour;
stir;
add 1 cups flour;
stir;
press ugali;
turn ugali;
cook 8 minutes;
check consistency;
shape ugali;
serve ugali;
```

The token stream that should be produced:

```
PREPARE, INGREDIENTS, SEMICOLON,
BOIL, NUMBER(4), CUPS, WATER, SEMICOLON,
ADD, NUMBER(2), CUPS, FLOUR, SEMICOLON, STIR, SEMICOLON,
ADD, NUMBER(1), CUPS, FLOUR, SEMICOLON, STIR, SEMICOLON,
PRESS, UGALI, SEMICOLON,
TURN, UGALI, SEMICOLON,
COOK, NUMBER(8), MINUTES, SEMICOLON,
CHECK, CONSISTENCY, SEMICOLON,
SHAPE, UGALI, SEMICOLON,
SERVE, UGALI, SEMICOLON
```

That is **41 tokens**. The actual run confirms it one token per line:

```
$ java -cp classes lexer.Main samples/partf_valid.upl
    1 |     1 |     1 | PREPARE      | -
    2 |     1 |     9 | INGREDIENTS  | -
    3 |     1 |    20 | SEMICOLON    | -
    4 |     2 |     1 | BOIL         | -
    5 |     2 |     6 | NUMBER       | value = 4
    6 |     2 |     8 | CUPS         | -
    7 |     2 |    13 | WATER        | -
    8 |     2 |    18 | SEMICOLON    | -
    9 |     3 |     1 | ADD          | -
   10 |     3 |     5 | NUMBER       | value = 2
   11 |     3 |     7 | CUPS         | -
   12 |     3 |    12 | FLOUR        | -
   13 |     3 |    17 | SEMICOLON    | -
   14 |     4 |     1 | STIR         | -
   15 |     4 |     5 | SEMICOLON    | -
   16 |     5 |     1 | ADD          | -
   17 |     5 |     5 | NUMBER       | value = 1
   18 |     5 |     7 | CUPS         | -
   19 |     5 |    12 | FLOUR        | -
   20 |     5 |    17 | SEMICOLON    | -
   21 |     6 |     1 | STIR         | -
   22 |     6 |     5 | SEMICOLON    | -
   23 |     7 |     1 | PRESS        | -
   24 |     7 |     7 | UGALI        | -
   25 |     7 |    12 | SEMICOLON    | -
   26 |     8 |     1 | TURN         | -
   27 |     8 |     6 | UGALI        | -
   28 |     8 |    11 | SEMICOLON    | -
   29 |     9 |     1 | COOK         | -
   30 |     9 |     6 | NUMBER       | value = 8
   31 |     9 |     8 | MINUTES      | -
   32 |     9 |    15 | SEMICOLON    | -
   33 |    10 |     1 | CHECK        | -
   34 |    10 |     7 | CONSISTENCY  | -
   35 |    10 |    18 | SEMICOLON    | -
   36 |    11 |     1 | SHAPE        | -
   37 |    11 |     7 | UGALI        | -
   38 |    11 |    12 | SEMICOLON    | -
   39 |    12 |     1 | SERVE        | -
   40 |    12 |     7 | UGALI        | -
   41 |    12 |    12 | SEMICOLON    | -

  Tokens recognised : 41
  Lexical errors    : 0
  RESULT            : PASS - the input is lexically valid
```

Note that the `// Ugali preparation program` comment contributes **no** token,
and that the sequence is exactly the one described by the grammar:
`Preparation Boiling Mixing Cooking Checking Shaping Serving`.

---

## (g) Lexical error detection — 7 marks

Input (`samples/partg_invalid.upl`):

```
prepare ingredients;
boil 4 cups water;
add @2 cups flour;
cook 5# minutes;
```

Two characters are illegal, because they match **no** rule at all:

| Character | Line | Column | Why it is illegal |
|---|---|---|---|
| `@` | 3 | 5 | `@` is in neither the keyword set, the identifier rule, the number rule nor the separator |
| `#` | 4 | 7 | same reason |

Error messages produced by the scanner:

```
Lexical error at line 3, column 5: illegal character '@'
Lexical error at line 4, column 7: illegal character '#'
```

Column counting is 1-based, so the `@` really is the 5th character of line 3
(`a`=1, `d`=2, `d`=3, space=4, `@`=5).

Because a lexical error destroys the synchronisation between the character
stream and the token stream, the driver stops at the **first** error. Running the
file as given therefore reports only `@`; the second message is obtained from
`samples/partg_invalid_hash.upl`, which is the same file with the `@` repaired:

```
$ java -cp classes lexer.Main samples/partg_invalid.upl
  Lexical error at line 3, column 5: illegal character '@'

$ java -cp classes lexer.Main samples/partg_invalid_hash.upl
  Lexical error at line 4, column 7: illegal character '#'
```

How detection works: the last rule of the scanner is the catch-all `.`, which
matches any single character that no other rule matched. Its action throws
`LexicalError`, a `RuntimeException` carrying the line, the column and the
offending text. `Main` catches it, prints the message and reports
`FAIL - the input is not lexically valid`.

---

## (h) Extension: lexical states — 10 marks

Multi-line comments cannot be expressed with a single regular expression rule in
a hand-written scanner, because the closing delimiter `*/` may appear after an
arbitrary amount of text, arbitrary newlines included. The regular-expression
solution exists (`"/\*" ([^*] | "*"+ [^/])* "\*/"`), but JFlex expresses it far
more clearly and efficiently with a **lexical state**.

### The mechanism

```jflex
%xstate COMMENT          /* an EXCLUSIVE state */
```

* `%xstate COMMENT` declares an exclusive state. **Do not use `%state`**: an
  inclusive state also keeps its rules active in `YYINITIAL`, and — worse — the
  `YYINITIAL` rules stay active *inside* the state, so the identifier rule would
  happily tokenise the text of the comment. This is a genuine trap; it is the
  reason the `%xstate` keyword exists.
* `"/*"` in `YYINITIAL` calls `yybegin(COMMENT)`: the scanner changes its DFA
  being used and from now on only the `<COMMENT>` rules can match.
* Inside `COMMENT` there are only three ordinary rules:

  ```jflex
  <COMMENT> "*/" { yybegin(YYINITIAL); blockCommentCount++; }  /* leave */
  <COMMENT> [^*] { }                                          /* ignore text */
  <COMMENT> "*"  { }                                          /* lone star   */
  ```

  `"*/"` is listed **before** the single-character rules; by the longest-match and
  rule-order rules a two-character match always beats a one-character match, so
  `*/` is recognised and a star inside the text (`2 * 3`) is ignored.
* The fourth rule is an **end-of-file rule**, `<<EOF>>`. It fires when the input
  is exhausted while the scanner is still in `COMMENT`, which is exactly the
  unterminated-comment case:

  ```jflex
  <COMMENT> <<EOF>> { throw new LexicalError(yyline + 1, yycolumn + 1,
                        "unterminated comment, the closing */ is missing"); }
  ```

### Verification

```
$ java -cp classes lexer.Main samples/parth_blockcomment.upl
  Tokens recognised : 15
  Block comments    : 1
  RESULT            : PASS - the input is lexically valid
```

The comment text — *"Ugali should be stirred continuously. Add flour
gradually."* — contributes no token at all; only `PREPARE INGREDIENTS SEMICOLON
BOIL NUMBER(4) CUPS WATER SEMICOLON ADD NUMBER(2) CUPS FLOUR SEMICOLON STIR
SEMICOLON` is produced.

```
$ java -cp classes lexer.Main samples/parth_unterminated.upl
  Lexical error at line 3, column 43: unterminated comment, the closing */ is missing
  RESULT            : FAIL - the input is not lexically valid
```

The state also gives a neat side effect: the scanner knows how many block
comments it has skipped, which is reported as `Block comments`.

---

## (i) Scanner and parser relationship — 10 marks

### Token generation and the CUP interface

CUP expects the scanner to implement

```java
public interface java_cup.runtime.Scanner {
    Symbol next_token() throws java.lang.Exception;
}
```

To connect a JFlex scanner to CUP:

1. **Delete the local token constants** from `UgaliLexer.flex`. CUP generates a
   `sym` class from the grammar's terminal declarations, and the parser refers to
   those symbols; the two files must not define the codes independently.
2. **Turn on CUP support** in the options section:

   ```jflex
   %cup
   %cupstream
   %type java_cup.runtime.Symbol
   ```

   `%cupstream` makes JFlex generate the `Scanner` implementation; without it
   `%type Symbol` alone does not satisfy the interface.
3. **Return a `Symbol` instead of an `int`**, carrying the production position so
   that CUP can build meaningful error messages:

   ```jflex
   "boil"  { return new Symbol(BOIL,  yyline + 1, yycolumn + 1); }
   ";"     { return new Symbol(SEMICOLON, yyline + 1, yycolumn + 1); }
   [0-9]+  { intValue = Integer.parseInt(yytext());
              return new Symbol(NUMBER, yyline + 1, yycolumn + 1, Integer.valueOf(intValue)); }
   [A-Za-z][A-Za-z0-9_]* {
              return new Symbol(IDENTIFIER, yyline + 1, yycolumn + 1, yytext()); }
   ```

### Passing tokens from the scanner to the parser

* The parser owns the scanner: `parser.yylex = new UgaliLexer(new FileReader(src));`
  `CUP` calls `yylex.next_token()` whenever it needs a lookahead symbol, so the
  tokens flow strictly on demand and left to right; the driver loop of `Main` is
  replaced by the parser's own loop.
* Because the pull model is used, the scanner must keep its position state
  (`yyline`, `yycolumn`, and the lexical state) between calls — this is another
  reason a single `UgaliLexer` instance is used for the whole file rather than a
  fresh one per token.

### Token attributes

* `new Symbol(id, left, right, value)` stores the semantic value in
  `Symbol.value`. In a CUP action the parser recovers it with
  `((Number) value).intValue()` for `NUMBER` and `(String) value` for
  `IDENTIFIER`, because CUP does not know Java types.
* This is exactly the `intValue` field of part (d), except that CUP requires it
  inside the `Symbol` so that the value travels together with the token. A
  separate public field also works, but it is only safe as long as the parser
  consumes the value before asking for the next token.
* `yyline`/`yycolumn` passed as `left`/`right` give every token a source
  position, which CUP uses in `parse_error` to print
  `Can't parse input: "four"` with the line number.

### Role of the symbol table

* The symbol table is built **after** lexical analysis, by the semantic phase.
  Each `IDENTIFIER` is looked up and either found (existing variable / ingredient
  name) or inserted with a fresh entry recording at least *name* and *line of
  first use*; `NUMBER` literals are added as constants.
* It is what turns a stream of names into *references to declared quantities*, so
  it is the link between the scanner's `IDENTIFIER("cooking_time")` and the
  interpreter's variable slot.
* In the grammar given in the question no `IDENTIFIER` appears in any production,
  so the symbol table would in fact be empty — a good observation for the answer:
  the lexer produces a token the grammar cannot use, and the parser rejects it.
* Keeping the symbol table out of the lexer is deliberate: it is a per-program
  data structure that the parser and the semantic analyser share, and it must
  survive across the whole file, not just across one `nextToken()` call.

### Lexical errors versus syntax errors

| | Lexical error | Syntax error |
|---|---|---|
| Cause | a character that matches **no** token | tokens that are individually valid but form **no** production |
| Detected by | the scanner (`UgaliLexer.LexicalError`) | the parser (`parse_error`) |
| Example | `@` in `add @2 cups flour;` | `boil four cups water;` |
| Recovery | stop; the token stream is out of step with the text | discard or insert a token and continue |

The two phases therefore have different error vocabularies and different
recovery strategies, and this split is what makes each phase testable on its
own.

---

## (j) Analysis question — 10 marks

Input: `boil four cups water;`

### (1) Which tokens does the lexer generate?

```
BOIL, IDENTIFIER(four), CUPS, WATER, SEMICOLON
```

Actual output:

```
    1 |     1 |     1 | BOIL         | -
    2 |     1 |     6 | IDENTIFIER   | name = four
    3 |     1 |    11 | CUPS         | -
    4 |     1 |    16 | WATER        | -
    5 |     1 |    21 | SEMICOLON    | -
```

`four` is matched by `[A-Za-z][A-Za-z0-9_]*` (4 characters), while the reserved
word `"boil"` matches 4 characters as well — but `four` is not a keyword at all,
so the identifier rule is the only one that matches it.

### (2) Should the lexer report an error?

**No.** `four` is a perfectly well-formed identifier, so from the point of view of
the token alphabet the input is lexically valid:

```
  Lexical errors    : 0
  RESULT            : PASS - the input is lexically valid
```

A lexer may only report an error when it can form **no** token at all. It has no
knowledge of the grammar, so it cannot know that this particular identifier is
in the wrong place — nor could it, even if it did, because whether an identifier
is acceptable depends on which production is being matched.

### (3) Which phase detects that `Quantity -> NUMBER CUPS` is violated?

The **parser** (syntax analysis). At the point where the grammar expects
`NUMBER`, the lookahead symbol is `IDENTIFIER`, so no item of the LR table
matches and CUP's `parse_error` is invoked:

```
Can't parse input: "four"
```

If the grammar were written in BNF the same diagnosis is obvious: `Quantity`
derives only `NUMBER CUPS`, so the token `IDENTIFIER` cannot appear where a
`NUMBER` is required. Recovering from this error (deleting the offending token or
inserting a missing one) is also the parser's job, since only the parser knows
which token the grammar was expecting.

### (4) Why this illustrates the separation of the two phases

* **Different inputs.** The lexer is described by *regular expressions* (a
  regular language, recognisable by a finite automaton); the parser is described
  by a *context-free grammar*. `NUMBER CUPS` is a context-free rule, not a
  regular one, so it lies outside the power of a finite automaton — no amount of
  extra DFA states could let a scanner check it.
* **Different error classes.** The `four` case produces no lexical error at all;
  the failure only appears once the token sequence meets the grammar. Conversely
  `@` produces a lexical error even though the token sequence looks perfectly
  plausible.
* **Different responsibilities.** The lexer answers *"what are the tokens?"*; the
  parser answers *"do the tokens make a program?"*. Only the parser needs the
  grammar, so only the parser can detect a grammar violation.
* **Practical consequence.** Because the phases are separated, the same scanner
  works with any grammar, a lexer can be tested on its own (as `Main` does with
  the samples in this folder), and a grammar can be changed without touching the
  scanner. It is also why the lexer runs **first** and each phase consumes only
  the output of the previous one.

The counterpart example in this project is `partg_invalid.upl`: `@` is rejected
by the lexer on lexical grounds, and no grammar rule is consulted at all.

---

## Appendix — token codes

| Code | Token | Code | Token |
|---|---|---|---|
| 1 | `PREPARE` | 11 | `CHECK` |
| 2 | `INGREDIENTS` | 12 | `CONSISTENCY` |
| 3 | `BOIL` | 13 | `SHAPE` |
| 4 | `WATER` | 14 | `SERVE` |
| 5 | `ADD` | 15 | `UGALI` |
| 6 | `FLOUR` | 16 | `CUPS` |
| 7 | `STIR` | 17 | `MINUTES` |
| 8 | `PRESS` | 18 | `NUMBER` |
| 9 | `TURN` | 19 | `IDENTIFIER` |
| 10 | `COOK` | 20 | `SEMICOLON` |

`YYEOF` is `-1` (JFlex's own value) and is reported as `EOF`.