/* Copyright (c) 2008-2021 Jonathan Revusky, revusky@javacc.com
 * Copyright (c) 2006, Sun Microsystems Inc.
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
 *       nor the names of any contributors may be used to endorse or promote
 *       products derived from this software without specific prior written
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

package com.javacc.lexgen;

import java.util.ArrayList;
import java.util.BitSet;
import java.util.Collections;
import java.util.List;

import com.javacc.Grammar;

import com.javacc.parsegen.RegularExpression;
import com.javacc.parser.Node;
import com.javacc.parser.tree.*;

/**
 * A Visitor object that builds an Nfa start and end state from a Regular expression. This is a
 * result of refactoring some legacy code that used all static methods. NB. This
 * class and the visit methods must be public because of the use of reflection.
 * Ideally, it would all be private and package-private.
 * 
 * @author revusky
 */
public class NfaBuilder extends Node.Visitor {

    private NfaState start, end;
    private boolean ignoreCase;
    private LexicalStateData lexicalState;
    private Grammar grammar;

    NfaBuilder(LexicalStateData lexicalState, boolean ignoreCase) {
        this.lexicalState = lexicalState;
        this.grammar = lexicalState.getGrammar();
        this.ignoreCase = ignoreCase;
    }

    void buildStates(RegularExpression regularExpression) {
        visit(regularExpression);
        end.setType(regularExpression);
        lexicalState.getInitialState().addEpsilonMove(start);
    }

    public void visit(CharacterList charList) {
        List<CharacterRange> descriptors = charList.getDescriptors();
        if (ignoreCase) {
            descriptors = toCaseNeutral(descriptors);
        }
        descriptors = sortDescriptors(descriptors);
        if (charList.isNegated()) {
            descriptors = removeNegation(descriptors);
        }
        start = new NfaState(lexicalState);
        end = new NfaState(lexicalState);
        for (CharacterRange cr : descriptors) {
            start.addRange(cr.left, cr.right);
        }
        start.setNextState(end);
    }

    public void visit(OneOrMoreRegexp oom) {
        NfaState startState = new NfaState(lexicalState);
        NfaState finalState = new NfaState(lexicalState);
        visit(oom.getRegexp());
        startState.addEpsilonMove(this.start);
        this.end.addEpsilonMove(this.start);
        this.end.addEpsilonMove(finalState);
        this.start = startState;
        this.end = finalState;
    }

    public void visit(RegexpChoice choice) {
        List<RegularExpression> choices = choice.getChoices();
        if (choices.size() == 1) {
            visit(choices.get(0));
            return;
        }
        NfaState startState = new NfaState(lexicalState);
        NfaState finalState = new NfaState(lexicalState);
        for (RegularExpression curRE : choices) {
            visit(curRE);
            startState.addEpsilonMove(this.start);
            this.end.addEpsilonMove(finalState);
        }
        this.start = startState;
        this.end = finalState;
    }

    public void visit(RegexpStringLiteral stringLiteral) {
        NfaState state = end = start = new NfaState(lexicalState);
        for (int ch : stringLiteral.getImage().codePoints().toArray()) {
            state.addCharMove(ch);
            if (grammar.isIgnoreCase() || ignoreCase) {//REVISIT
                state.addCharMove(Character.toLowerCase(ch));
                state.addCharMove(Character.toUpperCase(ch));
            }
            end = new NfaState(lexicalState);
            state.setNextState(end);
            state = end;
        }
    }

    public void visit(ZeroOrMoreRegexp zom) {
        NfaState startState = new NfaState(lexicalState);
        NfaState finalState = new NfaState(lexicalState);
        visit(zom.getRegexp());
        startState.addEpsilonMove(this.start);
        startState.addEpsilonMove(finalState);
        this.end.addEpsilonMove(finalState);
        this.end.addEpsilonMove(this.start);
        this.start = startState;
        this.end = finalState;
    }

    public void visit(ZeroOrOneRegexp zoo) {
        NfaState startState = new NfaState(lexicalState);
        NfaState finalState = new NfaState(lexicalState);
        visit(zoo.getRegexp());
        startState.addEpsilonMove(this.start);
        startState.addEpsilonMove(finalState);
        this.end.addEpsilonMove(finalState);
        this.start = startState;
        this.end = finalState;
    }

    public void visit(RegexpRef ref) {
        // REVISIT. Can the states generated
        // here be reused?
        visit(ref.getRegexp());
    }

    public void visit(RegexpSequence sequence) {
        if (sequence.getUnits().size() == 1) {
            visit(sequence.getUnits().get(0));
        }
        NfaState startState = new NfaState(lexicalState);
        NfaState finalState = new NfaState(lexicalState);
        NfaState prevStartState = null;
        NfaState prevEndState = null;
        for (RegularExpression re : sequence.getUnits()) {
            visit(re);
            if (prevStartState == null) {
                startState.addEpsilonMove(this.start);
            } else {
                prevEndState.addEpsilonMove(this.start);
            }
            prevStartState = this.start;
            prevEndState = this.end;
        }
        this.end.addEpsilonMove(finalState);
        this.start = startState;
        this.end = finalState;
    }

    public void visit(RepetitionRange repRange) {
        List<RegularExpression> units = new ArrayList<RegularExpression>();
        RegexpSequence seq;
        int i;
        for (i = 0; i < repRange.getMin(); i++) {
            units.add(repRange.getRegexp());
        }
        if (repRange.hasMax() && repRange.getMax() == -1) { // Unlimited
            ZeroOrMoreRegexp zom = new ZeroOrMoreRegexp();
            zom.setGrammar(grammar);
            zom.setRegexp(repRange.getRegexp());
            units.add(zom);
        }
        while (i++ < repRange.getMax()) {
            ZeroOrOneRegexp zoo = new ZeroOrOneRegexp();
            zoo.setGrammar(grammar);
            zoo.setRegexp(repRange.getRegexp());
            units.add(zoo);
        }
        seq = new RegexpSequence();
        seq.setGrammar(grammar);
        seq.setOrdinal(Integer.MAX_VALUE);
        for (RegularExpression re : units) {
            seq.addChild(re);
        }
        visit(seq);
    }

    static private List<CharacterRange> toCaseNeutral(List<CharacterRange> descriptors) {
        BitSet bs = rangeListToBS(descriptors);
        BitSet copy1 = (BitSet) bs.clone();
        BitSet copy2 = (BitSet) bs.clone();
        copy1.and(upperCaseDiffSet);
        copy2.and(lowerCaseDiffSet);
        copy1.stream().forEach(ch -> bs.set(Character.toUpperCase(ch)));
        copy2.stream().forEach(ch -> bs.set(Character.toLowerCase(ch)));
        return bsToRangeList(bs);
    }

    static private List<CharacterRange> removeNegation(List<CharacterRange> descriptors) {
        //NB. This routine depends on the fact that the descriptors list is already sorted by sortDescriptors()
        List<CharacterRange> result = new ArrayList<>();
        CharacterRange lastRange = null;
        for (CharacterRange range : descriptors) {
            if (range.left >0) {
                int begin = lastRange == null ? 0 : lastRange.right+1; 
                result.add(new CharacterRange(begin, range.left -1));
            }
            lastRange = range;
        }
        if (lastRange !=null && lastRange.right < 0x10FFFF) {
            result.add(new CharacterRange(lastRange.right+1, 0x10FFFF));
        }
        if (result.isEmpty()) {
            result.add(new CharacterRange(0, 0x10FFFF));
        }
        return result;
    }

   static List<CharacterRange> sortDescriptors(List<CharacterRange> descriptors) {
        Collections.sort(descriptors, (first, second) -> first.left - second.left);
        List<CharacterRange> result = new ArrayList<>();
        CharacterRange previous = null;
        for (CharacterRange range : descriptors) {
            if (previous == null) {
                result.add(range);
                previous = range;
            } else {
                if (previous.left == range.left) {
                    previous.right = Math.max(previous.right, range.right);
                } else if (previous.right >= range.left - 1) {
                    previous.right = Math.max(previous.right, range.right);
                } else {
                    result.add(range);
                    previous = range;
                }
            }
        }
        return result;
    }

    // BitSet that holds which characters are not the same in lower case
    static private BitSet lowerCaseDiffSet = caseDiffSetInit(false);
    // BitSet that holds which characters are not the same in upper case
    static private BitSet upperCaseDiffSet = caseDiffSetInit(true);

    static private BitSet caseDiffSetInit(boolean upper) {
        BitSet result = new BitSet();
        for (int ch = 0; ch <= 0x16e7f; ch++) {
            int converted = upper ? Character.toUpperCase(ch) : Character.toLowerCase(ch);
            if (converted != ch) {
                result.set(ch);
            }
        }
        return result;
    }

    // Convert a list of CharacterRange's to a BitSet
    static private BitSet rangeListToBS(List<CharacterRange> ranges) {
        BitSet result = new BitSet();
        for (CharacterRange range : ranges) {
            result.set(range.left, range.right+1);
        }
        return result;
    }

    //Convert a BitSet to a list of CharacterRange's
    static private List<CharacterRange> bsToRangeList(BitSet bs) {
        List<CharacterRange> result = new ArrayList<>();
        int curPos = 0;
        while (curPos >=0) {
            int left = bs.nextSetBit(curPos);
            int right = bs.nextClearBit(left) -1;
            result.add(new CharacterRange(left, right));
            curPos = bs.nextSetBit(right+1);
        }
        return result;
    }
}
