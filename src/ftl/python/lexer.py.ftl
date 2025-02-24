[#ftl strict_vars=true]
[#--
  Copyright (C) 2008-2020 Jonathan Revusky, revusky@javacc.com
  Copyright (C) 2021 Vinay Sajip, vinay_sajip@yahoo.co.uk
  All rights reserved.

  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions are met:

      * Redistributions of source code must retain the above copyright
        notices, this list of conditions and the following disclaimer.
      * Redistributions in binary form must reproduce the above copyright
        notice, this list of conditions and the following disclaimer in
        the documentation and/or other materials provided with the
        distribution.
      * None of the names Jonathan Revusky, Vinay Sajip, Sun
        Microsystems, Inc. nor the names of any contributors may be
        used to endorse or promote products derived from this software
        without specific prior written permission.

  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
  THE POSSIBILITY OF SUCH DAMAGE.
--]
# Parser lexing package. Generated by ${generated_by}. Do not edit.
[#import "common_utils.inc.ftl" as CU]

import bisect
import logging

from .tokens import TokenType, LexicalState, InvalidToken, new_token
from .utils import FileLineMap, as_chr, _List, EMPTY_SET

# See if an accelerated BitSet is available.
try:
    from _bitset import BitSet
    _fast_bitset = True
except ImportError:
    from .utils import BitSet
    _fast_bitset = False

[#var NFA_RANGE_THRESHOLD = 16]
[#var MAX_INT=2147483647]
[#var lexerData=grammar.lexerData]
[#var multipleLexicalStates = lexerData.lexicalStates.size() > 1]
[#var TT = "TokenType."]

logger = logging.getLogger(__name__)

#
# Hack to allow token types to be referenced in snippets without
# qualifying
#
globals().update(TokenType.__members__)

# NFA code and data
[#if multipleLexicalStates]
# A mapping from lexical state to NFA functions for that state.
[#-- We only need the mapping if there is more than one lexical state.--]
function_table_map = {}
[/#if]

[#list lexerData.lexicalStates as lexicalState]
[@GenerateStateCode lexicalState/]
[/#list]

# Just use binary search to check whether the char is in one of the
# intervals
def check_intervals(ranges, ch):
    index = bisect.bisect_left(ranges, ch)
    n = len(ranges)
    if index < n:
        if index % 2 == 0:
            if index < (n - 1):
                return ranges[index] <= ch <= ranges[index + 1]
        elif index > 0:
            return ranges[index - 1] <= ch <= ranges[index]
    return False

[#--
  Generate all the NFA transition code
  for the given lexical state
--]
[#macro GenerateStateCode lexicalState]
[#list lexicalState.allNfaStates as nfaState]
[#if nfaState.moveRanges.size() >= NFA_RANGE_THRESHOLD]
[@GenerateMoveArray nfaState/]
[/#if]
[@GenerateNfaStateMethod nfaState/]
[/#list]

def NFA_FUNCTIONS_${lexicalState.name}_init():
[#--
    In theory this could be initialized as a normal list, but it's
    not clear if state.index is always the same as state_index

    Update: it is, see https://github.com/javacc21/javacc21/issues/72

    functions = [None] * ${lexicalState.allNfaStates.size()}
    [#list lexicalState.allNfaStates as state]
    functions[${state.index}] = ${state.methodName}
    [/#list]
--]
    functions = [
[#list lexicalState.allNfaStates as state]
        ${state.methodName}[#if state_has_next],[/#if]
[/#list]
    ]
[#if multipleLexicalStates]
    function_table_map[LexicalState.${lexicalState.name}] = functions
[#else]
    return functions
[/#if]

[#if multipleLexicalStates]
NFA_FUNCTIONS_${lexicalState.name}_init()
[#else]
nfa_functions = NFA_FUNCTIONS_${lexicalState.name}_init()
[/#if]

def get_function_table_map(lexical_state):
    [#if multipleLexicalStates]
    return function_table_map[lexical_state]
    [#else]
    # We only have one lexical state in this case, so we return that!
    return nfa_functions
    [/#if]

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
[#-- No need to create an array and populate one by one - just
     initialize normally

def ${arrayName}_init():
     it!
    result = [0] * ${nfaState.moveRanges.size()}
[#list nfaState.moveRanges as char]
    result[${char_index}] = ${grammar.utils.displayChar(char)}
    return result
${arrayName} = ${arrayName}_init()
[/#list--]
${arrayName} = [
[#list nfaState.moveRanges as char]
    ${grammar.utils.displayChar(char)}[#if char_has_next],[/#if]
[/#list]
]
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
def ${nfaState.methodName}(ch, next_states, valid_types):
    [#var states = nfaState.orderedStates]
    [#-- sometimes set in the code below --]
    type = None
    [#var useElif = false]
    [#list states as state]
      [#var isFirstOfGroup=true, isLastOfGroup=true]
      [#if state_index!=0]
         [#set isFirstOfGroup = !states[state_index-1].moveRanges.equals(state.moveRanges)]
      [/#if]
      [#if state_has_next]
         [#set isLastOfGroup = !states[state_index+1].moveRanges.equals(state.moveRanges)]
      [/#if]
      [@GenerateStateMove state isFirstOfGroup isLastOfGroup useElif /]
      [#if state_has_next && isLastOfGroup && !states[state_index+1].overlaps(states.subList(0, state_index+1))]
        [#set useElif = true]
      [#else]
        [#set useElif = false]
      [/#if]
    [/#list]
    return type

  [/#if]
[/#macro]

[#--
  Generates the code for an NFA state transition
  within a composite state. This code is a bit tricky
  because it consolidates more than one condition in
  a single conditional block. The jumpOut parameter says
  whether we can just jump out of the method.
  (This is based on whether any of the moveRanges
  for later states overlap. If not, we can jump out.)
--]
[#macro GenerateStateMove nfaState isFirstOfGroup isLastOfGroup useElif=false]
  [#var nextState = nfaState.nextState.canonicalState]
  [#var type = nfaState.nextState.type]
    [#if isFirstOfGroup]
    [#if useElif]elif[#else]if[/#if] [@NfaStateCondition nfaState /]:
    [/#if]
      [#if nextState.index >= 0]
        next_states.set(${nextState.index})
      [/#if]
   [#if isLastOfGroup]
      [#if type??]
        if ${TT}${type.label} in valid_types:
            type = ${TT}${type.label}
     [/#if]
   [/#if]
[/#macro]

[#--
  Generate the code for a simple (non-composite) NFA state
--]
[#macro GenerateSimpleNfaMethod nfaState]
def ${nfaState.methodName}(ch, next_states, valid_types):
[#var nextState = nfaState.nextState.canonicalState]
[#var type = nfaState.nextState.type]
    if [@NfaStateCondition nfaState /]:
        [#if nextState.index >= 0]
        next_states.set(${nextState.index})
        [/#if]
      [#if type??]
        if ${TT}${type.label} in valid_types:
            return ${TT}${type.label}
      [/#if]
    [#--return None--]

[/#macro]

[#--
Generate the condition part of the NFA state transition
If the size of the moveRanges vector is greater than NFA_RANGE_THRESHOLD
it uses the canned binary search routine. For the smaller moveRanges
it just generates the inline conditional expression
--]
[#macro NfaStateCondition nfaState]
    [#if nfaState.moveRanges?size < NFA_RANGE_THRESHOLD]
      [@RangesCondition nfaState.moveRanges /][#t]
    [#elseif nfaState.hasAsciiMoves && nfaState.hasNonAsciiMoves]
      ([@RangesCondition nfaState.asciiMoveRanges/]) or (ch >= chr(128) and check_intervals(${nfaState.movesArrayName}, ch))[#t]
    [#else]
      check_intervals(${nfaState.movesArrayName}, ch)[#t]
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
          ch == ${displayLeft}[#t]
       [#elseif left +1 == right]
          ch == ${displayLeft} or ch == ${displayRight}[#t]
       [#elseif left > 0]
          ch >= ${displayLeft}[#t]
          [#if right < 1114111]
 and ch <= ${displayRight} [#rt]
          [/#if]
       [#else]
           ch <= ${displayRight} [#t]
       [/#if]
    [#else]
       ([@RangesCondition moveRanges[0..1]/]) or ([@RangesCondition moveRanges[2..moveRanges?size-1]/])[#t]
    [/#if]
[/#macro]

# Compute the maximum size of state bitsets

[#if !multipleLexicalStates]
MAX_STATES = ${lexerData.lexicalStates.get(0).allNfaStates.size()}
[#else]
MAX_STATES = max(
[#list lexerData.lexicalStates as state]
    ${state.allNfaStates.size()}[#if state_has_next],[/#if]
[/#list]
)
[/#if]

# Lexer code and data

[#macro EnumSet varName tokenNames indent=0]
[#var is = ""?right_pad(indent)]
[#if tokenNames?size=0]
${is}self.${varName} = EMPTY_SET
[#else]
${is}self.${varName} = {
   [#list tokenNames as type]
${is}    TokenType.${type}[#if type_has_next],[/#if]
   [/#list]
${is}}
[/#if]
[/#macro]

[#list grammar.parserCodeImports as import]
   ${import}
[/#list]

[#if lexerData.hasLexicalStateTransitions]
# A mapping for lexical state transitions triggered by a certain token type (token type -> lexical state)
token_type_to_lexical_state_map = {}
[/#if]
[#var injector = grammar.injector]

[#-- #var lexerClassName = grammar.lexerClassName --]
[#var lexerClassName = "Lexer"]
class ${lexerClassName}:

    __slots__ = (
        'input_source',
        'parser',
        'next_states',
        'current_states',
        '_char_buf',
        'active_token_types',
        'pending_invalid_chars',
        'token_begin_line',
        'token_begin_column',
        'trace_enabled',
        'invalid_token',
        'previous_token',
        'regular_tokens',
        'unparsed_tokens',
        'skipped_tokens',
        'more_tokens',
        'lexical_state',
        'input_stream',
        # TODO get these from kexer injection logic
        'indentation',
        'indentation_stack',
        'bracket_nesting',
        'parentheses_nesting',
        'brace_nesting',
        '_dummy_start_token'
    )

    def __init__(self, input_source, stream=None, lex_state=LexicalState.${lexerData.lexicalStates[0].name}, line=1, column=1):
${grammar.utils.translateLexerInjections(injector, true)}
        self.input_source = input_source
[#if grammar.lexerUsesParser]
        self.parser = None
[/#if]
        self._dummy_start_token = InvalidToken(None, None)
        # The following two BitSets are used to store the current active
        # NFA states in the core tokenization loop
        self.next_states = BitSet(MAX_STATES)
        self.current_states = BitSet(MAX_STATES)

        # Holder for the pending characters we read from the input stream
        self._char_buf = []

        self.active_token_types = set(TokenType)
  [#if grammar.deactivatedTokens?size>0]
       [#list grammar.deactivatedTokens as token]
        self.active_token_types.remove(TokenType.${token})
       [/#list]
  [/#if]
[#--
        # Holder for invalid characters, i.e. that cannot be matched as part of a token
        self.pending_invalid_chars = [] --]

        # Just used to "bookmark" the starting location for a token
        # for when we put in the location info at the end.
        self.token_begin_line = -1
        self.token_begin_column = -1

        # Token types that are "regular" tokens that participate in parsing,
        # i.e. declared as TOKEN
        [@EnumSet "regular_tokens" lexerData.regularTokens.tokenNames 8 /]
        # Token types that do not participate in parsing, a.k.a. "special" tokens in legacy JavaCC,
        # i.e. declared as UNPARSED (or SPECIAL_TOKEN)
        [@EnumSet "unparsed_tokens" lexerData.unparsedTokens.tokenNames 8 /]
        [#-- Tokens that are skipped, i.e. SKIP --]
        [#-- @EnumSet "skipped_tokens" lexerData.skippedTokens.tokenNames 8 / --]
        # Tokens that correspond to a MORE, i.e. that are pending
        # additional input
        [@EnumSet "more_tokens" lexerData.moreTokens.tokenNames 8 /]
        self.trace_enabled = ${CU.bool(grammar.debugLexer)}
        self.invalid_token = None
        self.previous_token = None
        self.lexical_state = None
        self.input_stream = FileLineMap(input_source, stream, line, column)
        self.switch_to(lex_state)

    #
    # The public method for getting the next token.
    # Most of the work is done in the private method
    # _next_token, which invokes the NFA machinery
    #
    def get_next_token(self):
        while True:
            token = self._next_token()
            if not isinstance(token, InvalidToken):
                break

        if self.invalid_token:
            self.invalid_token.next_token = token
            token.previous_token = self.invalid_token
            it = self.invalid_token
            self.invalid_token = None
    [#if grammar.faultTolerant]
            it.is_unparsed = True
    [/#if]
            return it
[#if false]
     This code moved elsewhere because, for python indent/dedent handling,
     we need this token chaining to happen at an earlier point in the cycle.
     Everything seems okay, but all this token chaining is excessively intricate.
     I think there is a need for a general cleanup/simplification of all that.

        token.previous_token = self.previous_token
        if self.previous_token:
            self.previous_token.next_token = token
[/#if]
        self.previous_token = token
        return token

    # The main method to invoke the NFA machinery
    def _next_token(self):
        matched_token = None
        in_more = False
        # The core tokenization loop
        input_stream = self.input_stream
        read_char = input_stream.read_char
        get_line = input_stream.get_line
        get_column = input_stream.get_column
        trace_enabled = self.trace_enabled
        _char_buf = self._char_buf
        while matched_token is None:
            matched_type = None
            matched_pos = chars_read = 0
            if in_more:
                cur_char = read_char()
                if cur_char:
                    _char_buf.append(cur_char)
            else:
                _char_buf.clear()
                self.token_begin_line = get_line()
                self.token_begin_column = get_column()
                cur_char = read_char()
                if trace_enabled:
                    logger.info('Starting new token on line: %d, column: %d' % (self.token_begin_line, self.token_begin_column))
                    if cur_char == '':
                        logger.info('Reached end of input')
                    else:
                        logger.info('Read character %r (%x)', cur_char, ord(cur_char))
                if cur_char == '':
                    matched_type = TokenType.EOF
                else:
                    _char_buf.append(cur_char)

[#if multipleLexicalStates]
            # Get the NFA function table current lexical state
            # There is some possibility that there was a lexical state change
            # since the last iteration of this loop!
            nfa_functions = get_function_table_map(self.lexical_state)
[/#if]
            # the core NFA loop
            if matched_type != TokenType.EOF:
                while True:
                    # Holder for the new type (if any) matched on this iteration
                    new_type = None
                    if chars_read > 0:
                        # What was next_states on the last iteration
                        # is now the current_states!
                        temp = self.current_states
                        self.current_states = self.next_states
                        self.next_states = temp
                        retval = read_char()
                        if trace_enabled:
                            logger.info('Read character %r (%x)', retval, ord(retval))
                        if retval:
                            cur_char = retval
                            _char_buf.append(cur_char)
                        else:
                            break
                        self.next_states.clear()
                    if chars_read == 0:
                        returned_type = nfa_functions[0](cur_char, self.next_states, self.active_token_types)
                        if returned_type and (new_type is None or returned_type.value < new_type.value):
                            new_type = returned_type
                            if self.trace_enabled:
                                logger.info('Potential match: %s' % new_type)
                    else:
                        next_active = self.current_states.next_set_bit(0)
                        while next_active != -1:
                            returned_type = nfa_functions[next_active](cur_char, self.next_states, self.active_token_types)
                            if returned_type and (new_type is None or returned_type.value < new_type.value):
                                new_type = returned_type
                                if trace_enabled:
                                    logger.info('Potential match: %s', new_type)
                            next_active = self.current_states.next_set_bit(next_active + 1)
                    chars_read += 1
                    if new_type:
                        matched_type = new_type
                        in_more = matched_type in self.more_tokens
                        matched_pos = chars_read
                    if self.next_states.is_empty:
                        break
            if matched_type is None:
                self.backup(chars_read - 1)
                if trace_enabled:
                    logger.info('Invalid input: %r', _char_buf[0])
                return self.handle_invalid_char(_char_buf[0])
            else:
                if trace_enabled:
                    logger.info('Matched pattern of type: %s: %r', matched_type, _char_buf)

            if chars_read > matched_pos:
                self.backup(chars_read - matched_pos)
            if matched_type in self.regular_tokens or matched_type in self.unparsed_tokens:
                matched_token = self.instantiate_token(matched_type)
            [#if lexerData.hasTokenActions]
            matched_token = self.token_lexical_actions(matched_token, matched_type)
            [/#if]
            [#if multipleLexicalStates]
            self.do_lexical_state_switch(matched_type)
            [/#if]
        return matched_token

    def backup(self, amount):
        self.input_stream.backup(amount)
        if amount:
            self._char_buf[-amount:] = []

[#if multipleLexicalStates]
    def do_lexical_state_switch(self, token_type):
        new_state = token_type_to_lexical_state_map.get(token_type)
        if new_state is None:
            return False
        return self.switch_to(new_state)

[/#if]

    #
    # Switch to specified lexical state.
    #
    def switch_to(self, lex_state):
        if self.lexical_state != lex_state:
            if self.trace_enabled:
                logger.info('Switching from lexical state %s to %s',
                            self.lexical_state, lex_state)
            self.lexical_state = lex_state
            return True
        return False

    # Reset the token source input
    # to just after the Token passed in.
    def reset(self, t, lex_state=None):
        if t is not self._dummy_start_token:
            self.input_stream.go_to(t.end_line, t.end_column)
            self.input_stream.forward(1)
            t.set_next(None)
            t.next = None
        if lex_state:
            seld.switch_to(lex_state)

    def handle_invalid_char(self, ch):
        line = self.input_stream.end_line
        column = self.input_stream.end_column
        img = ch
        if self.invalid_token is None:
            self.invalid_token = it = InvalidToken(img, self.input_source)
            it.begin_line = line
            it.begin_column = column
        else:
            it = self.invalid_token
            it.image +=  img
        it.end_line = line
        it.end_column = column
        return it

    def instantiate_token(self, type):
        tokenImage = ''.join(self._char_buf)
[#if grammar.settings.TOKEN_FACTORY??]
        matched_token = ${grammar.settings.TOKEN_FACTORY}.new_token(type, tokenImage, self.input_source)
[#else]
        matched_token = new_token(type, tokenImage, self)
[/#if]
        matched_token.begin_line = self.token_begin_line
        matched_token.begin_column = self.token_begin_column
        matched_token.end_line = self.input_stream.end_line
        matched_token.end_column = self.input_stream.end_column
        matched_token.input_source = self.input_source
        if self.previous_token is not None:
            matched_token.previous_token = self.previous_token
            self.previous_token.next_token = matched_token
        matched_token.is_unparsed = type in self.unparsed_tokens
 [#list grammar.lexerTokenHooks as tokenHookMethodName]
    [#if tokenHookMethodName = "CommonTokenAction"]
        self.${tokenHookMethodName}(matched_token)
    [#else]
        matched_token = self.${tokenHookMethodName}(matched_token)
    [/#if]
 [/#list]
        return matched_token

 [#if lexerData.hasTokenActions]
    def token_lexical_actions(self, matched_token, matched_type):
    [#var idx = 0]
    [#list lexerData.regularExpressions as regexp]
        [#if regexp.codeSnippet?has_content]
        [#if idx > 0]el[/#if]if matched_type == TokenType.${regexp.label}:
${grammar.utils.translateCodeBlock(regexp.codeSnippet.javaCode, 12)}
          [#set idx = idx + 1]
        [/#if]
    [/#list]
        return matched_token
 [/#if]

${grammar.utils.translateLexerInjections(injector, false)}

 [#if lexerData.hasLexicalStateTransitions]
# Generate the map for lexical state transitions from the various token types (if necessary)
    [#list grammar.lexerData.regularExpressions as regexp]
      [#if !regexp.newLexicalState?is_null]
token_type_to_lexical_state_map[TokenType.${regexp.label}] = LexicalState.${regexp.newLexicalState.name}
      [/#if]
    [/#list]
 [/#if]
