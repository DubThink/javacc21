/* Generated by: ${generated_by}. ${filename} */
[#if grammar.parserPackage?has_content]
   package ${grammar.parserPackage};
[/#if]

/**
 * This exception is thrown when parse errors are encountered.
 * You can explicitly create objects of this exception type by
 * calling the method generateParseException in the generated
 * parser.
 *
 * You can modify this class to customize your error reporting
 * mechanisms so long as you retain the public fields.
 */

@SuppressWarnings("serial")
public class ParseException extends Exception {

  public ParseException() {
    super();
  }

  /** Constructor with message. */
  public ParseException(String message) {
    super(message);
  }
  
  public ParseException(Token token) {
      this.currentToken = token;
  }
  
  public String getMessage() {
      if (currentToken == null) {
          return super.getMessage();
      }
      return "Encountered an error on (or somewhere around) line "
                + currentToken.getBeginLine() 
                + ", column " + currentToken.getBeginColumn() 
                + " of " + currentToken.getInputSource();
  }
  
  private Token currentToken;

   static public String addEscapes(String str) {
      StringBuilder retval = new StringBuilder();
      char ch;
      for (int i = 0; i < str.length(); i++) {
        switch (str.charAt(i))
        {
           case 0 :
              continue;
           case '\b':
              retval.append("\\b");
              continue;
           case '\t':
              retval.append("\\t");
              continue;
           case '\n':
              retval.append("\\n");
              continue;
           case '\f':
              retval.append("\\f");
              continue;
           case '\r':
              retval.append("\\r");
              continue;
           case '\"':
              retval.append("\\\"");
              continue;
           case '\'':
              retval.append("\\\'");
              continue;
           case '\\':
              retval.append("\\\\");
              continue;
           default:
              if ((ch = str.charAt(i)) < 0x20 || ch > 0x7e) {
                 String s = "0000" + java.lang.Integer.toString(ch, 16);
                 retval.append("\\u" + s.substring(s.length() - 4, s.length()));
              } else {
                 retval.append(ch);
              }
              continue;
        }
      }
      return retval.toString();
   }
  
}
