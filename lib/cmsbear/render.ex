defmodule Cmsbear.Render do

  def get_includes_used(text) do
    Regex.scan(~r/{{\s*include\s+(?<include_name>[a-zA-Z0-9\.]+)\s*}}/, text)
    |> Enum.map(&(&1 |> Enum.at(1)))
  end

  def get_variables_used(text) do
    Regex.scan(~r/{{\s*var\s+(?<var_name>[a-zA-Z0-9]+)\s*}}/, text)
    |> Enum.map(&(&1 |> Enum.at(1)))
  end

  def strip_layout_from_comment(text) do
    case Regex.named_captures(~r/(?<all>\<!--\s*layout:?\s+(?<layout>[a-zA-Z0-9]+)\s*--\>)/, text) do
      nil ->
        {:blank, text}
      %{"layout" => layout, "all" => text_to_strip} = captures ->
        {layout, String.replace(text, text_to_strip, "\n")}
    end
  end

  def get_layout_text(name, layouts) do
    case name do
      :blank ->
        "{{content}}"
      _ ->
        %{^name => layout_text} = layouts
        layout_text.body
    end
  end

  def render(text, context, layouts, includes) when is_binary(text) and is_map(context) and is_map(layouts) and is_map(includes) do
    with_includes = Enum.reduce(get_includes_used(text), text, fn include_name, acc ->
      include_text = render(includes[include_name].body, %{"layout" => :blank}, %{}, includes)
      String.replace(acc, ~r/{{\s*include\s+#{include_name}\s*}}/, include_text, [:global])
    end)

    with_variables = Enum.reduce(get_variables_used(text), with_includes, fn var_name, acc ->
      replacement = context[var_name]
      case replacement do
        nil ->
          acc
        _ ->
          String.replace(acc, ~r/{{\s*var\s+#{var_name}\s*}}/, replacement, [:global])
      end
    end)

    {layout, without_layout_comment} = strip_layout_from_comment(with_variables)

    layout = Map.get(context, "layout", layout)
    case layout do
      :blank ->
        without_layout_comment
      _ ->
        in_layout = String.replace(get_layout_text(layout, layouts), ~r/{{\s*content\s*}}/, without_layout_comment)
        # When rendering layouts, they can only specify their parent layout as an HTML comment,
        # not via context.
        render(in_layout, Map.delete(context, "layout"), layouts, includes)
    end
  end

end
