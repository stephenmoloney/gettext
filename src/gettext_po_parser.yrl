Nonterminals grammar elements element strings comments.
Terminals str msgid msgid_plural msgstr plural_form comment.
Rootsymbol grammar.

grammar ->
  elements : '$1'.

elements ->
  element : ['$1'].
elements ->
  element elements : ['$1'|'$2'].

element ->
  msgid strings : {msgid, extract_line('$1'), '$2'}.
element ->
  msgid_plural strings : {msgid_plural, extract_line('$1'), '$2'}.
element ->
  msgstr strings : {msgstr, extract_line('$1'), '$2'}.
element ->
  msgstr plural_form strings : {pluralization, extract_line('$1'), {'$2', '$3'}}.
element ->
  comments : {comments, '$1'}.

strings ->
  str : [extract_simple_token('$1')].
strings ->
  str strings : [extract_simple_token('$1')|'$2'].

comments ->
  comment : [extract_simple_token('$1')].
comments ->
  comment comments : [extract_simple_token('$1')|'$2'].


Erlang code.

extract_simple_token({_Token, _Line, Value}) ->
  Value.

extract_line({_Token, Line}) ->
  Line.
