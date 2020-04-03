/* Generated by: ${generated_by}. ${filename} */
[#if grammar.parserPackage?has_content]
package ${grammar.parserPackage};
[/#if]
import java.util.*;
[#if grammar.nodePackage?has_content && grammar.nodePackage != grammar.parserPackage]
import ${grammar.nodePackage}.*;
[/#if]

[#if grammar.options.freemarkerNodes]
import freemarker.template.*;
[/#if]

/**
 * Describes the input token stream.
 */
 
 [#var extendsNode = ""]
 
 [#if grammar.options.treeBuildingEnabled]
    [#set extendsNode =", Node"]
 [/#if]
 
public class Token implements ${grammar.constantsClassName} ${extendsNode} {

[#if grammar.options.faultTolerant]

   // The token does not correspond to actual characters in the input.
   // It was inserted to (tolerantly) complete some grammatical production.
   boolean virtual;
   
   // The token was not consumed legitimately by any grammatical 
   // production.
   boolean ignored;
   
   public void setVirtual(boolean virtual) {this.virtual = virtual;}
   
   public boolean isDirty() {return this.virtual || invalidToken != null || this.ignored;}
   
   // The lexically invalid input that precedes this token (if any)
   InvalidToken invalidToken;
   
   // The unparsed tokens that precede this token (if any)
   
   List<Token> precedingUnparsedTokens;
   
   void addUnparsedToken(Token tok) {
      if (precedingUnparsedTokens == null) precedingUnparsedTokens = new ArrayList<Token>();
      precedingUnparsedTokens.add(tok);
   }
   

[/#if]

    private String inputSource = "";

    /**
     * An integer that describes the kind of this token.  This numbering
     * system is determined by JavaCCParser, and a table of these numbers is
     * stored in the file ...Constants.java.
     */
    int kind;

    /**
     * beginLine and beginColumn describe the position of the first character
     * of this token; endLine and endColumn describe the position of the
     * last character of this token.
     */
    int beginLine, beginColumn, endLine, endColumn;

    /**
     * The string image of the token.
     */
    String image;

    /**
     * A reference to the next regular (non-special) token from the input
     * stream.  If this is the last token from the input stream, or if the
     * token manager has not read tokens beyond this one, this field is
     * set to null.  This is true only if this token is also a regular
     * token.  Otherwise, see below for a description of the contents of
     * this field.
     */
    Token next;

    /**
     * This field is used to access special tokens that occur prior to this
     * token, but after the immediately preceding regular (non-special) token.
     * If there are no such special tokens, this field is set to null.
     * When there are more than one such special token, this field refers
     * to the last of these special tokens, which in turn refers to the next
     * previous special token through its specialToken field, and so on
     * until the first special token (whose specialToken field is null).
     * The next fields of special tokens refer to other special tokens that
     * immediately follow it (without an intervening regular token).  If there
     * is no such token, this field is null.
     */
    Token specialToken;
    
    boolean unparsed;

    public Token() {}

    /**
     * Constructs a new token for the specified Image.
     */
    public Token(int kind) {
       this(kind, null);
    }

    /**
     * Constructs a new token for the specified Image and Kind.
     */
    public Token(int kind, String image) {
        this.kind = kind;
        this.image = image;
    }
    
    public int getId() {
        return kind;
    }

    public boolean isUnparsed() {
        return unparsed;
    }
    
    public void setUnparsed(boolean unparsed) {
        this.unparsed = unparsed;
    }
    
    public void clearChildren() {}
    
    public String getNormalizedText() {
[#if grammar.options.faultTolerant]
        if (virtual) {
             return "Virtual Token";
        }
        if (invalidToken != null) {
            return "invalid input: " + invalidToken.image + " followed by: " + image;
        }
[/#if]    
        return image;
    }
    
    public String getRawText() {
        return image;
    }
    
    public String toString() {
        return getNormalizedText();
    }
    
    public static Token newToken(int ofKind, String image) {
       [#if grammar.options.treeBuildingEnabled]
           [#var packagePrefix = ""]
           [#if grammar.nodePackage?has_content][#set packagePrefix=grammar.nodePackage+"."][/#if]
           switch(ofKind) {
//              case -1 : return new InvalidToken(image);
           [#list grammar.orderedNamedTokens as re]
            [#if re.generatedClassName != "Token" && !re.private]
              case ${re.label} : return new ${re.generatedClassName}(ofKind, image);
            [/#if]
           [/#list]
           }
       [/#if]
       return new Token(ofKind, image); 
    }

    public void setInputSource(String inputSource) {
        this.inputSource = inputSource;
    }
    
    public String getInputSource() {
        return inputSource;
    }
    
    
    public void setBeginColumn(int beginColumn) {
        this.beginColumn = beginColumn;
    }	
    
    public void setEndColumn(int endColumn) {
        this.endColumn = endColumn;
    }	
    
    public void setBeginLine(int beginLine) {
        this.beginLine = beginLine;
    }	
    
    public void setEndLine(int endLine) {
        this.endLine = endLine;
    }	
    
    public int getBeginLine() {
        return beginLine;
    }
    
    public int getBeginColumn() {
        return beginColumn;
    }
    
    public int getEndLine() {
        return endLine;
    }
    
    public int getEndColumn() {
        return endColumn;
    }
[#if !grammar.options.treeBuildingEnabled]    
    public String getLocation() {
         return "line " + getBeginLine() + ", column " + getBeginColumn() + " of " + getInputSource();
     }
[/#if]     
    
[#if grammar.options.treeBuildingEnabled]
    
    private Node parent;
    private Map<String,Object> attributes; 

    public void setChild(int i, Node n) {
        throw new UnsupportedOperationException();
    }

    public void addChild(Node n) {
        throw new UnsupportedOperationException();
    }
    
    public void addChild(int i, Node n) {
        throw new UnsupportedOperationException();
    }
    
    public Node removeChild(int i) {
        throw new UnsupportedOperationException();
    }
    
    public boolean removeChild(Node n) {
        return false;
    }
    
    public int indexOf(Node n) {
        return -1;
    }

    public Node getParent() {
        return parent;
    }

    public void setParent(Node parent) {
        this.parent = parent;
    }
    
    public int getChildCount() {
        return 0;
    }
    
    public Node getChild(int i) {
        return null;
    }
    
    public List<Node> children() {
        return Collections.emptyList();
    }
    
    

    public void open() {}

    public void close() {}
    
    
    public Object getAttribute(String name) {
        return attributes == null ? null : attributes.get(name); 
    }
     
    public void setAttribute(String name, Object value) {
        if (attributes == null) {
            attributes = new HashMap<String, Object>();
        }
        attributes.put(name, value);
    }
     
    public boolean hasAttribute(String name) {
        return attributes == null ? false : attributes.containsKey(name);
    }
     
    public Set<String> getAttributeNames() {
        if (attributes == null) return Collections.emptySet();
        return attributes.keySet();
    }

   [#if grammar.options.freemarkerNodes]
    public TemplateNodeModel getParentNode() {
        return parent;
    }
  
    public TemplateSequenceModel getChildNodes() {
        return null;
    }
  
    public String getNodeName() {
        return ${grammar.constantsClassName}.tokenImage[kind];
    }
  
    public String getNodeType() {
        return getClass().getSimpleName();
    }
  
    public String getNodeNamespace() {
        return null;
    }
  
    public String getAsString() {
        return getNormalizedText();
    }
[/#if]

 [#if grammar.options.visitor]
    [#var VISITOR_THROWS = ""]
    [#if grammar.options.visitorException?has_content]
       [#set VISITOR_THROWS = "throws " + grammar.options.visitorException + " "]
    [/#if]
    [#var VISITOR_CLASS = grammar.parserClassName + "Visitor"]
    [#var VISITOR_DATA_TYPE = grammar.options.visitorDataType]
    [#var VISITOR_RETURN_TYPE = grammar.options.visitorReturnType]
    [#if !VISITOR_DATA_TYPE?has_content][#set VISITOR_DATA_TYPE="Object"][/#if]
    [#if !VISITOR_RETURN_TYPE?has_content][#set VISITOR_RETURN_TYPE="Object"][/#if]
    /** Accept the visitor. **/
    public ${VISITOR_RETURN_TYPE} jjtAccept(${VISITOR_CLASS} visitor, ${VISITOR_DATA_TYPE} data) ${VISITOR_THROWS}{
      [#if VISITOR_RETURN_TYPE != "void"]
        return visitor.visit(this, data);
      [/#if]
    }
           
    /** Accept the visitor. **/
    public Object childrenAccept(${VISITOR_CLASS} visitor, ${VISITOR_DATA_TYPE} data) ${VISITOR_THROWS}{
        return data;
    }
[/#if]   
        
                
 [/#if]

}
