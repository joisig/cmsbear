defmodule Cmsbear.MarkupTest do
  use ExUnit.Case, async: true

  alias Cmsbear.Markup

  def get_default_ast() do
    {:ok, ast, _} = EarmarkParser.as_ast("Hello *world* how are you?\n\nWe are all good here! `yes?` maybe.\n\n# Heading!")
    ast
  end

  def count_tags(ast, tag_name) do
    {_, count} = Markup.walk_and_modify_ast(ast, 0, fn (item, acc) ->
      case item do
        {^tag_name, _, _, _} ->
          {item, acc + 1}
        _ ->
          {item, acc}
      end
    end)
    count
  end

  test "walk_and_modify_ast without change" do
    ast = get_default_ast()
    {new_ast, []} = Markup.walk_and_modify_ast(ast, [], &({&1, &2}))
    assert new_ast == ast
  end

  test "walk_and_modify_ast without change, but with accumulator" do
    ast = get_default_ast()
    {new_ast, count} = Markup.walk_and_modify_ast(ast, 0, fn (item, acc) ->
      case item do
        {"p", _, _, _} ->
          {item, acc + 1}
        _ ->
          {item, acc}
      end
    end)
    assert new_ast == ast
    assert count == 2
  end

  test "walk_and_modify_ast make the word 'are' bold" do
    ast = get_default_ast()
    {new_ast, _} = Markup.walk_and_modify_ast(ast, [], fn (item, acc) ->
      case item do
        text when is_binary(item) ->
          new_item = Markup.text_to_ast_list_splitting_regex(text, ~r/\bare\b/, fn [content] ->
            {"strong", [], [content], %{}}
          end)
          {new_item, acc}
        item ->
          {item, acc}
      end
    end)
    assert count_tags(new_ast, "strong") == 2
    assert Earmark.transform(new_ast) == "<p>\nHello <em>world</em> how <strong>are</strong> you?</p>\n<p>\nWe <strong>are</strong> all good here! <code class=\"inline\">yes?</code> maybe.</p>\n<h1>\nHeading!</h1>\n"
  end

end
