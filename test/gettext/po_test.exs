defmodule Gettext.POTest do
  use ExUnit.Case, async: true

  alias Gettext.PO
  alias Gettext.PO.Translation
  alias Gettext.PO.PluralTranslation
  alias Gettext.PO.SyntaxError

  doctest PO

  test "parse_string/1: valid string" do
    str = """
    msgid "hello there"
    msgstr "ciao"

       msgid "indenting and " "strings"
      msgstr "indentazione " "e stringhe"
    """

    assert {:ok, %PO{headers: [], translations: [
      %Translation{msgid: ["hello there"], msgstr: ["ciao"]},
      %Translation{msgid: ["indenting and ", "strings"], msgstr: ["indentazione ", "e stringhe"]},
    ]}} = PO.parse_string(str)
  end

  test "parse_string/1: invalid strings" do
    str = """
    msgid
    msgstr "foo"
    """
    assert PO.parse_string(str) == {:error, 1, "syntax error before: msgstr"}

    str = "msg"
    assert PO.parse_string(str) == {:error, 1, "unknown keyword 'msg'"}

    str = """
    msgid "foo
    bar"
    """
    assert PO.parse_string(str) == {:error, 1, "newline in string"}
  end

  test "parse_string!/1: valid strings" do
    str = """
    msgid "foo"
    msgstr "bar"
    """

    assert %PO{
      translations: [%Translation{msgid: ["foo"], msgstr: ["bar"]}],
      headers: []
    } = PO.parse_string!(str)
  end

  test "parse_string!/1: invalid strings" do
    str = "msg"
    assert_raise SyntaxError, "1: unknown keyword 'msg'", fn ->
      PO.parse_string!(str)
    end

    str = """

    msgid
    msgstr "bar"
    """
    assert_raise SyntaxError, "2: syntax error before: msgstr", fn ->
      PO.parse_string!(str)
    end
  end

  test "parse_string(!)/1: headers" do
    str = ~S"""
    msgid ""
    msgstr ""
      "Project-Id-Version: xxx\n"
      "Report-Msgid-Bugs-To: \n"
      "POT-Creation-Date: 2010-07-06 12:31-0500\n"

    msgid "foo"
    msgstr "bar"
    """

    assert {:ok, %PO{
      translations: [%Translation{msgid: ["foo"], msgstr: ["bar"]}],
      headers: [
        "",
        "Project-Id-Version: xxx\n",
        "Report-Msgid-Bugs-To: \n",
        "POT-Creation-Date: 2010-07-06 12:31-0500\n",
      ]
    }} = PO.parse_string(str)
  end

  test "parse_file/1: valid file contents" do
    fixture_path = Path.expand("../fixtures/valid.po", __DIR__)

    assert {:ok, %PO{headers: [], translations: [
      %Translation{msgid: ["hello"], msgstr: ["ciao"]},
      %Translation{msgid: ["how are you,", " friend?"], msgstr: ["come stai,", " amico?"]},
    ]}} = PO.parse_file(fixture_path)
  end

  test "parse_file/1: invalid file contents" do
    fixture_path = Path.expand("../fixtures/invalid_syntax_error.po", __DIR__)
    assert PO.parse_file(fixture_path) == {:error, 4, "syntax error before: msgstr"}

    fixture_path = Path.expand("../fixtures/invalid_token_error.po", __DIR__)
    assert PO.parse_file(fixture_path) == {:error, 3, "unknown keyword 'msg'"}
  end

  test "parse_file/1: missing file" do
    assert PO.parse_file("nonexistent") == {:error, :enoent}
  end

  test "parse_file!/1: populates the :file field with the path of the parsed file" do
    fixture_path = Path.expand("../fixtures/valid.po", __DIR__)
    assert {:ok, %PO{file: ^fixture_path}} = PO.parse_file(fixture_path)
  end

  test "parse_file!/1: valid file contents" do
    fixture_path = Path.expand("../fixtures/valid.po", __DIR__)

    assert %PO{headers: [], translations: [
      %Translation{msgid: ["hello"], msgstr: ["ciao"]},
      %Translation{msgid: ["how are you,", " friend?"], msgstr: ["come stai,", " amico?"]},
    ]} = PO.parse_file!(fixture_path)
  end

  test "parse_file!/1: invalid file contents" do
    fixture_path = Path.expand("../fixtures/invalid_syntax_error.po", __DIR__)
    msg = "invalid_syntax_error.po:4: syntax error before: msgstr"
    assert_raise SyntaxError, msg, fn ->
      PO.parse_file!(fixture_path)
    end

    fixture_path = Path.expand("../fixtures/invalid_token_error.po", __DIR__)
    msg = "invalid_token_error.po:3: unknown keyword 'msg'"
    assert_raise SyntaxError, msg, fn ->
      PO.parse_file!(fixture_path)
    end
  end

  test "parse_file!/1: missing file" do
    msg = "could not parse nonexistent: no such file or directory"
    assert_raise File.Error, msg, fn ->
      PO.parse_file!("nonexistent")
    end
  end

  test "parse_file/1: populates the :file field with the path of the parsed file" do
    fixture_path = Path.expand("../fixtures/valid.po", __DIR__)
    assert %PO{file: ^fixture_path} = PO.parse_file!(fixture_path)
  end

  test "parse_file(!)/1: empty files don't cause parsing errors" do
    fixture_path = Path.expand("../fixtures/empty.po", __DIR__)
    assert %PO{translations: [], headers: []} = PO.parse_file!(fixture_path)
  end

  test "dump/1: single translation" do
    po = %PO{headers: [], translations: [
      %Translation{msgid: ["foo"], msgstr: ["bar"]},
    ]}

    assert IO.iodata_to_binary(PO.dump(po)) == ~S"""
    msgid "foo"
    msgstr "bar"
    """
  end

  test "dump/1: single plural translation" do
    po = %PO{headers: [], translations: [%PluralTranslation{
      msgid: ["one foo"],
      msgid_plural: ["%{count} foos"],
      msgstr: %{
        0 => ["one bar"],
        1 => ["%{count} bars"]
      }
    }]}

    assert IO.iodata_to_binary(PO.dump(po)) == ~S"""
    msgid "one foo"
    msgid_plural "%{count} foos"
    msgstr[0] "one bar"
    msgstr[1] "%{count} bars"
    """
  end

  test "dump/1: multiple translations" do
    po = %PO{headers: [], translations: [
      %Translation{msgid: ["foo"], msgstr: ["bar"]},
      %Translation{msgid: ["baz"], msgstr: ["bong"]},
    ]}

    assert IO.iodata_to_binary(PO.dump(po)) == ~S"""
    msgid "foo"
    msgstr "bar"

    msgid "baz"
    msgstr "bong"
    """
  end

  test "dump/1: translation with comments" do
    # Reference comments are ignored.

    po = %PO{headers: [], translations: [
      %Translation{
        msgid: ["foo"],
        msgstr: ["bar"],
        comments: ["# comment", "#: foo.ex:32", "# another comment"],
      }
    ]}

    assert IO.iodata_to_binary(PO.dump(po)) == ~S"""
    # comment
    # another comment
    msgid "foo"
    msgstr "bar"
    """
  end

  test "dump/1: references" do
    po = %PO{translations: [
      %Translation{
        msgid: ["foo"],
        msgstr: ["bar"],
        references: [{"foo.ex", 1}, {"lib/bar.ex", 2}],
      },
      %PluralTranslation{
        msgid: ["foo"],
        msgid_plural: ["foos"],
        msgstr: %{0 => [""], 1 => [""]},
        references: [{"lib/with spaces.ex", 1}],
      }
    ]}

    assert IO.iodata_to_binary(PO.dump(po)) == ~S"""
    #: foo.ex:1
    #: lib/bar.ex:2
    msgid "foo"
    msgstr "bar"

    #: lib/with spaces.ex:1
    msgid "foo"
    msgid_plural "foos"
    msgstr[0] ""
    msgstr[1] ""
    """
  end

  test "dump/1: headers" do
    po = %PO{translations: [], headers: [
      "Content-Type: text/plain\n",
      "Project-Id-Version: xxx\n",
    ]}

    assert IO.iodata_to_binary(PO.dump(po)) == ~S"""
    msgid ""
    msgstr ""
    "Content-Type: text/plain\n"
    "Project-Id-Version: xxx\n"
    """
  end

  test "dump/1: multiple strings" do
    po = %PO{headers: [], translations: [
      %Translation{msgid: ["foo", "bar"], msgstr: ["bar", "baz\n", "bang"]},
      %PluralTranslation{msgid: ["a", "b"], msgid_plural: ["as", "bs"], msgstr: %{
        0 => ["c", "d"],
        1 => ["e", "f"]
      }},
    ]}

    assert IO.iodata_to_binary(PO.dump(po)) == ~S"""
    msgid "foo"
      "bar"
    msgstr "bar"
      "baz\n"
      "bang"

    msgid "a"
      "b"
    msgid_plural "as"
      "bs"
    msgstr[0] "c"
      "d"
    msgstr[1] "e"
      "f"
    """
  end

  test "dump/1: headers and multiple (plural) translations with comments" do
    po = %PO{
      translations: [
        %Translation{
          msgid: ["foo"],
          msgstr: ["bar"],
          comments: ["# comment", "#: foo.ex:32", "# another comment"],
        },
        %PluralTranslation{
          msgid: ["a foo, %{name}"],
          msgid_plural: ["%{count} foos, %{name}"],
          msgstr: %{0 => ["a bar, %{name}"], 1 => ["%{count} bars, %{name}"]},
          comments: ["# comment 1", "# comment 2", "#: lib/ref.ex:29"],
        }
      ],
      headers: [
        "Project-Id-Version: 1\n",
        "Language: fooesque\n",
      ]
    }

    assert IO.iodata_to_binary(PO.dump(po)) == ~S"""
    msgid ""
    msgstr ""
    "Project-Id-Version: 1\n"
    "Language: fooesque\n"

    # comment
    # another comment
    msgid "foo"
    msgstr "bar"

    # comment 1
    # comment 2
    msgid "a foo, %{name}"
    msgid_plural "%{count} foos, %{name}"
    msgstr[0] "a bar, %{name}"
    msgstr[1] "%{count} bars, %{name}"
    """
  end

  test "dump/1: escaped characters in msgid/msgstr" do
    po = %PO{headers: [], translations: [
      %Translation{msgid: [~s("quotes")], msgstr: [~s(foo "bar" baz)]},
      %Translation{msgid: [~s(new\nlines\r)], msgstr: [~s(and\ttabs)]},
    ]}

    assert IO.iodata_to_binary(PO.dump(po)) == ~S"""
    msgid "\"quotes\""
    msgstr "foo \"bar\" baz"

    msgid "new\nlines\r"
    msgstr "and\ttabs"
    """
  end

  test "dump/1: double quotes in headers are escaped" do
    po = %PO{headers: [~s(Foo: "bar"\n)]}

    assert IO.iodata_to_binary(PO.dump(po)) == ~S"""
    msgid ""
    msgstr ""
    "Foo: \"bar\"\n"
    """
  end

  # Individual testing of the `dump(parse(po)) == po` process for different PO
  # editors.
  for file <- Path.wildcard("test/fixtures/po_editors/*.po") do
    editor = Path.basename(file, ".ex")

    test "parsing and dumping gives back the original file (editor: #{editor})" do
      file              = unquote(file)
      parsed_and_dumped = file |> PO.parse_file! |> PO.dump |> IO.iodata_to_binary
      assert parsed_and_dumped == File.read!(file)
    end
  end

  test "merge/2: non-autogenerated translations are kept" do
    # No autogenerated translations
    t1 = %Translation{msgid: ["foo"], msgstr: ["bar"]}
    t2 = %Translation{msgid: ["baz"], msgstr: ["bong"]}
    t3 = %Translation{msgid: ["a", "b"], msgstr: ["c", "d"]}
    old = %PO{translations: [t1]}
    new = %PO{translations: [t2, t3]}

    assert PO.merge(old, new) == %PO{translations: [t1, t2, t3]}
  end

  test "merge/2: obsolete autogenerated translations are discarded" do
    # Autogenerated translations
    t1 = %Translation{msgid: ["foo"], msgstr: ["bar"], references: [{"foo.ex", 1}]}
    t2 = %Translation{msgid: ["baz"], msgstr: ["bong"]}
    old = %PO{translations: [t1]}
    new = %PO{translations: [t2]}

    assert PO.merge(old, new) == %PO{translations: [t2]}
  end

  test "merge/2: matching translations are merged" do
    ts1 = [
      %Translation{msgid: ["foo"], references: [{"foo.ex", 2}]},
      %Translation{msgid: ["bar"], references: [{"foo.ex", 1}]},
    ]
    ts2 = [
      %Translation{msgid: ["baz"]},
      %Translation{msgid: ["foo"], references: [{"foo.ex", 3}]},
    ]

    assert PO.merge(%PO{translations: ts1}, %PO{translations: ts2}) == %PO{translations: [
      %Translation{msgid: ["foo"], references: [{"foo.ex", 3}]},
      %Translation{msgid: ["baz"]},
    ]}
  end

  test "merge/2: headers are taken from the oldest PO file" do
    po1 = %PO{headers: ["Last-Translator: Foo", "Content-Type: text/plain"]}
    po2 = %PO{headers: ["Last-Translator: Bar"]}

    assert PO.merge(po1, po2) == %PO{headers: [
      "Last-Translator: Foo",
      "Content-Type: text/plain",
    ]}
  end

  test "merge/2: all obsolete translations are discarded if :keep_manual_translations is false" do
    obsolete = [
      %Translation{msgid: ["foo"], msgstr: ["bar"], references: [{"foo.ex", 1}]},
      %PluralTranslation{msgid: ["baz"], msgid_plural: ["bazes"], msgstr: %{}},
    ]

    old = %PO{translations: obsolete}
    new = %PO{translations: [%Translation{msgid: ["new"], msgstr: [""]}]}

    assert PO.merge(old, new, keep_manual_translations: false) == new
  end

  test "merge/2: msgstrs are not overridden if :pot_onto_po is true" do
    old = %PO{translations: [%Translation{msgid: ["foo"], msgstr: ["foo"]}]}
    new = %PO{translations: [%Translation{msgid: ["foo"], msgstr: [""]}]}

    assert PO.merge(old, new, pot_onto_po: true) == old
  end
end
