[#ftl strict_vars=true]
[#--
/* Copyright (c) 2008-2019 Jonathan Revusky, revusky@javacc.com
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
[#var classname = filename[0..(filename?length -6)]]
/* Generated by: ${generated_by}. Do not edit. 
  * Generated Code for ${classname} AST Node type
  * by the ASTNode.java.ftl template
  */

[#var package = ""]
[#if explicitPackageName??]
package ${explicitPackageName};
[#set package = explicitPackageName]
[#elseif grammar.nodePackage?has_content]
[#set package = grammar.nodePackage]
package ${package};
[/#if]
[#if grammar.parserPackage?has_content && package != grammar.parserPackage]
import ${grammar.parserPackage}.*;
[/#if]

[#if isInterface]

public interface ${classname} extends Node {}

[#else]

[#if grammar.parserPackage?has_content]
import static ${grammar.parserPackage}.${grammar.constantsClassName}.TokenType.*;
[/#if]

@SuppressWarnings("unused")
[#if isAbstract]abstract[/#if]
public class ${classname} extends ${grammar.baseNodeClassName} {
[#if false] grammar.nodeUsesParser]
    public ${classname}(${grammar.parserClassName} p, int id) {
        super(p, id);
    }

    public ${classname}(${grammar.parserClassName} p) {
        super(p, ${grammar.constantsClassName}.${classname?upper_case});
    }

[/#if]

}
[/#if]