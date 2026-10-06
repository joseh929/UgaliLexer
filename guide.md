# Ugali Preparation Language (UPL) — Lexical Analyzer Step-by-Step Guide

Everything below was executed and verified on **Fedora Linux** with
**OpenJDK**, **JFlex 1.7.0** and **Eclipse JDT (ecj)**.

---

## 1. Project layout

```
compiler/
├── UgaliLexer.flex          the JFlex specification (the deliverable)
├── Main.java                the test driver (package lexer)
├── step_by_step_guide.md    this file
├── generated/
│   └── UgaliLexer.java      produced by JFlex (do not edit by hand)
├── classes/                 produced by the Java compiler
└── ANSWERS.md                written answers to parts (a) - (j)
└── samples/                  the programs used in the question itself
    ├── partf_valid.upl             part (f)  valid program
    ├── partg_invalid.upl           part (g)  contains '@'
    ├── partg_invalid_hash.upl      part (g)  contains '#'
    ├── parte_identifiers.upl       part (e)  cooking_time / server
    ├── partb_identifiers.upl       part (b)  identifier examples
    ├── partj_four.upl              part (j)  boil four cups water;
    ├── parth_blockcomment.upl      part (h)  /* ... */ comment
    └── parth_unterminated.upl      part (h)  unterminated comment
```

---

## 2. Install the tools

### 2.1 Java

```bash
java -version          # a JRE is not enough, you need a JDK (javac)
```

If `javac` is missing on Fedora:

```bash
sudo dnf install java-21-openjdk-devel
```

### 2.2 JFlex

```bash
# check whether it is already installed
jflex --version

# otherwise install it
sudo dnf install java-21-openjdk-devel jflex
```

JFlex needs a CUP runtime on the class path. On Fedora that is
`/usr/share/java/java_cup.jar`, so the full command is:

```bash
java -cp "jflex.jar:/usr/share/java/java_cup.jar" jflex.Main --version
```

If `jflex` is already on the `PATH` the short form is enough:

```bash
jflex --version
```

### 2.3 No JDK? Use ecj as a compiler

Only a JRE is needed to run ecj, which is a single jar:

```bash
curl -L -o ecj.jar https://repo1.maven.org/maven2/org/eclipse/jdt/ecj/3.33.0/ecj-3.33.0.jar
java -jar ecj.jar -version
```

Every `javac` command in this guide has an `ecj` equivalent below it.

---

## 3. Generate the scanner

```bash
cd ~/Documents/3.2/compiler
mkdir -p generated classes

jflex -d generated UgaliLexer.flex
```

Expected output:

```
Reading "UgaliLexer.flex"
Writing code to "generated/UgaliLexer.java"
```

Equivalent when JFlex is not installed as an executable:

```bash
java -cp "jflex.jar:/usr/share/java/java_cup.jar" \
     jflex.Main -d generated UgaliLexer.flex
```

`UgaliLexer.flex` declares `package lexer;` **before** the first `%%`, so the
generated file must be compiled from the right directory and JFlex is told the
output directory explicitly with `-d`.

---

## 4. Compile

```bash
javac -d classes generated/UgaliLexer.java Main.java
```

or without a JDK:

```bash
java -jar ecj.jar -nowarn -1.8 -d classes generated/UgaliLexer.java Main.java
```

Nothing must be printed when the compilation succeeds.

---

## 5. Run the scanner on the samples

```bash
java -cp classes lexer.Main samples/partf_valid.upl
java -cp classes lexer.Main samples/partg_invalid.upl
java -cp classes lexer.Main samples/partg_invalid_hash.upl
java -cp classes lexer.Main samples/parte_identifiers.upl
java -cp classes lexer.Main samples/partb_identifiers.upl
java -cp classes lexer.Main samples/partj_four.upl
java -cp classes lexer.Main samples/parth_blockcomment.upl
java -cp classes lexer.Main samples/parth_unterminated.upl
```

### 5.1 Expected results

| Sample | Tokens | Block comments | Result |
|---|---|---|---|
| `partf_valid.upl` | 41 | 0 | `PASS` |
| `partb_identifiers.upl` | 4 | 0 | `PASS` |
| `parte_identifiers.upl` | 6 | 0 | `PASS` |
| `partj_four.upl` | 5 | 0 | `PASS` |
| `parth_blockcomment.upl` | 15 | 1 | `PASS` |
| `partg_invalid.upl` | 9 | 0 | `FAIL` at line 3, column 5 |
| `partg_invalid_hash.upl` | 15 | 0 | `FAIL` at line 4, column 7 |
| `parth_unterminated.upl` | 8 | 0 | `FAIL` at line 3, column 43 |

Exact error messages:

```
Lexical error at line 3, column 5: illegal character '@'
Lexical error at line 4, column 7: illegal character '#'
Lexical error at line 3, column 43: unterminated comment, the closing */ is missing
```

`parth_blockcomment.upl` is the regression test for section 8: it prints
`Block comments : 1`, which is only possible if the comment text produced no
tokens.

### 5.2 First lines of a real run

```
================================================================
 UPL Lexical Analyzer
 Source file : samples/partf_valid.upl
 Length      : 202 characters
================================================================

TOKEN |  LINE | COLUMN | TYPE         | ATTRIBUTE
----------------------------------------------------------------
    1 |     1 |     1 | PREPARE      | -
    2 |     1 |     9 | INGREDIENTS  | -
    3 |     1 |    20 | SEMICOLON    | -
    4 |     2 |     1 | BOIL         | -
    5 |     2 |     6 | NUMBER       | value = 4
```

`Main` also returns a shell exit code, `0` for a valid file and `1` for a
lexical error, so the scanner can be used inside scripts:

```bash
for f in samples/*.upl; do
    java -cp classes lexer.Main "$f" > /dev/null && echo "$f : valid" || echo "$f : invalid"
done
```

---

## 6. How the specification is organised

```
package lexer;          user code: package and imports
%%                      first separator
%class %type ...        options
%xstate COMMENT         lexical states
%{ ... %}               class code copied into the scanner
%eofval{ ... %eofval}   end of file action
%%                      second separator
rules                   patterns and actions
```

JFlex 1.7 reads the whole file in three blocks:

1. everything before the first `%%` is copied verbatim (package + imports),
2. everything between the two `%%` is read as options, declarations and
   `%{ ... %}` class code,
3. everything after the second `%%` is the list of lexical rules.

Writing `package` after the first `%%` is a compile error, and forgetting the
second `%%` produces the misleading message
`This seems not to be a lexical specification (first %% is missing)`.

---

## 7. Rules, in the order they are needed

| # | Pattern | Action | Purpose |
|---|---|---|---|
| 1 | `"prepare"` … `"minutes"` | `return <CODE>;` | the 17 reserved words |
| 2 | `";"` | `return SEMICOLON;` | the only separator |
| 3 | `[0-9]+` | `intValue = Integer.parseInt(yytext()); return NUMBER;` | integer literal + attribute |
| 4 | `[A-Za-z][A-Za-z0-9_]*` | `return IDENTIFIER;` | identifiers |
| 5 | `"//" [^\r\n]*` | nothing | single line comment |
| 6 | `"/*"` | `yybegin(COMMENT);` | open a multi line comment |
| 7 | `[ \t\r\n]+` | nothing | white space |
| 8 | `<COMMENT> "*/"` | `yybegin(YYINITIAL); blockCommentCount++;` | close the comment |
| 9 | `<COMMENT> [^*]` | nothing | comment text |
| 10 | `<COMMENT> "*"` | nothing | a star that does not close |
| 11 | `<COMMENT> <<EOF>>` | `throw new LexicalError(...)` | unterminated comment |
| 12 | `.` | `throw new LexicalError(...)` | any other character is illegal |

Two facts of the longest-match rule explain the whole table:

* `minutes` (7 characters) beats the identifier rule (also 7 characters) only
  because the keyword rules are written **first**; JFlex uses the first rule
  when two rules match the same length.  This is exactly what part (e) of the
  question asks about (`cook` vs `cooking_time`).
* `water2` is **one** identifier, because the identifier rule matches 6
  characters while `water` (the keyword) only matches 5.

Rule 12 must be the **last** rule, otherwise it would win every tie against
the rules above it.

---

## 8. `%xstate COMMENT` — why *exclusive*

`%state` declares an **inclusive** state: its rules are also active in
`YYINITIAL`. With `%state COMMENT` the identifier rule keeps matching inside a
comment, and a multi line comment such as

```
/* the words water and flour are not tokens */
```

is scanned as a sequence of `IDENTIFIER`, `WATER`, `AND`, `FLOUR` tokens.
`%xstate COMMENT` declares an **exclusive** state, so only rules 8–11 are active
there and the comment really is skipped. `samples/parth_blockcomment.upl` is the
regression test for this: it prints `Block comments : 1` and `PASS`.

The last sample proves the opposite corner: an unterminated comment reaches
`<<EOF>>` while the scanner is still in `COMMENT`, and that rule raises the
error.

---

## 9. Line and column numbers

```jflex
%line      /* keeps yyline   up to date */
%column    /* keeps yycolumn up to date */
```

**Both** `yyline` and `yycolumn` start at **0**, so `getLineNumber()` returns
`yyline + 1` and `getColumnNumber()` returns `yycolumn + 1` in order to report
positions the way a human counts (line 1, column 1 is the first character of the
file). Without the `+ 1` an error on the very first line is reported as
"line 0, column 0".

The values always describe the token that was recognised last, which is why the
driver prints them right after `nextToken()` has returned. The same is true for
`yytext()`, which is why `attributeOf()` can show `name = water2` for an
identifier.

---

## 10. Lexical errors

`LexicalError` is a `RuntimeException` stored as a nested class of the scanner,
so it carries the position and the offending text:

```java
throw new LexicalError(yyline, yycolumn, yytext());
```

```
Lexical error at line 18, column 0: illegal character '@'
```

`Main` catches it, prints the message and stops scanning, because after a
lexical error the token stream can no longer be trusted.

---

## 11. Using the scanner together with CUP

The token codes currently live in `UgaliLexer`, which is convenient for a
stand-alone test driver. To plug the scanner into a CUP parser:

1. Delete the `public static final int ... = n;` block from the class code.
2. Add `%cup` (and `%cupstream`) to the options.
3. Change `%type int` to `%type java_cup.runtime.Symbol` and add `%cup` and
   `%cupstream`.
4. Replace every `return X;` with

   ```java
   return new Symbol(X, yyline + 1, yycolumn + 1);
   ```

   and for the integer literal

   ```java
   return new Symbol(NUMBER, yyline + 1, yycolumn + 1,
                     Integer.valueOf(intValue));
   ```

   The third argument of `Symbol` is the left/right production position used
   for error messages, the fourth one is the value (`value(int)`).
5. CUP's generated `sym` class then provides the constants; the numbers used by
   `%cup` come from the grammar, not from this file.

---

## 12. One-command rebuild

```bash
cd ~/Documents/3.2/compiler && \
jflex -d generated UgaliLexer.flex && \
javac -d classes generated/UgaliLexer.java Main.java && \
java -cp classes lexer.Main samples/partf_valid.upl
```

Same thing without a JDK:

```bash
cd ~/Documents/3.2/compiler && \
jflex -d generated UgaliLexer.flex && \
java -jar ecj.jar -nowarn -1.8 -d classes generated/UgaliLexer.java Main.java && \
java -cp classes lexer.Main samples/partf_valid.upl
```

---

## 13. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `This seems not to be a lexical specification` | the second `%%` is missing | add it after the options |
| `Cannot resolve type` / class not found after `javac` | `package lexer;` is after the first `%%` | move it before the first `%%` and compile the generated file with `-d` |
| comment text appears as tokens | `%state COMMENT` is inclusive | use `%xstate COMMENT` |
| error reported as "line 0, column 0" | `yyline`/`yycolumn` start at 0 | return `yyline + 1`, `yycolumn + 1` |
| every token is an illegal character | the `.` rule is not the last rule | move it to the end |
| `error: unmappable character for encoding ASCII` | non ASCII source | add `-encoding UTF-8` to `javac` |
| `NumberFormatException` in `Integer.parseInt` | integer literal too large | the number does not fit in a Java `int` |
| `NoClassDefFoundError: java_cup/runtime/Symbol` | CUP missing | add `java-cup.jar` to the class path |