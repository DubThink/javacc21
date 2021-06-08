[#ftl strict_vars=true]
[#--
/* Copyright (c) 2021 Jonathan Revusky, revusky@javacc.com
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *     * Redistributions of source code must retain the above copyright notices,
 *       this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name Jonathan Revusky, Sun Microsystems, Inc.
 *       nor the names of any contributors may be used to endorse 
 *       or promote products derived from this software without specific prior written 
 *       permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 */
 --]

 [#--
    This template handles the generation of a class that is a holder
    for all the static data that represents an NFA state machine
 --]

[#var NFA_RANGE_THRESHOLD = 16]
[#var MAX_INT=2147483647]
[#var multipleLexicalStates = grammar.lexerData.lexicalStates.size()>1]
[#var TT = "TokenType."]

 /* Generated by: ${generated_by}. ${filename} */
 
[#if grammar.parserPackage?has_content]
    package ${grammar.parserPackage};
  [#if !grammar.legacyAPI]    
    import static ${grammar.parserPackage}.${grammar.constantsClassName}.TokenType.*;
    [#set TT=""]
  [/#if]
[/#if]
import java.util.Arrays;
import java.util.BitSet;
[#if multipleLexicalStates]
  import java.util.EnumMap;
[/#if]

/**
 * Holder class for the data used by ${grammar.lexerClassName}
 * to do the NFA thang
 */
class ${grammar.nfaDataClassName} implements ${grammar.constantsClassName} {

  // The functional interface that represents 
  // the acceptance method of an NFA state
  static interface NfaFunction {
    TokenType accept(int ch, BitSet bs);
  }

 [#if multipleLexicalStates]
  // A lookup of the NFA function tables for the respective lexical states.
  private static final EnumMap<LexicalState,NfaFunction[]> functionTableMap = new EnumMap<>(LexicalState.class);
 [#else]
  [#-- We don't need the above lookup if there is only one lexical state.--]
   static private NfaFunction[] nfaFunctions;
 [/#if]


  // This data holder class is never instantiated
  private ${grammar.nfaDataClassName}() {}

  /**
   * @param the lexical state
   * @return the table of function pointers that implement the lexical state
   */
  static final NfaFunction[] getFunctionTableMap(LexicalState lexicalState) {
    [#if multipleLexicalStates]
      return functionTableMap.get(lexicalState);
    [#else]
     // We only have one lexical state in this case, so we return that!
      return nfaFunctions;
    [/#if]
  }
 
  // Initialize the various NFA method tables
  static {
    [#list grammar.lexerData.lexicalStates as lexicalState]
      NFA_FUNCTIONS_${lexicalState.name}_init();
    [/#list]
  }

  // Just use the canned binary search to check whether the char
  // is in one of the intervals
  private static final boolean checkIntervals(int[] ranges, int ch) {
    int temp;
    return (temp = Arrays.binarySearch(ranges, ch)) >=0 || temp%2 == 0;
  }

 [#list grammar.lexerData.lexicalStates as lexicalState]
   [@GenerateStateCode lexicalState/]
 [/#list]  
}

[#--
  Generate all the NFA transition code
  for the given lexical state
--]
[#macro GenerateStateCode lexicalState]
  [#list lexicalState.allNfaStates as nfaState]
    [#if nfaState.moveCodeNeeded]
      [#if nfaState.moveRanges.size() >= NFA_RANGE_THRESHOLD]
        [@GenerateMoveArray nfaState/]
      [/#if]
      [@GenerateNfaStateMethod nfaState/]
    [/#if]
  [/#list]

  static private void NFA_FUNCTIONS_${lexicalState.name}_init() {
    NfaFunction[] functions = new NfaFunction[${lexicalState.allNfaStates.size()}];
    [#list lexicalState.allNfaStates as state]
      [#if state.moveCodeNeeded]
          functions[${state.index}] = ${grammar.nfaDataClassName}::${state.methodName};
      [/#if]
    [/#list]
    [#if multipleLexicalStates]
      functionTableMap.put(LexicalState.${lexicalState.name}, functions);
    [#else]
      nfaFunctions = functions;
    [/#if]
  }
[/#macro]

[#--
   Generate the array representing the characters
   that this NfaState "accepts".
   This corresponds to the moveRanges field in 
   com.javacc.core.NfaState
--]
[#macro GenerateMoveArray nfaState]
  [#var moveRanges = nfaState.moveRanges]
  [#var arrayName = nfaState.movesArrayName]
    static private int[] ${arrayName} = ${arrayName}_init();

    static private int[] ${arrayName}_init() {
        int[] result = new int[${nfaState.moveRanges.size()}];
        [#list nfaState.moveRanges as char]
          result[${char_index}] = ${grammar.utils.displayChar(char)};
        [/#list]
        return result;
    }
[/#macro] 

[#--
   Generate the method that represents the transition
   (or transitions if this is a CompositeStateSet)
   that correspond to an instanceof com.javacc.core.NfaState
--]
[#macro GenerateNfaStateMethod nfaState]  
  [#if !nfaState.composite]
     [@GenerateSimpleNfaMethod nfaState/]
  [#else]
    static TokenType ${nfaState.methodName}(int ch, BitSet nextStates) {
      TokenType type = null;
    [#var states = nfaState.orderedStates]
    [#list states as state]
      [#var jumpOut = state.isNonOverlapping(states.subList(state_index+1, states?size))]
      [@GenerateStateMove state jumpOut /]
      [#if !jumpOut && states[state_index+1].isNonOverlapping(states.subList(0, state_index+1))]
         else
      [/#if]
    [/#list]
      return type;
    }
  [/#if]
[/#macro]

[#--
  Generates the code for an NFA state transition
  within a composite state. The jumpOut parameter says 
  whether we can just jump out of the method. 
  (This is based on whether any of the moveRanges
  for later states overlap. If not, we can jump out.)
--]
[#macro GenerateStateMove nfaState jumpOut]
  [#var nextState = nfaState.nextState.canonicalState]
  [#var type = nfaState.nextState.type]
    if ([@NfaStateCondition nfaState /]) {
      [#if nextState.index >= 0]
         nextStates.set(${nextState.index});
      [/#if]
   [#if jumpOut]
     return
     [#if type?is_null]
        null;
     [#else]
        ${TT}${type.label};
     [/#if]
   [#elseif type??]
        type = ${TT}${type.label};
   [/#if]
   }
[/#macro]

[#-- 
  Generate the code for a simple (non-composite) NFA state
--]
[#macro GenerateSimpleNfaMethod nfaState]
  static TokenType ${nfaState.methodName}(int ch, BitSet nextStates) {
    [#var nextState = nfaState.nextState.canonicalState]
    [#var type = nfaState.nextState.type]
      if ([@NfaStateCondition nfaState /]) {
        [#if nextState.index >= 0]
          nextStates.set(${nextState.index});
        [/#if]
      [#if type??]
        return ${TT}${type.label};
      [/#if]
    }
    return null;
  }
[/#macro]

[#--
Generate the condition part of the NFA state transition
If the size of the moveRanges vector is greater than NFA_RANGE_THRESHOLD
it uses the canned binary search routine. For the smaller moveRanges
it just generates the inline conditional expression
--]
[#macro NfaStateCondition nfaState]
    [#if nfaState.moveRanges?size < NFA_RANGE_THRESHOLD]
      [@RangesCondition nfaState.moveRanges /]
    [#elseif nfaState.hasAsciiMoves && nfaState.hasNonAsciiMoves]
      ([@RangesCondition nfaState.asciiMoveRanges/])
      || (ch >=128 && checkIntervals(${nfaState.movesArrayName}, ch))
    [#else]
      checkIntervals(${nfaState.movesArrayName}, ch)
    [/#if]
[/#macro]

[#-- 
This is a recursive macro that generates the code corresponding
to the accepting condition for an NFA state. It is used
if NFA state's moveRanges array is smaller than NFA_RANGE_THRESHOLD
(which is set to 16 for now)
--]
[#macro RangesCondition moveRanges]
    [#var left = moveRanges[0], right = moveRanges[1]]
    [#var displayLeft = grammar.utils.displayChar(left), displayRight = grammar.utils.displayChar(right)]
    [#var singleChar = left == right]
    [#if moveRanges?size==2]
       [#if singleChar]
          ch == ${displayLeft}
       [#elseif left +1 == right]
          ch == ${displayLeft} || ch == ${displayRight}
       [#elseif left > 0]
          ch >= ${displayLeft} 
          [#if right < 1114111]
             && ch <= ${displayRight}
          [/#if]
       [#else]
           ch <= ${displayRight}
       [/#if]
    [#else]
       ([@RangesCondition moveRanges[0..1]/])||([@RangesCondition moveRanges[2..moveRanges?size-1]/])
    [/#if]
[/#macro]
