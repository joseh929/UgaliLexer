package lexer;

import java.io.IOException;
import java.io.StringReader;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Main.java
 * -------------------------------------------------------------------
 * Test driver for the Ugali Preparation Language (UPL) lexical analyzer.
 *
 * Usage
 * -----
 *      java lexer.Main <file.upl>
 *      java lexer.Main samples/partf_valid.upl
 *
 * What it does
 * ------------
 *  1. Reads the whole source file into a String.
 *  2. Feeds that String to a fresh scanner through a StringReader, so
 *     that several files can be scanned one after another in the same
 *     run (the scanner holds state such as the current lexical state).
 *  3. Prints every token in a table showing its index, its line, its
 *     column, its token type and its attribute value.
 *  4. Catches UgaliLexer.LexicalError and prints the exact position of
 *     the illegal character, for example
 *         Lexical error at line 12, column 1: illegal character '@'
 */
public class Main {

    /** Maximum number of tokens that are printed. */
    private static final int MAX_TOKENS = 200;

    public static void main(String[] args) {

        if (args.length < 1) {
            System.err.println("Usage : java lexer.Main <file.upl>");
            System.err.println("Example: java lexer.Main samples/partf_valid.upl");
            System.exit(1);
            return;
        }

        String path = args[0];
        String source;

        try {
            source = new String(Files.readAllBytes(Paths.get(path)),
                                 StandardCharsets.UTF_8);
        } catch (IOException e) {
            System.err.println("Could not read file '" + path + "': " + e.getMessage());
            System.exit(1);
            return;
        }

        System.out.println("================================================================");
        System.out.println(" UPL Lexical Analyzer");
        System.out.println(" Source file : " + path);
        System.out.println(" Length      : " + source.length() + " characters");
        System.out.println("================================================================");
        System.out.println();
        System.out.printf("%5s | %5s | %5s | %-12s | %s%n",
                          "TOKEN", "LINE", "COLUMN", "TYPE", "ATTRIBUTE");
        System.out.println("----------------------------------------------------------------");

        /* The scanner reads from a Reader, so a StringReader can be used. */
        UgaliLexer scanner = new UgaliLexer(new StringReader(source));

        int token;
        int index = 0;
        int errors = 0;

        try {
            while ((token = scanner.nextToken()) != UgaliLexer.YYEOF) {

                index++;

                if (index > MAX_TOKENS) {
                    System.out.println("... more than " + MAX_TOKENS
                                       + " tokens, output truncated ...");
                    break;
                }

                System.out.printf("%5d | %5d | %5d | %-12s | %s%n",
                                  index,
                                  scanner.getLineNumber(),
                                  scanner.getColumnNumber(),
                                  tokenName(token),
                                  attributeOf(scanner, token));
            }

        } catch (UgaliLexer.LexicalError e) {
            reportLexicalError(e);
            errors++;
        } catch (IOException e) {
            /* Should not happen when the input comes from a String. */
            System.out.println();
            System.out.println("I/O error while scanning: " + e.getMessage());
            errors++;
        }

        System.out.println();
        System.out.println("----------------------------------------------------------------");
        System.out.println("SUMMARY");
        System.out.println("  Tokens recognised : " + index);
        System.out.println("  Lexical errors    : " + errors);
        System.out.println("  Block comments    : " + scanner.getBlockCommentCount());

        if (errors == 0) {
            System.out.println("  RESULT            : PASS - the input is lexically valid");
        } else {
            System.out.println("  RESULT            : FAIL - the input is not lexically valid");
        }
        System.out.println("================================================================");

        /* Exit code 0 = valid input, 1 = lexical error. Useful in scripts. */
        System.exit(errors == 0 ? 0 : 1);
    }

    /** Prints a lexical error in a readable, exam friendly form. */
    private static void reportLexicalError(UgaliLexer.LexicalError e) {
        System.out.println();
        System.out.println("----------------------------------------------------------------");
        System.out.println("SCANNING STOPPED BY A LEXICAL ERROR");
        System.out.println("  " + e.getMessage());
        System.out.println("  Bad text : '" + e.getText() + "'");
        System.out.println("  Line     : " + e.getLine());
        System.out.println("  Column   : " + e.getColumn());
    }

    /**
     * Returns the attribute (semantic value) of the token that has just
     * been recognised. Only an integer literal carries a number, the
     * value of an identifier is its spelling.
     */
    private static String attributeOf(UgaliLexer scanner, int token) {
        switch (token) {
            case UgaliLexer.NUMBER:
                return "value = " + scanner.intValue;
            case UgaliLexer.IDENTIFIER:
                return "name = " + scanner.yytext();
            default:
                return "-";
        }
    }

    /**
     * Maps a token code onto a readable name. The table itself lives in
     * UgaliLexer so that the scanner and the driver can never get out of
     * step.
     */
    public static String tokenName(int token) {
        return UgaliLexer.tokenName(token);
    }

    /**
     * Counts how many tokens of each kind occur in a source string.
     */
    public static Map<String, Integer> tokenFrequency(String source) {
        Map<String, Integer> frequency = new LinkedHashMap<String, Integer>();
        try {
            UgaliLexer scanner = new UgaliLexer(new StringReader(source));
            int token;
            while ((token = scanner.nextToken()) != UgaliLexer.YYEOF) {
                String name = tokenName(token);
                Integer old = frequency.get(name);
                frequency.put(name, old == null ? 1 : old + 1);
            }
        } catch (UgaliLexer.LexicalError e) {
            System.err.println("Cannot count tokens: " + e.getMessage());
        } catch (IOException e) {
            System.err.println("Cannot count tokens: " + e.getMessage());
        }
        return frequency;
    }
}