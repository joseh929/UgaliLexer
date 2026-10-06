/* ===================================================================
 * UgaliLexer.flex
 * -------------------------------------------------------------------
 * Lexical Analyzer (Scanner) for the Ugali Preparation Language (UPL)
 * Generator : JFlex 1.7.x
 *
 * Structure of this specification file:
 *
 *      package / import statements     <- user code region
 *      %%
 *      JFlex options and declarations  <- %class, %type, %{...%}, macros
 *      %%
 *      lexical rules                    <- the patterns and their actions
 *
 * Contains:
 *   - 17 reserved words (keywords)
 *   - Integer literals   (NUMBER)    with their numeric value
 *   - Identifiers        (IDENTIFIER)
 *   - Separators         (SEMICOLON)
 *   - White space        (ignored)
 *   - Single line comments    // ... up to end of line
 *   - Multi line comments     /* ... * /   using the lexical state COMMENT
 *   - Position tracking  (%line and %column)
 *   - Meaningful lexical error reporting with line and column numbers
 * =================================================================== */

package lexer;

import java.io.Reader;

/* ================================================================== */
/*  Everything between the first %% and the second %% is read by JFlex  */
/*  as options, macro definitions and class code.                     */
/* ================================================================== */

%%

%public
%class UgaliLexer
%type int
%function nextToken
%line      /* keeps yyline   up to date                     */
%column    /* keeps yycolumn up to date                     */
%unicode

/* ------------------------------------------------------------------ */
/*  Lexical states                                                     */
/*    YYINITIAL : normal scanning of UPL tokens                       */
/*    COMMENT   : inside a multi line comment                         */
/* ------------------------------------------------------------------ */
%xstate COMMENT

%{
    /* =============================================================
     *  Class code: copied verbatim into the generated scanner.
     * ============================================================= */

    /* -------------------------------------------------------------
     *  Token types.
     *  JFlex returns these codes from nextToken(). When the scanner
     *  is used together with CUP the same codes are generated in the
     *  sym class of the grammar instead.
     * ------------------------------------------------------------- */
    public static final int PREPARE     = 1;
    public static final int INGREDIENTS = 2;
    public static final int BOIL        = 3;
    public static final int WATER       = 4;
    public static final int ADD         = 5;
    public static final int FLOUR       = 6;
    public static final int STIR        = 7;
    public static final int PRESS       = 8;
    public static final int TURN        = 9;
    public static final int COOK        = 10;
    public static final int CHECK       = 11;
    public static final int CONSISTENCY = 12;
    public static final int SHAPE       = 13;
    public static final int SERVE       = 14;
    public static final int UGALI       = 15;
    public static final int CUPS        = 16;
    public static final int MINUTES     = 17;
    public static final int NUMBER      = 18;
    public static final int IDENTIFIER  = 19;
    public static final int SEMICOLON   = 20;

    /**
     * Thrown when the scanner meets a character that is not part of the
     * UPL alphabet. It remembers the exact line and column of the
     * offending text so that the compiler driver can report it.
     */
    public static class LexicalError extends RuntimeException {
        private static final long serialVersionUID = 1L;

        private final int line;
        private final int column;
        private final String text;

        public LexicalError(int line, int column, String text) {
            super(buildMessage(line, column, text));
            this.line   = line;
            this.column = column;
            this.text   = text;
        }

        /**
         * Builds the message. A single character is reported as
         * "illegal character '@'", a longer piece of text (for example an
         * unterminated comment) is reported as it is.
         */
        private static String buildMessage(int line, int column, String text) {
            String detail = (text != null && text.length() == 1)
                          ? "illegal character '" + escape(text) + "'"
                          : String.valueOf(text);
            return "Lexical error at line " + line
                 + ", column " + column
                 + ": " + detail;
        }

        /** Makes control characters visible inside the error message. */
        private static String escape(String s) {
            StringBuilder sb = new StringBuilder();
            for (int i = 0; i < s.length(); i++) {
                char c = s.charAt(i);
                if      (c == '\n') sb.append("\\n");
                else if (c == '\r') sb.append("\\r");
                else if (c == '\t') sb.append("\\t");
                else                sb.append(c);
            }
            return sb.toString();
        }

        public int    getLine()   { return line;   }
        public int    getColumn() { return column; }
        public String getText()   { return text;   }
    }

    /** Semantic value of the token that was recognised last (NUMBER). */
    public int intValue;

    /** Readable name of every token type, indexed by the token code. */
    public static final String[] TOKEN_NAMES = {
        "EOF",         /*  0 */
        "PREPARE",     /*  1 */
        "INGREDIENTS", /*  2 */
        "BOIL",        /*  3 */
        "WATER",       /*  4 */
        "ADD",         /*  5 */
        "FLOUR",       /*  6 */
        "STIR",        /*  7 */
        "PRESS",       /*  8 */
        "TURN",        /*  9 */
        "COOK",        /* 10 */
        "CHECK",       /* 11 */
        "CONSISTENCY", /* 12 */
        "SHAPE",       /* 13 */
        "SERVE",       /* 14 */
        "UGALI",       /* 15 */
        "CUPS",        /* 16 */
        "MINUTES",     /* 17 */
        "NUMBER",      /* 18 */
        "IDENTIFIER",  /* 19 */
        "SEMICOLON"    /* 20 */
    };

    /** Number of multi line comments that were scanned successfully. */
    private int blockCommentCount = 0;

    public int getBlockCommentCount() { return blockCommentCount; }

    /**
     * Maps a token code onto its readable name. YYEOF has the value -1 in
     * JFlex, so it cannot be stored in TOKEN_NAMES and is dealt with here.
     */
    public static String tokenName(int token) {
        if (token == YYEOF) {
            return "EOF";
        }
        if (token >= 0 && token < TOKEN_NAMES.length) {
            return TOKEN_NAMES[token];
        }
        return "UNKNOWN(" + token + ")";
    }

    /* -------------------------------------------------------------
     *  Accessors for the position of the token that was recognised
     *  last. JFlex keeps them in the private fields yyline and
     *  yycolumn because of the %line and %column directives.
     *
     *  Both fields start at 0, so one is added to each of them in
     *  order to report positions the way a human counts: the first
     *  character of a line is line 1, column 1.
     * ------------------------------------------------------------- */
    public int getLineNumber()   { return yyline + 1;   }
    public int getColumnNumber() { return yycolumn + 1; }
%}

%eofval{
    return YYEOF;
%eofval}

%%

/* ================================================================== */
/*  Everything below this line are the lexical rules of the scanner.   */
/* ================================================================== */

/* ================================================================== */
/*  1. RESERVED WORDS                                                  */
/*     JFlex applies the longest match rule, therefore "minutes" is a   */
/*     keyword and MINUTESS would be an IDENTIFIER.                    */
/*     Keywords are matched case sensitively.                          */
/* ================================================================== */

"prepare"        { return PREPARE;      }
"ingredients"    { return INGREDIENTS;  }
"boil"           { return BOIL;         }
"water"          { return WATER;        }
"add"            { return ADD;          }
"flour"          { return FLOUR;        }
"stir"           { return STIR;         }
"press"          { return PRESS;        }
"turn"           { return TURN;         }
"cook"           { return COOK;         }
"check"          { return CHECK;        }
"consistency"    { return CONSISTENCY;  }
"shape"          { return SHAPE;        }
"serve"          { return SERVE;        }
"ugali"          { return UGALI;        }
"cups"           { return CUPS;         }
"minutes"        { return MINUTES;      }

/* ================================================================== */
/*  2. SEPARATORS                                                       */
/* ================================================================== */

";"              { return SEMICOLON;    }

/* ================================================================== */
/*  3. INTEGER LITERALS                                                 */
/*     One or more digits. The numeric value is stored in intValue so  */
/*     that the parser receives the attribute of the token (part d).    */
/* ================================================================== */

[0-9]+           { intValue = Integer.parseInt(yytext());
                   return NUMBER;       }

/* ================================================================== */
/*  4. IDENTIFIERS                                                      */
/*     A letter followed by letters, digits or underscores.            */
/*     Thanks to the longest match rule "water2" is one IDENTIFIER    */
/*     and is not split into WATER and NUMBER.                        */
/* ================================================================== */

[A-Za-z][A-Za-z0-9_]*  { return IDENTIFIER; }

/* ================================================================== */
/*  5. COMMENTS AND WHITE SPACE                                         */
/* ================================================================== */

/* Single line comment: everything up to (but not including) the newline */
"//" [^\r\n]*    { /* ignored by the scanner */ }

/* Opening delimiter of a multi line comment: switch the lexical state */
"/*"             { yybegin(COMMENT);    }

/* White space, new lines and tab characters */
[ \t\r\n]+       { /* ignored by the scanner */ }

/* ================================================================== */
/*  6. THE MULTI LINE COMMENT STATE                                     */
/*     Inside COMMENT the scanner only looks for the closing delimiter, */
/*     so the text of the comment is never turned into tokens.          */
/* ================================================================== */

<COMMENT>{
    "*/"        { yybegin(YYINITIAL); blockCommentCount++; }
    [^*]        { /* any character inside the comment   */ }
    "*"         { /* a lone star that does not close it */ }

    /* Reaching the end of file inside a comment is a lexical error. */
    <<EOF>>     { throw new LexicalError(yyline + 1, yycolumn + 1,
                              "unterminated comment, the closing */ is missing"); }
}

/* ================================================================== */
/*  7. ERROR HANDLING                                                   */
/*     Every character that matches none of the rules above is illegal. */
/*     It is reported together with its exact line and column number.   */
/*     This rule must be the LAST rule of the YYINITIAL state.          */
/* ================================================================== */

.   { throw new LexicalError(yyline + 1, yycolumn + 1, yytext()); }